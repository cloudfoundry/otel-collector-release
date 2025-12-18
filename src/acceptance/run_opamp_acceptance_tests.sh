#!/bin/bash

set -e

echo "🧪 Running OpAMP Acceptance Tests"
echo "================================="

# Ensure we're in the acceptance directory
cd "$(dirname "${BASH_SOURCE[0]}")"

# Check prerequisites
echo "🔍 Checking prerequisites..."

# Check if BOSH CLI is available
if ! command -v bosh &> /dev/null; then
    echo "❌ BOSH CLI is required but not found. Please install BOSH CLI."
    exit 1
fi

# Check if CF CLI is available
if ! command -v cf &> /dev/null; then
    echo "❌ CF CLI is required but not found. Please install CF CLI."
    exit 1
fi

# Check if we can connect to BOSH
if ! bosh env &> /dev/null; then
    echo "❌ Cannot connect to BOSH. Please set up BOSH environment."
    echo "   Run: bosh login"
    exit 1
fi

# Check if we can connect to CF
if ! cf target &> /dev/null; then
    echo "❌ Cannot connect to CF. Please set up CF target."
    echo "   Run: cf login"
    exit 1
fi

echo "✅ Prerequisites check passed"

# Get deployment information
echo "📋 Getting deployment information..."
DEPLOYMENT_NAME=$(bosh deployments --json | jq -r '.Tables[0].Rows[] | select(.name | contains("otel")) | .name' | head -1)

if [ -z "$DEPLOYMENT_NAME" ]; then
    echo "❌ No OTel deployment found. Please deploy the tanzu-otel-collector-release first."
    echo "   Available deployments:"
    bosh deployments
    exit 1
fi

echo "🎯 Using deployment: $DEPLOYMENT_NAME"

# Set BOSH deployment
export BOSH_DEPLOYMENT="$DEPLOYMENT_NAME"

# Check if OpAMP is enabled in the deployment
echo "🔍 Checking OpAMP configuration in deployment..."
OPAMP_ENABLED=$(bosh manifest | grep -c "opamp.enabled.*true" || echo "0")

if [ "$OPAMP_ENABLED" -gt 0 ]; then
    echo "✅ OpAMP is enabled in deployment"
    OPAMP_MODE="enabled"
else
    echo "ℹ️  OpAMP is disabled in deployment"
    OPAMP_MODE="disabled"
fi

# Check available VMs
echo "📋 Checking available VMs..."
AVAILABLE_VMS=$(bosh vms --json | jq -r '.Tables[0].Rows[].instance')
echo "Available VMs: $AVAILABLE_VMS"

# Validate required VMs are present
REQUIRED_VMS=("diego-cell" "router")
for vm in "${REQUIRED_VMS[@]}"; do
    if ! echo "$AVAILABLE_VMS" | grep -q "$vm"; then
        echo "⚠️  Warning: Required VM type '$vm' not found. Some tests may be skipped."
    fi
done

# Run the acceptance tests
echo "🚀 Running OpAMP acceptance tests..."
echo ""

# Set test environment variables
export OPAMP_MODE
export BOSH_DEPLOYMENT

# Run tests with focus on OpAMP
if command -v ginkgo &> /dev/null; then
    echo "Using Ginkgo test runner..."
    ginkgo run --focus="OpAMP" --v --progress --trace
else
    echo "Using Go test runner..."
    go test -v -run="TestAcceptance" .
fi

echo ""
echo "🎉 OpAMP acceptance tests completed!"

# Generate test report summary
echo ""
echo "📊 Test Summary"
echo "==============="
echo "Deployment: $DEPLOYMENT_NAME"
echo "OpAMP Mode: $OPAMP_MODE"
echo "Available VMs: $(echo "$AVAILABLE_VMS" | wc -w)"
echo ""

if [ "$OPAMP_MODE" = "enabled" ]; then
    echo "✅ OpAMP-enabled tests executed"
    echo "   - OpAMP extension functionality"
    echo "   - OpAMP supervisor operations"
    echo "   - Health check endpoints"
    echo "   - Configuration validation"
else
    echo "ℹ️  OpAMP-disabled tests executed"
    echo "   - Standard collector functionality"
    echo "   - OpAMP absence validation"
fi

echo ""
echo "For detailed logs, check the test output above."
echo "For BOSH logs, run: bosh logs"
