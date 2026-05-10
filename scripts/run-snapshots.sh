#!/bin/bash
set -euo pipefail

# Generate snapshot PNGs for all components

DEVICE="${SIMULATOR_DEVICE:-iPhone 17 Pro}"

cd "$(dirname "$0")/.."
mkdir -p docs/snapshots

TEST_RUNNER_SNAPSHOTS_EXPORT_DIR=docs/snapshots \
xcodebuild test \
  -project App/CoreDesignPreview.xcodeproj \
  -scheme SnapshotTests \
  -destination "platform=iOS Simulator,name=${DEVICE}" \
  -quiet

echo "Snapshots saved to docs/snapshots/"
count=$(find docs/snapshots -name "*.png" -type f | wc -l)
echo "${count} PNGs generated"
