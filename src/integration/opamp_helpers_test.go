package integration_test

import (
	"bytes"
	"embed"
	"fmt"
	"os"
	"path/filepath"
	"text/template"

	. "github.com/onsi/gomega"
)

//go:embed testdata/*
var opampTestData embed.FS

// createTempDir creates a temporary directory for test files
func createTempDir(dir string) error {
	return os.MkdirAll(dir, 0700)
}

// cleanupTempDir removes the temporary directory
func cleanupTempDir(dir string) {
	os.RemoveAll(dir)
}

// createCollectorConfig creates a collector configuration file from template
func createCollectorConfig(tempDir, templateName string, vars OTelConfigVars) string {
	t, err := template.ParseFS(opampTestData, fmt.Sprintf("testdata/%s", templateName))
	Expect(err).NotTo(HaveOccurred())

	configPath := filepath.Join(tempDir, "config.yml")
	buf := new(bytes.Buffer)
	err = t.Execute(buf, vars)
	Expect(err).NotTo(HaveOccurred())

	err = os.WriteFile(configPath, buf.Bytes(), 0660)
	Expect(err).NotTo(HaveOccurred())

	return configPath
}

// createSupervisorConfig creates an OpAMP supervisor configuration file
func createSupervisorConfig(tempDir string, vars OTelConfigVars) string {
	supervisorConfig := fmt.Sprintf(`server:
  endpoint: ws://localhost:%d/v1/opamp

agent:
  executable: %s

capabilities:
  accepts_remote_config: true
  reports_remote_config: true
  reports_effective_config: true
  reports_own_traces: true
  reports_own_metrics: true
  reports_own_logs: true
  reports_health: true

storage:
  directory: %s/opamp-storage
`, vars.OpAMPPort, componentPaths.Collector, tempDir)

	configPath := filepath.Join(tempDir, "supervisor-config.yaml")
	err := os.WriteFile(configPath, []byte(supervisorConfig), 0660)
	Expect(err).NotTo(HaveOccurred())

	// Create storage directory
	storageDir := filepath.Join(tempDir, "opamp-storage")
	err = os.MkdirAll(storageDir, 0700)
	Expect(err).NotTo(HaveOccurred())

	return configPath
}

// createInvalidSupervisorConfig creates an invalid OpAMP supervisor configuration
func createInvalidSupervisorConfig(tempDir string) string {
	invalidConfig := `server:
  endpoint: ws://localhost:4320/v1/opamp

agent:
  executable: /nonexistent/binary
  config_file: invalid_key  # This key is not supported

capabilities:
  invalid_capability: true  # This capability doesn't exist

storage:
  directory: /tmp/opamp-storage
`

	configPath := filepath.Join(tempDir, "invalid-supervisor-config.yaml")
	err := os.WriteFile(configPath, []byte(invalidConfig), 0660)
	Expect(err).NotTo(HaveOccurred())

	return configPath
}
