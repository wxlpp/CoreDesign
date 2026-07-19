# Issue #92 构建配置前置 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use oh-my-superpowers:subagent-driven-development (recommended) or oh-my-superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 给 CoreDesign 启用 `defaultIsolation(MainActor.self)`、修正构建配置矛盾、并按实测结果落地 CI 门禁，为后续 10 个 Issue 铺好前置。

**Architecture:** 三条互相独立的改动线——(1) `Package.swift` 的并发与平台配置 + 2 处 fallout 注解；(2) `App/project.yml` 的预览宿主配置；(3) `.github/workflows/` 的 CI 门禁。第 3 条的落地形态取决于 GitHub Actions runner 的实测能力，因此单独拆出一个「探测」任务先取得结论，再据结论实施。

**Tech Stack:** Swift 6.3 / SwiftPM（Package Traits）/ XcodeGen 2.45.4 / GitHub Actions

## Global Constraints

- 部署目标 iOS 26+ / macOS 26+，`swiftLanguageModes: [.v6]`，不为 iOS 26 API 加可用性回退
- 代码风格：显式 `self.`、中英双语注释、`#Preview` 与组件同文件（见 `CLAUDE.md`）
- 验证标准是四条 SwiftPM 命令：`swift build` / `swift test` / 两者的 `--traits Blossom` 版本
- **「零 warning」的口径是「不新增 warning」**。`swift test` 基线本就有 12 个 warning，全部来自 `Tests/CoreDesignTests/EmptyStateDeprecationTests.swift` 的 `EmptyState` deprecation，属 #6 的删除范围，本任务不处理也不计入
- `.build` 若有跨路径 ModuleCache 残留会报 `missing required module 'SwiftShims'`，遇到时先 `swift package clean`
- **不碰 #6 的删除名单**：`Sources/CoreDesign/Components/EmptyState/EmptyState.swift`、`Sources/CoreDesign/Utils/View+SizeReader.swift`、`Sources/CoreDesign/Utils/KeyboardHandling.swift`、`Tests/CoreDesignTests/KeyboardHandlingTests.swift`、`Tests/CoreDesignTests/EmptyStateDeprecationTests.swift`
- 工作区：`.worktrees/issue-92-build-config`，分支 `issue-92-build-config`，base `epic/coredesign-audit-remediation`
- **`ToastHostTests` 的 timing 用例会 flake**（实测：同一命令连跑两次，一次 `EXIT=0` 一次 `EXIT=65`，失败在 `dismiss(id:) 正在显示的 item 进入 dismissing 状态` / `重复触发不 double-fire`）。该 suite 依赖 `Task.sleep` 真实墙钟，文件头 `ToastHostTests.swift:15-21` 已自述此风险与预案。**处置规则：任何「绿」判据遇到该 suite 失败时先重跑一次，连续两次失败才算真红。**不要把 flake 误判为本任务引入的 fallout，也不要在本任务里改它（超出范围）
- **warning 计数不能直接用 `grep -c`**：实测同一仓库状态下，clean 后首次 = 12、增量重跑 = 12、touch 单个文件后 = 0——计数随编译粒度漂移。判据须改为「**除已知来源外无新 warning**」，见 Task 1 Step 8

## 已完成的探针实测（直接采信，不要重新验证）

| 结论 | 证据 |
|---|---|
| `defaultIsolation` 的 fallout 只有 **2 处** | 7 条诊断是同一问题的重复报告 |
| 修法：`CoreSpacing` + `CoreRadius` 标 `nonisolated` | `swift build` EXIT=0，0 error 0 warning |
| **不可**把 7 个 token 枚举全标 | 全标产生 17 error：`CoreElevation` 持 `Color`、`CoreTypography` 持 `Font`，SwiftUI 类型本身 MainActor 隔离 |
| 测试 target 也可加 `defaultIsolation` | 96 tests 通过，新增 warning **0** |
| 本机具备完整 iOS 26 工具链 | Xcode 26.4 / iOS 26.4 runtime / iPhone 17 Pro 设备均在 |
| **xcodegen 2.45.4 不支持 `traits:` 键** | 加了不报错，但生成物中零 trait 痕迹——静默忽略 |
| 重新生成 `.xcodeproj` 会删掉已提交的 shared xcscheme | `git status` 显示 `D ...CoreDesignPreview.xcscheme` |
| **`xcodebuild test` 当前就是红的**（与本任务改动无关） | `EXIT=65`，`Suite "Blossom assets" failed with 13 issues` |

