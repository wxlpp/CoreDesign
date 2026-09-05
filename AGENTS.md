# AGENTS.md

> **本文件是 `CLAUDE.md` 的 Codex 版镜像。`CLAUDE.md` 为 source of truth——两者若有分歧，以 `CLAUDE.md` 为准。** 本次（#102）已把 pre-audit 快照中的已知错误全部修正、逐行对齐当前 `CLAUDE.md`（正文与其 diff 仅本 banner 与首行「Codex/Claude Code」定位差异）：`.claude/` 路径（原误作 `.Codex/`）、#93 移除的 `Color.primary/secondary/tertiary`、#97 移除的 `.getSize`、token / 路径改名（`statusDangerForeground`、`Tokens/CoreGradient.swift`）均已修正。**未来 `CLAUDE.md` 更新时须同步本文件**（持续 follow-up 义务）。

本文件为 Codex 在本仓库中工作时提供指引。

## 项目概述

CoreDesign 是一个以 Swift Package 形式分发的 SwiftUI 设计系统库。目标平台为 iOS 26+ / macOS 26+，采用 Swift 6 语言模式（`swiftLanguageModes: [.v6]`，开启完整严格并发检查。

## 常用命令

```bash
swift build                                  # 构建库
swift test                                   # 运行所有测试（使用 Swift Testing，而非 XCTest）
swift test --filter CoreDesignTests.example  # 按完整名称运行单个测试
swift package resolve                        # 修改 Package.swift 后刷新依赖
swift package clean                          # 缓存出问题时清除 .build/ 目录
```

测试 target 使用 Apple 的 Swift Testing 框架（`import Testing`、`@Test`、`#expect`）。除非有明确理由，否则不要引入 XCTest。SwiftUI 的 `#Preview` 块与对应组件放在同一文件中——它们不是测试，但是组件的主要视觉冒烟检查方式。

## 架构

### 分层色彩系统

颜色按四层堆叠组织——根据意图选择对应层级，不要在组件中直接使用底层原子色。`0.3.0`
把地基从 GitHub Primer 换成 Apple HIG 后，第 3 层绝大多数 token 已改指系统语义色 API；
逐 token 的取值理由与新旧映射见 `docs/DESIGN-FOUNDATION.md`。

1. **资源调色板**（`Colors/ColorGrade.swift`）—— 17 种命名色相 × 10 个色阶（`brand-0`…`yellow-9`），由 `Resources.xcassets` 中的 color set 提供。通过 `Color("...", bundle: .module)` 加载。第 3 层迁到系统色后，本层现仅为 `StatusColors`（24 个状态色 token，Apple 无对应系统概念）与 `InteractionColors` 的 `secondaryAccent` / `neutralAccent` 族（显式定案保留品牌色阶）供色；组件代码中应避免直接使用第 1 层。
2. **系统色桥接**（`Colors/SystemBackgroundColors.swift`、`SystemLabelColors.swift`）—— 通过 `#if canImport(UIKit)` / `AppKit` 把 `UIColor` / `NSColor` 系统色重新导出为 `Color`，保证同一名称在两端平台都能编译。现在是第 3 层大多数 token 的直接来源。
3. **语义化 token**——`SurfaceColors`、`ContentColors`、`BorderColors`、`FillColors`、`InteractionColors`、`StatusColors`。命名描述用途而非色相（`surfaceRaised`、`contentPrimary`、`accent`、`accentPressed`、`statusDangerForeground`）。多数 token 直接改指系统语义色（`systemGroupedBackground` 族、`label` 族、`separator` 族、`systemFill` 族），随系统外观 / 对比度设置自动更新；`accent` 改指宿主 App 的 `Color.accentColor`，衍生态（`accentHover` / `accentPressed` / `accentDisabled` / `accentSubtleBackground`）用 `Color.mix(with:by:in:)` / `.opacity()` 对 `accent` 本身调制，而非各取固定色阶。`secondaryAccent` / `neutralAccent` / `StatusColors` 显式定案保留 `ColorGrade` 品牌色阶——Apple HIG 没有"第二强调色"或"5 态状态色板"的系统概念，无桥接目标。
4. **状态功能别名**（`Colors/FunctionalColor.swift`）—— `success`、`info`、`warning`、`danger` 及其现有变体。本层为 `public`，是最高层的 API 表面。

   **交互色不在此层**——`accent` / `secondaryAccent` / `neutralAccent` 等走第 3 层 `InteractionColors`。该层曾定义 `Color.primary/secondary/tertiary` 三组，因与 SwiftUI 内建成员同名而遮蔽它们（删除时编译器不报错，只静默改变解析目标），已于 Issue #93 移除。

