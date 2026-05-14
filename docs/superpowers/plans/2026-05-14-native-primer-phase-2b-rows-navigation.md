# Native Primer 第 2B 阶段行与导航实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**目标：** 把行与导航组件对齐到 Native Primer 基线——内容层（content layer）的 `ListRow`、控件层（control layer）的 `SidebarRow`、以及外壳层（chrome layer）的 `UnderlinedTabBar`——既不引入 glass，也不卡片化。

**架构：** 第 2A 阶段已重置 Button / SegmentedControl / SearchField。第 2B 阶段把同样的 content / control 层规则套到行与导航组件上。公开 API 冻结；视觉变化局限于内部的 token 替换和少量注释更新。在缺失覆盖时补充编译 / 行为测试。

**技术栈：** Swift 6.3、SwiftUI、Swift Testing、iOS 26 / macOS 26 package target。

---

## 源规格

实施前必读：

- `docs/superpowers/specs/2026-05-14-native-primer-telegram-taste-design.md`

本计划只覆盖第 2 阶段的行 + 导航子集：

- `ListRow`（content layer）
- `SidebarRow`（control layer，导航）
- `UnderlinedTabBar`（control layer，chrome）

本计划不修改 `Badge`、`Tag`、`StateLabel`（第 2C 阶段）或任何第 3 阶段组件。

## 文件结构

修改：

- `Sources/CoreDesign/Components/ListRow/ListRow.swift`
  - 验证 content-layer 行为；把 doc-comment 调成 Native Primer 措辞。
  - 公开 API 保持不变。不加 glass。不默认卡片化。
- `Sources/CoreDesign/Components/SidebarRow/SidebarRow.swift`
  - 验证选中 / 悬停语义；更新 doc-comment 标明 control-layer 角色。
  - 公开 API 保持不变。不加全局 glass。
- `Sources/CoreDesign/Components/TabBar/UnderlinedTabBar.swift`
  - 把 doc-comment 换成 Native Primer 措辞；确认没有使用 `.glassEffect`。
  - 公开 API 保持不变。

新建：

- `Tests/CoreDesignTests/ListRowTests.swift`
- `Tests/CoreDesignTests/SidebarRowTests.swift`
- `Tests/CoreDesignTests/UnderlinedTabBarTests.swift`

只读：

- `docs/superpowers/plans/2026-05-14-native-primer-phase-2a-controls.md`
  - 用于参照计划风格与 Native Primer doc-comment 措辞。

---

## 任务 1：ListRow 的 Native Primer 基线

**文件：**
- 修改：`Sources/CoreDesign/Components/ListRow/ListRow.swift`
- 新建：`Tests/CoreDesignTests/ListRowTests.swift`

- [ ] **步骤 1：写编译 / 行为测试**

创建 `Tests/CoreDesignTests/ListRowTests.swift`：

```swift
import SwiftUI
import Testing
@testable import CoreDesign

@Suite("ListRow")
struct ListRowTests {
    @MainActor
    @Test("list row constructs with label only")
    func listRowConstructsWithLabelOnly() {
        let row = ListRow(label: { Text("Item") })
        #expect(type(of: row) == ListRow<EmptyView, EmptyView, Text>.self)
    }

    @MainActor
    @Test("list row constructs with leading and trailing")
    func listRowConstructsWithLeadingAndTrailing() {
        let row = ListRow(
            leading: { Image(systemName: "doc") },
            trailing: { Text(">") },
            label: { Text("Item") }
        )
        #expect(type(of: row) == ListRow<Image, Text, Text>.self)
    }
}
```

- [ ] **步骤 2：运行测试以验证通过**

执行：

```bash
swift test --filter ListRowTests
```

预期：测试通过。提供一个编译保持基线。

- [ ] **步骤 3：更新 doc-comment 头部**

在 `Sources/CoreDesign/Components/ListRow/ListRow.swift` 中，把 `public struct ListRow` 上方现有顶部 doc-comment 替换为 Native Primer 措辞。保留现有的 "Hover token debt" 段落——它记录了一处已知 token 缺口，应保留：

```swift
/// Native Primer list row.
///
/// Content-layer component. Stays quiet, scannable, and stable: no default
/// glass, no default cardification. Hover and selected states use restrained
/// fills (`Color.surfaceCanvasSubtle`) and the default background sits on
/// `View.surface(.canvas)`.
///
/// **Material layer**: content. **Surface role**: canvas.
///
/// // 保留原有 "Hover token debt" 段落（解释 surfaceCanvasSubtle 的取值层取舍）。
```

其余 API 文档（参数说明、示例）保持不变。

