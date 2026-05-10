#!/bin/bash
set -euo pipefail

# Open CoreDesignPreview app in Simulator

cd "$(dirname "$0")/.."

xcodebuild build \
  -project App/CoreDesignPreview.xcodeproj \
  -scheme CoreDesignPreview \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -quiet

echo "Build succeeded. Opening Simulator..."

xcrun simctl boot "iPhone 17 Pro" 2>/dev/null || true
open -a Simulator

APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "CoreDesignPreview.app" -path "*/Debug-iphonesimulator/*" | head -1)
if [[ -z "$APP_PATH" ]]; then
    echo "Error: Could not find CoreDesignPreview.app in DerivedData" >&2
    exit 1
fi
xcrun simctl install booted "$APP_PATH"

echo "CoreDesignPreview installed in Simulator."
