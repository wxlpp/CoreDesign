# SearchField

搜索输入框 / Search input field.

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| text | Binding<String> | - | 搜索文本的双向绑定 |
| placeholder | String | "Search" | 空文本占位提示 |
| onSubmit | ((String) -> Void)? | nil | Return 提交回调 |

## 预览 / Preview

运行 `scripts/run-snapshots.sh` 后，预览图将生成于 `docs/snapshots/`。

## 使用示例 / Usage

```swift
@State private var query = ""

SearchField(text: $query, placeholder: "Filter issues") { submitted in
    viewModel.runSearch(submitted)
}
```

## 视觉 Token

- 容器背景：`Color.surfaceCanvasInset`
- 边框：`Color.borderMuted`，宽度 `CoreBorderWidth.thin`
- 圆角：`CoreRadius.medium`
- 文字色：`Color.contentPrimary`
- Icon 色：`Color.contentMuted`
- 字号 / padding / 高度：`CoreControlMetrics` for `.regular`
- 放大镜：`magnifyingglass`，16pt
- 清除按钮：`xmark.circle.fill`
- 焦点环：`.focusRing(visible: true, color: .borderFocus, width: CoreBorderWidth.thick, cornerRadius: CoreRadius.medium)`
