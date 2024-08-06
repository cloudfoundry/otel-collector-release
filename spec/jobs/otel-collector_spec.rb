# frozen_string_literal: true

require 'rspec'
require 'bosh/template/test'
require 'support/shared_examples_for_otel_collector'

describe 'otel-collector' do
  let(:release_dir) { File.join(File.dirname(__FILE__), '../..') }
  let(:release) { Bosh::Template::Test::ReleaseDir.new(release_dir) }
  let(:job) { release.job('otel-collector') }
  let(:config_path) { '/var/vcap/jobs/otel-collector/config' }

  it_behaves_like 'common config.yml'

  describe 'config/bpm.yml' do
    let(:template) { job.template('config/bpm.yml') }
    let(:properties) { { 'limits' => { 'memory_mib' => '512' } } }
    let(:rendered) { YAML.safe_load(template.render(properties)) }

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
