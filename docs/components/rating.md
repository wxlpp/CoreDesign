# Rating

`Binding<Double>` 驱动的星级评分组件 / Star rating control driven by a `Binding<Double>`.

星形复用 `Shape/StarShape.swift`（不重新实现五角星路径），按 `value` 与每颗星的索引计算
填充比例（整星 / 半星 / 空星三态），用 `.mask` 裁切实现半星视觉。

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| value | Binding\<Double\> | - | 当前评分，双向绑定 |
| count | Int | 5 | 星数；负数会被 clamp 到 0 |
| allowsHalfStar | Bool | false | 是否允许半星步进（手势 / VoiceOver 按 0.5 递增递减，关闭时按 1.0） |
| isReadOnly | Bool | false | 只读模式——`true` 时不挂载手势 / accessibility adjust action |

## 预览 / Preview

运行 `scripts/run-snapshots.sh`（默认模式）后，预览图落地 `docs/snapshots/`——但前提是该组件已在 `App/Sources/Previews.swift` 注册（导出文件名形如 `CoreDesignPreview_<组件名>.png`）；组件源码内自带的 `#Preview` 仅用于开发期本地预览，或经 `KEEP_LIBRARY_SNAPSHOTS=1 scripts/run-snapshots.sh` 导出到本地 scratch 目录做逐组件视觉核对（不写入 docs/snapshots，见 `.claude/epics/semi-mobile-components/phase0-decisions.md` §3）。

## 使用示例 / Usage

```swift
@State private var rating: Double = 3

Rating(value: $rating)

// 半星步进
Rating(value: $rating, allowsHalfStar: true)

// 只读展示（如评论列表里的历史评分）
Rating(value: .constant(4.5), allowsHalfStar: true, isReadOnly: true)

// 自定义星数
Rating(value: $rating, count: 3)

// 覆盖强调色——选中星走 `.tint`，不写死 `Color.accent`
Rating(value: $rating)
    .tint(.orange)
```

## 手势与取值

拖拽 / 点按沿控件宽度更新 `value`：按 `step`（`allowsHalfStar ? 0.5 : 1.0`）**向上取整（ceiling）**
后写回 `Binding`，并 clamp 在 `0...count`——落在第 k 颗星上的点按得 k 分（半星模式下星 k 左半 → k−0.5、
右半 → k），最左缘得 0（清空）。RTL 布局下按 `layoutDirection` 沿宽度翻折坐标，保证「点视觉上的第 k 颗星」
两个方向下都得 k 分。`isReadOnly == true` 或外层 `.disabled(true)` 时手势整体不挂载。

> **已知取舍：嵌入纵向 `ScrollView` / `List` 时的手势冲突**——手势用
> `DragGesture(minimumDistance: 0)` 以保留精确点按语义（拖拽或点按均可设值）。
> 与原生 `Slider` 一样，这意味着起手落在星形上的纵向滑动会被 Rating 自身的手势
> 捕获而非冒泡给祖先滚动容器（SwiftUI 对后代视图的 `.gesture` 默认优先于祖先的
> 滚动手势）。若把 Rating 放进可纵向滚动的列表且需要在星形上也能顺畅滚动，需
> 自行包一层方向判定或调整命中区域，本组件当前未内置这层协商。

## 视觉 Token

- 星形：`StarShape()`
- 选中态填充：`.tint`（`TintShapeStyle`，响应环境 `.tint(_:)`，未显式设置时解析为宿主 App 的
  `Color.accentColor`）
- 未选中态填充：`Color.tertiaryFill`
- 星间距：`CoreSpacing.xs`
- 星尺寸：`CoreControlMetrics.iconSize(for: controlSize) * 1.5`，随 `\.controlSize` 环境值变化
- 命中区：`.frame(minHeight: CoreControlMetrics.height(for: controlSize))`（`.regular` 档
  44pt）——星形视觉尺寸本身在多数档位下小于这条 HIG 下限，用最小高度地板补足纵向命中区，
  不放大星形，多余空间由 `HStack` 居中吸收

## Accessibility

- `accessibilityLabel`：Phase 0 预登记键 `"Rating"`
- `accessibilityValue`：位置键 `"%@ of %@"`，经
  `String(localized: "\(value.formatted()) of \(Double(count).formatted())", bundle: .module)`
  组装（`Rating.accessibilityValueText(value:count:)`），半星精确播报（`Double.formatted()`，
  不取整），如「2.5 of 5」
- `.accessibilityAdjustableAction`：VoiceOver increment / decrement 按 `step` 调整 `value`，
  clamp 在 `0...count`；`isReadOnly` 为 `true` 或外层 `.disabled(true)` 时不挂载该 action
- Phase 0 同时预登记了复数摘要键 `"%lld stars"`（如「5 stars」），供未来「满分摘要」类用法
  使用；`Rating` 本身只消费位置键 `"%@ of %@"`（半星精度更高），未消费 `"%lld stars"`，非
  遗漏
