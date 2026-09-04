#!/bin/bash
set -euo pipefail

# Generate snapshot PNGs for components with #Preview macros

DEVICE="${SIMULATOR_DEVICE:-iPhone 17 Pro}"

# ⚠️ SIMULATOR_ID 优先于 SIMULATOR_DEVICE：**同名设备是本机的常态**，不是边角。
# 实测（#256）本机 `xcrun simctl list devices available` 下有 **3 台**都叫
# "iPhone 17 Pro"（多个 runtime 各一台），于是 `name=iPhone 17 Pro` 让 xcodebuild
# 硬红：
#   xcodebuild: error: Unable to find a destination matching the provided
#   destination specifier ... The requested device could not be found because
#   multiple devices matched the request.
# ⇒ 本机上默认形态**跑不起来**，只能按 id 指定。CI runner 上只有一台同名设备，
# 故 `ci.yml` 的 name 形态照旧可用——两边都要能跑，所以是 override 而不是替换。
SIMULATOR_ID="${SIMULATOR_ID:-}"
if [ -n "${SIMULATOR_ID}" ]; then
  DESTINATION="platform=iOS Simulator,id=${SIMULATOR_ID}"
else
  DESTINATION="platform=iOS Simulator,name=${DEVICE}"
fi

# KEEP_LIBRARY_SNAPSHOTS=1 renders every #Preview (library CoreDesign_* AND host
# CoreDesignPreview_*) straight into a fresh scratch dir for per-Issue visual
# review during parallel component work, and NEVER touches the committed
# docs/snapshots. This makes `git diff docs/snapshots` unconditionally empty in
# keep mode — it does not depend on byte-identical re-rendering, so a legitimately
# changed host preview (e.g. an Issue editing ProgressIndicator) cannot dirty a
# committed snapshot. Default mode (=0) reproduces the prior filesystem/xcodebuild
# behavior byte-for-byte (only difference is one extra mode-announcement echo line).
KEEP_LIBRARY_SNAPSHOTS="${KEEP_LIBRARY_SNAPSHOTS:-0}"
case "${KEEP_LIBRARY_SNAPSHOTS}" in
  0 | 1) ;;
  *)
    echo "ERROR: KEEP_LIBRARY_SNAPSHOTS must be 0 or 1 (got '${KEEP_LIBRARY_SNAPSHOTS}')." >&2
    echo "       Refusing to run so an unrecognized value can't silently fall into the destructive default." >&2
    exit 2
    ;;
esac

cd "$(dirname "$0")/.."
SNAPSHOT_DIR="$(pwd)/docs/snapshots"

# Default scratch export dir is PER-WORKTREE (suffixed with the checkout root's
# basename). Phase 1 runs 10 Issue worktrees in parallel; a shared global scratch
# dir would let them `rm -rf` each other's exports. Override with the env var if
# needed — NOTE: in keep mode this dir is `rm -rf`'d wholesale each run, so point
# it at a scratch location only, never a shared/committed directory.
LIBRARY_SNAPSHOTS_EXPORT_DIR="${LIBRARY_SNAPSHOTS_EXPORT_DIR:-${TMPDIR:-/tmp}/coredesign-library-snapshots-$(basename "$(pwd)")}"

if [ "${KEEP_LIBRARY_SNAPSHOTS}" = "1" ]; then
  # Keep mode: render into a fresh scratch dir; leave docs/snapshots untouched.
  echo "run-snapshots: keep mode — docs/snapshots untouched, exporting to ${LIBRARY_SNAPSHOTS_EXPORT_DIR}"
  EXPORT_DIR="${LIBRARY_SNAPSHOTS_EXPORT_DIR}"
  rm -rf "${EXPORT_DIR}"
  mkdir -p "${EXPORT_DIR}"
else
  # Default: start fresh in docs/snapshots, removing all stale output.
  echo "run-snapshots: default mode — regenerating docs/snapshots"
  EXPORT_DIR="${SNAPSHOT_DIR}"
  rm -rf "${SNAPSHOT_DIR}"
  mkdir -p "${SNAPSHOT_DIR}"
fi

TEST_RUNNER_SNAPSHOTS_EXPORT_DIR="${EXPORT_DIR}" \
xcodebuild test \
  -project App/CoreDesignPreview.xcodeproj \
  -scheme CoreDesignPreview \
  -only-testing:SnapshotTests \
  -destination "${DESTINATION}" \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -quiet

if [ "${KEEP_LIBRARY_SNAPSHOTS}" = "1" ]; then
  echo "Library #Preview snapshots exported to ${EXPORT_DIR} (docs/snapshots untouched)"
  count=$(/usr/bin/find "${EXPORT_DIR}" -name "*.png" -type f | wc -l)
  echo "${count} PNGs generated (scratch)"
