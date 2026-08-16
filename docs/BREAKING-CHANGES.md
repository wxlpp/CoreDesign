# Breaking Changes

破坏性变更按版本 / Issue 记录在此，下游升级前请对照。

> 已发布的 git tag：`v0.1.0`（2026-07-19）、`v0.2.0`（2026-07-21）、`v0.3.0`（2026-07-23）、
> `v0.4.0`（2026-07-24，Phase 2 新组件）、`v0.4.1`（2026-07-24，非破坏性收尾）、
> `v0.5.0`（2026-07-24，文本入参统一——含破坏性变更）、
> `v0.6.0`（2026-07-25，Separator.Inset 改名 + ProgressBar 弃用 + SettingsRowMetrics 公开——含破坏性变更）、
> `v0.7.0`（2026-07-26，`semi-mobile-components` epic 10 新组件 + ProgressIndicator 增强/spinning + 收口的取色修正——纯新增，无破坏性变更）、
> `v0.8.0`（2026-08-16，`component-contract` epic：把 5 组压扁成 Bool 的 API 还原成语义类型——**含破坏性变更**）。
> 本文件早期版本曾写「本库当前无外部版本 tag」——那在 `v0.1.0` 之前成立，之后未同步，已更正。

## `0.8.0`（`component-contract` epic 试点改造，2026-08-16）

**含破坏性变更** —— 删除 **9 条 public 声明**（归为 5 组），另有 1 处「加枚举 case 但可能打断下游构建」。
本节的清单**不是凭 diff 印象写的**：由脚本从 `v0.7.0` 与发布 commit 的源码各提取一次 public
表面后做集合差得出（public 声明 642 → 652，public enum case 60 → 63），脚本全文见
`oh-my-story` 仓 `.claude/epics/component-contract/42-spec.md` 的附录。

> **为什么是一次 minor 而不是 1.0.0**：本库 0.x 阶段以 minor 携带破坏性变更，`v0.5.0`
> （文本入参统一）、`v0.6.0`（`Separator.Inset` 改名）已有两次先例，见下方各节。

### 主题：把「压扁成 Bool 的取值域」还原成语义类型

本次 5 组破坏性变更同源——它们都是把一个 `Bool` 参数还原成它真正表达的东西：
语义枚举、连续量、或干脆是两个不同的组件。判定依据是本 epic 产出的组件公约
（`docs/component-contract.md`）第 3 节的四条替代路径。

---

#### B1. `View.surface(_:bordered:)` → 删除 `bordered` 参数

```swift
// 变更前
func surface(_ kind: SurfaceKind, bordered: Bool = true) -> some View
// 变更后
func surface(_ kind: SurfaceKind) -> some View
```

**迁移**：`bordered: false` 表达的其实是「换一种容器角色」，改用新增的 `SurfaceKind.grouped`：

```swift
// 旧
.surface(.content, bordered: false)
.surface(.content, bordered: true)     // 或省略
// 新
.surface(.grouped)                     // 背景 + 圆角、无描边，等价于原 bordered: false
.surface(.content)                     // 背景 + 描边 + 圆角，等价于原 bordered: true
```

⚠️ `.grouped` 与原 `.content, bordered: false` **三个维度逐字等价**（背景 `surfaceCard`、
描边 `.clear`、圆角 `CoreRadius.medium`），视觉无变化。

⚠️ **但等价只在 `.content` 上成立**：`bordered` 是与全部 9 个 kind 正交的参数，
`.surface(.overlay, bordered: false)` / `.surface(.card, bordered: false)` 这类组合
**在新 API 下没有等价替代**。之所以只补 `.grouped` 一个 case 而不铺满 9×2 的积空间：
仓内实测 **7 处调用点 100% 落在 `.content` 上**，按用到的点建模、不按可能的组合建模。
若你在用其他 kind 的无描边组合，请提 issue——那会是一个新的容器角色，需要单独命名。

#### B2. `Card(bordered:)` → `Card(kind:)`

```swift
// 变更前
public init(padding: CGFloat = CoreSpacing.lg, alignment: Alignment = .leading,
            bordered: Bool = true, @ViewBuilder content: () -> Content)
// 变更后
public init(padding: CGFloat = CoreSpacing.lg, alignment: Alignment = .leading,
            kind: CardKind = .content, @ViewBuilder content: () -> Content)
```

**迁移**：

```swift
Card(bordered: false) { … }   →   Card(kind: .grouped) { … }
Card(bordered: true)  { … }   →   Card() { … }
```

⚠️ **`CardKind` 只有 `.content` / `.grouped` 两个 case，刻意不暴露完整 `SurfaceKind`**——
`Card` 是 `.content` 的薄封装，开放 `.canvas` / `.sidebar` 会把它拓宽成万能容器，
且 `Card(kind: .canvas)` 正是 Issue #140「卡片贴画布导致隐形」的形态。

#### B3 / B4. `SolidButtonStyle` 与 `LightButtonStyle` 删除 `glass` 开关

各删 3 条声明（存储属性 + init 参数 + 静态工厂参数）：