### 关键环境差异：SwiftPM 与 xcodebuild 是互补的镜像

上一行的失败根因值得单列，因为它影响 #4 与 #7：

| | `swift test`（SwiftPM） | `xcodebuild test`（Xcode） |
|---|---|---|
| `Assets.car` | ✗ 不生成 | ✓ 生成 |
| 原始 `.colorset` 目录 | ✓ 原样拷贝 | ✗ 不存在 |
| `CoreDesignTests.swift` 的 FileManager asset guard | 可用（正是为此而写） | **失败** |
| `Color.resolve` 取真实色值 | 失败，返回 `(0,0,0,0)` | **可用** |

实测证据：xcodebuild 产出的 `CoreDesign_CoreDesign.bundle` 内容只有 `Assets.car` + `Info.plist`，无任何 `.xcassets` / `.colorset` 目录。

**对下游 Issue 的影响（须写进 `ci-decision.md` 转告）：**

- **#7**：其 C4a 计划采用的「asset 名 → `Contents.json` 解析」路径**只在 `swift test` 下成立**，在 xcodebuild 下会因找不到 `Contents.json` 而失败。反过来 xcodebuild 恰恰是 `Color.resolve` 可用的环境。#7 若想让 Blossom 断言在两种环境都绿，需要按环境分支（检测 `Assets.car` 是否存在）；或明确只在 `swift test` 下运行并用 `#if` 排除。
- **#4**：布局断言层跑在 xcodebuild 下，与现有的 SwiftPM-only asset guard 同处一个 test target。#4 落地前，simulator 那条命令必须跳过该 suite（见 Task 5）。

> **关于「只标两个 token 枚举」**：这不是不彻底，而是技术上唯一正确的解。边界是「纯数值 token 可以 nonisolated，持有 SwiftUI 类型的不能」。评审时请勿要求扩大到其余 5 个。

---

### Task 1: 启用 defaultIsolation 并修复 2 处 fallout

**Files:**
- Modify: `Package.swift:26-33`（两个 target 加 `swiftSettings`）
- Modify: `Sources/CoreDesign/Tokens/CoreSpacing.swift:26`
- Modify: `Sources/CoreDesign/Tokens/CoreRadius.swift:24`
- Test: 四条 SwiftPM 命令（本任务无新增单元测试——改的是编译器语义，构建本身即测试）

**Interfaces:**
- Consumes: 无
- Produces: `CoreSpacing` 与 `CoreRadius` 成为 `nonisolated` 类型，可在 `Layout` / `InsettableShape` 等 nonisolated 协议要求中引用。后续 Issue（尤其 #4 改 `CoreTypography`、#10 改 `CoreControlMetrics`）若在 nonisolated 上下文引用这两个之外的 token，会遇到同类诊断——届时按同一边界判断：纯数值可标，持 SwiftUI 类型不可标。

- [ ] **Step 1: 先确认当前是绿的（建立对照）**

```bash
cd /Users/evan/Repositories/work-spec/CoreDesign/.worktrees/issue-92-build-config
swift build 2>&1 | tail -2
```

Expected: `Build complete!`

- [ ] **Step 2: 给两个 target 加 defaultIsolation**

`Package.swift` 的 `targets:` 数组改成：

```swift
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "CoreDesign",
            resources: [.process("Resources")],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(
            name: "CoreDesignTests",
            dependencies: ["CoreDesign"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
    ],
```

- [ ] **Step 3: 运行构建，确认它按预期变红**

```bash
# 只匹配「文件:行:列: error:」形式,滤掉诊断的 caret 上下文行与
# 「error: emit-module command failed」这类汇总行——否则 sort -u 会输出
# 4 行而非 2 行,干扰「恰好两个站点」的判断。
swift build 2>&1 | grep -E '\.swift:[0-9]+:[0-9]+: error:' | sed 's|.*/CoreDesign/||' | sort -u
```

Expected: 恰好两个不同站点

```
Components/BottomInputBar/BottomInputBar.swift:221:96: error: main actor-isolated static property 'large' can not be referenced from a nonisolated context
Layout/FlowLayout.swift:29:17: error: main actor-isolated default value in a nonisolated context
```

若出现**第三个站点**，说明 fallout 超出探针结论——按任务文件的「超预期即停」约束停下回报，不要继续硬修。

- [ ] **Step 4: 给 CoreSpacing 加 nonisolated**

`Sources/CoreDesign/Tokens/CoreSpacing.swift:26`，把

```swift
public enum CoreSpacing {
```

改为

