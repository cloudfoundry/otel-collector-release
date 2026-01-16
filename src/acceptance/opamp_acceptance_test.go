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
			// Verify single process mode
			ValidateSingleProcessMode("router/0")

			// Verify single-process mode in logs
			Eventually(func(g Gomega) *gbytes.Buffer {
				return GetCollectorLogs("router/0", 50)
			}, 2*time.Minute).Should(gbytes.Say("Starting OpenTelemetry Collector \\(no OpAMP\\)"), "Should show single-process mode startup message")
		})
	})

	Context("OpAMP Supervisor Configuration Validation", func() {
		It("should have valid OpAMP supervisor configuration", func() {
			ValidateOpAMPSupervisorConfiguration("diego-cell/0")
		})
	})
})
