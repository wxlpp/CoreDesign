# Native Primer 第 3C 阶段：Progress / Avatar / EmptyState 清理实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal（目标）：** 收尾 Native Primer 迁移：显式声明 `ProgressBar` / `ProgressIndicator` / `Avatar` / `AvatarGroup` 的 material/role、补上缺失的 `Avatar` 测试文件、并按规格 §Deprecated Components 把 `EmptyState` 从推荐 storybook / preview / 文档面下线。

**Architecture（架构）：** 这是 Phase 3 的最后一片。Progress 与 Avatar 组件已经符合内容层 / 控件层（content/control-layer）规范——工作量在于文档梳理加上把 `Avatar` 测试缺口补齐。`EmptyState` 的下线则更实质但有边界：源文件继续作为兼容包装层（Phase 1 已经把 API 标注为 deprecated）；本阶段移除 storybook 入口、移除应用内 preview、移除推荐组件文档、并消掉源文件内 `#Preview` 的 deprecation 警告，使整包可以重新通过 `-Xswiftc -warnings-as-errors` 构建。

**Tech Stack（技术栈）：** Swift 6.3、SwiftUI、Swift Testing、iOS 26 / macOS 26 package targets。

---

## 源规格

实施前请阅读：

- `docs/superpowers/specs/2026-05-14-native-primer-telegram-taste-design.md`（§Content Components、§Deprecated Components、§Phase 3）

本计划覆盖 Phase 3 剩余组件，以及分阶段下线 `EmptyState`：

- `ProgressBar` / `ProgressIndicator`
- `Avatar` / `AvatarGroup`
- 从推荐 storybook / preview / docs 中移除 `EmptyState`（源代码保留作为兼容包装层）

## File Structure（文件结构）

修改（仅 doc-comment 头部，不涉及行为变更）：

- `Sources/CoreDesign/Components/ProgressBar/ProgressBar.swift`
- `Sources/CoreDesign/Components/ProgressIndicator/ProgressIndicator.swift`
- `Sources/CoreDesign/Components/Avatar/Avatar.swift`
- `Sources/CoreDesign/Components/AvatarGroup/AvatarGroup.swift`

修改（把 EmptyState 从推荐面下线——源文件保留）：

- `App/Sources/ComponentData.swift`——把 `EmptyState` 条目从 storybook 注册表中移除，同时删掉 `EmptyStatePreview` 私有 wrapper。
- `App/Sources/Previews.swift`——移除 `#Preview("EmptyState")` 块。
- `Sources/CoreDesign/Components/EmptyState/EmptyState.swift`——删掉文件末尾的四个 `#Preview` 块（它们目前会触发 deprecation 警告，破坏 `-Xswiftc -warnings-as-errors`）。按规格 §Deprecated Components 要求，保留 public 类型与 deprecation 注解作为兼容包装层。
- `docs/README.md`——把组件索引表中的 `EmptyState` 行从列表中移除；在原位置加上一行“已废弃——请改用 `ContentUnavailableView`”。
- `docs/components/empty-state.md`——把内容替换成简短的废弃说明页，引导读者去 SwiftUI `ContentUnavailableView` / UIKit `UIContentUnavailableView`。

新建：

- `Tests/CoreDesignTests/AvatarTests.swift`（`AvatarGroupTests.swift` 已存在。）

只读：

- `Tests/CoreDesignTests/EmptyStateDeprecationTests.swift`——Phase 1 留下的编译期 deprecation 测试，必须保持绿。

不要删除：

- `Sources/CoreDesign/Components/EmptyState/EmptyState.swift`——按规格 §Deprecated Components 第 3 条，在当前大版本期间须保留为兼容包装层。

---

## 任务 1：ProgressBar Native Primer 声明

**文件：**
- 修改：`Sources/CoreDesign/Components/ProgressBar/ProgressBar.swift`

- [ ] **Step 1：基线现有测试**

运行：

```bash
swift test --filter ProgressBarTests
```

