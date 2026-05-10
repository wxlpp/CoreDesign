#!/bin/bash
set -euo pipefail

# Generate snapshot PNGs for components with #Preview macros

DEVICE="${SIMULATOR_DEVICE:-iPhone 16 Pro}"

cd "$(dirname "$0")/.."
# Start fresh: remove all stale output (PNGs + metadata sidecars)
rm -rf docs/snapshots/
mkdir -p docs/snapshots

TEST_RUNNER_SNAPSHOTS_EXPORT_DIR=docs/snapshots \
xcodebuild test \
  -project App/CoreDesignPreview.xcodeproj \
  -scheme CoreDesignPreview \
  -destination "platform=iOS Simulator,name=${DEVICE}" \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -quiet

echo "Snapshots saved to docs/snapshots/"
count=$(find docs/snapshots -name "*.png" -type f | wc -l)
echo "${count} PNGs generated"
