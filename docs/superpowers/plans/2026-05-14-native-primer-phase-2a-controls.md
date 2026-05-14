# Native Primer 第 2A 阶段控件实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**目标：** 把核心控件组件回归到 Native Primer 基线：朴素的非 glass 按钮、安静的原生 segmented control，以及内嵌式的原生搜索框。

**架构：** 第 1 阶段已建立共享的 surface role，并把按钮的 glass 改为按需启用。第 2A 阶段在不动导航行、Badge、Tag 或内容组件的前提下，把该基线应用到影响最大的控件组件上。视觉变化对内部封闭，公开 API 保持不变。

**技术栈：** Swift 6.3、SwiftUI、Swift Testing、iOS 26 / macOS 26 package target。

---

## 源规格

实施前必读：

- `docs/superpowers/specs/2026-05-14-native-primer-telegram-taste-design.md`

本计划只覆盖第 2 阶段的控件子集：

- Button / AsyncButton
- SegmentedControl
- SearchField

本计划不修改 `ListRow`、`SidebarRow`、`UnderlinedTabBar`、`Badge`、`Tag` 或 `StateLabel`。

## 文件结构

修改：

- `Sources/CoreDesign/Components/Button/styles/SolidButtonStyle.swift`
  - 把非 glass 默认背景调成符合 Native Primer 的实用控件外观。
  - 显式 `glass: true` 分支保持不变。
- `Sources/CoreDesign/Components/Button/styles/LightButtonStyle.swift`
  - 把非 glass 默认背景调成符合次级控件的实用外观。
  - 显式 `glass: true` 分支保持不变。
- `Sources/CoreDesign/Components/Button/AsyncButton.swift`
  - 仅当 preview/文档文案需要反映非 glass 默认样式时再更新。
  - 不修改 async 行为。
- `Sources/CoreDesign/Components/SegmentedControl/SegmentedControl.swift`
  - 把旧的 "no glass" Primer 文案改成 Native Primer 措辞。
  - 使用安静的 control surface + 略微抬升的选中 thumb。
  - 公开 API 保持不变。
- `Sources/CoreDesign/Components/SearchField/SearchField.swift`
  - 让容器对齐 `.surface(.control)` / 内嵌式控件处理。
  - 公开 API 保持不变，不加 glass。
- `Tests/CoreDesignTests/ButtonStyleDefaultTests.swift`
  - 视需要扩展已有的默认值测试。
- `Tests/CoreDesignTests/SegmentedControlTests.swift`
  - 新增针对 2 项 / 3 项构造的编译测试。
- `Tests/CoreDesignTests/SearchFieldTests.swift`
  - 新增针对构造的编译 / 行为测试。

---

## 任务 1：调整非 glass 按钮的默认外观

**文件：**
- 修改：`Sources/CoreDesign/Components/Button/styles/SolidButtonStyle.swift`
- 修改：`Sources/CoreDesign/Components/Button/styles/LightButtonStyle.swift`
- 修改：`Tests/CoreDesignTests/ButtonStyleDefaultTests.swift`

- [ ] **步骤 1：为非 glass 默认语义写具体测试**

扩展 `Tests/CoreDesignTests/ButtonStyleDefaultTests.swift`：

```swift
@Test("solid button style defaults to non-glass")
func solidDefaultsToNonGlass() {
    let style = SolidButtonStyle()
    #expect(style.glass == false)
}

@Test("light button style defaults to non-glass")
func lightDefaultsToNonGlass() {
    let style = LightButtonStyle()
    #expect(style.glass == false)
}

@Test("button style factories default to non-glass")
func buttonStyleFactoriesDefaultToNonGlass() {
    let solid: SolidButtonStyle = .solid()
    let light: LightButtonStyle = .light()

    #expect(solid.glass == false)
    #expect(light.glass == false)
}
```

这些测试直接构造具体 style struct，并通过显式类型上下文断言 `.solid()` / `.light()` 工厂便捷 API。SwiftUI 的 `ButtonStyle` 扩展返回值一旦传给 `.buttonStyle(...)` 就无法直接 introspect，所以工厂覆盖采用带类型的局部变量，而非 probe wrapper。

- [ ] **步骤 2：运行测试以验证当前行为**

