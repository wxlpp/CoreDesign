# EmptyState（已废弃 / Deprecated）

`EmptyState` 已废弃，请改用平台原生的"内容不可用"视图：

- SwiftUI：[`ContentUnavailableView`](https://developer.apple.com/documentation/swiftui/contentunavailableview)
- UIKit：[`UIContentUnavailableView`](https://developer.apple.com/documentation/uikit/uicontentunavailableview)、
  [`UIContentUnavailableConfiguration`](https://developer.apple.com/documentation/uikit/uicontentunavailableconfiguration)

如需带 action 的样式，把 `ContentUnavailableView` 与 CoreDesign 按钮组合即可：

```swift
ContentUnavailableView {
    Label("No results", systemImage: "magnifyingglass")
} description: {
    Text("Try a different search.")
} actions: {
    Button("Clear filters") { /* ... */ }
        .buttonStyle(.solid())
}
```

## 状态

- **Phase 1（2026-05-14）**：API 标注 `@available(*, deprecated, ...)`，附迁移指引指向 `ContentUnavailableView`。
- **Phase 3C（本阶段，2026-05-15）**：从 storybook 注册表、app preview catalog 与推荐组件索引中移除；源文件中所有内嵌 `#Preview` 块删除；`public extension EmptyState` 加 `@available(*, deprecated, ...)` 抑制 self-referential 警告——`swift build -Xswiftc -warnings-as-errors` 全包恢复 clean。
- **源码状态**：`Sources/CoreDesign/Components/EmptyState/EmptyState.swift` 仍保留为兼容包装层，**当前大版本期间**不会被删除；不会接收新的视觉打磨，仅做保持构建健康必需的修复。
- **彻底移除**：推迟到下一个明确规划的破坏性变更周期。
