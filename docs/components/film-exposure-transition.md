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
    public nonisolated static let properties: TransitionProperties       // hasMotion: false
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

⚠️ **过曝构不构成 WCAG 2.3.1 违规？单次使用不构成——但理由是频率，不是「单向」。**
（PR #289 第 2 轮 I-1 的再更正；下面的引文均对 `https://www.w3.org/TR/WCAG22/` 原文逐字核对过）

规范把 "a pair of opposing changes" 逐字定义为 "an increase followed by a decrease,
or a decrease followed by an increase"，Note 2 另有一句 "A flash consists of two opposing
transitions"。本转场的亮度曲线 `peak · 4p(1−p)` 是 **0 → 峰 → 0**，正是「先升后降」
⇒ 它**就是一次 general flash**。

⇒ 单次使用不构成违规的正确理由是**频率**：一次转场只放 **1** 次 flash，而阈值的第一条
通过条件逐字是 "there are no more than three general flashes and / or no more than three
red flashes within any one-second period"。

⚠️ **这是一条有边界的结论，不是无条件豁免**：调用方在**一秒内插入/移除 4 个以上**带本
转场的视图（列表批量插入、照片墙逐格出现）就越过了 3 次/秒线；届时幅度那条合取项
（"10% or more of the maximum relative luminance (1.0) where the relative luminance of the
darker image is below 0.80"）也会成立——`full` 档峰值是 **0.55**，而下表实测 0.08 在中到亮
的灰阶上已经给出 0.10–0.13 的 ΔrelLum。**批量场景请自行核对触发频率。**
（另一条并列的通过条件是面积："the combined area of flashes occurring concurrently
occupies no more than a total of .006 steradians within any 10 degree visual field on the
screen"——形态同 `flicker` 已登记的那条面积告警，同样由调用方决定。）

⚠️ 前两版这里先写「幅度 ≥ 0.1 仍在射程内」、再写「单向 ⇒ 不满足『一对反向变化』，
幅度多大都一样」，**两句都是误述**（终审 I-1 与第 2 轮 I-1）。0.1 不是一条独立的幅度
上限，而是 general flash 定义里的一个合取项；「单向」这个前提本身不成立。

⇒ **那为什么还压制？因为用户显式打开了「减弱闪烁灯光」**——那是系统为光敏性提供的
偏好开关，一次大面积亮冲正是它想减弱的东西。这个理由自己站得住，不需要 WCAG 背书。
开启时峰值压到 `FilterTransitionSafety.calmedBrightnessCeiling`（**0.08**）。

⚠️ **0.08 是一条产品策略线，不是达标线**：`.brightness(_:)` 是对色彩分量做**加性**偏移，
而 WCAG 量的是加权后的**相对亮度**。实测 `.brightness(0.08)` 的真实 ΔrelLum：

| 灰阶 | relLum 前 → 后 | ΔrelLum |
|---|---|---|
| 0.00 | 0.0000 → 0.0102 | 0.0102 |
| 0.50 | 0.2892 → 0.3756 | 0.0864 |
| 0.70 | 0.5289 → 0.6400 | **0.1111** |
| 0.85 | 0.7479 → 0.8765 | **0.1286** |
| 1.00 | 1.0000 → 1.0000 | 0.0000 |

对中到亮的内容（浅色卡片、白底照片——恰恰是本转场的典型宿主），它给出的相对亮度变化
**比 0.1 还高约 30%**。「保守的替身」这个说法方向是反的：只有暗底才保守。
要真把 ΔrelLum 压到 0.1 以下需要 ≈ 0.05，或改用乘性 / 线性空间的调制
——那是另一次裁决（会明显削弱效果），不在 #266 射程内。

⚠️ **不是 no-op**：饱和度洗白、对比度下降、淡出全部保留，用户仍看得出这是一次胶片式曝光
（判据 `exposureGateClampsPeakToThePolicyCeiling` 断言压制后的峰值 `> 0`，
`calmedExposureFramesDifferFromFullFrames` 断言压制帧与「完全没有曝光」那一帧不同）。

### ⚠️⚠️ `properties.hasMotion` 必须是 `false`，否则「有意不读 Reduce Motion」是假的

`Transition` 协议有 `static var properties: TransitionProperties`，**默认 `hasMotion == true`**。
SDK 原文：

> Whether the transition includes motion. When this behavior is included in a transition,
> that transition will be replaced by opacity when Reduce Motion is enabled. Defaults to `true`.

⇒ 不显式声明的话，只开启「减弱动态效果」的用户**照样**丢掉这条成像效果
——只是丢在框架那一层，本文件一个字都看不见，而上表却写着"有意不读"。
本类型因此写了 `public nonisolated static let properties = TransitionProperties(hasMotion: false)`，
判据 `everyTransitionOptsOutOfTheFrameworkMotionSubstitution` 直接断言那个**性质**
（PR #289 终审 C-4）。

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
