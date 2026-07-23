# Card

内容容器的最薄外壳 / Thinnest content-container shell.

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| padding | CGFloat | CoreSpacing.lg | 内容四周内边距（16pt，对齐 iOS 分组卡片惯例） |
| alignment | Alignment | .leading | 撑满宽度内的内容对齐 |
| content | () -> Content | - | 卡片内容 |

`Card` 不引入平行的容器体系：`content` → `.padding(padding)` → `.surface(.content)`（背景 / 描边 / 圆角均由 `SurfaceModifier` 提供，不重新实现）。默认**撑满父容器宽度**（`maxWidth: .infinity`），需要「hug 自身内容尺寸」的非撑满场景应直接用 `View.surface(.content)` 而非 `Card`。

## 预览 / Preview

运行 `scripts/run-snapshots.sh` 后，预览图将生成于 `docs/snapshots/`。

## 使用示例 / Usage

```swift
Card {
    VStack(alignment: .leading, spacing: CoreSpacing.sm) {
        Text("Title").coreFont(.headline)
        Text("Body").coreFont(.subheadline).foregroundStyle(.secondary)
    }
}

Card(alignment: .center) {
    EmptyStateView(...)  // 居中内容的空态卡片
}

Card(padding: CoreSpacing.md) {
    Text("紧凑内边距")
}
```

## 视觉 Token

- 背景：`.surface(.content)`，指向 `surfaceRaised`（`secondarySystemGroupedBackground`）——浮于画布之上，深浅双模式下都与 `Color.surfaceCanvas` 拉开
- 内边距：默认 `CoreSpacing.lg`
- 圆角 / 描边：由 `SurfaceModifier` 统一提供，不在 `Card` 自身重复定义
