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
            },
            'logs' => {
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
                'exporters' => ['otlp']
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
                'exporters' => ['otlp']
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
            'otlp/traces' => { 'endpoint' => 'otelcol:4317' },
            'nop' => nil
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

    describe 'secret interpolation' do
      let(:config) do
        {
          'exporters' => {
            'otlp' => {
              'endpoint' => 'otelcol:4317',
              'tls' => {
                'cert_pem' => '{{ .testsecret.cert }}',
                'key_pem' => '{{ .testsecret.key }}',
                'ca_pem' => '{{ .testsecret.ca }}'
              },
              'headers' => {
                'auth' => '{{ .anothersecret.secret }}'
              }
            }
          },
          'service' => {
            'pipelines' => {
              'traces' => {
                'exporters' => ['otlp']
              },
              'metrics' => {
                'exporters' => ['otlp']
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
              'name' => 'testsecret',
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
        expect(rendered['exporters']['otlp']['tls']['cert_pem']).to eq("-----BEGIN CERTIFICATE-----\nMIIE4jCCAsqgAwIBAgIUO/DRqVeXUmewgpy33MkQpe0ME7YwDQYJKoZIhvcNAQEL\nBQAwgZkxCzAJBgNVBAYTAlVTMRMwEQYDVQQIDApDYWxpZm9ybmlhMRYwFAYDVQQH\nDA1TYW4gRnJhbmNpc2NvMQwwCgYDVQQKDANNQVAxDzANBgNVBAsMBlZNd2FyZTEV\nMBMGA1UEAwwMVG9vbHNtaXRoc0NBMScwJQYJKoZIhvcNAQkBFhhjZi10b29sc21p\ndGhzQHdtd2FyZS5jb20wHhcNMjQwODI3MjEzMDU3WhcNMjYwODI4MjEzMDU3WjAy\nMQswCQYDVQQGEwJVUzEQMA4GA1UECgwHUGl2b3RhbDERMA8GA1UEAwwIYmxhaC5j\nb20wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDT0qMGluiM2jrZ0k/3\nYjSy6/55NJttugG+RjfWXIPTti3ySHBgf5oOhgE1w/TMH8vQC1QBXSi3erw+WlZV\nGW7pSs1AwPiTDJWlCmsyabY3En5+V+yFTI7CtA5uxC8Yo6szfHxk+RlZUcE8S7vd\n0Lty0hahK0q+cNLqDfWDJ4jgJWKkoT9yGKSF+LLoUpJXqzI7d0soevzAolXEGb6X\nO8ORQDYbT/onCwq9MKb4jRVE+KYT2+ajdKI0MPR4/3JA8/o2O4BNTf6MOnSFKWLe\nCYXdtcqaDE2GqK3OUnlH2Tv2lS+1KCGq9800MfXJ/ln7kuetPBz7MelR6Ph9SWqk\nEv3NAgMBAAGjgYcwgYQwHQYDVR0OBBYEFPF+Zo5VBV/ZCDQk02HBER1j5WDtMB8G\nA1UdIwQYMBaAFMGM2idsRltlr/D2KjmlZE2sdFgVMB0GA1UdJQQWMBQGCCsGAQUF\nBwMCBggrBgEFBQcDATAOBgNVHQ8BAf8EBAMCBaAwEwYDVR0RBAwwCoIIYmxhaC5j\nb20wDQYJKoZIhvcNAQELBQADggIBALkKkStBbqSJmhAgXsfxMyX+ksuf0iKchP14\n/PIq9srwy6S6urc+9ajp7qNDvM+xaj8w2poUF4CPPVS7RqiRf5wJr2ZJDq0lcXbU\nM+qqKth+6VkOPUsOP+5b6j/aUoo1zTxqiP6q2bJ2igujHfSJ4H3JenD2VogqzrDS\nhNU0m4vupB79dlqPUWkkhkyQ+83GMLWzgwatmjj11jBeOPHNXZJikUODxvwVqscZ\niYYdVzzSqVJCxinwk1eGvGXeGsSR4EBsLpF9g18L57PPT8OfDHM7KnBdwhSFkLuU\ngtd7i3u9NSScr7g3beQIBEi+ho/FR/pPcU453ilECsza3esMKAubr1nE6Be3tlhL\nEZpwAdkj3lZVnAMcXyNo20mgYK7yVoVa+rS4E9oyTcldjqBUvFnFtqbB70h5ZZ/v\n71uRB07WqE6zdvslcHtgWls5mM4APKhxjuszmY4GgEEQ7SJObQSzC53avPhlu+TB\n3EWIdIjpvyNSEsC6yIVQrKJ6ejcqV9+OVPFQyHQ2yzyBDVSVVU6EqYFUJy3zmHp+\nmm95ZMr9Q04nwi5//MNW7Yuw7XmjFtTlN6ybHrc82jNWDJx5GvZkHj0Qmg6TMYu2\nhqmaUsNEA27fgk2HRuHUOJ+2EFFlCVZMLR7vN/JVE/LhZ2CdzoyMOkH0vtKophTg\nHqBTRxft\n-----END CERTIFICATE-----")
        expect(rendered['exporters']['otlp']['tls']['key_pem']).to eq('bar')
        expect(rendered['exporters']['otlp']['tls']['ca_pem']).to eq('baz')
        expect(rendered['exporters']['otlp']['headers']['auth']).to eq('foobarbaz')
      end

      context 'when no secrets exist for template variables' do
        before do
          properties['secrets'][0]['key'] = ''
          properties['secrets'][0]['ca'] = nil
          properties['secrets'].delete_at(1)
        end

        it 'does not interpolate those template variables' do
          expect(rendered['exporters']['otlp']['tls']['cert_pem']).to eq("-----BEGIN CERTIFICATE-----\nMIIE4jCCAsqgAwIBAgIUO/DRqVeXUmewgpy33MkQpe0ME7YwDQYJKoZIhvcNAQEL\nBQAwgZkxCzAJBgNVBAYTAlVTMRMwEQYDVQQIDApDYWxpZm9ybmlhMRYwFAYDVQQH\nDA1TYW4gRnJhbmNpc2NvMQwwCgYDVQQKDANNQVAxDzANBgNVBAsMBlZNd2FyZTEV\nMBMGA1UEAwwMVG9vbHNtaXRoc0NBMScwJQYJKoZIhvcNAQkBFhhjZi10b29sc21p\ndGhzQHdtd2FyZS5jb20wHhcNMjQwODI3MjEzMDU3WhcNMjYwODI4MjEzMDU3WjAy\nMQswCQYDVQQGEwJVUzEQMA4GA1UECgwHUGl2b3RhbDERMA8GA1UEAwwIYmxhaC5j\nb20wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDT0qMGluiM2jrZ0k/3\nYjSy6/55NJttugG+RjfWXIPTti3ySHBgf5oOhgE1w/TMH8vQC1QBXSi3erw+WlZV\nGW7pSs1AwPiTDJWlCmsyabY3En5+V+yFTI7CtA5uxC8Yo6szfHxk+RlZUcE8S7vd\n0Lty0hahK0q+cNLqDfWDJ4jgJWKkoT9yGKSF+LLoUpJXqzI7d0soevzAolXEGb6X\nO8ORQDYbT/onCwq9MKb4jRVE+KYT2+ajdKI0MPR4/3JA8/o2O4BNTf6MOnSFKWLe\nCYXdtcqaDE2GqK3OUnlH2Tv2lS+1KCGq9800MfXJ/ln7kuetPBz7MelR6Ph9SWqk\nEv3NAgMBAAGjgYcwgYQwHQYDVR0OBBYEFPF+Zo5VBV/ZCDQk02HBER1j5WDtMB8G\nA1UdIwQYMBaAFMGM2idsRltlr/D2KjmlZE2sdFgVMB0GA1UdJQQWMBQGCCsGAQUF\nBwMCBggrBgEFBQcDATAOBgNVHQ8BAf8EBAMCBaAwEwYDVR0RBAwwCoIIYmxhaC5j\nb20wDQYJKoZIhvcNAQELBQADggIBALkKkStBbqSJmhAgXsfxMyX+ksuf0iKchP14\n/PIq9srwy6S6urc+9ajp7qNDvM+xaj8w2poUF4CPPVS7RqiRf5wJr2ZJDq0lcXbU\nM+qqKth+6VkOPUsOP+5b6j/aUoo1zTxqiP6q2bJ2igujHfSJ4H3JenD2VogqzrDS\nhNU0m4vupB79dlqPUWkkhkyQ+83GMLWzgwatmjj11jBeOPHNXZJikUODxvwVqscZ\niYYdVzzSqVJCxinwk1eGvGXeGsSR4EBsLpF9g18L57PPT8OfDHM7KnBdwhSFkLuU\ngtd7i3u9NSScr7g3beQIBEi+ho/FR/pPcU453ilECsza3esMKAubr1nE6Be3tlhL\nEZpwAdkj3lZVnAMcXyNo20mgYK7yVoVa+rS4E9oyTcldjqBUvFnFtqbB70h5ZZ/v\n71uRB07WqE6zdvslcHtgWls5mM4APKhxjuszmY4GgEEQ7SJObQSzC53avPhlu+TB\n3EWIdIjpvyNSEsC6yIVQrKJ6ejcqV9+OVPFQyHQ2yzyBDVSVVU6EqYFUJy3zmHp+\nmm95ZMr9Q04nwi5//MNW7Yuw7XmjFtTlN6ybHrc82jNWDJx5GvZkHj0Qmg6TMYu2\nhqmaUsNEA27fgk2HRuHUOJ+2EFFlCVZMLR7vN/JVE/LhZ2CdzoyMOkH0vtKophTg\nHqBTRxft\n-----END CERTIFICATE-----")
          expect(rendered['exporters']['otlp']['tls']['key_pem']).to eq('{{ .testsecret.key }}')
          expect(rendered['exporters']['otlp']['tls']['ca_pem']).to eq('{{ .testsecret.ca }}')
          expect(rendered['exporters']['otlp']['headers']['auth']).to eq('{{ .anothersecret.secret }}')
        end
      end

      context 'when no template variables exist for a secret' do
        before do
          config['exporters']['otlp'].delete('headers')
        end

        it 'raises an error' do
          expect { rendered }.to raise_error(/The following secrets are unused: \['anothersecret.secret'\]/)
        end
      end

      context 'when template variables uses differing amounts of space separation' do
        before do
          config['exporters']['otlp']['tls']['cert_pem'] = '{{.testsecret.cert}}'
          config['exporters']['otlp']['tls']['key_pem'] = '{{        .testsecret.key}}'
          config['exporters']['otlp']['tls']['ca_pem'] = '{{   .testsecret.ca     }}'
        end

        it 'interpolates the config and renders it successfully' do
          expect(rendered['exporters']['otlp']['tls']['cert_pem']).to eq("-----BEGIN CERTIFICATE-----\nMIIE4jCCAsqgAwIBAgIUO/DRqVeXUmewgpy33MkQpe0ME7YwDQYJKoZIhvcNAQEL\nBQAwgZkxCzAJBgNVBAYTAlVTMRMwEQYDVQQIDApDYWxpZm9ybmlhMRYwFAYDVQQH\nDA1TYW4gRnJhbmNpc2NvMQwwCgYDVQQKDANNQVAxDzANBgNVBAsMBlZNd2FyZTEV\nMBMGA1UEAwwMVG9vbHNtaXRoc0NBMScwJQYJKoZIhvcNAQkBFhhjZi10b29sc21p\ndGhzQHdtd2FyZS5jb20wHhcNMjQwODI3MjEzMDU3WhcNMjYwODI4MjEzMDU3WjAy\nMQswCQYDVQQGEwJVUzEQMA4GA1UECgwHUGl2b3RhbDERMA8GA1UEAwwIYmxhaC5j\nb20wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDT0qMGluiM2jrZ0k/3\nYjSy6/55NJttugG+RjfWXIPTti3ySHBgf5oOhgE1w/TMH8vQC1QBXSi3erw+WlZV\nGW7pSs1AwPiTDJWlCmsyabY3En5+V+yFTI7CtA5uxC8Yo6szfHxk+RlZUcE8S7vd\n0Lty0hahK0q+cNLqDfWDJ4jgJWKkoT9yGKSF+LLoUpJXqzI7d0soevzAolXEGb6X\nO8ORQDYbT/onCwq9MKb4jRVE+KYT2+ajdKI0MPR4/3JA8/o2O4BNTf6MOnSFKWLe\nCYXdtcqaDE2GqK3OUnlH2Tv2lS+1KCGq9800MfXJ/ln7kuetPBz7MelR6Ph9SWqk\nEv3NAgMBAAGjgYcwgYQwHQYDVR0OBBYEFPF+Zo5VBV/ZCDQk02HBER1j5WDtMB8G\nA1UdIwQYMBaAFMGM2idsRltlr/D2KjmlZE2sdFgVMB0GA1UdJQQWMBQGCCsGAQUF\nBwMCBggrBgEFBQcDATAOBgNVHQ8BAf8EBAMCBaAwEwYDVR0RBAwwCoIIYmxhaC5j\nb20wDQYJKoZIhvcNAQELBQADggIBALkKkStBbqSJmhAgXsfxMyX+ksuf0iKchP14\n/PIq9srwy6S6urc+9ajp7qNDvM+xaj8w2poUF4CPPVS7RqiRf5wJr2ZJDq0lcXbU\nM+qqKth+6VkOPUsOP+5b6j/aUoo1zTxqiP6q2bJ2igujHfSJ4H3JenD2VogqzrDS\nhNU0m4vupB79dlqPUWkkhkyQ+83GMLWzgwatmjj11jBeOPHNXZJikUODxvwVqscZ\niYYdVzzSqVJCxinwk1eGvGXeGsSR4EBsLpF9g18L57PPT8OfDHM7KnBdwhSFkLuU\ngtd7i3u9NSScr7g3beQIBEi+ho/FR/pPcU453ilECsza3esMKAubr1nE6Be3tlhL\nEZpwAdkj3lZVnAMcXyNo20mgYK7yVoVa+rS4E9oyTcldjqBUvFnFtqbB70h5ZZ/v\n71uRB07WqE6zdvslcHtgWls5mM4APKhxjuszmY4GgEEQ7SJObQSzC53avPhlu+TB\n3EWIdIjpvyNSEsC6yIVQrKJ6ejcqV9+OVPFQyHQ2yzyBDVSVVU6EqYFUJy3zmHp+\nmm95ZMr9Q04nwi5//MNW7Yuw7XmjFtTlN6ybHrc82jNWDJx5GvZkHj0Qmg6TMYu2\nhqmaUsNEA27fgk2HRuHUOJ+2EFFlCVZMLR7vN/JVE/LhZ2CdzoyMOkH0vtKophTg\nHqBTRxft\n-----END CERTIFICATE-----")
          expect(rendered['exporters']['otlp']['tls']['key_pem']).to eq('bar')
          expect(rendered['exporters']['otlp']['tls']['ca_pem']).to eq('baz')
          expect(rendered['exporters']['otlp']['headers']['auth']).to eq('foobarbaz')
        end
      end

      context 'when template variables are not formatted correctly' do
        before do
          config['exporters']['otlp']['tls']['cert_pem'] = '{{testsecret.cert}}'
          config['exporters']['otlp']['tls']['key_pem'] = '{{ .testsecret }}'
          config['exporters']['otlp']['tls']['ca_pem'] = "{{\n .testsecret.ca \n}}"
        end

        it 'does not match secrets to those variables' do
          expect { rendered }.to raise_error(/The following secrets are unused: \['testsecret.cert', 'testsecret.key', 'testsecret.ca'\]/)
        end
      end
    end
  end
end
