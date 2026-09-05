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

⚠️ **遮罩基色不在这四层之内**：`Color.maskOpaque`（`Colors/MaskColors.swift`，`#276`）是给 `.mask { … }` 用的**不透明基色**，唯一契约是 **α = 1**——`mask` 只吃 alpha，RGB 通道**不参与合成**（实测黑遮罩与白遮罩逐字节相同），所以它不是一个"颜色决定"。⚠️ **不要拿 `.primary` / `.contentPrimary` 当遮罩基色**：它们映射到 `label`，**macOS 实测 α = 0.8471、iOS 实测 1.0**，会让「完全揭示」在 macOS 上只揭示到 85%，而且不报错。纯几何的揭示优先走 `clipShape`（不涉及 alpha，`BeforeAfterRevealClip` 是先例）；新加 `.mask` 点位必须登记到 `MaskSiteRegistryGuard.registeredSites`。

### 多 target 结构

本包不再是单 target。`Package.swift` 现有三个 library product：

| product | 内容 | 备注 |
|---|---|---|
| `CoreDesign` | 系统原生观感的组件、四层色彩、token、modifier | 主体，**不依赖**下面两个 |
| `CoreDesignEffects` | 表达性视觉层：微交互 / 转场 / 庆祝与处理中动效 | 依赖 `CoreDesign` |
| `CoreDesignCharts` | Swift Charts 原生画不出来的四类图表（雷达图 / 活动环 / 贡献热力图 / 力导向网络图） | 依赖 `CoreDesign`；**有意不 `import Charts`** |

拆开的理由：只想要系统原生观感的消费者不必背上动效与图表。依赖是**单向**的
（`CoreDesign` 的 `target_dependencies` 必须恒为 `[]`），两条 `swift package describe`
判据守着它，见下方《验证边界与常见坑》。

⚠️ **新 target 各有独立的 test target**（`CoreDesignEffectsTests` / `CoreDesignChartsTests`），
**不并进 `CoreDesignTests`**——并进去需要 `@testable import`，会让 `CoreDesignTests` 的
依赖图包含新 target，破坏上面那条隔离判据。

⚠️ **源码守卫的扫描根有三个入口，不要混为一谈**（`#246` 落地、`#270` 收口后）：

| 根列表 | 谁在用 | 覆盖 |
|---|---|---|
| `GuardScanRoots.allRoots`（`Tests/CoreDesignTests/GuardScanRoots.swift`） | Bool 纪律（`BoolExemptionGuard` / `BoolParameterScanner`）、a11y 字面量、NFR-4 的 `@unchecked Sendable` grep | 三个 target 全覆盖 |
| `GuardScanRoots.newTargetRoots` | `EffectsColorLiteralGuard`（禁色相字面量）、`ChromeTextLiteralGuard`（禁 A 类 chrome 文案）、`ExtensionEntryPointGuard`（扩展成员入口点） | **只有**新 target，有意不回溯改造 CoreDesign 现状 |
| `ComponentRegistryGuard` 的 `componentScanRoots`（`#270` 前叫 `coreDesignSources`，当时确是单根） | 组件登记表与 J-2 / J-3 / FR-4 那一串判据 | **`#270` 起直接返回 `GuardScanRoots.allRoots`，三 target 全覆盖**，不另列一份根名（两套根必然漂）。⚠️ 本行原写「仍只有 `Sources/CoreDesign`、扩它会顶动 AD-4《下游连锁一》那串断言、归 `#255` 处置」——`#270` 落地后**已失真**，`ComponentExtensionPointGuard` 的 `inspected.count == 11` 在三根下照样成立 |