```swift
// 变更前
public init(role: ButtonRoleStyleRole = .primary, glass: Bool = false)
public let glass: Bool
static func solid(role: ButtonRoleStyleRole = .primary, glass: Bool = false) -> SolidButtonStyle
static func light(role: ButtonRoleStyleRole = .primary, glass: Bool = false) -> LightButtonStyle
// 变更后
public init(role: ButtonRoleStyleRole = .primary)
static func solid(role: ButtonRoleStyleRole = .primary) -> SolidButtonStyle
static func light(role: ButtonRoleStyleRole = .primary) -> LightButtonStyle
```

**迁移**：

```swift
// glass: false（默认值）——纯删参，行为完全不变
.buttonStyle(.solid(role: .primary, glass: false))   →  .buttonStyle(.solid(role: .primary))
.buttonStyle(.light(role: .secondary, glass: false)) →  .buttonStyle(.light(role: .secondary))
```

⚠️ **`glass: true` 没有行为保持的替代写法，别做机械替换。**
删掉的是 legacy Telegram 玻璃模式：它的渲染是 **Capsule 形状 + 宽度随 label 伸展 +
玻璃底色取 role 色**（`backgroundStyle(backgroundColor)`）。

本仓保留的 `CircularGlassButtonStyle` 虽然也是玻璃观感，但**三处都不一样**：
**Circle 形状 + 固定直径 frame**（`.large` 默认 50pt）+ **底色固定 `surfaceInteractive`
（role 色不携带）**。⇒ 把一个带文字 label 的 capsule 玻璃按钮直接换成它，会被压进一个圆里
并丢掉 role 配色——**它只适用于圆形 icon 按钮，不是 `glass: true` 的等价物**。

若你确实在用 `glass: true`：请按实际需要选择（a）改用普通 `.solid` / `.light`（放弃玻璃观感）、
（b）圆形 icon 场景改用 `CircularGlassButtonStyle`、或（c）自建 style 复用
`TelegramGlassButtonModifier`（仍是 public 且未改动）。

> 本仓跨仓复核确认 `glass:` **对外零调用点**（预览宿主、downstream-probe、StoryUI 全仓
> 零命中），所以本条预计不影响任何已知下游——写在这里是给未知使用者的。

⚠️ 这是**唯一一组走「论证删除」而非「记豁免」的变更**：公约第 3 节的终局条款有序——
先试 (b) 论证删除、(b) 不成立才用 (a) 记豁免。跨仓复核确认 `glass:` **对外零调用点**
（预览宿主、downstream-probe、StoryUI 全仓零命中），(b) 成立。

#### B5. `Rating(allowsHalfStar:isReadOnly:)` → `Rating(step:)` + 新组件 `RatingDisplay`

```swift
// 变更前
public init(value: Binding<Double>, count: Int = 5,
            allowsHalfStar: Bool = false, isReadOnly: Bool = false)
// 变更后
public init(value: Binding<Double>, count: Int = 5, step: Double = 1.0)
```

**迁移（两条，分别对应两个被删参数）**：

```swift
// ① allowsHalfStar → step：Bool 其实是被压扁的连续量（原实现内部就是 allowsHalfStar ? 0.5 : 1.0）
Rating(value: $v, allowsHalfStar: true)   →  Rating(value: $v, step: 0.5)
Rating(value: $v, allowsHalfStar: false)  →  Rating(value: $v)          // step 默认 1.0
Rating(value: $v, step: 0.25)             // 新能力：任意步进粒度，不再只有两档

// ② isReadOnly → 换组件（⚠️ 不是 .disabled(true)，见下）
Rating(value: .constant(4), isReadOnly: true)  →  RatingDisplay(value: 4)
```

⚠️ **`isReadOnly: true` 的迁移目标是 `RatingDisplay`，不是 `.disabled(true)`。**
`.disabled(true)` 走的是 SwiftUI 原生 disabled 视觉——**变灰 + 降对比度**，语义是
「这个控件现在不能用」；而只读评分的典型用途是**展示态**（列表里显示某本书的评分），
它不是「不能用」，是「本来就不是控件」。用 `.disabled(true)` 迁移会让所有展示态评分变灰，
是语义错配导致的视觉回归。拆成两个类型之后，「控制展示态」只剩一条路径：**选哪个类型**。

⚠️ `step` 的入参校验走 clamp 不 trap：`step <= 0` 或非有限值（如 `.infinity`）会被
clamp 回 `1.0`，不会崩溃。

---

### ⚠️ 非删除、但可能打断下游构建：`SurfaceKind` 新增 `.grouped`

```swift
public nonisolated enum SurfaceKind: Sendable, Equatable {
    case canvas
    case content
    case control
    case floating
    case overlay
    case grouped        // ← 本版本新增（声明位置在 overlay 与 canvasSubtle 之间）
    case canvasSubtle
    case panel
    case sidebar
    case card
}
```

`SurfaceKind` 是 public、非 `@frozen` 的 enum，且 CoreDesign 以 SwiftPM 源码分发、
**不开 library evolution** ⇒ **下游若对它做穷尽 `switch`，加一个 case 就编译不过**
（`switch must be exhaustive`）。

**迁移**：给这类 `switch` 补 `default:` 或 `case .grouped:` 分支。

> 之所以把它单列而不是塞进「新增」段落：它是本次唯一一个**不在删除清单里、却可能打断
> 下游构建**的变更。本仓自查 `scripts/downstream-probe` 对 `SurfaceKind` 是透传、无穷尽
> switch，故 CI 不会因此变红——但下游第三方使用者不受此保护。

