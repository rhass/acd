name 'acd'
maintainer 'Ryan Hass'
maintainer_email 'ryan@invalidchecksum.net'
license 'apachev2'
description 'Installs/Configures acd'
long_description 'Installs/Configures acd'
version '0.1.0'

issues_url 'https://github.com/rhass/acd/issues' if respond_to?(:issues_url)
source_url 'https://github.com/rhass/acd' if respond_to?(:source_url)

depends 'build-essential'
depends 'poise'
depends 'poise-python'

chef_version '>= 12.8.1'