else
  # ⚠️⚠️ **快照排除策略（#256）——按「产地」白名单，不是按名字黑名单。**
  #
  # SnapshotPreviews 会渲染**所有链入模块**的 `#Preview`，产物文件名前缀是**模块名**
  # （`<Module>_<file>_<preview name>.{png,json}`）。提交态的约定一直是「只收
  # `App/Sources/Previews.swift` 驱动的产物」（`CoreDesignPreview_*`）。
  #
  # ## 上一版为什么必须换掉（实测，不是推演）
  #
  # 上一版这里写的是 `-name "CoreDesign_*"` —— 一条**按模块名前缀的黑名单**。
  # glob `CoreDesign_*` 要求 "CoreDesign" 后紧跟下划线 ⇒ `CoreDesignEffects_*` /
  # `CoreDesignCharts_*` **一个都不匹配**。
  #
  # 实测（本 PR，`KEEP_LIBRARY_SNAPSHOTS=1` 全量渲染）：
  # · `#256` **之前**（`App/Sources/` 还没 import 两个新 product）导出 135 个 PNG，
  #   前缀只有 `CoreDesign_` 与 `CoreDesignPreview_` —— 两个新模块的 preview
  #   **一个都没被渲染**（未被 App 引用 ⇒ 未参与，扫描器看不到）。
  # · 本 PR 把 40 个 API 单位接进画廊之后再渲染：导出 175 个 PNG，多出的正是
  #   `CoreDesignEffects_*` 36 个 + `CoreDesignCharts_*` 4 个（135 → 175）。
  # ⇒ **在本 PR 之前黑名单“看起来没问题”，恰恰因为它管辖的东西还不存在。**
  #   本 PR 一接进画廊，默认模式就会把这 40 个库内产物连同 JSON 一起提交进
  #   `docs/snapshots`。黑名单形态对「新出现的模块」是**空真**，每加一个 target
  #   就要有人记得回来补一条前缀 —— 这正是 G-7 记在案的失效形态。
  # ⇒ 改成白名单：**凡不是 `CoreDesignPreview_*` 的产物一律删**。
  #   新 target、新模块、改名，都不需要回来改这一行。
  #
  # ## 关于「非确定 PNG」：epic 点的那三个名字**没有复现**
  #
  # `epic.md` / `256.md` 写的是「`Confetti` / `ParticleTransition` /
  # `AnimatedMeshGradient` 产出**非确定 PNG**」。本 PR 连跑**三次**全量渲染（每次 175 个 PNG + 175 个 JSON）
  # 逐字节比对（run1 vs run2、run1 vs run3），实测：
  # · 两轮比对**各是同一批 9 个 PNG** 有差异（两次比对结果逐字相同）；
  # · 这三个名字对应的 4 个产物（`Confetti…confetti`、`ParticleTransition`、
  #   `AnimatedMeshGradient` 两个）**全部逐字节相同**；
  # · 新模块 40 个产物里**只有 1 个**漂移：
  #   `CoreDesignEffects_BeforeAfterSlider.swift_BeforeAfterSlider_自定义文案_无标签.png`
  #   （该 preview 有一段 `.task` 驱动的 intro sweep）；
  # · 其余 8 个漂移**全是既有的 spinner / 进度族**，且其中 3 个**已经在提交态里**：
  #   `CoreDesignPreview_Previews.swift_{ProgressIndicator,Spinning,Spinning_Presentations}.png`。
  #   ⇒ **提交态今天就在漂**，那是既存状况（`KEEP_LIBRARY_SNAPSHOTS` 当初就是为它加的），
  #   不是本 PR 引入的，也不在本 PR 的射程内。
  #
  # ⚠️ **三次相同不等于确定性**，只等于「三次没能复现非确定」。之所以大多数
  # `TimelineView` 驱动的 preview 稳定，最可能的原因是 SnapshotPreviews 捕的是
  # **首帧**、时间轴尚未推进（同一现象在 `App/Sources/PerformanceBenchmark.swift`
  # 文件头有独立实测：unit test 宿主里 `TimelineView` 的 body 2 秒只求值 1 次）。
  # ⇒ **策略不建立在“哪几个名字不确定”上**：按名字列黑名单的形态，既写不对
  # （epic 点的三个实测是稳的），也管不住将来（BeforeAfterSlider 这种才是真漂的）。
  # **判据是「产地」——库内 `#Preview` 一律不进提交态，确定与否都不进。**
  #
  # ⚠️ 反向的守卫在 `Tests/CoreDesignTests/SnapshotArtifactGuard.swift`：
  # 提交态里出现任何非 `CoreDesignPreview_` 前缀的产物即判红。
  /usr/bin/find docs/snapshots -type f ! -name "CoreDesignPreview_*" -delete
  echo "Snapshots saved to docs/snapshots/"
  count=$(/usr/bin/find docs/snapshots -name "*.png" -type f | wc -l)
  echo "${count} PNGs generated"
fi
