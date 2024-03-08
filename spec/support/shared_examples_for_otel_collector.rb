# frozen_string_literal: true

require 'rspec'
require 'bosh/template/test'
require 'yaml'

shared_examples_for 'common config.yml' do
  describe 'config/config.yml' do
    let(:template) { job.template('config/config.yml') }
    let(:trace_exporters) { { 'otlp/traces' => { 'endpoint' => 'otelcol:4317' } } }
    let(:metric_exporters) do
      {
        'otlp' => { 'endpoint' => 'otelcol:4317' },
        'prometheus/tls' => {
          'endpoint' => '1.2.3.4:1234',
          'metric_expiration' => '60m'
        }
      }
    end
    let(:properties) do
      {
        'metric_exporters' => metric_exporters,
        'trace_exporters' => trace_exporters
      }
    end
    let(:rendered) { YAML.load(template.render(properties)) }

    describe 'exporters' do
      let(:exporters) { rendered['exporters'] }

      it 'has the right number of exporters' do
        expect(exporters.count).to eq(3)
      end

      context 'when an exporter has a name collision' do
        let(:trace_exporters) { { 'otlp' => { 'endpoint' => 'otelcol:4317' } } }
        it 'raises an error' do
          expect { rendered }.to raise_error(/Exporter names must be unique/)
        end
      end

      describe 'trace exporters' do
        it 'puts the trace exporters in the traces pipeline' do
          expect(rendered['service']['pipelines']['traces']).to eq({ 'exporters' => ['otlp/traces'], 'receivers' => ['otlp'] })
        end

        context 'when exporters is a string and not a hash' do
          let(:trace_exporters) { "{otlp/traces: {endpoint: 'otelcol:4317'}}" }
          it 'parses it as YAML' do
            expect(rendered['service']['pipelines']['traces']).to eq({ 'exporters' => ['otlp/traces'], 'receivers' => ['otlp'] })
          end
        end

        context 'when an exporter uses the reserved namespace' do
          let(:trace_exporters) { { 'otlp/cf-internal-foo' => { 'endpoint' => 'otelcol:4317' } } }
          it 'raises an error' do
            expect { rendered }.to raise_error(/Exporters cannot be defined under cf-internal namespace/)
          end
        end

        context 'when trace exporters is empty' do
          let(:trace_exporters) { {} }
          it 'does not create a trace pipeline, which would cause otel-collector to error' do
            expect(rendered['service']['pipelines']['traces']).to be_nil
          end
        end
      end

      describe 'metric exporters' do
        it 'puts the metric exporters in the metrics pipeline' do
          expect(rendered['service']['pipelines']['metrics']).to eq({ 'exporters' => ['otlp', 'prometheus/tls'], 'receivers' => ['otlp'] })
        end

        context 'when exporters is a string and not a hash' do
          let(:metric_exporters) { "{otlp/metrics: {endpoint: 'otelcol:4317'}}" }
          it 'parses it as YAML' do
            expect(rendered['service']['pipelines']['metrics']).to eq({ 'exporters' => ['otlp/metrics'], 'receivers' => ['otlp'] })
          end
        end

        context 'when there is a prometheus exporter listening on 8889' do
          let(:metric_exporters) do
            {
              'prometheus/tls' => {
                'endpoint' => '1.2.3.4:8889',
                'metric_expiration' => '60m'
              }
            }
          end

          it 'raises an error' do
            expect { rendered }.to raise_error(/Cannot define prometheus exporter listening on port 8889/)
          end
        end

        context 'when an exporter uses the reserved namespace' do
          let(:metric_exporters) { { 'otlp/cf-internal-foo' => { 'endpoint' => 'otelcol:4317' } } }
          it 'raises an error' do
            expect { rendered }.to raise_error(/Exporters cannot be defined under cf-internal namespace/)
          end
        end

        context 'when metric exporters is empty' do
          let(:metric_exporters) { {} }
          it 'does not create a metric pipeline, which would cause otel-collector to error' do
            expect(rendered['service']['pipelines']['metrics']).to be_nil
          end
        end
      end
    end

    context 'receivers' do
      let(:receivers) { rendered['receivers'] }

      it 'only has one receiver' do
        expect(receivers.count).to eq(1)
      end

      context 'otlpreceiver' do
        let(:otlpreceiver) { rendered['receivers']['otlp'] }

        it 'is configured by default' do
          expect(otlpreceiver).to eq(
            {
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
            }
          )
        end

        context 'when ingress.grpc.port is set' do
          let(:properties) { { 'ingress' => { 'grpc' => { 'port' => 1234 } } } }

          it 'has an endpoint with that port' do
            expect(otlpreceiver['protocols']['grpc']['endpoint']).to eq('127.0.0.1:1234')
          end
        end

        context 'when ingress.grpc.listen_address is set' do
          let(:properties) { { 'ingress' => { 'grpc' => { 'address' => '0.0.0.0' } } } }

          it 'has an endpoint with that address' do
            expect(otlpreceiver['protocols']['grpc']['endpoint']).to eq('0.0.0.0:9100')
          end
        end
      end
    end
  end
end
