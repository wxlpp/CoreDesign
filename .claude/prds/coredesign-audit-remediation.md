---
name: coredesign-audit-remediation
description: 修复四路审计发现的 83 项缺陷——遮蔽 SwiftUI 的真 bug、公开 API 断裂、重复色阶与 typography 层不缩放、以及缺失的质量保障基建
status: backlog
created: 2026-07-18T11:01:48Z
---

# PRD: coredesign-audit-remediation

## Executive Summary

CoreDesign 当前构建是绿的——`swift build`、`swift test`（96 tests / 32 suites）、`swift build --traits Blossom` 全部零 warning 通过。但四路并行审计（token 层 / 公开 API / 重复代码 / 构建测试基建）在代码中逐条核实出 **83 项**缺陷（完整清单见 `.claude/epics/coredesign-audit-remediation/audit-checklist.md`），其中两类是真问题：

1. **`Color.primary` 遮蔽 SwiftUI 同名成员**，导致 `CheckBox` 实际渲染成品牌色而非系统 label 色，且因该 extension 未标 `public`，同一行代码在库内外含义不同。
2. **一批公开 API 因漏写 `public` 而下游不可用**——已用下游消费包实测出编译错误，其中包括文档明确指引业务侧使用的 `CheckBoxToggleStyle`。

绿色构建之所以没能拦住这些，是因为**质量保障基建实际不存在**：`.github/workflows/` 是空目录；96 个测试中约 3/4 是恒真断言（`#expect(String(describing:).isEmpty == false)` 之类），编译通过即必过；快照测试只生成不比对。"96 tests passed" 这个信号是失真的。

本 epic 一次性修完全部四簇缺陷，并补上 CI 与真断言测试，使后续改动有自动化回归防线。用户已确认：**breaking change 直接改，不保留 deprecated 兼容层**。

## Problem Statement

**为什么现在要做？**

1. **存在会误导使用者的真 bug。** `Colors/FunctionalColor.swift:11-12` 在 `Color` 上定义了 `static let primary/secondary/tertiary`，与 SwiftUI 内建同名。模块内本地定义静默胜出（实测确认，无歧义报错），已确认**两处产品代码受害**：
   - `Components/CheckBox/CheckBox.swift:31` 的 `.foregroundStyle(Color.primary)` 实际解析到 `.brand5`，而该文件 21-23 行的注释还写着"light/dark 自动适配系统外观"。文档与行为直接矛盾。
   - `Components/StatusRow/StatusRow.swift:80` 的 `case .skipped: return .secondary` 处于返回 `Color` 的上下文，解析到 `.lightBlue5`（Blossom 下 `.violet5`）——skipped 状态图标渲染成浅蓝/紫罗兰而非作者意图的中性灰。

   这类 bug 的隐蔽性在于**删除遮蔽符号时也不会报错**，只会静默改变解析目标，因此修复必须逐处显式改写而非依赖编译器。

2. **公开 API 表面有断裂，且已实测。** 在 scratchpad 建下游消费包逐条 probe，确认以下符号下游不可达：
   - `CheckBox.swift:24` `CheckBoxToggleStyle` → `error: cannot find 'CheckBoxToggleStyle' in scope`（而 `:52` 文档写着"业务侧通常直接使用"）
   - `BorderlessButtonStyle.swift:40,52` → `error: 'BorderlessButtonStyle' initializer is inaccessible due to 'internal' protection level`
   - `ButtonRoleStyleRole.swift:18,33,48` 的 `color`/`activeColor`/`disabledColor` → `inaccessible`（CLAUDE.md 称该枚举是三色"唯一来源"）

   （`Utils/View+SizeReader.swift:44,48` 的 `getSize` 同样不可达，但它的处置是**删除**而非补 `public`——见 FR-5。）

   更隐蔽的是 `BorderlessButtonStyle` 与 SwiftUI 自带类型同名：下游写 `BorderlessButtonStyle()` **能编译通过**，但静默解析到 SwiftUI 的类型。`MenuButton` 与 macOS 上 deprecated 的 SwiftUI `MenuButton` 同样冲突，实测报错信息具有误导性。

3. **Typography token 层全部不缩放。** `Tokens/CoreTypography.swift:53-183` 全部 10 个字体 token 用 `.system(size:weight:)`，`relativeTo:` 出现 0 次。全库仅 `MenuButton.swift:67`（`@ScaledMetric`）与 `SegmentedControl.swift:245-249`（`UIFontMetrics`）两处组件级适配，另有 7 处绕过 token 直接用系统 TextStyle 的文字（`.caption`/`.caption2`/`.subheadline`）恰好因此**还能**缩放——即 token 层越是被正确使用，Dynamic Type 越失效。配合 `Sidebar.swift:121,183,238,287` 四处写死 `frame(height:)`，大字号下侧栏行会裁切。这对一个对外分发的设计系统是可访问性硬伤。

4. **同一套色阶声明了两遍，Blossom 分流点因此翻倍。** `FunctionalColor.swift:12-32` 与 `InteractionColors.swift:4-25` 逐值相同（`primary/Active/Disable/Hover` 与 `accent/Pressed/Disabled/Hover` 都是 `brand5/7/2/6`），且**各带一份重复的 `#if Blossom` violet 分流**。这直接违反 CLAUDE.md「分流点压到最低」的约定——改一次 Blossom 配色要同步改两个文件。而 `FunctionalColor` 的 primary/secondary/tertiary 三组除了那个 bug 点外引用数为 0。

