# 公开 API 形态统一（Issue #101）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use oh-my-superpowers:subagent-driven-development (recommended) or oh-my-superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 CoreDesign 上统一 9 个公开 API 形态审计项（B8b/B8e/B8f/B8g/D4/D5/D6a/D6b/D7），把重复枚举/switch 收敛、把布尔 hack 升级为 style 协议、把只收 `String` 的组件补 `@ViewBuilder` slot，并同步预览宿主 / docs / 下游 probe / 测试。

**Architecture:** 逐组件的形态收敛。多处引用的 `StatusLevel` 枚举合并先行；随后各组件独立改造（不同文件、可顺序执行）。所有改动是 **breaking change，直接改、不留 deprecated 兼容层**（epic 决策），但仓库内 `App/` 预览宿主、`docs/components/`、`Tests/`、`scripts/downstream-probe/` 必须同步改到编译绿。

**Tech Stack:** Swift 6.3（`swiftLanguageModes: [.v6]`，`defaultIsolation(MainActor.self)`）· SwiftUI（iOS 26+ / macOS 26+）· Swift Testing（`import Testing` / `@Test` / `#expect`，**非 XCTest**）· SwiftPM Package Trait（`Blossom`）· 下游 probe 为独立 SwiftPM 包（`scripts/downstream-probe`，path 依赖 `../..`）。

## Global Constraints

以下约束**每个 task 都隐式适用**，值逐字来自 Issue #101 与项目 memory：

- **零 warning**：每条验证命令的日志 `grep -c 'warning:'` 必须为 `0`。
- **两种 trait 都要绿**：`swift build` / `swift test`（默认 Craft）**与** `swift build --traits Blossom` / `swift test --traits Blossom`。本任务不新增 colorset，故无需 `swift package clean`（但最终全量验证仍冷跑，见 Task 9）。
- **第 5 条命令（本任务 DoD 强制）**：`xcodebuild test -scheme CoreDesign -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`——`DynamicTypeLayoutTests` 整 suite 被 `#if os(iOS)` 包住，前四条 SwiftPM 命令在 macOS 宿主下**编译都不进入**，只有这条能抓到 `SidebarNavigationRow` init 改动引发的 iOS-only 回归。
- **下游 probe 必须绿**：`cd scripts/downstream-probe && swift build`（守 nonisolated + public 可见性契约，CI job `downstream-probe`）。
- **公开面不得缩窄**：所有对外类型 / init / body 保持 `public`（含 init）。D4 的收敛是把**存储属性**从 `public` 降到 `internal`，不是删 API。
- **越界自查**：`git diff --name-only epic/coredesign-audit-remediation..HEAD` 应只落在 `Sources/`、`App/`、`docs/`、`scripts/downstream-probe/`、`Tests/`、`.claude/`。**`docs/superpowers/plans/*` 是历史归档，一律不动**——只改 `docs/components/*.md`。
- **注释禁污染 grep 自查**：源码注释里**不要**出现会污染统计的字面量（例如把 `@Test` / `#expect` 写进注释文本）。测试文件里正常的 `@Test` / `#expect` 是代码、不是注释，正常写。
- **Sendable 从不隐式合成**：枚举无关联值时 `Equatable` / `Hashable` 会隐式合成，但 `Sendable` 必须显式写。
- **`Color` 不 `Equatable`**：spec 结构体含 `Color` 字段时**不要**给 Spec 声明 `Equatable`（本任务 Spec 只在组件内部用，无需 Equatable）。
- **token 色隔离事实（关键）**：`Color.status*` 等 token 是 `public extension Color { static let x = Color("...", bundle: .module) }`，其 initializer 触达 `Bundle.module`，在 `defaultIsolation(MainActor.self)` 下**是 MainActor 隔离的**（见 `scripts/downstream-probe/.../PublicVisibility.swift` 的说明与 `NonisolatedUsage.swift` 对 `CoreElevation` 的注释）。凡 `switch` 返回 token `Color` 的成员，其宿主上下文必须是 MainActor（本计划的 `spec` 成员显式标 `@MainActor`）。

---

## 现状勘误（写码前已逐一 Read 核对，与题面的关键出入）

1. **`StateLabel` 实际只有 3 个 switch**（非题面"4 个"）：`iconName`、`backgroundColor`、`StateLabelStyle` 扩展上的 `defaultLabel`。`foregroundColor` 已是常量 `.contentOnEmphasis`（#93），不是 switch。`StateLabelStyle` 已是 `public nonisolated enum ... : Sendable, Equatable`。
2. **`CoreMenuButtonStyle` 与宿主 `CoreMenuButton` 都 internal**——D5 对它只是内部一致性收敛，**非 API breaking**。
3. **D4 的 7 处 `public let` 全部已有显式 designated init**（不依赖 memberwise init）。审计清单 D4 行还列了**第 8 处** `CoreBorderlessButtonStyle.swift:76` 的 `public let role`（#94 A2b 新增，"是否收回由 #10 判定"）——**本计划判定：保留 public**，因为 `PublicVisibility.swift:26` 的 `_ = style.role` 从下游 probe 钉死了它，降级会炸 probe。见 Task 3。
4. **`MessageLevel`（`Banner.swift:32`）与 `ButtonRoleStyleRole`（`ButtonRoleStyleRole.swift:11`）未标 `nonisolated`**；`ToastLevel`（`Toast.swift:24`，仅 `Sendable` 无 `Equatable`）/ `SurfaceKind`（`Sendable` 无 `Equatable`）/ `StateLabelStyle` / `StatusResult` 已是 `nonisolated ... Sendable`。
5. **`SurfaceKindAPIGuard.swift`（#98）引用全部 9 个 `SurfaceKind` case**——本任务对 `SurfaceKind` 只补 `Equatable`、不改 case，故它**不受影响**（Task 2 会跑它确认）。
6. **`Banner.swift` 的 `bannerIcon(for:)` / `bannerPalette(for:)` 已抽为 file-private 自由函数**；B8b 只剩两个 `makeBody` 的 11 行 HStack body 未抽（唯一差异是 Bordered 多 `.bordered(style: palette.border)`）。
7. **`EventRow` 已是双层形态**：`actor/action/timeAgo: String` + `@ViewBuilder pill: () -> PillContent = { EmptyView() }`（默认 EmptyView 的 designated init）。D6b 对 EventRow **已满足**，只需做 D4 降 internal。见 Task 7。
8. **额外破坏点（题面未提，本勘察新发现）**：`SidebarComponentsTests.swift:26` 有 `#expect(type(of: row) == SidebarNavigationRow.self)`——D6b 把 `SidebarNavigationRow` 泛型化后 `SidebarNavigationRow.self` 不再合法，须改成 `SidebarNavigationRow<AnyView>.self`。而 `DynamicTypeLayoutTests.swift:39` 的 `SidebarNavigationRow(systemImage:title:isSelected:){}` 走**保留的便利 init**、`{}` 绑定到 `action`，**预计不破**（仍要跑第 5 条命令确认）。

---

## 主编排已定的关键设计决策（本计划据此写死，勿自由改）

- **B8e**：新建 `Sources/CoreDesign/Components/StatusLevel.swift`，`public nonisolated enum StatusLevel: Sendable, Equatable { case info, success, warning, danger }`（用 `ToastLevel` 的 info/success/warning/danger 顺序）。删除 `ToastLevel` 与 `MessageLevel`，全局替换所有消费点。
- **D4**：降 `internal` 而非 `private`（AC 字面说"降 private"，但范例 `Badge` 存储属性本就是 `internal`，且降 private 会逼迫重写白盒测试；降 internal 已达成"不再是公开 API 表面、下游不能依赖内部布局"的真实意图）。
- **B8f**：`StateLabel`（3 switch）与 `StatusRow`（3 switch）各引入一个 spec 结构体 + 单个 `@MainActor var spec` 收敛为**一次穷举**。保留 `StatusRow` 关于 `.contentSecondary` 而非 `.secondary` 的 #93 注释语义。
- **D7**：`SegmentedControl` 对齐 `Banner` 四件套（`SegmentedControlStyle` 协议 + `SegmentedControlStyleConfiguration` + `@Entry var segmentedControlStyle` + `View.segmentedControlStyle(_:)`），提供两个内置实现，移除 `glass: Bool`。默认 style 保持玻璃观感。
- **B8g/B8b**：SegmentedControl 两处 glass overlay 抽共享构造；两个 `BannerStyle.makeBody` 抽公共 body-builder。
- **D5**：`ButtonRoleStyleRole` 补 `nonisolated` + `Sendable, Equatable`（三个调色板属性与 `resolvedColor` 显式标 `@MainActor` 保 token 访问）；`SurfaceKind` 补 `Equatable`；合并后的 `StatusLevel` 已含 Sendable/Equatable；`CoreMenuButtonStyle` 补 `Sendable, Equatable`（非 public、非 breaking）。
- **D6a/D6b**：`StateLabel`/`StatusRow` 泛型化为双层形态（`@ViewBuilder` designated init + `where Label == Text` String 便利 init，对齐 Badge/Tag）；`StateLabel` init 首参加标签（`init(_ style:)` → `init(style:)`）。`EventRow` 已满足。`SidebarNavigationRow` 补 `@ViewBuilder leading` designated init + AnyView 便利 init。

---

## File Structure（本任务将创建 / 修改的文件与职责）