预期：测试通过。

- [ ] **Step 2：更新顶部 doc-comment 头部**

在 `Sources/CoreDesign/Components/ProgressBar/ProgressBar.swift` 中，找到 `public struct ProgressBar` 上方的 doc-comment，前置一段 Native Primer 头部。保留现有关于值截断（clamp）/ 非有限值（non-finite）规整的文档：

```swift
/// Native Primer progress bar.
///
/// Content-layer indicator. Practical readability over decoration: solid
/// track + fill, no glass, no gradients, no decorative material. Value is
/// clamped to `0...1` and non-finite inputs are sanitized to `0`.
///
/// **Material layer**: content. **Surface role**: content.
```

- [ ] **Step 3：确认无 glass 使用**

运行：

```bash
rg "glassEffect|floatingGlass|circularGlass" Sources/CoreDesign/Components/ProgressBar
```

预期：零匹配。

- [ ] **Step 4：跑测试和构建**

运行：

```bash
swift test --filter ProgressBarTests
swift build
```

预期：测试通过；构建成功。

- [ ] **Step 5：提交**

```bash
git add Sources/CoreDesign/Components/ProgressBar/ProgressBar.swift
git commit -m "docs: declare ProgressBar Native Primer material/role"
```

---

## 任务 2：ProgressIndicator Native Primer 声明

**文件：**
- 修改：`Sources/CoreDesign/Components/ProgressIndicator/ProgressIndicator.swift`

- [ ] **Step 1：基线现有测试**

运行：

```bash
swift test --filter ProgressIndicatorTests
```

预期：测试通过。

- [ ] **Step 2：更新顶部 doc-comment 头部**

在 `Sources/CoreDesign/Components/ProgressIndicator/ProgressIndicator.swift` 中，找到 `public struct ProgressIndicator` 上方的顶部 doc-comment，前置一段 Native Primer 头部：

```swift
/// Native Primer progress indicator.
///
/// Content-layer spinner / determinate indicator. Practical readability
/// over decoration: no glass, no decorative material. Use for in-page
/// loading states; for floating feedback use `Toast` instead.
///
/// **Material layer**: content. **Surface role**: content.
```

- [ ] **Step 3：确认无 glass 使用**

运行：

```bash
rg "glassEffect|floatingGlass|circularGlass" Sources/CoreDesign/Components/ProgressIndicator
```

预期：零匹配。

- [ ] **Step 4：跑测试和构建**

运行：

```bash
swift test --filter ProgressIndicatorTests
swift build
```

预期：测试通过；构建成功。

- [ ] **Step 5：提交**

```bash
git add Sources/CoreDesign/Components/ProgressIndicator/ProgressIndicator.swift
git commit -m "docs: declare ProgressIndicator Native Primer material/role"
```

---

## 任务 3：Avatar 覆盖率与声明

**文件：**
- 修改：`Sources/CoreDesign/Components/Avatar/Avatar.swift`
- 新建：`Tests/CoreDesignTests/AvatarTests.swift`

- [ ] **Step 1：写编译 / 行为测试**

新建 `Tests/CoreDesignTests/AvatarTests.swift`：

```swift
import SwiftUI
import Testing
@testable import CoreDesign

@Suite("Avatar")
struct AvatarTests {
    @MainActor
    @Test("avatar constructs with image and size")
    func avatarConstructsWithImageAndSize() {
        let avatar = Avatar(image: Image(systemName: "person.crop.circle"), size: 32)
        #expect(type(of: avatar) == Avatar.self)
    }

    @MainActor
    @Test("avatar constructs with initials")
    func avatarConstructsWithInitials() {
        let avatar = Avatar(initials: "EW", size: 32)
        #expect(type(of: avatar) == Avatar.self)
    }
}
```

> 如果 `Avatar` 的公开 init 签名与上面的调用不一致（例如参数名不同、用了
> `AvatarSize` 枚举而非裸 `CGFloat`，或者两个便利 init 只有其中一个），
> 请对齐实际签名。不要为了让测试能编译而修改公开 API。

