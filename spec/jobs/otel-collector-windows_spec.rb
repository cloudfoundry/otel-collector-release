# frozen_string_literal: true

require 'rspec'
require 'bosh/template/test'
require 'support/shared_examples_for_otel_collector'
require 'json'

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

  describe 'monit' do
    let(:spec) { job.instance_variable_get(:@spec) }
    let(:job_path) { job.instance_variable_get(:@job_path) }
    let(:template) { Bosh::Template::Test::Template.new(spec, File.join(job_path, 'monit')) }
    let(:properties) { { 'limits' => { 'memory_mib' => '512' } } }
    let(:rendered) { JSON.load(template.render(properties)) }

    describe 'limits' do
      describe 'memory' do
        context 'when not provided' do
          before do
            properties['limits'].delete('memory_mib')
          end

          it 'uses the default job values in bpm' do
            expect(rendered['processes'][0]['limits']['memory']).to eq('512MiB')
            expect(rendered['processes'][0]['env']['GOMEMLIMIT']).to eq('409MiB')
          end
        end

        context 'when a custom memory limit is provided' do
          before do
            properties['limits']['memory_mib'] = '1000'
          end

          it 'sets the bpm memory limit and GOMEMLIMIT' do
            expect(rendered['processes'][0]['limits']['memory']).to eq('1000MiB')
            expect(rendered['processes'][0]['env']['GOMEMLIMIT']).to eq('800MiB')
          end
        end
      end
    end
  end
end