⚠️ 新增 library target 时**必须**把它加进 `GuardScanRoots.targetNames`——该表与
`Package.swift` 声明的 library target 做双向差集，忘了扩根会当场判红（这是刻意的
fail-closed：对一个不在列表里的 target，全部 grep 判据都无命中即绿）。
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
- **走 asset catalog 查找的那 198 个颜色常量，在 macOS `swift test` 下全部解析为透明
  ——颜色断言在这条腿上抓不到**（`#275`。⚠️ 本条**推翻**了这里原来那句「新增 / 修改
  colorset 后必须 `swift package clean` 再构建/测试；增量构建不会拷贝新加的目录」
  ——成因与补救都不对，逐条见下）。
  - ⚠️ **术语，别与《分层色彩系统》的「第 1 层」混用**：本条说的「走 asset catalog 查找的
    198 个常量」是**构建产物意义上**的集合——所有 `Color("…", bundle: .module)` 形式、
    磁盘上一一对应 `Resources.xcassets/**/*.colorset` 的常量（实测 `find … -name
    '*.colorset' | wc -l` = 198）。上面《分层色彩系统》里的 layer 1 = **仅** `ColorGrade`
    的 170 个色阶（`StatusColors` 列在 layer 3，`CoreElevation` 的阴影根本不在色彩分层里）
    ⇒ 两者**外延不同**。本条一律用前者。
  - ⚠️ **机理不是本轮首次查明**：`ColorAssetGuardTests` 的注释早就写对了「xcodebuild 会调
    `actool` 把整个 xcassets 编译成单个 `Assets.car`」，而「`swift test` 进程里资源色解析成
    完全透明」在 `#274` 就已实测并写进 `CoreDesignEffectsTests/CrossPlatformTests.swift`。
    `#275` 做的是**再发现 + 把两半合并 + 量化到 token 级 + 装机器判据**，不是首次发现。
  asset catalog 在本仓有**两种产物形态**，由构建路径决定：
  - `swift build` / `swift test`（SwiftPM native，即日常 macOS 腿）：**不调 `actool`**，
    `.process("Resources")` 对 `.xcassets` 就是一次**目录原样拷贝**。产物里是
    `Info.plist` / `Resources.xcassets/` / `en.lproj/`，**没有 `Assets.car`**。
    而 `Color(_:bundle:)` 在 AppKit 下最终落到 `NSColor(named:bundle:)`，**只认编译后的
    catalog** ⇒ 每一次查找都 miss、返回 clear。
  - `xcodebuild`（iOS Simulator 腿）与 `swift test --build-system swiftbuild`：跑 `actool`，
    产物里是 `Assets.car`，同一批 token 取值正常。
  ⇒ 在 macOS 腿上，这 **198 个** `Color("…", bundle: .module)` 常量
  （`Colors/ColorGrade.swift` 170 个色阶 + `Colors/StatusColors.swift` 24 个 status token
  + `Tokens/CoreElevation.swift` 4 个 shadow token）**以及原样转手它们的别名**
  （`InteractionColors` 的 `secondaryAccent` / `neutralAccent` 两族共 8 个、
  `FunctionalColor` 全部 10 个）**一律 `resolve(in:)` 出 `(0, 0, 0, 0)`**。
  两条腿的实测对照（同一份探针、同一个 commit）：`statusDangerForeground` 在 macOS 腿是
  `a=0.0`、在 iOS 腿是 `r=0.812 g=0.133 b=0.180 a=1.0`；同一次运行里
  `accent` / `contentPrimary` / `surfaceRaised` 这些系统语义色**两条腿都正常**。
  - ⇒ **硬规则：这 198 个常量及其别名绝不可进 macOS 腿的位图 / `resolve(in:)` 断言。**
    失效方向**向绿**：`a != b` 会因为其中一张根本没画出来而通过——判到的是「这个色没渲染」，
    不是「取色跟着调用方走」。阈值型断言（`α > x`）则会恒红得莫名其妙。
  - ⚠️ **`swift package clean` 对这一条毫无作用**：它是构建计划的结构性事实，
    从零构建一模一样。原句里「增量构建不会拷贝新加的目录」今天也**不成立**——实测新增一个
    colorset 目录后裸跑 `swift build`，日志就是 `[1/2] Copying Resources.xcassets`、
    新目录当场进 bundle，删除同理（Swift 6.3 / Xcode 26.4）。
    ⚠️ **「删除同理」只在 `.xcassets` 内部（colorset 粒度）成立**，
    删掉 / 改名**一整个顶层 resource item** 时不成立：实测把
    `Sources/CoreDesign/Resources/Resources.xcassets` 整个改名成 `Renamed.xcassets`
    后裸跑 `swift test`，产物 bundle 里**新旧两个目录同时存在**、
    本次跑的三个 suite（`ColorGradeResolutionGuard` / `ResourceBundleCanaryTests` /
    `ColorAssetGuardTests`）共 9 条全绿 `EXIT=0`；改回来之后 `Renamed.xcassets`
    仍作为孤儿留在 bundle 里。⇒ SwiftPM 增量构建**不清理已消失的顶层 resource item**，
    **那一格 `clean` 确实是补救**。
    clean 仍然是缓存出问题时的通用手段，但**不是**上面那条结构性盲区的补救
    ——⚠️ 别把本条读成「clean 对资源验证一律无用」：分两格看。
  - 机器判据：`ColorGradeResolutionGuard`（`Tests/CoreDesignTests/`）**五条**——
    两条按 bundle 形态**分叉**：有 `Assets.car` 时由
    `ColorGradeResolutionGuard.catalogColorsResolveOpaqueOnCompiledCatalog` 正向断言抽样
    token 非全透明；只有目录形态时由
    `ColorGradeResolutionGuard.catalogColorsAreFullyTransparentOnRawXcassets` 反向钉死
    「恒为全透明」。不适用的那条**显式 skip 且打印原因**，因为跳过在退出码上等同于通过。
    另有三条**无条件**：`ColorGradeResolutionGuard.catalogFormIsDetectable`
    （两种形态都探不到就判红，兜住上面双 skip）、
    `ColorGradeResolutionGuard.sampleBasisHasExpectedCardinality`（抽样面被清空 / 缩水就判红）
    与 `ColorGradeResolutionGuard.sampleLabelsMatchTheirColors`（label 与取值不同源就判红）。
    ⚠️ **这里写限定名不是排版洁癖**：`JudgementReferenceGuard` 的规则 A 只认
    `类型.成员` 形态，裸判据名它不核 ⇒ 上面这个「五条」的清单本身曾是散文——
    删掉其中一条不会有任何东西变红（**正是本节在讲的那个病的元层**）。写成限定名之后
    改名 / 删除至少会被规则 A 接住。⚠️ 但**数字「五」仍是散文**，仍要人工同步。
    ⚠️ 后两条都是补的，且补的正是这个文件自己犯过的病：
    · `sampleBasisHasExpectedCardinality`——`samples` 一旦返回 `[]`，两条分叉判据的循环
    一次都不进，**两条腿都给 `EXIT=0` 全绿**（实测）；它按**三组各钉一个数**，
    只钉总数会让一组缩水被另一组增长掩盖。
    · `sampleLabelsMatchTheirColors`——把 `("brand5", .brand5)` 写成 `("brand5", .amber5)`
    时**两条腿全绿 `EXIT=0`**（实测）：上一条只核名字集合的基数与归属，不核名字与取值
    **同源**，后果是失败信息**指错 token**。它用 `TestSupport.swift` 里既有的共享内省辅助
    抠出 `Color` 内部的 asset 名，与 label 推出的名字对表；抠不出来时**判红而不是跳过**。
  - **抽样面：44 个（共 198 个中）**——色阶 **17 / 170**（17 色相各取 grade 5 一档；
    ⚠️ 磁盘上是 `brand/brand-0.colorset` … `brand-9.colorset` **10 个独立目录**，
    「同源同目录」的说法是错的）、status **24 / 24**、shadow **3 / 4**
    （`shadow-none` 两种外观下 α 都是 `0.000`，是设计上的全透明，进正向判据会恒红）。
    ⚠️ **如实登记覆盖缺口**：未抽样的 153 个色阶若 colorset 目录被改名 / 删除，
    **编译腿（`xcodebuild` / `swiftbuild`）上不判红**；抓它的
    `ColorAssetGuardTests.hueRampColorsetsPresent` 逐目录查 `fileExists`，而那个 suite
    **只在 macOS native 腿启用**（编译腿产物里根本没有 `Resources.xcassets/` 目录可查）。
    ⇒ 两条腿各兜一半，CI 合起来兜得住目录改名；**单看任一条腿都有缺口**。
  - 今天全仓**唯一**把这批 token 喂进 `resolve(in:)` 的判据是
    `SurfaceContrastTests.statusSubtleFillsAreDistinguishableInDark`（5 个 `status*Subtle`），
    它整个 suite 在 `#if os(iOS)` 里 ⇒ 只在 catalog 已编译的那条腿上跑，**没有空转**。
    其余判据免疫的机制有**四类，机制各不相同**，本次覆盖到的就是这四类：
    1. `StatusColorsTests` / `TimelineTests`：断言的是 **asset 名**（经 `assetName`），不解析；
    2. `ColorAssetGuardTests`：查的是**文件系统里的目录是否存在**，不解析颜色；
    3. `ColorGradeResolutionGuard` 自己：解析，但**按形态分叉**，在 macOS 腿上断言的正是
       「恒为全透明」这一侧；
    4. `ButtonRoleStyleRoleTests.everyRoleHasThreeDistinctTones`（住在
       `ButtonStyleDefaultTests.swift` 里）：它在 macOS 腿上**确实摸到了**这批
       常量的别名（`ButtonRoleStyleRole` 的 secondary / tertiary / warning / danger 三态取自
       `secondaryAccent` / `neutralAccent` / `warning*` / `danger*`），它**安全**，
       但理由与前三类都不同——**它比的是 `Color` 值本身的结构相等，不是解析结果**。
       实测探针：`ButtonRoleStyleRole.secondary` 的 `color == activeColor` 为 **`false`**
       （所以判据有效），而三态 `resolve(in:)` 全是 **`#00000000`**、彼此**相等**。
       ⚠️ **这是今天唯一「安全，但一旦被改写成比解析值就立刻不安全」的机制**：谁把那三条
       `!=` 换成比 `resolve(in:)`，secondary / tertiary / warning / danger 四个 role 会
       **恒红**（三态解析后全是 `#00000000`、彼此相等），而 primary 走 `Color.accentColor`
       ——那不是 catalog 取色，三态解析后**仍互异**，所以照绿。
       ⇒ 同一条判据在同一次运行里一半恒红一半正常，是最难读的失效形态。
       ⚠️ **有意不钉 primary 的具体取值**：`Color.accentColor` 在 macOS 上取的是
       **用户 System Settings 里的强调色**，换机器 / 换设置这个数就变，且明暗两档不同
       （本机注记、仅供复现对照，不是判据：light `#0088FFFF` / dark `#0091FFFF`）。
       照绿的**理由**是「三态解析后仍互异」，不是某个具体色值。

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