新增组件时优先使用第 3、4 层名称。如果缺少需要的语义 token，应在对应文件中补充新名称，而不是把第 1 层色相硬编码进组件。

### 多 target 结构

本包不再是单 target。`Package.swift` 现有**四个** library product：

| product | 内容 | 备注 |
|---|---|---|
| `CoreDesign` | 系统原生观感的组件、四层色彩、token、modifier | 主体，**不依赖**下面两个 |
| `CoreDesignEffects` | 表达性视觉层：微交互 / 转场 / 庆祝与处理中动效 | 依赖 `CoreDesign` |
| `CoreDesignCharts` | Swift Charts 原生画不出来的四类图表（雷达图 / 活动环 / 贡献热力图 / 力导向网络图） | 依赖 `CoreDesign`；**有意不 `import Charts`** |
| `CoreDesignShaders` | Metal shader 程序化背景与内容层效果 | 依赖 `CoreDesign`；⚠️ **含 `.metal` 源，构建有额外约束**——见下方《验证边界与常见坑》 |

拆开的理由：只想要系统原生观感的消费者不必背上动效与图表。依赖是**单向**的
（`CoreDesign` 的 `target_dependencies` 必须恒为 `[]`），两条 `swift package describe`
判据守着它，见下方《验证边界与常见坑》。

⚠️ **新 target 各有独立的 test target**（`CoreDesignEffectsTests` / `CoreDesignChartsTests` /
`CoreDesignShadersTests`），
**不并进 `CoreDesignTests`**——并进去需要 `@testable import`，会让 `CoreDesignTests` 的
依赖图包含新 target，破坏上面那条隔离判据。


⚠️ **`CoreDesignShaders` 的构建约束**（`0.5.0` 起）：**原生 `swift build` 不编译 `.metal`**
——它只会把声明为资源的 `.metal` **源码**拷进 bundle，`default.metallib` 不会产生。
只有 `swift build --build-system swiftbuild` 与 `xcodebuild` 会真编。
⇒ 本地跑 shader 相关测试须用
`swift test --build-system swiftbuild --filter CoreDesignShadersTests`；
CI 的 SwiftPM 腿**显式 `--skip CoreDesignShadersTests`** 并另起一步用 swiftbuild 跑它。
⚠️ **不要整腿切 swiftbuild**：那会让 `ColorAssetGuardTests` 的 colorset 存在性守卫
**静默跳过**（swiftbuild 调 actool 把 `.xcassets` 编成 `Assets.car`，而那个 suite 的
启用条件是「`Resources.xcassets/` 以目录形式存在」）。

⚠️ **源码守卫的扫描根有两份，不要混为一谈**（`#246` 立的表、`#270` 把登记表并了进来、
`#279` 把 `CoreDesignShaders` 接了进去）：

| 根列表 | 谁在用 | 覆盖 |
|---|---|---|
| `GuardScanRoots.allRoots`（`Tests/CoreDesignTests/GuardScanRoots.swift`） | Bool 纪律（`BoolExemptionGuard` / `BoolParameterScanner`）、a11y 字面量、NFR-4 的 `@unchecked Sendable` grep、**组件登记表**（`ComponentRegistryGuard.componentScanRoots` 直接返回它）与 J-2 / J-3 / FR-4 那一串判据 | `targetNames` 里的全部 target（现为四个） |
| `GuardScanRoots.newTargetRoots` | `EffectsColorLiteralGuard`（禁色相字面量）、`ChromeTextLiteralGuard`（禁 A 类 chrome 文案）、`ExtensionEntryPointGuard`（扩展成员入口点） | **只有**新 target（Effects / Charts / Shaders），有意不回溯改造 CoreDesign 现状 |