### 新增（非破坏性）

- **`CardKind`** —— `Card` 的容器观感取值域（`.content` / `.grouped`）。
- **`RatingDisplay`** —— 只读评分展示组件（indicator）：`RatingDisplay(value:count:)`，
  无 binding、无手势、无 accessibility adjust action。
- **`RatingStyle` 样式扩展点** —— `RatingStyle` 协议 + `RatingStyleConfiguration` +
  `StarRatingStyle`（默认实现）+ `View.ratingStyle(_:)`，形态与既有 `BannerStyle` 一致。
  `Rating` 与 `RatingDisplay` 共用同一个扩展点。
  ⚠️ **`RatingStyleConfiguration` 没有 public init**（与 Apple 的 `ButtonStyleConfiguration`
  一致）——下游自定义 style 时无法自造 configuration 做预览/单测，只能经 `Rating` /
  `RatingDisplay` 渲染触发。

### 本次无 B 类变更（文本参数 → `LocalizedStringResource`）

本版本**没有任何裸 `String` 文本参数转 `LocalizedStringResource`**，故不涉及
`Bundle.main` 解析语义的变化。两条证据：

1. FR-4 判据的四条计数全程未变（`registryTextParams == 30` / `covered == 29` /
   `localizedByType == 11` / `carrying == 8`）；
2. ⚠️ 计数不变只约束**基数**不约束**集合**（一进一出会全部不动），故另有 diff 级证据：
   `v0.7.0..HEAD` 的 `Sources/` 全量 diff 中**零文本参数签名变更、零 `LocalizedStringResource`
   增删**；新增的 `RatingDisplay.init(value:count:)` 不带文本参数。

## `0.7.0` 收口部分（`semi-mobile-components` 收尾，**已随 v0.7.0 发布**）

> 这一节曾标为「`0.7.1`（未发布）」。实际情况是：`v0.7.0` 的 tag 打在了 `9df7b68`，
> 而 `9df7b68` **正是引入下面这些改动的那个 commit**——所以它们已经在 `v0.7.0` 里了，
> 从来没有单独的 0.7.1。之所以标错，是因为发 `v0.7.0` 时跳过了本仓一贯的
> 「docs(release): X 定稿」步骤（对照 `v0.6.0` 的 `eab5ecc`），文档没来得及去掉「未发布」。
> 下游读 `v0.7.0` 的 release notes 时不要以为这些修正不在自己的构建里。

**非破坏性** —— 仅取色语义修正与测试补充，无 API 变更，对下游零破坏。

- **`CheckBox` / `Radio` 未选中态取色**（Issue #189）：从硬编码 `Color.gray`（`systemGray`，固定不透明）改为语义 token `Color.contentSecondary`（桥接系统 `.secondaryLabel`）。`CheckBox` 自 `v0.1.0` 发布，本次一并对齐（两组件文档均声明「同一套 token」，只改其一会造成成对组件视觉分叉）。观感变化：纯色背景下肉眼几乎不可辨；在 raised/tinted 背景上因 `.secondaryLabel` 的半透明特性会有轻微原生混色，并新增 Increase Contrast 无障碍适配——属修正硬编码色、非破坏。
- **`DynamicTypeLayoutTests` 补 Rating/Radio/TagInput/Timeline 大字号断言**（Issue #188）：仅测试新增。

## `0.7.0`（`semi-mobile-components` epic 收尾，2026-07-26）

**非破坏性** —— 全部为纯新增，无删除/改名/签名变更，对下游零破坏，无需迁移。

### 新增组件（10 个，`semi-mobile-components` epic Phase 1，Issue #162–#171）

| 组件 | 说明 | 文档 |
|---|---|---|
| `Skeleton` / `SkeletonLine` / `SkeletonRect` / `SkeletonCircle` + `View.skeletonShimmer()` | 骨架屏容器 + 占位形状 + shimmer 扫光 modifier | [skeleton.md](components/skeleton.md) |
| `Steps` / `StepItem` / `StepsAxis` / `StepsIndicatorStyle` | 横向 / 纵向步骤条，点状 / 数字两种指示器 | [steps.md](components/steps.md) |
| `Timeline` / `TimelineItem` | 纵向时间线，默认圆点或自定义节点 | [timeline.md](components/timeline.md) |
| `Rating` | `Binding<Double>` 星级评分，支持半星步进 + 只读 | [rating.md](components/rating.md) |
| `PinCode` | 验证码 / PIN 分格输入，隐藏 `TextField` 承接系统键盘 | [pin-code.md](components/pin-code.md) |
| `RadioGroup` / `RadioOption` | 互斥单选组，与 `CheckBox` 成对的视觉语汇 | [radio.md](components/radio.md) |
| `TagInput` | 标签输入框：`Tag` chip + 内联 `TextField` | [tag-input.md](components/tag-input.md) |
| `Descriptions` / `DescriptionsColumns` / `DescriptionsDividerDensity` | 描述列表：`.core LabeledContentStyle` + `InsetGroupedSection`，1/2 列 + 大字号自动塌列 | [descriptions.md](components/descriptions.md) |
| `ExtendedFloatButtonStyle` + `.extendedFloat` / `.extendedFloat(size:)` | 胶囊玻璃悬浮按钮样式（与既有 `CircularGlassButtonStyle` 并列） | [float-button.md](components/float-button.md) |
| `Carousel` | 走马灯：`ScrollView` 分页滚动 + 自动轮播 + 页点指示器 | [carousel.md](components/carousel.md) |