- [ ] **步骤 4：确认未使用 glass**

执行：

```bash
rg "glassEffect|floatingGlass|circularGlass" Sources/CoreDesign/Components/ListRow
```

预期：零匹配。

- [ ] **步骤 5：运行测试与构建**

执行：

```bash
swift test --filter ListRowTests
swift build
```

预期：测试通过；构建成功。

- [ ] **步骤 6：提交**

```bash
git add Sources/CoreDesign/Components/ListRow/ListRow.swift Tests/CoreDesignTests/ListRowTests.swift
git commit -m "refactor: align ListRow to Native Primer content baseline"
```

---

## 任务 2：SidebarRow 的 Native Primer 导航形态

**文件：**
- 修改：`Sources/CoreDesign/Components/SidebarRow/SidebarRow.swift`
- 新建：`Tests/CoreDesignTests/SidebarRowTests.swift`

- [ ] **步骤 1：写编译 / 行为测试**

创建 `Tests/CoreDesignTests/SidebarRowTests.swift`：

```swift
import SwiftUI
import Testing
@testable import CoreDesign

@Suite("SidebarRow")
struct SidebarRowTests {
    @MainActor
    @Test("sidebar row constructs unselected")
    func sidebarRowConstructsUnselected() {
        let row = SidebarRow(isSelected: false) {
            Text("Inbox")
        }
        #expect(type(of: row) == SidebarRow<Text>.self)
    }

    @MainActor
    @Test("sidebar row constructs selected")
    func sidebarRowConstructsSelected() {
        let row = SidebarRow(isSelected: true) {
            Text("Inbox")
        }
        #expect(type(of: row) == SidebarRow<Text>.self)
    }
}
```

- [ ] **步骤 2：运行测试以验证通过**

执行：

```bash
swift test --filter SidebarRowTests
```

预期：测试通过。

- [ ] **步骤 3：更新 doc-comment 头部**

在 `Sources/CoreDesign/Components/SidebarRow/SidebarRow.swift` 中，把 `public struct SidebarRow` 上方现有顶部 doc-comment 替换为 Native Primer 措辞。保留现有的 "Hover token debt" 段落与 accent-bar 规范——这些是不显然的设计决策，值得保留：

```swift
/// Native Primer sidebar row.
///
/// Control-layer navigation component. Selected state is unmistakable but
/// low-noise: a 2pt left-edge `borderFocus` accent bar plus a quiet
/// `Color.surfaceCanvasSubtle` background. No global glass treatment — the
/// parent container's `surface(.sidebar)` provides the chrome.
///
/// **Material layer**: control. **Surface role**: control.
///
/// // 保留原有的 selected-over-hover 优先级说明、accent-bar 厚度规范（2pt
/// // per CoreBorderWidth.thick），以及 "Hover token debt" 段落（surfaceCanvasSubtle
/// // 的取值层取舍）。
```

参数文档与 "selected accent bar" 规范保持原样。

- [ ] **步骤 4：确认未使用 glass**

执行：

```bash
rg "glassEffect|floatingGlass|circularGlass" Sources/CoreDesign/Components/SidebarRow
```

预期：零匹配。

- [ ] **步骤 5：运行测试与构建**

执行：

```bash
swift test --filter SidebarRowTests
swift build
```

预期：测试通过；构建成功。

- [ ] **步骤 6：提交**

```bash
git add Sources/CoreDesign/Components/SidebarRow/SidebarRow.swift Tests/CoreDesignTests/SidebarRowTests.swift
git commit -m "refactor: align SidebarRow to Native Primer control baseline"
```

---

## 任务 3：UnderlinedTabBar 的 Native Primer 外壳形态

**文件：**
- 修改：`Sources/CoreDesign/Components/TabBar/UnderlinedTabBar.swift`
- 新建：`Tests/CoreDesignTests/UnderlinedTabBarTests.swift`

- [ ] **步骤 1：写编译 / 行为测试**

创建 `Tests/CoreDesignTests/UnderlinedTabBarTests.swift`：

```swift
import SwiftUI
import Testing
@testable import CoreDesign

@Suite("UnderlinedTabBar")
struct UnderlinedTabBarTests {
    @MainActor
    @Test("tab bar constructs with two items")
    func tabBarConstructsWithTwoItems() {
        let selection = Binding.constant("A")
        let bar = UnderlinedTabBar(
            items: ["A", "B"],
            selection: selection,
            title: { $0 }
        )

        #expect(String(describing: type(of: bar)).contains("UnderlinedTabBar"))
    }

    @MainActor
    @Test("tab bar constructs with three items")
    func tabBarConstructsWithThreeItems() {
        let selection = Binding.constant("Issues")
        let bar = UnderlinedTabBar(
            items: ["Issues", "PRs", "Discussions"],
            selection: selection,
            title: { $0 }
        )

        #expect(String(describing: type(of: bar)).contains("UnderlinedTabBar"))
    }
}
```

