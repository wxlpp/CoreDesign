#!/bin/bash
set -euo pipefail

# NFR-1 帧率基准 / NFR-1 frame-rate benchmark
#
# ⚠️⚠️⚠️ **Simulator 上跑绿不等于 NFR-1 过。**
#
# PRD 的 NFR-1 钉的是「iPhone 15 满帧」。Simulator 没有真实 GPU 调度，
# 合成走宿主 Mac 的显卡与 CoreSimulator 的窗口服务 —— 量到的数只能当**趋势参考**。
# 判据本身（掉帧率 ≤ 5%）两种环境同一条，但**只有真机那一次的输出**能当 NFR-1 的证据。
#
# ⚠️ **截至 `#256` 合入，真机那一次尚未执行**（实现者没有物理设备）。
# 本脚本交付的是「一台可重复跑的秤」，不是「已达标」的结论。
#
# ## 为什么是「启动 App + 解析 stdout」而不是 xcodebuild test
#
# 实测（#256）：把基准写成 `XCTestCase` + `UIHostingController` 托管被测视图时，
# **SwiftUI 的更新循环在 unit test 宿主里根本不转** —— 每帧主线程死等 40 ms 的对照组
# 被判成「零掉帧」，`TimelineView` 的 body 在 2 秒窗口里只求值 1 次。
# 而 Confetti / NetworkGraph 的全部开销正来自那条循环。
# ⇒ 基准必须跑在**正常启动的 App** 里。详见 `App/Sources/PerformanceBenchmark.swift` 文件头。
#
# ## 跑法
#
#   # Simulator（趋势参考；不构成 NFR-1 证据）
#   ./scripts/run-perf-benchmark.sh
#   PERF_DEVICE_ID=<simulator udid> ./scripts/run-perf-benchmark.sh
#
#   # 真机（NFR-1 的那一次）
#   xcrun devicectl list devices                       # 取 udid
#   PERF_PLATFORM=device PERF_DEVICE_ID=<device udid> \
#     DEVELOPMENT_TEAM=<team id> ./scripts/run-perf-benchmark.sh
#
# ⚠️ 真机跑需要有效签名：脚本会用 `CODE_SIGN_STYLE=Automatic` + `DEVELOPMENT_TEAM`
# 构建。没有签名时失败形态是 **`xcodebuild` 在安装阶段报错**，不是一个偏低的分数。

cd "$(dirname "$0")/.."

PERF_PLATFORM="${PERF_PLATFORM:-simulator}"      # simulator | device
PERF_DEVICE_ID="${PERF_DEVICE_ID:-}"
PERF_DEVICE_NAME="${PERF_DEVICE_NAME:-iPhone 17 Pro}"
BUNDLE_ID="com.coredesign.CoreDesignPreview"
DERIVED_DATA="$(pwd)/App/.derivedData"
LOG="$(pwd)/perf-benchmark.log"

resolve_simulator_id() {
  if [ -n "${PERF_DEVICE_ID}" ]; then
    echo "${PERF_DEVICE_ID}"
    return
  fi
  # ⚠️ 本机实测有 **3 台**都叫 "iPhone 17 Pro"（多 runtime 各一台）。按 name 传给
  # xcodebuild 会硬红 "multiple devices matched the request" —— 这里自己取第一台的 udid，
  # 让 name 形态在有同名设备的机器上也能跑。
  xcrun simctl list devices available \
    | grep -F "${PERF_DEVICE_NAME} (" \
    | head -1 \
    | sed 's/.*(\([A-F0-9-]*\)).*/\1/'
}