```swift
// `nonisolated`：本枚举只含纯数值常量，需要在 `Layout` / `InsettableShape` 等
// nonisolated 协议要求中被引用（如 `FlowLayout.init` 的默认参数）。
// 注意不能对 `CoreElevation` / `CoreTypography` 做同样处理——它们持有
// `Color` / `Font`，SwiftUI 类型本身是 MainActor 隔离的。
public nonisolated enum CoreSpacing {
```

- [ ] **Step 5: 给 CoreRadius 加 nonisolated**

`Sources/CoreDesign/Tokens/CoreRadius.swift:24`，把

```swift
public enum CoreRadius {
```

改为

```swift
// `nonisolated`：理由同 `CoreSpacing`——纯数值常量，需要在 nonisolated 上下文
// （如 `BottomInputBarGlassEffectShape.path(in:)`）中被引用。
public nonisolated enum CoreRadius {
```

- [ ] **Step 6: 确认构建转绿**

```bash
swift build 2>&1 | tail -2
```

Expected: `Build complete!`，无 error 无 warning

- [ ] **Step 7: 跑全部四条验证命令**

```bash
swift build && swift test 2>&1 | tail -1 && swift build --traits Blossom && swift test --traits Blossom 2>&1 | tail -1
```

Expected: 两次 `Test run with 96 tests in 32 suites passed`，两次 `Build complete!`

- [ ] **Step 8: 确认没有新增 warning**

```bash
# 不要用 grep -c 计数——实测该数字随编译粒度漂移(clean 后 12 / 增量 12 /
# touch 单文件后 0)。改为按来源过滤:列出所有「非 EmptyState deprecation」
# 的 warning,期望为空。
swift package clean && swift build >/dev/null 2>&1
swift test 2>&1 | grep 'warning:' | grep -v "is deprecated: Use SwiftUI ContentUnavailableView"
```

Expected: **无输出**（既有的 `EmptyState` deprecation 全部来自这一条 message，属 #6 范围）。若有任何输出，说明本任务引入了新 warning，须处理。

- [ ] **Step 9: Commit**

```bash
git add Package.swift Sources/CoreDesign/Tokens/CoreSpacing.swift Sources/CoreDesign/Tokens/CoreRadius.swift
git commit -m "Issue #92: enable defaultIsolation and mark numeric token enums nonisolated"
```

---

### Task 2: 修正 Package.swift 的平台声明形式（C7b）

**Files:**
- Modify: `Package.swift:8-11`

**Interfaces:**
- Consumes: Task 1 的 `Package.swift` 状态
- Produces: 无新接口

- [ ] **Step 1: 改为枚举 case 形式**

`Package.swift` 的 `platforms:` 从

```swift
    platforms: [
        .iOS("26.0"),
        .macOS("26.0"),
    ],
```

改为

```swift
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
    ],
```

- [ ] **Step 2: 验证四条命令仍绿**

```bash
swift build && swift test 2>&1 | tail -1 && swift build --traits Blossom && swift test --traits Blossom 2>&1 | tail -1
```

Expected: 与 Task 1 Step 7 相同

若 `.v26` 不被 swift-tools-version 6.3 识别（报 `type 'SupportedPlatform.IOSVersion' has no member 'v26'`），说明该工具链尚未提供 v26 枚举 case，**保持字符串形式不变**，并在完成记录中说明 C7b 因工具链限制不可行——不要为此降低 tools-version。

- [ ] **Step 3: Commit**

```bash
git add Package.swift
git commit -m "Issue #92: use enum case form for platform versions"
```

---

### Task 3: 修正预览宿主配置（C9a、C9b）

**Files:**
- Modify: `App/project.yml:6`（xcodeVersion）
- Modify: `App/project.yml:8-13`（trait 启用方式，待定）
- Create: `.claude/epics/coredesign-audit-remediation/updates/92/ci-decision.md`（本 Task 创建并写入 C9b 的路径尝试记录；Task 4 之后追加 CI 章节）
- 可能 Create: `App/BlossomPreviewShim/`（路径 4）

**Interfaces:**
- Consumes: 无
- Produces: 预览宿主能在 Blossom 主题下渲染，供 `scripts/run-preview.sh` 与视觉评审使用

**已知约束（探针实测）：** xcodegen 2.45.4 **不支持** `traits:` 键——加了不报错但生成物零痕迹。因此 C9b 不能靠改 `project.yml` 的 packages 段达成。且重新生成 `.xcodeproj` 会删掉已提交的 shared xcscheme，任何涉及 `xcodegen generate` 的步骤都要在之后确认 scheme 仍在。

