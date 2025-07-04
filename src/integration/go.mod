module code.cloudfoundry.org/otel-collector-release/src/integration

go 1.23.0

toolchain go1.24.1

require (
	code.cloudfoundry.org/otel-collector-release/src/otel-collector v0.0.0
	code.cloudfoundry.org/tlsconfig v0.29.0
	github.com/google/go-cmp v0.7.0
	github.com/onsi/ginkgo/v2 v2.23.4
	github.com/onsi/gomega v1.36.3
	go.opentelemetry.io/proto/otlp v1.7.0
	google.golang.org/grpc v1.73.0
	google.golang.org/protobuf v1.36.6
)

require (
	filippo.io/edwards25519 v1.1.0 // indirect
	github.com/alecthomas/participle/v2 v2.1.1 // indirect
	github.com/antchfx/xmlquery v1.4.1 // indirect
	github.com/antchfx/xpath v1.3.1 // indirect
	github.com/beorn7/perks v1.0.1 // indirect
	github.com/cenkalti/backoff/v4 v4.3.0 // indirect
	github.com/cespare/xxhash/v2 v2.3.0 // indirect
	github.com/davecgh/go-spew v1.1.2-0.20180830191138-d8f796af33cc // indirect
	github.com/ebitengine/purego v0.8.0 // indirect
	github.com/elastic/go-grok v0.3.1 // indirect
	github.com/elastic/lunes v0.1.0 // indirect
	github.com/expr-lang/expr v1.16.9 // indirect
	github.com/felixge/httpsnoop v1.0.4 // indirect
	github.com/fsnotify/fsnotify v1.7.0 // indirect
	github.com/go-logr/logr v1.4.2 // indirect
	github.com/go-logr/stdr v1.2.2 // indirect
	github.com/go-ole/go-ole v1.2.6 // indirect
	github.com/go-task/slim-sprig/v3 v3.0.0 // indirect
	github.com/go-viper/mapstructure/v2 v2.1.0 // indirect
	github.com/gobwas/glob v0.2.3 // indirect
	github.com/goccy/go-json v0.10.3 // indirect
	github.com/gogo/protobuf v1.3.2 // indirect
	github.com/golang/groupcache v0.0.0-20210331224755-41bb18bfe9da // indirect
	github.com/golang/snappy v0.0.4 // indirect
	github.com/google/pprof v0.0.0-20250403155104-27863c87afa6 // indirect
	github.com/google/uuid v1.6.0 // indirect
	github.com/grafana/regexp v0.0.0-20240518133315-a468a5bfb3bc // indirect
	github.com/grpc-ecosystem/grpc-gateway/v2 v2.26.3 // indirect
	github.com/hashicorp/go-version v1.7.0 // indirect
	github.com/hashicorp/golang-lru v1.0.2 // indirect
	github.com/hashicorp/golang-lru/v2 v2.0.7 // indirect
	github.com/iancoleman/strcase v0.3.0 // indirect
	github.com/inconshreveable/mousetrap v1.1.0 // indirect
	github.com/json-iterator/go v1.1.12 // indirect
	github.com/klauspost/compress v1.17.10 // indirect
	github.com/knadh/koanf/maps v0.1.1 // indirect
	github.com/knadh/koanf/providers/confmap v0.1.0 // indirect
	github.com/knadh/koanf/v2 v2.1.1 // indirect
	github.com/lufia/plan9stats v0.0.0-20211012122336-39d0f177ccd0 // indirect
	github.com/magefile/mage v1.15.0 // indirect
	github.com/mitchellh/copystructure v1.2.0 // indirect
	github.com/mitchellh/reflectwalk v1.0.2 // indirect
	github.com/modern-go/concurrent v0.0.0-20180306012644-bacd9c7ef1dd // indirect
	github.com/modern-go/reflect2 v1.0.2 // indirect
	github.com/mostynb/go-grpc-compression v1.2.3 // indirect
	github.com/munnerz/goautoneg v0.0.0-20191010083416-a7dc8b61c822 // indirect
	github.com/open-telemetry/opentelemetry-collector-contrib/exporter/fileexporter v0.111.0 // indirect
	github.com/open-telemetry/opentelemetry-collector-contrib/exporter/prometheusexporter v0.111.0 // indirect
	github.com/open-telemetry/opentelemetry-collector-contrib/exporter/prometheusremotewriteexporter v0.111.0 // indirect
	github.com/open-telemetry/opentelemetry-collector-contrib/exporter/splunkhecexporter v0.111.0 // indirect
	github.com/open-telemetry/opentelemetry-collector-contrib/extension/pprofextension v0.111.0 // indirect
	github.com/open-telemetry/opentelemetry-collector-contrib/internal/coreinternal v0.111.0 // indirect
	github.com/open-telemetry/opentelemetry-collector-contrib/internal/filter v0.111.0 // indirect
	github.com/open-telemetry/opentelemetry-collector-contrib/internal/pdatautil v0.111.0 // indirect
	github.com/open-telemetry/opentelemetry-collector-contrib/internal/sharedcomponent v0.111.0 // indirect
	github.com/open-telemetry/opentelemetry-collector-contrib/internal/splunk v0.111.0 // indirect
	github.com/open-telemetry/opentelemetry-collector-contrib/pkg/batchperresourceattr v0.111.0 // indirect
	github.com/open-telemetry/opentelemetry-collector-contrib/pkg/ottl v0.111.0 // indirect
	github.com/open-telemetry/opentelemetry-collector-contrib/pkg/pdatautil v0.111.0 // indirect
	github.com/open-telemetry/opentelemetry-collector-contrib/pkg/resourcetotelemetry v0.111.0 // indirect
	github.com/open-telemetry/opentelemetry-collector-contrib/pkg/translator/prometheus v0.111.0 // indirect
	github.com/open-telemetry/opentelemetry-collector-contrib/pkg/translator/prometheusremotewrite v0.111.0 // indirect
	github.com/open-telemetry/opentelemetry-collector-contrib/processor/filterprocessor v0.111.0 // indirect
	github.com/open-telemetry/opentelemetry-collector-contrib/processor/transformprocessor v0.111.0 // indirect
	github.com/pkg/errors v0.9.1 // indirect
	github.com/pmezard/go-difflib v1.0.1-0.20181226105442-5d4384ee4fb2 // indirect
	github.com/power-devops/perfstat v0.0.0-20210106213030-5aafc221ea8c // indirect
	github.com/prometheus/client_golang v1.20.4 // indirect
	github.com/prometheus/client_model v0.6.1 // indirect
	github.com/prometheus/common v0.60.0 // indirect
	github.com/prometheus/procfs v0.15.1 // indirect
	github.com/prometheus/prometheus v0.54.1 // indirect
	github.com/rs/cors v1.11.1 // indirect
	github.com/shirou/gopsutil/v4 v4.24.9 // indirect
	github.com/spf13/cobra v1.8.1 // indirect
	github.com/spf13/pflag v1.0.5 // indirect
	github.com/square/certstrap v1.3.0 // indirect
	github.com/stretchr/testify v1.10.0 // indirect
	github.com/tidwall/gjson v1.10.2 // indirect
	github.com/tidwall/match v1.1.1 // indirect
	github.com/tidwall/pretty v1.2.0 // indirect
	github.com/tidwall/tinylru v1.1.0 // indirect
	github.com/tidwall/wal v1.1.7 // indirect
	github.com/tklauser/go-sysconf v0.3.12 // indirect
	github.com/tklauser/numcpus v0.6.1 // indirect
	github.com/ua-parser/uap-go v0.0.0-20240611065828-3a4781585db6 // indirect
	github.com/yusufpapurcu/wmi v1.2.4 // indirect
	go.opentelemetry.io/auto/sdk v1.1.0 // indirect
	go.opentelemetry.io/collector v0.111.0 // indirect
	go.opentelemetry.io/collector/client v1.17.0 // indirect
	go.opentelemetry.io/collector/component v0.111.0 // indirect
	go.opentelemetry.io/collector/component/componentprofiles v0.111.0 // indirect
	go.opentelemetry.io/collector/component/componentstatus v0.111.0 // indirect
	go.opentelemetry.io/collector/config/configauth v0.111.0 // indirect
	go.opentelemetry.io/collector/config/configcompression v1.17.0 // indirect
	go.opentelemetry.io/collector/config/configgrpc v0.111.0 // indirect
	go.opentelemetry.io/collector/config/confighttp v0.111.0 // indirect
	go.opentelemetry.io/collector/config/confignet v1.17.0 // indirect
	go.opentelemetry.io/collector/config/configopaque v1.17.0 // indirect
	go.opentelemetry.io/collector/config/configretry v1.17.0 // indirect
	go.opentelemetry.io/collector/config/configtelemetry v0.111.0 // indirect
	go.opentelemetry.io/collector/config/configtls v1.17.0 // indirect
	go.opentelemetry.io/collector/config/internal v0.111.0 // indirect
	go.opentelemetry.io/collector/confmap v1.17.0 // indirect
	go.opentelemetry.io/collector/confmap/provider/envprovider v1.17.0 // indirect
	go.opentelemetry.io/collector/confmap/provider/fileprovider v1.17.0 // indirect
	go.opentelemetry.io/collector/connector v0.111.0 // indirect
	go.opentelemetry.io/collector/connector/connectorprofiles v0.111.0 // indirect
	go.opentelemetry.io/collector/consumer v0.111.0 // indirect
	go.opentelemetry.io/collector/consumer/consumerprofiles v0.111.0 // indirect
	go.opentelemetry.io/collector/consumer/consumertest v0.111.0 // indirect
	go.opentelemetry.io/collector/exporter v0.111.0 // indirect
	go.opentelemetry.io/collector/exporter/exporterprofiles v0.111.0 // indirect
	go.opentelemetry.io/collector/exporter/nopexporter v0.111.0 // indirect
	go.opentelemetry.io/collector/exporter/otlpexporter v0.111.0 // indirect
	go.opentelemetry.io/collector/extension v0.111.0 // indirect
	go.opentelemetry.io/collector/extension/auth v0.111.0 // indirect
	go.opentelemetry.io/collector/extension/experimental/storage v0.111.0 // indirect
	go.opentelemetry.io/collector/extension/extensioncapabilities v0.111.0 // indirect
	go.opentelemetry.io/collector/featuregate v1.17.0 // indirect
	go.opentelemetry.io/collector/internal/globalgates v0.111.0 // indirect
	go.opentelemetry.io/collector/internal/globalsignal v0.111.0 // indirect
	go.opentelemetry.io/collector/otelcol v0.111.0 // indirect
	go.opentelemetry.io/collector/pdata v1.17.0 // indirect
	go.opentelemetry.io/collector/pdata/pprofile v0.111.0 // indirect
	go.opentelemetry.io/collector/pdata/testdata v0.111.0 // indirect
	go.opentelemetry.io/collector/pipeline v0.111.0 // indirect
	go.opentelemetry.io/collector/processor v0.111.0 // indirect
	go.opentelemetry.io/collector/processor/batchprocessor v0.111.0 // indirect
	go.opentelemetry.io/collector/processor/memorylimiterprocessor v0.111.0 // indirect
	go.opentelemetry.io/collector/processor/processorprofiles v0.111.0 // indirect
	go.opentelemetry.io/collector/receiver v0.111.0 // indirect
	go.opentelemetry.io/collector/receiver/otlpreceiver v0.111.0 // indirect
	go.opentelemetry.io/collector/receiver/receiverprofiles v0.111.0 // indirect
	go.opentelemetry.io/collector/semconv v0.111.0 // indirect
	go.opentelemetry.io/collector/service v0.111.0 // indirect
	go.opentelemetry.io/contrib/config v0.10.0 // indirect
	go.opentelemetry.io/contrib/instrumentation/google.golang.org/grpc/otelgrpc v0.60.0 // indirect
	go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp v0.60.0 // indirect
	go.opentelemetry.io/contrib/propagators/b3 v1.30.0 // indirect
	go.opentelemetry.io/otel v1.35.0 // indirect
	go.opentelemetry.io/otel/exporters/otlp/otlplog/otlploghttp v0.6.0 // indirect
	go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetricgrpc v1.30.0 // indirect
	go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetrichttp v1.30.0 // indirect
	go.opentelemetry.io/otel/exporters/otlp/otlptrace v1.30.0 // indirect
	go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc v1.30.0 // indirect
	go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp v1.30.0 // indirect
	go.opentelemetry.io/otel/exporters/prometheus v0.52.0 // indirect
	go.opentelemetry.io/otel/exporters/stdout/stdoutlog v0.6.0 // indirect
	go.opentelemetry.io/otel/exporters/stdout/stdoutmetric v1.30.0 // indirect
	go.opentelemetry.io/otel/exporters/stdout/stdouttrace v1.30.0 // indirect
	go.opentelemetry.io/otel/log v0.6.0 // indirect
	go.opentelemetry.io/otel/metric v1.35.0 // indirect
	go.opentelemetry.io/otel/sdk v1.35.0 // indirect
	go.opentelemetry.io/otel/sdk/log v0.6.0 // indirect
	go.opentelemetry.io/otel/sdk/metric v1.35.0 // indirect
	go.opentelemetry.io/otel/trace v1.35.0 // indirect
	go.step.sm/crypto v0.66.0 // indirect
	go.uber.org/automaxprocs v1.6.0 // indirect
	go.uber.org/multierr v1.11.0 // indirect
	go.uber.org/zap v1.27.0 // indirect
	golang.org/x/crypto v0.39.0 // indirect
	golang.org/x/exp v0.0.0-20250408133849-7e4ce0ab07d0 // indirect
	golang.org/x/net v0.40.0 // indirect
	golang.org/x/sys v0.33.0 // indirect
	golang.org/x/text v0.26.0 // indirect
	golang.org/x/tools v0.33.0 // indirect
	gonum.org/v1/gonum v0.15.1 // indirect
	google.golang.org/genproto/googleapis/api v0.0.0-20250528174236-200df99c418a // indirect
	google.golang.org/genproto/googleapis/rpc v0.0.0-20250528174236-200df99c418a // indirect
	gopkg.in/natefinch/lumberjack.v2 v2.2.1 // indirect
	gopkg.in/yaml.v2 v2.4.0 // indirect
	gopkg.in/yaml.v3 v3.0.1 // indirect
)

replace code.cloudfoundry.org/otel-collector-release/src/otel-collector => ../otel-collector