⚠️ 新增 library target 时**必须**把它加进 `GuardScanRoots.targetNames`——该表与
`Package.swift` 声明的 library target 做双向差集，忘了扩根会当场判红（这是刻意的
fail-closed：对一个不在列表里的 target，全部 grep 判据都无命中即绿）。
⚠️ **同轮还有三处要跟着改，不然会红在别处**：① `docs/bool-exemptions-baseline.json` 的
`perTarget` 必须为新 target 补一条（哪怕是 `0/0`，键集合与 `targetNames` 做等式）；
② 该 target 的公开类型要按公约判定法登记进 `docs/component-registry.json`，
`public extension` 成员登记进同一份文件的 `entryPoints`；
③ `docs/README.md` 要有能覆盖这些条目的索引行（解析范围是
`## 组件索引 → ## 生成预览图` 与 `## 动效与图表索引 → ## NFR-1 帧率基准` 两段）。
⚠️ `App/project.yml` 也要加 `product:` 条目，**并同步 `App/CoreDesignPreview.xcodeproj/project.pbxproj`**
（`AppProjectManifestGuard` 的 K1/K2 两条判据逐条对账；⚠️ **不要在 worktree 里跑
`xcodegen generate`**，照着既有条目手工补齐或在主仓生成）。
⚠️ 台账键对新 target 带 `<Target>/` 前缀，主 target 保持裸形（`Owner.decl#param`）。

### 按钮样式模式

所有按钮样式遵循统一形态：`*ButtonStyle: ButtonStyle` + 在 `ButtonStyle where Self == ...` 上扩展 `static func *Button(role:) -> Self`，通过单个 `ButtonRoleStyleRole` 枚举（`Components/Button/ButtonRoleStyleRole.swift`）参数化。该枚举是 `color` / `activeColor` / `disabledColor` 的唯一来源——新增 role 时应扩展此枚举，而不是为每个样式各自定义调色板。样式从 `@Environment(\.controlSize)` 读取尺寸、从 `\.isEnabled` 决定禁用配色。

⚠️ 本节曾写「重度使用 iOS 26 的 `.glassEffect()`；`LightButtonStyle` 会按 `colorScheme` 分支：暗色用 `glassEffect`，亮色用柔和阴影代替」——**后半句实测为假**（#41 收尾时发现）：`Sources/CoreDesign/Components/Button/styles/` 下**没有任何按钮样式**直接调用 `.glassEffect`，也**没有任何一个读 `colorScheme`**；`LightButtonStyle.makeBody` 走的是 `buttonChrome` + `buttonBackground(fill: .surfaceInteractive, border: .borderSubtle)` + 链尾 `.opacity`，明暗差异全部来自系统语义色 token 的自动适配，不是代码分支。（该句在 #41 之前的 `95c29cf` 上就已失真，不是 #41 删 `glass` 簇造成的。）

`.glassEffect` 的真实调用面在组件与 modifier 层：`BottomInputBar`、`Carousel`、`SegmentedControl`、`FloatingGlassModifier`、`TelegramGlassButtonModifier`。按钮样式经 `TelegramGlassButtonModifier` 等间接使用。

### 组件 style 协议

需要支持多种外观的组件（目前是 `Banner`）遵循 Apple 自家 `ButtonStyle`/`ToggleStyle` 的形态：

- 公开 `BannerStyle` 协议，包含 `makeBody(configuration:)` 与 `BannerStyleConfiguration`。
- 提供具体样式实现（`PlainBannerStyle`、`BorderedBannerStyle`）。
- 通过 `EnvironmentValues` 入口（`@Entry var bannerStyle`）和 `View.bannerStyle(_:)` modifier 注入。

新增带样式的组件时复用该形态，不要另立平行模式。

### 系统控件 `.core` style 与分组容器（Phase 2 / `0.4.0`）

