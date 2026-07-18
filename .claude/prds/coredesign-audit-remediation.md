---
name: coredesign-audit-remediation
description: 修复四路审计发现的约 50 项缺陷——遮蔽 SwiftUI 的真 bug、公开 API 断裂、重复色阶与 Dynamic Type 全库失效、以及缺失的质量保障基建
status: backlog
created: 2026-07-18T11:01:48Z
---

# PRD: coredesign-audit-remediation

## Executive Summary

CoreDesign 当前构建是绿的——`swift build`、`swift test`（96 tests / 32 suites）、`swift build --traits Blossom` 全部零 warning 通过。但四路并行审计（token 层 / 公开 API / 重复代码 / 构建测试基建）在代码中逐条核实出约 50 项缺陷，其中两类是真问题：

1. **`Color.primary` 遮蔽 SwiftUI 同名成员**，导致 `CheckBox` 实际渲染成品牌色而非系统 label 色，且因该 extension 未标 `public`，同一行代码在库内外含义不同。
2. **一批公开 API 因漏写 `public` 而下游不可用**——已用下游消费包实测出编译错误，其中包括文档明确指引业务侧使用的 `CheckBoxToggleStyle`。

绿色构建之所以没能拦住这些，是因为**质量保障基建实际不存在**：`.github/workflows/` 是空目录；96 个测试中约 3/4 是恒真断言（`#expect(String(describing:).isEmpty == false)` 之类），编译通过即必过；快照测试只生成不比对。"96 tests passed" 这个信号是失真的。

本 epic 一次性修完全部四簇缺陷，并补上 CI 与真断言测试，使后续改动有自动化回归防线。用户已确认：**breaking change 直接改，不保留 deprecated 兼容层**。

## Problem Statement

**为什么现在要做？**

1. **存在会误导使用者的真 bug。** `Colors/FunctionalColor.swift:11-12` 在 `Color` 上定义了 `static let primary/secondary/tertiary`，与 SwiftUI 内建同名。模块内本地定义静默胜出（实测确认，无歧义报错），`Components/CheckBox/CheckBox.swift:31` 的 `.foregroundStyle(Color.primary)` 实际解析到 `.brand5`，而该文件 21-23 行的注释还写着"light/dark 自动适配系统外观"。文档与行为直接矛盾。

2. **公开 API 表面有断裂，且已实测。** 在 scratchpad 建下游消费包逐条 probe，确认以下符号下游不可达：
   - `CheckBox.swift:24` `CheckBoxToggleStyle` → `error: cannot find 'CheckBoxToggleStyle' in scope`（而 `:52` 文档写着"业务侧通常直接使用"）
   - `BorderlessButtonStyle.swift:40,52` → `error: 'BorderlessButtonStyle' initializer is inaccessible due to 'internal' protection level`
   - `Utils/View+SizeReader.swift:44,48` `getSize` → `inaccessible`（CLAUDE.md 将其列为通用公开辅助）
   - `ButtonRoleStyleRole.swift:18,33,48` 的 `color`/`activeColor`/`disabledColor` → `inaccessible`（CLAUDE.md 称该枚举是三色"唯一来源"）

   更隐蔽的是 `BorderlessButtonStyle` 与 SwiftUI 自带类型同名：下游写 `BorderlessButtonStyle()` **能编译通过**，但静默解析到 SwiftUI 的类型。`MenuButton` 与 macOS 上 deprecated 的 SwiftUI `MenuButton` 同样冲突，实测报错信息具有误导性。