5. **质量保障基建缺失，绿色信号失真。**
   - `.github/workflows/` 是空目录，CLAUDE.md 要求"两种构建模式都需保持绿"却无任何自动化守护
   - `ProgressIndicatorTests` 全文只有 `_ = ProgressIndicator()`；`FloatingGlassModifierTests` 用恒真的 `#expect(String(describing: type(of: view)).isEmpty == false)`；`StatusColorsTests` 5 个 test 共 20 行、没有一个 `#expect`
   - `App/Tests/SnapshotTests.swift` 是空 subclass，`scripts/run-snapshots.sh` 每次 `rm -rf` 全量重生成，committed 的 25 张 PNG 是文档插图不是 baseline
   - `swift test --traits Blossom` 与默认跑的是**同样 96 个测试、同样断言**——trait 是编译期 API 契约，其核心行为零测试保障

**不做会怎样？** 这个库刚引入编译期 trait 分流，正处在最需要回归防线的阶段。继续下去：Blossom 配色改动会因两处分流点而漂移；下游每次尝试用文档指引的 API 都会撞上编译错误；`Color.primary` 的遮蔽会随着新组件复制粘贴而扩散；而 CI 缺失意味着这些都要等到人工发现。

## User Stories

### US-1: 下游消费者

**作为** 依赖 CoreDesign 的 app 开发者
**我想要** 文档里写的 API 真的能用，且名字不与 SwiftUI 内建冲突
**以便** 按文档写代码时不会撞上编译错误或静默拿到错误的类型

**验收标准：**
- 下游消费包能成功构造 `CheckBoxToggleStyle`、`CoreBorderlessButtonStyle`，读取 `ButtonRoleStyleRole` 的三个调色板属性
- `CoreBorderlessButtonStyle` 与 SwiftUI 无同名冲突；下游写该类型名时不存在"解析到 SwiftUI 版本"的可能
- 第 4 层功能色（`success`/`info`/`warning`/`danger` 及变体）对下游可见
- 存在一个自动化验证：新增 public API 断裂能被 CI 捕获（下游消费包 probe 纳入 CI，或等效手段）

### US-2: 使用大字号的终端用户

**作为** 开启了 Dynamic Type 大字号的用户
**我想要** 用 CoreDesign 构建的界面文字随之缩放且不被裁切
**以便** 我能正常阅读界面内容

**验收标准：**
- 全部 10 个 typography token 通过 `.coreFont(_:)` 支持 Dynamic Type 缩放，fontSize 与 lineSpacing 同步缩放
- Primer 精确基准字号保留，`docs/PRIMER_VERSION.md` 的对应关系继续成立
- `Sidebar` 四种 row 在 `xxxLarge` 字号下不裁切内容。**验证机制（已实测确认，见 Constraints）**：用 `ImageRenderer` 在注入的 `dynamicTypeSize` 下渲染并断言高度单调增长且 ≥ 内容固有高度，测试用 `#if os(iOS)` 包住、经 `xcodebuild` + iOS Simulator 运行。断言写法：**相邻档位用 `>=`**（实测 `small` 与 `medium` 会相等，严格 `>` 会假失败），**跨档（`large` vs `xxxLarge`）才用 `>`**。布局断言**不得**依赖颜色（`swift test` 下 asset 颜色解析为 `(0,0,0,0)`）
- 组件中绕过 token 直接使用系统字号的 7 处（`AvatarGroup.swift:59`、`StatusRow.swift:46`、`StateLabel.swift:50`、`CommentCard.swift:56`、`RefPill.swift:34,37,40,42,45`、`BottomInputBar.swift:302,376`）全部迁移到 token

### US-3: 主题使用者（Blossom）

**作为** 启用 Blossom trait 的调用方
**我想要** 主题下的强调色表现一致，不出现"侧栏选中粉、搜索框 focus 蓝"
**以便** 界面视觉是统一的

**验收标准：**
- `borderFocus` 在 Blossom 下跟随品牌色（珊瑚粉）。**默认主题下它同时会从 Primer 蓝 `#0969DA` 变为品牌蓝 `#0077FA`**——这是别名继承方案的必然代价，已列入 NFR 视觉例外
- `statusSuccess`/`statusAttention`/`statusDanger` 在两个主题下保持标准语义色（绿/橙/红），不分流
- `statusAccent*` **保留**（原判整组删除，已于 #93 执行期改判）——删它与 FR-1 自身的 legacy 迁移冲突：新体系只有 `accent` 一个蓝色家族，而它正是 Primer 的 info 语义。改为修正**五组** `emphasis` 的 light 值（原判「accent 单组笔误」经横向比对为系统性错误）
- **同一语义的重复分流点归零**：violet secondary 分流从 2 份（`FunctionalColor` + `InteractionColors`）合并为 1 份
- **全库 `#if Blossom` 总数 9 → 8**（净减 1）。`borderFocus` 跟随品牌通过**指向 accent 家族别名**实现，不新增 `#if`——与 `borderSelected` 的既有处理一致；`statusAccent*` 保留但本就不分流（`StatusColors` 全组无 trait 分支），故不影响计数
- 存在测试断言 trait 分流后 token 指向不同且值正确的颜色——默认 `accent` → `brand-5` → light `#0077FA`，Blossom → `blossom-brand-5` → light `#FF6F8E`（断言取 light 值；dark 值分别为 `#3295FB` / `#D15F82`）
- `BorderColors.swift:50` 与代码矛盾的注释被修正

### US-4: 设计系统维护者（=本人）

**作为** CoreDesign 维护者
**我想要** CI 自动守护两种构建模式，且测试通过数是可信信号
**以便** 我改动 token 或组件时能立刻知道是否破坏了什么

