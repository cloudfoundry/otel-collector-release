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
    let(:properties) { { 'limits' => { 'memory' => '1G' } } }
    let(:rendered) { YAML.safe_load(template.render(properties)) }

    describe 'limits' do
      context 'when no limits are provided' do
        before do
          properties.delete('limits')
        end

        it 'is not set in bpm' do
          expect(rendered['processes'][0].keys).to_not include 'limits'
        end
      end

      describe 'memory' do
        context 'when not provided' do
          before do
            properties['limits'].delete('memory')
          end

          it 'is not set in bpm' do
            expect(rendered['processes'][0]).to_not include 'limits'
          end
        end

        context 'when a valid memory limit is provided' do
          before do
            properties['limits']['memory'] = '1G'
          end

          it 'sets the bpm memory limit' do
            expect(rendered['processes'][0]['limits']['memory']).to eq('1G')
          end
        end
      end
    end
  end
end
