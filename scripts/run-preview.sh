#!/bin/bash
set -euo pipefail

# Build and launch CoreDesignPreview app in Simulator

DEVICE="${SIMULATOR_DEVICE:-iPhone 17 Pro}"
DERIVED_DATA="$(dirname "$0")/../App/.derivedData"

# ⚠️ SIMULATOR_ID 优先于 SIMULATOR_DEVICE：**同名设备是本机的常态**，不是边角。
# 实测（#256）本机有 **3 台**都叫 "iPhone 17 Pro"（多个 runtime 各一台），
# `name=` 形态让 xcodebuild 硬红：
#   xcodebuild: error: Unable to find a destination matching the provided
#   destination specifier ... multiple devices matched the request.
# ⇒ 本脚本在这类机器上**跑不起来**，只能按 id 指定。
# 下面解析 UDID 的那一步本来就只取第一台（`head -1`），与这里保持一致。
SIMULATOR_ID="${SIMULATOR_ID:-}"
if [[ -n "${SIMULATOR_ID}" ]]; then
  DESTINATION="platform=iOS Simulator,id=${SIMULATOR_ID}"
else
  DESTINATION="platform=iOS Simulator,name=${DEVICE}"
fi

cd "$(dirname "$0")/.."

xcodebuild build \
  -project App/CoreDesignPreview.xcodeproj \
  -scheme CoreDesignPreview \
  -destination "${DESTINATION}" \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -derivedDataPath "${DERIVED_DATA}" \
  -quiet

echo "Build succeeded. Opening Simulator..."

# Resolve human-readable device name to UDID（给了 SIMULATOR_ID 就直接用）
if [[ -n "${SIMULATOR_ID}" ]]; then
  SIM_UDID="${SIMULATOR_ID}"
else
  SIM_UDID=$(xcrun simctl list devices available \
    | grep -F "${DEVICE} (" \
    | head -1 \
    | sed 's/.*(\([A-F0-9-]*\)).*/\1/' || true)
fi
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
xcrun simctl install "${SIM_UDID}" "$APP_PATH"
xcrun simctl launch "${SIM_UDID}" com.coredesign.CoreDesignPreview

echo "CoreDesignPreview installed and launched in Simulator."
