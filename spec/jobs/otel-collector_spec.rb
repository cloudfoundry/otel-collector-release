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
    let(:properties) { { 'limits' => { 'memory_mib' => '512', 'cpu' => '1' } } }
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

      describe 'cpu' do
        context 'when not provided' do
          before do
            properties['limits'].delete('cpu')
          end

          it 'does not set GOMAXPROCS' do
            expect(rendered['processes'][0]['env']).not_to have_key('GOMAXPROCS')
          end
        end

        context 'when a custom cpu limit is provided' do
          before do
            properties['limits']['cpu'] = 2
          end

          it 'sets GOMAXPROCS' do
            expect(rendered['processes'][0]['env']['GOMAXPROCS']).to eq(2)
          end
        end
      end
    end

    describe 'inject_bosh_env' do
      context 'when inject_bosh_env is false (default)' do
        it 'does not set BOSH environment variables' do
          env = rendered['processes'][0]['env']
          expect(env.keys).not_to include(
            'BOSH_DEPLOYMENT', 'BOSH_NAME', 'BOSH_ID',
            'BOSH_INDEX', 'BOSH_AZ', 'BOSH_ADDRESS', 'BOSH_IP'
          )
        end
      end

      context 'when inject_bosh_env is true' do
        before do
          properties['inject_bosh_env'] = true
        end

        it 'injects all BOSH spec environment variables into BPM env' do
          env = rendered['processes'][0]['env']
          expect(env).to include(
            'BOSH_DEPLOYMENT' => 'my-deployment',
            'BOSH_NAME' => 'me',
            'BOSH_ID' => 'xxxxxx-xxxxxxxx-xxxxx',
            'BOSH_INDEX' => '0',
            'BOSH_AZ' => 'az1',
            'BOSH_ADDRESS' => 'my.bosh.com',
            'BOSH_IP' => '192.168.0.0'
          )
        end
      end
    end
  end
end