- [ ] **Step 2：跑测试确认通过**

运行：

```bash
swift test --filter AvatarTests
```

预期：测试通过。

- [ ] **Step 3：更新顶部 doc-comment 头部**

在 `Sources/CoreDesign/Components/Avatar/Avatar.swift` 中，找到 `public struct Avatar` 上方的 doc-comment，前置一段 Native Primer 头部。保留现有关于 image / initials / 占位符的文档：

```swift
/// Native Primer avatar.
///
/// Content-layer identity affordance. Circular crop, restrained hairline
/// border, optional initials fallback. No glass — the avatar is a content
/// object inside lists / cards / headers.
///
/// **Material layer**: content. **Surface role**: content.
```

- [ ] **Step 4：确认无 glass 使用**

运行：

```bash
rg "glassEffect|floatingGlass|circularGlass" Sources/CoreDesign/Components/Avatar
```

预期：零匹配。

- [ ] **Step 5：跑测试和构建**

运行：

```bash
swift test --filter AvatarTests
swift build
```

预期：测试通过；构建成功。

- [ ] **Step 6：提交**

```bash
git add Sources/CoreDesign/Components/Avatar/Avatar.swift Tests/CoreDesignTests/AvatarTests.swift
git commit -m "test(Avatar): add compile tests; declare Native Primer role"
```

---

## 任务 4：AvatarGroup Native Primer 声明

**文件：**
- 修改：`Sources/CoreDesign/Components/AvatarGroup/AvatarGroup.swift`

- [ ] **Step 1：基线现有测试**

运行：

```bash
swift test --filter AvatarGroupTests
```

预期：测试通过。

- [ ] **Step 2：更新顶部 doc-comment 头部**

在 `Sources/CoreDesign/Components/AvatarGroup/AvatarGroup.swift` 中，找到 `public struct AvatarGroup` 上方的 doc-comment，前置一段 Native Primer 头部。保留现有关于重叠（overlap）/ 最大数量 / 溢出的文档：

```swift
/// Native Primer avatar group.
///
/// Content-layer composition of stacked `Avatar`s with overlap + overflow
/// counter. Same restraint rules as `Avatar`: no glass, hairline border,
/// quiet stacking. Use for participant lists, reviewers, contributors.
///
/// **Material layer**: content. **Surface role**: content.
```

- [ ] **Step 3：确认无 glass 使用**

运行：

```bash
rg "glassEffect|floatingGlass|circularGlass" Sources/CoreDesign/Components/AvatarGroup
```

预期：零匹配。

- [ ] **Step 4：跑测试和构建**

运行：

```bash
swift test --filter AvatarGroupTests
swift build
```

预期：测试通过；构建成功。

- [ ] **Step 5：提交**

```bash
git add Sources/CoreDesign/Components/AvatarGroup/AvatarGroup.swift
git commit -m "docs: declare AvatarGroup Native Primer material/role"
```

---

## 任务 5：从 Storybook 中移除 EmptyState

**文件：**
- 修改：`App/Sources/ComponentData.swift`
- 修改：`App/Sources/Previews.swift`

- [ ] **Step 1：基线 storybook 构建**

运行：

```bash
swift build
```

预期：构建成功。（开启 `-warnings-as-errors` 的版本仍会因为源文件里的 `#Preview` 块而失败；任务 6 会处理。）

- [ ] **Step 2：移除 storybook 条目**

在 `App/Sources/ComponentData.swift` 中，定位 `EmptyState` 注册项（大约在第 88 行——`id: "empty-state", name: "EmptyState", description: "空状态占位，可选 CTA 按钮"`，旁边还有对 `EmptyStatePreview()` 的引用，以及大约第 206 行处的 `private struct EmptyStatePreview` 声明）。删除：

