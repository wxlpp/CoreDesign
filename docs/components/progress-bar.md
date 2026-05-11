# ProgressBar

水平进度条 / Horizontal progress bar.

灰色底轨 + 可配置彩色填充 + 可选左侧 label 文本。`value` 自动 clamp 到 `0...1`。

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| value | Double | - | 进度，自动 clamp 到 `0...1` |
| tint | Color? | nil | 填充色，nil 时使用 `Color.accent` |
| label | String? | nil | 左侧 label，nil 时省略 |

## 预览 / Preview

运行 `scripts/run-snapshots.sh` 后，预览图将生成于 `docs/snapshots/`。

## 使用示例 / Usage

```swift
ProgressBar(value: 0.5, label: "50%")
ProgressBar(value: 1.0, tint: .statusSuccessEmphasis, label: "Done")
```

## 视觉 Token

- 高度：`CoreSpacing.xs`
- 圆角：`CoreRadius.small`
- 底轨色：`Color.surfaceCanvasInset`
- 填充色：`tint ?? Color.accent`
- Label 字号：`CoreTypography.bodySmallFont`
- 可访问性：`accessibilityValue("<percent>% complete")`