| 文件 | 动作 | 职责 / 变更 |
|---|---|---|
| `Sources/CoreDesign/Components/StatusLevel.swift` | 创建 | 合并后的 `StatusLevel` 枚举（B8e / D5） |
| `Sources/CoreDesign/Components/Toast/Toast.swift` | 修改 | `ToastLevel` → `StatusLevel`（B8e） |
| `Sources/CoreDesign/Components/Banner.swift` | 修改 | `MessageLevel` → `StatusLevel`；两个 `makeBody` 抽公共 body-builder（B8e / B8b） |
| `Sources/CoreDesign/Components/Button/ButtonRoleStyleRole.swift` | 修改 | `nonisolated` + `Sendable, Equatable`；调色板成员 `@MainActor`（D5） |
| `Sources/CoreDesign/Modifier/SurfaceModifier.swift` | 修改 | `SurfaceKind` 补 `Equatable`（D5） |
| `Sources/CoreDesign/Components/BottomInputBar/CoreMenuButton.swift` | 修改 | `CoreMenuButtonStyle` 补 `Sendable, Equatable`（D5，非 public） |
| `Sources/CoreDesign/Components/ProgressBar/ProgressBar.swift` | 修改 | `public let`×3 → `let`（D4） |
| `Sources/CoreDesign/Components/CommentCard/CommentCard.swift` | 修改 | `public let`×4 → `let`（D4） |
| `Sources/CoreDesign/Components/EventRow/EventRow.swift` | 修改 | `public let`×3 → `let`（D4）；D6b 已满足 |
| `Sources/CoreDesign/Components/TimelineItem/TimelineItem.swift` | 修改 | `public let`×2 → `let`（D4） |
| `Sources/CoreDesign/Components/AvatarGroup/AvatarGroup.swift` | 修改 | `public let`×1 → `let`（D4） |
| `Sources/CoreDesign/Components/StateLabel/StateLabel.swift` | 修改 | 泛型化 + spec 结构体 + init 改名 + `let`（B8f/D6a/D6b/D4） |
| `Sources/CoreDesign/Components/StatusRow/StatusRow.swift` | 修改 | 泛型化 + spec 结构体 + `let`（B8f/D6b/D4） |
| `Sources/CoreDesign/Components/Sidebar/Sidebar.swift` | 修改 | `SidebarNavigationRow` 泛型化 + `@ViewBuilder leading`（D6b） |
| `Sources/CoreDesign/Components/SegmentedControl/SegmentedControl.swift` | 修改 | 抽共享 glass chrome（B8g）+ style 协议四件套、移除 `glass:`（D7） |
| `App/Sources/Previews.swift` | 修改 | `StateLabel` init 改名同步 |
| `Tests/CoreDesignTests/StateLabelTests.swift` | 修改 | init 改名 + 泛型下改断言 |
| `Tests/CoreDesignTests/StatusRowTests.swift` | 修改 | 泛型下改断言 |
| `Tests/CoreDesignTests/SidebarComponentsTests.swift` | 修改 | `type(of:)` → `<AnyView>` |
| `Tests/CoreDesignTests/SegmentedControlTests.swift` | 修改 | 移除 `glass:`、改用 `.segmentedControlStyle(_:)` |
| `Tests/CoreDesignTests/DynamicTypeLayoutTests.swift` | 视需要 | 仅在便利 init 构造点不再编译时改（预计不改，第 5 条命令验证） |
| `scripts/downstream-probe/.../NonisolatedUsage.swift` | 修改 | `useToastLevel`→`useStatusLevel`；新增 `compareButtonRole` 守 D5 |
| `docs/components/toast.md` / `banner.md` / `state-label.md` / `segmented-control.md` | 修改 | 类型名 / 示例同步 |
| `.claude/epics/coredesign-audit-remediation/audit-checklist.md` | 修改 | 9 项标 `✅ 已修复（GitHub #101）`（只改状态描述、不增删行） |

---

## Task 1: `StatusLevel` 枚举合并（B8e + 合并枚举的 D5）

把 `ToastLevel` 与 `MessageLevel` 合并成单一 `StatusLevel`。这一步先行，因为它波及 Toast / Banner / probe / docs 多处；后续 Banner 的 B8b（Task 4）建立在合并后的类型上。

**Files:**
- Create: `Sources/CoreDesign/Components/StatusLevel.swift`
- Modify: `Sources/CoreDesign/Components/Toast/Toast.swift`（`:24-29` 删枚举、`:47`/`:60`/`:196`/`:535` 用点、文档字样）
- Modify: `Sources/CoreDesign/Components/Banner.swift`（`:20-37` 删枚举、`:76`/`:122`/`:132`/`:149` 签名、文档字样）
- Modify: `scripts/downstream-probe/Sources/DownstreamProbe/NonisolatedUsage.swift:60-62`
- Modify: `docs/components/toast.md`（`:17`,`:21`,`:65`）、`docs/components/banner.md`（`:9`,`:34`）
- Test: `Tests/CoreDesignTests/BannerTests.swift`、`ToastHostTests.swift`（**只跑、预计不改**——它们只用 `.info`/`.success`/`.danger` case 名，合并后仍成立）

**Interfaces (Produces):**
- `public nonisolated enum StatusLevel: Sendable, Equatable { case info, success, warning, danger }`
- `ToastItem.level: StatusLevel`；`ToastHost.show(_:level:duration:)` 的 `level: StatusLevel = .info`
- `Banner.init(level: StatusLevel, ...)`；`BannerStyleConfiguration.level: StatusLevel`
- 后续 Task 4 依赖 `bannerIcon(for level: StatusLevel)` / `bannerPalette(for level: StatusLevel)` 已改签名。

- [ ] **Step 1: 新建 `StatusLevel.swift`**

创建 `Sources/CoreDesign/Components/StatusLevel.swift`：

```swift
//
//  StatusLevel.swift
//  CoreDesign
//

import SwiftUI

// MARK: - StatusLevel

/// 状态语义等级，决定组件的图标 + 配色映射。
///
/// 概念对应 GitHub Primer 的 `Flash` / `Toast` variant。由 `Toast` 与 `Banner`
/// 共用——两者此前各有一份 case 完全相同的枚举（`ToastLevel` / `MessageLevel`），
/// 现合并为单一类型（审计项 B8e）。具体颜色由
/// `Sources/CoreDesign/Colors/StatusColors.swift` 的 status color token 决定，
/// 随系统 colorScheme 自动适配 light / dark。
///
/// - `info`：中性提示（蓝）。例：版本可用、操作已记录。
/// - `success`：操作成功（绿）。例：保存成功、上传完成。
/// - `warning`：警告（橙）。例：即将过期、配额接近上限。
/// - `danger`：错误 / 风险（红）。例：保存失败、操作被拒绝。
public nonisolated enum StatusLevel: Sendable, Equatable {
    case info
    case success
    case warning
    case danger
}
```

- [ ] **Step 2: `Toast.swift` 改用 `StatusLevel`**

删除 `Toast.swift:12-29` 的 `// MARK: - ToastLevel` 段与整个 `public nonisolated enum ToastLevel: Sendable { ... }`。然后把该文件所有 `ToastLevel` 标识符替换为 `StatusLevel`：

- `:41` 文档 `` `ToastLevel` `` → `` `StatusLevel` ``
- `:47` `public let level: ToastLevel` → `public let level: StatusLevel`
- `:60` `level: ToastLevel = .info,` → `level: StatusLevel = .info,`
- `:196` `level: ToastLevel = .info,` → `level: StatusLevel = .info,`
- `:411` 文档 `` `ToastLevel` `` → `` `StatusLevel` ``
- `:535` `private let levels: [(label: String, level: ToastLevel)] = [` → `... level: StatusLevel)] = [`

`ToastItem: Sendable` 承诺不变（`StatusLevel` 是 `Sendable`）。案名 `.info`/`.success`/`.warning`/`.danger` 全部保留，`ToastView.icon` / `.foregroundColor` 的 `switch self.item.level` 无需改。

- [ ] **Step 3: `Banner.swift` 改用 `StatusLevel`（先只做类型替换，body 抽取留 Task 4）**

删除 `Banner.swift:20-37` 的 `// MARK: - MessageLevel` 段与整个 `public enum MessageLevel { ... }`。把该文件所有 `MessageLevel` 标识符替换为 `StatusLevel`（`:13`,`:55`,`:74`,`:76`,`:95`,`:116`,`:122`,`:127`,`:131`,`:132`,`:145`,`:149`,`:166`,`:200`,`:204` 处的文档与签名，重点签名：`:76` `init(level: MessageLevel, ...)`、`:122` `public let level: MessageLevel`、`:132` `func bannerIcon(for level: MessageLevel)`、`:149` `func bannerPalette(for level: MessageLevel)`）。

> 注意 `MessageLevel` 的 case 顺序原为 info/warning/danger/success，`StatusLevel` 用 info/success/warning/danger——case **名集合相同**，`switch` 覆盖不受顺序影响，Banner 的 `bannerIcon`/`bannerPalette` 两个 switch 照常覆盖 4 个 case。

- [ ] **Step 4: 更新下游 probe**

`scripts/downstream-probe/Sources/DownstreamProbe/NonisolatedUsage.swift`：把 `:60-62`

```swift
nonisolated func useToastLevel() -> ToastLevel {
    .info
}
```

改为

```swift
nonisolated func useStatusLevel() -> StatusLevel {
    .info
}
```

`:11` 的 `ToastItem(message: "hi", level: .info)` 不动（`.info` 现解析到 `StatusLevel.info`）。

- [ ] **Step 5: 更新 docs**

`docs/components/toast.md`：`:17` 的 `level: ToastLevel = .info` → `level: StatusLevel = .info`；`:21` `ToastLevel: info / success / warning / danger。` → `StatusLevel: info / success / warning / danger。`；`:65` `` 按 `ToastLevel` 走 `` → `` 按 `StatusLevel` 走 ``。

`docs/components/banner.md`：`:9` 表格 `| level | MessageLevel | ... |` → `| level | StatusLevel | ... |`；`:34` `` 按 `MessageLevel` 走 `` → `` 按 `StatusLevel` 走 ``。

- [ ] **Step 6: 构建 + 测试（两种 trait）+ probe**

Run:
```bash
swift build 2>&1 | tee /tmp/t1-build.log | tail -3
grep -c 'warning:' /tmp/t1-build.log
swift test 2>&1 | tail -5
swift build --traits Blossom 2>&1 | tee /tmp/t1-blossom.log | tail -3
grep -c 'warning:' /tmp/t1-blossom.log
cd scripts/downstream-probe && swift build 2>&1 | tail -3 && cd ../..
```
Expected: `Build complete!`；两处 `grep -c` 均输出 `0`；`swift test` 全绿（含 `BannerTests` / `ToastHostTests` 不改而过）；probe `Build complete!`。

- [ ] **Step 7: Commit**

```bash
git add Sources/CoreDesign/Components/StatusLevel.swift \
        Sources/CoreDesign/Components/Toast/Toast.swift \
        Sources/CoreDesign/Components/Banner.swift \
        scripts/downstream-probe/Sources/DownstreamProbe/NonisolatedUsage.swift \
        docs/components/toast.md docs/components/banner.md
git commit -m "refactor(status): merge ToastLevel + MessageLevel into StatusLevel (B8e)"
```

---

## Task 2: D5 剩余枚举协议补齐（`ButtonRoleStyleRole` / `SurfaceKind` / `CoreMenuButtonStyle`）

**Files:**
- Modify: `Sources/CoreDesign/Components/Button/ButtonRoleStyleRole.swift:11`
- Modify: `Sources/CoreDesign/Modifier/SurfaceModifier.swift:20`
- Modify: `Sources/CoreDesign/Components/BottomInputBar/CoreMenuButton.swift:77`
- Modify: `scripts/downstream-probe/Sources/DownstreamProbe/NonisolatedUsage.swift`（新增 `compareButtonRole` 守 nonisolated+Equatable）
- Test: `Tests/CoreDesignTests/SurfaceKindAPIGuard.swift`（只跑，确认 9 case 不受影响）

**Interfaces (Produces):**
- `public nonisolated enum ButtonRoleStyleRole: Sendable, Equatable`，`color`/`activeColor`/`disabledColor`/`resolvedColor(...)` 均标 `@MainActor`。
- `public nonisolated enum SurfaceKind: Sendable, Equatable`
- `enum CoreMenuButtonStyle: Sendable, Equatable`（internal）

- [ ] **Step 1: `ButtonRoleStyleRole` 补 nonisolated + Sendable, Equatable，成员保 `@MainActor`**

关键：枚举整体 `nonisolated` 会让 `color`/`activeColor`/`disabledColor`/`resolvedColor` 也变 nonisolated，而它们读 `.accent` 等 **MainActor 隔离的 token Color**——必须给这四个成员显式补 `@MainActor` 否则编译失败（见 Global Constraints「token 色隔离事实」）。

`ButtonRoleStyleRole.swift:11`，把