- [ ] **Step 1: 修正 xcodeVersion 矛盾（C9a）**

`App/project.yml:6`，把

```yaml
  xcodeVersion: "16.0"
```

改为

```yaml
  xcodeVersion: "26.0"
```

- [ ] **Step 2: 确认 SWIFT_VERSION 与主包一致**

`App/project.yml` 两处 `SWIFT_VERSION: "6.0"` 与主包 `swiftLanguageModes: [.v6]` 语义一致（都是 Swift 6 语言模式），**不需要改**。此步骤只是确认，不产生改动。

- [ ] **Step 3: 探明 Blossom 在预览宿主中的可行启用方式（C9b）**

依次尝试，任一成功即停，并把成功的方式与失败的证据都记录到 `.claude/epics/coredesign-audit-remediation/updates/92/ci-decision.md`：

1. 检查是否有更新版 xcodegen 支持 traits：

```bash
brew info xcodegen | head -3
xcodegen --version
```

2. 检查 `xcodebuild` 是否提供 trait 参数：

```bash
xcodebuild -help 2>&1 | grep -i trait || echo "xcodebuild 无 trait 参数"
```

3. 若前两条均不可行，用编译条件等价替代——CoreDesign 源码是裸 `#if Blossom`（无 local trait 映射），因此给 App target 设置 `SWIFT_ACTIVE_COMPILATION_CONDITIONS` 在**App 自身代码**中等价；但对**作为依赖编译的 CoreDesign 包**是否生效需实测：

```yaml
# App/project.yml 的 CoreDesignPreview target settings.base 下试加
        SWIFT_ACTIVE_COMPILATION_CONDITIONS: "DEBUG Blossom"
```

```bash
cd App && xcodegen generate --spec project.yml && cd ..
xcodebuild build -project App/CoreDesignPreview.xcodeproj -scheme CoreDesignPreview \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
ls App/CoreDesignPreview.xcodeproj/xcshareddata/xcschemes/   # 确认 scheme 未被删
```

> **路径 3 的预期要写明**：`SWIFT_ACTIVE_COMPILATION_CONDITIONS` 只作用于 **App target 自身的代码**。CoreDesign 作为 SPM 依赖编译时，其 `#if Blossom` 由**包的 trait 解析**决定，不受 App target 的编译条件影响。所以路径 3 大概率**不会**让颜色变成珊瑚粉——实测时要看的是真实渲染色值，不是「构建成功」。构建成功但颜色没变属于失败，不要记为达成。

- [ ] **Step 4: 路径 4——wrapper 本地包（前三条不可行时必须尝试，不可跳过）**

> **本路径已实测验证可行**，不是推测。在 scratchpad 建同构 wrapper 包后，探针输出：
>
> ```
> ### ACCENT DESC: NamedColor(name: "blossom-brand-5", bundle: ...CoreDesign_CoreDesign.bundle)
> ```
>
> 即 `Color.accent` 确实解析到 `blossom-brand-5`（Blossom 珊瑚粉），而非默认的 `brand-5`。**trait 通过 wrapper 真实生效**。因此 C9b 是可达成的，Step 5 的「记录不修」出口只应在本路径也因环境原因失败时才走。

这条路径不依赖 xcodegen 支持 traits，也不怕 `xcodegen generate` 覆盖。在 `App/` 下建一个薄 wrapper 包，由它以 trait 方式依赖 CoreDesign 并 re-export：

`App/BlossomPreviewShim/Package.swift`：

```swift
// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "BlossomPreviewShim",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "BlossomPreviewShim", targets: ["BlossomPreviewShim"]),
    ],
    dependencies: [
        .package(path: "../..", traits: ["Blossom"]),
    ],
    targets: [
        .target(
            name: "BlossomPreviewShim",
            dependencies: [.product(name: "CoreDesign", package: "CoreDesign")]
        ),
    ],
    swiftLanguageModes: [.v6]
)
```

`App/BlossomPreviewShim/Sources/BlossomPreviewShim/Exports.swift`：

```swift
@_exported import CoreDesign
```

`App/project.yml` 的 `packages:` 段把 CoreDesign 换成 shim：

```yaml
packages:
  BlossomPreviewShim:
    path: BlossomPreviewShim
  SnapshotPreviews:
    url: https://github.com/EmergeTools/SnapshotPreviews
    exactVersion: "0.14.0"
```

并把 `CoreDesignPreview` target 的 `dependencies` 从 `- package: CoreDesign` 改为 `- package: BlossomPreviewShim`。