- 引用 `id: "empty-state"` 的整个单条注册项。
- `private struct EmptyStatePreview: View { ... }` 声明及其函数体。

不要删除任何其它组件条目。

- [ ] **Step 3：移除独立 preview**

在 `App/Sources/Previews.swift` 中，删除 `#Preview("EmptyState") { ... }` 块（大约在第 79–80 行附近及其函数体）。

- [ ] **Step 4：跑构建**

运行：

```bash
swift build
```

预期：构建成功。（仍会有源文件内 preview 导致的 deprecation 警告；任务 6 会修。）

- [ ] **Step 5：提交**

```bash
git add App/Sources/ComponentData.swift App/Sources/Previews.swift
git commit -m "chore(storybook): remove EmptyState from registry + previews"
```

---

## 任务 6：移除 EmptyState 源文件内 Preview

**文件：**
- 修改：`Sources/CoreDesign/Components/EmptyState/EmptyState.swift`

- [ ] **Step 1：基线构建标记现有警告**

运行：

```bash
swift build -Xswiftc -warnings-as-errors 2>&1 | grep -A1 "EmptyState" | head -20
```

预期：四个 `#Preview` 块（light / dark 的 icon+title，light / dark 的 icon+title+description）上有 deprecation 警告。这就是本任务要消除的 warning-as-error 噪声。

- [ ] **Step 2：删除文件末尾的 `#Preview` 块**

在 `Sources/CoreDesign/Components/EmptyState/EmptyState.swift` 中，滚到文件末尾。删除四个 `#Preview("Light - icon + title only")`、`#Preview("Dark - icon + title only")`、`#Preview("Light - icon + title + description")`、`#Preview("Dark - icon + title + description")` 块。按规格 §Deprecated Components 第 3 条，源代码继续作为兼容包装层存在——不引入新的视觉样式——但推荐组件 preview 面要被移除。

> 保留 `public struct EmptyState` 和 `public init(...)` 声明完整不动，
> 包括 Phase 1 加上的 `@available(*, deprecated, ...)` 注解。
> 兼容包装层留下，只删掉 preview。

- [ ] **Step 3：重新跑 warnings-as-errors 构建**

运行：

```bash
swift build -Xswiftc -warnings-as-errors
```

预期：构建干净，`EmptyState.swift` preview 不再产生 deprecation 警告。

- [ ] **Step 4：跑 deprecation 测试**

运行：

```bash
swift test --filter EmptyStateDeprecationTests
```

预期：通过——Phase 1 的 deprecation 测试只验证 deprecated API 仍然**可调用**（编译期），不依赖 preview。

- [ ] **Step 5：提交**

```bash
git add Sources/CoreDesign/Components/EmptyState/EmptyState.swift
git commit -m "chore(EmptyState): remove in-file previews from deprecated compat wrapper"
```

---

## 任务 7：把 EmptyState 文档更新为废弃说明页

**文件：**
- 修改：`docs/README.md`
- 修改：`docs/components/empty-state.md`

- [ ] **Step 1：更新 `docs/README.md` 中的组件索引**

在 `docs/README.md` 中，定位包含 `| EmptyState |` 的表格行（大约第 41 行——目前是 snapshot 那一行）。把该行的描述 / 链接单元格替换，使条目变成：

```markdown
| EmptyState | _已废弃——请改用 SwiftUI `ContentUnavailableView` 或 UIKit `UIContentUnavailableView`。详见 [empty-state.md](components/empty-state.md)。_ |
```

保留该行在表格中的位置和其他行不动。不要把整行删掉——把它留作墓碑（tombstone）能给读者一条可被发现的迁移路径。

- [ ] **Step 2：把 `docs/components/empty-state.md` 重写为废弃说明页**

把 `docs/components/empty-state.md` 的全部内容替换为：

