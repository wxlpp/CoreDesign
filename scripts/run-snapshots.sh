#!/bin/bash
set -euo pipefail

# Generate snapshot PNGs for components with #Preview macros

DEVICE="${SIMULATOR_DEVICE:-iPhone 17 Pro}"

cd "$(dirname "$0")/.."
# Start fresh: remove all stale output (PNGs + metadata sidecars)
SNAPSHOT_DIR="$(pwd)/docs/snapshots"
rm -rf "${SNAPSHOT_DIR}"
mkdir -p "${SNAPSHOT_DIR}"

TEST_RUNNER_SNAPSHOTS_EXPORT_DIR="${SNAPSHOT_DIR}" \
xcodebuild test \
  -project App/CoreDesignPreview.xcodeproj \
  -scheme CoreDesignPreview \
  -only-testing:SnapshotTests \
  -destination "platform=iOS Simulator,name=${DEVICE}" \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -quiet

# Snapshot scanner also picks up `#Preview` blocks in the CoreDesign library
# source tree (CoreDesign_*.{png,json}); those are byproducts—convention is to
# only commit App/Sources/Previews.swift-driven outputs (CoreDesignPreview_*).
/usr/bin/find docs/snapshots -name "CoreDesign_*" -type f -delete

echo "Snapshots saved to docs/snapshots/"
count=$(/usr/bin/find docs/snapshots -name "*.png" -type f | wc -l)
echo "${count} PNGs generated"
