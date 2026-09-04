# FlickerTransition

闪烁转场 / A flicker (faulty-tube) transition.

`.transition(.flicker)`（`CoreDesignEffects/FlickerTransition.swift`，Issue #266）。
⚠️ **`Transition` 形态**——不是容器视图，也不是 `View` 上的 modifier。

```swift
import CoreDesign
import CoreDesignEffects
```

## API

```swift
public struct FlickerTransition: Transition {
    public let cycles: Int
    public nonisolated static let defaultCycles: Int   // 3
    public init(cycles: Int = FlickerTransition.defaultCycles)
    public func body(content: Content, phase: TransitionPhase) -> some View
}

public extension Transition where Self == FlickerTransition {
    static var flicker: FlickerTransition { get }
    static func flicker(cycles: Int = FlickerTransition.defaultCycles) -> FlickerTransition
}
```

两个静态成员按 `Host.member` 去重，**算同一种转场**。

## ⚠️⚠️ Reduce Motion / 减弱闪烁灯光：**两个都读**，全簇唯一

#266 逐字点名本转场（「`flicker` 尤其——闪烁是 WCAG 明确点名的诱因」）。

| 维度 | 判断 | 处置 |
|---|---|---|
| 光敏（主要） | WCAG 2.3.1《Three Flashes or Below Threshold》**直接管**这件事 | 读 `\.accessibilityDimFlashingLights`——系统为光敏性提供的**正确**信号 |
| 非必要动画（次要） | 往复闪烁是全簇唯一会在**一次转场里来回好几遍**的效果，落在「减弱动态效果」想关掉的那一类 | **也**读 `\.accessibilityReduceMotion` |

**任一开启即压制**（`FilterTransitionSafety.oscillation(dimFlashingLights:reduceMotion:)`）：
两个偏好在系统设置里是**各自独立**的开关，取「或」才能覆盖只开了其中一个的用户。
判据 `oscillationGateTakesEitherSignal` 把四种组合逐个钉住。

压制后 `cycles` 归 0 ⇒ 曲线退化为**单调淡出** `1 − p`。
⚠️ **不是 no-op**：转场仍然发生（内容仍然淡入 / 淡出），去掉的只有往复。
判据 `flickerActuallyOscillates` 与 `calmedFlickerIsMonotone` 互锁——
前者证明未压制时曲线上真的存在**上升段**（一条普通淡出永远不会有），
后者证明压制后**没有**上升段且逐点等于 `1 − p`。

⚠️ **调用方绕不过这道闸**：`cycles` 先过 `FilterTransitionSafety.oscillationCycles(_:)`，
`.calmed` 档下恒为 0（`oscillationCycles(99) == 0` 有判据）。

## ⚠️⚠️ 已知限度：闪烁**频率**由调用方的动画时长决定，本类型控制不了

一次转场里发生 `cycles` 次明暗往复，而这段动画有多长**写在调用方的
`withAnimation(_:)` 里**——`Transition` 拿不到任何时间源（它只被喂三个离散相位，
不知道时长、曲线，也不知道"何时开始"；同 `ParticleTransition` 记的那条）。

⇒ **感知频率 = `cycles ÷ 时长`**。默认 `cycles = 3`，
**要落在 WCAG 的 3 次/秒线下，调用方的动画时长需 ≥ 1 秒**
（`#Preview` 用的就是 1.1 秒）。

```swift
// ✅ 3 次往复 ÷ 1.1 秒 < 3 次/秒
withAnimation(.easeInOut(duration: 1.1)) { shown.toggle() }

// ⚠️ 3 次往复 ÷ 0.3 秒 = 10 次/秒 —— 超过 WCAG 2.3.1 的通用闪光阈值
withAnimation(.easeInOut(duration: 0.3)) { shown.toggle() }
```

⚠️ 这条限度**不能靠"把默认调小"绕开**——`cycles = 1` 就不是闪烁了。
真正兜底的是上面那道闸：开启「减弱闪烁灯光」的用户拿到的是单调淡出，
与调用方写了多短的时长无关。

⚠️ WCAG 的通用闪光阈值还要求闪光区域达到一定占比才构成风险；
本转场作用在**调用方给的那一块内容**上，用在小徽章上与用在整屏上不是同一件事。
**用作全屏转场时，请自行核对时长与面积。**

## 相位契约与曲线

`opacity(p) = (1 − p) · (1 − depth · (0.5 − 0.5·cos(2π · cycles · p)))`，`depth = 0.75`。

| 相位 | 进度 | 不透明度 |
|---|---|---|
| `.willAppear` | 1 | **0** |
| `.identity` | **0** | **1** |
| `.didDisappear` | 1 | **0** |
| （插值 1/6，默认 3 次） | 0.1667 | ≈ 0.208（谷） |
| （插值 1/3，默认 3 次） | 0.3333 | ≈ 0.667（峰） |

⚠️ `depth` 有意 **< 1**：全灭会让内容在转场中途整块消失一瞬，那既更刺眼、
也更像"渲染出错"而不是"灯管在闪"。

## ⚠️⚠️ 曲线往复 ⇒ 绘制层**必须** `Animatable`

曲线在两个**可达相位**上分别是 1 与 0，**中间的每一次明暗全靠 SwiftUI 对
`animatableData` 的插值逐帧重求 `body`** 得到。
不 `Animatable` 的话 `.opacity` 的输出被直接从 1 插到 0
⇒ **就是一次普通淡出，闪烁一次都不会发生，而所有测试照样绿**。

⇒ 判据 `flickerDrawsDifferentFramesMidFlight` 取曲线上**真实存在的一段上升**
（谷 1/6 → 峰 1/3），把 SwiftUI 的插值步骤原样跑一遍，两帧位图必须不同；
并要求**同一条链在压制档下画出不同的帧**（否则 `oscillationCycles(_:)` 的结论
没有走到绘制层，那道 a11y 闸是摆设）。

⚠️ 这条判据比同簇另两条更难写：flicker 的每一帧只是"内容 + 某个不透明度"，
**一次普通淡出的中间帧也长这样** ⇒ 光证"中间帧与端点不同"不够。

## 退化输入

`cycles ≤ 0`（含 `Int.min`）退化为单调淡出 `1 − p`，**不抛断言**（AD-F）。
判据：`degenerateInputsStayFinite` 逐点核对退化后就是 `1 − p`。

## a11y 分工（FR-13）

无装饰层——滤镜直接作用在调用方内容上。
**"这块内容出现 / 消失了"的通告由调用方提供。**

## 登记

`Transition.flicker` 已登记进 `docs/component-registry.json` 的 `entryPoints`。

## 预览

`#Preview("FlickerTransition")` 在同文件内（时长 1.1 秒，理由见上）。
