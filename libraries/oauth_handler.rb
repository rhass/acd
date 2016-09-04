#
# Cookbook Name:: acd
# Library:: oauth_handler
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

module Acd
  class OauthHandler
    require 'json'

    attr_reader :token

    def initialize(args = {})
      # We must require the gem within the initializer otherwise Chef will
      # attempt to evalute and load the class dependencies before we can
      # install them on the box. Since mechanize does native compilation at
      # install-time, we also need to drop build-essential before the gem is
      # installed which prevents us from being able to add the gem as a
      # dependency in the cookbook metadata file.
      require 'mechanize'
      @email ||= args[:email]
      @password ||= args[:password]
      @oauth_endpoint ||= args[:oauth_endpoint]
      @token ||= authenticate
    end

    private

    # This has way to much responsiblity. I originally wrote it in as very
    # small methods, but had some weird side-effects with Mechanize where it
    # the mechanize agent seemed to think I pressed a "back" button in the 
    # browser.
    # Note: If you fail to authenticate too many times -- Amazon tries to
    # somewaht intelligently block the specific User Agent from the requesting IP
    # to prevent brute force attacks. Clearing cookies does nothing to stop it,
    # however simply changing the UA alias seems to work around it for some
    # reason.
    def authenticate
      agent = Mechanize.new
      agent.cookie_jar.clear!
      agent.user_agent_alias="Windows Firefox"
      agent.follow_meta_refresh = true
      agent.redirect_ok = true

      page = agent.get(@oauth_endpoint)
      form = page.form(name: 'signIn')
      form.field(name: 'email').value = @email
      form.field(name: 'password').value = @password
      page2 = agent.submit(form)

      if !page2.form(name: 'consent-form').nil?
        raise "Automatic Amazon app authorization consent is not yet supported.\nPlease login to #{@oauth_endpoint} and authorize the Amazon application access to your drive before running this cookbook."
      end

      response_page = page2

      begin
        response = JSON.parse(response_page.body)
        raise response['error_decription'] if response.has_key?('error')
      rescue JSON::ParserError
        puts response_page.body
        raise 'Invalid amazon.com credentials or unexpected response from server.'
      end

      response
    end

  end
end
