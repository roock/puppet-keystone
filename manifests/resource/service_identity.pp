#
# Copyright (C) 2014 eNovance SAS <licensing@enovance.com>
#
# Author: Emilien Macchi <emilien.macchi@enovance.com>
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.
#
# == Definition: keystone::resource::service_identity
#
# This resource configures Keystone resources for an OpenStack service.
#
# == Parameters:
#
# [*ensure*]
#   Ensure parameter for the types used in resource.
#   string; optional: default to 'present'
#
# [*password*]
#   Password to create for the service user;
#   string; required
#
# [*auth_name*]
#   The name of the service user;
#   string; optional; default to the $title of the resource, i.e. 'nova'
#
# [*service_name*]
#   Name of the service;
#   string; required
#
# [*service_type*]
#   Type of the service;
#   string; required
#
# [*service_description*]
#   Description of the service;
#   string; optional: default to '$name service'
#
# [*public_url*]
#   Public endpoint URL;
#   string; required
#
# [*internal_url*]
#   Internal endpoint URL;
#   string; required
#
# [*admin_url*]
#   Admin endpoint URL;
#   string; required
#
# [*region*]
#   Endpoint region;
#   string; optional: default to 'RegionOne'
#
# [*tenant*]
#   Service tenant;
#   string; optional: default to 'services'
#
# [*roles*]
#   List of roles;
#   array of strings; optional: default to ['admin']
#
# [*system_scope*]
#   Scope for system operations
#   string; optional: default to 'all'
#
# [*system_roles*]
#   List of system roles;
#   array of strings; optional: default to []
#
# [*email*]
#   Service email;
#   string; optional: default to '$auth_name@localhost'
#
# [*configure_endpoint*]
#   Whether to create the endpoint.
#   string; optional: default to True
#
# [*configure_user*]
#   Whether to create the user.
#   string; optional: default to True
#
# [*configure_user_role*]
#   Whether to create the user role.
#   string; optional: default to True
#
# [*configure_service*]
#   Whether to create the service.
#   string; optional: default to True
#
# [*user_domain*]
#   (Optional) Domain for $auth_name
#   Defaults to undef (use the keystone server default domain)
#
# [*project_domain*]
#   (Optional) Domain for $tenant (project)
#   Defaults to undef (use the keystone server default domain)
#
# [*default_domain*]
#   (Optional) Domain for $auth_name and $tenant (project)
#   If keystone_user_domain is not specified, use $keystone_default_domain
#   If keystone_project_domain is not specified, use $keystone_default_domain
#   Defaults to undef
#
define keystone::resource::service_identity(
  $ensure                = 'present',
  $admin_url             = false,
  $internal_url          = false,
  $password              = false,
  $public_url            = false,
  $service_type          = false,
  $auth_name             = $name,
  $configure_endpoint    = true,
  $configure_user        = true,
  $configure_user_role   = true,
  $configure_service     = true,
  $email                 = "${name}@localhost",
  $region                = 'RegionOne',
  $service_name          = undef,
  $service_description   = "${name} service",
  $tenant                = 'services',
  $roles                 = ['admin'],
  $system_scope          = 'all',
  $system_roles          = [],
  $user_domain           = undef,
  $project_domain        = undef,
  $default_domain        = undef,
) {

  include keystone::deps

  validate_legacy(Enum['present', 'absent'], 'validate_re', $ensure,
    [['^present$', '^absent$'], 'Valid values for ensure parameter are present or absent'])

  if $service_name == undef {
    $service_name_real = $auth_name
  } else {
    $service_name_real = $service_name
  }

  if $user_domain == undef {
    $user_domain_real = $default_domain
  } else {
    $user_domain_real = $user_domain
  }

  if $configure_user {
    if $user_domain_real {
      # We have to use ensure_resource here and hope for the best, because we have
      # no way to know if the $user_domain is the same domain passed as the
      # $default_domain parameter to class keystone.
      ensure_resource('keystone_domain', $user_domain_real, {
        'ensure'  => $ensure,
        'enabled' => true,
      })
    }
    ensure_resource('keystone_user', $auth_name, {
      'ensure'                => $ensure,
      'enabled'               => true,
      'password'              => $password,
      'email'                 => $email,
      'domain'                => $user_domain_real,
    })
    if ! $password {
      warning("No password had been set for ${auth_name} user.")
    }
  }

  if $configure_user_role {
    if $ensure == 'present' {
      # NOTE(jaosorior): We only handle ensure 'present' here, since deleting a
      # role might be conflicting in some cases. e.g. the deployer removing a
      # role from one service but adding it to another in the same puppet run.
      # So role deletion should be handled elsewhere.
      ensure_resource('keystone_role', $roles, { 'ensure' => 'present' })
      ensure_resource('keystone_role', $system_roles, { 'ensure' => 'present' })
    }
    unless empty($roles) {
      ensure_resource('keystone_user_role', "${auth_name}@${tenant}", {
        'ensure' => $ensure,
        'roles'  => $roles,
      })
    }
    unless empty($system_roles) {
      ensure_resource('keystone_user_role', "${auth_name}@::::${system_scope}", {
        'ensure' => $ensure,
        'roles'  => $system_roles,
      })
    }
  }

  if $configure_service {
    if $service_type {
      ensure_resource('keystone_service', "${service_name_real}::${service_type}", {
        'ensure'      => $ensure,
        'description' => $service_description,
      })
    } else {
      fail ('When configuring a service, you need to set the service_type parameter.')
    }
  }

  if $configure_endpoint {
    if $service_type {
      if $public_url and $admin_url and $internal_url {
        ensure_resource('keystone_endpoint', "${region}/${service_name_real}::${service_type}", {
          'ensure'       => $ensure,
          'public_url'   => $public_url,
          'admin_url'    => $admin_url,
          'internal_url' => $internal_url,
        })
      } else {
        fail ('When configuring an endpoint, you need to set the _url parameters.')
      }
    } else {
      if $public_url and $admin_url and $internal_url {
        ensure_resource('keystone_endpoint', "${region}/${service_name_real}", {
          'ensure'       => $ensure,
          'public_url'   => $public_url,
          'admin_url'    => $admin_url,
          'internal_url' => $internal_url,
        })
      } else {
        fail ('When configuring an endpoint, you need to set the _url parameters.')
      }
      warning('Defining a endpoint without the type is supported in Liberty and will be dropped in Mitaka. See https://bugs.launchpad.net/puppet-keystone/+bug/1506996')
    }
  }
}
