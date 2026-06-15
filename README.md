# otel-collector-release

BOSH release for Cloud Foundry's distribution of the [OpenTelemetry Collector](https://github.com/open-telemetry/opentelemetry-collector).

If you have any questions, or want to get attention for a PR or issue please reach out in the [#logging-and-metrics](https://cloudfoundry.slack.com/archives/CUW93AF3M) channel within Cloud Foundry Slack.

See [Configuring the OpenTelemetry Collector](https://docs.cloudfoundry.org/loggregator/opentelemetry.html) in the Cloud Foundry documentation for more information.

## FAQ

### How do I configure mTLS per exporter?

Put each exporter's PEMs under `config` and reference CredHub-stored values
via BOSH `((var))` placeholders:

```yaml
config:
  exporters:
    otlp_grpc/prod:
      endpoint: prod-backend:4317
      tls:
        ca_pem:   ((prod_ca))
        cert_pem: ((prod_cert))
        key_pem:  ((prod_key))
    otlp_grpc/staging:
      endpoint: staging-backend:4317
      tls:
        ca_pem:   ((staging_ca))
        cert_pem: ((staging_cert))
        key_pem:  ((staging_key))
  service:
    pipelines:
      metrics:
        exporters: [otlp_grpc/prod, otlp_grpc/staging]
```

If `config` must be a YAML string instead of a map, BOSH `((var))`
substitution cannot indent multi-line PEMs into the block scalar and
template rendering fails. In that case use the `secrets` property — see the
`secrets` description in the [job spec](jobs/otel-collector/spec).
