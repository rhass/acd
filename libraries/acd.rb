#
# Cookbook Name:: acd
# Library:: acd
#
# Copyright 2016 Ryan Hass
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'poise'
require 'chef/resource'
require 'chef/provider'
require 'json'

module Acd
  class Resource < Chef::Resource
    include Poise
    include PoisePython::PythonCommandMixin
    provides(:acd)

    attribute(:path, kind_of: String, name_attribute: true)
    attribute(:acd_cli_settings_path, kind_of: String, default: lazy { self.acd_cli_settings_path })
    attribute(:acd_cli_cache_path, kind_of: String)
    attribute(:amazon_email, kind_of: String)
    attribute(:amazon_password, kind_of: String)
    attribute(:group, kind_of: String, default: 'root')
    attribute(:mount_opts, kind_of: [Array, NilClass])
    attribute(:oauth_endpoint, kind_of: String, default: 'https://tensile-runway-92512.appspot.com/')
    attribute(:remount, kind_of: [TrueClass, FalseClass], default: true)
    attribute(:user, kind_of: String, default: 'root')
    attribute(:version, kind_of: String, default: '0.3.2')

    actions(:mount, :unmount, :sync)

    def acd_cli_settings_path
      ::File.join(::Dir.home(self.user), '.cache', 'acd_cli')
    end
  end

  class Provider < Chef::Provider
    include Poise
    include PoisePython::Resources::PythonPackage

    provides(:acd)

    def action_mount
      notifying_block do
        install_acd_cli
        generate_oauth_data_file
        mount_drive
      end
    end

    def action_unmount
      install_acd_cli
      unmount_drive
    end

    def action_sync
      install_acd_cli
      sync_drive
    end

    def mount_cmd
      cmd ||= [
        'acd_cli',
        'mount',
        '--uid', Etc.getpwnam(new_resource.user).uid,
        '--gid', Etc.getgrnam(new_resource.group).gid,
        "#{new_resource.mount_opts.join(' ')}",
        new_resource.path,
      ]
    end

    private

    def sync_drive
      cmd = [
        'acd_cli',
        'sync',
      ]

      poise_shell_out!(
        cmd,
        user: new_resource.user,
        group: new_resource.group,
      )
    end

    def mount_drive
      notifying_block do
        directory new_resource.path do
          recursive true
          user new_resource.user
          group new_resource.group
          # Match permissions which acdcli sets when mount is run.
          # acdcli seems to remap the permissions to 0776 for some reason.
          mode 0776
        end

        if new_resource.remount
          create_mount_script

          mount new_resource.path do
            device '/usr/local/bin/acdmount'
            fstype 'fuse'
            options '_netdev'
            action :enable
          end
        end

        unless node['filesystem'].attribute?('ACDFuse') && node['filesystem']['ACDFuse']['mount'] == new_resource.path
          sync_drive

          poise_shell_out(
            mount_cmd.join(' '),
            user: new_resource.user,
            group: new_resource.group,
          )
        end
      end
    end

    def unmount_drive
      cmd = [
        'acd_cli',
        'unmount',
        new_resource.path,
      ]

      poise_shell_out!(
        cmd,
        user: new_resource.user,
        group: new_resource.group,
      )

    end

    def install_acd_cli
      notifying_block do
        package %w{fuse}

        python_package 'acdcli' do
          python_from_parent new_resource
          user new_resource.user
          version new_resource.version
          action :upgrade
        end
      end
    end

    # Return token as hash for defined username and password.
    # We install mechanize here rather than with `gem` in the metadata
    # as mechanize depends on build-essential to compile the native parts.
    def oauth_token
      notifying_block do
        include_recipe 'build-essential'

        chef_gem 'mechanize' do
          compile_time true
        end
      end

      oauth_data ||= Acd::OauthHandler.new(
        email: new_resource.amazon_email,
        password: new_resource.amazon_password,
        oauth_endpoint: new_resource.oauth_endpoint,
      )

      oauth_data.token
    end

    # Create a new oauth_data if missing, or if the file is over one hour old.
    def generate_oauth_data_file
      oauth_data_file = ::File.join(new_resource.acd_cli_settings_path, 'oauth_data')
      oauth_data_content = oauth_token.to_json

      notifying_block do
        directory new_resource.acd_cli_settings_path do
          recursive true
          mode 0750
          owner new_resource.user
          group new_resource.group
        end

        file oauth_data_file do
          content oauth_data_content
          mode 0640
          owner new_resource.user
          group new_resource.group
          sensitive true
          only_if do
            if ::File.exist?(oauth_data_file)
              (::Time.now - ::File.stat(oauth_data_file).mtime).to_i > 3600
            else
              true
            end
          end
        end

      end
    end

    def create_mount_script
      file '/usr/local/bin/acdmount' do
        content "#!/usr/bin/env bash\n\n#{mount_cmd.join(' ')}\n"
        mode 0755
      end
    end

    def configure_acd_cli
      oauth_data

      cmd = [
        'acd_cli',
        'init',
        '-v',
      ]

      unless node['filesystem'].attribute?('ACDFuse') && node['filesystem']['ACDFuse']['mount'] == new_resource.path
        python_shell_out!(
          cmd,
          user: new_resource.user,
          group: new_resource.group,
        )
      end
    end
  end
end
