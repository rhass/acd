# acd

This cookbook provides resources to install and configure acd_cli.

# WARNING

If you plan to use this for anything serious or production like, you are
absolutely crazy.

Using this cookbook could violate the terms of service for Amazon Drive.
By using this software you are accepting and assume Amazon will delete your
account, your data, or both. By using this software you accept the authors of
acd_cli, committers, and maintainers, of the upstream projet and this cookbook
are not responsible under any circumstances for any such violations,
repercussions of any kind for use or misuse of Amazon Drive, any data
corruption and/or data loss from using this cookbook or acd_cli.

## Usage

Include `acd` in your cookbooks metadata file, and make use of the acd provider:

## Resources

### acd
The `acd` resource installs and configures acd_cli. The oauth data is generated
using the Appspot application provided by the acd_cli author. For details and
to see the code please see the [authorization documentation from acd_cli](https://github.com/yadayada/acd_cli/blob/master/docs/authorization.rst).


#### Attributes

- `path`                  - Mount path. _Name Attribute_
- `amazon_email`          - E-Mail Address used for your Amazon Drive account. _Required_
- `amazon_password`       - Password for Amazaon Drive account. _Required_
- `mount_opts`            - acdcli mount options.
- `user`                  - User to use for acdcli commands and cache home dir . _Default: `root`_
- `group`                 - Group to use for acdcli commands. _Default: `root`_
- `acd_cli_cache_path`    - Custom cache directory path.
- `acd_cli_settings_path` - Custom settings path. _Default: ~/.cache/acd_cli_
- `version`               - Version of acd_cli to install from pypi. _Default: '0.3.2'_

#### Actions
- `:mount`
- `:unmount`
- `:sync`

#### Usage

```ruby
python_runtime 'acd' do
  provider :system
  version '3'
end

acd '/srv/acd' do
  amazon_email 'user@some.com'
  amazon_password 'my.password.which.should.be.retrieved.from.an.encrypted.data.bag'
  mount_opts %w{--allow-other}
  sensitive true # Always use this to ensure your credentials are hidden in a failure.
  action [:sync, :mount]
end
```
## License and Authors

Author:: Ryan Hass (<ryan@invalidchecksum.net>)

Copyright (c) 2016, Ryan Hass

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
