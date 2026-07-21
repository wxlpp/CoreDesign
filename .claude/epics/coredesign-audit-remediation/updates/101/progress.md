# Issue #101 公开 API 形态统一 — 完成记录

分支 `issue-101-api-shape`（base `epic/coredesign-audit-remediation`，已 merge 同步含 #99 的 epic）。承载 **9 项设计级 breaking**：B8b/B8e/B8f/B8g/D4/D5/D6a/D6b/D7。plan 经 2 轮评审 PASS，实现由 opus subagent 照 1712 行详细 plan 执行（10 commit），checkpoint 终审 PASS。

## 9 项做了什么

| 项 | 改动 |
|---|---|
| B8e | `ToastLevel` + `MessageLevel` 合并为 `StatusLevel`（新建 `Components/StatusLevel.swift`，`public nonisolated enum ... Sendable, Equatable`），全消费点同步（Toast/Banner/App/docs/probe） |
| D5 | 语义枚举协议一致化：`ButtonRoleStyleRole` 补 `nonisolated + Sendable, Equatable`（调色板成员保 `@MainActor` 读 token）；`SurfaceKind` 补 `Equatable`；`CoreMenuButtonStyle` 补 `Sendable, Equatable`（internal、非 breaking） |
| D4 | 7 处 `public let` 存储属性降 `internal`（ProgressBar/CommentCard/EventRow/TimelineItem/AvatarGroup + StateLabel/StatusRow）；`CoreBorderlessButtonStyle.role` **保 public**（probe `_ = style.role` 钉死，#94 A2b 契约） |
| B8b | Banner 两个 `makeBody` 抽公共 `bannerBody(configuration:bordered:)` |
| B8f | `StateLabel`（3 switch）/ `StatusRow`（3 switch）各收敛为单个 `@MainActor var spec`（token Color MainActor 隔离） |
| B8g | SegmentedControl 两处 glass overlay 抽 `segmentedGlassChrome(_:)` |
| D6a/D6b | `StateLabel`/`StatusRow` 泛型化双层形态（`@ViewBuilder` designated + String 便利 init，对齐 Badge/Tag）；`StateLabel` init 首参加标签（`init(style:)`）；`SidebarNavigationRow` 补 `@ViewBuilder leading`；`EventRow` D6b 已满足只做 D4 |
| D7 | SegmentedControl `glass: Bool` → `SegmentedControlStyle` 四件套（协议 + Configuration + `@Entry` + `View` 扩展，对齐 Banner），泛型 `Item` 收敛为 `Segment`（index/title/isSelected）非泛型 Configuration |

## 关键取舍（评审沉淀）

- **StatusLevel `nonisolated Sendable`**：保 `ToastItem` 跨 actor 传递承诺，probe `useStatusLevel` 守卫。
- **D4 降 internal 而非 private**：对齐 Badge 范例、不破坏 7 个白盒测试（`@testable` 可读 internal）、达成「不再公开、下游不能依赖内部布局」。
- **spec `@MainActor`**：token Color 在 `defaultIsolation(MainActor)` 下 MainActor 隔离，spec 返回 token 必须 @MainActor。
- **SegmentedControl 类型擦除**：私有 `SwiftUISegmentedControl`/`NativeGlassSegmentedControl` 作 `some View` 从 public makeBody 返回；`.padding(CoreSpacing.xxs)` inset 与 `.sensoryFeedback(.selection)` 评审补回（原实现 :74/:84，迁移曾漏）。
- **StateLabel/StatusRow 的 leading Image `.accessibilityHidden(true)`**：泛型化改 `.combine` 后防 SF Symbol 名泄漏进 VoiceOver name（对齐 Banner）。

## 验证（全独立复核，非仅信 subagent）

- 四条 SwiftPM 命令 clean 冷跑全 **EXIT=0**，两侧 **95 tests / 30 suites**（原 96：StateLabel 7→5、SegmentedControl 3→4），**warning 全 0**。
- 下游 probe `swift build` EXIT=0（D5 `compareButtonRole` 守卫 + `useStatusLevel` + `_ = style.role`）。
- **第 5 条 iOS Simulator**（带 CI skip 列表 `-skip BlossomAssetTests/ToastHostTests`）：**TEST SUCCEEDED**——D6b 的 `SidebarNavigationRow<AnyView>` 布局断言、D7 的 iOS 原生 SegmentedControl 路径、#98 的 BlossomColorDivergence 平台自适应全过。（不带 skip 时 BlossomAssetTests 的 24 失败是 #98 记录的 Assets.car 坑、base 也有、与 #101 无关；CI iOS job 已 skip 它。）
- 越界自查 `rc=1`（改动只在 Sources/App/docs·components/scripts·downstream-probe/Tests/.claude）；audit-checklist 9 项标 ✅、计数 **83 / 79** 未漂移。
- 编辑期 SourceKit 诊断经确认是 **stale**（`build --build-tests` EXIT=0、0 error，反映 subagent 逐 task「测试先改红→Sources 后改绿」的中间态）。

## checkpoint 三个 Suggestion（非阻塞，列给用户 accept-or-improve）

- **S1（coverage 收窄）**：`StateLabel`/`StatusRow` 泛型化后 label 是 `Text`（不暴露字符串），便利 init 的 payload wiring（`Text(label ?? spec.defaultLabel)`）现无运行时测试——若回归忽略 passed label 会 pass CI。plan 已预批准（Text 擦除固有）；补测需 ViewInspector（Out of Scope）或提取 label 解析 helper。**接受或后续补强，请用户定。**
- **S2（视觉冒烟，运行时不可自动测）**：D7 把 `@Namespace` 移进 child `SwiftUISegmentedControl` 且整个 body 包 `AnyView`。thumb 的 `matchedGeometryEffect` slide 动画（macOS + iOS-Plain 路径）在 AnyView 边界内，应存活但可能静默退化成 snap。**建议视觉复核：macOS 默认 + `.segmentedControlStyle(PlainSegmentedControlStyle())` 下确认 thumb 滑动而非跳变；并抽查 B8g 描边 z-order（从 above-content 移到 behind-content）。**
- **S3（minor）**：`plainStyleOptsOutOfGlass` 现为纯编译检查（`_ = styled`），`builtInStylesProduceBody` 部分补偿运行时。

## 给下游的交接

- **#100（本地化）现可开始**：本任务已完成 `CoreMenuButton` / `Toast` 的 API 形态统一（`StatusLevel` 合并触及 Toast），#100 的 `depends_on: [101]` 满足。
- **#102（机械清理）**：与本任务多个共享文件，须在其后。