### 增强（Issue #172）

- `ProgressIndicator` 新增 `init(text: LocalizedStringKey)` 与 `init<S: StringProtocol>(text: S)`——可选文案渲染于 spinner 下方；原 `init()` 签名不变（NFR-6 无破坏）。带文案时 accessibility label 播报文案本身而非固定 `"Loading"`（收口修复，见下）。
- `SpinningModifier` + `View.spinning(_:text:)`——为任意内容整体叠加加载遮罩（吸收 Semi Design `Spin` 能力）。

### Typography 墓碑

`Typography`（PRD 原 12 组件候选之一）判定 parity 已由 `.coreFont(_:)` + 原生 `Text` modifier 达成，
不作为独立组件实现，见 [typography.md](components/typography.md)。

### Phase 1 评审累积收口项（Phase 3 / #173 统一处理）

- `Radio` 单选圆点 SF Symbol 从遗留名 `largecircle.fill.circle` 改为推荐名 `circle.inset.filled`。
- `TagInput` 的 `"Add tag"` Phase 0 预登记键确认为死键（组件 verbatim 消费 placeholder，仿 `SearchField` 先例），已从 `Localizable.strings` 移除。
- `FloatButton`（`CircularGlassButtonStyle` / `ExtendedFloatButtonStyle`）新增 `\.isEnabled` 禁用视觉（此前禁用态与启用态渲染无区别）；`ExtendedFloatButtonStyle` 胶囊横向 padding 改随 `size` 档位缩放（`CoreControlMetrics.horizontalPadding(for:)`），不再固定 `CoreSpacing.lg`。
- `ProgressIndicator` 带文案时的 accessibility label 改播报文案本身（`self.text ?? Text("Loading", bundle: .module)`），此前恒播 `"Loading"`。
- `spinning` 遮罩改用 `ContainerRelativeShape()` 替代 `Rectangle()`，避免直角材质溢出圆角内容轮廓。
- `PinCode` 隐藏承接输入的 `TextField` 补 `.fixedSize()`——此前在某些外层宽度大于格子行实际宽度的场景下（如宿主画廊详情页）会撑满可用宽度，导致其 0.01 透明度的文字内容露出到格子行左侧边界之外（Phase 3 视觉复查发现，截图可见「重影」，非本次改动引入，已一并修复）。
- 各组件 `docs/components/*.md` 结尾「运行 `run-snapshots.sh` 生成于 `docs/snapshots`」的样板措辞统一订正——与 `phase0-decisions.md` §3 的实际生成路径（默认模式依赖 `App/Sources/Previews.swift` 注册；组件自带 `#Preview` 走 `KEEP_LIBRARY_SNAPSHOTS=1` 到本地 scratch 目录）对齐（本 PR 共订正 32 个 `docs/components/*.md`，含既有组件）。
- `ToastHostTests` 时序 flaky 修复：`.serialized` trait + buffer 从 0.3–0.5s 放宽到 0.8–1.2s（`Suite` 与整套测试并跑时的调度抖动会吃掉窄余量）。
- Steps/Timeline 连线宽度对 phase0-decisions「hairline」的有意偏离（`Timeline` 取 `CoreBorderWidth.thin`、`Steps` 横向连线取 `.thick`）在各自源文件 doc comment 中已有记录，本次未额外改动。
- `%lld steps` 复数摘要键（Phase 0 预登记）裁决**不消费**——已在 `Steps.swift` doc comment 中记录理由（每步已有「N of M」位置播报，容器层再插入总览摘要需要重新设计 accessibility 树分层，收益与改动面不成比例）；键保留在 `.stringsdict` 供未来复用。

## `0.6.0`（收尾攒项 2/5/8，2026-07-25）

### 签名变更（source-breaking）

| 组件 | 旧 | 新（`0.6.0`） |
|---|---|---|
| `Separator.Inset` | `case none`（贯穿） | `case edgeToEdge`（贯穿） |

**迁移**：`Separator(inset: .none)` → `Separator(inset: .edgeToEdge)`；`init` 默认值同步改为 `.edgeToEdge`。**理由**：`.none` 与 `Optional.none` 同名，调用方持有 `Inset?` 时写 `.none` 会静默解析成 `Optional.none`（编译器仅在部分位置告警）——改名消除该遮蔽。

### 弃用（source-compatible，带警告）

| 符号 | 替代 |
|---|---|
| `ProgressBar`（`@available(*, deprecated)`） | 系统 `ProgressView(value:).progressViewStyle(.core)`——`.core` **响应环境 `.tint`**、走系统控件（`ProgressBar` 有意拒绝环境 tint）。见 [components/core-control-styles.md](components/core-control-styles.md)。`ProgressBar` 保留至下游迁移完成后移除 |

### 新增（非破坏）

- `SettingsRowMetrics` 从 `internal` 改为 **`public`**——让调用方把自定义行/内容对齐到 `SettingsRow` 的网格（图标列宽 `iconSquareSize`、分隔线 inset `iconAlignedDividerInset` / `textAlignedDividerInset` 等），不必抄魔数（SC#10「不写 CoreDesign 之外样式代码」对自定义行的支撑）。