case "${PERF_PLATFORM}" in
  simulator)
    SIM_ID="$(resolve_simulator_id)"
    if [ -z "${SIM_ID}" ]; then
      echo "ERROR: 找不到可用的 Simulator（PERF_DEVICE_NAME=${PERF_DEVICE_NAME}）" >&2
      exit 2
    fi
    echo "run-perf-benchmark: ⚠️ Simulator 模式（${SIM_ID}）—— 数值仅作趋势参考，**不构成 NFR-1 达标证据**"

    xcodebuild build \
      -project App/CoreDesignPreview.xcodeproj \
      -scheme CoreDesignPreview \
      -destination "platform=iOS Simulator,id=${SIM_ID}" \
      -derivedDataPath "${DERIVED_DATA}" \
      CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
      -quiet

    APP_PATH=$(/usr/bin/find "${DERIVED_DATA}" -name "CoreDesignPreview.app" -path "*/Debug-iphonesimulator/*" | head -1)
    if [ -z "${APP_PATH}" ]; then
      echo "ERROR: 构建产物里找不到 CoreDesignPreview.app" >&2
      exit 2
    fi

    xcrun simctl boot "${SIM_ID}" 2>/dev/null || true
    xcrun simctl bootstatus "${SIM_ID}" -b 2>/dev/null || true
    xcrun simctl install "${SIM_ID}" "${APP_PATH}"
    # ⚠️ `--console-pty` 而不是 `--console`：后者在 App 自行 `exit()` 时可能吞掉最后几行。
    set +e
    xcrun simctl launch --console-pty "${SIM_ID}" "${BUNDLE_ID}" --perf-benchmark 2>&1 | tee "${LOG}"
    set -e
    ;;

  device)
    if [ -z "${PERF_DEVICE_ID}" ]; then
      echo "ERROR: 真机模式必须给 PERF_DEVICE_ID（`xcrun devicectl list devices` 取）" >&2
      exit 2
    fi
    echo "run-perf-benchmark: 真机模式（${PERF_DEVICE_ID}）—— 本次输出可作为 NFR-1 的证据留证"

    SIGN_ARGS=(CODE_SIGN_STYLE=Automatic)
    if [ -n "${DEVELOPMENT_TEAM:-}" ]; then
      SIGN_ARGS+=("DEVELOPMENT_TEAM=${DEVELOPMENT_TEAM}")
    fi
    xcodebuild build \
      -project App/CoreDesignPreview.xcodeproj \
      -scheme CoreDesignPreview \
      -destination "platform=iOS,id=${PERF_DEVICE_ID}" \
      -derivedDataPath "${DERIVED_DATA}" \
      -allowProvisioningUpdates \
      "${SIGN_ARGS[@]}" \
      -quiet

    APP_PATH=$(/usr/bin/find "${DERIVED_DATA}" -name "CoreDesignPreview.app" -path "*/Debug-iphoneos/*" | head -1)
    if [ -z "${APP_PATH}" ]; then
      echo "ERROR: 构建产物里找不到真机版 CoreDesignPreview.app" >&2
      exit 2
    fi

    xcrun devicectl device install app --device "${PERF_DEVICE_ID}" "${APP_PATH}"
    set +e
    xcrun devicectl device process launch \
      --device "${PERF_DEVICE_ID}" \
      --console \
      --terminate-existing \
      "${BUNDLE_ID}" --perf-benchmark 2>&1 | tee "${LOG}"
    set -e
    ;;

  *)
    echo "ERROR: PERF_PLATFORM 只能是 simulator 或 device（收到 '${PERF_PLATFORM}'）" >&2
    exit 2
    ;;
esac

echo
echo "完整日志：${LOG}"

# ⚠️ **必须先断言「拿到了判词」再断言「判词是 PASS」**：App 崩了 / 没启动时
# stdout 里一行 `[perf]` 都没有，只查 "FAIL" 不存在会让脚本静默返回 0
# —— 那正是本仓反复记在案的「零输出 ⇒ 零违规 ⇒ 绿」。
if ! grep -q "PERF-VERDICT:" "${LOG}"; then
  echo "❌ 日志里没有 PERF-VERDICT —— App 没跑起来或提前崩了，这不是「通过」" >&2
  exit 3
fi
if grep -q "PERF-VERDICT: FAIL" "${LOG}"; then
  echo "❌ 基准判红" >&2
  exit 1
fi
echo "✅ 三条判词全 PASS（含对照组必须被判为掉帧那一条）"
if [ "${PERF_PLATFORM}" = "simulator" ]; then
  echo "⚠️ 但这是 Simulator —— **不构成 NFR-1 达标证据**，真机那一次仍未执行。"
fi
