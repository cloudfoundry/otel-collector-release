package acceptance_test

import (
	"time"

	"github.com/onsi/gomega/gbytes"

	"os/exec"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"
)

var _ = Describe("OTel Collector configured with exporters to write to files", func() {

	Context("When the data is a trace", func() {
		It("resourceSpans can be read from the trace file on the router VM", func() {
			Eventually(func() error {
				boshCmd := exec.Command("bosh", "ssh", "router/0", "-c", "sudo cat /var/vcap/data/otel-collector/tmp/otel-collector-traces.log | grep -q resourceSpans")
				boshCmd.Stdout = GinkgoWriter
				boshCmd.Stderr = GinkgoWriter
				return boshCmd.Run()
			}, 60*time.Second, 5*time.Second).Should(Succeed())
		})
	})

	Context("When the data is a metric", func() {
		It("resourceMetrics can be read from the metrics file on the diego cell", func() {
			Eventually(func() error {
				boshCmd := exec.Command("bosh", "ssh", "diego-cell/0", "-c", "sudo cat /var/vcap/data/otel-collector/tmp/otel-collector-metrics.log | grep -q resourceMetrics")
				boshCmd.Stdout = GinkgoWriter
				boshCmd.Stderr = GinkgoWriter
				return boshCmd.Run()
			}, 60*time.Second, 5*time.Second).Should(Succeed())
		})

		It("resourceMetrics can be read from the metrics file on the windows diego cell", func() {
			Eventually(func(g Gomega) *gbytes.Buffer {
				boshCmd := exec.Command("bosh", "ssh", "windows2019-cell/0", "-c \"powershell -Command Get-Content C:\\tmp\\otel-collector-metrics.log -Tail 100\"")
				session, err := gexec.Start(boshCmd, GinkgoWriter, GinkgoWriter)
				Expect(err).ShouldNot(HaveOccurred())
				return session.Wait(60 * time.Second).Out
			}, 2*time.Minute).Should(gbytes.Say("resourceMetrics"))
		})
	})

	Context("When the data is a log", func() {
		It("resourceLogs can be read from the log file on the diego cell", func() {
			Eventually(func() error {
				boshCmd := exec.Command("bosh", "ssh", "diego-cell/0", "-c", "sudo cat /var/vcap/data/otel-collector/tmp/otel-collector-logs.log | grep -q resourceLogs")
				boshCmd.Stdout = GinkgoWriter
				boshCmd.Stderr = GinkgoWriter
				return boshCmd.Run()
			}, 60*time.Second, 5*time.Second).Should(Succeed())
		})

		It("resourceLogs can be read from the log file on the windows diego cell", func() {
			Eventually(func(g Gomega) *gbytes.Buffer {
				boshCmd := exec.Command("bosh", "ssh", "windows2019-cell/0", "-c \"powershell -Command Get-Content C:\\tmp\\otel-collector-logs.log -Tail 500\"")
				session, err := gexec.Start(boshCmd, GinkgoWriter, GinkgoWriter)
				Expect(err).ShouldNot(HaveOccurred())
				return session.Wait(60 * time.Second).Out
			}, 2*time.Minute).Should(gbytes.Say("resourceLogs"))
		})
	})
})
