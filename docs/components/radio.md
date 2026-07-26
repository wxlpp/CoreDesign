# Radio

单选组 / Mutually-exclusive selection group，与 `Components/CheckBox/`（`CheckBoxToggleStyle`）视觉成对。

`RadioGroup<SelectionValue>` 由 `Binding<SelectionValue>` 驱动，渲染一组 `RadioOption`；点击任意一行即把 `selection` 更新为该行的 `value`，其余行随之切换为未选中态。

## API

### `RadioOption<SelectionValue: Hashable & Sendable>`

纯数据结构，`Identifiable`（`id == value`）。

| 参数 | 类型 | 说明 |
|---|---|---|
| value | SelectionValue | 该选项代表的选中值 |
| title | String | 选项标题，运行期字符串，直接展示，不经 `Localizable.strings` |

### `RadioGroup<SelectionValue: Hashable & Sendable>`

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| selection | Binding\<SelectionValue\> | - | 当前选中值 |
| options | [RadioOption\<SelectionValue\>] | - | 全部候选项，按传入顺序渲染 |
| axis | Axis | `.vertical` | 排列方向：`.vertical` 纵向堆叠，`.horizontal` 横向排列 |
| spacing | CGFloat | `CoreSpacing.sm` | 选项间距 |

## 预览 / Preview

运行 `scripts/run-snapshots.sh`（默认模式）后，预览图落地 `docs/snapshots/`——但前提是该组件已在 `App/Sources/Previews.swift` 注册（导出文件名形如 `CoreDesignPreview_<组件名>.png`）；组件源码内自带的 `#Preview` 仅用于开发期本地预览，或经 `KEEP_LIBRARY_SNAPSHOTS=1 scripts/run-snapshots.sh` 导出到本地 scratch 目录做逐组件视觉核对（不写入 docs/snapshots，见 `.claude/epics/semi-mobile-components/phase0-decisions.md` §3）。

## 使用示例 / Usage

```swift
struct PlanPicker: View {
    @State private var selection = "basic"

    var body: some View {
        RadioGroup(
            selection: $selection,
            options: [
                RadioOption(value: "basic", title: "基础版"),
                RadioOption(value: "pro", title: "专业版"),
                RadioOption(value: "enterprise", title: "企业版"),
            ]
        )
    }
}

// 水平排列
RadioGroup(
    selection: $sizeSelection,
    options: [
        RadioOption(value: 1, title: "小"),
        RadioOption(value: 2, title: "中"),
        RadioOption(value: 3, title: "大"),
    ],
    axis: .horizontal
)
```

`SelectionValue` 可以是任意 `Hashable & Sendable` 类型（`String` / `Int` / 自定义 `enum` 均可），选中判断走值相等（`option.value == selection`），不额外引入公开的"选中/未选中"状态枚举。

## 视觉 Token（与 CheckBox 成对）

- 选中态：`largecircle.fill.circle` SF Symbol，`Color.contentPrimary`
- 未选中态：`circle` SF Symbol，`Color.contentSecondary`
- 图标字号：`CoreControlMetrics.iconSize(for: .regular)`（16pt），与 `CheckBoxToggleStyle` 一致
- 图标 ↔ 文字间距：`CoreSpacing.sm`
- 命中区：`.frame(minHeight: CoreControlMetrics.height(for: .regular))`（44pt 地板）+ `.contentShape(Rectangle())`，复刻 `CheckBoxToggleStyle` 的手法——单靠 icon + label 的 intrinsic 高度会远低于 44pt，需要显式撑高整行命中区
- 选中切换动画：`.animation(.easeOut(duration: 0.25), value:)`，与 CheckBox 一致
- 无障碍：每个选项 `.accessibilityElement(children: .combine)` + `.accessibilityAddTraits(.isButton)`，选中项额外带 `.isSelected`；圆点图标本身纯装饰、`.accessibilityHidden(true)`，避免 SF Symbol 隐式 label（如 "circle"）混入朗读结果

> **不响应 `.tint`**：与本仓库 Phase 2 的 `.core` style 系统控件（`ProgressView`/`Label`/`DisclosureGroup`，见 `docs/components/core-control-styles.md`）不同，`RadioGroup` 的选中态颜色**固定用 `Color.contentPrimary`**，不经 `TintShapeStyle`——调用方 `.tint(_:)` 对它不生效。这是与 `CheckBoxToggleStyle` 视觉配对的显式取舍（两者都不引入强调色语义），而非疏漏；需要强调色响应的场景应换用系统 `Picker`/`Toggle` + `.tint`。

## 取舍：为何不用 `.pickerStyle(.radioGroup)`

SwiftUI 在 macOS 上原生提供 `Picker` + `.pickerStyle(.radioGroup)`，是 Apple 官方更推荐的 radio 实现路径。但该 style **仅 macOS 可用**，iOS/iPadOS 没有对应渲染，且其视觉（系统原生单选圆钮）与本仓库已有的 `CheckBoxToggleStyle`（手写方框 + SF Symbol）语汇不一致。

CoreDesign 的 Semi 组件集里 Radio 与 CheckBox 是并列的表单控件——为保持跨端（iOS/macOS 同一套视觉）一致，以及与既有 CheckBox 语汇（icon-swap 手法、`Color.contentPrimary`/`Color.contentSecondary` 取色、44pt 命中区手法）延续，`RadioGroup` 复刻 `CheckBoxToggleStyle` 的手写实现，只把方框图标换成 Semi 风格的圆点图标（`circle` / `largecircle.fill.circle`），而不采用 `.pickerStyle(.radioGroup)`。
