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
    attribute(:user, kind_of: String, default: 'root')

    actions(:mount, :unmount, :sync)

    def acd_cli_settings_path
      ::File.join(::File.expand_path('~'), '.acdcli')
    end
  end

  class Provider < Chef::Provider
    include Poise
    include PoisePython::PythonCommandMixin
    include PoisePython::Resources::PythonPackage

    provides(:acd)

    def action_mount
      install_acd_cli
      oauth_data

      cmd = [
        'acd_cli',
        'mount',
        new_resource.mount_opts,
        new_resource.path,
      ]

      notifying_block do
        directory new_resource.path do
          recursive true
          user new_resource.user
          group new_resource.group
          mode 0775
        end
      end

      unless node['filesystem'].attribute?('ACDFuse') && node['filesystem']['ACDFuse']['mount'] == new_resource.path
        python_shell_out!(
          cmd,
          user: new_resource.user,
          group: new_resource.group,
          environment: (python_from_parent new_resource),
        )
      end
    end

    def action_unmount
      install_acd_cli

      cmd = [
        'acd_cli',
        'unmount',
        new_resource.path,
      ]

      python_shell_out!(
        cmd,
        user: new_resource.user,
        group: new_resource.group,
      )
    end

    def action_sync
      install_acd_cli

      cmd = [
        'acd_cli',
        'sync',
      ]

      python_shell_out!(
        cmd,
        user: new_resource.user,
        group: new_resource.group,
      )
    end

    private

    def install_acd_cli
      notifying_block do
        package %w{fuse}
      end

      python_package 'acd_cli' do
        python_from_parent new_resource
        name "#{ node['acd']['from_git'] ? 'git+https://github.com/yadayada/acd_cli.git' : 'acdcli' }"
        action [:install, :upgrade]
      end
    end


    # Create a new oauth_data if missing, or if the file is over one hour old.
    def oauth_data
      notifying_block do
        include_recipe 'build-essential'

        chef_gem 'mechanize' do
          compile_time true
        end

        oauth_data = Acd::OauthHandler.new(
          email: new_resource.amazon_email,
          password: new_resource.amazon_password,
        )
        oauth_data_file = ::File.join(new_resource.acd_cli_settings_path, 'oauth_data')

        directory new_resource.acd_cli_settings_path do
          mode 0750
          owner new_resource.user
          group new_resource.group
        end

        file oauth_data_file do
          content oauth_data.token.to_json
          mode 0640
          owner new_resource.user
          group new_resource.group
          sensitive true
          only_if do
            if ::File.exist?(oauth_data_file)
              (Time.now - File.stat(oauth_data_file)).to_i > 3600
            else
              true
            end
          end
        end
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