- **`.core` style 的强调色必须走 `.tint` 通路**：`ProgressView` / `Label` / `DisclosureGroup` 各有一个 `.core` style（`Components/Style/`），**换皮不重造控件**；`makeBody` 中强调色一律经 `TintShapeStyle`（`.tint`）取，**不得写死 `Color.accent`**——否则调用方 `.tint(_:)` 对这些控件静默失效（FR-12）。`Toggle` / `TextField` 有意未提供 `.core` style（前者丢原生手势/haptic，后者 `_body` 私有无公开自定义入口）；设置行里的开关直接用系统 `Toggle` + `.tint`。
- **分组容器只复刻视觉、不复刻 `List` 能力**：`InsetGroupedSection` / `SettingsRow` 复刻 iOS `.insetGrouped` 观感（圆角卡片 + raised 背景 + 自动分隔线 inset），但不做数据/滚动/编辑——因此能嵌进已有 `ScrollView` / `VStack`，也能直接作原生 `List` 行（配 `.listRowInsets(EdgeInsets())`）。相邻行分隔线用 iOS 18+ `Group(subviews:)` 在真实子视图间插入，leading inset 从 `SettingsRowMetrics` 推导（不硬编码，改图标尺寸自动跟随）。
- **`Card` 是薄封装**：`Card` = `.surface(.content)` + 默认内边距，不重造背景/描边/圆角；需更细控制直接用 `View.surface(_:)`。分隔件 `Separator(inset:)` 走 `Color.dividerDefault` 系统色、hairline 宽度。

### Modifier 约定

可复用的 `ViewModifier` 放在 `Modifier/` 目录下；以 `View` 扩展形式暴露（如 `.bordered(...)`），而不是要求调用方写 `.modifier(BorderModifier(...))`。跨组件复用的纯辅助扩展放在 `Utils/`（目前仅 `ColorExtension.swift`）；只服务单个组件的辅助扩展与组件同文件（如 `.focusedExternally` 在 `BottomInputBar.swift`）。

### 资源加载

所有资源查找都必须传入 `bundle: .module`——包通过 `.process("Resources")` 处理 `Sources/CoreDesign/Resources`，SwiftUI 默认的 main bundle 查找方式找不到这些资源。

### 公开 API 表面

调用方依赖的内容必须显式标记为 `public`（包括 init）。Swift 默认可见性是 internal，漏写 `public` 会悄无声息地导致下游编译失败——新增组件时务必检查导出。现有组件展示了惯例：public 类型、public init、public `body`、private state。

## 验证边界与常见坑

「`swift build` / `swift test` 全绿」不等于「一切都验证过了」——本仓库有好几块验证盲区，
不了解会误判为绿：

- **`swift build` 不编译 `Tests/`**，`swift test` 才编译并跑测试；但 `Tests/` 下 `#if
  os(iOS)` 的 suite（如 `DynamicTypeLayoutTests`）在 macOS 上是**空 suite**——`swift
  test` 通过在这类 suite 上是假绿，必须看 CI 的 **xcodebuild iOS Simulator 腿**（或本地跑
  `xcodebuild test -scheme CoreDesign-Package -destination 'platform=iOS Simulator,...'`）才作数。
  ⚠️ scheme 必须是 `CoreDesign-Package`——理由见下方《多 target 结构》。
- **`App/`（预览宿主）不受 `swift build` / `swift test` 覆盖，CI 也不构建它**——它是独立的
  `xcodegen` 生成的 `.xcodeproj`，只能用 `scripts/run-preview.sh` 或直接
  `xcodebuild -project App/CoreDesignPreview.xcodeproj` 手动验证。删除或改名公开符号后
  务必手动确认它仍能构建，否则预览宿主可能已经无法编译却没人发现（trait 删除这类
  manifest 层变更尤其如此——报错发生在依赖解析期，不会在库自身的编译期出现）。
- **`scripts/downstream-probe` 是独立 SwiftPM 包**（自带 `Package.swift`），只有 CI 的
  `downstream-probe` job（`cd scripts/downstream-probe && swift build`）覆盖它。任何
  删除/改名公开符号都必须同步这个包，否则本地 `swift build` 全绿而这个 job 会红。