执行：

```bash
swift test --filter ButtonStyleDefaultTests
```

预期：测试通过。视觉调整前先建立 guard。

- [ ] **步骤 3：调整 SolidButtonStyle 的非 glass modifier**

在 `Sources/CoreDesign/Components/Button/styles/SolidButtonStyle.swift` 中，把 `SolidButtonBackgroundModifier.body` 更新为：

```swift
func body(content: Content) -> some View {
    content
        .background(
            Capsule(style: .continuous)
                .fill(self.backgroundColor)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.borderMuted, lineWidth: CoreBorderWidth.hairline)
        )
        .scaleEffect(self.isPressed ? CoreButtonMetrics.pressedScale : 1)
        .opacity(self.isPressed ? 0.92 : 1)
        .animation(.snappy(duration: 0.16), value: self.isPressed)
}
```

理由：默认的 solid 样式应该是一个实用的 control surface，而不是一个漂浮 / 抬升的控件。需要抬升 / 漂浮效果时仍可显式使用 `glass: true`。

- [ ] **步骤 4：调整 LightButtonStyle 的非 glass modifier**

在 `Sources/CoreDesign/Components/Button/styles/LightButtonStyle.swift` 中，把 `LightButtonBackgroundModifier.body` 更新为：

```swift
func body(content: Content) -> some View {
    content
        .background(
            Capsule(style: .continuous)
                .fill(Color.surfaceInteractive)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.borderSubtle, lineWidth: CoreBorderWidth.hairline)
        )
        .scaleEffect(self.isPressed ? CoreButtonMetrics.pressedScale : 1)
        .animation(.snappy(duration: 0.16), value: self.isPressed)
}
```

理由：去除次级控件的默认抬升感，同时保留按压反馈。

- [ ] **步骤 5：运行定向测试**

执行：

```bash
swift test --filter ButtonStyleDefaultTests
swift test --filter AsyncButton
swift test --filter CoreButtonMetrics
```

预期：所有测试通过。

- [ ] **步骤 6：提交**

```bash
git add Sources/CoreDesign/Components/Button/styles/SolidButtonStyle.swift Sources/CoreDesign/Components/Button/styles/LightButtonStyle.swift Tests/CoreDesignTests/ButtonStyleDefaultTests.swift
git commit -m "refactor: quiet default button surfaces"
```

---

## 任务 2：把 SegmentedControl 回归 Native Primer 控件外观

**文件：**
- 修改：`Sources/CoreDesign/Components/SegmentedControl/SegmentedControl.swift`
- 新建：`Tests/CoreDesignTests/SegmentedControlTests.swift`

> **计划修订（2026-05-14，第 2A 阶段复盘）：** 实际落地的实现引入了一个可选启用的
> `glass: Bool = true` 参数，以及一条针对 iOS 26 的原生 UIKit Glass 路径
> （`NativeGlassSegmentedControl` + `UIGlassEffect` + `ImmediateFeedbackSegmentedControl`），
> 当 `glass == false` 时以及在 macOS 上则走安静的 SwiftUI 回退路径。下文的 doc-comment、
> body 与选中 thumb 片段早于该改动 —— 当前的分支行为以源码为准。步骤 5 中
> "不使用 Liquid Glass" 的禁令已不再适用；现在 glass 是默认值，非 glass
> 路径才采用此处描述的 control surface。

- [ ] **步骤 1：写编译 / 行为测试**

创建 `Tests/CoreDesignTests/SegmentedControlTests.swift`：

```swift
import SwiftUI
import Testing
@testable import CoreDesign

@Suite("SegmentedControl")
struct SegmentedControlTests {
    @MainActor
    @Test("segmented control constructs with two items")
    func segmentedControlConstructsWithTwoItems() {
        let selection = Binding.constant("One")
        let control = SegmentedControl(
            items: ["One", "Two"],
            selection: selection,
            title: { $0 }
        )

        #expect(type(of: control) == SegmentedControl<String>.self)
    }

    @MainActor
    @Test("segmented control constructs with three items")
    func segmentedControlConstructsWithThreeItems() {
        let selection = Binding.constant("A")
        let control = SegmentedControl(
            items: ["A", "B", "C"],
            selection: selection,
            title: { $0 }
        )

        #expect(type(of: control) == SegmentedControl<String>.self)
    }
}
```