## `0.5.0`（文本入参统一，2026-07-24）

**破坏性** —— `SettingsRow` 的文本入参从 `Text` 改为 `LocalizedStringKey` / `StringProtocol`，与库内 `SectionHeader` / `SectionFooter` / `AsyncButton` 的入参形态统一。

### 签名变更（source-breaking）

| 组件 | 旧（`0.4.x`） | 新（`0.5.0`） |
|---|---|---|
| `SettingsRow`（带 accessory） | `init(icon:, title: Text, subtitle: Text? = nil, accessory:)` | `init(icon:, title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil, accessory:)` + `@_disfavoredOverload init<S: StringProtocol>(...)` |
| `SettingsRow`（无 accessory 便利 init，`Accessory == EmptyView`） | `init(icon:, title: Text, subtitle: Text? = nil)` | `init(icon:, title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil)` + `@_disfavoredOverload init<S: StringProtocol>(...)` |

**迁移**：把 `SettingsRow(title: Text("Wi-Fi"))` 改为 `SettingsRow(title: "Wi-Fi")`；副标题同理。**字面量**走 `LocalizedStringKey`（`Bundle.main` 本地化——`StringProtocol` 重载带 `@_disfavoredOverload`，与 SwiftUI `Text` 同款做法，保证字面量不落到 verbatim 泛型重载）；**运行期字符串**走 `StringProtocol` 重载（verbatim）。**注意**：`title` 与 `subtitle` 类型须一致——混用字面量 title + 运行期字符串 subtitle 时，两者会一起落到 `StringProtocol` 重载、字面量 title 也按 verbatim 处理（不本地化）。**代价**：不再能直接传样式化 `Text`（如 `Text("x").bold()`）——如需样式化标题，用系统 `.font` / attributed string 于 accessory，或按需在库层再引入 `titleView:` 形态。

### 新增（非破坏，随本次一并）

- `InsetGroupedSection` 的 `header` / `footer` 补 `StringProtocol` 重载——此前只收 `LocalizedStringKey`，运行期字符串传不进；现与 `SettingsRow` / Section 组件对齐。现有 `header: "General"` 字面量调用不变。

## `0.3.0`（epic coredesign-native-foundation，2026-07-21 ~ 2026-07-23）

把 token 地基从 GitHub Primer 换成 Apple HIG。取值理由见
[`docs/DESIGN-FOUNDATION.md`](DESIGN-FOUNDATION.md)。这是一次**破坏面很大**的改造：
6 个组件删除、`Blossom` trait 删除、`CoreGradient` 删除、9 个字体 token 改名、
圆角与控件尺寸档位换值、大量语义色改指系统色。本条目定稿时库自 `0.2.0` 升往 `0.3.0`；
库处于 `1.0` 之前，接受破坏性变更，但要求完整记录。

> **下游升级路径**：本次改造分两个版本发布——`0.3.0`（本条目，地基）与 `0.4.0`
> （新组件，`InsetGroupedSection` / `SettingsRow` / `Card` / `Separator` /
> `SectionHeader` / `SectionFooter` 等，另立 epic 交付）。若不急于跟进 `0.3.0`，
> **可直接从 `0.2.0` 跳到 `0.4.0`**，届时以本条目与 `0.4.0` 条目的并集为准。凡本条目中
> 标注"无直接替代"的删除项，下游都应先确认 `0.4.0` 是否提供了可组合出等价效果的
> 通用容器，而不是假定永久没有替代路径。

### 删除的公开符号