- **在 git worktree 里跑 `xcodegen generate` 有坑**：会把 `App/project.yml` 里 local
  package 的 `name` 按当前目录名（而非 `CoreDesign`）写死，并清空
  `xcshareddata/xcschemes/CoreDesignPreview.xcscheme`。完整警告与恢复步骤见
  `App/project.yml` 顶部注释；验证要覆盖 `name=` 字段与文件内注释两种形态的目录名
  残留，只查一种会漏。
- **新增 / 修改 `.xcassets` 里的 colorset 后必须 `swift package clean` 再构建/测试**：
  macOS SwiftPM 以目录形式而非 `.car` 分发 `.xcassets`，增量构建不会拷贝新加的目录，
  资源缺失是静默失败，颜色断言抓不到。

- **多 product 之后，CI 的 iOS 腿必须用 `-scheme CoreDesign-Package`**：包只有一个
  product 时 Xcode 把包 scheme 合并进同名 scheme，于是 `-scheme CoreDesign` 恰好能跑测试；
  多 product 后 scheme 列表变成 `CoreDesign` / `CoreDesign-Package` / 各 product 一个，
  而 `xcodebuild test -scheme CoreDesign` 会**硬红**（不是静默跳过）：
  `error: Scheme CoreDesign is not currently configured for the test action`。
- **两条隔离判据**（改 `Package.swift` 后必跑）：
  `swift package describe --type json | jq '.targets[] | select(.name=="CoreDesignTests") | .target_dependencies'`
  须恰为 `["CoreDesign"]`；同样的查询对 `CoreDesign` 自身须输出 **`null`**（禁反向依赖）。
  ⚠️ **是 `null` 不是 `[]`**：无依赖的 target 在 SwiftPM 的 JSON 里该字段**直接缺席**，
  jq 取到的是 `null`。照 `[]` 写判据会永远判红。
- **`App/project.yml` 在多 product 下必须逐条写 `product:`**：不写只会链同名的
  `CoreDesign` 产品，失效形态是「预览宿主编译得过、但画廊里的新组件 import 不到」。

## 仓库内的代码风格观察

- 即使在同一类型内访问成员也显式使用 `self.`（如 `self.controlSize`、`self.title(item)`）。修改现有文件时保持一致。
- 注释与 `// MARK: -` 标题双语混用（中文 + 英文），这是有意为之，编辑时与周围文件保持一致。部分注释是较长的设计说明（例如 `BottomInputBar.autoFocus` 解释了为何必须放在 bar 自身的 `onAppear` 中执行），编辑时予以保留。
- 组件大量使用 `iOS 26+` API：`.glassEffect`、`.safeAreaBar`、`EnvironmentValues` 上的 `@Entry`、`matchedGeometryEffect`。除非部署目标下调，否则不要为这些 API 加可用性回退。

## 工作流 skill（项目本地 `.claude/skills/`）

本仓库启用了三个工作流 skill——通过 `Skill` 工具调用，不要手动读取 SKILL.md 文件：

- **`ccpm`**——规格驱动流程（PRD → epic → 任务拆解 → GitHub Issues → 并行 agent）。当用户处理有计划的交付工作时启用；status/standup/next 这类确定性查询在 skill 的 `references/scripts/` 下已有现成的 shell 脚本，直接运行而不要重新实现。
- **`copilot-cross-review`**——CCPM 在 `.claude/prds/` 或 `.claude/epics/` 中写入/更新 PRD 或 epic 后，进入下一阶段前先运行 `copilot -p "..."` 做第二意见审查。最多 2 轮。
- **`auto-fix-pr-after-implementation`**——`superpowers:finishing-a-development-branch` 创建 PR 之后，轮询 Copilot review 并把反馈喂给 fix-pr 循环。无人值守最多自动运行 3 轮，达到上限后须由用户确认是否继续。遇到构建/测试失败或需要人工判断的 `CHANGES_REQUESTED` 时立即停止。

用户全局配置同时启用了 Context7 MCP 用于查询库文档（`mcp__context7__resolve-library-id` → `query-docs`）——查询外部库 / 框架 / SDK 时优先使用它，而不是 WebSearch。