**验收标准：**
- CI 覆盖 NFR 定义的**五条**命令（四条 SwiftPM + 一条 `xcodebuild` iOS Simulator 布局断言）
- 恒真断言测试被删除或改写为真断言；保留的行为测试（`ToastHostTests`、`AsyncButtonTests`、`ProgressBarTests`、`ListRowTests` 的泛型 slot 断言）继续通过
- `KeyboardHandlingTests` 随 `KeyboardHandling.swift` 一并删除（见 FR-5：其被测对象 `KeyboardHeightPublisherFactory` 无生产调用点，保留即构成"只为测试而活"的死代码，正是本 epic 要清理的东西）
- 存在布局断言层覆盖 Dynamic Type 改造的裁切风险
- 每个被删除的测试在审计清单中标记处置理由，使"恒真断言归零"可核对而非人工判断

### US-5: 使用辅助技术的终端用户

**作为** 使用 VoiceOver 的用户
**我想要** 图标按钮有可读的标签、选中态被正确播报
**以便** 我能操作用 CoreDesign 构建的界面

**验收标准：**
- `BottomInputBar` 的 send / stop / suggestion 三个 icon-only 按钮有 `accessibilityLabel`
- `UnderlinedTabItem` 通过 `.accessibilityAddTraits(.isSelected)` 暴露选中态
- `Form` 的 `ChevronRightIcon`、`LabelIcon` 标记为 `accessibilityHidden(true)`；`DangerIcon` 有语义 label
- UI 字符串统一为英文并走 String Catalog，硬编码中文（`Toast.swift:441`、`MenuButton.swift:139,169`、`BookCover.swift:23`）清零

## Functional Requirements

### FR-1 色彩层重组

