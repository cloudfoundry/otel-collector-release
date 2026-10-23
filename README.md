# otel-collector-release

BOSH release for Cloud Foundry's distribution of the [OpenTelemetry Collector](https://github.com/open-telemetry/opentelemetry-collector).

If you have any questions, or want to get attention for a PR or issue please reach out in the [#logging-and-metrics](https://cloudfoundry.slack.com/archives/CUW93AF3M) channel within Cloud Foundry Slack.

See [Configuring the OpenTelemetry Collector](https://docs.cloudfoundry.org/loggregator/opentelemetry.html) in the Cloud Foundry documentation for more information.

## Migration: receiver preservation

The introduction of `ingress.pipelines` is a **breaking change** for configurations
that relied on receiver replacement. The release now preserves operator-provided
receiver definitions and pipeline receiver lists while adding its managed
`otlp/cf-internal-local` receiver.

Before upgrading a configuration that uses placeholder receivers:

1. Remove receiver definitions used only as placeholders, such as
   `config.receivers.otlp/placeholder`. Omit `config.receivers` entirely if there
   are no custom receivers.
2. Replace those placeholders in CF ingress pipelines' `receivers` lists with
   `otlp/cf-internal-local`. The release supplies its configuration from the
   `ingress.grpc.*` properties.

For example, a CF metrics configuration becomes:

```yaml
config:
  exporters:
    otlp_grpc:
      endpoint: otelcol:4317
  service:
    pipelines:
      metrics:
        receivers: [otlp/cf-internal-local]
        exporters: [otlp_grpc]
```

An empty `otlp/placeholder` definition now fails collector validation with
`must specify at least one protocol when using the OTLP receiver`. Adding the
internal receiver to a pipeline alone does not fix this; remove the placeholder
definition and its references as well.

For routing or custom-receiver configurations, set `ingress.pipelines` to the
exact CF ingress pipeline names, or use `[]` with explicit receiver wiring.
Leaving it unset adds the internal receiver to every pipeline, including
connector-fed pipelines.

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