```swift
public enum ButtonRoleStyleRole {
    case primary
```

改为

```swift
public nonisolated enum ButtonRoleStyleRole: Sendable, Equatable {
    case primary
```

`:18`/`:33`/`:48` 三个计算属性各加 `@MainActor`：

```swift
    @MainActor
    public var color: Color {
```
```swift
    @MainActor
    public var activeColor: Color {
```
```swift
    @MainActor
    public var disabledColor: Color {
```

`:72` 的 `resolvedColor(...)` 加 `@MainActor`（它调用上面三个属性）：

```swift
    /// 按交互状态解析出最终颜色 / Resolve the color for a given interaction state.
    /// ...（保留原文档）...
    @MainActor
    public func resolvedColor(isEnabled: Bool, isPressed: Bool) -> Color {
```

> 现有 probe `readRolePalette`/`consumeResolvedColor` 已是 `@MainActor`，这些成员保持 `@MainActor` 后它们照常编译。

- [ ] **Step 2: `SurfaceKind` 补 `Equatable`**

`SurfaceModifier.swift:20`：

```swift
public nonisolated enum SurfaceKind: Sendable {
```
→
```swift
public nonisolated enum SurfaceKind: Sendable, Equatable {
```

9 个 case 与 `SurfaceKindAPIGuard.swift`（#98）无关（只补 conformance、不改 case）。

- [ ] **Step 3: `CoreMenuButtonStyle` 补 `Sendable, Equatable`（internal、非 breaking）**

`CoreMenuButton.swift:77`：

```swift
enum CoreMenuButtonStyle {
    case labeled
    case circular
}
```
→
```swift
enum CoreMenuButtonStyle: Sendable, Equatable {
    case labeled
    case circular
}
```

> `CoreMenuButtonStyle` 与宿主 `CoreMenuButton` 都是 internal——本项是内部一致性收敛，**非公开 API breaking**。

- [ ] **Step 4: 在 probe 增设 `ButtonRoleStyleRole` 的 nonisolated+Equatable 守卫**

在 `NonisolatedUsage.swift` 的 `compareStatusResult` / `compareStateLabelStyle` 一族旁（约 `:29` 后）新增（case 值二选一即可，只为触发 nonisolated + Equatable 契约）：

```swift
nonisolated func compareButtonRole(_ a: ButtonRoleStyleRole, _ b: ButtonRoleStyleRole) -> Bool {
    a == b
}
```

> 若日后有人抹掉 `ButtonRoleStyleRole` 的 `nonisolated` 或 `Equatable`/`Sendable`，此函数会在下游 probe 编译失败——四条 SwiftPM 命令看不见这层。

- [ ] **Step 5: 构建 + 测试 + probe**

Run:
```bash
swift build 2>&1 | tee /tmp/t2-build.log | tail -3 && grep -c 'warning:' /tmp/t2-build.log
swift test --filter SurfaceKind 2>&1 | tail -5
swift test 2>&1 | tail -5
swift build --traits Blossom 2>&1 | tee /tmp/t2-blossom.log | tail -3 && grep -c 'warning:' /tmp/t2-blossom.log
cd scripts/downstream-probe && swift build 2>&1 | tail -3 && cd ../..
```
Expected: `Build complete!`；`grep -c` 均 `0`；`SurfaceKindAPIGuard` 及全量测试绿；probe `Build complete!`。

- [ ] **Step 6: Commit**

```bash
git add Sources/CoreDesign/Components/Button/ButtonRoleStyleRole.swift \
        Sources/CoreDesign/Modifier/SurfaceModifier.swift \
        Sources/CoreDesign/Components/BottomInputBar/CoreMenuButton.swift \
        scripts/downstream-probe/Sources/DownstreamProbe/NonisolatedUsage.swift
git commit -m "refactor(enums): unify semantic-enum protocol conformances (D5)"
```

---

## Task 3: D4 存储属性降 internal（5 个纯 D4 组件）

只处理**不做泛型化**的 5 个组件（`StateLabel`/`StatusRow` 的 `let` 收进它们各自的 Task 5/6，避免同文件改两遍）。这 5 个组件的白盒测试都跨文件 `@testable` 读这些属性，降 `internal`（非 `private`）后**测试不受影响**。

**Files:**
- Modify: `Sources/CoreDesign/Components/ProgressBar/ProgressBar.swift:22-24`
- Modify: `Sources/CoreDesign/Components/CommentCard/CommentCard.swift:27-30`
- Modify: `Sources/CoreDesign/Components/EventRow/EventRow.swift:23-25`
- Modify: `Sources/CoreDesign/Components/TimelineItem/TimelineItem.swift:33-34`
- Modify: `Sources/CoreDesign/Components/AvatarGroup/AvatarGroup.swift:23`
- Test: `ProgressBarTests` / `CommentCardTests` / `EventRowTests` / `TimelineItemTests` / `AvatarGroupTests`（只跑、不改）

**决定并记录：`CoreBorderlessButtonStyle.swift:76` 的 `public let role` 不降级**——它由 `PublicVisibility.swift:26`（`_ = style.role`）从下游 probe 钉死（#94 A2b 契约），降级会炸 probe。审计清单 D4 的"是否收回由 #10 判定"由本任务判为**保留**。

- [ ] **Step 1: `ProgressBar` 降 internal**

`ProgressBar.swift:22-24`：

```swift
    public let value: Double  // 0.0...1.0
    public let tint: Color?
    public let label: String?
```
→
```swift
    let value: Double  // 0.0...1.0
    let tint: Color?
    let label: String?
```
（`public init` 不动。）

- [ ] **Step 2: `CommentCard` 降 internal**

`CommentCard.swift:27-30`：

```swift
    public let author: String
    public let role: String?
    public let timestamp: String
    public let isMinimized: Binding<Bool>?
```
→（去掉每行 `public`；`:31` 的 `@ViewBuilder let content` 已非 public，不动）
```swift
    let author: String
    let role: String?
    let timestamp: String
    let isMinimized: Binding<Bool>?
```

- [ ] **Step 3: `EventRow` 降 internal**

`EventRow.swift:23-25`：

```swift
    public let actor: String
    public let action: String
    public let timeAgo: String
```
→
```swift
    let actor: String
    let action: String
    let timeAgo: String
```
（`:26` 的 `@ViewBuilder let pill` 已非 public。EventRow 的 D6b 由既有 `pill` 默认 EmptyView designated init 满足，无需新增——见 Task 7 说明。）

- [ ] **Step 4: `TimelineItem` 降 internal**

`TimelineItem.swift:33-34`：

```swift
    public let showsTopConnector: Bool
    public let isLast: Bool
```
→
```swift
    let showsTopConnector: Bool
    let isLast: Bool
```

- [ ] **Step 5: `AvatarGroup` 降 internal**

`AvatarGroup.swift:23`：

```swift
    public let max: Int
```
→
```swift
    let max: Int
```

- [ ] **Step 6: 测试确认不受影响**

Run:
```bash
swift test --filter "ProgressBar" 2>&1 | tail -5
swift test --filter "CommentCard" 2>&1 | tail -5
swift test --filter "EventRow" 2>&1 | tail -5
swift test --filter "TimelineItem" 2>&1 | tail -5
swift test --filter "AvatarGroup" 2>&1 | tail -5
swift build 2>&1 | tee /tmp/t3-build.log | tail -3 && grep -c 'warning:' /tmp/t3-build.log
cd scripts/downstream-probe && swift build 2>&1 | tail -3 && cd ../..
```
Expected: 五个 suite 全绿（`@testable` 内部仍可读 internal 属性）；`grep -c` 输出 `0`；probe `Build complete!`（`CoreBorderlessButtonStyle.role` 保 public，probe `_ = style.role` 照常编译）。

- [ ] **Step 7: Commit**

```bash
git add Sources/CoreDesign/Components/ProgressBar/ProgressBar.swift \
        Sources/CoreDesign/Components/CommentCard/CommentCard.swift \
        Sources/CoreDesign/Components/EventRow/EventRow.swift \
        Sources/CoreDesign/Components/TimelineItem/TimelineItem.swift \
        Sources/CoreDesign/Components/AvatarGroup/AvatarGroup.swift
git commit -m "refactor(api): demote frozen stored properties to internal (D4)"
```

---

## Task 4: B8b — Banner 两个 `makeBody` 抽公共 body-builder

**Files:**
- Modify: `Sources/CoreDesign/Components/Banner.swift`（`:174-193` `PlainBannerStyle`、`:207-226` `BorderedBannerStyle`，新增共享自由函数）
- Test: `Tests/CoreDesignTests/BannerTests.swift`（只跑，构造型断言不变）

**Interfaces (Consumes):** Task 1 已把 `bannerIcon(for:)` / `bannerPalette(for:)` 改为收 `StatusLevel`。

- [ ] **Step 1: 新增共享 body-builder（唯一差异是 `bordered` 布尔控制描边）**

在 `Banner.swift` 的 `// MARK: - Banner shared helpers` 段内（`bannerPalette(for:)` 之后、`// MARK: - PlainBannerStyle` 之前）插入：

```swift
/// 两个内置 `BannerStyle` 的公共布局主体（审计项 B8b）。
///
/// `PlainBannerStyle` 与 `BorderedBannerStyle` 的 body 只差最后的背景是否叠描边，
/// 抽此一处避免两份 11 行 HStack 逐字重复。`bordered` 为 `true` 时在背景 `Rectangle`
/// 上追加 `.bordered(style: palette.border)`（`CoreBorderWidth.thin`）。
@ViewBuilder
private func bannerBody(configuration: BannerStyleConfiguration, bordered: Bool) -> some View {
    let palette = bannerPalette(for: configuration.level)
    HStack(spacing: CoreSpacing.sm) {
        bannerIcon(for: configuration.level)
            .foregroundStyle(palette.foreground)
            .accessibilityHidden(true)
        configuration.label
    }
    .accessibilityElement(children: .combine)
    .coreFont(.bodyMedium)
    .foregroundStyle(palette.foreground)
    .padding(CoreSpacing.md)
    .background {
        if bordered {
            Rectangle().fill(palette.background).bordered(style: palette.border)
        } else {
            Rectangle().fill(palette.background)
        }
    }
}
```

- [ ] **Step 2: `PlainBannerStyle.makeBody` 改为委托**

`Banner.swift:177-192`，把 `PlainBannerStyle.makeBody` 的整个 body 替换为：

```swift
    public func makeBody(configuration: Configuration) -> some View {
        bannerBody(configuration: configuration, bordered: false)
    }
```

- [ ] **Step 3: `BorderedBannerStyle.makeBody` 改为委托**

`Banner.swift:210-225`，替换为：

```swift
    public func makeBody(configuration: Configuration) -> some View {
        bannerBody(configuration: configuration, bordered: true)
    }
```

- [ ] **Step 4: 构建 + 测试**

Run:
```bash
swift build 2>&1 | tee /tmp/t4-build.log | tail -3 && grep -c 'warning:' /tmp/t4-build.log
swift test --filter Banner 2>&1 | tail -5
swift build --traits Blossom 2>&1 | tee /tmp/t4-blossom.log | tail -3 && grep -c 'warning:' /tmp/t4-blossom.log
```
Expected: `Build complete!`；`grep -c` 均 `0`；`BannerTests` 两个用例（`Banner<Text>` 构造）绿。

