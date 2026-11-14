package integration_test

import (
	"bytes"
	"os"
	"os/exec"
	"path/filepath"
	"text/template"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gbytes"
	"github.com/onsi/gomega/gexec"
)

var _ = Describe("BOSH-rendered OTel Collector configuration validation", func() {
	for _, jobName := range []string{"otel-collector", "otel-collector-windows"} {
		Describe(jobName, func() {
			DescribeTable("validates the rendered configuration without starting the collector",
				func(receiverConfig, ingressPipelines string, exitCode int, errorMessage string) {
					t, err := template.ParseFS(f, "testdata/validate.yml")
					Expect(err).NotTo(HaveOccurred())
					buf := new(bytes.Buffer)
					Expect(t.Execute(buf, map[string]string{
						"ReceiverConfig":   receiverConfig,
						"IngressPipelines": ingressPipelines,
					})).To(Succeed())

					cmd := exec.Command("bundle", "exec", "ruby", "src/integration/testdata/render-config.rb", jobName)
					cmd.Dir = filepath.Join("..", "..")
					cmd.Stdin = buf
					renderSession, err := gexec.Start(cmd, GinkgoWriter, GinkgoWriter)
					Expect(err).NotTo(HaveOccurred())
					DeferCleanup(renderSession.Kill)
					Eventually(renderSession, 10*time.Second).Should(gexec.Exit(0))

					configPath := filepath.Join(GinkgoT().TempDir(), "config.yml")
					Expect(os.WriteFile(configPath, renderSession.Out.Contents(), 0600)).To(Succeed())
					cmd = exec.Command(componentPaths.Collector, "validate", "--config", configPath)
					session, err := gexec.Start(cmd, GinkgoWriter, GinkgoWriter)
					Expect(err).NotTo(HaveOccurred())
					DeferCleanup(session.Kill)
					Eventually(session, 10*time.Second).Should(gexec.Exit(exitCode))
					if errorMessage != "" {
						Expect(session.Err).To(gbytes.Say(errorMessage))
					}
				},
				Entry("a manually wired gRPC receiver", "{protocols: {grpc: {}}}", "[]", 0, ""),
				Entry("a manually wired receiver with missing protocols", "{}", "[]", 1, "must specify at least one protocol"),
				Entry("a manually wired receiver with empty protocols", "{protocols: {}}", "[]", 1, "must specify at least one protocol"),
				Entry("default ingress replaces the operator receiver and adds missing-signal pipelines", "{}", "null", 0, ""),
			)
		})
	}
})
