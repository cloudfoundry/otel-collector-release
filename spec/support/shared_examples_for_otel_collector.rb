# frozen_string_literal: true

require 'rspec'
require 'bosh/template/test'
require 'yaml'

shared_examples_for 'common config.yml' do
  describe 'config/config.yml' do
    let(:template) { job.template('config/config.yml') }
    let(:config) do
      {
        'receivers' => {
          'otlp/placeholder' => nil
        },
        'processors' => {
          'batch' => nil
        },
        'exporters' => {
          'otlp' => {
            'endpoint' => 'otelcol:4317'
          }
        },
        'extensions' => {
          'pprof' => nil,
          'zpages' => nil
        },
        'service' => {
          'extensions' => %w[pprof zpages],
          'pipelines' => {
            'traces' => {
              'receivers' => ['otlp/placeholder'],
              'processors' => ['batch'],
              'exporters' => ['otlp']
            },
            'metrics' => {
              'receivers' => ['otlp/placeholder'],
              'processors' => ['batch'],
              'exporters' => ['otlp']
            }
          }
        }
      }
    end
    let(:properties) { { 'config' => config } }
    let(:rendered) { YAML.safe_load(template.render(properties)) }

    context 'when the config is provided as a string, not a hash' do
      let(:string_config) { YAML.dump(config) }
      let(:rendered) { YAML.safe_load(template.render({ 'config' => string_config })) }

      def without_receivers(cfg)
        cfg.delete('receivers')
        cfg['service']['pipelines']['metrics'].delete('receivers')
        cfg['service']['pipelines']['traces'].delete('receivers')
        cfg
      end

      def without_internal_telemetry(cfg)
        cfg.tap { |c| c['service'].delete('telemetry') }
      end

      it 'uses the config provided and parses it as YAML' do
        expect(without_internal_telemetry(without_receivers(rendered))).to eq(
          without_internal_telemetry(without_receivers(config))
        )
      end
    end

    context 'when only minimal valid config is provided' do
      before do
        config.delete('receivers')
        config.delete('processors')
        config.delete('extensions')
      end

      it 'renders successfully' do
        expect(rendered.keys).to contain_exactly('receivers', 'exporters', 'service')
      end
    end

    context 'receivers' do
      let(:receivers) { rendered['receivers'] }

      it 'removes any receiver that the operator provided to keep the config well-formed' do
        expect(receivers.keys).to_not include 'otlp/placeholder'
      end

      context 'when the operator provides a real receiver' do
        before do
          config['receivers']['otlp/some-receiver'] = {
            'protocols' => {
              'grpc' => {
                'endpoint' => '0.0.0.0:2345'
              },
              'http' => {
                'endpoint' => '0.0.0.0:3456'
              }
            }
          }
        end

        it 'is ignored' do
          expect(rendered['receivers'].keys).to_not include 'otlp/some-receiver'
        end
      end

      context 'built-in otlp receiver' do
        let(:builtin_otlp_receiver) { rendered['receivers']['otlp/cf-internal-local'] }

        it 'is configured by default' do
          expect(builtin_otlp_receiver).to eq(
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

        context 'when multiple pipelines exist' do
          before do
            config['service']['pipelines'] = {
              'traces' => {
                'receivers' => ['otlp/placeholder'],
                'processors' => ['batch'],
                'exporters' => ['otlp']
              },
              'traces/2' => {
                'receivers' => ['otlp/placeholder'],
                'processors' => ['batch/test'],
                'exporters' => ['otlp/2']
              },
              'metrics' => {
                'receivers' => ['otlp/placeholder'],
                'processors' => ['batch'],
                'exporters' => ['otlp']
              },
              'metrics/foo' => {
                'receivers' => ['otlp/placeholder'],
                'processors' => ['batch'],
                'exporters' => ['otlp']
              }
            }
          end

          it 'includes only the built-in receiver in every pipeline' do
            expect(rendered['service']['pipelines']['traces']['receivers']).to eq(['otlp/cf-internal-local'])
            expect(rendered['service']['pipelines']['traces/2']['receivers']).to eq(['otlp/cf-internal-local'])
            expect(rendered['service']['pipelines']['metrics']['receivers']).to eq(['otlp/cf-internal-local'])
            expect(rendered['service']['pipelines']['metrics/foo']['receivers']).to eq(['otlp/cf-internal-local'])
          end
        end

        context 'when ingress.grpc.port is set' do
          before do
            properties['ingress'] = { 'grpc' => { 'port' => 1234 } }
          end

          it 'has an endpoint with that port' do
            expect(builtin_otlp_receiver['protocols']['grpc']['endpoint']).to eq('127.0.0.1:1234')
          end
        end

        context 'when ingress.grpc.listen_address is set' do
          before do
            properties['ingress'] = { 'grpc' => { 'address' => '0.0.0.0' } }
          end

          it 'has an endpoint with that address' do
            expect(builtin_otlp_receiver['protocols']['grpc']['endpoint']).to eq('0.0.0.0:9100')
          end
        end
      end
    end

    describe 'processors' do
      it 'list of available processors matches builder source of truth' do
        config['processors']['unavailable'] = nil

        builder_config = YAML.load_file(File.join(release_dir, "src/otel-collector-builder/config.yaml"))
        processor_gomods = builder_config.fetch('processors').map {|entry| entry.fetch('gomod').split(" ")[0]}
        processor_names = processor_gomods.map do |gomod|
          YAML.load_file(File.join(release_dir, "src/otel-collector/vendor", gomod, "metadata.yaml")).fetch('type')
        end
        formatted_names = processor_names.sort.map {|name| "\"#{name}\"" }.join(", ")

        expect { rendered }.to raise_error do |error|
          expect(error.message).to include("Available: [#{formatted_names}]")
        end
      end

      it 'includes the configured processors in the config' do
        expect(rendered.keys).to include 'processors'
        expect(rendered['processors']).to eq(config['processors'])
      end

      it 'includes the configured processors even if their names contain `/`' do
        config['processors']['batch/bar'] = nil
        expect(rendered.keys).to include 'processors'
        expect(rendered['processors']).to eq(config['processors'])
      end

      context 'when a processor uses the reserved namespace' do
        before do
          config['processors']['batch/cf-internal-foo'] = nil
        end

        it 'raises an error' do
          expect { rendered }.to raise_error(/Processors cannot be defined under cf-internal namespace/)
        end
      end

      it 'errors when a configured processor is not allowed' do
        properties['allow_list'] = {'processors' => ['memory_limiter']}
        expect { rendered }.to raise_error(/The following configured processors are not allowed: \["batch"\]/)
      end

      it 'allows all processors with empty allow list' do
        properties['allow_list'] = {'processors' => [] }
        expect(rendered.keys).to include 'processors'
        expect(rendered['processors']).to eq(config['processors'])
      end

      it 'errors when an unrecognized processor is in allow list' do
        properties['allow_list'] = {'processors' => ['memory_limiter', 'unrecognized-processor']}
        expect { rendered }.to raise_error(/The following processors specified in the allow list are not included in this OpenTelemetry Collector distribution: \["unrecognized-processor"\]/)
      end

      it 'errors when an unavailable processor is configured' do
        config['processors']['unavailable'] = nil
        expect { rendered }.to raise_error(/The following configured processors are not included in this OpenTelemetry Collector distribution: \["unavailable"\]/)
      end
    end

    describe 'exporters' do
      it 'list of available exporters matches builder source of truth' do
        config['exporters']['unavailable'] = nil

        builder_config = YAML.load_file(File.join(release_dir, "src/otel-collector-builder/config.yaml"))
        exporter_gomods = builder_config.fetch('exporters').map {|entry| entry.fetch('gomod').split(" ")[0]}
        exporter_names = exporter_gomods.map do |gomod|
          YAML.load_file(File.join(release_dir, "src/otel-collector/vendor", gomod, "metadata.yaml")).fetch('type')
        end
        formatted_names = exporter_names.sort.map {|name| "\"#{name}\"" }.join(", ")

        expect { rendered }.to raise_error do |error|
          expect(error.message).to include("Available: [#{formatted_names}]")
        end
      end

      it 'includes the configured exporters in the config' do
        expect(rendered.keys).to include 'exporters'
        expect(rendered['exporters']).to eq(config['exporters'])
      end

      it 'errors when a configured exporters is not allowed' do
        properties['allow_list'] = {'exporters' => ['prometheus']}
        expect { rendered }.to raise_error(/The following configured exporters are not allowed: \["otlp"\]/)
      end

      it 'allows all exporters with empty allow list' do
        properties['allow_list'] = {'exporters' => []}
        expect(rendered.keys).to include 'exporters'
        expect(rendered['exporters']).to eq(config['exporters'])
      end

      it 'includes the configured exporters even if their names contain `/`' do
        config['exporters']['otlp/bar'] = nil
        expect(rendered.keys).to include 'exporters'
        expect(rendered['exporters']).to eq(config['exporters'])
      end

      context 'when unsupported exporter is provided' do
        it 'raises unrecognized exporter error' do
          properties['allow_list'] = {'exporters' => ['unrecognized-exporter']}
          expect { rendered }.to raise_error(/The following exporters specified in the allow list are not included in this OpenTelemetry Collector distribution/)
        end
        it 'raises not allowed error' do
          config['exporters']['another-unrecognized-exporter/bar'] = nil
          expect { rendered }.to raise_error(/The following configured exporters are not included in this OpenTelemetry Collector distribution/)
        end
      end

      context 'when there is a prometheus exporter listening on 8889' do
        before do
          config['exporters']['prometheus/tls'] = {
            'endpoint' => '203.0.113.10:8889',
            'metric_expiration' => '60m'
          }
        end

        it 'raises an error' do
          expect { rendered }.to raise_error(/Cannot define prometheus exporter listening on port 8889/)
        end
      end

      context 'when an exporter uses the reserved namespace' do
        before do
          config['exporters']['otlp/cf-internal-foo'] = {
            'endpoint' => '203.0.113.10:4317'
          }
        end
        it 'raises an error' do
          expect { rendered }.to raise_error(/Exporters cannot be defined under cf-internal namespace/)
        end
      end
    end

    describe 'extensions' do
      context 'when extensions are specified' do
        it 'includes the configured extensions in the config' do
          expect(rendered.keys).to include 'extensions'
          expect(rendered['extensions']).to eq(config['extensions'])
        end
      end
    end

    describe 'internal telemetry' do
      it 'exposes telemetry at the default port' do
        expect(rendered['service']['telemetry']['metrics']['address']).to eq('127.0.0.1:14830')
      end
      it 'provides basic level metrics by default' do
        expect(rendered['service']['telemetry']['metrics']['level']).to eq('basic')
      end

      context 'when the port is specified' do
        let(:properties) { { 'config' => config, 'telemetry' => { 'metrics' => { 'port' => 14_831 } } } }
        it 'exposes telemetry at the specified port' do
          expect(rendered['service']['telemetry']['metrics']['address']).to eq('127.0.0.1:14831')
        end
      end

      context 'when the metrics level is specified' do
        let(:properties) { { 'config' => config, 'telemetry' => { 'metrics' => { 'level' => 'detailed' } } } }
        it 'applies the telemetry metrics level' do
          expect(rendered['service']['telemetry']['metrics']['level']).to eq('detailed')
        end
      end
    end

    describe 'invalid config' do
      context 'when the config does not provide exporters' do
        before do
          config.delete('exporters')
        end
        it 'errors' do
          expect { rendered }.to raise_error(/Exporter configuration must be provided/)
        end
      end
      context 'when the config has the exporters key but no value' do
        before do
          config['exporters'] = nil
        end
        it 'errors' do
          expect { rendered }.to raise_error(/Exporter configuration must be provided/)
        end
      end
      context 'when the config does not provide a service section' do
        before do
          config.delete('service')
        end
        it 'errors' do
          expect { rendered }.to raise_error(/Service configuration must be provided/)
        end
      end
    end

    context 'when disabled and no other config properties are provided' do
      let(:properties) { { 'enabled' => false } }

      it "doesn't raise an error" do
        expect { rendered }.to_not raise_error
      end
    end

    context 'when the older config properties are provided' do
      let(:properties) do
        {
          'metric_exporters' => {
            'otlp' => { 'endpoint' => 'otelcol:4317' },
            'prometheus/tls' => {
              'endpoint' => '1.2.3.4:1234',
              'metric_expiration' => '60m'
            }
          },
          'trace_exporters' => {
            'otlp/traces' => { 'endpoint' => 'otelcol:4317' }
          }
        }
      end

      it 'uses the exporters provided' do
        expect(rendered['exporters']).to eq(
          {
            'otlp' => { 'endpoint' => 'otelcol:4317' },
            'prometheus/tls' => {
              'endpoint' => '1.2.3.4:1234',
              'metric_expiration' => '60m'
            },
            'otlp/traces' => { 'endpoint' => 'otelcol:4317' }
          }
        )
      end

      it 'generates pipelines that include the exporters' do
        metrics_pipeline = rendered['service']['pipelines']['metrics']
        expect(metrics_pipeline['receivers']).to eq(['otlp/cf-internal-local'])
        expect(metrics_pipeline['exporters']).to eq(['otlp', 'prometheus/tls'])

        traces_pipeline = rendered['service']['pipelines']['traces']
        expect(traces_pipeline['receivers']).to eq(['otlp/cf-internal-local'])
        expect(traces_pipeline['exporters']).to eq(['otlp/traces'])
      end

      context 'when only a metrics pipeline is defined' do
        before do
          properties.delete('trace_exporters')
        end
        it 'does not generate a traces pipeline' do
          expect(rendered['service']['pipelines'].keys).to_not include 'traces'
        end
      end

      context 'when only a traces pipeline is defined' do
        before do
          properties.delete('metric_exporters')
        end
        it 'does not generate a metrics pipeline' do
          expect(rendered['service']['pipelines'].keys).to_not include 'metrics'
        end
      end

      context 'when an exporter has a name collision' do
        before do
          properties['trace_exporters'] = { 'otlp' => { 'endpoint' => 'otelcol:4317' } }
        end

        it 'raises an error' do
          expect { rendered }.to raise_error(/Exporter names must be unique/)
        end
      end

      context 'when trace_exporters is a string and not a hash' do
        before do
          properties['trace_exporters'] = YAML.dump(properties['trace_exporters'])
        end

        it 'parses it as YAML' do
          expect(rendered['service']['pipelines']['traces']).to eq({ 'exporters' => ['otlp/traces'],
                                                                     'receivers' => ['otlp/cf-internal-local'] })
        end
      end

      describe 'and a normal configuration is also provided' do
        before do
          properties['config'] = { 'some' => 'configuration' }
        end

        it 'raises an error' do
          expect do
            rendered
          end.to raise_error(/Can not provide 'config' property when deprecated 'metric_exporters' or 'trace_exporters' properties are provided/)
        end
      end
    end
  end
end
