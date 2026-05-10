#!/bin/bash
set -euo pipefail

# Build and launch CoreDesignPreview app in Simulator

DEVICE="${SIMULATOR_DEVICE:-iPhone 17 Pro}"
DERIVED_DATA="$(dirname "$0")/../App/.derivedData"

cd "$(dirname "$0")/.."

xcodebuild build \
  -project App/CoreDesignPreview.xcodeproj \
  -scheme CoreDesignPreview \
  -destination "platform=iOS Simulator,name=${DEVICE}" \
  -derivedDataPath "${DERIVED_DATA}" \
  -quiet

echo "Build succeeded. Opening Simulator..."

xcrun simctl boot "${DEVICE}" 2>/dev/null || true
open -a Simulator

APP_PATH=$(find "${DERIVED_DATA}" -name "CoreDesignPreview.app" -path "*/Debug-iphonesimulator/*" | head -1)
if [[ -z "$APP_PATH" ]]; then
    echo "Error: Could not find CoreDesignPreview.app in ${DERIVED_DATA}" >&2
    exit 1
fi
xcrun simctl install booted "$APP_PATH"
xcrun simctl launch booted com.coredesign.CoreDesignPreview

echo "CoreDesignPreview installed and launched in Simulator."
