package main

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"gopkg.in/yaml.v3"
)

type Config struct {
	Dist struct {
		Module     string `yaml:"module"`
		Name       string `yaml:"name"`
		Description string `yaml:"description"`
		Version    string `yaml:"version"`
		OutputPath string `yaml:"output_path"`
		GoModFile  string `yaml:"go_mod_file"`
	} `yaml:"dist"`
	Supervisor struct {
		BaseModule string `yaml:"base_module"`
		Version    string `yaml:"version"`
	} `yaml:"supervisor"`
	Collector struct {
		ExecutablePath string `yaml:"executable_path"`
	} `yaml:"collector"`
}

func main() {
	if len(os.Args) < 2 {
		log.Fatal("Usage: go run main.go <config.yaml>")
	}

	configFile := os.Args[1]
	
	// Read configuration
	data, err := os.ReadFile(configFile)
	if err != nil {
		log.Fatalf("Failed to read config file: %v", err)
	}

	var config Config
	if err := yaml.Unmarshal(data, &config); err != nil {
		log.Fatalf("Failed to parse config: %v", err)
	}

	fmt.Printf("Building OpAMP Supervisor: %s\n", config.Dist.Name)
	fmt.Printf("Version: %s\n", config.Dist.Version)
	fmt.Printf("Output: %s\n", config.Dist.OutputPath)

	// Create output directory
	outputDir := config.Dist.OutputPath
	if err := os.MkdirAll(outputDir, 0755); err != nil {
		log.Fatalf("Failed to create output directory: %v", err)
	}

	// Generate go.mod for the supervisor
	goModPath := filepath.Join(outputDir, "go.mod")
	goModContent := fmt.Sprintf(`module %s

go 1.24

require (
	%s %s
)
`, config.Dist.Module, config.Supervisor.BaseModule, config.Supervisor.Version)

	if err := os.WriteFile(goModPath, []byte(goModContent), 0644); err != nil {
		log.Fatalf("Failed to write go.mod: %v", err)
	}

	// Change to output directory
	if err := os.Chdir(outputDir); err != nil {
		log.Fatalf("Failed to change directory: %v", err)
	}

	// Download the supervisor module
	fmt.Println("Downloading supervisor module...")
	cmd := exec.Command("go", "get", fmt.Sprintf("%s@%s", config.Supervisor.BaseModule, config.Supervisor.Version))
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		log.Fatalf("Failed to download supervisor module: %v", err)
	}

	// Build the supervisor directly from the module
	fmt.Println("Building supervisor binary...")
	binaryName := "opampsupervisor"
	cmd = exec.Command("go", "build", "-o", binaryName, config.Supervisor.BaseModule)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		log.Fatalf("Failed to build supervisor: %v", err)
	}

	fmt.Printf("✅ Successfully built OpAMP Supervisor: %s/%s\n", outputDir, binaryName)
}
