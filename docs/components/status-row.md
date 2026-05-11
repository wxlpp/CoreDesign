# StatusRow

CI 检查状态行 / CI status row.

图标 + 名称 + 耗时 + 结果指示器。用于平铺的检查列表（VStack），不是时间线组件。

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| label | String | - | 步骤名（如 `build (arm64)`） |
| duration | String | - | 耗时文本（如 `2m 14s`，未开始用 `—`） |
| result | StatusResult | - | 状态枚举 |

`StatusResult` 枚举：

| 值 | 图标 | 前景色 |
|---|---|---|
| `.success` | `checkmark.circle.fill` | `statusSuccessForeground` |
| `.failure` | `xmark.circle.fill` | `statusDangerForeground` |
| `.pending` | `clock` | `statusAttentionForeground` |
| `.skipped` | `minus.circle` | `.secondary` |

## 预览 / Preview

运行 `scripts/run-snapshots.sh` 后，预览图将生成于 `docs/snapshots/`。

## 使用示例 / Usage

```swift
VStack(spacing: 0) {
    StatusRow(label: "build (arm64)", duration: "2m 14s", result: .success)
    Divider()
    StatusRow(label: "lint", duration: "0m 12s", result: .failure)
    Divider()
    StatusRow(label: "deploy", duration: "—", result: .pending)
}
```

## 视觉 Token

- 字号：`CoreTypography.bodySmallFont`，duration 加 `.monospacedDigit()`
- Padding：横向 `CoreSpacing.md`，纵向 `CoreSpacing.sm`
- 行内间距：`CoreSpacing.sm`
- 可访问性：合并为单个元素，label 读 step name，value 读 `"<result>, <duration>"`