验证（必须看真实 asset 解析结果，不能只看构建成功——这正是 xcodegen `traits:` 的陷阱）：

先用 SwiftPM 层面确认 trait 生效（最快、无需 simulator）。在 shim 包里临时加一个 test target，断言 `String(describing: Color.accent)` 含 `blossom-brand-5`：

```swift
let d = String(describing: Color.accent)
#expect(d.contains("blossom-brand-5"))   // 默认 trait 下会是 "brand-5"
```

确认 trait 生效后再走 Xcode 侧：

```bash
cd App && xcodegen generate --spec project.yml && cd ..
git checkout -- App/CoreDesignPreview.xcodeproj/xcshareddata/   # 恢复被 regenerate 删掉的 shared scheme
xcodebuild build -project App/CoreDesignPreview.xcodeproj -scheme CoreDesignPreview \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -3
ls App/CoreDesignPreview.xcodeproj/xcshareddata/xcschemes/       # 确认 scheme 在
```

- [ ] **Step 5: 四条路径都不可行时才允许记录不修**

在 `ci-decision.md` 中写明：预览宿主无法渲染 Blossom，视觉验证只能靠 Xcode canvas 手动切 trait 或库内 `#Preview`。`audit-checklist.md` 的 C9b 标为「记录不修 + 理由」，并**在 PR 描述中显式声明这是对 92.md 硬验收标准的降级**（92.md 把 C9b 列为 AC，不是尽力而为项）。

**不要为达成它而手工编辑 `.pbxproj`**——下次 `xcodegen generate` 会覆盖掉。

- [ ] **Step 6: 让 C9a 的修正真正落地**

前面各路径无论走哪条，`xcodeVersion: "26.0"` 都只改了 spec 文件，而已提交的 `.xcodeproj` 仍是按旧值生成的。四条 SwiftPM 命令不触碰 `App/`，所以不会暴露这一点。二选一并写明选了哪个：

**(a) 重新生成并提交**（推荐，让生成物与 spec 一致）：

```bash
cd App && xcodegen generate --spec project.yml && cd ..
git checkout -- App/CoreDesignPreview.xcodeproj/xcshareddata/   # 恢复 shared scheme
ls App/CoreDesignPreview.xcodeproj/xcshareddata/xcschemes/       # 确认 scheme 在
xcodebuild build -project App/CoreDesignPreview.xcodeproj -scheme CoreDesignPreview \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -3
```

**(b) 只改 spec、生成物延后**：须在 `ci-decision.md` 写明理由，并注明下次任何人跑 `xcodegen generate` 时生成物才会同步。

- [ ] **Step 7: 验证四条 SwiftPM 命令未受影响**

```bash
swift build && swift test 2>&1 | tail -1 && swift build --traits Blossom && swift test --traits Blossom 2>&1 | tail -1
```

Expected: 与 Task 1 Step 7 相同（`App/` 的改动不影响 SwiftPM 构建）。若 `ToastHostTests` 失败，按 Global Constraints 的 flake 规则重跑一次。

- [ ] **Step 8: Commit（含本 Task 产生的全部落盘物）**

```bash
git add App/project.yml .claude/epics/coredesign-audit-remediation/updates/92/ci-decision.md
git add App/BlossomPreviewShim App/CoreDesignPreview.xcodeproj 2>/dev/null || true   # 若走了路径 4 / Step 6(a)
git status --short          # 确认工作区无遗留未提交文件(跨 Task 脏状态对 subagent 执行是隐患)
git commit -m "Issue #92: fix preview host xcodeVersion; land Blossom trait decision"
```

---

### Task 4: 探测 GitHub Actions runner 能力（C1 的前置决策）

**Files:**
- Create: `.github/workflows/_probe-runner.yml`（临时探针，本任务结束时删除）
- Modify: `.claude/epics/coredesign-audit-remediation/updates/92/ci-decision.md`（**由 Task 3 创建**，本 Task 只追加 CI 章节）

**Interfaces:**
- Consumes: 无
- Produces: runner 能力结论 + 降级级别决定，Task 5 据此实施；`ci-decision.md` 同时是 #4 判断布局断言层是否有自动化守护的依据

**这是本任务不确定性的核心。** 目标不是「让 CI 跑起来」，而是先取得事实：runner 上到底有没有 Xcode 26 和**可用的 iOS 26 Simulator**。仅有 Xcode 26 而无 iOS 26 Simulator 不满足要求（NFR 第 5 条命令依赖它）。

- [ ] **Step 1: 写探针 workflow**