3. **Dynamic Type 全库失效。** `Tokens/CoreTypography.swift:53-183` 全部 10 个字体 token 用 `.system(size:weight:)`，`relativeTo:` 出现 0 次。全库仅 `MenuButton.swift:67` 与 `SegmentedControl.swift:247` 两处适配。配合 `Sidebar.swift:121,183,238,287` 四处写死 `frame(height:)`，大字号下侧栏行会裁切。这对一个对外分发的设计系统是可访问性硬伤。

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
- 下游消费包能成功构造 `CheckBoxToggleStyle`、`CoreBorderlessButtonStyle`、调用 `View.getSize`、读取 `ButtonRoleStyleRole` 的三个调色板属性
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
- `Sidebar` 四种 row 在 `xxxLarge` 字号下不裁切内容（由布局断言测试覆盖）
- 组件中绕过 token 直接使用系统字号的 7 处（`AvatarGroup.swift:59`、`StatusRow.swift:46`、`StateLabel.swift:50`、`CommentCard.swift:56`、`RefPill.swift:34,37,40,42,45`、`BottomInputBar.swift:302,376`）全部迁移到 token

### US-3: 主题使用者（Blossom）

**作为** 启用 Blossom trait 的调用方
**我想要** 主题下的强调色表现一致，不出现"侧栏选中粉、搜索框 focus 蓝"
**以便** 界面视觉是统一的

**验收标准：**
- `borderFocus`、`statusAccent*` 在 Blossom 下跟随品牌色（珊瑚粉）
- `statusSuccess`/`statusWarning`/`statusDanger` 在两个主题下保持标准语义色（绿/橙/红），不分流
- Blossom 分流点从 2 处降至 1 处（仅 `InteractionColors`）
- 存在测试断言 trait 分流后 token 指向不同且值正确的颜色——默认 `accent` → `brand-5` → `#0077FA`，Blossom → `blossom-brand-5` → `#FF6F8E`
- `BorderColors.swift:50` 与代码矛盾的注释被修正

### US-4: 设计系统维护者（=本人）

**作为** CoreDesign 维护者
**我想要** CI 自动守护两种构建模式，且测试通过数是可信信号
**以便** 我改动 token 或组件时能立刻知道是否破坏了什么

**验收标准：**
- CI 覆盖 `swift build`、`swift test`、`swift build --traits Blossom`、`swift test --traits Blossom` 四条命令
- 恒真断言测试被删除或改写为真断言；保留的行为测试（`ToastHostTests`、`AsyncButtonTests`、`KeyboardHandlingTests`、`ProgressBarTests`、`ListRowTests` 的泛型 slot 断言）继续通过
- 存在布局断言层覆盖 Dynamic Type 改造的裁切风险
- 修改后的测试总数与"真正验证了什么"可对应说明，不再有"编译即通过"的测试

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

- 第 4 层职责重定义为**状态功能别名**：保留 `success`/`info`/`warning`/`danger` 及 Active/Hover/Disable 变体，整层补 `public`
- 删除 `FunctionalColor` 的 `primary`/`secondary`/`tertiary` 三组；交互色统一走第 3 层 `InteractionColors`
- `CheckBox.swift:31` 改用 `Color.contentPrimary`，修正 21-23 行注释
- `danger` 基准 `red4` → `red5`，与同组的 5 档基准对齐
- `borderSelected` → `.accent`；`selectionBackgroundEmphasis` 走命名别名，消除层级违规
- `borderFocus`、`statusAccent*` 补 Blossom 分流
- `StatusColors` 新体系补 `*Border` 档，`Toast`/`Badge`/`Banner` 全量迁移，legacy 组（`StatusColors.swift:63-77`）删除
- 同步更新 CLAUDE.md 分层描述

### FR-2 公开 API 修复与改名

- 补 `public`：`CheckBoxToggleStyle`、`View.getSize` 及其 extension、`ButtonRoleStyleRole` 三个调色板属性、`FunctionalColor` extension
- `BorderlessButtonStyle` → `CoreBorderlessButtonStyle`，补 `public init(role:)` 与 `public let role`
- `MenuButton` → `CoreMenuButton`，避开 macOS 上 SwiftUI 同名的 deprecated 类型
- `CheckBox` 演示视图内联进 `#Preview`，只保留 `CheckBoxToggleStyle` 作为公开面
- 仓库内 `App/` 预览宿主同步适配改名

### FR-3 Dynamic Type 改造

