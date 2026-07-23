# SettingsRow

iOS 设置页 / 偏好面板的行 / iOS Settings-style preference row.

## API

### SettingsRow

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| icon | SettingsRowIcon? | nil | 左侧可着色图标方块，nil 时不显示 |
| title | Text | - | 标题 |
| subtitle | Text? | nil | 可选副标题 |
| accessory | () -> Accessory | - | `@ViewBuilder` 尾部附件，支持任意视图 |

无 accessory 的便利 init：`SettingsRow(icon:title:subtitle:)`（`Accessory == EmptyView`）。

### SettingsRowIcon

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| systemName | String | - | SF Symbol 名 |
| background | Color | - | 色块背景色（图标本身固定白色，如同 iOS 设置） |

### SettingsRowChevron

无参数。渲染尾部 disclosure chevron（`chevron.forward`，自动镜像 RTL），`Color.contentTertiary`，供 accessory 组合。

`SettingsRow` 既能放进 `InsetGroupedSection`，也能直接作原生 `List` 的行（ADR-2）——它只画内容与内边距，不画自己的背景 / 分隔线。放进 `List` 时需加 `.listRowInsets(EdgeInsets())` 清零 List 侧 inset，避免与 `SettingsRow` 自带的横向内边距叠加。尾部挂 `Toggle` 时不写死强调色，`Toggle` 自然读环境 `.tint`。

## 预览 / Preview

运行 `scripts/run-snapshots.sh` 后，预览图将生成于 `docs/snapshots/`。

## 使用示例 / Usage

```swift
SettingsRow(
    icon: .init(systemName: "wifi", background: .blue),
    title: Text("Wi-Fi"),
    subtitle: Text("HomeNetwork")
) {
    Text("On").foregroundStyle(.secondary)
    SettingsRowChevron()
}

SettingsRow(
    icon: .init(systemName: "bell.badge.fill", background: .red),
    title: Text("Notifications")
) {
    Toggle("Notifications", isOn: $on).labelsHidden() // label 非空、仅隐藏视觉
}
.tint(.green) // Toggle 跟随

// 无 accessory
SettingsRow(title: Text("Version")) {
    Text("0.4.0").foregroundStyle(.secondary)
}
```

## 视觉 Token

- 图标方块：边长 `SettingsRowMetrics.iconSquareSize`（30pt），圆角 `CoreRadius.small`，经 `CoreShape.rounded`
- 图标 glyph：`@ScaledMetric(relativeTo: .body)`，随 Dynamic Type 与同行标题同步缩放，上限封到「方块边长 − CoreSpacing.sm × 2」
- 标题：`.coreFont(.body)` + `Color.contentPrimary`；副标题：`.coreFont(.footnote)` + `Color.contentSecondary`
- 布局间距：图标 ↔ 标题 `SettingsRowMetrics.iconTitleGap`（= `CoreSpacing.md`），accessory 内部视图间 `CoreSpacing.xs`
- 内边距：横向 `SettingsRowMetrics.horizontalPadding`（= `CoreSpacing.lg`），纵向 `CoreSpacing.sm`
- 最小高度：`CoreControlMetrics.height(for: .regular)`（44pt，Apple HIG 最小可点击目标地板）
- 无障碍：标题 + 副标题 combine 成单个静态元素（不含 accessory），accessory 保持独立焦点
