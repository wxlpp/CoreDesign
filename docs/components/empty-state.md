# EmptyState（已移除 / Removed）

`EmptyState` 已于 **Issue #97** 从源码中彻底移除。请改用平台原生的「内容不可用」视图：

- SwiftUI：[`ContentUnavailableView`](https://developer.apple.com/documentation/swiftui/contentunavailableview)
- UIKit：[`UIContentUnavailableView`](https://developer.apple.com/documentation/uikit/uicontentunavailableview)

## 迁移 / Migration

```swift
// 旧（已不存在）
EmptyState(
    systemName: "tray",
    title: "没有内容",
    description: "稍后再来看看"
)

// 新
ContentUnavailableView(
    "没有内容",
    systemImage: "tray",
    description: Text("稍后再来看看")
)
```

需要在空状态里放操作按钮时，把 CoreDesign 的按钮样式组合进 `ContentUnavailableView` 的 actions：

```swift
ContentUnavailableView {
    Label("没有内容", systemImage: "tray")
} description: {
    Text("稍后再来看看")
} actions: {
    Button("刷新") { reload() }
        .buttonStyle(.solid(role: .primary))
}
```

## 时间线 / Timeline

- **Phase 1（2026-05-14）**：API 标注 `@available(*, deprecated, ...)`，迁移指引指向 `ContentUnavailableView`。
- **Phase 3C（2026-05-15）**：从 storybook 注册表、app preview catalog 与推荐组件索引中移除；源文件内嵌 `#Preview` 全部删除。
- **Issue #97（2026-07-21）**：**源文件整体删除**（237 行）及其自证测试。

> **关于「当前大版本期间不会被删除」的承诺。** 本文件此前写着源码「仍保留为兼容包装层，当前大版本期间不会被删除」，「彻底移除推迟到下一个明确规划的破坏性变更周期」。
>
> **epic `coredesign-audit-remediation`（本轮全量审计修复）就是那个明确规划的周期**——它整体是一次破坏性变更集合（#94 改了两个公开类型名、#97 删除多个 public 符号），本库当前也无外部版本 tag 约束。#97 的 B9g 据此执行了移除。
>
> 记在这里是因为：删掉一条兼容承诺时，**不应该连记录那条承诺的文件一起删掉**——否则日后无从判断承诺是被履行了还是被遗忘了。