- [ ] **步骤 2：实现前先跑测试**

执行：

```bash
swift test --filter SegmentedControlTests
```

预期：测试通过。在视觉调整前提供一个编译保持基线。

- [ ] **步骤 3：更新文档注释**

在 `Sources/CoreDesign/Components/SegmentedControl/SegmentedControl.swift` 中，把旧注释里 "复刻 Primer thumb" 和 "不使用 `.glassEffect`" 的措辞换成 Native Primer 语言：

```swift
/// Native Primer segmented control.
///
/// The component keeps GitHub-like utility and density while rendering as an
/// Apple-native control surface. The base stays quiet; only the selected segment
/// gets a lightly raised thumb. This is a control-layer component, so it does
/// not use Liquid Glass by default.
```

其余 API 文档保持简洁与准确。

- [ ] **步骤 4：更新 body 的表面处理**

在 `body` 中，把当前的 `.background` 替换成带细微 border 的 control surface：

```swift
.background(
    RoundedRectangle(cornerRadius: CoreRadius.medium, style: .continuous)
        .fill(Color.surfaceInteractive)
)
.overlay(
    RoundedRectangle(cornerRadius: CoreRadius.medium, style: .continuous)
        .strokeBorder(Color.borderSubtle, lineWidth: CoreBorderWidth.hairline)
)
```

保留：

```swift
.padding(CoreSpacing.xxs)
.frame(height: CoreControlMetrics.height(for: .regular))
.sensoryFeedback(.selection, trigger: self.selection)
```

- [ ] **步骤 5：更新选中 thumb**

在 `segment(for:)` 中，把选中 thumb 的填充由 `Color.surfaceRaised` 改为 `Color.surfaceCanvas`，并保留小阴影：

```swift
RoundedRectangle(cornerRadius: CoreRadius.small, style: .continuous)
    .fill(Color.surfaceCanvas)
    .overlay {
        RoundedRectangle(cornerRadius: CoreRadius.small, style: .continuous)
            .strokeBorder(Color.borderSubtle, lineWidth: CoreBorderWidth.hairline)
    }
    .coreShadow(.small)
    .matchedGeometryEffect(id: "SegmentedControl.thumb", in: self.namespace)
```

注（计划修订）：实际落地的代码只在 `glass == false` / macOS 回退路径上保留这种
control-surface 处理。默认的 `glass == true` 路径用的是 Liquid Glass 外壳——
参见文件顶部 "计划修订" 提示框中的上下文。

- [ ] **步骤 6：运行测试**

执行：

```bash
swift test --filter SegmentedControlTests
swift test
```

预期：所有测试通过。

- [ ] **步骤 7：提交**

```bash
git add Sources/CoreDesign/Components/SegmentedControl/SegmentedControl.swift Tests/CoreDesignTests/SegmentedControlTests.swift
git commit -m "refactor: reset segmented control surface"
```

---

## 任务 3：让 SearchField 对齐 control surface 规则

**文件：**
- 修改：`Sources/CoreDesign/Components/SearchField/SearchField.swift`
- 新建：`Tests/CoreDesignTests/SearchFieldTests.swift`

- [ ] **步骤 1：写编译测试**

创建 `Tests/CoreDesignTests/SearchFieldTests.swift`：

```swift
import SwiftUI
import Testing
@testable import CoreDesign

@Suite("SearchField")
struct SearchFieldTests {
    @MainActor
    @Test("search field constructs with default placeholder")
    func searchFieldConstructsWithDefaultPlaceholder() {
        let field = SearchField(text: .constant(""))
        #expect(type(of: field) == SearchField.self)
    }

    @MainActor
    @Test("search field constructs with submit handler")
    func searchFieldConstructsWithSubmitHandler() {
        let field = SearchField(text: .constant("query"), placeholder: "Filter") { _ in }

        #expect(type(of: field) == SearchField.self)
    }
}
```

- [ ] **步骤 2：实现前先跑测试**

执行：

```bash
swift test --filter SearchFieldTests
```

预期：测试通过。提供一个编译保持基线。

