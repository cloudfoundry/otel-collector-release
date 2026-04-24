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

  describe 'config/config.yml' do
    let(:template) { job.template('config/config.yml') }

    context('when no TLS properties are provided for the grpc exporter') do
      let(:properties) do
        {
          'config' => {
            'exporters' => {
              'otlp_grpc' => { 'endpoint' => 'otelcol:4317' },
            },
            'service' => {
              'pipelines' => {
                'metrics' => {
                  'exporters' => ['otlp_grpc']
                }
              }
            }
          },
        }
      end
      let(:rendered) { YAML.safe_load(template.render(properties)) }

      it 'renders the otlp grpc endpoint without tls certificates' do
        expect(rendered['exporters']['otlp_grpc']['endpoint']).to eq('otelcol:4317')
        expect(rendered.dig('exporters', 'otlp_grpc', 'tls', 'ca_file')).to be_nil
        expect(rendered.dig('exporters', 'otlp_grpc', 'tls', 'cert_file')).to be_nil
        expect(rendered.dig('exporters', 'otlp_grpc', 'tls', 'key_file')).to be_nil
      end
    end

    context('when TLS properties are provided for the grpc exporter') do
      let(:properties) do
        {
          'config' => {
            'exporters' => {
              'otlp_grpc' => { 'endpoint' => 'otelcol:4317' },
            },
            'service' => {
              'pipelines' => {
                'metrics' => {
                  'exporters' => ['otlp_grpc']
                }
              }
            }
          },
          'exporter' => {
            'grpc' => {
              'tls' => {
                'ca_cert' => 'dummy-ca',
                'cert' => 'dummy-public-cert',
                'key' => 'dummy-private-key',
              }
            }
          }
        }
      end
      let(:rendered) { YAML.safe_load(template.render(properties)) }

      it 'adds tls file paths to the otlp_grpc exporter' do
        expect(rendered['exporters']['otlp_grpc']['endpoint']).to eq('otelcol:4317')
        expect(rendered['exporters']['otlp_grpc']['tls']).to eq(
                                                               'ca_file' => "#{config_path}/certs/otel-collector-exporter-ca.crt",
                                                               'cert_file' => "#{config_path}/certs/otel-collector-exporter.crt",
                                                               'key_file' => "#{config_path}/certs/otel-collector-exporter.key"
                                                             )
      end

      context('when exporter tls settings already exist in the config') do
        before do
          properties['config']['exporters']['otlp_grpc']['tls'] = {
            'ca_file' => '/custom/ca.crt',
            'cert_file' => '/custom/cert.crt',
            'key_file' => '/custom/key.key',
            'insecure' => false,
          }
        end

        it 'preserves existing tls settings' do
          expect(rendered['exporters']['otlp_grpc']['tls']).to eq(
            'ca_file' => '/custom/ca.crt',
            'cert_file' => '/custom/cert.crt',
            'key_file' => '/custom/key.key',
            'insecure' => false,
          )
        end
      end
    end
  end

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
  end
end