- `CoreTypography` 从 `Font` 常量升级为 `.coreFont(_:)` modifier
- 内部用 `ScaledMetric(wrappedValue:relativeTo:)` 在 init 中按 token 角色指定缩放基准（display → `.largeTitle`，正文 → `.body`，caption → `.caption`）
- fontSize 与 lineSpacing 同步缩放；font/lineSpacing/tracking「三件套」收进单一调用点
- `Sidebar` 四处 `frame(height:)` → `minHeight`
- 组件中 7 处系统字号迁移到 token

### FR-4 结构性收敛

- `ButtonRoleStyleRole.resolvedColor(isEnabled:isPressed:)` 吸收三份重复取色逻辑
- `SolidButtonBackgroundModifier` 与 `LightButtonBackgroundModifier` 合并
- font/padding/contentShape 四行提炼为共享 modifier
- `CircularGlassButtonStyle` 接入 `@Environment(\.controlSize)`
- `Sidebar` 四个 row 收敛为共享骨架 + 薄封装
- `SegmentedControl` 的 `glass: Bool` 升级为 `SegmentedControlStyle` 协议 + `@Entry` + `.segmentedControlStyle(_:)`
- `ToastLevel` + `MessageLevel` 合并为单一 `StatusLevel`；各组件的平行 switch 收敛为返回 spec 结构体的单一 switch
- 四个 ButtonStyle 保持现有 `ButtonStyle` + 静态扩展形态，不再协议化

### FR-5 死代码清理与现代化

- 删除 `BottomInputBar.swift:87,138` 的 `textFieldSize` 及 `Utils/View+SizeReader.swift` 整文件
- 删除 `Utils/KeyboardHandling.swift` 中零引用的 public API（`KeyboardReadable` 及默认实现、`dismissKeyboardOnTap`、`resignFirstResponder`、`anyWriterFirstResponderNotification`/`becomeFirstResponder`）
- `CoreGradient`：`static var` → `static let`，文件移入 `Tokens/`，并至少在一处组件真实消费以验证抽象成立
- `TimelineItem` 旧式 `EnvironmentKey` → `@Entry`（同步改 `TimelineItemTests.swift:30`）
- `BookCover` 图片解码移出 body
- `CommentCard` 手写三件套 → `.surface(.card)`
- 删除 `bordered(color:)` 死重载；`BorderModifier` 改 `strokeBorder` 并支持任意 shape
- 删除 `SegmentedControl.swift:205,301` 恒真的 `@available(iOS 26.0, *)`
- 删除已废弃的 `EmptyState.swift` 整文件及其自证测试
- 删除死 token `CoreRadius.full`

### FR-6 测试与 CI 基建

- GitHub Actions workflow 覆盖四条命令组合
- 删除恒真断言测试；保留并扩充真行为测试
- 新增 Blossom 分流断言测试：`String(describing: Color)` 取 asset 名 → 解析 `.colorset/Contents.json` 的 sRGB 分量 → 按 `#if Blossom` 断言期望值
- 新增布局断言层覆盖 Dynamic Type 裁切风险
- 新增下游消费包 probe 纳入 CI，使 public API 断裂能被自动捕获（对应 US-1 验收标准）
- `Package.swift` 加 `.defaultIsolation(MainActor.self)`；`.iOS("26.0")` 改枚举形式
- `App/project.yml` 补 `traits: ["Blossom"]`；修正 `xcodeVersion` 与 iOS 26 部署目标的矛盾
- 补 LICENSE；修正 README 组件数量；`.gitignore` 去重并加入 `.claude/omsp/`

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

- **构建绿**：`swift build`、`swift test`、`swift build --traits Blossom`、`swift test --traits Blossom` 四条命令零 warning、零失败
- **平台**：iOS 26+ / macOS 26+ 双端编译通过，不为 iOS 26 API 添加可用性回退
- **并发**：Swift 6 语言模式 + `defaultIsolation(MainActor.self)`，无数据竞争诊断
- **视觉零回归**：除本 PRD 明确变更的项（`danger` 基准色档、Blossom 下 `borderFocus`/`statusAccent` 转品牌色、Dynamic Type 缩放）外，默认主题观感不变
- **性能**：消除 body 内的重复图片解码与每帧 `AnyShapeStyle` 装箱
- **代码风格**：遵循仓库既有约定（显式 `self.`、中英双语注释、`#Preview` 与组件同文件）

