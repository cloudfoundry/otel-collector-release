// Code generated by "go.opentelemetry.io/collector/cmd/builder". DO NOT EDIT.

// Program cf-otel-collector is an OpenTelemetry Collector binary.
package main

import (
	"log"

	"go.opentelemetry.io/collector/component"
	"go.opentelemetry.io/collector/otelcol"
)

func main() {
	info := component.BuildInfo{
		Command:     "cf-otel-collector",
		Description: "Cloud Foundry OpenTelemetry Collector",
		Version:     "0.3.1",
	}

	if err := run(otelcol.CollectorSettings{BuildInfo: info, Factories: components}); err != nil {
		log.Fatal(err)
	}
}

func runInteractive(params otelcol.CollectorSettings) error {
	cmd := otelcol.NewCommand(params)
	if err := cmd.Execute(); err != nil {
		log.Fatalf("collector server run finished with error: %v", err)
	}

	return nil
}