| 删除 | 来源 | 替代 |
|---|---|---|
| `BookCover` / `RefPill` / `StatusRow` / `EventRow` / `CommentCard` / `TimelineItem`（6 个组件） | #117 | **无直接替代**——它们服务于「GitHub Issue 时间线」这一具体场景，在通用设计系统里被判定为死重而非迁移目标。若下游依赖，需按各自场景用 SwiftUI 原生组件重建；`0.4.0` **已提供**的 `Card` / `InsetGroupedSection` / `SettingsRow` 等通用容器可作为重建时的基础构件，但**不是**这 6 个组件的直接替代品（Phase 1 已裁决：通用容器 ≠ GitHub 时间线场景组件的等价物） |
| `StatusResult`（枚举，`StatusRow.swift` 内） | #117 | 随 `StatusRow` 一并删除，无独立替代。注意 `StatusLevel`（`Banner` / `Toast` 的公开参数类型）**保留**，未受影响，不要混淆两者 |
| `timelineDepth`（`EnvironmentValues` 入口） | #117 | **从未 `public`，对下游无影响**——`@Entry` 不继承 public 访问级别（本库对此有惯例：`Toast.swift` 的 `toastHost` 显式写了 `@Entry public var`，而 `segmentedControlStyle` / `bannerStyle` 与本条一样是 internal）。列在此处仅为完整记录随 `TimelineItem` 一并消失的符号，**不构成破坏性变更** |
| `Blossom` package trait | #118 | **无替代**。下游若在 `Package.swift` 里写 `.package(url: "...", traits: ["Blossom"])`，升级后会在**依赖解析期**报 unknown-trait 错误——报错发生在 SwiftPM manifest 解析层，**不是编译错误**，下游不一定能第一时间把这个报错与本次升级关联起来，请特别注意。若需要强调色主题化，改用宿主 App 自己的 `AccentColor` 资源（见下方「改名的 token」表外的语义色变更） |
| `CoreGradient.brand` / `.cta` / `.canvas` | #118 | `brand` / `cta` → `Color.accent`；`canvas` → `Color.surfaceCanvas`。三者此前都是 `AnyShapeStyle`，默认主题下本就退化为对应纯色，替换后视觉不变 |
| `CoreRadius.smallPlus`（4pt，删除前库内零调用点） | #119 / #121 | 就近改用 `CoreRadius.small`（6pt） |
| `CoreRadius.mediumPlus`（8pt，删除前唯一调用点 `Sidebar.swift:157,411`） | #119 / #121 | 库内实际迁移选择改用 `CoreRadius.medium`（10pt）；若下游场景确实需要介于 `small`(6) 与 `large`(16) 之间的中间档，参考同一选择 |
| `CoreControlMetrics.primerVerticalPadding(for:)` | #119 / #121 | `CoreControlMetrics.verticalPadding(for:)`——原 escape hatch 是为了精确命中 Primer 的非 `CoreSpacing` 档位（6/10/14pt），新标度下不再需要 |
| `CoreTypography` 的全部 `*LineSpacing` / `*Tracking` 静态量（如 `bodyMediumLineSpacing` / `bodyMediumTracking`，每个旧尺寸档位各一对） | #119 | **无需替代**——新实现直接取系统 `Font.TextStyle`，行高与字距由系统决定，调用方不应再手动施加这两项 |
| `CoreTypography.Spec.scales` 开关、`Token.fixedFont` | #119 | 无替代——旧的"是否随 Dynamic Type 缩放"开关被删除，新 12 档 token 全部缩放，没有不缩放的例外 |
| `CoreTypography` 的 10 个旧 `*Font` static var：`displayLargeFont` / `titleLargeFont` / `titleMediumFont` / `titleSmallFont` / `subtitleFont` / `bodyLargeFont` / `bodyMediumFont` / `bodySmallFont` / `captionFont` / `captionSmallFont` | #119 / #121 | 改用 `.coreFont(_:)` + 对应新 `Token`（见下方改名表），如 `.coreFont(.largeTitle)`。**注意这是一次静默行为变化**：旧 `*Font` 是 `.system(size:)` 固定字号，不随 Dynamic Type 缩放；新 token 必然缩放 |

### 改名的 token

`CoreTypography.Token` 9 个改名档位，映射逐字沿用 `.claude/epics/coredesign-native-foundation/119.md` 定案（不做二次判断）：

| 旧名 | 新名 |
|---|---|
| `displayLarge` | `largeTitle` |
| `titleLarge` | `title` |
| `titleMedium` | `title2` |
| `subtitle` | `title3` |
| `titleSmall` | `headline` |
| `bodyLarge` | `body` |
| `bodyMedium` | `callout` |
| `bodySmall` | `footnote` |
| `captionSmall` | `caption2` |

> **`caption` / `captionMono` 名字未变，但语义变了**（同名换语义，不产生 deprecation warning，编译器与 grep 都发现不了）：旧版本是 Primer 手写字号表的固定档位，新版本直接映射系统 `.caption` 文本样式（`captionMono` 额外指定等宽 design）。下游若有代码依赖旧 `caption` 的具体字号/行高数值，需要重新核对。
>
> **`subheadline` 是净新增**——对应系统 `.subheadline` 文本样式，Primer 标度里没有对应档位，无旧名可改。

### 同名换值（探针对此系统性失明，逐点列出）

这一类变化**编译器不报错、不产生 warning、grep 找不到、测试不变红**——调用点静默继承新值。下游升级后只会表现为"界面看着不太对"而无从定位，请对照下表逐点确认。

> **本库的 `scripts/downstream-probe`（CI 的 Downstream API probe job）对本节系统性失明**，
> 不要以它跑通为"同名换值已确认无影响"的证据。该探针只能发现**删除的符号**（下游引用会
> 编译失败）与**改名的符号**（下游用旧名会编译失败），因为它验证的是"下游代码能否编译"；
> 而同名换值不改变符号名、不改变类型签名，探针照样编译通过——它验证不了"这个值变了、
> 是否仍然符合下游的视觉预期"这件事。本节的逐点旧值 → 新值对照表是唯一权威来源。

#### `CoreRadius`

| 档位 | 旧值 | 新值 | 备注 |
|---|---|---|---|
| `none` | 0 | 0 | 未变 |
| `small` | 3pt | **6pt** | 新 `small` 恰好等于旧 `medium`——风险最集中的一档 |
| `medium` | 6pt | **10pt** | |
| `large` | 12pt | **16pt** | |
| `xLarge` | *(不存在)* | 22pt | 新增档位，非换值 |

#### `CoreControlMetrics.height(for:)`

| `ControlSize` | 旧值 | 新值 |
|---|---|---|
| `.mini` | 24pt | **28pt** |
| `.small` | 28pt | **32pt** |
| `.regular` | 32pt | **44pt** |
| `.large` | 40pt | **50pt** |
| `.extraLarge` | 48pt | **56pt** |

