package loggregatorreceiver

import (
	"errors"

	"go.opentelemetry.io/collector/component"
	"go.opentelemetry.io/collector/config/configgrpc"
	"go.opentelemetry.io/collector/confmap"
)

const (
	// Protocol values.
	protoV1 = "protocols::v1"
	protoV2 = "protocols::v2"
)

// V1Config is the configuration for the Loggregator v1 server.
type V1Config struct {
	// Port configures the UDP port for receiving Loggregator v1 envelopes via UDP.
	Port int `mapstructure:"port"`
}

// V2Config is the configuration for the Loggregator v2 server.
type V2Config struct {
	GRPC *configgrpc.GRPCServerSettings `mapstructure:"grpc"`
}

// Protocols is the configuration for the supported protocols.
type Protocols struct {
	V1 *V1Config `mapstructure:"v1"`
	V2 *V2Config `mapstructure:"v2"`
}

type Config struct {
	Protocols `mapstructure:"protocols"`
}

var _ component.Config = (*Config)(nil)
var _ confmap.Unmarshaler = (*Config)(nil)

// Validate checks the receiver configuration is valid.
func (cfg *Config) Validate() error {
	if cfg.V1 == nil && cfg.V2 == nil {
		return errors.New("must specify at least one protocol when using the loggregator receiver")
	}
	return nil
}

// Unmarshal a confmap.Conf into the config struct.
func (cfg *Config) Unmarshal(conf *confmap.Conf) error {
	// first load the config normally
	err := conf.Unmarshal(cfg)
	if err != nil {
		return err
	}

	if !conf.IsSet(protoV1) {
		cfg.V1 = nil
	}

	if !conf.IsSet(protoV2) {
		cfg.V2 = nil
	}

	return nil
}
