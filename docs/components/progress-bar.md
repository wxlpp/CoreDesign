# ProgressBar

水平进度条 / Horizontal progress bar.

> **⚠️ 已弃用（`0.6.0` 起）**：改用系统 `ProgressView(value:).progressViewStyle(.core)`（见 [core-control-styles.md](core-control-styles.md)）。二者视觉几乎一致，但 `.core` **响应环境 `.tint`**、走系统控件，无障碍与 Dynamic Type 更完整；`ProgressBar` 有意拒绝环境 tint、只认自己的 `tint:` 参数。`ProgressBar` 保留至下游迁移完成后移除。

灰色底轨 + 可配置彩色填充 + 可选左侧 label 文本。`value` 自动 clamp 到 `0...1`。

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| value | Double | - | 进度，自动 clamp 到 `0...1` |
| tint | Color? | nil | 填充色，nil 时使用 `Color.accent` |
| label | String? | nil | 左侧 label，nil 时省略 |

## 预览 / Preview

已弃用，不再生成快照预览图。替代品的预览见 [core-control-styles.md](core-control-styles.md)（`.core ProgressView`）。

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