#### `CoreControlMetrics.horizontalPadding(for:)`

| `ControlSize` | 旧值 | 新值 |
|---|---|---|
| `.mini` | 8pt | 8pt（未变） |
| `.small` | 12pt | 12pt（未变） |
| `.regular` | 12pt | **16pt** |
| `.large` | 12pt | **16pt** |
| `.extraLarge` | 12pt | **24pt** |

#### `CoreControlMetrics.verticalPadding(for:)`

| `ControlSize` | 旧值 | 新值 |
|---|---|---|
| `.mini` | 2pt | **4pt** |
| `.small` | 4pt | 4pt（未变） |
| `.regular` | 8pt | **12pt** |
| `.large` | 12pt | **16pt** |
| `.extraLarge` | 16pt | 16pt（未变） |

#### 语义色指向变更

| Token | 旧实现 | 新实现 |
|---|---|---|
| `Color.accent` | `Color.brand5`（CoreDesign 固定品牌蓝） | `Color.accentColor`（跟随宿主 App 的 `AccentColor` 资源） |
| `Color.accentHover` | `Color.brand6`（固定色阶） | `accent.mix(with: .primary, by: 0.15)`（对宿主 accent 动态调制） |
| `Color.accentPressed` | `Color.brand7`（固定色阶） | `accent.mix(with: .primary, by: 0.25)` |
| `Color.accentDisabled` | `Color.brand2`（固定色阶） | `accent.opacity(0.35)` |
| `Color.accentSubtleBackground` | `Color.brand1`（固定色阶） | `accent.opacity(0.12)` |
| `Color.selectionBackgroundEmphasis` | 借道 `accentDisabled`（= `brand2`，淡色块） | 实心 `accent` |
| `Color.borderFocus` / `Color.borderSelected` | `Color.accent`（即固定色阶 `brand5` 品牌蓝）——**注意它们在 `0.2.0` 就已指向 `accent`**，独立蓝色 colorset 是更早的 Issue #93 删的，不是本次 | `Color.accent`（指向不变，但 `accent` 本身改指宿主 `AccentColor`，故实际取值随之变化——见上一行） |
| `Color.surfaceCanvas` / `Color.surfaceGrouped` | 自有 `canvas-default` colorset（light `#FCFBF7` / dark `#11110F`） | `Color.systemGroupedBackground` |
| `Color.surfaceCanvasSubtle` | 自有 `canvas-subtle` colorset（light `#F3F0EA` / dark `#1A1916`） | `Color.secondarySystemGroupedBackground` |
| `Color.surfaceCanvasInset` / `Color.surfaceInteractive` | 自有 `canvas-inset` colorset（light `#F8F5EF` / dark `#0F0F0D`，不透明） | `Color.tertiaryFill`（系统填充色，半透明叠加语义） |
| `Color.surfaceRaised` | `.secondarySystemBackground`（plain 系统背景族） | `.secondarySystemGroupedBackground`（grouped 族，与 `surfaceCanvas` 同族） |
| `Color.surfaceElevated` | `.tertiarySystemBackground`（plain） | `.tertiarySystemGroupedBackground`（grouped） |
| `Color.systemGroupedBackground`（**仅 macOS**） | AppKit 降级 `.controlBackgroundColor` | AppKit 降级 `.windowBackgroundColor`——此前与 `secondarySystemGroupedBackground` 同色，画布与 raised 层在 macOS 上完全无法区分，本次修正为可辨的两档 |
| `status-accent-subtle` / `status-success-subtle` / `status-attention-subtle` / `status-danger-subtle` / `status-done-subtle`（**仅深色模式**） | alpha `0.067` | alpha `0.280`（视觉终审 #125 发现深色下四档在纯黑画布上几乎不可辨，统一提高不透明度） |

> `ContentColors`（`label` 族）与 `FillColors`（`systemFill` 族）本就直接指向系统色，本次未改动，不在上表中。`secondaryAccent` / `neutralAccent` 两族与 `StatusColors` 的其余 19 个 token（非 subtle 变体）**显式定案保留**现有取值，同样未换值。

## `0.4.1`（Phase 2 收尾改进，2026-07-24）

**非破坏性** —— 纯新增 + RTL 正确性修复，对下游零破坏，无需迁移。

- **`Card(bordered:)` + `View.surface(_:bordered:)`（新增公开 API）**：`Card` 新增 `bordered: Bool = true` 参数，`SurfaceModifier` 同步暴露 `.surface(_:bordered:)`。置 `false` 去描边、只留背景 + 圆角，贴近 iOS 系统分组容器（无描边、靠填充色对比定界）。默认 `true`，现有 `Card { }` / `.surface(kind)` 调用行为不变。
- **全库 chevron 统一 `chevron.forward`（RTL 正确性）**：`ChevronRightIcon` / `Sidebar` / `ListRow` / `CoreDisclosureGroupStyle` 的 disclosure chevron 从 `chevron.right` 改为 `chevron.forward`。**LTR 下视觉不变**（仍指右），**RTL 下自动镜像**为指左，与系统一致。`CoreDisclosureGroupStyle` 的展开旋转同步做了 `layoutDirection` 感知（RTL 展开态指下而非指上）。`ChevronRightIcon` 公开类型名保留（API 稳定）。

