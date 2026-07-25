# Descriptions

描述列表 / Description list —— `.core` `LabeledContentStyle` + `InsetGroupedSection`
分组容器的组合，1/2 列排布，大字号可访问性档位下自动塌成单列。

## 为何不重造分组容器

`Descriptions` 不是一个独立实现的容器组件——它是**换皮组合**：分组卡片背景 / 圆角 /
分隔线视觉全部来自既有 `InsetGroupedSection`，行内 label/value 的配色来自新增的
`CoreLabeledContentStyle`（系统 `LabeledContent` 的 CoreDesign 皮肤，与
`CoreLabelStyle` / `CoreProgressViewStyle` / `CoreDisclosureGroupStyle` 同一形态）。
`Descriptions` 自身只做一件事：把调用方传入的若干 `LabeledContent` 行，按 1/2 列
重新分组，再交给 `InsetGroupedSection` 渲染。

**分隔线密度不靠重新实现分隔线来控制**：`InsetGroupedSection` 的分隔线逻辑是「相邻
顶层子视图之间插一条 `Separator`」（数量恒为「行数 − 1」）。`Descriptions` 通过控制
喂给它的顶层视图形状来间接控制分隔线——`.row` 密度下把每个行组作为独立顶层视图
（组间产生分隔线）；`.none` 密度下把所有行组包进同一个 `VStack`（对
`InsetGroupedSection` 而言只有 1 个顶层视图，天然产出 0 条分隔线）。两种密度都不
新写任何绘制分隔线的代码。

## API

### CoreLabeledContentStyle

| 成员 | 说明 |
|---|---|
| `LabeledContentStyle where Self == CoreLabeledContentStyle` | `.labeledContentStyle(.core)` |

重排系统 `LabeledContent` 的 `label` / `content`（不重新实现控件本身）：`label` 走
`Color.contentSecondary`（弱化），`content` 走 `Color.contentPrimary`（强化）——
描述列表惯例：字段名弱化、值强化。沿用「label leading、content trailing」的语义排布，
但几何由本 style 自建：`HStack(alignment: .firstTextBaseline)` + `CoreSpacing.sm` 间距 +
`Spacer(minLength:)` + 值侧 `.multilineTextAlignment(.trailing)`（重排 alignment 是 style
协议的正当用途，非「重造控件」）。

### Descriptions

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| columns | DescriptionsColumns | .two | 列数偏好：`.one` 单列 / `.two` 两列。大字号可访问性档位下会被强制覆盖为 `.one` |
| dividerDensity | DescriptionsDividerDensity | .row | 行（组）间分隔线密度：`.row` 每行之间都有 / `.none` 无分隔线 |
| header | LocalizedStringKey? | nil | 可选分组页眉，透传给内部 `InsetGroupedSection` |
| content | () -> Content | - | 描述列表的行，通常是若干 `LabeledContent` |

`columns == .two` 时，相邻两行配成一组、用 `Grid` 排布；行数为奇数时最后一行单独
成组、`.gridCellColumns(2)` 占满整行。`columns == .one` 时每行单独纵向排布，不套
`Grid`。列切分是纯函数（`DescriptionsLayout.rowGroups(rowCount:columns:)`），见
`Tests/CoreDesignTests/DescriptionsTests.swift`。

### 大字号塌列

`@Environment(\.dynamicTypeSize)` 读取当前字号档位；`dynamicTypeSize.isAccessibilitySize
== true` 时，无论调用方传入的 `columns` 是什么，都强制单列渲染
（`DescriptionsLayout.effectiveColumns`，纯函数）——这是可访问性优先于调用方偏好的
既定约束：两列在超大字号下会把每个 `LabeledContent` 挤到极窄的列宽，被迫大量换行，
可读性反而更差。

### 无障碍

每行 `LabeledContent` 天然带有系统无障碍语义（label + value 合成播报），`Descriptions`
不额外定制。

## 预览 / Preview

运行 `scripts/run-snapshots.sh` 后，预览图将生成于 `docs/snapshots/`。

## 使用示例 / Usage

```swift
Descriptions(header: "Order") {
    LabeledContent("Status") { Text("Active") }
    LabeledContent("Total") { Text("$42.00") }
    LabeledContent("Placed") { Text("2026-07-20") }
}

// 单列
Descriptions(columns: .one, header: "Contact") {
    LabeledContent("Name") { Text("Jane Appleseed") }
    LabeledContent("Email") { Text("jane@example.com") }
}

// 无分隔线
Descriptions(dividerDensity: .none, header: "Device") {
    LabeledContent("Model") { Text("iPhone 17 Pro") }
    LabeledContent("Storage") { Text("512 GB") }
}

// 独立套用 CoreLabeledContentStyle（不经 Descriptions）
LabeledContent("Status") { Text("Active") }
    .labeledContentStyle(.core)
```

## 视觉 Token

- 分组卡片背景 / 圆角 / 分隔线：全部继承 `InsetGroupedSection`（`Color.surfaceCard`、`CoreShape.rounded(CoreRadius.medium)`、`Separator`）
- 行内 label / content 配色：`Color.contentSecondary` / `Color.contentPrimary`
- 两列网格列间距：`CoreSpacing.lg`；行内 label ↔ content 最小间距：`CoreSpacing.sm`
- `.none` 密度下行组纵向间距：`CoreSpacing.md`
