# SegmentedControl

Token 化的分段控件 / Token-styled segmented control.

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| items | [Item] | - | 选项数据源，Item 需 Hashable |
| selection | Binding<Item> | - | 当前选中项的双向绑定 |
| title | (Item) -> String | - | 选项到显示文字的映射 |

支持 `View.segmentedControlStyle(_:)` 注入外观，内置 `GlassSegmentedControlStyle`（默认）与 `PlainSegmentedControlStyle`。

## 预览 / Preview

运行 `scripts/run-snapshots.sh`（默认模式）后，预览图落地 `docs/snapshots/`——但前提是该组件已在 `App/Sources/Previews.swift` 注册（导出文件名形如 `CoreDesignPreview_<组件名>.png`）；组件源码内自带的 `#Preview` 仅用于开发期本地预览，或经 `KEEP_LIBRARY_SNAPSHOTS=1 scripts/run-snapshots.sh` 导出到本地 scratch 目录做逐组件视觉核对（不写入 docs/snapshots，见 `.claude/epics/semi-mobile-components/phase0-decisions.md` §3）。

## 使用示例 / Usage

```swift
@State private var selection = "A"

SegmentedControl(
    items: ["A", "B", "C"],
    selection: $selection,
    title: { $0 }
)
```

## 视觉 Token

- 外框背景：`Color.surfaceMuted`，圆角 `CoreRadius.medium`
- Thumb 背景：`Color.surfaceRaised`，圆角 `CoreRadius.small`
- 选中文字：`Color.contentPrimary` + `.semibold`
- 非选中文字：`Color.contentSecondary` + `.regular`
- 字号：`CoreTypography.bodyMediumFont`
- 间距：外框 padding `CoreSpacing.xxs`，segment 间距 `CoreSpacing.xxs`
- 高度：`CoreControlMetrics.height(for: .regular)`
- Thumb 阴影：`.coreShadow(.small)`
- 切换动画：`.easeInOut(duration: 0.18)` + `matchedGeometryEffect`
- 触感反馈：`.sensoryFeedback(.selection)`
