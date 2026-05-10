# EmptyState

空状态占位视图 / Empty state placeholder.

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| systemName | String | - | SF Symbol 名称 |
| title | String | - | 标题文本 |
| description | String? | nil | 说明文本（多行居中） |
| iconSize | CGFloat | CoreSpacing.xxxxl | 图标尺寸（pt） |

如需 CTA，使用 `EmptyState(systemName:title:description:iconSize:action:)`。

## 预览 / Preview

运行 `scripts/run-snapshots.sh` 后，预览图将生成于 `docs/snapshots/`。

## 使用示例 / Usage

```swift
// 仅 icon + title
EmptyState(systemName: "tray", title: "No items")

// 含描述
EmptyState(
    systemName: "magnifyingglass",
    title: "No results",
    description: "Try a different search term."
)

// 含 CTA
EmptyState(
    systemName: "doc.text",
    title: "No documents yet"
) {
    Button("New document") { /* ... */ }
        .buttonStyle(.borderedProminent)
}
```

## 视觉 Token

- 布局：垂直 VStack，`CoreSpacing.xl` 外边距，`frame(maxWidth: .infinity)`
- 图标：`Color.contentMuted`，尺寸由 `iconSize` 控制
- 图标底部间距：`CoreSpacing.lg`
- 标题：`CoreTypography.titleMediumFont` + `Color.contentPrimary`
- 描述：`CoreTypography.bodyMediumFont` + `Color.contentMuted`
- CTA 上方间距：`CoreSpacing.xl`