### 「退出码 0，却一条测试都没跑」——已实测到的五种形态（`#302`）

⚠️ 五种的共同点：**退出码是成功的**。只看 `$?` 的验证纪律对它们全部免疫，
必须核对「到底跑了几条」。除第 4 条另有标注外，以下每条都在本仓实测过
（Swift 6.3 / Xcode 26.4）：

1. **`swift test --filter` 传的是 `@Suite` 的中文显示名**——要传 Swift **类型名**。
   实测：`swift test --filter "资源 bundle canary"` → `Test run with 0 tests in 0 suites passed`、
   `EXIT=0`；换成类型名 `ResourceBundleCanaryTests` 才真的跑。
2. **macOS 上 `#if os(iOS)` 的 suite 是空 suite**（`DynamicTypeLayoutTests`、
   `SurfaceContrastTests`）。整跑与 `--filter` 到这类类型名都是零条 + `EXIT=0`。
   ⚠️ 这一条与构建系统无关：native 与 swiftbuild 表现一致。
3. **`xcodebuild` 的 `-only-testing:` / `-skip-testing:` 传了不存在的标识符 ⇒ 静默 no-op**。
   实测 `-only-testing:CoreDesignTests/NoSuchSuiteTests` → `** TEST SUCCEEDED **`、`EXIT=0`、
   日志里**连一行 `Test run with …` 都没有**。⇒ `ci.yml` 里那几行 skip 标识符写错了不会报错，
   只会静默失效（这也是那里反复强调「用类型名不用显示名」的原因）。
