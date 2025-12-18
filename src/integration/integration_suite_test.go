package integration_test

import (
	"encoding/json"
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

	path, err := gexec.Build("code.cloudfoundry.org/otel-collector-release/src/otel-collector")
	Expect(err).NotTo(HaveOccurred())
	cps.Collector = path

	// Build OpAMP supervisor - this will be available once the package is built
	supervisorPath, err := gexec.Build("code.cloudfoundry.org/otel-collector-release/src/opamp-supervisor-builder")
	if err != nil {
		// OpAMP supervisor not available yet, tests will skip
		cps.OpAMPSupervisor = ""
	} else {
		cps.OpAMPSupervisor = supervisorPath
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
