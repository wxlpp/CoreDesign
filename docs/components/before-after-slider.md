# BeforeAfterSlider

拖动分隔线对比"之前 / 之后"两层内容 / A draggable before-after comparison slider.

`BeforeAfterSlider { } after: { }`（`CoreDesignEffects/BeforeAfterSlider.swift`，Issue #253）。
**容器视图形态**，两个 `@ViewBuilder` 槽。

```swift
import CoreDesign
import CoreDesignEffects
```

⚠️ **两个 import 一个都不能少**：全仓 `@_exported` 为 0。

## API

```swift
public struct BeforeAfterSlider<Before: View, After: View>: View {
    public init(
        labels: BeforeAfterSliderLabels = .standard,
        @ViewBuilder before: () -> Before,
        @ViewBuilder after: () -> After
    )
}

public enum BeforeAfterSliderLabels {
    case hidden
    case standard
    case shown(before: LocalizedStringKey, after: LocalizedStringKey)
}
```

## 哪边画哪一层

**`before` 露在分隔线左侧，`after` 露在右侧**——`init` 的参数文档是这条语义的唯一权威，
默认 `.standard` 标签的 chip 顺序（左 "Before" / 右 "After"）也照它排。

⚠️ **这条曾经反了，而全套测试全绿**（#253 PR #273 终审 C-1）：绘制层把 `after` 叠在
`before` 之上并 mask 到 **leading** ⇒ 左半画的是 `after`、右半是 `before`，
而 chip 顺序没跟着反 ⇒ 默认标签把**两半都标错**，`.shown(before:after:)` 对所有调用方
同样标错。当时的两条渲染判据（`fractionReachesRendering` 只比"两个位置的位图不同"、
`labelDomainIsAnEnumWithThreeDistinctRenderings` 只比"三档互不相同"）**对方向完全不敏感**。

⇒ **两条判据分别钉住这件事的两半，缺一条都能被绕过**：

- **图层方向**——`BeforeAfterSliderTests.beforeIsOnTheLeadingSide`（逐像素取色：
  fraction 0.5 时左侧必须是 `before` 的色、右侧必须是 `after` 的色）
  + `endpointsRevealASingleSide`（fraction 0 / 1 两个端点各整块换成另一层，作互锁）。
- **chip 与图层的对应**——`BeforeAfterSliderTests.beforeChipIsOnTheLeadingSide`。

⚠️⚠️ **上一版这里只写了「逐像素取色判据钉住」，而那条走 `labels: .hidden`、
结构上观测不到 chip**（#253 PR #273 终审 I-A）：终审只把 `labelPair` 里
`self.chip(before)` 与 `self.chip(after)` 对调（**图层一动不动**），
"Before" 就压在 `after` 那半上——**与 C-1 的用户可见后果逐字相同**，
而当时 `swift test` **665 全绿**。⇒ chip 那一半必须单独有判据。
它的形态是「宽窄文案 + 差分计数」：位图路认不出 chip 上写的是哪个词，但认得出宽度
——一次给 `before` 长文案、一次给 `after` 长文案，各与 `.hidden` 基线做差分计数，
长文案那一侧的差异像素必须**跟着它的实参位置走**。

⚠️ 采样点必须避开把手：`handleHitSize` 的命中区在端点形态下会盖住
`[0, handleHitSize]` / `[width - handleHitSize/2, width]`（落进去会取到把手的灰 156）。
采样点**从 `BeforeAfterSweep.handleHitSize` 推导、不写裸字面量**
（终审 Preference；自洽核对见 `endpointProbesStayOutsideTheHandle`）。

## 入场摆动不会覆盖拖拽

摆动是一次性的"这里可以拖"提示，前后共约 `sweepDuration × 2 ≈ 1.1s`。用户在这段窗口里
抓住把手时，**回程不再执行**——否则显式输入会被一个提示动画拽回正中
（#253 PR #273 终审 I-6：上一版 `playIntroSweep` 与 `DragGesture.onChanged` 写同一个
`fraction`、无任何协调）。

