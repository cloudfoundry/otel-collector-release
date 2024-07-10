# frozen_string_literal: true

require 'rspec'
require 'bosh/template/test'
require 'support/shared_examples_for_otel_collector'

describe 'otel-collector-windows' do
  let(:release_dir) { File.join(File.dirname(__FILE__), '../..') }
  let(:release) { Bosh::Template::Test::ReleaseDir.new(release_dir) }
  let(:job) { release.job('otel-collector-windows') }
  let(:config_path) { '/var/vcap/jobs/otel-collector-windows/config' }

  it_behaves_like 'common config.yml'

  describe 'spec' do
    it 'has only the specified differences from the linux spec' do
      windows_spec = YAML.safe_load(File.read(File.join(release_dir, 'jobs', 'otel-collector-windows', 'spec')))
      linux_spec = YAML.safe_load(File.read(File.join(release_dir, 'jobs', 'otel-collector', 'spec')))

      windows_spec['name'] = 'otel-collector'
      windows_spec['packages'] = ['otel-collector']
      windows_spec['templates'].merge!({ 'bpm.yml.erb' => 'config/bpm.yml' })

      expect(windows_spec).to eq(linux_spec)
    end
  end

  describe 'config.yml' do
    it 'has only the specified differences from the linux config' do
      windows_config = File.read(File.join(release_dir, 'jobs', 'otel-collector-windows', 'templates', 'config.yml.erb'))
      linux_config = File.read(File.join(release_dir, 'jobs', 'otel-collector', 'templates', 'config.yml.erb'))

      windows_config.gsub!('/var/vcap/jobs/otel-collector-windows/', '/var/vcap/jobs/otel-collector/')

      expect(windows_config).to eq(linux_config)
    end
  end
end
