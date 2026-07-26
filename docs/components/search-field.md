# SearchField

搜索输入框 / Search input field.

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| text | Binding<String> | - | 搜索文本的双向绑定 |
| placeholder | String | "Search" | 空文本占位提示 |
| onSubmit | ((String) -> Void)? | nil | Return 提交回调 |

## 预览 / Preview

运行 `scripts/run-snapshots.sh`（默认模式）后，预览图落地 `docs/snapshots/`——但前提是该组件已在 `App/Sources/Previews.swift` 注册（导出文件名形如 `CoreDesignPreview_<组件名>.png`）；组件源码内自带的 `#Preview` 仅用于开发期本地预览，或经 `KEEP_LIBRARY_SNAPSHOTS=1 scripts/run-snapshots.sh` 导出到本地 scratch 目录做逐组件视觉核对（不写入 docs/snapshots，见 `.claude/epics/semi-mobile-components/phase0-decisions.md` §3）。

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
