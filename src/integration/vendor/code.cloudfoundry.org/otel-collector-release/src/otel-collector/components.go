// Code generated by "go.opentelemetry.io/collector/cmd/builder". DO NOT EDIT.

package main

import (
	"go.opentelemetry.io/collector/connector"
	"go.opentelemetry.io/collector/exporter"
	"go.opentelemetry.io/collector/extension"
	"go.opentelemetry.io/collector/otelcol"
	"go.opentelemetry.io/collector/processor"
	"go.opentelemetry.io/collector/receiver"
	otlpexporter "go.opentelemetry.io/collector/exporter/otlpexporter"
	nopexporter "go.opentelemetry.io/collector/exporter/nopexporter"
	fileexporter "github.com/open-telemetry/opentelemetry-collector-contrib/exporter/fileexporter"
	prometheusexporter "github.com/open-telemetry/opentelemetry-collector-contrib/exporter/prometheusexporter"
	prometheusremotewriteexporter "github.com/open-telemetry/opentelemetry-collector-contrib/exporter/prometheusremotewriteexporter"
	splunkhecexporter "github.com/open-telemetry/opentelemetry-collector-contrib/exporter/splunkhecexporter"
	batchprocessor "go.opentelemetry.io/collector/processor/batchprocessor"
	memorylimiterprocessor "go.opentelemetry.io/collector/processor/memorylimiterprocessor"
	transformprocessor "github.com/open-telemetry/opentelemetry-collector-contrib/processor/transformprocessor"
	filterprocessor "github.com/open-telemetry/opentelemetry-collector-contrib/processor/filterprocessor"
	otlpreceiver "go.opentelemetry.io/collector/receiver/otlpreceiver"
)

func components() (otelcol.Factories, error) {
	var err error
	factories := otelcol.Factories{}

	factories.Extensions, err = extension.MakeFactoryMap(
	)
	if err != nil {
		return otelcol.Factories{}, err
	}

	factories.Receivers, err = receiver.MakeFactoryMap(
		otlpreceiver.NewFactory(),
	)
	if err != nil {
		return otelcol.Factories{}, err
	}

	factories.Exporters, err = exporter.MakeFactoryMap(
		otlpexporter.NewFactory(),
		nopexporter.NewFactory(),
		fileexporter.NewFactory(),
		prometheusexporter.NewFactory(),
		prometheusremotewriteexporter.NewFactory(),
		splunkhecexporter.NewFactory(),
	)
	if err != nil {
		return otelcol.Factories{}, err
	}

	factories.Processors, err = processor.MakeFactoryMap(
		batchprocessor.NewFactory(),
		memorylimiterprocessor.NewFactory(),
		transformprocessor.NewFactory(),
		filterprocessor.NewFactory(),
	)
	if err != nil {
		return otelcol.Factories{}, err
	}

	factories.Connectors, err = connector.MakeFactoryMap(
	)
	if err != nil {
		return otelcol.Factories{}, err
	}

	return factories, nil
}