- [ ] **Step 5: Commit**

```bash
git add Sources/CoreDesign/Components/Banner.swift
git commit -m "refactor(banner): extract shared makeBody body-builder (B8b)"
```

---

## Task 5: `StateLabel` — B8f + D6a + D6b + D4

泛型化为 Badge/Tag 双层形态、3 个 switch 收敛为单个 `@MainActor var spec`、init 首参加标签。

**Files:**
- Modify: `Sources/CoreDesign/Components/StateLabel/StateLabel.swift`（整文件重构）
- Modify: `App/Sources/Previews.swift:181-185`
- Modify: `docs/components/state-label.md:30-33`
- Test: `Tests/CoreDesignTests/StateLabelTests.swift`（改断言）

**Interfaces (Produces):**
- `public struct StateLabel<Label: View>: View`
- designated：`public init(style: StateLabelStyle, @ViewBuilder label: () -> Label)`
- 便利：`public extension StateLabel where Label == Text { init(style: StateLabelStyle, label: String? = nil) }`
- `internal` 存储：`let style: StateLabelStyle`、`let label: Label`
- `StateLabelStyle` 上新增 `@MainActor var spec: Spec`，`struct Spec { let icon: String; let background: Color; let defaultLabel: String }`（`internal`，供测试读 `spec.defaultLabel`）

- [ ] **Step 1: 先改测试（红→绿的红）——更新 `StateLabelTests` 到新 init + spec 断言**

泛型化后 `label` 是 `Text` 视图、无法与 `String` 比较；default label 覆盖改为断言 `StateLabelStyle.<case>.spec.defaultLabel`。整文件替换为：

```swift
import SwiftUI
import Testing
@testable import CoreDesign

@Suite("StateLabel")
@MainActor
struct StateLabelTests {
    @Test("active maps to success status color")
    func activeMapsToSuccess() {
        let label = StateLabel(style: .active)
        #expect(label.style == .active)
        #expect(StateLabelStyle.active.spec.defaultLabel == "Active")
    }

    @Test("completed maps to done status color")
    func completedMapsToDone() {
        let label = StateLabel(style: .completed)
        #expect(label.style == .completed)
    }

    @Test("all styles construct and expose a spec")
    func allStylesConstruct() {
        for style in [StateLabelStyle.active, .draft, .completed, .cancelled, .inProgress, .error] {
            let label = StateLabel(style: style)
            #expect(label.style == style)
            #expect(!style.spec.icon.isEmpty)
        }
    }

    @Test("default labels come from the style spec")
    func defaultLabels() {
        #expect(StateLabelStyle.draft.spec.defaultLabel == "Draft")
        #expect(StateLabelStyle.inProgress.spec.defaultLabel == "In Progress")
        #expect(StateLabelStyle.error.spec.defaultLabel == "Error")
    }

    @Test("convenience init accepts a custom label and preserves style")
    func customLabelPreservesStyle() {
        let label = StateLabel(style: .inProgress, label: "Saving…")
        #expect(label.style == .inProgress)
    }
}
```

- [ ] **Step 2: 跑测试确认红（未改实现前，新 init 名不存在）**

Run: `swift test --filter StateLabel 2>&1 | tail -15`
Expected: 编译失败，形如 `incorrect argument label in call (have '_:', expected 'style:')` 或 `value of type 'StateLabelStyle' has no member 'spec'`。

- [ ] **Step 3: 重构 `StateLabel.swift`**

整文件替换为（`StateLabelStyle` 枚举本体保持不变，新增 `spec`；`StateLabel` 泛型化 + 单 switch）：

```swift
//
//  StateLabel.swift
//  CoreDesign
//

import SwiftUI

// MARK: - StateLabelStyle

/// 通用状态标签的语义样式。
///
/// 颜色映射通过 `StatusColors` 系统的 emphasis 背景 + `contentOnEmphasis` 前景实现，
/// 图标 / 背景 / 默认文案统一由下方 `spec` 单次穷举给出（审计项 B8f）。
public nonisolated enum StateLabelStyle: Sendable, Equatable {
    case active      // success (green) — in progress
    case draft       // attention (yellow) — not ready / WIP
    case completed   // done (purple) — finished
    case cancelled   // danger (red) — cancelled
    case inProgress  // attention (yellow) — transient / in-flight (e.g. saving)
    case error       // danger (red) — recoverable failure (e.g. save failed)
}

extension StateLabelStyle {
    /// 单个样式的图标 / 背景 / 默认文案三元组（审计项 B8f）。
    ///
    /// 收敛前 `StateLabel` 有三个平行 switch（iconName / backgroundColor / defaultLabel）；
    /// 现由 `spec` 一次穷举返回。新增 case 时编译器只在此处要求穷举。
    struct Spec {
        let icon: String
        let background: Color
        let defaultLabel: String
    }

    /// `@MainActor`：`background` 读 `status*Emphasis` token Color，在
    /// `defaultIsolation(MainActor.self)` 下这些 token 是 MainActor 隔离的。
    /// 消费点（`StateLabel.body` 与便利 init）都在 MainActor，故不受限。
    @MainActor
    var spec: Spec {
        switch self {
        case .active:
            Spec(icon: "circle.fill", background: .statusSuccessEmphasis, defaultLabel: "Active")
        case .draft:
            Spec(icon: "circle.dashed", background: .statusAttentionEmphasis, defaultLabel: "Draft")
        case .completed:
            Spec(icon: "checkmark.circle.fill", background: .statusDoneEmphasis, defaultLabel: "Completed")
        case .cancelled:
            Spec(icon: "xmark.circle.fill", background: .statusDangerEmphasis, defaultLabel: "Cancelled")
        case .inProgress:
            Spec(icon: "arrow.triangle.2.circlepath", background: .statusAttentionEmphasis, defaultLabel: "In Progress")
        case .error:
            Spec(icon: "exclamationmark.triangle.fill", background: .statusDangerEmphasis, defaultLabel: "Error")
        }
    }
}

// MARK: - StateLabel

/// Native Primer lifecycle state label.
///
/// Control-layer status pill driven by `StateLabelStyle`. Compact,
/// color-for-meaning, no decorative material — same restraint rules as
/// `Badge`, with a fixed icon + caller-supplied label payload.
///
/// **Material layer**: control. **Surface role**: control.
///
/// 通用状态标识 pill。大圆角 + 彩色背景 + SF Symbol 图标 + label 内容。
/// 双层 init 形态对齐 `Badge` / `Tag`：`@ViewBuilder` designated init 可插图标 /
/// 富文本，`where Label == Text` 便利 init 收 `String`（审计项 D6a / D6b）。
public struct StateLabel<Label: View>: View {
    let style: StateLabelStyle
    let label: Label

    /// 以任意 label 视图构造。
    public init(style: StateLabelStyle, @ViewBuilder label: () -> Label) {
        self.style = style
        self.label = label()
    }

    public var body: some View {
        HStack(spacing: CoreSpacing.xs) {
            Image(systemName: self.style.spec.icon)
                .coreFont(.caption)
                // 评审 Suggestion 4：`.combine` 会把未隐藏子元素的可访问名折进来。
                // 原 `.accessibilityLabel(self.label)`（String）压掉了 icon；泛型化后改
                // `.combine`，须显式隐藏 icon 否则 SF Symbol 名泄漏进 VoiceOver name
                // （与 Banner.swift:182 对 icon 的处理一致）。
                .accessibilityHidden(true)
            self.label
                .coreFont(.bodySmall)
        }
        // 前景统一走 `contentOnEmphasis`（白）——背景用 `status*Emphasis`（饱和填充），
        // 配对前景即 `onEmphasis`。此前按 style 返回 `status*Foreground` 在 #93 修正
        // emphasis 为饱和实色后会与背景同色（对比度 1.00、文字不可见）。
        // `BookCover.swift:155` 是同一配对的既有先例。
        .foregroundStyle(Color.contentOnEmphasis)
        .padding(.horizontal, CoreSpacing.sm)
        .padding(.vertical, CoreSpacing.xxs)
        .background(
            Capsule(style: .continuous)
                .fill(self.style.spec.background)
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - StateLabel convenience init

public extension StateLabel where Label == Text {
    /// 文本 StateLabel 便利构造。`label == nil` 时用 style 的默认文案。
    init(style: StateLabelStyle, label: String? = nil) {
        self.init(style: style) {
            Text(label ?? style.spec.defaultLabel)
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        StateLabel(style: .active)
        StateLabel(style: .draft)
        StateLabel(style: .completed)
        StateLabel(style: .cancelled)
        StateLabel(style: .inProgress)
        StateLabel(style: .error)
        StateLabel(style: .inProgress, label: "Saving…")
        StateLabel(style: .error, label: "Save failed")
    }
    .padding()
}
```

> 注意：原 `.accessibilityLabel(self.label)`（String）在泛型下无法保留，改由 `.accessibilityElement(children: .combine)` 从 label 内容合并可访问名——与 `Badge` 一致。

- [ ] **Step 4: 同步 App 预览宿主**

`App/Sources/Previews.swift:181-185`：

```swift
        StateLabel(.active)
        StateLabel(.draft)
        StateLabel(.completed)
        StateLabel(.cancelled)
        StateLabel(.active, label: "In Progress")
```
→
```swift
        StateLabel(style: .active)
        StateLabel(style: .draft)
        StateLabel(style: .completed)
        StateLabel(style: .cancelled)
        StateLabel(style: .active, label: "In Progress")
```

- [ ] **Step 5: 同步 docs**

`docs/components/state-label.md:30-33`：

```swift
StateLabel(.active)
StateLabel(.draft, label: "WIP")
StateLabel(.completed)
StateLabel(.cancelled)
```
→
```swift
StateLabel(style: .active)
StateLabel(style: .draft, label: "WIP")
StateLabel(style: .completed)
StateLabel(style: .cancelled)
```

- [ ] **Step 6: 跑测试确认绿 + 构建**

Run:
```bash
swift test --filter StateLabel 2>&1 | tail -8
swift build 2>&1 | tee /tmp/t5-build.log | tail -3 && grep -c 'warning:' /tmp/t5-build.log
swift build --traits Blossom 2>&1 | tee /tmp/t5-blossom.log | tail -3 && grep -c 'warning:' /tmp/t5-blossom.log
```
Expected: `StateLabel` suite 绿；`Build complete!`；两处 `grep -c` 均 `0`。

- [ ] **Step 7: Commit**

```bash
git add Sources/CoreDesign/Components/StateLabel/StateLabel.swift \
        App/Sources/Previews.swift docs/components/state-label.md \
        Tests/CoreDesignTests/StateLabelTests.swift
git commit -m "refactor(state-label): generic label slot + spec + labeled init (B8f/D6a/D6b/D4)"
```

---

## Task 6: `StatusRow` — B8f + D6b + D4

泛型化为双层形态、3 个 switch 收敛为单个 `@MainActor var spec`、`public let` → `let`。便利 init 保留原签名，故 App / docs / Preview 调用点**无需改**。

