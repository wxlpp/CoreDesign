# SettingsRow

iOS 设置页 / 偏好面板的行 / iOS Settings-style preference row.

## API

### SettingsRow

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| icon | SettingsRowIcon? | nil | 左侧可着色图标方块，nil 时不显示 |
| title | LocalizedStringKey / StringProtocol | - | 标题（字面量本地化，运行期字符串 verbatim） |
| subtitle | LocalizedStringKey? / StringProtocol? | nil | 可选副标题 |
| accessory | () -> Accessory | - | `@ViewBuilder` 尾部附件，支持任意视图 |

无 accessory 的便利 init：`SettingsRow(icon:title:subtitle:)`（`Accessory == EmptyView`）。

> **文本入参**：`title` / `subtitle` 各有 `LocalizedStringKey` 与 `StringProtocol` 两个重载。字面量（`title: "Wi-Fi"`）走 `LocalizedStringKey` 在 `Bundle.main` 本地化——`StringProtocol` 重载带 `@_disfavoredOverload`，保证字面量不误落 verbatim；运行期字符串变量走 `StringProtocol`（verbatim）。**`title` 与 `subtitle` 类型须一致**：混用字面量 + 运行期字符串时，字面量也会按 verbatim 处理、跳过本地化。

### SettingsRowIcon

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| systemName | String | - | SF Symbol 名 |
| background | Color | - | 色块背景色（图标本身固定白色，如同 iOS 设置） |

### SettingsRowMetrics

`SettingsRow` 与 `InsetGroupedSection` **共享**的布局常量命名空间——图标列宽、
分隔线 inset 从这里推导，调用方把自定义行对齐到同一网格时读它（逐值见下方
「视觉 Token」一节）。

```swift
public nonisolated enum SettingsRowMetrics {
    public static let iconSquareSize: CGFloat            // 30
    public static let iconTitleGap: CGFloat              // CoreSpacing.md
    public static let horizontalPadding: CGFloat         // CoreSpacing.lg
    public static let iconCornerRadius: CGFloat          // CoreRadius.small
    public static var iconAlignedDividerInset: CGFloat   // 越过图标列
    public static var textAlignedDividerInset: CGFloat   // 对齐内容 leading
}
```

⚠️ **`nonisolated` 在这个 enum 上是承重的、不是装饰**（#290）：本包开了
`.defaultIsolation(MainActor.self)`，不标它就是 MainActor 隔离的，而调用方读这些
常量的地方（自己的布局计算）不必然在主 actor 上 ⇒ 会拿到**硬 error**

```
error: main actor-isolated static property 'iconSquareSize'
       can not be referenced from a nonisolated context
```

而库自身的 `swift build` / `swift test` 全跑在被隔离的 target 内部，看不见这条。
常驻判据是 `scripts/downstream-probe`（`useSettingsRowMetrics()`），CI 的
`downstream-probe` job 带 `-Xswiftc -warnings-as-errors`。

### SettingsRowChevron

无参数。渲染尾部 disclosure chevron（`chevron.forward`，自动镜像 RTL），`Color.contentTertiary`，供 accessory 组合。

`SettingsRow` 既能放进 `InsetGroupedSection`，也能直接作原生 `List` 的行（ADR-2）——它只画内容与内边距，不画自己的背景 / 分隔线。放进 `List` 时需加 `.listRowInsets(EdgeInsets())` 清零 List 侧 inset，避免与 `SettingsRow` 自带的横向内边距叠加。尾部挂 `Toggle` 时不写死强调色，`Toggle` 自然读环境 `.tint`。

## 预览 / Preview

运行 `scripts/run-snapshots.sh`（默认模式）后，预览图落地 `docs/snapshots/`——但前提是该组件已在 `App/Sources/Previews.swift` 注册（导出文件名形如 `CoreDesignPreview_<组件名>.png`）；组件源码内自带的 `#Preview` 仅用于开发期本地预览，或经 `KEEP_LIBRARY_SNAPSHOTS=1 scripts/run-snapshots.sh` 导出到本地 scratch 目录做逐组件视觉核对（不写入 docs/snapshots，见 `.claude/epics/semi-mobile-components/phase0-decisions.md` §3）。

## 使用示例 / Usage

```swift
SettingsRow(
    icon: .init(systemName: "wifi", background: .blue),
    title: "Wi-Fi",
    subtitle: "HomeNetwork"
) {
    Text("On").foregroundStyle(.secondary)
    SettingsRowChevron()
}

SettingsRow(
    icon: .init(systemName: "bell.badge.fill", background: .red),
    title: "Notifications"
) {
    Toggle("Notifications", isOn: $on).labelsHidden() // label 非空、仅隐藏视觉
}
.tint(.green) // Toggle 跟随

// 纯 value 行（trailing 是 value 文本）
SettingsRow(title: "Version") {
    Text("0.4.0").foregroundStyle(.secondary)
}

// 真正无 accessory（便利 init，Accessory == EmptyView）
SettingsRow(icon: .init(systemName: "info.circle", background: .gray), title: "Build")
```

## 视觉 Token

- 图标方块：边长 `SettingsRowMetrics.iconSquareSize`（30pt），圆角 `CoreRadius.small`，经 `CoreShape.rounded`
- 图标 glyph：`@ScaledMetric(relativeTo: .body)`，随 Dynamic Type 与同行标题同步缩放，上限封到「方块边长 − CoreSpacing.sm × 2」
- 标题：`.coreFont(.body)` + `Color.contentPrimary`；副标题：`.coreFont(.footnote)` + `Color.contentSecondary`
- 布局间距：图标 ↔ 标题 `SettingsRowMetrics.iconTitleGap`（= `CoreSpacing.md`），accessory 内部视图间 `CoreSpacing.xs`
- 内边距：横向 `SettingsRowMetrics.horizontalPadding`（= `CoreSpacing.lg`），纵向 `CoreSpacing.sm`
- 最小高度：`CoreControlMetrics.height(for: .regular)`（44pt，Apple HIG 最小可点击目标地板）
- 无障碍：标题 + 副标题 combine 成单个静态元素（不含 accessory），accessory 保持独立焦点
