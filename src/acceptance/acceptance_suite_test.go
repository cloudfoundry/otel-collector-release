package acceptance_test

import (
	"os/exec"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/onsi/gomega/gbytes"
	"github.com/onsi/gomega/gexec"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

func TestAcceptance(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Acceptance Suite")
}

const (
	dora        = "dora-app"
	doraWindows = "dora-windows-app"
	orgName     = "otelAcceptanceTestOrg"
	spaceName   = "otelAcceptanceTestSpace"
)

var _ = SynchronizedBeforeSuite(func() {

	// delete the org before test just in case it already exists
	DeleteOrg(orgName)
	CreateOrg(orgName)
	DeferCleanup(func() {
		DeleteOrg(orgName)
	})
	CreateSpace(orgName, spaceName)
	DeferCleanup(func() {
		DeleteSpace(spaceName)
	})

	targetCmd := exec.Command("cf", "target", "-o", orgName, "-s", spaceName)
	targetCmd.Stdout = GinkgoWriter
	targetCmd.Stderr = GinkgoWriter
	Eventually(targetCmd.Run, 60*time.Second, 5*time.Second).Should(Succeed())

	var wg sync.WaitGroup
	wg.Add(2)

	go func() {
		defer wg.Done()
		PushApp(dora)
	}()
	go func() {
		defer wg.Done()
		PushApp(doraWindows)
	}()
	wg.Wait()
}, func() {})

func CreateOrg(orgName string) {
	Eventually(func() error {
		cmd := exec.Command("cf", "create-org", orgName)
		cmd.Stdout = GinkgoWriter
		cmd.Stderr = GinkgoWriter
		return cmd.Run()
	}, 15*time.Second, 5*time.Second).Should(Succeed(), "failed to create org")
}

func CreateSpace(org string, spaceName string) {
	Eventually(func() error {
		cmd := exec.Command("cf", "create-space", spaceName, "-o", org)
		cmd.Stdout = GinkgoWriter
		cmd.Stderr = GinkgoWriter
		return cmd.Run()
	}, 15*time.Second, 5*time.Second).Should(Succeed(), "failed to create space")
}

func DeleteOrg(orgName string) {
	Eventually(func() error {
		cmd := exec.Command("cf", "delete-org", "-f", orgName)
		cmd.Stdout = GinkgoWriter
		cmd.Stderr = GinkgoWriter
		return cmd.Run()
	}, 15*time.Second, 5*time.Second).Should(Succeed(), "failed to delete org")
}

func DeleteSpace(spaceName string) {
	Eventually(func() error {
		cmd := exec.Command("cf", "delete-space", "-f", spaceName)
		cmd.Stdout = GinkgoWriter
		cmd.Stderr = GinkgoWriter
		return cmd.Run()
	}, 15*time.Second, 5*time.Second).Should(Succeed(), "failed to delete space")
}

// PushApp attempts to push an app which should always fail
// because we are not giving a real app, however it should generate logs.
// By checking for a specific string in output we are confirming
// that the process exited where we need.
func PushApp(appName string) {
	Eventually(func(g Gomega) *gbytes.Buffer {
		var pushCmd *exec.Cmd
		if strings.Contains(appName, "windows") {
			pushCmd = exec.Command("cf", "push", appName, "-s", "windows")
		} else {
			pushCmd = exec.Command("cf", "push", appName)
		}
		session, err := gexec.Start(pushCmd, GinkgoWriter, GinkgoWriter)
		Expect(err).ShouldNot(HaveOccurred())
		return session.Wait(5 * time.Minute).Out
	}, 5*time.Minute).Should(gbytes.Say("Staging app and tracing logs..."))
}
