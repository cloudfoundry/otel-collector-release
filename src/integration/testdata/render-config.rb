# frozen_string_literal: true

require 'erb'
require 'bosh/template/test'
require 'yaml'

release_dir = File.expand_path('../../..', __dir__)
release = Bosh::Template::Test::ReleaseDir.new(release_dir)
properties = YAML.safe_load($stdin.read)
print release.job(ARGV.fetch(0)).template('config/config.yml').render(properties)
