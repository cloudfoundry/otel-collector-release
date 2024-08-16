package integration_test

import (
	"bytes"
	"context"
	"embed"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"text/template"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gbytes"
	"github.com/onsi/gomega/gexec"
	colmetricspb "go.opentelemetry.io/proto/otlp/collector/metrics/v1"
	metricspb "go.opentelemetry.io/proto/otlp/metrics/v1"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
	_ "google.golang.org/grpc/encoding/gzip"
)

//go:embed testdata/*
var f embed.FS

var _ = Describe("OTel Collector", func() {
	var otelCollectorSession *gexec.Session
	var testOtelReceiver *grpc.Server
	var fakeMetricsServiceServer FakeMetricsServiceServer
	var msc colmetricspb.MetricsServiceClient
	var otelConfigVars OTelConfigVars
	var otelConfigPath string

	BeforeEach(func() {
		otelConfigVars = NewOTELConfigVars()

		lis, err := net.Listen("tcp", fmt.Sprintf(":%d", otelConfigVars.EgressOTLPPort))
		Expect(err).NotTo(HaveOccurred())

		tlsCert, err := otelConfigVars.TLSCert()
		Expect(err).NotTo(HaveOccurred())
		testOtelReceiver = grpc.NewServer(grpc.Creds(credentials.NewServerTLSFromCert(&tlsCert)))

		fakeMetricsServiceServer = NewFakeMetricsServiceServer()
		colmetricspb.RegisterMetricsServiceServer(testOtelReceiver, fakeMetricsServiceServer)
		go testOtelReceiver.Serve(lis)

		ca, err := otelConfigVars.CaAsTLSConfig()
		Expect(err).NotTo(HaveOccurred())
		creds := credentials.NewTLS(ca)

		conn, err := grpc.NewClient(fmt.Sprintf("127.0.0.1:%d", otelConfigVars.IngressOTLPPort),
			grpc.WithTransportCredentials(creds),
		)
		Expect(err).NotTo(HaveOccurred())
		msc = colmetricspb.NewMetricsServiceClient(conn)
	})

	JustBeforeEach(func() {
		t, err := template.ParseFS(f, fmt.Sprintf("testdata/%s", otelConfigPath))
		Expect(err).NotTo(HaveOccurred())

		dir := fmt.Sprintf("./tmp-%d", GinkgoParallelProcess())
		os.MkdirAll(dir, 0700)
		DeferCleanup(os.RemoveAll, dir)
		configPath := filepath.Join(dir, "config.yml")

		buf := new(bytes.Buffer)
		err = t.Execute(buf, otelConfigVars)
		Expect(err).NotTo(HaveOccurred())
		os.WriteFile(configPath, buf.Bytes(), 0660)

		cmd := exec.Command(componentPaths.Collector, fmt.Sprintf("--config=file:%s", configPath))
		otelCollectorSession, err = gexec.Start(cmd, GinkgoWriter, GinkgoWriter)
		Expect(err).NotTo(HaveOccurred())
		Eventually(otelCollectorSession.Err).Should(gbytes.Say(`Everything is ready. Begin running and processing data.`))
	})

	AfterEach(func() {
		otelCollectorSession.Kill()
		testOtelReceiver.Stop()
	})

	Describe("metrics", func() {
		BeforeEach(func() {
			otelConfigPath = "simple.yml"
		})

		It("can forward an otlp metric", func() {
			rm := NewSimpleResourceMetrics("goes_up")
			_, err := msc.Export(context.Background(), &colmetricspb.ExportMetricsServiceRequest{
				ResourceMetrics: []*metricspb.ResourceMetrics{&rm},
			})
			Expect(err).NotTo(HaveOccurred())
			var emsr *colmetricspb.ExportMetricsServiceRequest
			Eventually(fakeMetricsServiceServer.ExportMetricsServiceRequests, 5).Should(Receive(&emsr))
			Expect(emsr.GetResourceMetrics()[0].GetScopeMetrics()[0].GetMetrics()[0].Name).To(Equal("goes_up"))
		})

		Context("when a prometheus exporter is configured", func() {
			BeforeEach(func() {
				otelConfigPath = "prometheus_exporter.yml"
			})

			It("serves the metric over the promql endpoint", func() {
				rm := NewSimpleResourceMetrics("goes_down")
				_, err := msc.Export(context.Background(), &colmetricspb.ExportMetricsServiceRequest{
					ResourceMetrics: []*metricspb.ResourceMetrics{&rm},
				})
				Expect(err).NotTo(HaveOccurred())

				caConfig, err := otelConfigVars.CaAsTLSConfig()
				Expect(err).NotTo(HaveOccurred())
				client := &http.Client{
					Transport: &http.Transport{
						TLSClientConfig: caConfig,
					},
				}

				Eventually(func(g Gomega) []byte {
					response, err := client.Get(fmt.Sprintf("https://127.0.0.1:%d/metrics", otelConfigVars.Port))
					g.Expect(err).NotTo(HaveOccurred())
					body, err := io.ReadAll(response.Body)
					g.Expect(err).NotTo(HaveOccurred())
					return body
				}).Should(ContainSubstring("goes_down"))
			})
		})
	})
})