- [ ] **步骤 3：更新文档注释**

在 `Sources/CoreDesign/Components/SearchField/SearchField.swift` 中，把顶部注释由 "GitHub Primer 风格" 改为 Native Primer 措辞：

```swift
/// Native Primer search field.
///
/// A compact Apple-native search/filter control with GitHub-like utility:
/// leading search icon, optional clear action, clear focus ring, and no default
/// Liquid Glass.
```

参数文档保持准确。

- [ ] **步骤 4：更新形状半径与填充**

把：

```swift
let shape = RoundedRectangle(cornerRadius: CoreRadius.medium, style: .continuous)
```

改为：

```swift
let shape = RoundedRectangle(cornerRadius: CoreRadius.small, style: .continuous)
```

把背景填充由：

```swift
shape.fill(Color.surfaceCanvasInset)
```

改为：

```swift
shape.fill(Color.surfaceInteractive)
```

把 focus ring 圆角由 `CoreRadius.medium` 改为 `CoreRadius.small`。

理由：SearchField 属于 control-layer 组件。它应当看起来像一个紧凑的原生输入控件，而不是一张圆角卡片。

- [ ] **步骤 5：运行测试**

执行：

```bash
swift test --filter SearchFieldTests
swift test
```

预期：所有测试通过。

- [ ] **步骤 6：提交**

```bash
git add Sources/CoreDesign/Components/SearchField/SearchField.swift Tests/CoreDesignTests/SearchFieldTests.swift
git commit -m "refactor: align search field control surface"
```

---

## 任务 4：第 2A 阶段验证

**文件：**
- 验证：任务 1–3 涉及的全部文件

- [ ] **步骤 1：运行全部测试**

执行：

```bash
swift test
```

预期：所有测试通过。

- [ ] **步骤 2：运行构建**

执行：

```bash
swift build
```

预期：构建成功。

- [ ] **步骤 3：检查 control-layer 组件中是否误用 Liquid Glass**

执行：

```bash
rg "glassEffect|floatingGlass|circularGlass" Sources/CoreDesign/Components/SegmentedControl Sources/CoreDesign/Components/SearchField Sources/CoreDesign/Components/Button/styles
```

预期：

- `SegmentedControl` 出现匹配是预期且允许的：实际落地的组件在
  `glass == true` 分支（SwiftUI 回退路径与 iOS 26 原生 UIKit Glass 路径）上
  使用 `.glassEffect`。把匹配项视为 "glass 仍被关在该分支后面" 的一次健全性检查，
  而不是一次违规。
- `SearchField` 无匹配。
- Button style 的匹配仅允许出现在显式 `glass == true` 分支中，或 `.circularGlass` 中。

- [ ] **步骤 4：检查改动相关的 preview 仍存在**

执行：

```bash
rg "#Preview|Solid — default|Light — default|SegmentedControl|SearchField" Sources/CoreDesign/Components/Button Sources/CoreDesign/Components/SegmentedControl Sources/CoreDesign/Components/SearchField
```

预期：按钮样式、segmented control、search field 的 preview 仍在。

- [ ] **步骤 5：确认状态干净**

执行：

```bash
git status --short
```

预期：没有未提交的变更。

---

## 交接说明

- 本计划刻意不动 navigation / content / status 组件。
- 不要为 `.solid` 或 `.light` 重新引入默认 glass。
- 不要给 `SearchField` 加 Liquid Glass。
- `SegmentedControl` 出厂为 `glass: Bool = true`（见任务 2 的 "计划修订" 提示框）。
  路径矩阵：
  - iOS + `glass == true` → `NativeGlassSegmentedControl`（UIKit `UIGlassEffect`）。
  - iOS + `glass == false` → SwiftUI 路径走 `glass == false` 分支（安静的
    control surface，无 `glassEffect`）。
  - macOS（无论 `glass` 取值）→ SwiftUI 路径；该 modifier 尊重 `glass`，所以
    在 macOS 上默认 `glass == true` 仍是 Liquid Glass 表面。
  - 若要在 macOS 强制安静表面，请显式传入 `glass: false`。
- 后续视觉评审若发现 search field 过于扁平，先在 control-layer token 内调整；不要让它变成 floating glass。