创建 `.github/workflows/_probe-runner.yml`：

```yaml
name: _probe-runner
# 用 push 触发,不用 workflow_dispatch——后者要求 workflow 文件存在于**默认分支**
# 才能 dispatch,而本探针只在 issue 分支上。实测 main 上无任何 workflow
# (gh api .../contents/.github/workflows 返回 404),dispatch 会报
# "could not find any workflows"。
on:
  push:
    paths:
      - '.github/workflows/_probe-runner.yml'

jobs:
  probe:
    strategy:
      fail-fast: false
      matrix:
        image: [macos-26, macos-15, macos-latest]
    runs-on: ${{ matrix.image }}
    continue-on-error: true
    steps:
      - name: Runner image
        run: sw_vers && uname -m

      - name: Available Xcode versions
        run: ls /Applications | grep -i '^Xcode' || echo "none"

      - name: Selected Xcode
        run: xcodebuild -version

      - name: Simulator runtimes
        run: xcrun simctl list runtimes

      - name: iOS 26 runtime present?
        run: |
          if xcrun simctl list runtimes | grep -q 'iOS 26'; then
            echo "IOS26_RUNTIME=yes"
          else
            echo "IOS26_RUNTIME=no"
          fi

      - name: iPhone 17 Pro device present?
        run: |
          if xcrun simctl list devices available | grep -q 'iPhone 17 Pro'; then
            echo "IPHONE17PRO=yes"
          else
            echo "IPHONE17PRO=no"
          fi

      - name: Swift version
        run: swift --version
```

- [ ] **Step 2: 提交并推送探针**

```bash
git add .github/workflows/_probe-runner.yml
git commit -m "Issue #92: add temporary runner capability probe"
git push -u origin issue-92-build-config
```

- [ ] **Step 3: 触发并读取结果**

push 即触发（Step 2 已 push）。等待并读日志：

```bash
run_id=$(gh run list --workflow=_probe-runner.yml --limit 1 --json databaseId -q '.[0].databaseId')
gh run watch "$run_id"
gh run view "$run_id" --log | grep -E 'Xcode |iOS 26|IOS26_RUNTIME|IPHONE17PRO|swift-driver|Darwin'
```

- [ ] **Step 4: 按四级决策树定级并记录**

依据 Step 3 的真实输出，在 `.claude/epics/coredesign-audit-remediation/updates/92/ci-decision.md` 写下结论。判据：

| 级别 | 条件 | 结论 |
|---|---|---|
| 1 | 某个 hosted image 同时有 Xcode 26 + `iOS 26` runtime + iPhone 17 Pro | 用该 image，五条命令全部进 CI |
| 2 | 有 Xcode 26 但无 iOS 26 runtime | 尝试 `xcodes install` / `xcrun simctl runtime add` 装 runtime；装不上则降级 |
| 3 | hosted 均不可行 | self-hosted runner（本机已具备 Xcode 26.4 + iOS 26.4） |
| 4 | 以上均不可行 | 本地 pre-push 脚本作为临时闸门 |

`ci-decision.md` 必须包含：

```markdown
# CI runner 能力结论（Issue #92）

## 实测输出
（粘贴 Step 3 的真实日志片段，不要转述）

## 结论
- 采用级别：N
- Xcode 26 可用：是/否（版本号）
- iOS 26 Simulator runtime 可用：是/否
- iPhone 17 Pro 设备可用：是/否

## 对下游 Issue 的影响
- SC-1（下游 probe 包）：进 CI / 降级为本地执行
- SC-4（CI workflow 覆盖五条命令）：达成 / 部分达成（仅四条 SwiftPM）/ 降级为 pre-push
- **#4 的布局断言层是否有自动化守护：有 / 无**
  （#4 据此判断——若无，它的 `xcodebuild` 验证只能本地手工执行并记录输出）
```

- [ ] **Step 5: 删除探针 workflow**

```bash
git rm .github/workflows/_probe-runner.yml
git add .claude/epics/coredesign-audit-remediation/updates/92/ci-decision.md
git commit -m "Issue #92: record runner capability findings; remove probe"
```

---

### Task 5: 按决策级别落地 CI 门禁（C1）

**Files:**
- Create: `.github/workflows/ci.yml`（级别 1–3）**或** `scripts/pre-push-check.sh`（级别 4）
- Modify: `.claude/epics/coredesign-audit-remediation/updates/92/ci-decision.md`（补充实施记录）

**Interfaces:**
- Consumes: Task 4 的 `ci-decision.md` 结论
- Produces: 后续 Issue 的门禁形态