```markdown
# EmptyState（已废弃）

`EmptyState` 已废弃。请改用平台原生的 unavailable-content API：

- SwiftUI：[`ContentUnavailableView`](https://developer.apple.com/documentation/swiftui/contentunavailableview)
- UIKit：[`UIContentUnavailableView`](https://developer.apple.com/documentation/uikit/uicontentunavailableview)、
  [`UIContentUnavailableConfiguration`](https://developer.apple.com/documentation/uikit/uicontentunavailableconfiguration)

如果需要带操作按钮的样式，可把 `ContentUnavailableView` 与 CoreDesign 的按钮组合使用：

```swift
ContentUnavailableView {
    Label("No results", systemImage: "magnifyingglass")
} description: {
    Text("Try a different search.")
} actions: {
    Button("Clear filters") { ... }
        .buttonStyle(.solid())
}
```

## 状态

- Phase 1（2026-05）——API 标注 `@available(*, deprecated, ...)`。
- Phase 3C（本阶段）——从 storybook、preview、推荐组件索引中移除。
- 源代码继续作为当前大版本的兼容包装层保留，不再追加新的视觉样式。
- 真正删除推迟到下一次明确规划的破坏性变更周期。
```

- [ ] **Step 3：确认没有其它文档把旧 EmptyState 页面当作推荐组件引用**

运行：

```bash
rg "EmptyState" docs/ --type md
```

预期：只剩本任务写入的条目（`docs/README.md` 的墓碑行、`docs/components/empty-state.md` 的废弃说明页）以及规格 / plan 引用（这些是历史性的，保留）。

- [ ] **Step 4：提交**

```bash
git add docs/README.md docs/components/empty-state.md
git commit -m "docs(EmptyState): tombstone in index; rewrite component doc as deprecation page"
```

---

## 任务 8：Phase 3C 验收

**文件：**
- 验证：任务 1–7 改动过的所有文件。

- [ ] **Step 1：跑全部测试**

运行：

```bash
swift test
```

预期：所有测试通过（包括新增的 `AvatarTests` 和现有的 `EmptyStateDeprecationTests`）。

- [ ] **Step 2：跑 warnings-as-errors 构建**

运行：

```bash
swift build -Xswiftc -warnings-as-errors
```

预期：构建干净，**零**警告。原先 `EmptyState` 的 deprecation 噪声应该已经随着源文件内 preview 被删而消失。

- [ ] **Step 3：确认 progress + avatar 批次无 glass 泄漏**

运行：

```bash
rg "glassEffect|floatingGlass|circularGlass" Sources/CoreDesign/Components/ProgressBar Sources/CoreDesign/Components/ProgressIndicator Sources/CoreDesign/Components/Avatar Sources/CoreDesign/Components/AvatarGroup
```

预期：零匹配。

- [ ] **Step 4：确认 EmptyState 兼容包装层仍能编译**

运行：

```bash
swift test --filter EmptyStateDeprecationTests
```

预期：通过——兼容包装层 API 仍可调用。

- [ ] **Step 5：确认 storybook 不再暴露 EmptyState**

运行：

```bash
rg "EmptyState" App/Sources/
```

预期：零匹配。

- [ ] **Step 6：工作区干净**

运行：

```bash
git status --short
```

预期：没有未提交的改动。

---

## Handoff Notes（交接说明）

- 本阶段完成 Native Primer 迁移。落地后，规格
  §Phase 1、§Phase 2、§Phase 3 全部交付完毕。
- `EmptyState` 源代码须作为当前大版本的兼容包装层保留——**不要**删除文件。
  真正删除推迟到下一次明确规划的破坏性变更周期（规格 §Deprecated Components
  第 4 条）。
- 本阶段过后，`-Xswiftc -warnings-as-errors` 在整个 package 上应保持干净。
  之后若再出现新的 deprecation 警告，按构建阻断处理，不要当成噪音放过。
- 如果未来仍有调用方需要带操作按钮的样式化空状态，请按废弃说明页的指引把他们
  导向 `ContentUnavailableView` 配合 `.buttonStyle(.solid())`——不要扩展
  `EmptyState` 包装层。
