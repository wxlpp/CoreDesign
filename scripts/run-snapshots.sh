#!/bin/bash
set -euo pipefail

# Generate snapshot PNGs for components with #Preview macros

DEVICE="${SIMULATOR_DEVICE:-iPhone 17 Pro}"

# KEEP_LIBRARY_SNAPSHOTS=1 preserves the library's own `#Preview` byproducts
# (CoreDesign_*) for per-Issue visual review during parallel component work,
# WITHOUT disturbing the committed host snapshots (CoreDesignPreview_*).
# Three-part behavior vs. the default:
#   1. skip the `rm -rf docs/snapshots` that would wipe committed host snapshots;
#   2. export the CoreDesign_* byproducts to a scratch dir instead of docs/snapshots;
#   3. skip the CoreDesign_* deletion so the scratch export survives.
# Result in keep mode: `git diff docs/snapshots` stays empty, and library
# #Preview PNGs land in LIBRARY_SNAPSHOTS_EXPORT_DIR for review.
KEEP_LIBRARY_SNAPSHOTS="${KEEP_LIBRARY_SNAPSHOTS:-0}"
LIBRARY_SNAPSHOTS_EXPORT_DIR="${LIBRARY_SNAPSHOTS_EXPORT_DIR:-${TMPDIR:-/tmp}/coredesign-library-snapshots}"

cd "$(dirname "$0")/.."
SNAPSHOT_DIR="$(pwd)/docs/snapshots"

if [ "${KEEP_LIBRARY_SNAPSHOTS}" = "1" ]; then
  # Keep mode: do NOT wipe committed snapshots; just ensure the dir exists.
  mkdir -p "${SNAPSHOT_DIR}"
else
  # Default: start fresh, removing all stale output (PNGs + metadata sidecars).
  rm -rf "${SNAPSHOT_DIR}"
  mkdir -p "${SNAPSHOT_DIR}"
fi

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
if [ "${KEEP_LIBRARY_SNAPSHOTS}" = "1" ]; then
  # Export the library byproducts to scratch instead of deleting them, so the
  # committed docs/snapshots stays untouched (git diff empty) yet reviewers get
  # the library #Preview renders.
  mkdir -p "${LIBRARY_SNAPSHOTS_EXPORT_DIR}"
  /usr/bin/find docs/snapshots -name "CoreDesign_*" -type f -exec mv {} "${LIBRARY_SNAPSHOTS_EXPORT_DIR}/" \;
  echo "Library #Preview snapshots exported to ${LIBRARY_SNAPSHOTS_EXPORT_DIR}"
else
  /usr/bin/find docs/snapshots -name "CoreDesign_*" -type f -delete
fi

echo "Snapshots saved to docs/snapshots/"
count=$(/usr/bin/find docs/snapshots -name "*.png" -type f | wc -l)
echo "${count} PNGs generated"
