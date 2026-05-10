#!/bin/bash
set -euo pipefail

# Generate snapshot PNGs for components with #Preview macros

DEVICE="${SIMULATOR_DEVICE:-iPhone 17 Pro}"

cd "$(dirname "$0")/.."
rm -f docs/snapshots/*.png
mkdir -p docs/snapshots

TEST_RUNNER_SNAPSHOTS_EXPORT_DIR=docs/snapshots \
xcodebuild test \
  -project App/CoreDesignPreview.xcodeproj \
  -scheme SnapshotTests \
  -destination "platform=iOS Simulator,name=${DEVICE}" \
  -quiet

echo "Snapshots saved to docs/snapshots/"
count=$(find docs/snapshots -name "*.png" -type f | wc -l)
if [[ "$count" -eq 0 ]]; then
    echo "Warning: 0 PNGs generated. Check that #Preview macros exist and the scheme builds correctly." >&2
fi
echo "${count} PNGs generated"