## `0.4.0`（epic coredesign-native-components）

Phase 2 新组件交付,**纯新增为主**:基础容器 `Card` / `Separator` / `SectionHeader` / `SectionFooter`、分组设置行 `InsetGroupedSection` / `SettingsRow`（含 `SettingsRowIcon` / `SettingsRowChevron` / 顶层枚举 `SettingsDividerInset`）、系统控件 `.core` style 3 个（`progressViewStyle(.core)` / `labelStyle(.core)` / `disclosureGroupStyle(.core)`）。这些**不删不改公开符号,对下游零破坏**。唯一的破坏面是下方「同名换值」的 `.content` / `.card` 表面色指向变更（对下游编译零感知,仅改观感）。

> `.toggleStyle(.core)` / `.textFieldStyle(.core)` **有意未提供**——自定义 `ToggleStyle.makeBody` 会丢原生 switch 的手势与 haptic、`TextFieldStyle._body` 是私有的无公开自定义入口;换皮即重造控件,违反「不重造系统控件」约束。设置行里的开关直接用系统 `Toggle` + `.tint`。

### 同名换值

#### `Color.surfaceCard`（Issue #140）

| 旧实现 | 新实现 | 影响 |
|---|---|---|
| 别名 `Color.surfaceCanvas`（= `systemGroupedBackground`，页面画布色） | 别名 `Color.surfaceRaised`（= `secondarySystemGroupedBackground`，浮起层色） | **对下游编译零感知**——符号名、类型签名均未变，`scripts/downstream-probe` 探测不到。视觉上：`.surface(.content)` 与 `.surface(.card)` 两个 `SurfaceKind` case（唯二消费 `surfaceCard` 的调用点）渲染出的背景色**在浅色与深色两种外观下都改变**（iOS 浅色：`systemGroupedBackground` #F2F2F7 → `secondarySystemGroupedBackground` #FFFFFF，灰画布卡片变白色浮起卡片；iOS 深色：由此前与画布同色的塌缩隐形变为可辨的浮起背景。上述 hex 为 **iOS 值**；macOS 走降级映射 `windowBackgroundColor` → `controlBackgroundColor`，具体值不同但同样两种外观下都变，见 `SystemBackgroundColors.swift` 的降级注释）。深色是动机（塌缩隐形），不是变化的全部范围。本变更落地（`0.3.0`）时库内**无生产组件调用** `.surface(.content)` / `.surface(.card)`（彼时唯一**生产**调用点是 `ListRow.swift` 的 `.surface(.canvas)`，不受影响；`SurfacePreviewGallery` 的 `#Preview` 会遍历全部 case，非生产路径）。**`0.4.0` 起新增的 `Card` 消费 `.surface(.content)`**——但 `Card` 是净新增组件、自始即渲染新值,不构成升级前后的观感变化。若下游代码直接调用了这两个 case，或直接引用 `Color.surfaceCard`，升级后视觉会随之改变 |

Phase 1 视觉终审（#125）与 #136 查明 `.surface(.content)` → `surfaceCard` → `surfaceCanvas` → `systemGroupedBackground` 这条链路——卡片背景与页面画布完全同色，深色下、无描边时不可辨。iOS 卡片本应浮于画布之上（`secondarySystemGroupedBackground`，即库内已有的 `surfaceRaised`），故只改 `surfaceCard` 的别名目标，不改 `SurfaceKind` 的 case 结构。

## Issue #97（epic coredesign-audit-remediation，2026-07-21）

### 删除的公开符号

| 删除 | 替代 |
|---|---|
| `EmptyState`（组件） | SwiftUI `ContentUnavailableView` / UIKit `UIContentUnavailableView`（见 [components/empty-state.md](components/empty-state.md)） |
| `KeyboardReadable` 协议及其默认实现 | 无 CoreDesign 替代；键盘高度用 `keyboardLayoutGuide` 或自建 publisher |
| `View.dismissKeyboardOnTap(enabled:onKeyboardDismissed:)` | 同上 |
| `HideKeyboardOnTapGesture` | 同上 |
| `View.resignFirstResponder()` / `View.becomeFirstResponder()` | 直接用 UIKit/AppKit 的 first responder API |
| `anyWriterFirstResponderNotification`（= 字符串 `"io.platform.inputView.becomeFirstResponder"`） | **字符串键契约**：若下游用字面量 observe 该通知，符号 grep 查不到，请手动核对 |
| `CoreRadius.full`（= 9999） | pill 形态用 `Capsule()`，不要用大 `cornerRadius` |
| `bordered(color:width:)` 重载 | `bordered(style:width:shape:)`（`Color` 已 conform `ShapeStyle`，直接传） |

### 签名变更（源码兼容，追加带默认值的参数）

| 变更 | 说明 |
|---|---|
| `bordered(style:width:)` → `bordered(style:width:shape:)` | 新增 `shape` 参数（默认 `Rectangle()`）；同时描边从 `stroke` 改 `strokeBorder`，边框向内收 `width/2` |

> **零引用验证**：上述删除的符号已在真实下游 `any-writer` 实测零引用（排除其 vendored CoreDesign 副本）。唯一无法用 grep 覆盖的是 `anyWriterFirstResponderNotification` 的**字符串键**——已单独在上表标注。