**Files:**
- Modify: `Sources/CoreDesign/Components/StatusRow/StatusRow.swift`（整文件重构）
- Test: `Tests/CoreDesignTests/StatusRowTests.swift`（改断言）

**Interfaces (Produces):**
- `public struct StatusRow<Label: View>: View`
- designated：`public init(duration: String, result: StatusResult, @ViewBuilder label: () -> Label)`
- 便利：`public extension StatusRow where Label == Text { init(label: String, duration: String, result: StatusResult) }`
- `internal` 存储：`let label: Label`、`let duration: String`、`let result: StatusResult`
- `StatusResult` 上新增 `@MainActor var spec: Spec`，`struct Spec { let icon: String; let color: Color; let label: String }`

- [ ] **Step 1: 先改测试**

`StatusRowTests.swift` 整文件替换（`label` 现为 `Text`，去掉 `.label == String` 断言）：

```swift
import SwiftUI
import Testing
@testable import CoreDesign

@Suite("StatusRow")
@MainActor
struct StatusRowTests {
    @Test("convenience init stores scalar parameters")
    func initParams() {
        let row = StatusRow(label: "build (arm64)", duration: "2m 14s", result: .success)
        #expect(row.duration == "2m 14s")
        #expect(row.result == .success)
    }

    @Test("all result cases construct and expose a spec")
    func allResults() {
        for result in [StatusResult.success, .failure, .pending, .skipped] {
            let row = StatusRow(label: "test", duration: "0s", result: result)
            #expect(row.result == result)
            #expect(!result.spec.label.isEmpty)
        }
    }
}
```

- [ ] **Step 2: 跑测试确认红**

Run: `swift test --filter StatusRow 2>&1 | tail -12`
Expected: 编译失败，`value of type 'StatusResult' has no member 'spec'`。

- [ ] **Step 3: 重构 `StatusRow.swift`**

整文件替换为：

```swift
//
//  StatusRow.swift
//  CoreDesign
//

import SwiftUI

// MARK: - StatusResult

/// CI 检查结果状态。
public nonisolated enum StatusResult: Sendable, Equatable {
    case success
    case failure
    case pending
    case skipped
}

extension StatusResult {
    /// 单个结果的图标 / 前景色 / 可读标签三元组（审计项 B8f）。
    ///
    /// 收敛前 `StatusRow` 有三个平行 switch（resultIcon / resultColor / resultLabel）；
    /// 现由 `spec` 一次穷举返回。
    struct Spec {
        let icon: String
        let color: Color
        let label: String
    }

    /// `@MainActor`：`color` 读 status token Color（MainActor 隔离）。
    @MainActor
    var spec: Spec {
        switch self {
        case .success:
            Spec(icon: "checkmark.circle.fill", color: .statusSuccessForeground, label: "Passed")
        case .failure:
            Spec(icon: "xmark.circle.fill", color: .statusDangerForeground, label: "Failed")
        case .pending:
            Spec(icon: "clock", color: .statusAttentionForeground, label: "Pending")
        case .skipped:
            // #93：原写 `.secondary` 会解析到已删的第 4 层同名别名（`lightBlue5` /
            // Blossom `violet5`）而非中性次要色，skipped 图标渲染成浅蓝/紫罗兰。
            // 用语义层 `.contentSecondary` 明确表达「中性次要色」。
            Spec(icon: "minus.circle", color: .contentSecondary, label: "Skipped")
        }
    }
}

// MARK: - StatusRow

/// Native Primer status row.
///
/// Content-layer row. CI status entry (icon + label + duration + result).
/// Color carries semantics; chrome stays minimal. No glass, no cardification.
///
/// **Material layer**: content. **Surface role**: content.
///
/// CI 检查状态行。图标 + label 内容 + 耗时 + 结果指示器。双层 init 形态对齐
/// `Badge` / `Tag`：`@ViewBuilder` designated init 可插图标 / 富文本，
/// `where Label == Text` 便利 init 收 `String`（审计项 D6b）。
public struct StatusRow<Label: View>: View {
    let label: Label
    let duration: String
    let result: StatusResult

    /// 以任意 label 视图构造。
    public init(duration: String, result: StatusResult, @ViewBuilder label: () -> Label) {
        self.duration = duration
        self.result = result
        self.label = label()
    }

    public var body: some View {
        HStack(spacing: CoreSpacing.sm) {
            Image(systemName: self.result.spec.icon)
                .foregroundStyle(self.result.spec.color)
                .coreFont(.caption)
                // 评审 Suggestion 4：泛型化后改 `.combine`，显式隐藏 icon 防 SF Symbol 名
                // 泄漏进 VoiceOver name（对齐 Banner.swift:215）。
                .accessibilityHidden(true)

            self.label
                .coreFont(.bodySmall)
                .lineLimit(1)

            Spacer()

            Text(self.duration)
                .coreFont(.bodySmall)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
                // duration 已由 accessibilityValue 承载，隐藏避免 combine 重复朗读。
                .accessibilityHidden(true)
        }
        .padding(.horizontal, CoreSpacing.md)
        .padding(.vertical, CoreSpacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(self.result.spec.label), \(self.duration)")
    }
}

// MARK: - StatusRow convenience init

public extension StatusRow where Label == Text {
    /// 文本 StatusRow 便利构造（保留原签名，既有调用点不变）。
    init(label: String, duration: String, result: StatusResult) {
        self.init(duration: duration, result: result) {
            Text(label)
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        StatusRow(label: "build (arm64)", duration: "2m 14s", result: .success)
        Divider()
        StatusRow(label: "test (macOS)", duration: "3m 01s", result: .success)
        Divider()
        StatusRow(label: "lint", duration: "0m 12s", result: .failure)
        Divider()
        StatusRow(label: "deploy (preview)", duration: "—", result: .pending)
        Divider()
        StatusRow(label: "analyze", duration: "—", result: .skipped)
    }
    .padding()
    .background(Color.surfaceCanvas)
}
```

> 可访问性行为保持：原 `.accessibilityLabel(self.label)`（String）在泛型下改由 `.combine` 从 label 内容取名；`duration` 标 `.accessibilityHidden(true)` 防止与 `accessibilityValue` 重复朗读，最终 VoiceOver 输出「名 = label 内容 / 值 = "<result>, <duration>"」与改前一致。

- [ ] **Step 4: 跑测试确认绿 + 构建（两 trait）**

Run:
```bash
swift test --filter StatusRow 2>&1 | tail -6
swift build 2>&1 | tee /tmp/t6-build.log | tail -3 && grep -c 'warning:' /tmp/t6-build.log
swift build --traits Blossom 2>&1 | tee /tmp/t6-blossom.log | tail -3 && grep -c 'warning:' /tmp/t6-blossom.log
```
Expected: `StatusRow` suite 绿；`Build complete!`；两处 `grep -c` 均 `0`（App `Previews.swift:289-297` / `docs/components/status-row.md` 走保留的便利 init，未改亦编译）。

- [ ] **Step 5: Commit**

```bash
git add Sources/CoreDesign/Components/StatusRow/StatusRow.swift \
        Tests/CoreDesignTests/StatusRowTests.swift
git commit -m "refactor(status-row): generic label slot + spec collapse (B8f/D6b/D4)"
```

---

## Task 7: `SidebarNavigationRow` D6b（+ EventRow D6b 结论）

`SidebarNavigationRow` 泛型化补 `@ViewBuilder leading` designated init + AnyView 便利 init。`EventRow` 的 D6b 已由既有 `pill` 默认-EmptyView designated init 满足（Task 3 已做其 D4），此任务只记录结论。**本任务触及 `Sidebar.swift` 的 row init 形态——必须跑第 5 条命令**（`DynamicTypeLayoutTests` iOS-only）。

**Files:**
- Modify: `Sources/CoreDesign/Components/Sidebar/Sidebar.swift`（`SidebarNavigationRow` `:172-203`）
- Modify: `Tests/CoreDesignTests/SidebarComponentsTests.swift:26`
- 视需要 Modify: `Tests/CoreDesignTests/DynamicTypeLayoutTests.swift:39`（预计不改）
- 不改：`App/Sources/Previews.swift:94-95`、`ComponentData.swift:220-221`、`docs/components/sidebar.md:44-45`（走保留的便利 init）

**Interfaces (Produces):**
- `public struct SidebarNavigationRow<Leading: View>: View`
- designated：`public init(title: String, isSelected: Bool, action: @escaping () -> Void, @ViewBuilder leading: () -> Leading)`
- 便利：`public extension SidebarNavigationRow where Leading == AnyView { init(systemImage: String, title: String, isSelected: Bool, action: @escaping () -> Void) }`

- [ ] **Step 1: 重构 `SidebarNavigationRow`**

`Sidebar.swift:172-203` 的整个 `public struct SidebarNavigationRow: View { ... }` 替换为：

```swift
public struct SidebarNavigationRow<Leading: View>: View {
    /// 以任意 leading 视图构造（可插图标 / 富文本，审计项 D6b）。
    public init(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void,
        @ViewBuilder leading: () -> Leading
    ) {
        self.title = title
        self.isSelected = isSelected
        self.action = action
        self.leading = leading()
    }

    public var body: some View {
        SidebarRow(
            title: self.title,
            titleLineLimit: nil,
            isSelected: self.isSelected,
            action: self.action
        ) {
            self.leading
        } trailing: {
            EmptyView()
        }
    }

    private let title: String
    private let isSelected: Bool
    private let action: () -> Void
    private let leading: Leading
}

public extension SidebarNavigationRow where Leading == AnyView {
    /// SF Symbol 便利构造（保留原签名，既有调用点不变）。
    ///
    /// `AnyView` 擦除在此可接受：leading 只是单个 `.coreFont(.bodyLarge)` 图标、
    /// 无测试断言其具体类型（与 `Badge` 需保留 `Text` 精确类型的场景不同），
    /// 擦除代价可忽略，且能一比一复现改前的 bodyLarge 字号观感。
    init(systemImage: String, title: String, isSelected: Bool, action: @escaping () -> Void) {
        self.init(title: title, isSelected: isSelected, action: action) {
            AnyView(Image(systemName: systemImage).coreFont(.bodyLarge))
        }
    }
}
```

> `SidebarRow` 骨架对 leading 施加 `.foregroundStyle(.secondary).frame(width:).accessibilityHidden(true)`（`:128-133`）不变，故 systemImage 便利路径的观感与改前逐像素一致。

- [ ] **Step 2: 更新 `SidebarComponentsTests.swift:26`（类型断言泛型化）**

```swift
        #expect(type(of: row) == SidebarNavigationRow.self)
```
→
```swift
        #expect(type(of: row) == SidebarNavigationRow<AnyView>.self)
```
（`:19-24` 的构造 `SidebarNavigationRow(systemImage:title:isSelected:action:)` 走便利 init，不改。）

- [ ] **Step 3: 默认 trait 构建 + macOS 测试**

Run:
```bash
swift build 2>&1 | tee /tmp/t7-build.log | tail -3 && grep -c 'warning:' /tmp/t7-build.log
swift test --filter Sidebar 2>&1 | tail -6
```
Expected: `Build complete!`；`grep -c` `0`；`Sidebar components` suite 绿。

