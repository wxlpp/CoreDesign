#!/bin/bash
set -euo pipefail

# Generate snapshot PNGs for components with #Preview macros

DEVICE="${SIMULATOR_DEVICE:-iPhone 16 Pro}"

cd "$(dirname "$0")/.."
mkdir -p docs/snapshots
# Remove stale PNGs from prior runs to avoid inflating the count
rm -f docs/snapshots/*.png

TEST_RUNNER_SNAPSHOTS_EXPORT_DIR=docs/snapshots \
xcodebuild test \
  -project App/CoreDesignPreview.xcodeproj \
  -scheme CoreDesignPreview \
  -destination "platform=iOS Simulator,name=${DEVICE}" \
  -quiet

echo "Snapshots saved to docs/snapshots/"
count=$(find docs/snapshots -name "*.png" -type f | wc -l)
echo "${count} PNGs generated"