- [ ] **Step 1（级别 1–3）: 写 CI workflow**

`.github/workflows/ci.yml`，把 `<IMAGE>` 换成 Task 4 定下的 image：

```yaml
name: CI
on:
  push:
    # 包含 issue-** :本 epic 的 11 个 Issue 各有一条 issue-* 分支,让它们在
    # 开 PR 之前就能跑到 CI。也是 Task 5 Step 2 能验证 CI 的前提——若只写
    # main/epic**,在 issue 分支上 push 不会产生任何 run,验证步骤会空等。
    branches: [main, 'epic/**', 'issue-**']
  pull_request:

jobs:
  swiftpm:
    name: SwiftPM (${{ matrix.mode }})
    runs-on: <IMAGE>
    strategy:
      fail-fast: false
      matrix:
        mode: [default, blossom]
    steps:
      - uses: actions/checkout@v4
      # hosted runner 上常装有多个 Xcode,默认选中的未必是 26。若 Task 4 的探针
      # 显示「Xcode 26 存在但非默认」,取消下面两行的注释并填入实测路径。
      # - name: Select Xcode 26
      #   run: sudo xcode-select -s /Applications/Xcode_26.app
      - name: Build
        run: |
          if [ "${{ matrix.mode }}" = "blossom" ]; then
            swift build --traits Blossom
          else
            swift build
          fi
      - name: Test
        # ToastHostTests 的 timing 用例依赖真实墙钟,在负载较高的 runner 上会
        # flake(本机实测同命令连跑两次一绿一红)。失败重跑一次,连续两次才算红。
        run: |
          run_tests() {
            if [ "${{ matrix.mode }}" = "blossom" ]; then
              swift test --traits Blossom
            else
              swift test
            fi
          }
          run_tests || { echo "第一次失败,重跑一次(timing flake)"; run_tests; }

  simulator:
    name: iOS Simulator (layout assertions)
    runs-on: <IMAGE>
    steps:
      - uses: actions/checkout@v4
      - name: Run iOS tests
        # 跳过 "Blossom assets" suite：它用 FileManager 查 .colorset 目录,
        # 那是为 SwiftPM(不调 actool)写的;xcodebuild 会生成 Assets.car,
        # 原始目录不存在,故该 suite 在此环境必然失败。详见 92-plan.md 的
        # 「SwiftPM 与 xcodebuild 是互补的镜像」一节。
        run: |
          run_ios() {
            xcodebuild test \
              -scheme CoreDesign \
              -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
              -skip-testing:CoreDesignTests/BlossomAssetTests \
              CODE_SIGNING_ALLOWED=NO
          }
          run_ios || { echo "第一次失败,重跑一次(timing flake)"; run_ios; }
```

> **`simulator` job 的当前意义**：它跑不到任何 `#if os(iOS)` 布局断言（那由 #4 引入），此刻验证的只是「这条命令在 CI 上能跑通」。#4 落地后才开始真正守护。
>
> **`-skip-testing:` 的标识符已实测确认**：要用**类型名** `BlossomAssetTests`，不是 `@Suite` 的显示名 "Blossom assets"。用显示名不会报错，只是静默不生效（`EXIT=65` 依旧）。实测正确形式的结果：`EXIT=0`、`** TEST SUCCEEDED **`、`Test run with 94 tests`（96 减去被跳过的 2 个）。
>
> 若 Task 4 定级为 2 且 Simulator 不可用，**删掉 `simulator` job** 并在 `ci-decision.md` 注明。

- [ ] **Step 1（级别 4）: 写本地 pre-push 脚本**

`scripts/pre-push-check.sh`（参照 `scripts/run-snapshots.sh` 的 `set -euo pipefail` 惯例）：

```bash
#!/bin/bash
set -euo pipefail

# 本地门禁：CI runner 不具备 Xcode 26 / iOS 26 Simulator 时的临时替代。
# 见 .claude/epics/coredesign-audit-remediation/updates/92/ci-decision.md

cd "$(dirname "$0")/.."

echo "1/5 swift build"
swift build

echo "2/5 swift test"
swift test

echo "3/5 swift build --traits Blossom"
swift build --traits Blossom

echo "4/5 swift test --traits Blossom"
swift test --traits Blossom

echo "5/5 xcodebuild iOS Simulator"
# 跳过 "Blossom assets" suite——它是 SwiftPM-only 的（用 FileManager 查 .colorset
# 目录），xcodebuild 下资源被编译成 Assets.car，原始目录不存在。
xcodebuild test \
  -scheme CoreDesign \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -skip-testing:CoreDesignTests/BlossomAssetTests \
  CODE_SIGNING_ALLOWED=NO

echo "全部通过"
```

