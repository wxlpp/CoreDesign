# Carousel

分页走马灯，支持自动轮播（可关闭）、手势滑动与页点指示器 / Paged carousel with
optional auto-advance, native swipe gestures, and a page-dot indicator.

## 为什么不用 `TabView(.page)`

`TabView(.page)`（`PageTabViewStyle`）**只在 iOS 上可用，macOS 上没有对应实现**——
直接用它会违反 epic NFR-2「双端单一实现，不留单端公开符号」，导致 `#if os(iOS)` 分支
或 macOS 端功能缺失。

`Carousel` 改用纯 `ScrollView`/`List` 通用 API 组合出等价效果：

```swift
ScrollView(.horizontal) {
    LazyHStack(spacing: 0) {
        ForEach(data) { element in
            content(element)
                .containerRelativeFrame(.horizontal)
        }
    }
    .scrollTargetLayout()
}
.scrollTargetBehavior(.paging)     // 结算到容器对齐边界，效果等价 TabView(.page)
.scrollPosition(id: $selection)    // 双向绑定当前页 id，可读可写（编程式翻页）
```

`scrollTargetBehavior(.paging)` 与 `scrollPosition(id:)` 均为 iOS 17+ / macOS 14+
通用 API（非 `UIScrollView` 专属包装），在双平台行为一致——这是选择该实现路径而非
`TabView(.page)` 的直接原因。手势滑动直接复用原生 `ScrollView` 手势，组件内部
**不自定义 `DragGesture`**。

## API

### `Carousel`

```swift
public struct Carousel<Data: RandomAccessCollection, ID: Hashable, Content: View>: View
    where Data.Element: Identifiable, Data.Element.ID == ID
```

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| data | Data | - | 走马灯页数据源，元素须 `Identifiable` |
| autoAdvance | Bool | true | 是否自动轮播；`false` 时只保留手势滑动 / 点击页点跳转 |
| interval | Duration | .seconds(4) | 自动轮播间隔；`autoAdvance == false` 时不生效 |
| content | (Data.Element) -> Content | - | 单页内容构建闭包（`@ViewBuilder`） |

```swift
Carousel(items, autoAdvance: true, interval: .seconds(4)) { item in
    CardView(item)
}

Carousel(items, autoAdvance: false) { item in
    CardView(item)
}
```

## 自动轮播与手动滑动的协调

自动轮播由 `.task(id: selection)` 驱动，对应 issue #171 Technical Details 中的
**方案 2**（未采用方案 1 的 `.onScrollPhaseChange` 拖拽态探测，实现更简单、不依赖
额外 API）：

- `selection`（当前页 `id`）每次变化——无论是用户滑动手势结算触发，还是本组件自身
  的定时推进——都会让 SwiftUI **取消旧 task、以新 `id` 重启** `.task(id:)`；
- 因此用户手动滑动之后天然获得"重新计时"的效果，不需要额外 `@State private var
  isUserInteracting` 标志位去探测拖拽态；
- 计时循环本身（睡眠 `interval` 后推进一页）与回绕逻辑（末尾元素后回绕到首个）拆成
  两段：前者是 `.task(id:)` 里的运行时副作用（不可脱离 SwiftUI 运行时单测），后者
  抽成 `static func nextID(after:in:) -> ID?` 纯函数，覆盖空集合 / `nil` 当前值 /
  当前值不在集合中（防御式处理数据源变化）/ 末尾回绕 / 单元素恒返回自身五种边界，
  见 `Tests/CoreDesignTests/CarouselTests.swift`。

## 页点指示器

- 底部居中叠加（`ZStack(alignment: .bottom)`），玻璃质感背景（`.glassEffect(.regular,
  in: Capsule())`）；数据源仅一页时不渲染指示器
- 当前页走 `.tint`（`TintShapeStyle`，响应环境 `.tint(_:)`，不写死 `Color.accent`）；
  其余页走 `Color.fill`（细小形状叠加填充，与 `Steps` 未完成态描边同一色彩语义层级）
- 点击任意页点可跳转到对应页（`withAnimation` 写 `selection` 触发编程式滚动）
- 每个页点是独立 `Button`，`accessibilityLabel` 用 Phase 0 预登记的位置键
  `"%@ of %@"`（`String(localized: "\(index.formatted()) of \(count.formatted())",
  bundle: .module)`，1-based，如「3 of 5」），当前页额外携带 `.isSelected` trait

## 视觉 Token

- 页点尺寸：`CoreSpacing.xs`（4pt 直径），间距 `CoreSpacing.xs`；命中区域另放大到
  `CoreSpacing.lg`（不改变可视尺寸）
- 指示器容器内边距：水平 `CoreSpacing.sm`、垂直 `CoreSpacing.xs`；距底部
  `CoreSpacing.sm`

## Accessibility

- 走马灯容器 `.accessibilityElement(children: .contain)`——VoiceOver 可进入内部单页
  内容与页点逐一浏览
- 页点指示器逐个提供「第 N / 共 M 页」播报（见上）

## 预览 / Preview

`#Preview` 覆盖：3–5 张卡片自动轮播态、`autoAdvance: false` 手动态、单张边界态
（无页点指示器）、`.tint(.red)` 覆盖态，均含 Light / Dark。运行
`scripts/run-snapshots.sh` 后，预览图将生成于 `docs/snapshots/`。

## 已知局限 / Known limitations

- 末尾到首个的回绕是一次性滚动跳转（非无缝循环轮播），与常见电商 App 首页 banner
  的"无缝循环"观感不同——若后续需要无缝循环需另行设计（如首尾各追加一份哨兵页），
  当前实现未覆盖该需求（issue #171 Acceptance Criteria 未要求）
- `selection` 的回绕/回落逻辑假定 `data` 在轮播期间结构稳定；若调用方在自动轮播运行
  期间整体替换 `data`（如异步刷新列表）且当前 `selection` 对应的 `id` 不再存在，下一次
  `.task` 的 `nextID(after:in:)` 会防御式回落到新集合的首个元素，但当次已经排队的滚动
  动画可能出现跳变——高频动态刷新数据源场景建议调用方自行在数据替换时重置
  `autoAdvance`／改用受控 `id` 保持稳定
