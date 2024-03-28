package loggregatorreceiver

import (
	"context"
	"fmt"

	"code.cloudfoundry.org/otel-collector-release/src/receiver/loggregatorreceiver/internal/metadata"
	"go.opentelemetry.io/collector/component"
	"go.opentelemetry.io/collector/config/configgrpc"
	"go.opentelemetry.io/collector/config/confignet"
	"go.opentelemetry.io/collector/consumer"
	"go.opentelemetry.io/collector/receiver"
)

const (
	grpcPort = 4317
	udpPort  = 4318
)

// NewFactory creates a new loggregator receiver factory.
func NewFactory() receiver.Factory {
	return receiver.NewFactory(
		metadata.Type,
		createDefaultConfig,
		receiver.WithTraces(createTrace, metadata.TracesStability),
		receiver.WithMetrics(createMetric, metadata.MetricsStability),
		receiver.WithLogs(createLog, metadata.LogsStability),
	)
}

// createDefaultConfig creates the default configuration for the receiver.
func createDefaultConfig() component.Config {
	return &Config{
		Protocols: Protocols{
			V2: &V2Config{
				GRPC: &configgrpc.GRPCServerSettings{
					NetAddr: confignet.NetAddr{
						Endpoint:  fmt.Sprintf("localhost:%d", grpcPort),
						Transport: "tcp",
					},
					ReadBufferSize: 512 * 1024,
				},
			},
			V1: &V1Config{
				Port: udpPort,
			},
		},
	}
}

// createTrace creates a trace receiver based on the provided config.
func createTrace(
	_ context.Context,
	set receiver.CreateSettings,
	cfg component.Config,
	nextConsumer consumer.Traces,
) (receiver.Traces, error) {
	rCfg := cfg.(*Config)
	if r, ok := receivers[rCfg]; ok {
		r.nextTraces = nextConsumer
		return r, nil
	}
	r, err := newLoggregatorReceiver(rCfg, &set)
	if err != nil {
		return nil, err
	}
	r.nextTraces = nextConsumer
	receivers[rCfg] = r
	return r, nil
}

// createMetric creates a metric receiver based on the provided config.
func createMetric(
	_ context.Context,
	set receiver.CreateSettings,
	cfg component.Config,
	nextConsumer consumer.Metrics,
) (receiver.Metrics, error) {
	rCfg := cfg.(*Config)
	if r, ok := receivers[rCfg]; ok {
		r.nextMetrics = nextConsumer
		return r, nil
	}
	r, err := newLoggregatorReceiver(rCfg, &set)
	if err != nil {
		return nil, err
	}
	r.nextMetrics = nextConsumer
	receivers[rCfg] = r
	return r, nil
}

// createLog creates a log receiver based on the provided config.
func createLog(
	_ context.Context,
	set receiver.CreateSettings,
	cfg component.Config,
	nextConsumer consumer.Logs,
) (receiver.Logs, error) {
	rCfg := cfg.(*Config)
	if r, ok := receivers[rCfg]; ok {
		r.nextLogs = nextConsumer
		return r, nil
	}
	r, err := newLoggregatorReceiver(rCfg, &set)
	if err != nil {
		return nil, err
	}
	r.nextLogs = nextConsumer
	receivers[rCfg] = r
	return r, nil
}

var receivers = make(map[*Config]*loggregatorReceiver)
