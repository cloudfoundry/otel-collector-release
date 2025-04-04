package acceptance_test

import (
	"fmt"
	"os/exec"
	"strings"
	"testing"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

func TestAcceptance(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Acceptance Suite")
}

var (
	dora        = "dora"
	doraWindows = "dora-windows"
)
var _ = SynchronizedBeforeSuite(func() {
	orgName := "orgNameIprotsiuk"
	spaceName := "spaceNameIprotsiuk"

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
	PushApp(dora)
	PushApp(doraWindows)
}, func() {})

func CreateOrg(orgName string) {
	var cmd *exec.Cmd
	cmd = exec.Command("cf", "create-org", orgName)
	cmd.Stdout = GinkgoWriter
	cmd.Stderr = GinkgoWriter
	_ = cmd.Run()
}

func CreateSpace(org string, spaceName string) {
	var cmd *exec.Cmd
	cmd = exec.Command("cf", "create-space", spaceName, "-o", org)
	cmd.Stdout = GinkgoWriter
	cmd.Stderr = GinkgoWriter
	_ = cmd.Run()
}

func DeleteOrg(orgName string) {
	var cmd *exec.Cmd
	cmd = exec.Command("cf", "delete-org", "-f", orgName)
	cmd.Stdout = GinkgoWriter
	cmd.Stderr = GinkgoWriter
	_ = cmd.Run()
}

func DeleteSpace(spaceName string) {
	var cmd *exec.Cmd
	cmd = exec.Command("cf", "delete-space", "-f", spaceName)
	cmd.Stdout = GinkgoWriter
	cmd.Stderr = GinkgoWriter
	_ = cmd.Run()
}

func PushApp(appName string) {
	var pushCmd *exec.Cmd
	fmt.Printf("Pushing app %s\n", appName)
	if strings.Contains(appName, "windows") {
		pushCmd = exec.Command("cf", "push", appName, "-s", "windows")
	} else {
		pushCmd = exec.Command("cf", "push", appName)
	}
	pushCmd.Stdout = GinkgoWriter
	pushCmd.Stderr = GinkgoWriter
	_ = pushCmd.Run()
}
