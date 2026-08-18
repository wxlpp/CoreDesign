# RatingDisplay

只读评分展示 / Read-only rating indicator.

`Rating` 的兄弟组件——**拆的是 control vs indicator 的交互语义，不是外观变体**
（Apple 自己就是这么分的：`Slider` vs `ProgressView`、`Toggle` vs 只读标签）。
证据是两者**共用同一个 `RatingStyle`**：外观候选并没有被兄弟组件消化掉，扩展点照样存在。

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| value | Double | - | 要展示的评分（可含小数——半星由小数部分表达） |
| count | Int | 5 | 档位总数；负数会被 clamp 到 0 |

无 binding、无手势、无 `accessibilityAdjustableAction`——它恒不可交互。

## 为什么不是 `Rating(isReadOnly: true)`

归并方案（删 `isReadOnly`、统一走 `.disabled(true)`）会让所有展示态评分走 SwiftUI 原生
disabled 视觉——**变灰 + 降低对比度**，语义是「这个控件现在不能用」。而展示态（列表里
显示某本书的评分）不是「不能用」，是「本来就不是控件」。归并是**语义错配导致的视觉回归**，
不是 API 收敛。拆分后「控制展示态的路径」只剩一条：**选哪个类型**；`isEnabled` 回归它
原本的语义（控件可用性），不再兼任展示态开关。

## 预览 / Preview

运行 `scripts/run-snapshots.sh`（默认模式）后，预览图落地 `docs/snapshots/`——但前提是该组件已在 `App/Sources/Previews.swift` 注册（导出文件名形如 `CoreDesignPreview_<组件名>.png`）；组件源码内自带的 `#Preview` 仅用于开发期本地预览，或经 `KEEP_LIBRARY_SNAPSHOTS=1 scripts/run-snapshots.sh` 导出到本地 scratch 目录做逐组件视觉核对（不写入 docs/snapshots，见 `.claude/epics/semi-mobile-components/phase0-decisions.md` §3）。

## 使用示例 / Usage

```swift
RatingDisplay(value: 4.5)

// 十档
RatingDisplay(value: 7, count: 10)

// 覆盖强调色——选中档走 `.tint`，不写死 `Color.accent`
RatingDisplay(value: 4.5)
    .tint(.orange)

// 与 Rating 共用同一个样式扩展点，一次注入同时影响两者
VStack {
    Rating(value: $score)
    RatingDisplay(value: 4.5)
}
.ratingStyle(NumericRatingStyle())
```

## 样式扩展点 / RatingStyle

见 [`rating.md` 的「样式扩展点」一节](rating.md#样式扩展点--ratingstyle)——`RatingDisplay`
与 `Rating` 共用 `RatingStyle` 协议、`StarRatingStyle` 默认实现与 `View.ratingStyle(_:)`
注入入口。

## 视觉 Token

外观全部来自当前生效的 `RatingStyle`。默认 `StarRatingStyle` 的取值：

- 星形：`StarShape()`
- 选中态填充：`.tint`（`TintShapeStyle`，响应环境 `.tint(_:)`）
- 未选中态填充：`Color.tertiaryFill`
- 星间距：`CoreSpacing.xs`
- 星尺寸：`CoreControlMetrics.iconSize(for: controlSize) * 1.5`，随 `\.controlSize` 变化

⚠️ **刻意没有 `.frame(minHeight:)` 命中区地板**：44pt 的 HIG 下限约束的是**可交互**元素，
而本组件恒不可交互。给它补命中区只会在列表里凭空撑高行距。`Rating` 那条地板照旧保留。

## Accessibility

- `accessibilityLabel`：Phase 0 预登记键 `"Rating"`（与 `Rating` 同键——对辅助技术而言
  它们是同一个概念的两种形态）
- `accessibilityValue`：复用 `Rating.accessibilityValueText(value:count:)`，位置键
  `"%@ of %@"`，半星精确播报（不取整），如「4.5 of 5」
- **不挂** `.accessibilityAdjustableAction`：没有可调整的东西
