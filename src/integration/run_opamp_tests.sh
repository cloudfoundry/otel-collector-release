#!/bin/bash

set -e

echo "🧪 Running OpAMP Integration Tests"
echo "=================================="

# Ensure we're in the integration directory
cd "$(dirname "${BASH_SOURCE[0]}")"

# Build the collector first
echo "📦 Building OpenTelemetry Collector..."
pushd ../otel-collector > /dev/null
go build -o otelcol-cf .
popd > /dev/null

# Build the OpAMP supervisor builder (if available)
echo "📦 Building OpAMP Supervisor Builder..."
if [ -d "../opamp-supervisor-builder" ]; then
    pushd ../opamp-supervisor-builder > /dev/null
    go build -o opampsupervisor-builder .
    popd > /dev/null
    echo "✅ OpAMP Supervisor Builder built successfully"
else
    echo "⚠️  OpAMP Supervisor Builder not found - supervisor tests will be skipped"
fi

# Run the integration tests
echo "🚀 Running integration tests..."
echo ""

# Run only OpAMP-related tests
ginkgo run --focus="OpAMP Integration" --v --progress --trace

echo ""
echo "✅ OpAMP Integration Tests completed!"
