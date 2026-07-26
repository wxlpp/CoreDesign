# Typography（未实现 / Not implemented — parity 已由 `.coreFont` 达成）

`semi-mobile-components` epic 的原始 12 组件候选清单（Semi Design Tier 1 移动端通用组件补齐）中包含
`Typography`——一个用于统一渲染标题 / 正文 / 说明文字样式的展示型组件。**PRD v2 评审阶段裁决它出局**，
不作为独立组件实现：

> 原 12 组件清单中，**Typography** 与 **Spin** 按本库「不重造原生/既有」哲学（先例：`EmptyState` →
> `ContentUnavailableView`、`ProgressBar` → `.core`）被裁决为「parity 已达成」——Typography 出局
> （由 `.coreFont(_:)` + 原生 `Text` modifier 覆盖）。
> —— `.claude/prds/semi-mobile-components.md`

本文件是该裁决的**墓碑记录**：不存在名为 `Typography` 的 CoreDesign 组件、也不会有，本页给出等价能力的
迁移指引。

## 为什么不需要一个 `Typography` 组件

Semi Design 的 `Typography` 通常提供一组预设文字样式（Title / Body / Secondary / …）+ 截断 / 复制等
辅助能力。CoreDesign 已经用两层机制覆盖了同等诉求，且更贴近 SwiftUI 原生习惯：

1. **`CoreTypography.Token` + `.coreFont(_:)`**——12 档 token 一一对应系统 `Font.TextStyle`
   （见 `Sources/CoreDesign/Tokens/CoreTypography.swift`），随 Dynamic Type 自动缩放，调用方直接
   `Text("...").coreFont(.headline)` 即可拿到对齐 Apple HIG 的字号 / 行高 / 字重标度，不需要额外的
   包装组件。
2. **原生 `Text` modifier**——截断（`.lineLimit(_:)`）、对齐（`.multilineTextAlignment(_:)`）、颜色
   （`.foregroundStyle(_:)`，配合第 3 层 `ContentColors` token）、字重（`.fontWeight(_:)`）等能力
   SwiftUI 已经原生具备，包一层 `Typography` 组件只会重复这些 API 而不增加价值。

## 迁移 / Migration

| Semi `Typography` 常见用法 | CoreDesign 等价写法 |
|---|---|
| 标题 | `Text("...").coreFont(.title)` / `.coreFont(.title2)` / `.coreFont(.title3)`（按层级选档） |
| 正文 | `Text("...").coreFont(.body)` |
| 次要说明文字 | `Text("...").coreFont(.footnote).foregroundStyle(Color.contentSecondary)` |
| 弱化辅助文字 | `Text("...").coreFont(.caption).foregroundStyle(Color.contentMuted)` |
| 等宽（如 ref / 版本号） | `Text("...").coreFont(.captionMono)` |
| 单行截断省略号 | `Text("...").lineLimit(1).truncationMode(.tail)`（原生，不需要包装） |
| 多行截断 | `Text("...").lineLimit(2)`（原生） |

```swift
// 旧（Semi Design 心智，CoreDesign 中不存在）
Typography.Title("订单详情")
Typography.Body("感谢您的购买", type: .secondary)

// 新（CoreDesign）
Text("订单详情").coreFont(.title2)
Text("感谢您的购买")
    .coreFont(.body)
    .foregroundStyle(Color.contentSecondary)
```

`CoreTypography.Token` 的完整 12 档见 `docs/DESIGN-FOUNDATION.md` 与
`Sources/CoreDesign/Tokens/CoreTypography.swift` 的 doc comment；`0.3.0` 的改名映射（旧
`displayLarge`/`titleLarge`/… → 新 `largeTitle`/`title`/…）记录在
[BREAKING-CHANGES.md](../BREAKING-CHANGES.md)。

## 时间线 / Timeline

- **PRD v1（`semi-mobile-components` 起草）**：`Typography` 位列 12 组件候选清单。
- **PRD v2（superpowers-reviewer 评审 BLOCK 后修订）**：与 `Spin` 一并裁决出局——`Typography` 判定
  parity 已由 `.coreFont(_:)` + 原生 `Text` modifier 达成，不重复造轮子；`Spin` 降级为
  `ProgressIndicator` 增强 + `View.spinning(_:text:)` modifier（见
  [progress-indicator.md](progress-indicator.md) / [spinning.md](spinning.md)）。
- **Phase 3 / #173（本文件，`0.7.0`）**：补齐墓碑文档，记录裁决依据与迁移指引，避免日后有人重新
  发起「要不要做一个 Typography 组件」的讨论时找不到此前的决策记录。
