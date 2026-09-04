# FilmExposureTransition

胶片过曝转场 / A film over-exposure transition.

`.transition(.filmExposure)`（`CoreDesignEffects/FilmExposureTransition.swift`，Issue #266）。
⚠️ **`Transition` 形态**——不是容器视图，也不是 `View` 上的 modifier。

```swift
import CoreDesign
import CoreDesignEffects
```

## API

```swift
public struct FilmExposureTransition: Transition {
    public let intensity: Double
    public nonisolated static let defaultIntensity: Double   // 0.55
    public init(intensity: Double = FilmExposureTransition.defaultIntensity)
    public func body(content: Content, phase: TransitionPhase) -> some View
}

public extension Transition where Self == FilmExposureTransition {
    static var filmExposure: FilmExposureTransition { get }
    static func filmExposure(intensity: Double = FilmExposureTransition.defaultIntensity)
        -> FilmExposureTransition
}
```

两个静态成员按 `Host.member` 去重，**算同一种转场**。

## ⚠️ Reduce Motion / 减弱闪烁灯光：**只读「减弱闪烁灯光」**

| 维度 | 判断 | 处置 |
|---|---|---|
| 前庭（光流） | **无风险**——无位移 / 旋转 / 缩放 | **有意不读** `\.accessibilityReduceMotion` |
| 光敏（亮度） | **有（弱）**——过曝峰值是一次大面积亮度上冲 | 读 `\.accessibilityDimFlashingLights` |

⚠️ **为什么不读 Reduce Motion**：读了会让只开启「减弱动态效果」的用户白白丢掉一条
无害的成像效果，而真正需要保护的（只开启「减弱闪烁灯光」的那批）仍然拿不到保护
——**张冠李戴的信号比没有信号更糟**。

⚠️ **过曝为什么仍在射程内**：它是**单向、一次性**的，不构成 WCAG 2.3.1 定义的「闪烁」
（那要求每秒 ≥ 3 次）；但同一条款的通用闪光阈值同时看**幅度**
（相对亮度变化 ≥ 0.1 视为大面积闪光）。

⇒ 开启「减弱闪烁灯光」时峰值压到 `FilterTransitionSafety.calmedBrightnessCeiling`
（**0.08**，落在 0.1 之下）。
⚠️ **口径照实说**：`.brightness(_:)` 是对各通道做**加性**偏移，不等于相对亮度的精确定义；
0.08 是一个**保守的替身**，不是逐像素达标证明。

⚠️ **不是 no-op**：饱和度洗白、对比度下降、淡出全部保留，用户仍看得出这是一次胶片式曝光
（判据 `exposureGateClampsPeakBelowTheFlashThreshold` 断言压制后的峰值 `> 0`，
`calmedExposureFramesDifferFromFullFrames` 断言压制帧与「完全没有曝光」那一帧不同）。

⚠️ **调用方调不高这个上限**：`intensity` 先过 `FilterTransitionSafety.exposurePeak(_:)`，
`.calmed` 档下 `min(requested, 0.08)`。

## 相位契约与曲线

| 相位 | 进度 | 亮度增量 | 饱和度 | 对比度 | 不透明度 |
|---|---|---|---|---|---|
| `.willAppear` | 1 | **0** | 0.15 | 0.65 | **0** |
| `.identity` | **0** | **0** | **1** | **1** | **1** |
| `.didDisappear` | 1 | **0** | 0.15 | 0.65 | **0** |
| （插值中点 0.5） | 0.5 | **`intensity`** | 0.575 | 0.825 | 0.75 |

- 亮度：`peak · 4p(1−p)` —— 抛物线，两端**精确**为 0、中点取满峰值。
  ⚠️ 用抛物线而不是 `sin(πp)`：`sin(.pi)` 在 `Double` 上是 `1.2246e-16` 而不是 0，
  端点会留一个肉眼看不见、但判据看得见的残余亮度。
- 饱和度：`1 − 0.85p`；对比度：`1 − 0.35p`；不透明度：`1 − p²`
  （平方项让内容在前半程留得更久，否则峰值处已经半透明、亮冲几乎看不见）。

## ⚠️⚠️ 曲线非单调 ⇒ 绘制层**必须** `Animatable`

`TransitionPhase` 只有三个 case ⇒ `body(content:phase:)` 的**可达进度只有 `{0, 1}`**，
而过曝峰值在中间。绘制层若不是 `Animatable`，SwiftUI 只会把 `.brightness` 的**输出**
从 0 插到 0 —— **过曝一次都不会发生，而所有纯函数判据照样全绿**。
这正是 #253 `ParticleTransition` 踩过的坑（粒子从未在任何真实相位上出现过）。

⇒ `FilmExposureFilm` 是 `ViewModifier & Animatable`，`animatableData` 直接绑在 `progress` 上。
判据两条互锁：
- `filmExposureOnlyBlowsOutMidFlight` —— 曲线两端为 0、中点为满峰值；
- `filmExposureDrawsTheBlowOutMidFlight` —— **把 SwiftUI 的插值步骤原样跑一遍**，
  中间那一帧的位图必须与两个端点都不同，且必须等于「直接用中间进度构造」的那一帧
  （后半句证明 `animatableData` 真的绑在 `progress` 上，而不是某个不参与绘制的字段）。

## 退化输入

`intensity` 为负 / `NaN` / `∞` / `> 1` 一律夹进 `0...1`，**不抛断言**（AD-F）。
判据：`degenerateInputsStayFinite`。

## a11y 分工（FR-13）

无装饰层——滤镜直接作用在调用方内容上。
**"这块内容出现 / 消失了"的通告由调用方提供。**

## 登记

`Transition.filmExposure` 已登记进 `docs/component-registry.json` 的 `entryPoints`
（`host` = `Transition`），由 `ExtensionEntryPointGuard` 做双向差集。
`public struct FilmExposureTransition` 本身不进 `components`（同 `BlurTransition` 的理由）。

## 预览

`#Preview("FilmExposureTransition")` 在同文件内。
