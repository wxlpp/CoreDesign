#!/bin/bash
set -euo pipefail

# Generate snapshot PNGs for all components

cd "$(dirname "$0")/.."
mkdir -p docs/snapshots

TEST_RUNNER_SNAPSHOTS_EXPORT_DIR=docs/snapshots \
xcodebuild test \
  -project App/CoreDesignPreview.xcodeproj \
  -scheme SnapshotTests \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -quiet

echo "Snapshots saved to docs/snapshots/"
ls -la docs/snapshots/*.png | wc -l
echo "PNGs generated"
