#!/bin/bash
set -euo pipefail

# Generate snapshot PNGs for components with #Preview macros

DEVICE="${SIMULATOR_DEVICE:-iPhone 17 Pro}"

# KEEP_LIBRARY_SNAPSHOTS=1 renders every #Preview (library CoreDesign_* AND host
# CoreDesignPreview_*) straight into a fresh scratch dir for per-Issue visual
# review during parallel component work, and NEVER touches the committed
# docs/snapshots. This makes `git diff docs/snapshots` unconditionally empty in
# keep mode — it does not depend on byte-identical re-rendering, so a legitimately
# changed host preview (e.g. an Issue editing ProgressIndicator) cannot dirty a
# committed snapshot. Default mode (=0) is byte-for-byte the prior behavior.
KEEP_LIBRARY_SNAPSHOTS="${KEEP_LIBRARY_SNAPSHOTS:-0}"
# NOTE: in keep mode this dir is `rm -rf`'d wholesale on each run — point it at a
# scratch location only, never a shared/committed directory. Default is under $TMPDIR.
LIBRARY_SNAPSHOTS_EXPORT_DIR="${LIBRARY_SNAPSHOTS_EXPORT_DIR:-${TMPDIR:-/tmp}/coredesign-library-snapshots}"

cd "$(dirname "$0")/.."
SNAPSHOT_DIR="$(pwd)/docs/snapshots"

if [ "${KEEP_LIBRARY_SNAPSHOTS}" = "1" ]; then
  # Keep mode: render into a fresh scratch dir; leave docs/snapshots untouched.
  EXPORT_DIR="${LIBRARY_SNAPSHOTS_EXPORT_DIR}"
  rm -rf "${EXPORT_DIR}"
  mkdir -p "${EXPORT_DIR}"
else
  # Default: start fresh in docs/snapshots, removing all stale output.
  EXPORT_DIR="${SNAPSHOT_DIR}"
  rm -rf "${SNAPSHOT_DIR}"
  mkdir -p "${SNAPSHOT_DIR}"
fi

TEST_RUNNER_SNAPSHOTS_EXPORT_DIR="${EXPORT_DIR}" \
xcodebuild test \
  -project App/CoreDesignPreview.xcodeproj \
  -scheme CoreDesignPreview \
  -only-testing:SnapshotTests \
  -destination "platform=iOS Simulator,name=${DEVICE}" \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -quiet

if [ "${KEEP_LIBRARY_SNAPSHOTS}" = "1" ]; then
  echo "Library #Preview snapshots exported to ${EXPORT_DIR} (docs/snapshots untouched)"
  count=$(/usr/bin/find "${EXPORT_DIR}" -name "*.png" -type f | wc -l)
  echo "${count} PNGs generated (scratch)"
else
  # Snapshot scanner also picks up `#Preview` blocks in the CoreDesign library
  # source tree (CoreDesign_*.{png,json}); those are byproducts—convention is to
  # only commit App/Sources/Previews.swift-driven outputs (CoreDesignPreview_*).
  /usr/bin/find docs/snapshots -name "CoreDesign_*" -type f -delete
  echo "Snapshots saved to docs/snapshots/"
  count=$(/usr/bin/find docs/snapshots -name "*.png" -type f | wc -l)
  echo "${count} PNGs generated"
fi