> **注：** `UnderlinedTabBar` 是泛型，参数为 `Item` 与 `Trailing`。基于
> closure 的 init 可能把 `Trailing` 默认推断为 `EmptyView`。`contains` 检查
> 与具体的泛型擦除形式无关；如果步骤 2 显示有唯一的具体 initializer
> 签名，可收紧为 `type(of: bar) == UnderlinedTabBar<String, EmptyView>.self`。

- [ ] **步骤 2：运行测试以验证通过**

执行：

```bash
swift test --filter UnderlinedTabBarTests
```

预期：测试通过。若类型不匹配导致失败，按失败信息里显示的真实泛型擦除形式调整断言。

- [ ] **步骤 3：更新 doc-comment 头部**

在 `Sources/CoreDesign/Components/TabBar/UnderlinedTabBar.swift` 中，把 `public struct UnderlinedTabBar` 上方现有顶部 doc-comment 替换为 Native Primer 措辞。现有注释已说明不用 `.glassEffect`——保留这层意图，只换措辞：

```swift
/// Native Primer underlined tab bar.
///
/// Control-layer chrome for primary navigation. Selected tab is marked by a
/// short, low-noise underline (`borderFocus` token) plus active label
/// emphasis. No global glass treatment — the host scene supplies the
/// background, this component supplies the indicator and labels.
///
/// **Material layer**: control. **Surface role**: control.
///
/// Per the Native Primer baseline, navigation chrome does not use Liquid
/// Glass; selected states stay typographic + line-based (see spec §Controls).
```

参数文档与 trailing-content 支持保持原样。

- [ ] **步骤 4：确认未使用 glass**

执行：

```bash
rg "glassEffect|floatingGlass|circularGlass" Sources/CoreDesign/Components/TabBar
```

预期：零匹配。如 `UnderlinedTabBar.swift` 中出现匹配（应当只剩文档引用），将其移除。

- [ ] **步骤 5：运行测试与构建**

执行：

```bash
swift test --filter UnderlinedTabBarTests
swift build
```

预期：测试通过；构建成功。

- [ ] **步骤 6：提交**

```bash
git add Sources/CoreDesign/Components/TabBar/UnderlinedTabBar.swift Tests/CoreDesignTests/UnderlinedTabBarTests.swift
git commit -m "refactor: align UnderlinedTabBar to Native Primer chrome"
```

---

## 任务 4：第 2B 阶段验证

**文件：**
- 验证：任务 1–3 涉及的全部文件。

- [ ] **步骤 1：运行全部测试**

执行：

```bash
swift test
```

预期：所有测试通过（包括三个新建的测试文件）。

- [ ] **步骤 2：运行构建**

执行：

```bash
swift build
```

预期：构建成功。

- [ ] **步骤 3：确认 glass 未渗入第 2B 阶段组件**

执行：

```bash
rg "glassEffect|floatingGlass|circularGlass" Sources/CoreDesign/Components/ListRow Sources/CoreDesign/Components/SidebarRow Sources/CoreDesign/Components/TabBar
```

预期：零匹配。这三者都不是 floating-layer 表面。

- [ ] **步骤 4：确认 preview 仍存在**

执行：

```bash
rg "#Preview" Sources/CoreDesign/Components/ListRow Sources/CoreDesign/Components/SidebarRow Sources/CoreDesign/Components/TabBar
```

预期：每个组件文件至少保留一个 `#Preview`。

- [ ] **步骤 5：状态干净**

执行：

```bash
git status --short
```

预期：没有未提交的变更。

---

## 交接说明

- 本计划刻意不动第 2C 阶段（`Badge`、`Tag`、`StateLabel`）或任何第 3 阶段组件。
- 不要给 `ListRow`、`SidebarRow`、`UnderlinedTabBar` 中任一个引入默认 glass——按规格 §Component Direction，它们属于 content / control 层。
- `ListRow` 与 `SidebarRow` 都标注了一项相对 Primer `bgColor.muted` 的
  "Hover token debt"——请原样保留这些注释；它们是已知 token 缺口的承重文档，
  而非过期文字。
- 后续视觉评审若发现某种行处理过于扁平或过于嘈杂，请优先在已有 control-layer
  token 内调整，而不是加 glass。