裁决点是纯函数 `BeforeAfterSweep.settlesAfterSweep(hasInteracted:)`，两条判据：
- `BeforeAfterSliderTests.settleIsGatedByInteraction`（函数体 + 互锁）；
- `BeforeAfterSliderTests.introSweepYieldsToTheDrag`（调用点：`onChanged` 置位、
  闸出现且排在回程赋值**之前**）。

## ⚠️ 标签为什么不是 `showLabels: Bool`（J-1 / FR-6）

上游 ShipSwift 的签名是 `showLabels: Bool`，而 `shipswift-harvest` 的 **FR-6** 逐字点名了
它：「上游的 `showLabels: Bool` / `autoReset: Bool` / `isActive: Binding<Bool>`
**一律不得照搬**」。

⚠️ 本枚举也**不是**"把 Bool 换成两 case enum"——那是公约第 3 节点名的**头号反例**。
它是**三档且带载荷**的取值域：`Bool` 表达不了「显示，但用调用方给的文案」这一档，
而那一档正是这个组件现实中最常用的形态（"原图 / 修图后"、"Draft / Final"）。
⇒ 走的是「专用参数 + 取值域枚举」这条替代路径，**没有**动用本 epic 的豁免预算
（`docs/bool-exemptions-baseline.json` 的 `maxEntries` 32 / `sourceSites` 35 一动不动，
`perTarget.CoreDesignEffects` 仍为 0）。

## 文案类型：两档各按公约走各自的类别（FR-7 / 公约 §4）

| 档 | 文案来源 | 公约类别 | 类型 |
|---|---|---|---|
| `.standard` | **写在本组件源码里**，调用方看不见也改不了 | **A 类** | `LocalizedStringResource`，经本 target 的 `Bundle.module` |
| `.shown(before:after:)` | 调用方传入的界面文案 | **B 类** | `LocalizedStringKey`（公约第 4 节裁决：新增 B 类用 LSK） |

⚠️ **两档用不同类型不是不一致，正是公约要求的**：A 类与 B 类在公约里本来就落在不同的
类型列上。把默认文案也做成 `LocalizedStringKey` 会让它去查**宿主 App** 的表
——本包自己的译文永远命不中；反过来把调用方参数做成 `LocalizedStringResource`
又与第 4 节「新增 B 类参数用 `LocalizedStringKey`」的成文裁决相反（`.rise(text:)`
正是按那条落的）。

⚠️ 为此 `CoreDesignEffects` 新增了自己的 `Resources/en.lproj/Localizable.strings`
与 `Package.swift` 的 `resources:` 声明（与 `CoreDesignCharts` 同一条裁决，PR #263 终审 C-5）：
没有资源包时 `LocalizedStringResource("Before")` 只能落到 `Bundle.main`，
**本包永远无法为自己的 chrome 文案提供翻译**。
文件里有一个哨兵键 `__localization_probe__`（译文与 key **有意不同**），
`BeforeAfterSliderTests.defaultLabelsResolveThroughModuleBundle` 用它区分「查表命中」
与「静默回退」——删掉它 = 让本地化通路重新变成不可验证的。

## Reduce Motion

**停止自动摆动，但保留拖拽**（AC 逐字）。开启该偏好时不做入场摆动，分隔线直接停在正中；
拖拽手势原样可用——PRD 的 **FR-12** 逐字要求保留「由用户手势/倾斜驱动的空间输入」，
冻结它会让这个组件不可用。

裁决点是纯函数 `BeforeAfterSweep.introSweep(reduceMotion:)`（`nil` ⇒ 不摆）。
「保留拖拽」这一半**不在**那个函数里，而在于 `BeforeAfterSweep.fraction(dragX:width:)`
是纯几何、签名里根本**没有** `reduceMotion` 这个参数 ⇒ 拖拽在结构上就无从被门控。

## ⚠️ 实现约定：位置走**布局宽度**，一个 `offset` 都不用

