package integration_test

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"encoding/hex"
	"strings"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	v11 "go.opentelemetry.io/proto/otlp/common/v1"
	v1 "go.opentelemetry.io/proto/otlp/resource/v1"

	"code.cloudfoundry.org/tlsconfig/certtest"
	collogspb "go.opentelemetry.io/proto/otlp/collector/logs/v1"
	colmetricspb "go.opentelemetry.io/proto/otlp/collector/metrics/v1"
	coltracepb "go.opentelemetry.io/proto/otlp/collector/trace/v1"
	commonpb "go.opentelemetry.io/proto/otlp/common/v1"
	logspb "go.opentelemetry.io/proto/otlp/logs/v1"
	metricspb "go.opentelemetry.io/proto/otlp/metrics/v1"
	tracepb "go.opentelemetry.io/proto/otlp/trace/v1"
)

func NewSimpleResourceMetrics() metricspb.ResourceMetrics {
	return metricspb.ResourceMetrics{
		Resource: &v1.Resource{},
		ScopeMetrics: []*metricspb.ScopeMetrics{
			{
				Scope: &v11.InstrumentationScope{},
				Metrics: []*metricspb.Metric{
					{
						Name: "system_disk_persistent_read_bytes",
						Unit: "Bytes",
						Data: &metricspb.Metric_Gauge{
							Gauge: &metricspb.Gauge{
								DataPoints: []*metricspb.NumberDataPoint{
									{
										TimeUnixNano: uint64(1741217715419374304),
										Attributes: []*commonpb.KeyValue{
											{
												Key:   "instance_id",
												Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: ""}},
											},
											{
												Key:   "source_id",
												Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "system_metrics_agent"}},
											},
											{
												Key:   "deployment",
												Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "appMetrics-dff15cf433f62cdc8cef"}},
											},
											{
												Key:   "index",
												Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "7b819535-2de6-46f6-9e25-730911deb2fe"}},
											},
											{
												Key:   "job",
												Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "db-and-errand-runner"}},
											},
											{
												Key:   "origin",
												Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "system_metrics_agent"}},
											},
											{
												Key:   "id",
												Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "7b819535-2de6-46f6-9e25-730911deb2fe"}},
											},
											{
												Key:   "product",
												Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "Small Footprint VMware Tanzu Application Service"}},
											},
											{
												Key:   "system_domain",
												Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "sys.kelp-3832350.cf-app.com"}},
											},
											{
												Key:   "instance_group",
												Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "db-and-errand-runner"}},
											},
											{
												Key:   "ip",
												Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "10.0.4.15"}},
											},
										},
										Value: &metricspb.NumberDataPoint_AsDouble{
											AsDouble: 5436416,
										},
									},
								},
							},
						},
					},
				},
			},
		},
	}
}

func NewSimpleLog() logspb.ResourceLogs {
	return logspb.ResourceLogs{
		Resource: &v1.Resource{},
		ScopeLogs: []*logspb.ScopeLogs{
			{
				Scope: &v11.InstrumentationScope{},
				LogRecords: []*logspb.LogRecord{
					{
						ObservedTimeUnixNano: uint64(1741217717582339523),
						TimeUnixNano:         uint64(1741217715635087516),
						SeverityText:         logspb.SeverityNumber_SEVERITY_NUMBER_INFO.String(),
						SeverityNumber:       logspb.SeverityNumber_SEVERITY_NUMBER_INFO,
						Body: &commonpb.AnyValue{
							Value: &commonpb.AnyValue_StringValue{
								StringValue: "Added process: \"web\"",
							},
						},
						Attributes: []*commonpb.KeyValue{
							{
								Key:   "instance_id",
								Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "0"}},
							},
							{
								Key:   "source_id",
								Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "64f96e84-e84d-4543-bf85-9cbfc567aa44"}},
							},
							{
								Key:   "space_name",
								Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "tanzu-hub-collector"}},
							},
							{
								Key:   "app_name",
								Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "tanzu-hub-sli-test-app"}},
							},
							{
								Key:   "product",
								Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "Small Footprint VMware Tanzu Application Service"}},
							},
							{
								Key:   "system_domain",
								Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "sys.kelp-3832350.cf-app.com"}},
							},
							{
								Key:   "organization_id",
								Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "6ac10a06-72ee-4f35-ab9b-a39f505b4ebf"}},
							},
							{
								Key:   "space_id",
								Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "bc5ee0ca-97f1-40ce-adb6-b363b86f2e46"}},
							},
							{
								Key:   "deployment",
								Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "cf-f8276f626bbef8bea7fe"}},
							},
							{
								Key:   "source_type",
								Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "API"}},
							},
							{
								Key:   "app_id",
								Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "64f96e84-e84d-4543-bf85-9cbfc567aa44"}},
							},
							{
								Key:   "origin",
								Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "cloud_controller"}},
							},
							{
								Key:   "organization_name",
								Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "system"}},
							},
							{
								Key:   "ip",
								Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "10.0.4.7"}},
							},
							{
								Key:   "job",
								Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "control"}},
							},
							{
								Key:   "index",
								Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "284c19a9-0d80-46a4-94e5-65a40362e9af"}},
							},
						},
					},
				},
			},
		},
	}
}

