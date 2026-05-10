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
  -scheme SnapshotTests \
  -destination "platform=iOS Simulator,name=${DEVICE}" \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -quiet

echo "Snapshots saved to docs/snapshots/"
count=$(find docs/snapshots -name "*.png" -type f | wc -l)
echo "${count} PNGs generated"