```bash
chmod +x scripts/pre-push-check.sh
```

- [ ] **Step 2: 验证门禁本身可用**

级别 1–3：

```bash
git push
gh run list --workflow=ci.yml --limit 1
run_id=$(gh run list --workflow=ci.yml --limit 1 --json databaseId -q '.[0].databaseId')
gh run watch "$run_id"
```

Expected: 所有 job 绿

级别 4：

```bash
./scripts/pre-push-check.sh
```

Expected: 打印到「全部通过」

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/ci.yml   # 或 scripts/pre-push-check.sh
git add .claude/epics/coredesign-audit-remediation/updates/92/ci-decision.md
git commit -m "Issue #92: land CI gate at determined fallback level"
```

---

### Task 6: 更新审计清单并写完成记录

**Files:**
- Modify: `.claude/epics/coredesign-audit-remediation/audit-checklist.md`（C1、C7a、C7b、C9a、C9b 五行）
- Create: `.claude/epics/coredesign-audit-remediation/updates/92/progress.md`

**Interfaces:**
- Consumes: 前五个 Task 的全部结论
- Produces: SC-7 的判定依据

- [ ] **Step 1: 更新五个审计项状态**

在 `audit-checklist.md` 中，把 C1、C7a、C7b、C9a、C9b 五行的处置状态改为「已修复」，或对未达成项写明「记录不修 + 理由」（尤其 C7b 若工具链不支持 `.v26`、C9b 若 xcodegen 不支持 traits）。

**注意计数口径**：该文件头部的核对命令依赖行首形态 `^| [A-D][0-9]`，修改时**不要改动列结构**，只改单元格内容。改完跑一次核对：

```bash
cd /Users/evan/Repositories/work-spec/CoreDesign/.worktrees/issue-92-build-config/.claude/epics/coredesign-audit-remediation
echo $(( $(grep -c '^| [A-D][0-9]' audit-checklist.md) - 4 ))   # 期望 83
grep -oE '\| #[0-9]+ \|$' audit-checklist.md | sort -V | uniq -c | awk '{s+=$1} END {print s}'  # 期望 79
```

- [ ] **Step 2: 写 progress.md**

```markdown
---
issue: 92
started: <date -u +"%Y-%m-%dT%H:%M:%SZ">
last_sync: <同上>
completion: 100%
---

# Issue #92 完成记录

## defaultIsolation fallout 修复清单

| 文件 | 改动 | 是否在 #6 删除名单 |
|---|---|---|
| `Sources/CoreDesign/Tokens/CoreSpacing.swift:26` | 加 `nonisolated` | 否 |
| `Sources/CoreDesign/Tokens/CoreRadius.swift:24` | 加 `nonisolated` | 否 |

未对 `CoreElevation` / `CoreTypography` / `CoreButtonMetrics` / `CoreBorderWidth` /
`CoreControlMetrics` 做同样处理——前两者持有 `Color` / `Font`（MainActor 隔离的
SwiftUI 类型），标 `nonisolated` 会产生 17 个 error；后三者当前无 nonisolated
上下文引用，按「最小化」约束不动。

## CI 结论

见 `ci-decision.md`。采用级别 N。**#4 的布局断言层是否有自动化守护：有/无**。

## 未达成项（如有）

- C7b / C9b：<理由>
```

- [ ] **Step 3: 跑完整验证**

```bash
cd /Users/evan/Repositories/work-spec/CoreDesign/.worktrees/issue-92-build-config
swift package clean
swift build && swift test 2>&1 | tail -1 && swift build --traits Blossom && swift test --traits Blossom 2>&1 | tail -1
swift test 2>&1 | grep 'warning:' | grep -v "is deprecated: Use SwiftUI ContentUnavailableView"   # 期望无输出
```

- [ ] **Step 4: Commit**

```bash
git add .claude/epics/coredesign-audit-remediation/
git commit -m "Issue #92: update audit checklist and record completion"
```

---

## 收尾

全部 Task 完成后：

1. `oh-my-superpowers:verification-before-completion` —— 给「完成」结论前必须有命令输出为证
2. `oh-my-superpowers:finishing-a-development-branch` —— Option 2 开 PR，**base = `epic/coredesign-audit-remediation`**，禁止直接合 `main`
3. PR 开出后进 `auto-fix-pr-after-implementation`
