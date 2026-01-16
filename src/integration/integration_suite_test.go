package integration_test

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"
)

func TestIntegration(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Integration Suite")
}

type ComponentPaths struct {
	Collector       string `json:"collector"`
	OpAMPSupervisor string `json:"opamp_supervisor"`
}

func NewComponentPaths() ComponentPaths {
	cps := ComponentPaths{}

	// Use pre-built collector binary from src/otel-collector/otelcol-cf
	// This ensures we're testing the actual built collector with all extensions (including opamp)
	collectorPath := "../otel-collector/otelcol-cf"
	if _, err := os.Stat(collectorPath); err == nil {
		absPath, err := filepath.Abs(collectorPath)
		if err == nil {
			cps.Collector = absPath
		}
	} else {
		// Fallback to building from source if pre-built binary doesn't exist
		path, err := gexec.Build("code.cloudfoundry.org/otel-collector-release/src/otel-collector")
		Expect(err).NotTo(HaveOccurred())
		cps.Collector = path
	}

	// Use pre-built OpAMP supervisor binary from src/opamp-supervisor/opampsupervisor
	// The supervisor is built by opamp-supervisor-builder and committed to src/opamp-supervisor/
	supervisorPath := "../opamp-supervisor/opampsupervisor"
	if _, err := os.Stat(supervisorPath); err == nil {
		absPath, err := filepath.Abs(supervisorPath)
		if err == nil {
			cps.OpAMPSupervisor = absPath
		}
	}

	return cps
}

func (cps *ComponentPaths) Marshal() []byte {
	data, err := json.Marshal(cps)
	Expect(err).NotTo(HaveOccurred())
	return data
}

var componentPaths ComponentPaths

var _ = SynchronizedBeforeSuite(func() []byte {
	cps := NewComponentPaths()
	return cps.Marshal()
}, func(data []byte) {
	Expect(json.Unmarshal(data, &componentPaths)).To(Succeed())
})

var _ = SynchronizedAfterSuite(func() {}, func() {
	gexec.CleanupBuildArtifacts()
})
