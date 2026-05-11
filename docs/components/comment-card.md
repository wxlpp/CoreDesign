# CommentCard

通用评论卡片 / Generic comment card.

Header（作者名 + 可选 role badge + 时间戳）+ 主体内容 slot + 最小化提示。Avatar 由外层 `TimelineItem` 的 icon 槽提供，不在卡片内。

`isMinimized` 为 `Binding<Bool>?`：`nil` 时不可折叠（始终展开）；非 nil 时由调用方控制折叠/展开状态。

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| author | String | - | 作者名（粗体） |
| role | String? | nil | 可选 role badge（"Contributor" / "Bot" 等） |
| timestamp | String | - | 时间戳文本 |
| isMinimized | Binding\<Bool\>? | nil | 折叠态绑定；nil 表示不可折叠 |
| content | () -> some View | - | 卡片主体内容 |

## 预览 / Preview

运行 `scripts/run-snapshots.sh` 后，预览图将生成于 `docs/snapshots/`。

## 使用示例 / Usage

```swift
// 普通评论
CommentCard(author: "evan", role: "Contributor", timestamp: "2 hours ago") {
    Text("LGTM — ready to ship 🚀")
}

// 可折叠（bot 评论 / 长 diff 占位）
@State var minimized = true
CommentCard(
    author: "renovate",
    role: "Bot",
    timestamp: "2 days ago",
    isMinimized: $minimized
) {
    Text("chore(deps): update github actions")
}
```

## 视觉 Token

- 圆角：`CoreRadius.medium`
- 背景：`Color.surfaceCard`
- 描边：`Color.borderMuted`，宽度 `CoreBorderWidth.thin`
- Padding：`CoreSpacing.md`
- Header / body 间距：`CoreSpacing.sm`
- Role badge：`Capsule` + `Color.surfaceCanvasInset` 背景 + `Color.borderMuted` 描边，文字 `.caption2 secondary`
- 最小化态：单行提示 + "Show" 按钮（带 `accessibilityLabel` / `accessibilityHint`）
- 可访问性：整卡 `accessibilityElement(children: .contain)`，label 为 `"Comment by <author>"`
