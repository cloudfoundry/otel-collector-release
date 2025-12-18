package acceptance_test

import (
	"os/exec"
	"time"

	"github.com/onsi/gomega/gbytes"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"
)

var _ = Describe("OpAMP (Open Agent Management Protocol) - Simplified Implementation", func() {

	Context("When OpAMP is enabled (opamp.enabled=true) - Dual Process Mode", func() {
		It("should have OpAMP extension configured and loaded", func() {
			// Verify OpAMP extension is in configuration
			Eventually(func() error {
				return CheckOpAMPExtensionEnabled("diego-cell/0")
			}, 60*time.Second, 5*time.Second).Should(Succeed(), "OpAMP extension should be present in collector configuration")

			// Verify OpAMP extension is loaded and attempting connection
			Eventually(func(g Gomega) *gbytes.Buffer {
				return GetCollectorLogs("diego-cell/0", 200)
			}, 2*time.Minute).Should(gbytes.Say("opamp.*extension.*started"), "OpAMP extension should be started in collector logs")

			Eventually(func(g Gomega) *gbytes.Buffer {
				return GetCollectorLogs("diego-cell/0", 200)
			}, 2*time.Minute).Should(gbytes.Say("opamp.*connecting|opamp.*connection"), "OpAMP extension should attempt server connection")
		})

		// Health check endpoint test removed - health_check extension not included in collector build

		It("should have both collector and supervisor processes running", func() {
			ValidateDualProcessMode("diego-cell/0")
		})

		It("should use the wrapper script for process management", func() {
			Eventually(func(g Gomega) *gbytes.Buffer {
				boshCmd := exec.Command("bosh", "ssh", "diego-cell/0", "-c", "sudo cat /var/vcap/jobs/otel-collector/bin/bpm.yml | grep executable")
				session, err := gexec.Start(boshCmd, GinkgoWriter, GinkgoWriter)
				Expect(err).ShouldNot(HaveOccurred())
				return session.Wait(30 * time.Second).Out
			}, 60*time.Second).Should(gbytes.Say("otel-wrapper.sh"), "BPM should use the wrapper script")
		})
	})

	Context("When OpAMP supervisor is running (dual-process mode)", func() {
		It("should have supervisor properly configured and running", func() {
			// Verify supervisor binary exists
			Eventually(func() error {
				return CheckFileExists("diego-cell/0", "/var/vcap/packages/opamp-supervisor/opampsupervisor")
			}, 30*time.Second, 5*time.Second).Should(Succeed(), "OpAMP supervisor binary should exist")

			// Verify supervisor configuration exists
			Eventually(func() error {
				return CheckFileExists("diego-cell/0", "/var/vcap/jobs/opamp-supervisor/config/opamp-supervisor.yml")
			}, 30*time.Second, 5*time.Second).Should(Succeed(), "OpAMP supervisor config should exist")

			// Verify supervisor is running
			Eventually(func(g Gomega) *gbytes.Buffer {
				return CheckOpAMPSupervisorRunning("diego-cell/0")
			}, 60*time.Second).Should(gbytes.Say("opampsupervisor"), "OpAMP supervisor process should be running")

			// Verify supervisor startup logs
			WaitForOpAMPSupervisorStartup("diego-cell/0", 2*time.Minute)

			// Verify storage directory exists
			Eventually(func() error {
				return CheckDirectoryExists("diego-cell/0", "/var/vcap/store/opamp-supervisor")
			}, 60*time.Second, 5*time.Second).Should(Succeed(), "OpAMP storage directory should exist")
		})
	})

	Context("When OpAMP is disabled (opamp.enabled=false) - Single Process Mode", func() {
		It("should run in single process mode", func() {
			// Verify OpAMP extension is not in configuration
			Eventually(func() error {
				return CheckOpAMPExtensionDisabled("router/0")
			}, 30*time.Second, 5*time.Second).Should(Succeed(), "OpAMP extension should not be present when disabled")

			// Verify single process mode
			ValidateSingleProcessMode("router/0")

			// Verify single-process mode in logs
			Eventually(func(g Gomega) *gbytes.Buffer {
				return GetCollectorLogs("router/0", 50)
			}, 2*time.Minute).Should(gbytes.Say("Starting OpenTelemetry Collector \\(no OpAMP\\)"), "Should show single-process mode startup message")
		})
	})

	// Health Check Extension tests removed - extension not included in collector build

	Context("OpAMP Configuration Validation", func() {
		It("should have valid OpAMP configuration", func() {
			ValidateOpAMPConfiguration("diego-cell/0")
		})
	})

	Context("OpAMP Metrics and Monitoring", func() {
		It("should expose OpAMP metrics through the collector", func() {
			Eventually(func() error {
				boshCmd := exec.Command("bosh", "ssh", "diego-cell/0", "-c", "curl -s http://localhost:8888/metrics | grep -q 'otelcol_opamp'")
				boshCmd.Stdout = GinkgoWriter
				boshCmd.Stderr = GinkgoWriter
				return boshCmd.Run()
			}, 60*time.Second, 5*time.Second).Should(Succeed(), "OpAMP metrics should be available")
		})

		It("should show OpAMP connection status in metrics", func() {
			Eventually(func(g Gomega) *gbytes.Buffer {
				boshCmd := exec.Command("bosh", "ssh", "diego-cell/0", "-c", "curl -s http://localhost:8888/metrics")
				session, err := gexec.Start(boshCmd, GinkgoWriter, GinkgoWriter)
				Expect(err).ShouldNot(HaveOccurred())
				return session.Wait(30 * time.Second).Out
			}, 60*time.Second).Should(gbytes.Say("otelcol_opamp.*connection"), "OpAMP connection metrics should be present")
		})
	})

	Context("Windows Support", func() {
		It("should have OpAMP extension working on Windows cells", func() {
			Eventually(func(g Gomega) *gbytes.Buffer {
				boshCmd := exec.Command("bosh", "ssh", "windows2019-cell/0", "-c", "powershell -Command \"Get-Content C:\\var\\vcap\\jobs\\otel-collector\\config\\config.yml | Select-String 'opamp'\"")
				session, err := gexec.Start(boshCmd, GinkgoWriter, GinkgoWriter)
				Expect(err).ShouldNot(HaveOccurred())
				return session.Wait(60 * time.Second).Out
			}, 2*time.Minute).Should(gbytes.Say("opamp"), "OpAMP should be configured on Windows cells")
		})

		// Health check test removed - health_check extension not included in collector build
	})
})
