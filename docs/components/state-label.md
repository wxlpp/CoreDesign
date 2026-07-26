# StateLabel

通用状态标识 pill / Generic state label pill.

大圆角 + 彩色背景 + SF Symbol 图标 + 文字。颜色由 `StateLabelStyle` 枚举驱动，映射到 `StatusColors` 系统的 emphasis 背景 + foreground 文字。

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| style | StateLabelStyle | - | 语义样式：active / draft / completed / cancelled |
| label | String? | nil | 自定义文本，nil 时使用 style 的默认文案 |

`StateLabelStyle` 枚举：

| 值 | 默认 label | 图标 | 背景 / 前景 token |
|---|---|---|---|
| `.active` | Active | `circle.fill` | `statusSuccessEmphasis` / `statusSuccessForeground` |
| `.draft` | Draft | `circle.dashed` | `statusAttentionEmphasis` / `statusAttentionForeground` |
| `.completed` | Completed | `checkmark.circle.fill` | `statusDoneEmphasis` / `statusDoneForeground` |
| `.cancelled` | Cancelled | `xmark.circle.fill` | `statusDangerEmphasis` / `statusDangerForeground` |

## 预览 / Preview

运行 `scripts/run-snapshots.sh`（默认模式）后，预览图落地 `docs/snapshots/`——但前提是该组件已在 `App/Sources/Previews.swift` 注册（导出文件名形如 `CoreDesignPreview_<组件名>.png`）；组件源码内自带的 `#Preview` 仅用于开发期本地预览，或经 `KEEP_LIBRARY_SNAPSHOTS=1 scripts/run-snapshots.sh` 导出到本地 scratch 目录做逐组件视觉核对（不写入 docs/snapshots，见 `.claude/epics/semi-mobile-components/phase0-decisions.md` §3）。

## 使用示例 / Usage

```swift
StateLabel(style: .active)
StateLabel(style: .draft, label: "WIP")
StateLabel(style: .completed)
StateLabel(style: .cancelled)
```

## 视觉 Token

- 形状：`Capsule(style: .continuous)`
- 字号：`CoreTypography.bodySmallFont`（label），`.caption2`（icon）
- Padding：横向 `CoreSpacing.sm`，纵向 `CoreSpacing.xxs`
- 间距（icon-to-label）：`CoreSpacing.xs`
