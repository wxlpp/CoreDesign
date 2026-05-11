# EventRow

紧凑单行时间线事件 / Compact single-line timeline event.

Actor + 动作文本 + 可选 object pill + 时间戳。用于 `TimelineItem` 内容槽中的非评论事件行，例如 "labeled / force-pushed / commented"。

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| actor | String | - | 操作者名（粗体） |
| action | String | - | 动作短语（次要色） |
| timeAgo | String | - | 相对时间 |
| pill | () -> some View | `EmptyView()` | 可选对象 pill，例如 `Tag` / `RefPill` |

## 预览 / Preview

运行 `scripts/run-snapshots.sh` 后，预览图将生成于 `docs/snapshots/`。

## 使用示例 / Usage

```swift
EventRow(actor: "renovate", action: "added the", timeAgo: "2 days ago") {
    Tag("dependencies", color: .blue)
}
EventRow(actor: "renovate", action: "force-pushed from", timeAgo: "2 days ago") {
    RefPill("4d2040c")
}
EventRow(actor: "evan", action: "commented", timeAgo: "1 hour ago")
```

## 视觉 Token

- 字号：`CoreTypography.bodyMediumFont`（actor / action）、`CoreTypography.bodySmallFont`（timeAgo）
- 颜色：actor 默认，action `.secondary`，timeAgo `.tertiary`
- 行内间距：`CoreSpacing.xs`
- 单行限制：`lineLimit(1)`
- 可访问性：`.accessibilityElement(children: .combine)` 不覆盖 label——actor / action / pill (Tag / RefPill) / timeAgo 各自的 a11y 文本自动合并；显式覆盖会丢失 pill 内容
