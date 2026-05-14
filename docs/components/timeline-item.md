# TimelineItem

时间线脊柱节点容器 / Timeline spine node container.

左侧脊柱（连接线 + 图标圆点）+ 右侧内容槽。通过 `@Environment(\.timelineDepth)` 自动管理缩进递归——父级嵌套子 `TimelineItem` 时缩进自动 +1，无需手动传参。

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| icon | () -> some View | - | 左侧脊柱图标槽（通常是 `Circle` + symbol overlay） |
| showsTopConnector | Bool | true | 是否显示图标上方的连接线；顶层首节点应传 `false` |
| isLast | Bool | false | 是否为列表最后一项，影响底部连接线的渲染 |
| content | () -> some View | - | 右侧内容槽 |

## 预览 / Preview

运行 `scripts/run-snapshots.sh` 后，预览图将生成于 `docs/snapshots/`。

## 使用示例 / Usage

```swift
TimelineItem(icon: {
    Circle().fill(Color.statusAccentEmphasis)
        .overlay(Image(systemName: "plus").foregroundStyle(.white))
}, showsTopConnector: false) {
    VStack(alignment: .leading) {
        EventRow(actor: "evan", action: "opened this PR", timeAgo: "3 days ago")
        // 嵌套子 TimelineItem：depth 自动 +1
        TimelineItem(icon: { /* ... */ }, isLast: true) {
            Text("CI passed")
        }
    }
}
TimelineItem(icon: { /* ... */ }, isLast: true) {
    Text("merged 1 hour ago")
}
```

## 视觉 Token

- 脊柱连接线：`Color.borderMuted`，宽度 `CoreBorderWidth.thin`，竖向长度 `CoreSpacing.sm`
- 图标圆点尺寸：depth 0 → 32pt，depth ≥ 1 → 20pt
- 内容列垂直间距：`CoreSpacing.xs`
- 缩进：每深一层 +`CoreSpacing.xl`
- 可访问性：脊柱视图整体 `accessibilityHidden(true)`，焦点交给 content
