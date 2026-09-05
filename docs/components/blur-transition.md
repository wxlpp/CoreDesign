# BlurTransition

失焦转场 / A defocus (blur) transition.

`.transition(.blur)`（`CoreDesignEffects/BlurTransition.swift`，Issue #266）。
⚠️ **`Transition` 形态**——不是容器视图，也不是 `View` 上的 modifier。

```swift
import CoreDesign
import CoreDesignEffects
```

⚠️ **两个 import 一个都不能少**：全仓 `@_exported` 为 0。

## API

```swift
public struct BlurTransition: Transition {
    public let radius: CGFloat
    public nonisolated static let defaultRadius: CGFloat   // 12
    public nonisolated static let properties: TransitionProperties     // hasMotion: false
    public init(radius: CGFloat = BlurTransition.defaultRadius)
    public func body(content: Content, phase: TransitionPhase) -> some View
}

public extension Transition where Self == BlurTransition {
    static var blur: BlurTransition { get }
    static func blur(radius: CGFloat = BlurTransition.defaultRadius) -> BlurTransition
}
```

无参 `static var blur` 与含参 `static func blur(radius:)` 按 `Host.member` 去重，
**算同一种转场**（#251 口径：计数单位是「一种 transition」不是「一个静态成员」）。

## ⚠️⚠️ Reduce Motion / 减弱闪烁灯光：**两个都不读，本转场不降级**

这是 #266 要求的「逐个判断」的**结论**，不是遗漏：

| 维度 | 判断 | 依据 |
|---|---|---|
| 前庭（光流） | **无风险** | 全文件没有一处位移 / 旋转 / 缩放（判据 `filterClusterChangesImagingNotGeometry` 逐字断言不含任何运动关键字）⇒ 屏幕上没有东西在"移动"，构不成 WCAG 2.3.3 与 Apple「减弱动态效果」针对的诱因 |
| 光敏（闪烁） | **无风险** | 两条曲线（模糊半径、不透明度）在进度上**单调且仿射**，亮度不往复、不闪跳 ⇒ 与 WCAG 2.3.1 的闪光阈值无关 |
| 降级的代价 | **等于删掉它** | 本转场 = 模糊 + 淡入淡出。去掉模糊剩下的就是 `.opacity` ⇒ 「降级」在这里不是形态 1 也不是形态 2，是把 API 变成一个骗人的别名 |

⇒ 判据 `FilterTransitionTests.blurConsumesNoAccessibilitySignal` 把这个决定**钉在源码上**：
文件里出现 `reduceMotion` / `dimFlashingLights` 任一即判红，逼人回到这份文档重新裁决。

### ⚠️⚠️ `properties.hasMotion` 必须是 `false`，否则上表在运行时是假的

`Transition` 协议有 `static var properties: TransitionProperties`，**默认 `hasMotion == true`**。
SDK 对该位的原文：

> Whether the transition includes motion. When this behavior is included in a transition,
> that transition will be replaced by opacity when Reduce Motion is enabled. Defaults to `true`.

⇒ 不显式声明的话，**框架已经在 Reduce Motion 下把本转场整个换成了 `.opacity`**
——正是上表「降级的代价：等于删掉它」那一行说绝不能发生的事。
本类型因此写了 `public nonisolated static let properties = TransitionProperties(hasMotion: false)`，
由 `everyTransitionOptsOutOfTheFrameworkMotionSubstitution` 直接断言那个**性质**
（并用一个不覆写 `properties` 的探针类型互锁，证明默认值真的是 `true`）。
⚠️ 这一条是 PR #289 终审 C-4 的处置：`blurConsumesNoAccessibilitySignal` 钉的是
「文件里没出现某个词」，与「Reduce Motion 下这条转场**实际发生什么**」无关。

⚠️ 同簇另外三种的判断**各不相同**（`filmExposure` / `snapshot` 只读「减弱闪烁灯光」，
`flicker` 两个都读），完整对照表见 `Sources/CoreDesignEffects/FilterTransitionSupport.swift` 文件头。

## 相位契约

`TransitionPhase` 是 **3 case frozen enum** ⇒ `body(content:phase:)` 只可能拿到三个值：

| 相位 | 进度 | 模糊半径 | 内容不透明度 |
|---|---|---|---|
| `.willAppear`（`value == -1`） | 1 | `radius` | **0** |
| `.identity`（`value == 0`） | **0** | **0** | **1** |
| `.didDisappear`（`value == 1`） | 1 | `radius` | **0** |

`.identity` 上一切中性 ⇒ 转场停住之后常驻态与「没用过这条转场」等价
（判据 `identityIsNeutralForEveryFilter`）。

## ⚠️ 它是全簇唯一不套 `Animatable` 绘制层的

同簇另外三种的曲线**非单调**（峰值落在两个可达相位之外），必须靠
`ViewModifier & Animatable` 让 SwiftUI 插值 `progress` 才画得出来。
`blur` 的两条曲线是**仿射**的：`radius = maximum · p`、`opacity = 1 − p`
⇒ 「SwiftUI 插值输出」与「先插值进度再求值」逐点相等，中间帧不丢任何形状。

⚠️ 这张豁免**有机器判据看着**：`FilterTransitionTests.blurCurvesAreAffine` 逐点核对
`f((a+b)/2) == (f(a)+f(b))/2`，并用另外三条曲线做互锁（它们必须被判成非仿射）。
**谁把 blur 的曲线改成非仿射（比如给模糊加个 ease-out），那条判据当场判红
——那正是"必须补上 `Animatable`"的信号。**

## 退化输入

`radius` 为负 / `NaN` / `∞` 一律按 0 处理（渲染成"没有模糊"），**不抛断言**
——库代码对数据抛断言就是让宿主 App crash（epic `shipswift-effects` 的 AD-F）。
判据：`degenerateInputsStayFinite`。

## a11y 分工（FR-13）

本转场**没有装饰层**：滤镜直接作用在调用方内容上，没有可以 `accessibilityHidden(true)`
的东西（藏掉的话藏的是调用方的内容，那是 bug）。
**"这块内容出现 / 消失了"的通告由调用方提供**——组件不会自己播报。

## 登记

静态成员 `Transition.blur` 是一个**公开入口点**：它不是类型，
`ComponentRegistryGuard` 的组件条目结构上覆盖不到它 ⇒ 已登记进
`docs/component-registry.json` 的 `entryPoints`
（`target` = `CoreDesignEffects`、`host` = `Transition`、`member` = `blur` + `notes`），
由 `ExtensionEntryPointGuard` 做双向差集（漏登记与幽灵条目两个方向都判红）。

⚠️ `public struct BlurTransition` 本身**不**进 `components` 数组，但 `#270` 起**理由变了**：
`ComponentRegistryGuard` 的扫描根已由单根 `Sources/CoreDesign` 扩成
`GuardScanRoots.allRoots`（三个 target），**扫描根不再是理由**；
真正的理由是 `PublicTypeCollector` 只采 `public struct: View / ViewModifier`，
而它是 `public struct: Transition` ⇒ 结构上仍不进 `components`。
公开表面由上面那条 `entryPoints` 覆盖，不是漏登记。

## 预览

`#Preview("BlurTransition")` 在同文件内。