- [ ] **Step 4: 第 5 条命令（iOS Simulator，抓 `DynamicTypeLayoutTests`）**

`DynamicTypeLayoutTests.swift:39` 的 `SidebarNavigationRow(systemImage:title:isSelected:){}` 走便利 init、`{}` 绑定 `action`，**预计仍编译**。跑第 5 条命令验证：

Run:
```bash
xcodebuild test -scheme CoreDesign -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -25
```
Expected: `** TEST SUCCEEDED **`，`DynamicTypeLayoutTests` 全绿。

**若** 编译报 `DynamicTypeLayoutTests.swift:39` 处 ambiguous / cannot find init，则把该行改为显式 `leading:` + `action:` 双标签（保底修法，仅此情形执行）：
```swift
        let row = SidebarNavigationRow(systemImage: "star", title: "Long enough title to wrap at accessibility sizes", isSelected: false, action: {})
```
改后重跑第 5 条命令确认绿。

- [ ] **Step 5: Blossom 构建**

Run: `swift build --traits Blossom 2>&1 | tee /tmp/t7-blossom.log | tail -3 && grep -c 'warning:' /tmp/t7-blossom.log`
Expected: `Build complete!`；`grep -c` `0`。

- [ ] **Step 6: Commit**

```bash
git add Sources/CoreDesign/Components/Sidebar/Sidebar.swift \
        Tests/CoreDesignTests/SidebarComponentsTests.swift
# 仅当 Step 4 保底修法触发时追加：
# git add Tests/CoreDesignTests/DynamicTypeLayoutTests.swift
git commit -m "refactor(sidebar): generic leading slot on navigation row (D6b)"
```

---

## Task 8: `SegmentedControl` — B8g 抽共享 glass chrome + D7 style 协议

本任务两个 commit：先做 B8g（在现结构上抽共享 glass chrome、测试保持绿），再做 D7（style 四件套、移除 `glass:`）。合并处理因二者同文件、且 D7 会搬动 B8g 抽出的代码。

**Files:**
- Modify: `Sources/CoreDesign/Components/SegmentedControl/SegmentedControl.swift`（整文件重构）
- Modify: `Tests/CoreDesignTests/SegmentedControlTests.swift`
- Modify: `docs/components/segmented-control.md`
- 不改：`App/Sources/Previews.swift:57`、`ComponentData.swift:136`（未传 `glass:`，走默认 style）

**Interfaces (Produces):**
- `public struct SegmentedControlStyleConfiguration`：内含 `struct Segment: Identifiable { let index: Int; let title: String; let isSelected: Bool; var id: Int { index } }`、`let segments: [Segment]`、`let select: (Int) -> Void`
- `public protocol SegmentedControlStyle { associatedtype Body: View; @ViewBuilder @MainActor @preconcurrency func makeBody(configuration: Configuration) -> Body; typealias Configuration = SegmentedControlStyleConfiguration }`
- `public struct GlassSegmentedControlStyle: SegmentedControlStyle`（默认）、`public struct PlainSegmentedControlStyle: SegmentedControlStyle`
- `@Entry var segmentedControlStyle: any SegmentedControlStyle = GlassSegmentedControlStyle()`
- `public extension View { func segmentedControlStyle(_ style: some SegmentedControlStyle) -> some View }`
- `SegmentedControl.init(items:selection:title:)`（**移除 `glass:`**）

### Commit 1 — B8g：抽共享 glass chrome

- [ ] **Step 1: 新增共享 glass chrome 自由函数**

在 `SegmentedControl.swift` 文件顶部（`import` 之后、`// MARK: - SegmentedControl` 之前）插入：

```swift
/// 分段控件玻璃壳的共享构造（审计项 B8g）。
///
/// `selectedThumb` 的 glass 分支与 `SegmentedControlBackgroundModifier` 的 glass
/// 分支此前各自复制同一段「透明填充 + 交互玻璃 + 细描边」；抽此一处，thumb 侧再叠
/// `.coreShadow(.small)`。
@ViewBuilder
private func segmentedGlassChrome<S: InsettableShape>(_ shape: S) -> some View {
    shape
        .fill(.clear)
        .glassEffect(.regular.interactive(), in: shape)
        .overlay(
            shape.strokeBorder(Color.borderSubtle, lineWidth: CoreBorderWidth.hairline)
        )
}
```

- [ ] **Step 2: `selectedThumb` glass 分支改用共享构造**

`SegmentedControl.swift:124-138`（`if self.glass { ... }` 分支）替换为：

```swift
        if self.glass {
            // thumb 叠在 SegmentedControlBackgroundModifier 的玻璃外壳之上；
            // `.fill(.clear)` 有意——再加底色会让两层玻璃变浑浊。
            segmentedGlassChrome(shape)
                .coreShadow(.small)
        } else {
```

- [ ] **Step 3: `SegmentedControlBackgroundModifier` glass 分支改用共享构造**

`SegmentedControl.swift:389-397`（`content.background(...).overlay(...)` 的 glass 分支）替换为：

```swift
            content
                .background(segmentedGlassChrome(self.shape))
```

> **评审 Suggestion 3（z-order 微变，列入视觉冒烟）**：原 `SegmentedControlBackgroundModifier` 把 `strokeBorder` **overlay 在 `content` 之上**（`:395-397`，描边在 segments 上方），而 `segmentedGlassChrome` 把描边烤进 `.background`（shape 上、content 之下）。合并后 container hairline 从 above-content 移到 behind-content。capsule 边缘实际差异大概率为 nil，但这是真实 z-order 变化——**收尾的视觉冒烟须抽查 SegmentedControl 的描边观感**（`selectedThumb` 侧本就是 overlay-on-shape，无变化；仅外壳 modifier 侧变）。

- [ ] **Step 4: 构建 + 测试（B8g 视觉近似——有一处描边 z-order 微变见 Step 3，测试仅测构造全绿）**

Run:
```bash
swift build 2>&1 | tee /tmp/t8a-build.log | tail -3 && grep -c 'warning:' /tmp/t8a-build.log
swift test --filter SegmentedControl 2>&1 | tail -6
```
Expected: `Build complete!`；`grep -c` `0`；`SegmentedControl` suite 三用例绿（此时仍含 `glass: false`）。

- [ ] **Step 5: Commit（B8g）**

```bash
git add Sources/CoreDesign/Components/SegmentedControl/SegmentedControl.swift
git commit -m "refactor(segmented): extract shared glass chrome constructor (B8g)"
```

### Commit 2 — D7：style 协议四件套 + 移除 `glass:`

- [ ] **Step 6: 先改测试到 style 形态**

`SegmentedControlTests.swift` 整文件替换（移除 `glass:`，opt-out 改走 `.segmentedControlStyle(_:)`）：

```swift
import SwiftUI
import Testing
@testable import CoreDesign

@Suite("SegmentedControl")
struct SegmentedControlTests {
    @MainActor
    @Test("segmented control constructs with two items")
    func segmentedControlConstructsWithTwoItems() {
        let selection = Binding.constant("One")
        let control = SegmentedControl(
            items: ["One", "Two"],
            selection: selection,
            title: { $0 }
        )

        #expect(type(of: control) == SegmentedControl<String>.self)
    }

    @MainActor
    @Test("segmented control constructs with three items")
    func segmentedControlConstructsWithThreeItems() {
        let selection = Binding.constant("A")
        let control = SegmentedControl(
            items: ["A", "B", "C"],
            selection: selection,
            title: { $0 }
        )

        #expect(type(of: control) == SegmentedControl<String>.self)
    }

    @MainActor
    @Test("plain style opts out of glass via the style modifier")
    func plainStyleOptsOutOfGlass() {
        let selection = Binding.constant("One")
        let styled = SegmentedControl(
            items: ["One", "Two"],
            selection: selection,
            title: { $0 }
        )
        .segmentedControlStyle(PlainSegmentedControlStyle())
        // 四件套接通即编译通过（modifier 返回 `some View`，不再是 SegmentedControl<Item>）。
        _ = styled
    }

    @MainActor
    @Test("both built-in styles produce a body from a configuration")
    func builtInStylesProduceBody() {
        let config = SegmentedControlStyleConfiguration(
            segments: [
                .init(index: 0, title: "A", isSelected: true),
                .init(index: 1, title: "B", isSelected: false),
            ],
            select: { _ in }
        )
        _ = GlassSegmentedControlStyle().makeBody(configuration: config)
        _ = PlainSegmentedControlStyle().makeBody(configuration: config)
    }
}
```

- [ ] **Step 7: 跑测试确认红**

Run: `swift test --filter SegmentedControl 2>&1 | tail -12`
Expected: 编译失败，`cannot find 'PlainSegmentedControlStyle'` / `extra argument 'glass'` 之类。

- [ ] **Step 8: 重构 `SegmentedControl.swift` 为 style 四件套**

把 `SegmentedControl` 的可见部分改为「构建 type-erased 配置 → 委托当前 style」。`items`/`selection`/`title` 保留，**删 `glass`**。`SegmentedControl.swift:20-154` 的 `public struct SegmentedControl<Item: Hashable>: View { ... }` 整块替换为：

```swift
// MARK: - SegmentedControlStyleConfiguration

/// 传给 `SegmentedControlStyle.makeBody` 的上下文：类型擦除的分段数据 + 选择回调。
///
/// `Item` 泛型在此收敛为「index + 展示文字 + 选中态」，让 style 能同时驱动 iOS 原生
/// `UISegmentedControl`（收 `[String]` + index）与 SwiftUI 回退路径（按 index 重建）。
public struct SegmentedControlStyleConfiguration {
    /// 单个分段的类型擦除表示。
    public struct Segment: Identifiable {
        public let index: Int
        public let title: String
        public let isSelected: Bool
        public var id: Int { self.index }

        public init(index: Int, title: String, isSelected: Bool) {
            self.index = index
            self.title = title
            self.isSelected = isSelected
        }
    }

    public let segments: [Segment]
    /// 选中第 `index` 段的回调（由 `SegmentedControl` 注入，内部做 `withAnimation` + 越界保护）。
    public let select: (Int) -> Void

    public init(segments: [Segment], select: @escaping (Int) -> Void) {
        self.segments = segments
        self.select = select
    }
}

// MARK: - SegmentedControlStyle

/// `SegmentedControl` 视觉外观的扩展点，形态对齐 `BannerStyle` / Apple `ButtonStyle`。
///
/// 实现该协议提供新外观，通过 `View.segmentedControlStyle(_:)` 注入子树。内置
/// `GlassSegmentedControlStyle`（默认，Liquid Glass 外壳）与 `PlainSegmentedControlStyle`
/// （纯色外壳）。此前的 `glass: Bool` 布尔 hack 升级为本协议（审计项 D7）。
public protocol SegmentedControlStyle {
    associatedtype Body: View

    @ViewBuilder
    @MainActor @preconcurrency
    func makeBody(configuration: Self.Configuration) -> Body

    typealias Configuration = SegmentedControlStyleConfiguration
}

// MARK: - SegmentedControl

/// Native Primer segmented control.
///
/// GitHub-like density on an Apple-native control surface. 外观由环境注入的
/// `SegmentedControlStyle` 决定，默认 `GlassSegmentedControlStyle`。
public struct SegmentedControl<Item: Hashable>: View {
    /// 创建分段控件。
    ///
    /// - Parameters:
    ///   - items: 选项数据源；`Item: Hashable`，用于 `selection` 比较与标识。
    ///   - selection: 当前选中项的双向绑定。
    ///   - title: 把 `Item` 映射到展示文字。
    public init(
        items: [Item],
        selection: Binding<Item>,
        title: @escaping (Item) -> String
    ) {
        self.items = items
        self._selection = selection
        self.title = title
    }

    public var body: some View {
        let segments = self.items.enumerated().map { index, item in
            SegmentedControlStyleConfiguration.Segment(
                index: index,
                title: self.title(item),
                isSelected: item == self.selection
            )
        }
        let configuration = SegmentedControlStyleConfiguration(segments: segments) { index in
            guard self.items.indices.contains(index) else { return }
            self.select(self.items[index])
        }
        return AnyView(self.style.makeBody(configuration: configuration))
    }

    @Binding private var selection: Item
    @Environment(\.segmentedControlStyle) private var style

    private let items: [Item]
    private let title: (Item) -> String

    private func select(_ item: Item) {
        withAnimation(.easeInOut(duration: 0.18)) {
            self.selection = item
        }
    }
}
```

