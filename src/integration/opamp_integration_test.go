package integration_test

import (
	"fmt"
	"os/exec"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gbytes"
	"github.com/onsi/gomega/gexec"
)

var _ = Describe("OpAMP Integration - Simplified Implementation", func() {
	var wrapperSession *gexec.Session
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
		if wrapperSession != nil {
			wrapperSession.Kill()
		}
	})

	Describe("Single Process Mode (opamp.enabled=false)", func() {
		It("should start collector only", func() {
			configPath := createCollectorConfig(tempDir, "standard_collector.yml", otelConfigVars)

			cmd := exec.Command(componentPaths.Collector, fmt.Sprintf("--config=file:%s", configPath))
			var err error
			wrapperSession, err = gexec.Start(cmd, GinkgoWriter, GinkgoWriter)
			Expect(err).NotTo(HaveOccurred())

			// Wait for collector to be ready
			Eventually(wrapperSession.Err, 10*time.Second).Should(gbytes.Say(`Everything is ready. Begin running and processing data.`))
		})

		It("should collect and export host metrics", func() {
			// Skip - hostmetrics receiver not included in collector build
			Skip("hostmetrics receiver not included in collector build")
		})
	})

	Describe("Dual Process Mode (opamp.enabled=true)", func() {
		It("should start both collector and supervisor processes", func() {
			// Skip for now - we need wrapper script in test environment
			Skip("Wrapper script integration test requires BOSH job template evaluation")

			// This test would validate that the wrapper script:
			// 1. Starts both collector with OpAMP extension and supervisor
			// 2. Both processes are running simultaneously
			// 3. Collector has OpAMP extension loaded
			// 4. Supervisor attempts server connections
			// 5. Health check endpoint works
		})

		It("should start collector with OpAMP extension and handle server unavailability", func() {
			configPath := createCollectorConfig(tempDir, "opamp_extension_collector.yml", otelConfigVars)

			cmd := exec.Command(componentPaths.Collector, fmt.Sprintf("--config=file:%s", configPath))
			var err error
			wrapperSession, err = gexec.Start(cmd, GinkgoWriter, GinkgoWriter)
			Expect(err).NotTo(HaveOccurred())

			// Wait for collector to be ready
			Eventually(wrapperSession.Err, 10*time.Second).Should(gbytes.Say(`Everything is ready. Begin running and processing data.`))

			// Verify OpAMP extension is loaded
			Eventually(wrapperSession.Err, 5*time.Second).Should(gbytes.Say(`opamp.*extension`))

			// Verify OpAMP connection attempts (should fail since no server)
			Eventually(wrapperSession.Err, 10*time.Second).Should(gbytes.Say(`Failed to connect to the OpAMP server|Connection failed.*will retry`))

			// Verify retry logic is working
			Eventually(wrapperSession.Err, 15*time.Second).Should(gbytes.Say(`Connection failed.*will retry`))

			// Collector should continue running despite OpAMP connection failures
			Consistently(wrapperSession, 5*time.Second).ShouldNot(gexec.Exit())
		})
	})

	// Health Check Extension tests removed - extension not included in collector build

	Describe("Configuration Validation", func() {
		It("should reject invalid OpAMP extension configuration", func() {
			configPath := createCollectorConfig(tempDir, "invalid_opamp_collector.yml", otelConfigVars)

			cmd := exec.Command(componentPaths.Collector, fmt.Sprintf("--config=file:%s", configPath))
			var err error
			wrapperSession, err = gexec.Start(cmd, GinkgoWriter, GinkgoWriter)
			Expect(err).NotTo(HaveOccurred())

			// Should exit with configuration error
			Eventually(wrapperSession, 5*time.Second).Should(gexec.Exit())
			Expect(wrapperSession.Err).To(gbytes.Say(`failed to get config`))
		})

		It("should validate memory limiter configuration", func() {
			configPath := createCollectorConfig(tempDir, "invalid_memory_limiter_collector.yml", otelConfigVars)

			cmd := exec.Command(componentPaths.Collector, fmt.Sprintf("--config=file:%s", configPath))
			var err error
			wrapperSession, err = gexec.Start(cmd, GinkgoWriter, GinkgoWriter)
			Expect(err).NotTo(HaveOccurred())

			// Should exit with configuration error
			Eventually(wrapperSession, 5*time.Second).Should(gexec.Exit())
			Expect(wrapperSession.Err).To(gbytes.Say(`'check_interval' must be greater than zero`))
		})
	})
})
