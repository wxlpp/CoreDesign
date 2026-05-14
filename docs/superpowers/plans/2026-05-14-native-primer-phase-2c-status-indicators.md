# Native Primer 第 2C 阶段：状态指示器实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**目标：** 把三个状态指示器组件 —— `Badge`、`Tag`、`StateLabel` —— 对齐到 Native Primer 基线：紧凑、以颜色承载语义、不带装饰性材质。

**架构：** 第 2B 阶段收尾了行/导航层。第 2C 阶段通过扫一遍小型状态指示器组件，完成 spec §Phase 2 的关闭。这些组件本身基本已经合规（无 glass、低饱和度表面）—— 本阶段是要确认这一点、显式声明 material/role，并补齐缺失的测试覆盖（`Tag` 目前没有测试文件）。

**技术栈：** Swift 6.3、SwiftUI、Swift Testing、iOS 26 / macOS 26 包目标。

---

## 源 Spec

实施前阅读：

- `docs/superpowers/specs/2026-05-14-native-primer-telegram-taste-design.md`

本计划仅覆盖 Phase 2 中的状态指示器子集：

- `Badge`（5 个固定语义级别）
- `Tag`（调用方着色的分类标签）
- `StateLabel`（生命周期 pill）

不要修改任何 Phase 3 组件。

## 文件结构

修改：

- `Sources/CoreDesign/Components/Badge/Badge.swift`
  - 调整文档注释，显式声明 Native Primer 的 material/role。
  - 保持 `BadgeVariant` 映射、公开 API 与视觉 token 不变。
- `Sources/CoreDesign/Components/Tag/Tag.swift`
  - 调整文档注释，显式声明 Native Primer 的 material/role。
  - 保持公开 API 与调用方着色 chip 的行为不变。
- `Sources/CoreDesign/Components/StateLabel/StateLabel.swift`
  - 调整文档注释，显式声明 Native Primer 的 material/role。
  - 保持 `StateLabelStyle` 映射与视觉 token 不变。

新建：

- `Tests/CoreDesignTests/TagTests.swift`

只读参考：

- `Tests/CoreDesignTests/BadgeTests.swift`（已有测试覆盖参考）
- `Tests/CoreDesignTests/StateLabelTests.swift`（已有测试覆盖参考）

---

## 任务 1：Badge Native Primer 文档化

**文件：**
- 修改：`Sources/CoreDesign/Components/Badge/Badge.swift`

- [ ] **步骤 1：跑现有 Badge 测试**

运行：

```bash
swift test --filter BadgeTests
```

预期：测试通过。这是在调整文档注释之前的编译保真基线。

- [ ] **步骤 2：更新顶部文档注释抬头**

在 `Sources/CoreDesign/Components/Badge/Badge.swift` 中，找到 `public struct Badge` 上方的文档注释，前置一段 Native Primer 抬头。保留全部现有正文（BadgeVariant 表格、Tag ↔ Badge 边界段、token 规格段）—— 只在开头加上 material/role 声明：

```swift
/// Native Primer status badge.
///
/// Control-layer status indicator with 5 fixed semantic levels. Compact, low
/// chrome, no glass — color is the semantic carrier, not decoration. Pairs
/// with row, header, and inline-label contexts.
///
/// **Material layer**: control. **Surface role**: control.
///
/// // 保留原有的 Primer Label / BadgeVariant 列表、Tag ↔ Badge 边界说明、
/// // token 规格段落（背景/边框/圆角）。这些是 load-bearing 文档，不要删。
```

- [ ] **步骤 3：确认未使用 glass**

运行：

```bash
rg "glassEffect|floatingGlass|circularGlass" Sources/CoreDesign/Components/Badge
```

预期：零匹配。

- [ ] **步骤 4：跑测试和构建**

运行：

```bash
swift test --filter BadgeTests
swift build
```

预期：测试通过；构建成功。

- [ ] **步骤 5：提交**

```bash
git add Sources/CoreDesign/Components/Badge/Badge.swift
git commit -m "docs: declare Badge Native Primer material/role"
```

---

## 任务 2：Tag Native Primer 补齐

**文件：**
- 修改：`Sources/CoreDesign/Components/Tag/Tag.swift`
- 新建：`Tests/CoreDesignTests/TagTests.swift`

- [ ] **步骤 1：编写编译/行为测试**

新建 `Tests/CoreDesignTests/TagTests.swift`：

```swift
import SwiftUI
import Testing
@testable import CoreDesign

@Suite("Tag")
struct TagTests {
    @MainActor
    @Test("tag constructs with text and color")
    func tagConstructsWithTextAndColor() {
        let tag = Tag(text: "bug", color: .red)
        #expect(type(of: tag) == Tag.self)
    }

    @MainActor
    @Test("removable tag constructs with onRemove")
    func removableTagConstructsWithOnRemove() {
        let tag = Tag(text: "wontfix", color: .gray, removable: true) {
            // remove handler is required when removable == true
        }
        #expect(type(of: tag) == Tag.self)
    }
}
```

> 如果 `Tag` 实际的公开 init 签名跟上面的调用不一致（例如 closure 的参数标签不同，
> 或者 `removable` 是由是否传 `onRemove` 来隐式决定的），写测试时要按实际签名匹配。
> 不要为了让测试编译而修改公开 API —— 应该改测试。