## Success Criteria

1. 下游消费包能成功编译使用全部文档所述 public API（0 个 `inaccessible` / `cannot find in scope` 错误）
2. Blossom 分流点数量：2 → 1
3. Dynamic Type 覆盖率：10 个 typography token 全部支持缩放（当前 0）
4. CI workflow 数量：0 → ≥1，覆盖 4 条命令组合
5. 恒真断言测试数量归零；保留测试全部为真断言
6. 存在至少 1 个测试能区分默认与 Blossom 主题的实际颜色值
7. 审计清单约 50 项缺陷全部关闭或有明确记录的不修理由
8. `Sidebar` row 代码量从约 120 行降至约 50 行

## Constraints & Assumptions

**约束：**
- **CI runner 需 Xcode 26**（iOS/macOS 26 部署目标要求）。GitHub Actions hosted runner 的 Xcode 版本可用性**未经验证**，是本 epic 的首要技术风险，必须在实现前实测
- `swift test` 下 asset 颜色**无法解析**——已实测确认 SwiftPM 不调用 `actool`，产出 bundle 只有原始 `Resources.xcassets` 目录，既无 `Assets.car` 也无 `Info.plist`，`Color.accent.resolve()` 返回 `(0,0,0,0)`。因此 Blossom 颜色断言必须走 asset 名 → `Contents.json` 解析路径，不能用 `Color.resolve`
- 新增 colorset 后必须 `swift package clean` 再构建，否则资源静默缺失
- `.build/` 存有跨路径 ModuleCache 时构建会失败，需先 clean

**假设：**
- **CoreDesign 无外部下游消费者**（用户明确确认"直接改，不管下游"）。若此假设不成立，FR-2 的改名与 FR-1 的删除会破坏下游编译
- 仓库内 `App/` 预览宿主是唯一需同步适配的消费者
- Primer 对齐仍是 typography 的设计目标，因此保留精确字号而非改用系统 TextStyle

## Out of Scope

- **像素级视觉回归测试**——用户明确选择"只生成 + agent 审美"，快照 PNG 继续作为文档插图，不升级为 baseline，不做像素比对
- **upcoming features**（`ExistentialAny`、`MemberImportVisibility`、`InternalImportsByDefault`）——会引入大片与本次修复无关的机械改动，搅浑 diff，另开一轮
- **版本 tag 与 semver 发布流程**——用户选择不管下游，故本轮不建立版本契约；README 的 `branch: "main"` 指引保持不变
- **deprecated 兼容层**——用户明确选择直接改，不保留 `@available(*, deprecated, renamed:)` 过渡
- **`StarShape` 的去留**——public 且零引用，但可能是给下游预留，本轮仅记录不处理
- **新增组件或新功能**——本 epic 纯修复与收敛，不做加法
- **`swift-snapshot-testing` 等外部测试依赖引入**

## Dependencies

**内部依赖（Issue 间）：**
- `#1 CI + Xcode 26 可行性` 是全局前置——后续每个 Issue 的"验证绿"都依赖它建立的自动化基线
- `#4 Dynamic Type` 依赖 `#2 色彩层重组`（token 层改动需先稳定）
- `#5 按钮体系收敛` 依赖 `#3 公开 API 修复`（含 `CoreBorderlessButtonStyle` 改名）
- `#7 测试质量重建` 依赖 `#1`
- `#8 可访问性`、`#9 本地化`、`#10 一致性清理` 与主线无依赖，可全程并行

**外部依赖：**
- Xcode 26 / Swift 6.3 工具链
- GitHub Actions macOS runner（版本待实测）
- EmergeTools SnapshotPreviews 0.14.0（现状保留，不升级）
- 仓库内 `App/` 预览宿主需随 FR-2 改名同步更新