func NewSimpleTrace() tracepb.ResourceSpans {
	var traceBytes, _ = hex.DecodeString("f0db4801b9634b85636b69c94e622b26")
	var spanBytes, _ = hex.DecodeString("636b69c94e622b26")
	return tracepb.ResourceSpans{
		Resource: &v1.Resource{},
		ScopeSpans: []*tracepb.ScopeSpans{
			{
				Scope: &v11.InstrumentationScope{},
				Spans: []*tracepb.Span{
					{
						Status:            &tracepb.Status{},
						TraceId:           traceBytes,
						SpanId:            spanBytes,
						ParentSpanId:      []byte(""),
						Name:              "/",
						Kind:              2,
						StartTimeUnixNano: uint64(1741216325739358994),
						EndTimeUnixNano:   uint64(1741216325759969237),
						Attributes: []*commonpb.KeyValue{
							{
								Key:   "instance_id",
								Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "0"}},
							},
							{
								Key:   "source_id",
								Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "gorouter"}},
							},
							{
								Key:   "ip",
								Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "10.0.4.9"}},
							},
							{
								Key:   "request_id",
								Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "f0db4801-b963-4b85-636b-69c94e622b26"}},
							},
							{
								Key:   "uri",
								Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "https://log-store.sys.kelp-3832350.cf-app.com/"}},
							},
							{
								Key:   "routing_instance_id",
								Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: ""}},
							},
							{
								Key:   "method",
								Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "GET"}},
							},
							{
								Key:   "content_length",
								Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "70"}},
							},
							{
								Key:   "index",
								Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "7adb4db7-3755-48ba-88e9-6a02f85fdf3f"}},
							},
							{
								Key:   "origin",
								Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "gorouter"}},
							},
							{
								Key:   "deployment",
								Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "cf-f8276f626bbef8bea7fe"}},
							},
							{
								Key:   "job",
								Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "router"}},
							},
							{
								Key:   "forwarded",
								Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: ""}},
							},
							{
								Key:   "status_code",
								Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "200"}},
							},

							{
								Key:   "product",
								Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "Small Footprint VMware Tanzu Application Service"}},
							},
							{
								Key:   "system_domain",
								Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "sys.kelp-3832350.cf-app.com"}},
							},
							{
								Key:   "peer_type",
								Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "Server"}},
							},
							{
								Key:   "user_agent",
								Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "okhttp/4.11.0"}},
							},
							{
								Key:   "remote_address",
								Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "104.197.77.219:44444"}},
							},
						},
					},
				},
			},
		},
	}
}

type FakeLogsServiceServer struct {
	collogspb.LogsServiceServer
	ExportLogsServiceRequest chan *collogspb.ExportLogsServiceRequest
}

func NewFakeLogsServiceServer() FakeLogsServiceServer {
	return FakeLogsServiceServer{
		ExportLogsServiceRequest: make(chan *collogspb.ExportLogsServiceRequest, 10),
	}
}