`MicroInteractionReduceMotionGuard.everyMotionCallIsGated` 要求：不走早退的文件里，
**每一处**运动变换（`offset(` / `position(` / `scaleEffect(` …）的实参都必须自带
`isReduced` 门控。而本组件的分隔线位置是**由用户手势驱动的空间输入**，FR-12 要求它在
Reduce Motion 下保留 ⇒ 「给这个 `offset` 加一个 `isReduced` 三元」在语义上是错的：
真分支该填什么都不对。

布局定位（`Color.clear.frame(width:)` 把把手推到位、`mask` 的矩形按宽度裁）不是为了绕开
那条判据——它本来就是这类"按比例分割"的常规写法，且顺带让本文件里一个 `motionCalls`
关键字都不出现。⇒ 本文件登记在 `MicroInteractionReduceMotionGuard.approvedNoMotion` 上。

⚠️⚠️ **那条登记不等于"这个组件不动"**（入场摆动会让分隔线滑过去）。它与三个"处理中"
薄封装（`ScanningOverlay` / `GlowSweep` / `LightSweep`）同一处置：名单里的豁免由**两条**
判据在别处接管，缺一条就是个洞：

- `BeforeAfterSliderTests.sliderPositionsByLayoutNotByTransform`
  —— 本文件里不得出现任何 `motionCalls` 关键字（豁免的前提本身）；
- `BeforeAfterSliderTests.reduceMotionIsOnlyConsumedByTheSweepGate`
  —— `reduceMotion` 只许喂给 `BeforeAfterSweep.introSweep(reduceMotion:)`。

## 触控目标 ≥ 44pt

把手的视觉直径是 28pt，靠 `frame(minWidth:minHeight:)` + 最外层 `contentShape` 撑到
`BeforeAfterSweep.handleHitSize = 44`（同 `CoreDesign` 里 `Rating` / `CheckBox` 的处置）。

判据**在 `CoreDesignEffectsTests` 内同形态实现**，两条：

- `BeforeAfterSliderTests.handleHitSizeConstantMeetsMinimum`（平台无关，钉常量）；
- `BeforeAfterSliderTouchTargetTests`（`#if os(iOS)` + `ImageRenderer` 量渲染尺寸，
  与 `CoreDesignTests.TouchTargetTests` 同形态；**只在 xcodebuild iOS Simulator 腿上执行**）。

⚠️ **有意不加进 `CoreDesignTests.TouchTargetTests`**：那会让 `CoreDesignTests` 的依赖图
包含 `CoreDesignEffects`，判红 `shipswift-foundation` #245 立的 NFR-5② 隔离判据
（`swift package describe` 里 `CoreDesignTests` 的依赖必须恰为 `["CoreDesign"]`）。

## 后台 / 低电量（NFR-7）

⚠️ **本组件不接能耗闸，这是一条判定不是遗漏**：NFR-7 管的是**常驻渲染**的效果。
本组件的入场摆动是**一次性**的（`.task` 里一次 `withAnimation`，之后没有任何调度器），
其余时间它是一张静止的图 + 一个手势——与 `.ping` / `.spray` 这些一次性微交互同类。
另一半理由：能耗闸的 `.none` 语义是**一个像素都不画**，而这里画的是调用方的**内容**。

## a11y

整块合成为一个**可调节**元素：VoiceOver 上下轻扫即可移动分隔线
（`accessibilityAdjustableAction`，步长 5%），值播报为百分比。
标签层已 `accessibilityHidden(true)`——它与那个百分比说的是同一件事。

## 使用示例 / Usage

```swift
import CoreDesign
import CoreDesignEffects
import SwiftUI

struct RetouchComparison: View {
    let original: Image
    let edited: Image

    var body: some View {
        BeforeAfterSlider(labels: .shown(before: "Original", after: "Edited")) {
            original.resizable().scaledToFill()
        } after: {
            edited.resizable().scaledToFill()
        }
        .frame(height: 240)
        .clipShape(CoreShape.rounded(CoreRadius.large))
    }
}
```

⚠️ **本文档的示例代码零机器覆盖**（与 `confetti.md` 同一条登记）。