- [ ] **Step 9: 新增共享 SwiftUI body + 两个内置 style + 环境入口**

在 Step 8 替换块之后、`#if os(iOS)` 原生实现之前，插入 SwiftUI 回退主体（owns `@Namespace`，两 style 共用，仅 glass 布尔不同）与两个 style。把原 `swiftUISegmentedControl` / `segment(for:)` / `selectedThumb` 逻辑迁进此私有 View：

```swift
// MARK: - SwiftUI body（两个内置 style 共用）

private struct SwiftUISegmentedControl: View {
    let configuration: SegmentedControlStyleConfiguration
    let glass: Bool

    @Namespace private var namespace

    var body: some View {
        let shape = Capsule(style: .continuous)
        return HStack(spacing: CoreSpacing.xxs) {
            ForEach(self.configuration.segments) { segment in
                self.segmentView(segment)
            }
        }
        // 保留原 `swiftUISegmentedControl` 的 inset（SegmentedControl.swift:74）——
        // 让 segments/thumb 从玻璃外壳边缘缩进，形成「track 内浮起 thumb」的观感。
        // 评审 Finding 1：迁移时漏掉会让 thumb 贴外壳（所有 SwiftUI 回退渲染 = iOS
        // Plain + 全 macOS 受影响；测试只测构造，四命令/iOS 命令都抓不到）。
        .padding(CoreSpacing.xxs)
        .frame(maxWidth: .infinity)
        .modifier(SegmentedControlBackgroundModifier(shape: shape, glass: self.glass))
        .frame(height: CoreControlMetrics.height(for: .regular))
        // 保留原 fallback 路径的选择触感（SegmentedControl.swift:84）——评审 Finding 2：
        // 无 `selection` 属性，改由选中 segment 的 index 驱动 trigger（Int? 可 Equatable）。
        .sensoryFeedback(.selection, trigger: self.configuration.segments.first(where: \.isSelected)?.index)
    }

    @ViewBuilder
    private func segmentView(_ segment: SegmentedControlStyleConfiguration.Segment) -> some View {
        Button {
            self.configuration.select(segment.index)
        } label: {
            Text(segment.title)
                .coreFont(.bodyMedium)
                .fontWeight(segment.isSelected ? .semibold : .regular)
                .foregroundStyle(segment.isSelected ? Color.contentPrimary : Color.contentSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .background {
                    if segment.isSelected {
                        self.selectedThumb
                            .matchedGeometryEffect(id: "SegmentedControl.thumb", in: self.namespace)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(segment.isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var selectedThumb: some View {
        let shape = Capsule(style: .continuous)
        if self.glass {
            segmentedGlassChrome(shape)
                .coreShadow(.small)
        } else {
            shape
                .fill(Color.surfaceCanvasSubtle)
                .overlay(
                    shape.strokeBorder(Color.borderSubtle, lineWidth: CoreBorderWidth.hairline)
                )
                .coreShadow(.small)
        }
    }
}

// MARK: - Built-in styles

/// 默认外观：Liquid Glass 外壳。iOS 走原生 `UISegmentedControl` + `UIGlassEffect`，
/// 其他平台走玻璃版 SwiftUI 回退。
public struct GlassSegmentedControlStyle: SegmentedControlStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        #if os(iOS)
        NativeGlassSegmentedControl(
            titles: configuration.segments.map(\.title),
            selectedIndex: configuration.segments.first(where: \.isSelected)?.index,
            onSelect: configuration.select
        )
        .frame(maxWidth: .infinity)
        .frame(height: CoreControlMetrics.height(for: .regular))
        .sensoryFeedback(.selection, trigger: configuration.segments.firstIndex(where: \.isSelected))
        #else
        SwiftUISegmentedControl(configuration: configuration, glass: true)
        #endif
    }
}

/// 纯色外壳外观（此前 `glass: false`）。全平台走 SwiftUI 回退。
public struct PlainSegmentedControlStyle: SegmentedControlStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        SwiftUISegmentedControl(configuration: configuration, glass: false)
    }
}

// MARK: - Environment entry

extension EnvironmentValues {
    /// 当前生效的 `SegmentedControlStyle`，默认 `GlassSegmentedControlStyle`。
    @Entry var segmentedControlStyle: any SegmentedControlStyle = GlassSegmentedControlStyle()
}

public extension View {
    /// 为子树中的所有 `SegmentedControl` 设置外观（对齐 `View.bannerStyle(_:)`）。
    func segmentedControlStyle(_ style: some SegmentedControlStyle) -> some View {
        self.environment(\.segmentedControlStyle, style)
    }
}
```

- [ ] **Step 10: `NativeGlassSegmentedControl` 由泛型 `<Item>` 改为 `[String]` + index**

`#if os(iOS)` 块内的 `private struct NativeGlassSegmentedControl<Item: Hashable>: UIViewRepresentable { ... }`（`:157-203`）替换为按 index 驱动的版本（`NativeGlassSegmentedControlView` / `ImmediateFeedbackSegmentedControl` 两个下层 UIKit 类**不动**）：

```swift
#if os(iOS)
private struct NativeGlassSegmentedControl: UIViewRepresentable {
    let titles: [String]
    let selectedIndex: Int?
    let onSelect: (Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> NativeGlassSegmentedControlView {
        let view = NativeGlassSegmentedControlView()
        view.control.addTarget(
            context.coordinator,
            action: #selector(Coordinator.selectionChanged(_:)),
            for: .valueChanged
        )
        return view
    }

    func updateUIView(_ uiView: NativeGlassSegmentedControlView, context: Context) {
        context.coordinator.parent = self
        uiView.configure(titles: self.titles)

        let target = self.selectedIndex ?? UISegmentedControl.noSegment
        if uiView.control.selectedSegmentIndex != target {
            uiView.control.selectedSegmentIndex = target
        }

        uiView.updateForCurrentTraits()
    }

    final class Coordinator: NSObject {
        var parent: NativeGlassSegmentedControl

        init(parent: NativeGlassSegmentedControl) {
            self.parent = parent
        }

        @objc func selectionChanged(_ control: UISegmentedControl) {
            let index = control.selectedSegmentIndex
            guard index >= 0, index < self.parent.titles.count else { return }
            self.parent.onSelect(index)
        }
    }
}
```

（原文件 `:205-374` 的 `NativeGlassSegmentedControlView` 与 `ImmediateFeedbackSegmentedControl` 保持不变；`:377-408` 的 `SegmentedControlBackgroundModifier` 保持不变——它已在 B8g Step 3 用 `segmentedGlassChrome`。两个 `#Preview`（`:410-469`）保持不变，因为它们不传 `glass:`。）

- [ ] **Step 11: 更新 docs**

`docs/components/segmented-control.md`，在 API 表格（`:11` 之后）与「使用示例」之间补一句 style 说明（对齐 banner.md 的写法）。在 `:11` 行后、`:13` `## 预览` 前插入：

```markdown

支持 `View.segmentedControlStyle(_:)` 注入外观，内置 `GlassSegmentedControlStyle`（默认）与 `PlainSegmentedControlStyle`。
```

- [ ] **Step 12: 跑测试确认绿 + 构建（两 trait）**

Run:
```bash
swift test --filter SegmentedControl 2>&1 | tail -8
swift build 2>&1 | tee /tmp/t8b-build.log | tail -3 && grep -c 'warning:' /tmp/t8b-build.log
swift build --traits Blossom 2>&1 | tee /tmp/t8b-blossom.log | tail -3 && grep -c 'warning:' /tmp/t8b-blossom.log
```
Expected: `SegmentedControl` suite 四用例绿；`Build complete!`；两处 `grep -c` 均 `0`（App `Previews.swift:57` / `ComponentData.swift:136` 未传 `glass:`、走默认 style，无需改）。

- [ ] **Step 13: 第 5 条命令（iOS，确认原生玻璃路径与 Dynamic Type 联动仍编译/绿）**

Run:
```bash
xcodebuild test -scheme CoreDesign -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
```
Expected: `** TEST SUCCEEDED **`。

- [ ] **Step 14: Commit（D7）**

```bash
git add Sources/CoreDesign/Components/SegmentedControl/SegmentedControl.swift \
        Tests/CoreDesignTests/SegmentedControlTests.swift \
        docs/components/segmented-control.md
git commit -m "refactor(segmented): SegmentedControlStyle four-piece set, drop glass Bool (D7)"
```

---

## Task 9: 收尾 — audit-checklist + 全量冷验证 + finishing/PR

**Files:**
- Modify: `.claude/epics/coredesign-audit-remediation/audit-checklist.md`（9 项状态，只改描述、不增删行）

- [ ] **Step 1: 标记 audit-checklist 9 项为已修复**

对 `:60`(B8b)、`:63`(B8e)、`:64`(B8f)、`:65`(B8g)、`:106`(D4)、`:107`(D5)、`:108`(D6a)、`:109`(D6b)、`:110`(D7) 九行，在**第 2 列（缺陷描述）最前**插入 `✅ **已修复**（GitHub #101）——<理由>。原缺陷：`，保留其余列（证据 / FR / Issue）原样。逐行插入的理由文案：

