package acceptance_test

import (
	"time"

	"github.com/onsi/gomega/gbytes"

	"os/exec"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"
)

var _ = Describe("OTel Collector", func() {

	Describe("writes logs to respective files", func() {
		It("writes resourceSpans", func() {
			Eventually(func() error {
				boshCmd := exec.Command("bosh", "ssh", "router/0", "-c", "sudo cat /var/vcap/data/otel-collector/tmp/otel-collector-traces.log | grep -q resourceSpans")
				boshCmd.Stdout = GinkgoWriter
				boshCmd.Stderr = GinkgoWriter
				return boshCmd.Run()
			}, 60*time.Second, 5*time.Second).Should(Succeed())
		})

		It("writes resourceMetrics", func() {
			boshCmd := exec.Command("bosh", "ssh", "diego-cell/0", "-c", "sudo cat /var/vcap/data/otel-collector/tmp/otel-collector-metrics.log | grep -q resourceMetrics")
			boshCmd.Stdout = GinkgoWriter
			boshCmd.Stderr = GinkgoWriter
			Eventually(boshCmd.Run, 60*time.Second, 5*time.Second).Should(Succeed())
		})

		It("writes resourceMetrics on windows", func() {
			Eventually(func(g Gomega) *gbytes.Buffer {
				boshCmd := exec.Command("bosh", "ssh", "windows2019-cell/0", "-c \"powershell -Command Get-Content C:\\tmp\\otel-collector-metrics.log -Tail 100\"")
				session, err := gexec.Start(boshCmd, GinkgoWriter, GinkgoWriter)
				Expect(err).ShouldNot(HaveOccurred())
				return session.Wait(15 * time.Second).Out
			}, 60*time.Second).Should(gbytes.Say("resourceMetrics"))
		})

		It("writes resourceLogs", func() {
			boshCmd := exec.Command("bosh", "ssh", "diego-cell/0", "-c", "sudo cat /var/vcap/data/otel-collector/tmp/otel-collector-logs.log | grep -q resourceLogs")
			boshCmd.Stdout = GinkgoWriter
			boshCmd.Stderr = GinkgoWriter
			Eventually(boshCmd.Run, 60*time.Second, 5*time.Second).Should(Succeed())
		})

		It("writes resourceLogs on windows", func() {
			Eventually(func(g Gomega) *gbytes.Buffer {
				boshCmd := exec.Command("bosh", "ssh", "windows2019-cell/0", "-c \"powershell -Command Get-Content C:\\tmp\\otel-collector-logs.log -Tail 500\"")
				session, err := gexec.Start(boshCmd, GinkgoWriter, GinkgoWriter)
				Expect(err).ShouldNot(HaveOccurred())
				return session.Wait(15 * time.Second).Out
			}, 60*time.Second).Should(gbytes.Say("resourceLogs"))
		})
	})
})
