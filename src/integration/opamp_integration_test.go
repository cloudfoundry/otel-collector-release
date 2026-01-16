package integration_test

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gbytes"
	"github.com/onsi/gomega/gexec"
)

var _ = Describe("OpAMP Integration - Simplified Implementation", func() {
	var collectorSession *gexec.Session
	var supervisorSession *gexec.Session
	var otelConfigVars OTelConfigVars
	var tempDir string

	BeforeEach(func() {
		otelConfigVars = NewOTELConfigVars()
		tempDir = fmt.Sprintf("./tmp-opamp-%d", GinkgoParallelProcess())
		err := createTempDir(tempDir)
		Expect(err).NotTo(HaveOccurred())
		DeferCleanup(cleanupTempDir, tempDir)
	})

	AfterEach(func() {
		if collectorSession != nil {
			collectorSession.Kill()
			collectorSession.Wait()
		}
		if supervisorSession != nil {
			supervisorSession.Kill()
			supervisorSession.Wait()
		}
	})

	Describe("Single Process Mode (opamp.enabled=false)", func() {
		It("should start collector only", func() {
			configPath := createCollectorConfig(tempDir, "standard_collector.yml", otelConfigVars)

			cmd := exec.Command(componentPaths.Collector, fmt.Sprintf("--config=file:%s", configPath))
			var err error
			collectorSession, err = gexec.Start(cmd, GinkgoWriter, GinkgoWriter)
			Expect(err).NotTo(HaveOccurred())

			// Wait for collector to be ready
			Eventually(collectorSession.Err, 10*time.Second).Should(gbytes.Say(`Everything is ready. Begin running and processing data.`))
		})

	})

	Describe("Dual Process Mode (opamp.enabled=true)", func() {
		BeforeEach(func() {
			if componentPaths.OpAMPSupervisor == "" {
				Skip("OpAMP supervisor binary not available")
			}
		})

		It("should verify supervisor binary exists and can be executed", func() {
			// Test that the supervisor binary is executable and can show help
			cmd := exec.Command(componentPaths.OpAMPSupervisor, "--help")
			helpSession, err := gexec.Start(cmd, GinkgoWriter, GinkgoWriter)
			Expect(err).NotTo(HaveOccurred())

			// Supervisor should exit successfully when showing help
			Eventually(helpSession, 5*time.Second).Should(gexec.Exit(0))

			// Help output should mention config
			helpOutput := string(helpSession.Out.Contents()) + string(helpSession.Err.Contents())
			Expect(helpOutput).To(ContainSubstring("config"))
		})

		It("should verify supervisor validates configuration", func() {
			// Create an invalid supervisor config (missing required fields)
			invalidConfig := `
server:
  endpoint: ""
agent:
  executable: ""
`
			configPath := filepath.Join(tempDir, "invalid-supervisor-config.yaml")
			err := os.WriteFile(configPath, []byte(invalidConfig), 0660)
			Expect(err).NotTo(HaveOccurred())

			// Start the supervisor with invalid config
			cmd := exec.Command(componentPaths.OpAMPSupervisor, fmt.Sprintf("--config=%s", configPath))
			supervisorSession, err = gexec.Start(cmd, GinkgoWriter, GinkgoWriter)
			Expect(err).NotTo(HaveOccurred())

			// Supervisor should exit with an error due to invalid configuration
			Eventually(supervisorSession, 10*time.Second).Should(gexec.Exit())
			// Exit code should be non-zero
			Expect(supervisorSession.ExitCode()).NotTo(Equal(0))
		})

		It("should start supervisor and attempt to connect to OpAMP server", func() {
			// Create collector configuration
			collectorConfigPath := createCollectorConfig(tempDir, "standard_collector.yml", otelConfigVars)

			// Create supervisor configuration that points to the collector
			supervisorConfigPath := createSupervisorConfigWithCollector(tempDir, collectorConfigPath, otelConfigVars)

			// Start the supervisor - it will attempt to start and connect to OpAMP server
			cmd := exec.Command(componentPaths.OpAMPSupervisor, fmt.Sprintf("--config=%s", supervisorConfigPath))
			var err error
			supervisorSession, err = gexec.Start(cmd, GinkgoWriter, GinkgoWriter)
			Expect(err).NotTo(HaveOccurred())

			// Give the supervisor time to start and attempt connections
			// The supervisor will continuously retry connecting to the OpAMP server
			time.Sleep(3 * time.Second)

			// Supervisor should continue running (not exit immediately)
			// This proves the supervisor starts correctly and handles server unavailability gracefully
			Expect(supervisorSession.ExitCode()).To(Equal(-1), "Supervisor should still be running (exit code -1 means not exited)")
		})

		// Note: Full integration testing of OpAMP supervisor with collector requires:
		// 1. An OpAMP server running, OR
		// 2. A pre-cached remote configuration in the storage directory
		// Per the OpAMP specification: "When the supervisor cannot connect to the OpAMP server,
		// the collector will be run with the last known configuration if a previous configuration
		// is persisted. If no previous configuration has been persisted, the collector does not run."
		// This is the expected behavior for security reasons - the supervisor needs authorization
		// from an OpAMP server before running arbitrary configurations.
	})

	Describe("Configuration Validation", func() {
		It("should validate memory limiter configuration", func() {
			configPath := createCollectorConfig(tempDir, "invalid_memory_limiter_collector.yml", otelConfigVars)

			cmd := exec.Command(componentPaths.Collector, fmt.Sprintf("--config=file:%s", configPath))
			var err error
			collectorSession, err = gexec.Start(cmd, GinkgoWriter, GinkgoWriter)
			Expect(err).NotTo(HaveOccurred())

			// Should exit with configuration error
			Eventually(collectorSession, 5*time.Second).Should(gexec.Exit())
			Expect(collectorSession.Err).To(gbytes.Say(`'check_interval' must be greater than zero`))
		})
	})
})
