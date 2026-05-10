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

# Resolve human-readable device name to UDID
SIM_UDID=$(xcrun simctl list devices available \
  | grep "${DEVICE}" \
  | head -1 \
  | sed 's/.*(\([A-F0-9-]*\)).*/\1/')
if [[ -z "${SIM_UDID}" ]]; then
  echo "Error: No available simulator found for '${DEVICE}'" >&2
  exit 1
fi

xcrun simctl boot "${SIM_UDID}" 2>/dev/null || true
xcrun simctl bootstatus "${SIM_UDID}" -b 2>/dev/null || true
open -a Simulator

APP_PATH=$(find "${DERIVED_DATA}" -name "CoreDesignPreview.app" -path "*/Debug-iphonesimulator/*" | head -1)
if [[ -z "$APP_PATH" ]]; then
    echo "Error: Could not find CoreDesignPreview.app in ${DERIVED_DATA}" >&2
    exit 1
fi
xcrun simctl install booted "$APP_PATH"
xcrun simctl launch booted com.coredesign.CoreDesignPreview

echo "CoreDesignPreview installed and launched in Simulator."
