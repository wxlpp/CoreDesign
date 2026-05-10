# Tag

任意分类标签 / Caller-colored label chip.

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| text | String | - | 标签文本 |
| color | Color | - | 调色板，驱动衬底与前景色 |
| removable | Bool | false | 是否显示关闭按钮 |
| onRemove | (() -> Void)? | nil | 关闭按钮回调 |

也可使用 `Tag(color:removable:onRemove:label:)` 自定义 label 视图。

## 预览 / Preview

![Light](../snapshots/CoreDesignPreview_Previews.swift_Tag.png)

## 使用示例 / Usage

```swift
Tag("bug", color: .red)
Tag("enhancement", color: .blue, removable: true, onRemove: { print("dismissed") })
Tag(color: .green, removable: true, onRemove: {}) {
    Label("verified", systemImage: "checkmark.seal.fill")
}
```

## 视觉 Token

- 圆角：`CoreRadius.small`（3pt），与 Badge 的 pill 形态区分
- 字号：`CoreTypography.bodySmallFont`
- Padding：横向 `CoreSpacing.sm`，纵向 `CoreSpacing.xs`
- 背景：`color.opacity(0.12)` 衬底
- 前景：直接使用 `color`
- 关闭按钮：`xmark.circle.fill`，尺寸 `CoreControlMetrics.iconSize(for: .small)`