- **B8b**：`两个 makeBody 抽出 file-private bannerBody(configuration:bordered:)，唯一差异 .bordered 由布尔控制。`
- **B8e**：`ToastLevel + MessageLevel 合并为单一 StatusLevel（nonisolated Sendable Equatable，info/success/warning/danger），Toast/Banner/probe/docs 同步；ToastItem: Sendable 与 downstream probe 仍绿。`
- **B8f**：`StateLabel 3 switch 与 StatusRow 3 switch 各收敛为单个 @MainActor var spec（返回 icon/背景/文案 三元组），新增 case 只在一处要求穷举。`
- **B8g**：`两处 glass overlay 抽为 segmentedGlassChrome(_:)（透明填充+交互玻璃+细描边），thumb 侧再叠 coreShadow。`
- **D4**：`7 处 public let 存储属性降 internal（ProgressBar/StatusRow/StateLabel/CommentCard/EventRow/TimelineItem/AvatarGroup），@testable 白盒测试不受影响；CoreBorderlessButtonStyle.role 判定保留 public——由 PublicVisibility probe（_ = style.role，#94 A2b 契约）钉死，降级会炸 probe。`
- **D5**：`StatusLevel（合并后）/ SurfaceKind 补 Equatable；ButtonRoleStyleRole 补 nonisolated + Sendable, Equatable（三个调色板属性与 resolvedColor 保 @MainActor 以访问 token Color），新增 probe compareButtonRole 守卫；CoreMenuButtonStyle 补 Sendable, Equatable（internal、非 public breaking）。`
- **D6a**：`StateLabel 泛型化对齐 Badge/Tag 双层形态，init 首参加标签 init(style:...)；三个 pill 组件 init 形态统一。`
- **D6b**：`StateLabel/StatusRow 补 @ViewBuilder designated init + where Label==Text 便利 init；EventRow 既有 pill（默认 EmptyView）designated init 已满足；SidebarNavigationRow 泛型化补 @ViewBuilder leading + AnyView 便利 init。`
- **D7**：`glass: Bool 升级为 SegmentedControlStyle 四件套（协议 + Configuration + @Entry + View.segmentedControlStyle(_:)），内置 Glass/Plain 两实现，对齐 BannerStyle 形态。`

- [ ] **Step 2: 校验 checklist 计数不漂移**

Run（在 `.claude/epics/coredesign-audit-remediation/` 下）：
```bash
cd .claude/epics/coredesign-audit-remediation
echo $(( $(grep -c '^| [A-D][0-9]' audit-checklist.md) - 4 ))
grep -oE '\| #[0-9]+ \|$' audit-checklist.md | sort -V | uniq -c | awk '{s+=$1}END{print s}'
cd -
```
Expected: 第一条 `83`，第二条 `79`（只改了状态描述、未增删数据行、未动行首 `| <ID> |` 与行尾 `| #10 |`）。

- [ ] **Step 3: 全量冷验证（4 条 SwiftPM + 第 5 条 + probe）**

`verification-before-completion`：给"完成"结论前必须有命令输出为证。冷跑（`swift package clean` 清缓存，虽未新增 colorset 仍冷跑求稳）：

Run:
```bash
swift package clean
swift build            2>&1 | tee /tmp/f-build.log        | tail -3 && grep -c 'warning:' /tmp/f-build.log
swift test             2>&1 | tee /tmp/f-test.log         | tail -6 && grep -c 'warning:' /tmp/f-test.log
swift build --traits Blossom 2>&1 | tee /tmp/f-bbuild.log | tail -3 && grep -c 'warning:' /tmp/f-bbuild.log
swift test  --traits Blossom 2>&1 | tee /tmp/f-btest.log  | tail -6 && grep -c 'warning:' /tmp/f-btest.log
xcodebuild test -scheme CoreDesign -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tee /tmp/f-xcode.log | tail -6
cd scripts/downstream-probe && swift build 2>&1 | tail -3 && cd ../..
```
Expected: 四条 SwiftPM 全绿、五处 `grep -c 'warning:'` 全 `0`；`xcodebuild` `** TEST SUCCEEDED **`；probe `Build complete!`。

- [ ] **Step 4: 越界自查**

Run:
```bash
git diff --name-only epic/coredesign-audit-remediation..HEAD | sort
```
Expected：仅出现在 `Sources/`、`App/`、`docs/components/`、`scripts/downstream-probe/`、`Tests/`、`.claude/epics/coredesign-audit-remediation/`。**不得**出现 `docs/superpowers/plans/*`（历史归档）或其他目录。

- [ ] **Step 5: Commit checklist**

```bash
git add .claude/epics/coredesign-audit-remediation/audit-checklist.md
git commit -m "docs(audit): mark B8b/B8e/B8f/B8g/D4/D5/D6a/D6b/D7 fixed (#101)"
```

- [ ] **Step 6: finishing-a-development-branch → 开 PR（base=epic/coredesign-audit-remediation）**

用 `oh-my-superpowers:finishing-a-development-branch` 的 **Option 2（PR）**：

```bash
gh pr create --base epic/coredesign-audit-remediation --head issue-101-api-shape \
  --title "公开 API 形态统一（#101）：B8b/B8e/B8f/B8g/D4/D5/D6a/D6b/D7" \
  --body "$(cat <<'EOF'
承载 9 个 API 形态审计项。全部 breaking change、直接改无兼容层，仓库内预览宿主 / docs / 下游 probe / 测试已同步。

## 变更
- B8e：ToastLevel + MessageLevel → 单一 StatusLevel
- B8b：Banner 两个 makeBody 抽公共 body-builder
- B8f：StateLabel / StatusRow 各 3 switch → 单个 @MainActor spec
- B8g：SegmentedControl 两处 glass overlay 抽共享构造
- D7：SegmentedControl glass:Bool → SegmentedControlStyle 四件套
- D4：7 处 public let 存储属性降 internal（CoreBorderlessButtonStyle.role 判定保留 public，probe 钉死）
- D5：ButtonRoleStyleRole/SurfaceKind/CoreMenuButtonStyle 协议补齐
- D6a/D6b：StateLabel/StatusRow/SidebarNavigationRow 补 @ViewBuilder designated init + String 便利 init（EventRow 既有形态已满足）

## 验证
- swift build / test（默认 + Blossom）四条全绿、零 warning
- xcodebuild test iOS Simulator（iPhone 17 Pro）绿（覆盖 iOS-only DynamicTypeLayoutTests）
- downstream-probe swift build 绿
- audit-checklist 计数仍 83 / 79

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 7: PR 评审（Copilot 不可用则降级）**

按项目 memory：PR 开出后即进 `auto-fix-pr-after-implementation`（拉 Copilot review → 改 → threaded reply）。**Copilot 不可用时降级**：用 `Agent`（`subagent_type: superpowers-reviewer`，focus=finishing，传 `BASE_SHA`=epic/coredesign-audit-remediation、`HEAD_SHA`=HEAD）做终审，并把结论作为 PR 顶层评论贴出。反馈按 `oh-my-superpowers:receiving-code-review` 处置（技术正确且重要→修；风格→列给用户；不同意→写明理由）。

---

## Self-Review

**1. Spec coverage**（Issue #101 九项逐一对账）：
- B8b → Task 4 ✅ · B8e → Task 1 ✅ · B8f → Task 5（StateLabel）+ Task 6（StatusRow）✅ · B8g → Task 8 commit1 ✅
- D4 → Task 3（5 组件）+ Task 5/6（StateLabel/StatusRow 随泛型化降 internal）✅ · D5 → Task 1（StatusLevel）+ Task 2（其余三）✅
- D6a → Task 5 ✅ · D6b → Task 5/6（StateLabel/StatusRow）+ Task 7（Sidebar；EventRow 结论）✅ · D7 → Task 8 commit2 ✅
- DoD：4 命令 + 第 5 条 + checklist + probe → Task 9 ✅

**2. Placeholder scan**：无 TBD/TODO；所有代码步给出完整 before/after；所有命令带预期输出。测试代码含 `@Test`/`#expect` 是合法测试代码（非注释污染）。

**3. Type consistency**：`StatusLevel`（Task 1 产出）→ Toast/Banner 消费一致；`spec`/`Spec` 在 StateLabel（`StateLabelStyle.spec`）与 StatusRow（`StatusResult.spec`）命名一致、均 `@MainActor`；`SegmentedControlStyleConfiguration.Segment(index:title:isSelected:)` 在 Task 8 的 style 实现、SwiftUI body、测试三处签名一致；`SidebarNavigationRow<Leading>` 便利 `where Leading == AnyView` 与测试 `type(of:) == SidebarNavigationRow<AnyView>.self` 一致。

---

## 写 plan 时发现的、主编排未点到的额外风险 / 依赖

1. **`ButtonRoleStyleRole` 加 `nonisolated` 会连累三个调色板属性 + `resolvedColor`**：它们读 MainActor 隔离的 token Color，必须逐个补 `@MainActor` 否则整个 D5 步骤编译失败。这是本任务里最容易被漏的隐性依赖（Task 2 Step 1 已写死）。

2. **B8f 的单 spec 只能是 `@MainActor`**：token Color 的 MainActor 隔离使「一个纯 `nonisolated` spec」不可行；把 `spec` 挂在枚举扩展上并标 `@MainActor`，消费点（body / 便利 init / `@MainActor` 测试）都在 MainActor 才成立。若实现者按直觉写 nonisolated spec 会炸。

3. **`SidebarComponentsTests.swift:26` 是主编排未提的第二个 iOS-无关破坏点**：`type(of: row) == SidebarNavigationRow.self` 在泛型化后非法，必须改 `<AnyView>`。它在 macOS `swift test`（第 2 条命令）就会炸，比 DynamicTypeLayoutTests 更早暴露。反倒是主编排担心的 `DynamicTypeLayoutTests.swift:39` 走保留的便利 init、`{}` 绑定 `action`，**预计不破**（Task 7 仍按 DoD 跑第 5 条命令并留了保底修法）。

4. **`CoreBorderlessButtonStyle.role` 不应降级**：审计清单 D4 把它列为"是否收回由 #10 判定"的第 8 处，但 `PublicVisibility.swift:26` 的 `_ = style.role` 从下游 probe 钉死了它（#94 A2b 契约）。降级 → probe 编译失败。故本任务判定**保留 public**，与主编排"7 处"口径一致，并在 checklist 里写清理由。

5. **`EventRow` 的 D6b 已满足**：它已是 `actor/action/timeAgo: String` + `@ViewBuilder pill = { EmptyView() }` 的双层 designated init，无需新增 `@ViewBuilder` slot——否则会平白造出第二个语义不清的 slot。本任务只对它做 D4。

6. **`SegmentedControl` D7 的类型擦除设计是最大不确定点**：把泛型 `Item` 收敛为「index + title + isSelected」的 `Segment`，让单一非泛型 `SegmentedControlStyleConfiguration` 能同时喂 iOS 原生 `UISegmentedControl`（`[String]` + index）与 SwiftUI 回退（按 index 重建 + `@Namespace` thumb）。`NativeGlassSegmentedControl` 随之由 `<Item>` 泛型改为 `[String]`+index 驱动（下层 `NativeGlassSegmentedControlView` / `ImmediateFeedbackSegmentedControl` 不动）。这是本任务代码量与回归风险最集中处，第 5 条命令是它的主要安全网（原生玻璃路径只在 iOS 编译）。

7. **`docs/superpowers/plans/*` 有大量历史命中**（grep `StateLabel(`/`StatusRow(`/`MessageLevel` 等），全部是归档计划文档，**一律不动**；只改 `docs/components/*.md`。越界自查（Task 9 Step 4）会兜底。

8. **Toast/Banner 的 App 调用点无需改**：它们用 `.info`/`.success`/`.warning`/`.danger` case 名（合并后仍在）、不显式写类型名，故 `App/Sources/{Previews,ComponentData}.swift` 的 banner/toast 段零改动——只有 docs 表格里显式写 `MessageLevel`/`ToastLevel` 类型名处要改。
