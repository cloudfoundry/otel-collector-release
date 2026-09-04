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
          'otlp_grpc' => {
            'endpoint' => 'otelcol:4317'
          }
        },
        'extensions' => {
          'pprof' => nil,
        },
        'service' => {
          'extensions' => %w[pprof],
          'pipelines' => {
            'traces' => {
              'receivers' => ['otlp/placeholder'],
              'processors' => ['batch'],
              'exporters' => ['otlp_grpc']
            },
            'metrics' => {
              'receivers' => ['otlp/placeholder'],
              'processors' => ['batch'],
              'exporters' => ['otlp_grpc']
            },
            'logs' => {
              'receivers' => ['otlp/placeholder'],
              'processors' => ['batch'],
              'exporters' => ['otlp_grpc']
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
        cfg['service']['pipelines']['logs'].delete('receivers')
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

    describe 'adding nop pipelines so forwarder agent doesnt log errors for unaccepted signals' do
      describe "traces" do
        context "when there is no traces pipeline" do
          before do
            config['service']['pipelines'].delete('traces')
          end

          it "adds a noop metrics pipeline" do
            expect(rendered['service']['pipelines']['traces']).to eq(
              'receivers' => ['otlp/cf-internal-local'],
              'processors' => nil,
              'exporters' => ['nop'])

            expect(rendered['exporters'].keys).to include('nop')
          end
        end

        context "when there is already a traces pipeline" do
          before do
            config['service']['pipelines'].delete('traces')
            config['service']['pipelines']['traces/foo'] = {
              'traces' => {
                'receivers' => ['otlp/placeholder'],
                'processors' => ['batch'],
                'exporters' => ['otlp_grpc']
              }
            }
          end

          it "not does add a nop traces pipeline" do
            expect(rendered['service']['pipelines']['traces']).to eq(nil)

            expect(rendered['exporters'].keys).not_to include('nop')
          end
        end
      end

      describe "logs" do
        context "when there is no logs pipeline" do
          before do
            config['service']['pipelines'].delete('logs')
          end

          it "adds a noop logs pipeline" do
            expect(rendered['service']['pipelines']['logs']).to eq(
              'receivers' => ['otlp/cf-internal-local'],
              'processors' => nil,
              'exporters' => ['nop'])

            expect(rendered['exporters'].keys).to include('nop')
          end
        end

        context "when there is already a logs pipeline" do
          before do
            config['service']['pipelines'].delete('logs')
            config['service']['pipelines']['logs/bar'] = {
              'traces' => {
                'receivers' => ['otlp/placeholder'],
                'processors' => ['batch'],
                'exporters' => ['otlp_grpc']
              }
            }
          end

          it "not does add a nop traces pipeline" do
            expect(rendered['service']['pipelines']['logs']).to eq(nil)

            expect(rendered['exporters'].keys).not_to include('nop')
          end
        end
      end

      describe "metrics" do
        context "when there is no metrics pipeline" do
          before do
            config['service']['pipelines'].delete('metrics')
          end

          it "adds a noop metrics pipeline" do
            expect(rendered['service']['pipelines']['metrics']).to eq(
              'receivers' => ['otlp/cf-internal-local'],
              'processors' => nil,
              'exporters' => ['nop'])

            expect(rendered['exporters'].keys).to include('nop')
          end
        end
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
                'exporters' => ['otlp_grpc']
              },
              'traces/2' => {
                'receivers' => ['otlp/placeholder'],
                'processors' => ['batch/test'],
                'exporters' => ['otlp_grpc/2']
              },
              'metrics' => {
                'receivers' => ['otlp/placeholder'],
                'processors' => ['batch'],
                'exporters' => ['otlp_grpc']
              },
              'metrics/foo' => {
                'receivers' => ['otlp/placeholder'],
                'processors' => ['batch'],
                'exporters' => ['otlp_grpc']
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

        context 'when a pipeline is fed by a connector' do
          before do
            config['connectors'] = { 'routing' => nil }
            config['service']['pipelines'] = {
              # real ingress: exports into the connector
              'metrics/router-inbound' => {
                'receivers' => ['otlp/placeholder'],
                'exporters' => ['routing']
              },
              # connector-fed downstream pipelines
              'metrics/team-a' => {
                'receivers' => ['routing'],
                'exporters' => ['otlp_grpc']
              },
              'metrics/team-b' => {
                'receivers' => ['routing/2'],
                'exporters' => ['otlp_grpc']
              },
              # mixed: operator receiver alongside the connector
              'metrics/mixed' => {
                'receivers' => ['otlp/placeholder', 'routing'],
                'exporters' => ['otlp_grpc']
              }
            }
          end

          it 'forces the internal receiver on the ingress pipeline' do
            expect(rendered['service']['pipelines']['metrics/router-inbound']['receivers']).to eq(['otlp/cf-internal-local'])
          end

          it 'preserves connector-fed receivers so the connector stays consumed' do
            expect(rendered['service']['pipelines']['metrics/team-a']['receivers']).to eq(['routing'])
            expect(rendered['service']['pipelines']['metrics/team-b']['receivers']).to eq(['routing/2'])
          end

          it 'keeps the connector receiver but forces the internal receiver on a mixed pipeline' do
            expect(rendered['service']['pipelines']['metrics/mixed']['receivers']).to eq(['routing', 'otlp/cf-internal-local'])
          end

          it 'still forces the internal receiver on injected nop pipelines' do
            expect(rendered['service']['pipelines']['traces']['receivers']).to eq(['otlp/cf-internal-local'])
            expect(rendered['service']['pipelines']['logs']['receivers']).to eq(['otlp/cf-internal-local'])
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

      it 'allows no processors with empty allow list' do
        properties['allow_list'] = {'processors' => [] }
        expect { rendered }.to raise_error(/The following configured processors are not allowed: \["batch"\]/)
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
        exporter_names = exporter_gomods.flat_map do |gomod|
          metadata = YAML.load_file(File.join(release_dir, "src/otel-collector/vendor", gomod, "metadata.yaml"))
          metadata.values_at('type', 'deprecated_type').compact
        end

        formatted_names = exporter_names.sort.map { |name| "\"#{name}\"" }.join(", ")
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
        expect { rendered }.to raise_error(/The following configured exporters are not allowed: \["otlp_grpc"\]/)
      end

      it 'allows no exporters with empty allow list' do
        properties['allow_list'] = {'exporters' => []}
        expect { rendered }.to raise_error(/The following configured exporters are not allowed: \["otlp_grpc"\]/)
      end

      it 'includes the configured exporters even if their names contain `/`' do
        config['exporters']['otlp_grpc/bar'] = nil
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
          config['exporters']['otlp_grpc/cf-internal-foo'] = {
            'endpoint' => '203.0.113.10:4317'
          }
        end
        it 'raises an error' do
          expect { rendered }.to raise_error(/Exporters cannot be defined under cf-internal namespace/)
        end
      end
    end

    describe 'extensions' do
      it 'list of available extensions matches builder source of truth' do
        config['extensions']['unavailable'] = nil

        builder_config = YAML.load_file(File.join(release_dir, "src/otel-collector-builder/config.yaml"))
        extension_gomods = builder_config.fetch('extensions').map {|entry| entry.fetch('gomod').split(" ")[0]}
        extension_names = extension_gomods.map do |gomod|
          YAML.load_file(File.join(release_dir, "src/otel-collector/vendor", gomod, "metadata.yaml")).fetch('type')
        end
        formatted_names = extension_names.sort.map {|name| "\"#{name}\"" }.join(", ")

        expect { rendered }.to raise_error do |error|
          expect(error.message).to include("Available: [#{formatted_names}]")
        end
      end

      it 'includes the configured extensions in the config' do
        expect(rendered.keys).to include 'extensions'
        expect(rendered['extensions']).to eq(config['extensions'])
      end

      # TODO: re-enable this test when we have more than one extension
      # it 'errors when a configured extension is not allowed' do
      #   properties['allow_list'] = {'extensions' => ['zpages']}
      #   expect { rendered }.to raise_error(/The following configured extensions are not allowed: \["pprof"\]/)
      # end

      it 'allows no extensions with empty allow list' do
        properties['allow_list'] = {'extensions' => []}
        expect { rendered }.to raise_error(/The following configured extensions are not allowed: \["pprof"\]/)
      end

      it 'errors when an unrecognized extension is in allow list' do
        properties['allow_list'] = {'extensions' => ['pprof', 'unrecognized-extension']}
        expect { rendered }.to raise_error(/The following extensions specified in the allow list are not included in this OpenTelemetry Collector distribution: \["unrecognized-extension"\]/)
      end

      it 'errors when an unavailable extension is configured' do
        config['extensions']['unavailable'] = nil
        expect { rendered }.to raise_error(/The following configured extensions are not included in this OpenTelemetry Collector distribution: \["unavailable"\]/)
      end
    end

    describe 'connectors' do
      before do
        config['connectors'] = { 'routing' => nil }
      end

      it 'list of available connectors matches builder source of truth' do
        config['connectors']['unavailable'] = nil

        builder_config = YAML.load_file(File.join(release_dir, "src/otel-collector-builder/config.yaml"))
        connector_gomods = builder_config.fetch('connectors').map {|entry| entry.fetch('gomod').split(" ")[0]}
        connector_names = connector_gomods.map do |gomod|
          YAML.load_file(File.join(release_dir, "src/otel-collector/vendor", gomod, "metadata.yaml")).fetch('type')
        end
        formatted_names = connector_names.sort.map {|name| "\"#{name}\"" }.join(", ")

        expect { rendered }.to raise_error do |error|
          expect(error.message).to include("Available: [#{formatted_names}]")
        end
      end

      it 'includes the configured connectors in the config' do
        expect(rendered.keys).to include 'connectors'
        expect(rendered['connectors']).to eq(config['connectors'])
      end

      it 'allows no connectors with empty allow list' do
        properties['allow_list'] = {'connectors' => []}
        expect { rendered }.to raise_error(/The following configured connectors are not allowed: \["routing"\]/)
      end

      it 'errors when an unrecognized connector is in allow list' do
        properties['allow_list'] = {'connectors' => ['routing', 'unrecognized-connector']}
        expect { rendered }.to raise_error(/The following connectors specified in the allow list are not included in this OpenTelemetry Collector distribution: \["unrecognized-connector"\]/)
      end

      it 'errors when an unavailable connector is configured' do
        config['connectors']['unavailable'] = nil
        expect { rendered }.to raise_error(/The following configured connectors are not included in this OpenTelemetry Collector distribution: \["unavailable"\]/)
      end
    end

    describe 'internal telemetry' do
      it 'exposes telemetry at the default port' do
        expect(rendered['service']['telemetry']['metrics']['readers'][0]['pull']['exporter']['prometheus']['host']).to eq('127.0.0.1')
        expect(rendered['service']['telemetry']['metrics']['readers'][0]['pull']['exporter']['prometheus']['port']).to eq(14830)
      end
      it 'provides basic level metrics by default' do
        expect(rendered['service']['telemetry']['metrics']['level']).to eq('basic')
      end

      context 'when the port is specified' do
        let(:properties) { { 'config' => config, 'telemetry' => { 'metrics' => { 'port' => 14_831 } } } }
        it 'exposes telemetry at the specified port' do
          expect(rendered['service']['telemetry']['metrics']['readers'][0]['pull']['exporter']['prometheus']['host']).to eq('127.0.0.1')
          expect(rendered['service']['telemetry']['metrics']['readers'][0]['pull']['exporter']['prometheus']['port']).to eq(14_831)
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
            'otlp_grpc' => { 'endpoint' => 'otelcol:4317' },
            'prometheus/tls' => {
              'endpoint' => '1.2.3.4:1234',
              'metric_expiration' => '60m'
            }
          },
          'trace_exporters' => {
            'otlp_grpc/traces' => { 'endpoint' => 'otelcol:4317' }
          }
        }
      end

      it 'uses the exporters provided' do
        expect(rendered['exporters']).to eq(
          {
            'otlp_grpc' => { 'endpoint' => 'otelcol:4317' },
            'prometheus/tls' => {
              'endpoint' => '1.2.3.4:1234',
              'metric_expiration' => '60m'
            },
            'otlp_grpc/traces' => { 'endpoint' => 'otelcol:4317' },
            'nop' => nil
          }
        )
      end

      it 'generates pipelines that include the exporters' do
        metrics_pipeline = rendered['service']['pipelines']['metrics']
        expect(metrics_pipeline['receivers']).to eq(['otlp/cf-internal-local'])
        expect(metrics_pipeline['exporters']).to eq(['otlp_grpc', 'prometheus/tls'])

        traces_pipeline = rendered['service']['pipelines']['traces']
        expect(traces_pipeline['receivers']).to eq(['otlp/cf-internal-local'])
        expect(traces_pipeline['exporters']).to eq(['otlp_grpc/traces'])
      end

      context 'when only a metrics pipeline is defined' do
        before do
          properties.delete('trace_exporters')
        end
        it 'includes a nop traces pipeline' do
          expect(rendered['service']['pipelines']['traces']['exporters']).to eq(['nop'])
        end
      end

      context 'when only a traces pipeline is defined' do
        before do
          properties.delete('metric_exporters')
        end
        it 'includes a nop metrics pipeline' do
          expect(rendered['service']['pipelines']['metrics']['exporters']).to eq(['nop'])
        end
      end

      context 'when an exporter has a name collision' do
        before do
          properties['trace_exporters'] = { 'otlp_grpc' => { 'endpoint' => 'otelcol:4317' } }
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
          expect(rendered['service']['pipelines']['traces']).to eq({ 'exporters' => ['otlp_grpc/traces'],
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

    describe 'secret interpolation' do
      let(:config) do
        {
          'exporters' => {
            'otlp_grpc' => {
              'endpoint' => 'otelcol:4317',
              'tls' => {
                'cert_pem' => '{{ .test-secret.cert }}',
                'key_pem' => '{{ .test-secret.key }}',
                'ca_pem' => '{{ .test-secret.ca }}'
              },
              'headers' => {
                'auth' => '{{ .anothersecret.secret }}'
              }
            },
            'prometheus/test' => {
              'tags' => [
                '{{ .anothersecret.secret }}'
              ]
            }
          },
          'service' => {
            'pipelines' => {
              'traces' => {
                'exporters' => ['otlp_grpc']
              },
              'metrics' => {
                'exporters' => ['otlp_grpc']
              }
            }
          }
        }
      end
      let(:properties) do
        {
          'config' => YAML.dump(config),
          'secrets' => [
            {
              'name' => 'test-secret',
              'cert' => '-----BEGIN CERTIFICATE-----
MIIE4jCCAsqgAwIBAgIUO/DRqVeXUmewgpy33MkQpe0ME7YwDQYJKoZIhvcNAQEL
BQAwgZkxCzAJBgNVBAYTAlVTMRMwEQYDVQQIDApDYWxpZm9ybmlhMRYwFAYDVQQH
DA1TYW4gRnJhbmNpc2NvMQwwCgYDVQQKDANNQVAxDzANBgNVBAsMBlZNd2FyZTEV
MBMGA1UEAwwMVG9vbHNtaXRoc0NBMScwJQYJKoZIhvcNAQkBFhhjZi10b29sc21p
dGhzQHdtd2FyZS5jb20wHhcNMjQwODI3MjEzMDU3WhcNMjYwODI4MjEzMDU3WjAy
MQswCQYDVQQGEwJVUzEQMA4GA1UECgwHUGl2b3RhbDERMA8GA1UEAwwIYmxhaC5j
b20wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDT0qMGluiM2jrZ0k/3
YjSy6/55NJttugG+RjfWXIPTti3ySHBgf5oOhgE1w/TMH8vQC1QBXSi3erw+WlZV
GW7pSs1AwPiTDJWlCmsyabY3En5+V+yFTI7CtA5uxC8Yo6szfHxk+RlZUcE8S7vd
0Lty0hahK0q+cNLqDfWDJ4jgJWKkoT9yGKSF+LLoUpJXqzI7d0soevzAolXEGb6X
O8ORQDYbT/onCwq9MKb4jRVE+KYT2+ajdKI0MPR4/3JA8/o2O4BNTf6MOnSFKWLe
CYXdtcqaDE2GqK3OUnlH2Tv2lS+1KCGq9800MfXJ/ln7kuetPBz7MelR6Ph9SWqk
Ev3NAgMBAAGjgYcwgYQwHQYDVR0OBBYEFPF+Zo5VBV/ZCDQk02HBER1j5WDtMB8G
A1UdIwQYMBaAFMGM2idsRltlr/D2KjmlZE2sdFgVMB0GA1UdJQQWMBQGCCsGAQUF
BwMCBggrBgEFBQcDATAOBgNVHQ8BAf8EBAMCBaAwEwYDVR0RBAwwCoIIYmxhaC5j
b20wDQYJKoZIhvcNAQELBQADggIBALkKkStBbqSJmhAgXsfxMyX+ksuf0iKchP14
/PIq9srwy6S6urc+9ajp7qNDvM+xaj8w2poUF4CPPVS7RqiRf5wJr2ZJDq0lcXbU
M+qqKth+6VkOPUsOP+5b6j/aUoo1zTxqiP6q2bJ2igujHfSJ4H3JenD2VogqzrDS
hNU0m4vupB79dlqPUWkkhkyQ+83GMLWzgwatmjj11jBeOPHNXZJikUODxvwVqscZ
iYYdVzzSqVJCxinwk1eGvGXeGsSR4EBsLpF9g18L57PPT8OfDHM7KnBdwhSFkLuU
gtd7i3u9NSScr7g3beQIBEi+ho/FR/pPcU453ilECsza3esMKAubr1nE6Be3tlhL
EZpwAdkj3lZVnAMcXyNo20mgYK7yVoVa+rS4E9oyTcldjqBUvFnFtqbB70h5ZZ/v
71uRB07WqE6zdvslcHtgWls5mM4APKhxjuszmY4GgEEQ7SJObQSzC53avPhlu+TB
3EWIdIjpvyNSEsC6yIVQrKJ6ejcqV9+OVPFQyHQ2yzyBDVSVVU6EqYFUJy3zmHp+
mm95ZMr9Q04nwi5//MNW7Yuw7XmjFtTlN6ybHrc82jNWDJx5GvZkHj0Qmg6TMYu2
hqmaUsNEA27fgk2HRuHUOJ+2EFFlCVZMLR7vN/JVE/LhZ2CdzoyMOkH0vtKophTg
HqBTRxft
-----END CERTIFICATE-----',
              'key' => 'bar',
              'ca' => 'baz'
            },
            {
              'name' => 'anothersecret',
              'secret' => 'foobarbaz'
            }
          ]
        }
      end

      it 'interpolates the config and renders it successfully' do
        expect(rendered['exporters']['otlp_grpc']['tls']['cert_pem']).to eq("-----BEGIN CERTIFICATE-----\nMIIE4jCCAsqgAwIBAgIUO/DRqVeXUmewgpy33MkQpe0ME7YwDQYJKoZIhvcNAQEL\nBQAwgZkxCzAJBgNVBAYTAlVTMRMwEQYDVQQIDApDYWxpZm9ybmlhMRYwFAYDVQQH\nDA1TYW4gRnJhbmNpc2NvMQwwCgYDVQQKDANNQVAxDzANBgNVBAsMBlZNd2FyZTEV\nMBMGA1UEAwwMVG9vbHNtaXRoc0NBMScwJQYJKoZIhvcNAQkBFhhjZi10b29sc21p\ndGhzQHdtd2FyZS5jb20wHhcNMjQwODI3MjEzMDU3WhcNMjYwODI4MjEzMDU3WjAy\nMQswCQYDVQQGEwJVUzEQMA4GA1UECgwHUGl2b3RhbDERMA8GA1UEAwwIYmxhaC5j\nb20wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDT0qMGluiM2jrZ0k/3\nYjSy6/55NJttugG+RjfWXIPTti3ySHBgf5oOhgE1w/TMH8vQC1QBXSi3erw+WlZV\nGW7pSs1AwPiTDJWlCmsyabY3En5+V+yFTI7CtA5uxC8Yo6szfHxk+RlZUcE8S7vd\n0Lty0hahK0q+cNLqDfWDJ4jgJWKkoT9yGKSF+LLoUpJXqzI7d0soevzAolXEGb6X\nO8ORQDYbT/onCwq9MKb4jRVE+KYT2+ajdKI0MPR4/3JA8/o2O4BNTf6MOnSFKWLe\nCYXdtcqaDE2GqK3OUnlH2Tv2lS+1KCGq9800MfXJ/ln7kuetPBz7MelR6Ph9SWqk\nEv3NAgMBAAGjgYcwgYQwHQYDVR0OBBYEFPF+Zo5VBV/ZCDQk02HBER1j5WDtMB8G\nA1UdIwQYMBaAFMGM2idsRltlr/D2KjmlZE2sdFgVMB0GA1UdJQQWMBQGCCsGAQUF\nBwMCBggrBgEFBQcDATAOBgNVHQ8BAf8EBAMCBaAwEwYDVR0RBAwwCoIIYmxhaC5j\nb20wDQYJKoZIhvcNAQELBQADggIBALkKkStBbqSJmhAgXsfxMyX+ksuf0iKchP14\n/PIq9srwy6S6urc+9ajp7qNDvM+xaj8w2poUF4CPPVS7RqiRf5wJr2ZJDq0lcXbU\nM+qqKth+6VkOPUsOP+5b6j/aUoo1zTxqiP6q2bJ2igujHfSJ4H3JenD2VogqzrDS\nhNU0m4vupB79dlqPUWkkhkyQ+83GMLWzgwatmjj11jBeOPHNXZJikUODxvwVqscZ\niYYdVzzSqVJCxinwk1eGvGXeGsSR4EBsLpF9g18L57PPT8OfDHM7KnBdwhSFkLuU\ngtd7i3u9NSScr7g3beQIBEi+ho/FR/pPcU453ilECsza3esMKAubr1nE6Be3tlhL\nEZpwAdkj3lZVnAMcXyNo20mgYK7yVoVa+rS4E9oyTcldjqBUvFnFtqbB70h5ZZ/v\n71uRB07WqE6zdvslcHtgWls5mM4APKhxjuszmY4GgEEQ7SJObQSzC53avPhlu+TB\n3EWIdIjpvyNSEsC6yIVQrKJ6ejcqV9+OVPFQyHQ2yzyBDVSVVU6EqYFUJy3zmHp+\nmm95ZMr9Q04nwi5//MNW7Yuw7XmjFtTlN6ybHrc82jNWDJx5GvZkHj0Qmg6TMYu2\nhqmaUsNEA27fgk2HRuHUOJ+2EFFlCVZMLR7vN/JVE/LhZ2CdzoyMOkH0vtKophTg\nHqBTRxft\n-----END CERTIFICATE-----")
        expect(rendered['exporters']['otlp_grpc']['tls']['key_pem']).to eq('bar')
        expect(rendered['exporters']['otlp_grpc']['tls']['ca_pem']).to eq('baz')
        expect(rendered['exporters']['otlp_grpc']['headers']['auth']).to eq('foobarbaz')
        expect(rendered['exporters']['prometheus/test']['tags'][0]).to eq('foobarbaz')
      end

      context 'when no secrets exist for template variables' do
        before do
          properties['secrets'][0]['key'] = ''
          properties['secrets'][0]['ca'] = nil
          properties['secrets'].delete_at(1)
        end

        it 'does not interpolate those template variables' do
          expect(rendered['exporters']['otlp_grpc']['tls']['cert_pem']).to eq("-----BEGIN CERTIFICATE-----\nMIIE4jCCAsqgAwIBAgIUO/DRqVeXUmewgpy33MkQpe0ME7YwDQYJKoZIhvcNAQEL\nBQAwgZkxCzAJBgNVBAYTAlVTMRMwEQYDVQQIDApDYWxpZm9ybmlhMRYwFAYDVQQH\nDA1TYW4gRnJhbmNpc2NvMQwwCgYDVQQKDANNQVAxDzANBgNVBAsMBlZNd2FyZTEV\nMBMGA1UEAwwMVG9vbHNtaXRoc0NBMScwJQYJKoZIhvcNAQkBFhhjZi10b29sc21p\ndGhzQHdtd2FyZS5jb20wHhcNMjQwODI3MjEzMDU3WhcNMjYwODI4MjEzMDU3WjAy\nMQswCQYDVQQGEwJVUzEQMA4GA1UECgwHUGl2b3RhbDERMA8GA1UEAwwIYmxhaC5j\nb20wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDT0qMGluiM2jrZ0k/3\nYjSy6/55NJttugG+RjfWXIPTti3ySHBgf5oOhgE1w/TMH8vQC1QBXSi3erw+WlZV\nGW7pSs1AwPiTDJWlCmsyabY3En5+V+yFTI7CtA5uxC8Yo6szfHxk+RlZUcE8S7vd\n0Lty0hahK0q+cNLqDfWDJ4jgJWKkoT9yGKSF+LLoUpJXqzI7d0soevzAolXEGb6X\nO8ORQDYbT/onCwq9MKb4jRVE+KYT2+ajdKI0MPR4/3JA8/o2O4BNTf6MOnSFKWLe\nCYXdtcqaDE2GqK3OUnlH2Tv2lS+1KCGq9800MfXJ/ln7kuetPBz7MelR6Ph9SWqk\nEv3NAgMBAAGjgYcwgYQwHQYDVR0OBBYEFPF+Zo5VBV/ZCDQk02HBER1j5WDtMB8G\nA1UdIwQYMBaAFMGM2idsRltlr/D2KjmlZE2sdFgVMB0GA1UdJQQWMBQGCCsGAQUF\nBwMCBggrBgEFBQcDATAOBgNVHQ8BAf8EBAMCBaAwEwYDVR0RBAwwCoIIYmxhaC5j\nb20wDQYJKoZIhvcNAQELBQADggIBALkKkStBbqSJmhAgXsfxMyX+ksuf0iKchP14\n/PIq9srwy6S6urc+9ajp7qNDvM+xaj8w2poUF4CPPVS7RqiRf5wJr2ZJDq0lcXbU\nM+qqKth+6VkOPUsOP+5b6j/aUoo1zTxqiP6q2bJ2igujHfSJ4H3JenD2VogqzrDS\nhNU0m4vupB79dlqPUWkkhkyQ+83GMLWzgwatmjj11jBeOPHNXZJikUODxvwVqscZ\niYYdVzzSqVJCxinwk1eGvGXeGsSR4EBsLpF9g18L57PPT8OfDHM7KnBdwhSFkLuU\ngtd7i3u9NSScr7g3beQIBEi+ho/FR/pPcU453ilECsza3esMKAubr1nE6Be3tlhL\nEZpwAdkj3lZVnAMcXyNo20mgYK7yVoVa+rS4E9oyTcldjqBUvFnFtqbB70h5ZZ/v\n71uRB07WqE6zdvslcHtgWls5mM4APKhxjuszmY4GgEEQ7SJObQSzC53avPhlu+TB\n3EWIdIjpvyNSEsC6yIVQrKJ6ejcqV9+OVPFQyHQ2yzyBDVSVVU6EqYFUJy3zmHp+\nmm95ZMr9Q04nwi5//MNW7Yuw7XmjFtTlN6ybHrc82jNWDJx5GvZkHj0Qmg6TMYu2\nhqmaUsNEA27fgk2HRuHUOJ+2EFFlCVZMLR7vN/JVE/LhZ2CdzoyMOkH0vtKophTg\nHqBTRxft\n-----END CERTIFICATE-----")
          expect(rendered['exporters']['otlp_grpc']['tls']['key_pem']).to eq('{{ .test-secret.key }}')
          expect(rendered['exporters']['otlp_grpc']['tls']['ca_pem']).to eq('{{ .test-secret.ca }}')
          expect(rendered['exporters']['otlp_grpc']['headers']['auth']).to eq('{{ .anothersecret.secret }}')
          expect(rendered['exporters']['prometheus/test']['tags'][0]).to eq('{{ .anothersecret.secret }}')
        end
      end

      context 'when no template variables exist for a secret' do
        before do
          config['exporters']['otlp_grpc'].delete('headers')
          config['exporters'].delete('prometheus/test')
        end

        it 'raises an error' do
          expect { rendered }.to raise_error(/The following secrets are unused: \['anothersecret.secret'\]/)
        end
      end

      context 'when template variables uses differing amounts of space separation' do
        before do
          config['exporters']['otlp_grpc']['tls']['cert_pem'] = '{{.test-secret.cert}}'
          config['exporters']['otlp_grpc']['tls']['key_pem'] = '{{        .test-secret.key}}'
          config['exporters']['otlp_grpc']['tls']['ca_pem'] = '{{   .test-secret.ca     }}'
        end

        it 'interpolates the config and renders it successfully' do
          expect(rendered['exporters']['otlp_grpc']['tls']['cert_pem']).to eq("-----BEGIN CERTIFICATE-----\nMIIE4jCCAsqgAwIBAgIUO/DRqVeXUmewgpy33MkQpe0ME7YwDQYJKoZIhvcNAQEL\nBQAwgZkxCzAJBgNVBAYTAlVTMRMwEQYDVQQIDApDYWxpZm9ybmlhMRYwFAYDVQQH\nDA1TYW4gRnJhbmNpc2NvMQwwCgYDVQQKDANNQVAxDzANBgNVBAsMBlZNd2FyZTEV\nMBMGA1UEAwwMVG9vbHNtaXRoc0NBMScwJQYJKoZIhvcNAQkBFhhjZi10b29sc21p\ndGhzQHdtd2FyZS5jb20wHhcNMjQwODI3MjEzMDU3WhcNMjYwODI4MjEzMDU3WjAy\nMQswCQYDVQQGEwJVUzEQMA4GA1UECgwHUGl2b3RhbDERMA8GA1UEAwwIYmxhaC5j\nb20wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDT0qMGluiM2jrZ0k/3\nYjSy6/55NJttugG+RjfWXIPTti3ySHBgf5oOhgE1w/TMH8vQC1QBXSi3erw+WlZV\nGW7pSs1AwPiTDJWlCmsyabY3En5+V+yFTI7CtA5uxC8Yo6szfHxk+RlZUcE8S7vd\n0Lty0hahK0q+cNLqDfWDJ4jgJWKkoT9yGKSF+LLoUpJXqzI7d0soevzAolXEGb6X\nO8ORQDYbT/onCwq9MKb4jRVE+KYT2+ajdKI0MPR4/3JA8/o2O4BNTf6MOnSFKWLe\nCYXdtcqaDE2GqK3OUnlH2Tv2lS+1KCGq9800MfXJ/ln7kuetPBz7MelR6Ph9SWqk\nEv3NAgMBAAGjgYcwgYQwHQYDVR0OBBYEFPF+Zo5VBV/ZCDQk02HBER1j5WDtMB8G\nA1UdIwQYMBaAFMGM2idsRltlr/D2KjmlZE2sdFgVMB0GA1UdJQQWMBQGCCsGAQUF\nBwMCBggrBgEFBQcDATAOBgNVHQ8BAf8EBAMCBaAwEwYDVR0RBAwwCoIIYmxhaC5j\nb20wDQYJKoZIhvcNAQELBQADggIBALkKkStBbqSJmhAgXsfxMyX+ksuf0iKchP14\n/PIq9srwy6S6urc+9ajp7qNDvM+xaj8w2poUF4CPPVS7RqiRf5wJr2ZJDq0lcXbU\nM+qqKth+6VkOPUsOP+5b6j/aUoo1zTxqiP6q2bJ2igujHfSJ4H3JenD2VogqzrDS\nhNU0m4vupB79dlqPUWkkhkyQ+83GMLWzgwatmjj11jBeOPHNXZJikUODxvwVqscZ\niYYdVzzSqVJCxinwk1eGvGXeGsSR4EBsLpF9g18L57PPT8OfDHM7KnBdwhSFkLuU\ngtd7i3u9NSScr7g3beQIBEi+ho/FR/pPcU453ilECsza3esMKAubr1nE6Be3tlhL\nEZpwAdkj3lZVnAMcXyNo20mgYK7yVoVa+rS4E9oyTcldjqBUvFnFtqbB70h5ZZ/v\n71uRB07WqE6zdvslcHtgWls5mM4APKhxjuszmY4GgEEQ7SJObQSzC53avPhlu+TB\n3EWIdIjpvyNSEsC6yIVQrKJ6ejcqV9+OVPFQyHQ2yzyBDVSVVU6EqYFUJy3zmHp+\nmm95ZMr9Q04nwi5//MNW7Yuw7XmjFtTlN6ybHrc82jNWDJx5GvZkHj0Qmg6TMYu2\nhqmaUsNEA27fgk2HRuHUOJ+2EFFlCVZMLR7vN/JVE/LhZ2CdzoyMOkH0vtKophTg\nHqBTRxft\n-----END CERTIFICATE-----")
          expect(rendered['exporters']['otlp_grpc']['tls']['key_pem']).to eq('bar')
          expect(rendered['exporters']['otlp_grpc']['tls']['ca_pem']).to eq('baz')
          expect(rendered['exporters']['otlp_grpc']['headers']['auth']).to eq('foobarbaz')
          expect(rendered['exporters']['prometheus/test']['tags'][0]).to eq('foobarbaz')
        end
      end

      context 'when template variables are not formatted correctly' do
        before do
          config['exporters']['otlp_grpc']['tls']['cert_pem'] = '{{test-secret.cert}}'
          config['exporters']['otlp_grpc']['tls']['key_pem'] = '{{ .test-secret }}'
          config['exporters']['otlp_grpc']['tls']['ca_pem'] = "{{\n .test-secret.ca \n}}"
        end

        it 'does not match secrets to those variables' do
          expect { rendered }.to raise_error(/The following secrets are unused: \['test-secret.cert', 'test-secret.key', 'test-secret.ca'\]/)
        end
      end

      context 'when template variables are not quoted' do
        before do
          properties['config'] = '
exporters:
  otlp/other:
    endpoint: otelcol:4317
    headers:
      auth: {{ .test.secret }}'
          properties['secrets'] = [{'name' => 'test', 'secret' => 'mysecret'}]
        end

        it 'does not match secrets to those variables' do
          expect { rendered }.to raise_error(/The following secrets are unused: \['test.secret'\]/)
        end
      end
    end

    context 'when configs is a non-empty list' do
      def entry_config(exporter)
        {
          'exporters' => { exporter => { 'endpoint' => "#{exporter}:4317" } },
          'service' => {
            'pipelines' => {
              'metrics' => {
                'receivers' => ['otlp/placeholder'],
                'exporters' => [exporter]
              }
            }
          }
        }
      end

      let(:properties) do
        {
          'configs' => [
            { 'name' => 'platform', 'config' => entry_config('otlp_grpc') },
            { 'name' => 'team a!', 'config' => entry_config('otlp_grpc/team') }
          ]
        }
      end
      # `rendered` (from the enclosing describe) YAML.safe_loads the template output; the
      # multi-config path emits a JSON array, and YAML is a superset of JSON so it parses
      # into the manifest array of {file, content} entries.
      let(:manifest) { rendered }

      it 'emits a JSON array manifest with one entry per config' do
        expect(manifest).to be_an(Array)
        expect(manifest.length).to eq(2)
      end

      it 'derives an indexed, sanitized filename per entry' do
        expect(manifest[0]['file']).to eq('config-000-platform.yml')
        expect(manifest[1]['file']).to eq('config-001-team_a_.yml')
      end

      it 'falls back to cfN when an entry has no name' do
        properties['configs'][1].delete('name')
        expect(manifest[1]['file']).to eq('config-001-cfg1.yml')
      end

      it 'renders each entry through the same rewrites (internal receiver + nop pipelines)' do
        first = YAML.safe_load(manifest[0]['content'])
        expect(first['receivers'].keys).to eq(['otlp/cf-internal-local'])
        expect(first['service']['pipelines']['metrics']['receivers']).to eq(['otlp/cf-internal-local'])
        # nop pipelines injected for the signals the entry does not define
        expect(first['service']['pipelines']['traces']['exporters']).to eq(['nop'])
        expect(first['service']['pipelines']['logs']['exporters']).to eq(['nop'])
      end

      it 'preserves connector-fed receivers within an entry' do
        properties['configs'][0]['config'] = {
          'connectors' => { 'routing' => nil },
          'exporters' => { 'otlp_grpc' => { 'endpoint' => 'otelcol:4317' } },
          'service' => {
            'pipelines' => {
              'metrics/in' => { 'receivers' => ['otlp/placeholder'], 'exporters' => ['routing'] },
              'metrics/out' => { 'receivers' => ['routing'], 'exporters' => ['otlp_grpc'] }
            }
          }
        }
        first = YAML.safe_load(manifest[0]['content'])
        expect(first['service']['pipelines']['metrics/in']['receivers']).to eq(['otlp/cf-internal-local'])
        expect(first['service']['pipelines']['metrics/out']['receivers']).to eq(['routing'])
      end

      it 'is mutually exclusive with config' do
        properties['config'] = { 'some' => 'thing' }
        expect { rendered }.to raise_error(/Can not provide 'configs' together with 'config'/)
      end

      it 'is mutually exclusive with the deprecated metric_exporters' do
        properties['metric_exporters'] = { 'otlp_grpc' => { 'endpoint' => 'otelcol:4317' } }
        expect { rendered }.to raise_error(/Can not provide 'configs' together with 'config'/)
      end

      it 'checks secret usage across the union of all entries' do
        properties['configs'][0]['config']['exporters']['otlp_grpc']['headers'] =
          { 'auth' => '{{ .shared.secret }}' }
        properties['secrets'] = [{ 'name' => 'shared', 'secret' => 'tok' }]
        expect { rendered }.to_not raise_error
        expect(YAML.safe_load(manifest[0]['content'])['exporters']['otlp_grpc']['headers']['auth']).to eq('tok')
      end

      it 'raises when a declared secret is unused by any entry' do
        properties['secrets'] = [{ 'name' => 'orphan', 'secret' => 'tok' }]
        expect { rendered }.to raise_error(/The following secrets are unused: \['orphan.secret'\]/)
      end
    end

    describe 'inject_internal_receiver' do
      def entry_config_for_inject(exporter)
        {
          'exporters' => { exporter => { 'endpoint' => "#{exporter}:4317" } },
          'service' => {
            'pipelines' => {
              'metrics' => {
                'receivers' => ['otlp/placeholder'],
                'exporters' => [exporter]
              }
            }
          }
        }
      end

      context 'all (default)' do
        let(:properties) { { 'config' => config } }

        it 'injects the internal receiver (regression guard)' do
          expect(rendered['receivers'].keys).to eq(['otlp/cf-internal-local'])
        end

        it 'adds nop pipelines for missing signals' do
          cfg = config.dup
          cfg['service'] = cfg['service'].dup
          cfg['service']['pipelines'] = cfg['service']['pipelines'].reject { |k, _| k.start_with?('traces') }
          r = YAML.safe_load(template.render({ 'config' => cfg }))
          expect(r['service']['pipelines']['traces']['exporters']).to eq(['nop'])
        end
      end

      context 'first with 2 configs' do
        let(:properties) do
          {
            'inject_internal_receiver' => 'first',
            'validate_configs' => 'first',
            'configs' => [
              { 'name' => 'ingress', 'config' => entry_config_for_inject('otlp_grpc') },
              {
                'name' => 'egress',
                'config' => {
                  'receivers' => { 'prometheus/scrape' => { 'config' => { 'scrape_interval' => '15s' } } },
                  'exporters' => { 'otlp_grpc/out' => { 'endpoint' => 'out:4317' } },
                  'service' => {
                    'pipelines' => {
                      'metrics' => {
                        'receivers' => ['prometheus/scrape'],
                        'exporters' => ['otlp_grpc/out']
                      }
                    }
                  }
                }
              }
            ]
          }
        end
        let(:manifest) { rendered }

        it 'injects the internal receiver into config-000 only' do
          first = YAML.safe_load(manifest[0]['content'])
          expect(first['receivers'].keys).to eq(['otlp/cf-internal-local'])
          expect(first['service']['pipelines']['metrics']['receivers']).to eq(['otlp/cf-internal-local'])
        end

        it 'adds nop pipelines to config-000' do
          first = YAML.safe_load(manifest[0]['content'])
          expect(first['service']['pipelines']['traces']['exporters']).to eq(['nop'])
          expect(first['service']['pipelines']['logs']['exporters']).to eq(['nop'])
        end

        it 'renders config-001 verbatim (operator receivers preserved, no internal receiver)' do
          second = YAML.safe_load(manifest[1]['content'])
          expect(second['receivers'].keys).to eq(['prometheus/scrape'])
          expect(second['service']['pipelines']['metrics']['receivers']).to eq(['prometheus/scrape'])
        end

        it 'does not inject nop pipelines into config-001' do
          second = YAML.safe_load(manifest[1]['content'])
          expect(second['service']['pipelines'].keys).to eq(['metrics'])
        end

        it 'renders a fragment with no exporters map verbatim (no completeness error)' do
          properties['configs'] << {
            'name' => 'fragment',
            'config' => {
              'service' => {
                'pipelines' => {
                  'metrics/bosh' => {
                    'receivers' => ['routing'],
                    'exporters' => ['otlp']
                  }
                }
              }
            }
          }
          expect { rendered }.not_to raise_error
          fragment = YAML.safe_load(manifest[2]['content'])
          expect(fragment['exporters']).to be_nil
        end

        it 'renders a fragment with no service map verbatim (no completeness error)' do
          properties['configs'] << {
            'name' => 'ext-fragment',
            'config' => {
              'extensions' => { 'pprof' => nil }
            }
          }
          expect { rendered }.not_to raise_error
        end

        it 'still raises for a fragment referencing a disallowed exporter' do
          properties['allow_list'] = { 'exporters' => ['otlp_grpc'] }
          properties['configs'] << {
            'name' => 'bad-fragment',
            'config' => {
              'exporters' => { 'debug' => nil },
              'service' => {
                'pipelines' => {
                  'metrics/dbg' => {
                    'exporters' => ['debug']
                  }
                }
              }
            }
          }
          expect { rendered }.to raise_error(/The following configured exporters are not allowed/)
        end
      end

      context 'none' do
        let(:none_config) do
          {
            'receivers' => { 'prometheus/scrape' => { 'config' => { 'scrape_interval' => '15s' } } },
            'exporters' => { 'otlp_grpc' => { 'endpoint' => 'out:4317' } },
            'service' => {
              'pipelines' => {
                'metrics' => {
                  'receivers' => ['prometheus/scrape'],
                  'exporters' => ['otlp_grpc']
                }
              }
            }
          }
        end
        let(:properties) { { 'inject_internal_receiver' => 'none', 'config' => none_config } }

        it 'preserves the operator receiver' do
          expect(rendered['receivers'].keys).to eq(['prometheus/scrape'])
        end

        it 'does not inject the internal receiver' do
          expect(rendered['receivers'].keys).not_to include('otlp/cf-internal-local')
        end

        it 'does not inject nop pipelines' do
          expect(rendered['service']['pipelines'].keys).to eq(['metrics'])
        end

        it 'still emits self-telemetry' do
          expect(rendered['service']['telemetry']['metrics']['readers'][0]['pull']['exporter']['prometheus']['port']).to eq(14830)
        end

        it 'still raises when exporters are missing (completeness is governed by validate_configs, not inject_internal_receiver)' do
          properties['config'] = none_config.reject { |k, _| k == 'exporters' }
          expect { rendered }.to raise_error(/Exporter configuration must be provided/)
        end
      end

      context 'invalid value' do
        let(:properties) { { 'inject_internal_receiver' => 'bogus', 'config' => config } }

        it 'raises a descriptive error' do
          expect { rendered }.to raise_error(/inject_internal_receiver must be one of all\|first\|none/)
        end
      end

      context 'validate_configs invalid value' do
        let(:properties) { { 'validate_configs' => 'bogus', 'config' => config } }

        it 'raises a descriptive error' do
          expect { rendered }.to raise_error(/validate_configs must be one of all\|first\|none/)
        end
      end
    end
  end
end
