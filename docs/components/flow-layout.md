# FlowLayout

Tag 自动换行布局容器 / Wrapping flow layout container for tag chips.

实现 SwiftUI `Layout` 协议，子视图在行内容纳不下时自动折行。通过 `Layout.Cache` 在 `sizeThatFits` 与 `placeSubviews` 之间共享尺寸测量结果，每个 subview 一次布局只测一次。

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| spacing | CGFloat | `CoreSpacing.xs` | 行内 / 行间间距 |

## 预览 / Preview

运行 `scripts/run-snapshots.sh` 后，预览图将生成于 `docs/snapshots/`。

## 使用示例 / Usage

```swift
FlowLayout(spacing: CoreSpacing.xs) {
    Tag("bug", color: .red)
    Tag("enhancement", color: .blue)
    Tag("help wanted", color: .green)
    Tag("documentation", color: .cyan)
}
```

## 实现 Note

- `typealias Cache = [CGSize]`，在 `makeCache(subviews:)` / `updateCache(_:subviews:)` 阶段把每个 subview 的 `sizeThatFits(.unspecified)` 缓存进数组。
- `computeRows` 基于 cache 索引重新计算行布局，不重复调 `sizeThatFits`。
- 适合 Tag chip group、Label cloud；不要塞进可变高度的复杂内容。
