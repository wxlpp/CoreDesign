# ProgressIndicator

通用圆形加载指示器 / Generic circular loading indicator.

封装系统 `ProgressView`，使用 Primer `accent` 色作为 tint，自动响应 `@Environment(\.controlSize)`。

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| (none) | - | - | 通过 `.controlSize(_:)` 调整尺寸 |

## 预览 / Preview

运行 `scripts/run-snapshots.sh` 后，预览图将生成于 `docs/snapshots/`。

## 使用示例 / Usage

```swift
ProgressIndicator()
    .controlSize(.large)

// 与其他 SwiftUI 控件一起被外层 controlSize 影响
HStack {
    ProgressIndicator()
    Text("Loading…")
}
.controlSize(.small)
```

## 视觉 Token

- Tint：`Color.accent`
- 尺寸：跟随 `\.controlSize`（mini / small / regular / large / extraLarge）
- 可访问性：默认 `accessibilityLabel("Loading")`