func (f FakeLogsServiceServer) Export(ctx context.Context, elsr *collogspb.ExportLogsServiceRequest) (*collogspb.ExportLogsServiceResponse, error) {
	f.ExportLogsServiceRequest <- elsr
	return &collogspb.ExportLogsServiceResponse{}, nil
}

type FakeTracesServiceServer struct {
	coltracepb.TraceServiceServer
	ExportTracesServiceRequest chan *coltracepb.ExportTraceServiceRequest
}

func NewFakeTracesServiceServer() FakeTracesServiceServer {
	return FakeTracesServiceServer{
		ExportTracesServiceRequest: make(chan *coltracepb.ExportTraceServiceRequest, 10),
	}
}

func (f FakeTracesServiceServer) Export(ctx context.Context, elsr *coltracepb.ExportTraceServiceRequest) (*coltracepb.ExportTraceServiceResponse, error) {
	f.ExportTracesServiceRequest <- elsr
	return &coltracepb.ExportTraceServiceResponse{}, nil
}

type FakeMetricsServiceServer struct {
	colmetricspb.MetricsServiceServer
	ExportMetricsServiceRequests chan *colmetricspb.ExportMetricsServiceRequest
}

func NewFakeMetricsServiceServer() FakeMetricsServiceServer {
	return FakeMetricsServiceServer{
		ExportMetricsServiceRequests: make(chan *colmetricspb.ExportMetricsServiceRequest, 10),
	}
}

func (s FakeMetricsServiceServer) Export(ctx context.Context, emsr *colmetricspb.ExportMetricsServiceRequest) (*colmetricspb.ExportMetricsServiceResponse, error) {
	s.ExportMetricsServiceRequests <- emsr
	return &colmetricspb.ExportMetricsServiceResponse{}, nil
}

type OTelConfigVars struct {
	IngressOTLPPort int
	EgressOTLPPort  int
	MetricsPort     int
	Port            int
	CA              *certtest.Authority
	Cert            *certtest.Certificate
}

func NewOTELConfigVars() OTelConfigVars {
	ingressOTLPPort := 5000 + GinkgoParallelProcess()*100
	egressOTLPPort := 5000 + GinkgoParallelProcess()*100 + 1
	metricsPort := 5000 + GinkgoParallelProcess()*100 + 2
	port := 5000 + GinkgoParallelProcess()*100 + 3

	ca, err := certtest.BuildCA("otel")
	Expect(err).NotTo(HaveOccurred())
	cert, err := ca.BuildSignedCertificate("egress")
	Expect(err).NotTo(HaveOccurred())

	return OTelConfigVars{
		IngressOTLPPort: ingressOTLPPort,
		EgressOTLPPort:  egressOTLPPort,
		MetricsPort:     metricsPort,
		Port:            port,
		Cert:            cert,
		CA:              ca,
	}

}

func (o OTelConfigVars) CertPem() (string, error) {
	certPem, _, err := o.Cert.CertificatePEMAndPrivateKey()
	return strings.ReplaceAll(string(certPem), "\n", "\\n"), err
}

func (o OTelConfigVars) KeyPem() (string, error) {
	_, key, err := o.Cert.CertificatePEMAndPrivateKey()
	return strings.ReplaceAll(string(key), "\n", "\\n"), err
}

func (o OTelConfigVars) CaPem() (string, error) {
	caPem, err := o.CA.CertificatePEM()
	return strings.ReplaceAll(string(caPem), "\n", "\\n"), err
}

func (o *OTelConfigVars) TLSCert() (tls.Certificate, error) {
	tlsCert, err := o.Cert.TLSCertificate()
	return tlsCert, err
}

func (o OTelConfigVars) CaAsTLSConfig() (*tls.Config, error) {
	certPool := x509.NewCertPool()
	caPem, err := o.CA.CertificatePEM()
	if err != nil {
		return &tls.Config{}, err
	}
	if certPool.AppendCertsFromPEM(caPem) != true {
		return &tls.Config{}, err
	}

	return &tls.Config{
		RootCAs: certPool,
	}, nil
}
