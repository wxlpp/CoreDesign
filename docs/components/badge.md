# Badge

GitHub 风格的状态指示器 / GitHub-style status indicator.

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| text | String | - | 显示的文本 |
| variant | BadgeVariant | .neutral | 语义等级：info / success / warning / danger / neutral |
| outlined | Bool | false | 是否带描边 |

也可使用 `Badge(variant:outlined:label:)` 自定义 label 视图（如含 SF Symbol）。

## 预览 / Preview

运行 `scripts/run-snapshots.sh` 后，预览图将生成于 `docs/snapshots/`。

## 使用示例 / Usage

```swift
Badge("Beta", variant: .info)
Badge("Draft", variant: .warning, outlined: true)
Badge(variant: .success) {
    HStack(spacing: CoreSpacing.xxs) {
        Image(systemName: "checkmark")
            .accessibilityHidden(true)
        Text("Merged")
    }
}
```

## 视觉 Token

- 圆角：`CoreRadius.full`（Capsule pill 形态）
- 字号：`CoreTypography.bodySmallFont` + `bodySmallTracking`
- Padding：横向 `CoreSpacing.sm`，纵向 `CoreSpacing.xs`
- 背景色：`Color.surfaceCanvasSubtle`（neutral）/ status background token（info/success/warning/danger）
- 边框（`outlined: true` 时）：`Color.borderMuted`（neutral）/ status border token，宽度 `CoreBorderWidth.thin`