4. **`-destination` 的 simulator id 过期 ⇒ 零测试、退出码 0** —— **历史报告，本仓复现不出来；
   四种可构造变体实测全是硬红。别把这一条当既定事实传播。**
   ⚠️ 上一版这里写的复现障碍（「要复现需要一台『存在但不合格』的设备，本机凑不出」）
   **是错的**：本机装了 iOS 18.0 / 18.1 / 18.2 / 18.4 四个 runtime、共 44 台设备，
   对 iOS 26+ 的包**全部不合格**，正是所需器材。实测（`rtk proxy xcodebuild test
   -scheme CoreDesign-Package -destination …`，Xcode 26.4）：

   | `-destination` | 情形 | EXIT | `Test run with` 行数 |
   |---|---|---|---|
   | `id=4D99708C-…`（iPhone 16 Pro / iOS 18.4） | 设备**存在但不合格** | **70** | 0 |
   | `platform=iOS Simulator,name=iPhone 16 Pro,OS=18.4` | 同上，按名字寻址 | **70** | 0 |
   | `platform=iOS Simulator,name=iPhone 16 Pro,OS=17.0` | runtime **未安装** | **70** | 0 |
   | `id=00000000-0000-0000-0000-000000000000` | id **压根不存在** | **70** | 0 |

   ⇒ **没有一种给出退出码 0。**四者都伴随 `xcodebuild: error: Unable to find a
   destination/device matching the provided destination specifier` 与一份
   `Ineligible destinations` 清单。
   ⚠️ 那份 `Ineligible` 清单**列的不是那台不合格的 simulator**——实测它列的是本机没装的
   tvOS / visionOS / watchOS **平台 placeholder**；不合格的 iOS 18.x 设备连候选都不进。
   ⇒ 只看到 `Ineligible` 就下「静默零测试」的结论会判错；判据是那一行 `error:` 与退出码。
   ⚠️ 本条保留在列表里，只作**历史登记**（记不清源自何处的一次报告），
   本仓至今**没有任何一次实测支持它**。要么它属于别的 Xcode 版本 / CI 环境，
   要么原报告本身就是误读。谁将来真复现出退出码 0，请连原始日志一起补在这里。
