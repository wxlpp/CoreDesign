# Breaking Changes

破坏性变更按版本 / Issue 记录在此，下游升级前请对照。

> 已发布的 git tag：`v0.1.0`（2026-07-19）、`v0.2.0`（2026-07-21）。本文件早期版本曾写
> 「本库当前无外部版本 tag」——那在 `v0.1.0` 之前成立，之后未同步，已更正。

## `0.3.0`（epic coredesign-native-foundation，2026-07-21 ~ 2026-07-23）

把 token 地基从 GitHub Primer 换成 Apple HIG。取值理由见
[`docs/DESIGN-FOUNDATION.md`](DESIGN-FOUNDATION.md)。这是一次**破坏面很大**的改造：
6 个组件删除、`Blossom` trait 删除、`CoreGradient` 删除、9 个字体 token 改名、
圆角与控件尺寸档位换值、大量语义色改指系统色。库当前版本 `0.2.0`，处于 `1.0` 之前，
接受破坏性变更，但要求完整记录。

> **下游升级路径**：本次改造分两个版本发布——`0.3.0`（本条目，地基）与 `0.4.0`
> （新组件，`InsetGroupedSection` / `SettingsRow` / `Card` / `Separator` /
> `SectionHeader` / `SectionFooter` 等，另立 epic 交付）。若不急于跟进 `0.3.0`，
> **可直接从 `0.2.0` 跳到 `0.4.0`**，届时以本条目与 `0.4.0` 条目的并集为准。凡本条目中
> 标注"无直接替代"的删除项，下游都应先确认 `0.4.0` 是否提供了可组合出等价效果的
> 通用容器，而不是假定永久没有替代路径。

### 删除的公开符号

| 删除 | 来源 | 替代 |
|---|---|---|
| `BookCover` / `RefPill` / `StatusRow` / `EventRow` / `CommentCard` / `TimelineItem`（6 个组件） | #117 | **无直接替代**——它们服务于「GitHub Issue 时间线」这一具体场景，在通用设计系统里被判定为死重而非迁移目标。若下游依赖，需按各自场景用 SwiftUI 原生组件重建；`0.4.0` 会新增的 `Card` / `InsetGroupedSection` 等通用容器可作为重建时的基础构件，但不是这 6 个组件的直接替代品 |
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

## `0.4.0`（epic coredesign-native-components，进行中）

新组件交付（`InsetGroupedSection` / `SettingsRow` / `Card` / `Separator` / `SectionHeader` / `SectionFooter` 等）；本条目随任务推进逐步补全。

### 同名换值

#### `Color.surfaceCard`（Issue #140）

| 旧实现 | 新实现 | 影响 |
|---|---|---|
| 别名 `Color.surfaceCanvas`（= `systemGroupedBackground`，页面画布色） | 别名 `Color.surfaceRaised`（= `secondarySystemGroupedBackground`，浮起层色） | **对下游编译零感知**——符号名、类型签名均未变，`scripts/downstream-probe` 探测不到。视觉上：`.surface(.content)` 与 `.surface(.card)` 两个 `SurfaceKind` case（唯二消费 `surfaceCard` 的调用点）渲染出的背景色**在浅色与深色两种外观下都改变**（浅色：`systemGroupedBackground` #F2F2F7 → `secondarySystemGroupedBackground` #FFFFFF，灰画布卡片变白色浮起卡片；深色：由此前与画布同色的塌缩隐形变为可辨的浮起背景）。深色是动机（塌缩隐形），不是变化的全部范围。库内**当前无生产组件调用** `.surface(.content)` / `.surface(.card)`（唯一 `.surface(` 调用点是 `ListRow.swift` 的 `.canvas`，不受影响），若下游代码直接调用了这两个 case，或直接引用 `Color.surfaceCard`，升级后视觉会随之改变 |

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