- 第 4 层职责重定义为**状态功能别名**：`success`/`info`/`warning`/`danger` 及其现有变体**按现状保留**（注意 `success`/`info` 本就无 Active/Hover/Disable 变体，不需补齐），整层补 `public`
- 删除 `FunctionalColor` 的 `primary`/`secondary`/`tertiary` 三组；交互色统一走第 3 层 `InteractionColors`
- `CheckBox.swift:31` 改用 `Color.contentPrimary`，修正 21-23 行注释
- `danger` 基准 `red4` → `red5`，与同组的 5 档基准对齐
- `borderSelected` → `.accent`；`selectionBackgroundEmphasis` 走命名别名，消除层级违规
- `borderFocus` → `.accent`。**通过别名继承实现 Blossom 跟随，不新增 `#if Blossom`**。副作用：默认主题下 focus ring 从 `#0969DA` 变为 `#0077FA`，影响 `FocusRingModifier.swift:106`（默认参数）与 `SearchField.swift:136` 两个真实渲染点，已列入 NFR 例外
- **`statusAccent*` 保留**（原 AD-2 定为整组删除，已于 #93 执行期改判）。删除它与本 FR 自身的 legacy 迁移要求**互斥**：新体系只有 `accent` 一个蓝色家族，而它正是 Primer 的 info 语义，`Banner`/`Toast`/`Badge` 的 legacy `info*` 只能迁到它。原判据 (a)「库内零渲染消费点」恰恰因为 info 当时走 legacy——迁移一做即失效。原判据 (d) 的「accent 单组笔误」经横向比对亦不成立：五组 `*-emphasis` 的 light 值**逐组等于同组 `*-muted`**，是系统性错误，改为一并修正
- `StatusColors` 新体系补 `*Border` 档，`Toast`/`Badge`/`Banner`/**`Form`** 全量迁移（`Form.swift:101` 使用 legacy `Color.dangerForeground`，`:92,99` 文档注释同样引用，漏改会直接编译失败），legacy 组（`StatusColors.swift:63-77`）删除
- 同步更新 CLAUDE.md 分层描述
- **`#2` 的仓内触及清单**（删除 token 会波及但不一定报错的地方，须逐一处理）：
  - `Tests/CoreDesignTests/StatusColorsTests.swift` —— `:10-13` 引用四个 `statusAccent*`、`:48-62` 引用 12 个 legacy token，两组都被本 FR 删除，该测试文件**整体编译失败**。须随 `#2` 一并改写（它本身也在 #7 的恒真断言清单里，见下方依赖说明）
  - `App/Sources/Previews.swift:233` —— `Circle().fill(Color.statusAccentEmphasis)`，须改用其它 token 或删除该色块
  - `Sources/CoreDesign/Components/StatusRow/StatusRow.swift:80` —— **最危险的一处，在产品代码里**。`case .skipped: return .secondary` 处于返回 `Color` 的上下文，今天解析到 `FunctionalColor.secondary`（默认 `lightBlue5`、Blossom 下 `violet5`），即 skipped 行图标当前渲染成浅蓝/紫罗兰而非作者意图的系统灰。删除后此行**不报错**，静默改解析到 SwiftUI 内建灰——恰好"治好"这个 bug，但属未声明的产品视觉变化，须在 `#2` 中显式改写并记入 NFR 视觉例外
  - `Sources/CoreDesign/Colors/CoreGradient+Preview.swift:17` —— `RoundedRectangle(...).fill(Color.secondary)`，同型静默重解析。Blossom 视觉冒烟 Preview 的色块会从 violet 悄悄变灰。须显式改为期望的语义 token
  - 修正五组 `status-{accent,success,attention,danger,done}-emphasis.colorset` 的 light 值（原为同组 muted 值，应为各组 `fg` 同色）；四个 `status-accent-*.colorset` **保留**
  - `docs/components/` 下引用被删 token 的示例：`timeline-item.md:24`（`statusAccentEmphasis`）、`form-icons.md:27,67`、`banner.md:34`、`toast.md:65`（legacy token）。`docs/superpowers/plans/` 下的历史计划文档是归档，不改
  - **源码内注释**同样引用被删 legacy token，漏改只是文档漂移不报错，须逐一处理：`Toast.swift:18`、`Banner.swift:26,68,167,201`、`Badge.swift:55`、`Form.swift:92,99`

### FR-2 公开 API 修复与改名

- 补 `public`：`CheckBoxToggleStyle`、`ButtonRoleStyleRole` 三个调色板属性、`FunctionalColor` extension（`View.getSize` **不在此列**——它随 FR-5 删除）
- `BorderlessButtonStyle` → `CoreBorderlessButtonStyle`，补 `public init(role:)` 与 `public let role`
- `MenuButton` → `CoreMenuButton`，避开 macOS 上 SwiftUI 同名的 deprecated 类型
- `CheckBox` 演示视图内联进 `#Preview`，只保留 `CheckBoxToggleStyle` 作为公开面
- 仓库内 `App/` 预览宿主同步适配改名

### FR-3 Dynamic Type 改造

- `CoreTypography` 从 `Font` 常量升级为 `CoreTypography.Token` 枚举 + `.coreFont(_:)` modifier
- 内部用 `ScaledMetric(wrappedValue:relativeTo:)` 在 init 中按 token 角色指定缩放基准（display → `.largeTitle`，正文 → `.body`，caption → `.caption`）
- fontSize 与 lineSpacing 同步缩放；font/lineSpacing/tracking「三件套」收进单一调用点
- **波及面已量化**：`CoreTypography.` 在 24 个文件、94 处被消费，FR-3 事实上要触及几乎每个组件。这是本 epic 改动面最大的单项
- **`CoreControlMetrics.font(for:)` 的处置**（关键）：该 API 返回 `Font` 且被全部按钮样式消费（`CoreControlMetrics.swift:174-179`），而 `@ScaledMetric` 需要 View 上下文，modifier 形态服务不了它。改为 `CoreControlMetrics.fontToken(for:) -> CoreTypography.Token`，调用方写 `.coreFont(CoreControlMetrics.fontToken(for: controlSize))`。**不这样做则按钮文字仍不缩放，SC-3 名不副实**
- **`RefPill` 的等宽需求**：`RefPill.swift:37,40,45` 用 `.caption.monospaced()`，而 `CoreTypography` 中 `monospaced` 出现 0 次。需新增 mono 变体 token，否则迁移会静默丢失等宽特性（ref / branch 名的视觉回归）。此项属"为保持现有表现所必需"，不受 Out of Scope「不做加法」约束
- **硬顺序**：`.coreFont()` 必须**先**落地，7 处系统字号迁移**后**进行。这 7 处当前是 TextStyle，今天**会**随 Dynamic Type 缩放；顺序颠倒会让它们经历"先失去缩放再恢复"的中间态
- `Sidebar` 四处 `frame(height:)` → `minHeight`（审计项 B2b）。**归属 Issue #5 而非 #4**——它与 FR-4 的 Sidebar row 骨架收敛改同一批行，由 #5 在收敛出新骨架时一并带上，彻底消除跨 Issue 文件冲突。FR-3 只声明需求，不承担实施
- 组件中 7 处系统字号迁移到 token（清单见 audit-checklist.md D3）
- **范围边界**：`CoreControlMetrics.iconSize(for:)` 驱动的图标字号（如 `CheckBox.swift:30,34`）**不纳入** Dynamic Type 改造，保持固定尺寸。US-2 承诺的是文字缩放；执行时不要自行扩大到图标

### FR-4 结构性收敛

- `ButtonRoleStyleRole.resolvedColor(isEnabled:isPressed:)` 吸收三份重复取色逻辑
- `SolidButtonBackgroundModifier` 与 `LightButtonBackgroundModifier` 合并
- font/padding/contentShape 四行提炼为共享 modifier
- `CircularGlassButtonStyle` 接入 `@Environment(\.controlSize)`
- `Sidebar` 四个 row 收敛为共享骨架 + 薄封装
- `SegmentedControl` 的 `glass: Bool` 升级为 `SegmentedControlStyle` 协议 + `@Entry` + `.segmentedControlStyle(_:)`
- `ToastLevel` + `MessageLevel` 合并为单一 `StatusLevel`；各组件的平行 switch 收敛为返回 spec 结构体的单一 switch
- `BottomInputBarModifier.body`（78 行，全库唯一超 50 行的 body）拆分子视图；两个同构 `onChange` 合并为单一 `syncSuggestionsVisibility(shouldShow:)`；重复的 chip 样式收敛（审计项 B8h）
- 四个 ButtonStyle 保持现有 `ButtonStyle` + 静态扩展形态，不再协议化

### FR-5 死代码清理与现代化

- 删除 `BottomInputBar.swift:87,138` 的 `textFieldSize` 及 `Utils/View+SizeReader.swift` 整文件（`getSize` 全库唯一消费点即 `BottomInputBar.swift:138`，删后整文件成死代码）。**同步从 CLAUDE.md 删去 `.getSize` 的通用辅助描述**
- 删除 `Utils/KeyboardHandling.swift` **整文件**（含 `KeyboardReadable` 及默认实现、`dismissKeyboardOnTap`、`resignFirstResponder`、`anyWriterFirstResponderNotification`/`becomeFirstResponder`）**及其测试 `KeyboardHandlingTests.swift`**。保留 `KeyboardHeightPublisherFactory` 会构成"只为测试而活"的死代码——它无生产调用点，仅被该测试消费
- `CoreGradient`：`static var` → `static let`，文件移入 `Tokens/`，并至少在一处组件真实消费以验证抽象成立
- `TimelineItem` 旧式 `EnvironmentKey` → `@Entry`（同步改 `TimelineItemTests.swift:30`）
- `BookCover` 图片解码移出 body
- `CommentCard` 手写三件套 → `.surface(.card)`
- 删除 `bordered(color:)` 死重载；`BorderModifier` 改 `strokeBorder` 并支持任意 shape
- 删除 `SegmentedControl.swift:205,301` 恒真的 `@available(iOS 26.0, *)`
- 删除已废弃的 `EmptyState.swift` 整文件及其自证测试 `EmptyStateDeprecationTests.swift`；同步移除 `docs/README.md:41` 的组件索引行与 `docs/components/empty-state.md` 迁移文档
- 删除死 token `CoreRadius.full`

### FR-6 测试与 CI 基建

- GitHub Actions workflow 覆盖 NFR 定义的五条命令组合（含 iOS Simulator 布局断言，须确认 runner 有可用的 iOS 26 Simulator）
- 删除恒真断言测试；保留并扩充真行为测试
- 新增 Blossom 分流断言测试：`String(describing: Color)` 取 asset 名 → 解析 `.colorset/Contents.json` 的 sRGB 分量 → 按 `#if Blossom` 断言期望值
- 新增布局断言层覆盖 Dynamic Type 裁切风险
- 新增下游消费包 probe 纳入 CI，使 public API 断裂能被自动捕获（对应 US-1 验收标准）
- `Package.swift` 加 `.defaultIsolation(MainActor.self)`；`.iOS("26.0")` 改枚举形式
- `App/project.yml` 补 `traits: ["Blossom"]`；修正 `xcodeVersion` 与 iOS 26 部署目标的矛盾
- 补 LICENSE；修正 README 组件数量；`.gitignore` 去重（`.superpowers/` 重复两次）
- 消除 `.claude/`、`.agents/`、`AGENTS.md` 的悬空状态：`.claude/prds/` 与 `.claude/epics/` **纳入版本控制**（本 epic 的 artifact 存放处），`.agents/` 与 `.claude/omsp/` 加入 `.gitignore`，`AGENTS.md` 纳入版本控制
- **维护 `audit-checklist.md`**：每个 Issue 完成时更新其覆盖条目的状态，作为 SC-7 的判定依据

### FR-7 一致性清理

- 可访问性补全（见 US-5 验收标准）
- UI 字符串统一英文 + String Catalog
- `public let` 存储属性降为 private（`ProgressBar`、`StatusRow`、`StateLabel`、`CommentCard`、`EventRow`、`TimelineItem`、`AvatarGroup`）
- 语义枚举统一补 `Sendable, Equatable`（`MessageLevel`、`ButtonRoleStyleRole`、`MenuButtonStyle`、`SurfaceKind`）
- 初始化形态对齐：`StateLabel` 首参加标签；只收 `String` 的组件补 `@ViewBuilder` designated init
- `Banner.swift` 移入 `Components/Banner/`
- `FillColors` 平台分支改 `#if/#else` 形式
- 硬编码数值改引用 token（`MenuButton.swift:146` `pressedScale`、`:136` `CoreSpacing.sm`、`TimelineItem.swift:74` `CoreSpacing.none` 等）
- 文档漂移修正（`StateLabel.swift:28`、CLAUDE.md 的 `.focusedExternally` 描述）
- `Sidebar`、两个 public modifier 补 `#Preview`

## Non-Functional Requirements

- **构建绿**：以下**五条**命令零 warning、零失败——
  1. `swift build`
  2. `swift test`
  3. `swift build --traits Blossom`
  4. `swift test --traits Blossom`
  5. `xcodebuild test -scheme CoreDesign -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`（布局断言层专用，见下）

  第 5 条是 FR-3 引入的新增项：布局断言**只能**在 iOS 上跑（见 Constraints 的 Dynamic Type 实测结论），故用 `#if os(iOS)` 包住，前四条命令下自动跳过、不影响现有双 trait 流程
- **平台**：iOS 26+ / macOS 26+ 双端编译通过，不为 iOS 26 API 添加可用性回退
- **并发**：Swift 6 语言模式 + `defaultIsolation(MainActor.self)`，无数据竞争诊断
- **视觉零回归**：除以下明确变更项外，默认主题观感不变——
  1. `danger` 基准色档 `red4` → `red5`
  2. Blossom 下 `borderFocus` 转品牌色
  3. **默认主题下 `borderFocus` 从 Primer 蓝 `#0969DA`/`#1F6FEB` 统一到品牌 accent `#0077FA`/`#3295FB`**——别名继承方案的必然代价，影响 `SearchField` focus ring 与 `.focusRing()` 默认参数
  4. Dynamic Type 缩放生效
  5. **7 处系统字号 → token 的字号归一**（#95 执行期实测的具体变化）：
     - `.subheadline`（15pt）→ `.bodyLarge`（16pt）：`BottomInputBar` 的 chip，+1pt
     - `.caption2`（≈11pt）→ `.caption`（12pt）：`AvatarGroup` / `StateLabel` / `CommentCard` / `RefPill` 五处，+1pt（`CoreTypography` 无 11pt 档，`caption` 12 是最近的缩放档）
     - `.caption`（12pt）→ `.caption`（12pt）：`StatusRow`，精确对应无变化
     - `.caption.monospaced()` → `.captionMono`（12pt 等宽）：`RefPill` ×3 + `ListRow`，等宽保留
     - **`captionSmall` 明确不缩放**：AC 原写「10 个 token 全缩放」，`captionSmall`（9pt 紧凑 chrome）有既有设计约束「故意不缩放」（放大会撑爆 tab 角标/status bar），经用户确认改为「9 缩放 + captionSmall 固定」
  6. ~~`statusAccent*` 整组移除~~ —— **已在 #93 执行时改判为保留**。删除它与 FR-1 自身的 legacy 迁移要求冲突：新体系只有 `accent` 一个蓝色家族，而它正是 Primer 的 info 语义，`Banner`/`Toast`/`Badge` 的 legacy `info*` 只能迁到它。原判据「库内零渲染消费点」在迁移完成后不再成立
  7. **五组 `status-*-emphasis` 的 light 值修正**（`accent`/`success`/`attention`/`danger`/`done`）。原 D19 记为「accent 单组 colorset 笔误」，横向比对发现五组全部把 emphasis 填成了同组 muted 的值；Primer 语义里 emphasis 是饱和实色。修正后该档才真正可用
  8. **legacy → 新体系迁移的 light 值变化（8 处，含一处色相改变）**。迁移不是等值替换——两套 scale 取自不同来源（legacy 走本仓库原子色 ramp，新体系走 Primer colorset）：

     | 语义 | 档 | legacy | 新体系 |
     |---|---|---|---|
     | info | fg / bg | `#004FB3` / `#CBE7FE` | `#0969DA` / `#DDF4FF` |
     | success | fg / bg | `#25772F` / `#D0F0D1` | `#1F883D` / `#AFF5B5` |
     | **warning** | **fg** | **`#A84A00`（橙）** | **`#9A6700`（橄榄黄）← 色相改变** |
     | warning | bg | `#FEEECC` | `#F8E3A1` |
     | danger | fg / bg | `#B2140C` / `#FEDDD2` | `#CF222E` / `#FFC1BA` |

     影响 `Banner` / `Toast` / `Badge` 三个组件。warning 的橙→黄最明显——它从暖橙转为 Primer 的 attention 黄。这是「统一到 Primer 体系」的必然结果，不是回归。

     **border 档不变**：新增的 `status-*-border` 沿用 legacy 的原子色 3 档原值（`#65B2FC`/`#7DD182`/`#FDC165`/`#FB9078`），故 `Badge` / `Banner` 的边框 light 观感保持不变。

  9. **legacy → 新体系迁移的 dark 观感变化**：legacy 用不透明原子色（如 `blue-1` dark `#0A4694`），新体系 dark 是 alpha 叠加（如 `#1F6FEB @13.3%`）。迁移后 dark 模式下状态背景从实色变为半透明叠加。这是 Primer 的标准做法（能随底层 surface 自适应），比 legacy 写死实色更正确
  10. **`StatusRow` 的 skipped 图标从浅蓝（Blossom 下紫罗兰）变为系统灰**——修复 A1 遮蔽的直接结果，即把该图标恢复成作者原本意图的中性色
- **性能**：消除 body 内的重复图片解码与每帧 `AnyShapeStyle` 装箱
- **代码风格**：遵循仓库既有约定（显式 `self.`、中英双语注释、`#Preview` 与组件同文件）

## Success Criteria

1. 下游消费包能成功编译使用全部文档所述 public API（0 个 `inaccessible` / `cannot find in scope` 错误）——由纳入 CI 的 probe 包自动判定
2. `grep -rn "#if Blossom" Sources/ | wc -l` 从 **9 降至 8**；且 violet secondary 分流从 2 份合为 1 份（`FunctionalColor` 那份消失）
3. Dynamic Type 覆盖率：10 个 typography token 全部通过 `.coreFont()` 支持缩放（当前 0），且 `CoreControlMetrics` 不再暴露任何返回 `Font` 的 API
4. CI workflow 数量：0 → ≥1，覆盖 5 条命令组合（若 runner 受限，见 Constraints 的降级路径，此时判定标准改为"本地五条命令 + pre-push 闸门就位"）
5. 恒真断言测试归零。判定依据是 **#7 执行时产出的逐文件处置清单**（每个测试文件标注「保留 / 删除 / 改写」及理由，作为 `audit-checklist.md` 的 C2 附录落盘）——PRD 阶段无法逐一枚举 32 个 suite，故把枚举义务下推到 #7 而非留作人工判断
6. 存在至少 1 个测试能区分默认与 Blossom 主题的实际颜色值（light 值：`#0077FA` vs `#FF6F8E`）
7. `.claude/epics/coredesign-audit-remediation/audit-checklist.md` 中 **83 项**全部标记为「已修复」或「记录不修 + 理由」（当前规划：78 修 / 5 不修）
8. `Sidebar` row 代码量从约 120 行降至约 50 行

## Constraints & Assumptions

**约束：**
- **CI runner 需 Xcode 26**（iOS/macOS 26 部署目标要求）。GitHub Actions hosted runner 的 Xcode 版本可用性**未经验证**，是本 epic 的首要技术风险。**降级决策树**（#1 按序尝试，任一成功即停）：
  1. `macos-26` hosted image（若已 GA）
  2. `macos-15` + `xcodes` / `xcode-select` 装载 Xcode 26
  3. self-hosted runner
  4. 全部不可行 → 降级为**本地 pre-push 脚本**跑五条命令作为临时闸门，CI 留待 runner 就绪后回补

  runner 还须提供**可用的 iOS 26 Simulator**（NFR 第 5 条命令依赖），决策树每一级都要同时验证这一点。

  **CI 不可用不阻塞其余 Issue**：NFR 对"构建绿"的定义本就是五条本地命令，其余 Issue 以此为验证依据
- **macOS 无 Dynamic Type，布局断言只能跑在 iOS Simulator 上**（已实测）。在 macOS `swift test` 宿主中：`ImageRenderer` 本身工作正常（能渲染、出位图、测量布局，且对显式 point size 敏感），`.environment(\.dynamicTypeSize,)` 的**环境值传播也正常**（视图内能读到注入值），但 `@ScaledMetric(wrappedValue: 16, relativeTo: .body)` 在全部 12 个档位下**恒返回 16.0**——macOS 的字体解析层根本不消费 Dynamic Type（`NSFont.preferredFont(.body).pointSize` 恒为 13.0）。同一视图在 iOS 26 Simulator 上则完全正常：`large=16` → `xxxLarge=21` → `accessibility5=45`。

  **后果**：布局断言测试必须 `#if os(iOS)` 包住并经 `xcodebuild` + Simulator 运行（NFR 第 5 条命令）。这也**放大了 Xcode 26 runner 风险**——CI 不仅需要 Xcode 26，还需要可用的 iOS 26 Simulator，`#1` 的降级决策树须覆盖此项。

  附带结论：`.coreFont()` 在 macOS 上退化为固定基准字号，属正确行为（该平台本就无 Dynamic Type），不算缺陷。
- `swift test` 下 asset 颜色**无法解析**——已实测确认 SwiftPM 不调用 `actool`，产出 bundle 只有原始 `Resources.xcassets` 目录，既无 `Assets.car` 也无 `Info.plist`，`Color.accent.resolve()` 返回 `(0,0,0,0)`。因此 Blossom 颜色断言必须走 asset 名 → `Contents.json` 解析路径，不能用 `Color.resolve`
- 新增 colorset 后必须 `swift package clean` 再构建，否则资源静默缺失
- `.build/` 存有跨路径 ModuleCache 时构建会失败，需先 clean

**假设：**
- **CoreDesign 无外部下游消费者**（用户明确确认"直接改，不管下游"）。**支持证据**：`gh repo view` 显示仓库虽为 PUBLIC，但 **0 forks / 0 stars**，未发现反证。**风险留存**：`README.md` 的 Quick Start 指引消费者 `branch: "main"` 且无版本钉扎，任何匿名 clone 者会在下次 pull 时直接编译失败。**已更新**：用户确认仓库为自用后，`v0.1.0` 已打在 `43b71e2`（修复前基线，四种模式验证绿），作为可回退点。README 改为 pin tag 归 `#11`
- 仓库内 `App/` 预览宿主是唯一需同步适配的消费者
- Primer 对齐仍是 typography 的设计目标，因此保留精确字号而非改用系统 TextStyle

## Out of Scope

- **像素级视觉回归测试**——用户明确选择"只生成 + agent 审美"，快照 PNG 继续作为文档插图，不升级为 baseline，不做像素比对
- **upcoming features**（`ExistentialAny`、`MemberImportVisibility`、`InternalImportsByDefault`）——会引入大片与本次修复无关的机械改动，搅浑 diff，另开一轮
- **完整 semver 发布流程**——本轮只打了 `v0.1.0` 这一个修复前基线 tag 作为回退点，不建立持续的版本发布契约
- **deprecated 兼容层**——用户明确选择直接改，不保留 `@available(*, deprecated, renamed:)` 过渡
- **`StarShape` 的去留**——public 且零引用，但可能是给下游预留，本轮仅记录不处理
- **新增组件或新功能**——本 epic 纯修复与收敛。例外：为保持现有表现所必需的 token（`StatusColors` 的 `*Border` 档、`CoreTypography` 的 mono 变体）属修复范畴，不受此限
- **`swift-snapshot-testing` 等外部测试依赖引入**
- **lint / format 工具链**（SwiftLint、swift-format、.editorconfig）——CLAUDE.md 的「显式 `self.`」等风格约定继续靠人工与文档执行；引入新工具链会产生大批与本次修复无关的格式化 diff，另开一轮（对应审计项 C8）

## Dependencies

**Issue 枚举与 FR 映射：**

共 **11 个 Issue**，承载 83 个审计项（78 修 / 5 不修）。各 Issue 承载数：#1=5、#2=12、#3=6、#4=2、#5=8、#6=18、#7=4、#8=3、#9=1、#10=9、#11=10。

| Issue | 范围 | 对应 FR | 审计项 | 数 |
|---|---|---|---|---|
| #1 | 构建配置前置：CI + Xcode 26 可行性、`defaultIsolation`、预览宿主 trait | FR-6（CI/Package 部分） | C1、C7a、C7b、C9a、C9b | 5 |
| #2 | 色彩层重组 | FR-1 | A1、A2d、B1a–c、B6a–c、D11、D13、D14、D19 | 12 |
| #3 | 公开 API 修复与改名 | FR-2 | A2a–c、A3a–b、B9e | 6 |
| #4 | Dynamic Type 改造 | FR-3 | B2a、D3 | 2 |
| #5 | 按钮体系 + Sidebar 收敛（含 B2b 的 `minHeight`） | FR-4（按钮/Sidebar 部分） | B2b、B3a–e、B5、B8a | 8 |
| #6 | 死代码清理与现代化 | FR-5、FR-4（B8h） | B4a–d、B7a–c、B8c、B8d、B8h、B9a–d、B9f、B9g、D8、D10 | 18 |
| #7 | 测试质量重建 + Blossom 断言 | FR-6（测试部分） | C2、C4a、C4b、C5 | 4 |
| #8 | 可访问性 | FR-7（a11y 部分） | D1a–c | 3 |
| #9 | 本地化 String Catalog | FR-7（i18n 部分） | D2 | 1 |
| #10 | **公开 API 形态统一**：init 形态、`@ViewBuilder` slot、style 协议化、枚举合并 | FR-4（枚举合并）、FR-7（API 部分） | B8b、B8e–g、D4、D5、D6a–b、D7 | 9 |
| #11 | **机械清理**：文档、目录、gitignore、硬编码数值、Preview 补全 | FR-6（文档部分）、FR-7（清理部分） | C6b、C10a、C10c、C10d、D9、D12、D15、D16a–b、D18 | 10 |

（原 #10 按第 2 轮评审建议二分为 #10 / #11——公开 API 形态设计与 gitignore 去重、LICENSE 之类机械项混在一个 Issue 里会让评审粒度失配。）

**内部依赖（Issue 间）：**
- **`#1` 须最先合入**。它含 `defaultIsolation(MainActor.self)`（审计项 C7a）——这个开关改变**全库编译语义**，所有文件在新隔离默认值下重新检查，可能在任意组件冒出并发诊断。若它晚于 `#2`–`#11` 落地，期间写的代码会在开关合入时批量报错。故 C7a/C7b 从 #6 移入 #1，并作为唯一的硬性顺序约束
- `#1` 的 **CI 部分**不阻塞任何 Issue——其余 Issue 的"验证绿"以 NFR 前四条 SwiftPM 命令为准；**第 5 条（`xcodebuild` iOS Simulator 布局断言）只有 `#4` 需要**。CI 若因 runner 受限而降级，只影响门禁形态，不影响验证标准
- `#5` 依赖 `#3`（含 `CoreBorderlessButtonStyle` 改名，两者改同一批文件）
- `#4` 与 `#5` **有文件冲突**：B2b（Sidebar `minHeight`）已归 #5 实施化解了一处，但 FR-3 的 `CoreControlMetrics.font(for:)` → `fontToken(for:)` 改造要改写全部四个 ButtonStyle 的 font 调用行，而 #5 的 B3d 正在把这些行收敛成共享 modifier——同文件同行级冲突，须串行
- `#2` 与 `#4` **无逻辑依赖，但有 4 个文件重叠**：`Toast.swift`、`Badge.swift`、`Banner.swift`、`StatusRow.swift` 既是 #2 的 legacy status 迁移对象、又是 #4 的 `CoreTypography` 消费者，须由 owner 矩阵串行化。（注：`CheckBox.swift` 零 `CoreTypography` 引用，**不是** #2/#4 的重叠点；它的真实冲突方是 `#3`）
- `#7` 与 `#1` 相互独立，但 `#1` 的 CI 就绪后 `#7` 的成果才能进门禁
- `#2` 与 `#7` 须协同：`StatusColorsTests.swift` 同时是 `#2` 的破坏对象（引用被删的 token）与 `#7` 的改写对象（恒真断言）。**由 `#2` 负责让它编译通过**（删掉引用已删 token 的断言），`#7` 再做恒真断言的整体清理。否则 `#2` 单独落地时 `swift test` 必红，违反其自身验证标准

**文件级冲突：分解时须生成 owner 矩阵，不可依赖本节穷举**

**没有任何一组 Issue 可以无条件并发。** `#4` 一项就波及 24 文件 / 94 处（FR-3 自述），在 PRD 层面逐对枚举冲突注定挂一漏万——第 3 轮曾断言「#8/#9/#10/#11 可全程并行」、第 4 轮又断言「#4 与 #5 无文件冲突」，两条都被 grep 证伪。因此改为规则约束：

> **分解规则**：ccpm 分解时须按各 task 的实际触及文件生成 **owner 矩阵**，**同文件即串行**。`#4` 因波及面最大而成为串行枢纽，应整体排在结构性收敛（`#5`/`#6`/`#10`）之前或之后统一定序，不可与它们交错。

下表是**已知高危冲突示例**（用于校验 owner 矩阵是否合理，非穷举清单）。**表头约定**：`#4` 波及 24 文件 / 94 处，故各行默认可能叠加 `#4`，表中未逐行标注——用本表校验矩阵时须自行叠加 `#4` 维度，否则会产生假通过：

| 文件 | 涉及 Issue | 冲突性质 |
|---|---|---|
| `MenuButton.swift` | #3（改名）/ #5（B8a）/ #9（D2 中文串）/ #10（D5）/ #11（D12） | 五方 |
| `CommentCard.swift` | #4（D3）/ #6（B8c）/ #10（D4）/ #11（D12） | 四方 |
| `Toast.swift` | #2（legacy 迁移）/ #9（D2）/ #10（B8e 枚举合并） | 三方 |
| `Banner.swift` | #2（迁移）/ #10（B8b、B8e）/ #11（D9 **整文件移目录**） | 三方，含移动 vs 编辑 |
| `TimelineItem.swift` | #6（B9b）/ #10（D4）/ #11（D12） | 三方 |
| `Sidebar.swift` | #5（B5、B2b）/ #10（D6b）/ #11（D18） | 三方 |
| `ButtonRoleStyleRole.swift` | #3（A2c）/ #5（resolvedColor）/ #10（D5） | 三方 |
| `AvatarGroup.swift` | #4（D3）/ #10（D4）/ #11（D12） | 三方 |
| `BottomInputBar.swift` | #4（D3 `:302,376`）/ #6（B8h `:297-308,374-381`）/ #8（D1a） | 三方，#4 与 #6 **同 hunk** |
| 四个 ButtonStyle 文件 | #4（`fontToken` 改造）/ #5（B3d 收敛 font 行） | 同行级 |
| `StatusRow.swift` | #2（A1 `:80`）/ #4（D3 `:46`）/ #10（B8f、D4） | 三方 |
| `SegmentedControl.swift` | #6（B9d）/ #10（B8g、D7） | 两方 |
| `Form.swift` | #2（`:101` legacy）/ #8（D1c） | 两方 |
| `RefPill.swift` | #4（D3 + mono token）/ #6（B8d） | 两方 |
| `CLAUDE.md` | #2（分层描述）/ #6（删 `.getSize`）/ #11（`.focusedExternally`） | 三方；建议由 Epic 收尾统一改一次 |

**外部依赖：**
- Xcode 26 / Swift 6.3 工具链
- GitHub Actions macOS runner（版本待实测）
- EmergeTools SnapshotPreviews 0.14.0（现状保留，不升级）
- 仓库内 `App/` 预览宿主需随 FR-2 改名同步更新