5. **`--build-system swiftbuild` 下，`swift test` 给每个 test target 各打印一行
   `Test run with …` 汇总，而末行常常是 `0 tests`**（排在后面的 target 没有匹配项）。
   ⇒ `tail -1` 或肉眼扫结尾，会把一次**真实的运行**读成「零测试」。
   实测（`main`，三个 test target）：`swift test --build-system swiftbuild --filter <类型名>`
   打印 3 行汇总，其中一行是真实条数、末行是 `0 tests`，`EXIT=0`。
   ⇒ 核对条数**必须扫全文**（`grep -qE 'Test run with [1-9][0-9]* tests?'`），不能取末行。

⚠️ **`#302` 把第 5 条记成了「`--build-system swiftbuild --filter` 静默跑零个测试」——
复现不出来**（本次在 `main` 与 `epic/shipswift-shaders` 各测一遍）：后者上
`swift test --build-system swiftbuild --filter CoreDesignShadersTests` **真跑了 27 条**
（4 行汇总里的一行），只是末行为 `0 tests`；它同时举的 `--filter RenderProofTests` 确实零条，
但那是上面第 2 条（那个文件整包在 `#if os(iOS)` 里），在 native 构建下同样零条，与 swiftbuild 无关。
⇒ 第 5 条是**读日志的方式**问题，不是 `--filter` 语义问题。

