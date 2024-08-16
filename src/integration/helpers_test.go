package integration_test

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"strings"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"code.cloudfoundry.org/tlsconfig/certtest"
	colmetricspb "go.opentelemetry.io/proto/otlp/collector/metrics/v1"
	commonpb "go.opentelemetry.io/proto/otlp/common/v1"
	metricspb "go.opentelemetry.io/proto/otlp/metrics/v1"
)

func NewSimpleResourceMetrics(name string) metricspb.ResourceMetrics {
	return metricspb.ResourceMetrics{
		ScopeMetrics: []*metricspb.ScopeMetrics{
			{
				Metrics: []*metricspb.Metric{
					{
						Name: name,
						Data: &metricspb.Metric_Sum{
							Sum: &metricspb.Sum{
								AggregationTemporality: metricspb.AggregationTemporality_AGGREGATION_TEMPORALITY_CUMULATIVE,
								IsMonotonic:            true,
								DataPoints: []*metricspb.NumberDataPoint{
									{
										TimeUnixNano: uint64(0),
										Attributes: []*commonpb.KeyValue{
											{
												Key:   "instance_id",
												Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "dead-beef"}},
											},
										},
										Value: &metricspb.NumberDataPoint_AsInt{
											AsInt: int64(42),
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