- [ ] **步骤 2：跑测试验证通过**

运行：

```bash
swift test --filter TagTests
```

预期：测试通过。

- [ ] **步骤 3：更新顶部文档注释抬头**

在 `Sources/CoreDesign/Components/Tag/Tag.swift` 中，找到 `public struct Tag` 上方的文档注释，前置一段 Native Primer 抬头。保留现有的 Tag ↔ Badge 边界段以及视觉规格段不变：

```swift
/// Native Primer category tag.
///
/// Control-layer category label. Color is supplied by the caller (issue
/// labels, repo-defined palettes); the chip stays compact and low chrome.
/// No default glass, no decorative material — semantics come from the
/// caller's color choice.
///
/// **Material layer**: control. **Surface role**: control.
///
/// // 保留原有 Tag ↔ Badge 边界说明（重要！）、视觉规格段落（背景/前景/圆角/字号/
/// // padding/关闭按钮/light-dark 行为）、以及使用示例。
```

- [ ] **步骤 4：确认未使用 glass**

运行：

```bash
rg "glassEffect|floatingGlass|circularGlass" Sources/CoreDesign/Components/Tag
```

预期：零匹配。

- [ ] **步骤 5：跑测试和构建**

运行：

```bash
swift test --filter TagTests
swift build
```

预期：测试通过；构建成功。

- [ ] **步骤 6：提交**

```bash
git add Sources/CoreDesign/Components/Tag/Tag.swift Tests/CoreDesignTests/TagTests.swift
git commit -m "test(Tag): add compile tests; align doc to Native Primer"
```

---

## 任务 3：StateLabel Native Primer 文档化

**文件：**
- 修改：`Sources/CoreDesign/Components/StateLabel/StateLabel.swift`

- [ ] **步骤 1：跑现有 StateLabel 测试**

运行：

```bash
swift test --filter StateLabelTests
```

预期：测试通过。

- [ ] **步骤 2：更新顶部文档注释抬头**

在 `Sources/CoreDesign/Components/StateLabel/StateLabel.swift` 中，找到 `public struct StateLabel` 上方的文档注释，前置一段 Native Primer 抬头。保留现有 `StateLabelStyle` 枚举文档、配色映射段、以及 pill 几何形态的设计说明不变：

```swift
/// Native Primer lifecycle state label.
///
/// Control-layer status pill driven by `StateLabelStyle` (`active` /
/// `draft` / `completed` / `cancelled`). Compact, color-for-meaning, no
/// decorative material — same restraint rules as `Badge`, with a fixed icon
/// + label payload tuned for lifecycle scanning.
///
/// **Material layer**: control. **Surface role**: control.
///
/// // 保留原有 StateLabelStyle 枚举语义、backgroundColor / foregroundColor
/// // 映射规则、SF Symbol + 文字布局说明。
```

- [ ] **步骤 3：确认未使用 glass**

运行：

```bash
rg "glassEffect|floatingGlass|circularGlass" Sources/CoreDesign/Components/StateLabel
```

预期：零匹配。

- [ ] **步骤 4：跑测试和构建**

运行：

```bash
swift test --filter StateLabelTests
swift build
```

预期：测试通过；构建成功。

- [ ] **步骤 5：提交**

```bash
git add Sources/CoreDesign/Components/StateLabel/StateLabel.swift
git commit -m "docs: declare StateLabel Native Primer material/role"
```

---

## 任务 4：第 2C 阶段验收

**文件：**
- 验收：任务 1–3 修改过的所有文件。

- [ ] **步骤 1：跑全部测试**

运行：

```bash
swift test
```

预期：所有测试通过（含新增的 `TagTests`）。

- [ ] **步骤 2：构建**

运行：

```bash
swift build
```

预期：构建成功。

- [ ] **步骤 3：确认无 glass 泄漏**

运行：

```bash
rg "glassEffect|floatingGlass|circularGlass" Sources/CoreDesign/Components/Badge Sources/CoreDesign/Components/Tag Sources/CoreDesign/Components/StateLabel
```

预期：零匹配。

- [ ] **步骤 4：确认 Preview 仍存在**

运行：

```bash
rg "#Preview" Sources/CoreDesign/Components/Badge Sources/CoreDesign/Components/Tag Sources/CoreDesign/Components/StateLabel
```

预期：每个组件文件至少一个 `#Preview`。

- [ ] **步骤 5：工作区干净**

运行：

```bash
git status --short
```

预期：无未提交变更。

---

## 交接说明

- 本阶段完成后，spec §Phase 2 "Foundation Components" 即全部覆盖完毕
  （Button / AsyncButton / SegmentedControl / SearchField 在 2A；ListRow /
  SidebarRow / UnderlinedTabBar 在 2B；Badge / Tag / StateLabel 在 2C）。
- 不要给这三个组件引入 glass。它们是控件层的扫读元素 —— 颜色是承载者，
  装饰不是。
- `Tag.swift` 与 `Badge.swift` 中的 Tag ↔ Badge 边界文档是 load-bearing：
  调用方经常把两者混淆，那段文字会把他们引导到正确的组件上。请逐字保留。
- 如果未来的调用方需要一个带固定语义级别的彩色 chip（比如一个 "info" Tag），
  他们应该使用 `Badge`，而不是扩展 `Tag`。