⚠️ **编号与 `#302` issue 正文对不上，别按编号互引**：issue 里说的「第 4 种」「第 3 种」
分别对应本节的**第 5 条**与**第 4 条**（本节按「实测发生在哪一层」重排过）。
互相引用时用形态的描述，不要用序号。

⚠️ **那道 fail-closed 的 grep 网只在 `epic/shipswift-shaders` 上**（`ci.yml` 的
「Test (swiftbuild) — CoreDesignShaders」步骤末尾），`main` 的 `ci.yml` 里既没有它、
也没有 shader 那一步。它扫全文而非取末行，**对第 5 条免疫**——实测在
`--filter CoreDesignShadersTests` 上判绿、在 `--filter RenderProofTests` 上判红，方向正确。
⚠️ 但它只兜第 5 条与第 1 条：第 3 条（`-only-testing:` 打错）根本不产生
`Test run with` 行，第 4 条发生在 `xcodebuild` 腿上而那条腿没有同类的网。

### 判据引用与「更正传播」约定（`#287`）

- **注释 / 文档里写「测试类型 + 点 + 判据名」形式的引用，其类型与成员必须在测试目标里
  真的存在**——由 `JudgementReferenceGuard`（`Tests/CoreDesignTests/`）机器守着，扫描面
  是 `Sources/` `Tests/` `docs/`（含 `docs/component-registry.json`）**加仓库根那一层
  `.md`（含本文件）**。它按 SwiftSyntax 解析出的**声明**建符号表（写在字符串字面量里的
  fixture 类型不进表），引用侧只取注释 trivia 与字符串片段；射程与堵不住的路径逐条写在
  该文件头，**不要读成完备保证**。
- ⚠️ **`.claude/**` 是历史归档，有意不在扫描面内**——那里面确实活着若干条悬空引用，
  但归档记的是「写下它的那天的事实」，回改等于篡改归档。⇒ 引一条判据时，
  **别把 `.claude/` 里的旧写法当成现行事实抄过来**，它没有任何机器判据兜底。
- **该判据不区分「活引用」与「历史提及」**：提到一个已被改名 / 删除的符号（包括
  「上一版这里写的是…」这类撤回痕迹）或**跨仓符号**时，把类型名与成员名**拆开写**
  （各自加反引号、中间不用点连），并写明它现在叫什么。
- ⚠️ **更正 / 撤回一处声称时，必须 grep 该判据名或该理由的关键词，确认三处落点同步**：
  源码注释、`docs/components/*.md`、`docs/component-registry.json` 的 `notes`。
  前两处离改动近、会被顺手改到，**登记表在另一个文件、另一种格式，每次都掉队**
  （`#286` 的 `.move`、`#291` 的 `blinds` 都是这么漏的）。
- ⚠️ 登记表里有**两族同形的 `notes`，两个守卫各管一族、都只看长度、都不校验真伪**：
  `entryPoints[].notes` 由 `ExtensionEntryPointGuard` 校验（长度下限 + 占位短语黑名单），
  `components[].notes`（更长、声称更密集的那一族）由 `ComponentRegistryGuard` 校验
  （只有长度下限）。⇒ 「引用的判据真实存在、却被声称证明了它证明不了的事」这一族
  **没有机器判据**，两族都是**人工评审项**——别把人工复核的射程说小了。

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
