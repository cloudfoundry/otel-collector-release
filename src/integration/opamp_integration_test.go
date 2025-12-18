package integration_test

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"os/exec"
	"path/filepath"
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
		It("should start collector only and respond to health checks", func() {
			configPath := createCollectorConfig(tempDir, "standard_collector.yml", otelConfigVars)

			cmd := exec.Command(componentPaths.Collector, fmt.Sprintf("--config=file:%s", configPath))
			var err error
			wrapperSession, err = gexec.Start(cmd, GinkgoWriter, GinkgoWriter)
			Expect(err).NotTo(HaveOccurred())

			// Wait for collector to be ready
			Eventually(wrapperSession.Err, 10*time.Second).Should(gbytes.Say(`Everything is ready. Begin running and processing data.`))

			// Verify only one process (collector) is running
			Eventually(wrapperSession.Out, 5*time.Second).Should(gbytes.Say(`Starting OpenTelemetry Collector \(no OpAMP\)`))

			// Test health check endpoint
			healthURL := fmt.Sprintf("http://127.0.0.1:%d", otelConfigVars.HealthCheckPort)
			Eventually(func() error {
				resp, err := http.Get(healthURL)
				if err != nil {
					return err
				}
				defer resp.Body.Close()
				if resp.StatusCode != http.StatusOK {
					return fmt.Errorf("health check failed with status: %d", resp.StatusCode)
				}
				return nil
			}, 5*time.Second, 500*time.Millisecond).Should(Succeed())
		})

		It("should collect and export host metrics", func() {
			configPath := createCollectorConfig(tempDir, "hostmetrics_collector.yml", otelConfigVars)

			cmd := exec.Command(componentPaths.Collector, fmt.Sprintf("--config=file:%s", configPath))
			var err error
			otelCollectorSession, err = gexec.Start(cmd, GinkgoWriter, GinkgoWriter)
			Expect(err).NotTo(HaveOccurred())

			// Wait for collector to be ready
			Eventually(otelCollectorSession.Err, 10*time.Second).Should(gbytes.Say(`Everything is ready. Begin running and processing data.`))

			// Check that host metrics are being collected (look for debug output)
			Eventually(otelCollectorSession.Out, 15*time.Second).Should(gbytes.Say(`system\.cpu\.time`))
			Eventually(otelCollectorSession.Out, 15*time.Second).Should(gbytes.Say(`system\.memory\.usage`))
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

		It("should start collector with OpAMP extension when wrapper not available", func() {
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
			Eventually(wrapperSession.Err, 10*time.Second).Should(gbytes.Say(`Failed to connect to the OpAMP server`))
			Eventually(wrapperSession.Err, 5*time.Second).Should(gbytes.Say(`Connection failed.*will retry`))

			// Test health check endpoint still works
			healthURL := fmt.Sprintf("http://127.0.0.1:%d", otelConfigVars.HealthCheckPort)
			Eventually(func() error {
				resp, err := http.Get(healthURL)
				if err != nil {
					return err
				}
				defer resp.Body.Close()
				if resp.StatusCode != http.StatusOK {
					return fmt.Errorf("health check failed with status: %d", resp.StatusCode)
				}
				return nil
			}, 5*time.Second, 500*time.Millisecond).Should(Succeed())
		})

		It("should gracefully handle OpAMP server unavailability", func() {
			configPath := createCollectorConfig(tempDir, "opamp_extension_collector.yml", otelConfigVars)

			cmd := exec.Command(componentPaths.Collector, fmt.Sprintf("--config=file:%s", configPath))
			var err error
			wrapperSession, err = gexec.Start(cmd, GinkgoWriter, GinkgoWriter)
			Expect(err).NotTo(HaveOccurred())

			// Wait for collector to be ready
			Eventually(wrapperSession.Err, 10*time.Second).Should(gbytes.Say(`Everything is ready. Begin running and processing data.`))

			// Verify retry logic is working
			Eventually(wrapperSession.Err, 15*time.Second).Should(gbytes.Say(`Connection failed.*will retry`))

			// Collector should continue running despite OpAMP connection failures
			Consistently(wrapperSession, 5*time.Second).ShouldNot(gexec.Exit())

			// Health check should still work
			healthURL := fmt.Sprintf("http://127.0.0.1:%d", otelConfigVars.HealthCheckPort)
			Consistently(func() error {
				resp, err := http.Get(healthURL)
				if err != nil {
					return err
				}
				defer resp.Body.Close()
				if resp.StatusCode != http.StatusOK {
					return fmt.Errorf("health check failed with status: %d", resp.StatusCode)
				}
				return nil
			}, 3*time.Second, 500*time.Millisecond).Should(Succeed())
		})
	})

	Describe("Health Check Extension", func() {
		It("should provide detailed health information", func() {
			configPath := createCollectorConfig(tempDir, "health_check_collector.yml", otelConfigVars)

			cmd := exec.Command(componentPaths.Collector, fmt.Sprintf("--config=file:%s", configPath))
			var err error
			wrapperSession, err = gexec.Start(cmd, GinkgoWriter, GinkgoWriter)
			Expect(err).NotTo(HaveOccurred())

			// Wait for collector to be ready
			Eventually(wrapperSession.Err, 10*time.Second).Should(gbytes.Say(`Everything is ready. Begin running and processing data.`))

			// Test health check endpoint
			healthURL := fmt.Sprintf("http://127.0.0.1:%d", otelConfigVars.HealthCheckPort)
			Eventually(func() (string, error) {
				resp, err := http.Get(healthURL)
				if err != nil {
					return "", err
				}
				defer resp.Body.Close()
				body, err := io.ReadAll(resp.Body)
				if err != nil {
					return "", err
				}
				return string(body), nil
			}, 5*time.Second, 500*time.Millisecond).Should(ContainSubstring("Server available"))
		})

		It("should report unhealthy state during shutdown", func() {
			configPath := createCollectorConfig(tempDir, "health_check_collector.yml", otelConfigVars)

			cmd := exec.Command(componentPaths.Collector, fmt.Sprintf("--config=file:%s", configPath))
			var err error
			wrapperSession, err = gexec.Start(cmd, GinkgoWriter, GinkgoWriter)
			Expect(err).NotTo(HaveOccurred())

			// Wait for collector to be ready
			Eventually(wrapperSession.Err, 10*time.Second).Should(gbytes.Say(`Everything is ready. Begin running and processing data.`))

			// Verify health check is working
			healthURL := fmt.Sprintf("http://127.0.0.1:%d", otelConfigVars.HealthCheckPort)
			Eventually(func() error {
				resp, err := http.Get(healthURL)
				if err != nil {
					return err
				}
				defer resp.Body.Close()
				if resp.StatusCode != http.StatusOK {
					return fmt.Errorf("health check failed with status: %d", resp.StatusCode)
				}
				return nil
			}, 5*time.Second, 500*time.Millisecond).Should(Succeed())

			// Initiate shutdown
			wrapperSession.Terminate()

			// Verify health check state change is logged
			Eventually(wrapperSession.Err, 5*time.Second).Should(gbytes.Say(`Health Check state change.*unavailable`))
		})
	})

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
