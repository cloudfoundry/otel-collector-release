# frozen_string_literal: true

require 'rspec'
require 'bosh/template/test'
require 'yaml'

shared_examples_for 'common config.yml' do
  describe 'config/config.yml' do
    let(:template) { job.template('config/config.yml') }
    let(:properties) {
      {
        'metric_exporters' => {
          'otlp' => {'endpoint' => 'otelcol:4317'},
          'prometheus/tls' => {
            'endpoint' => '1.2.3.4:1234',
            'metric_expiration' => '60m'
          }
        }
      }
    }
    let(:rendered) { YAML.load(template.render(properties)) }

    context 'receivers' do
      let(:receivers) { rendered["receivers"] }

      it 'only has one receiver' do
        expect(receivers.count).to eq(1)
      end

      context 'otlpreceiver' do
        let(:otlpreceiver) { rendered["receivers"]['otlp'] }

        it 'is configured by default' do
          expect(otlpreceiver).to eq({
            'protocols' => {
              'grpc' => {
                'endpoint' => '127.0.0.1:9100',
                'tls' => {
                  'client_ca_file' => "#{config_path}/certs/otel-collector-ca.crt",
                  'cert_file' => "#{config_path}/certs/otel-collector.crt",
                  'key_file' => "#{config_path}/certs/otel-collector.key",
                  'min_version' => '1.3'
                }
              }
            }
          })
        end

        context 'when ingress.grpc.port is set' do
          let(:properties) { {'ingress' => {'grpc' => {'port' => 1234}}} }

          it 'has an endpoint with that port' do
            expect(otlpreceiver['protocols']['grpc']['endpoint']).to eq('127.0.0.1:1234')
          end
        end
      end
    end
  end
end
