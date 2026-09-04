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
    public static let properties: TransitionProperties // hasMotion: false
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
判据 `flickerActuallyOscillates` 一条里两半互锁——先证未压制时曲线上真的存在**上升段**
（一条普通淡出永远不会有），再证**经那道闸取到的** `cycles` 下没有上升段、
且逐点等于 `1 − p`；少了前一半，后一半是恒真的。
⚠️ 上一版这里引用的 `calmedFlickerIsMonotone` **是一个不存在的符号**（`grep -c` = 0），
断言写在 `flickerActuallyOscillates` 内部（PR #289 终审 I-4）。

⚠️ **调用方绕不过这道闸**：`cycles` 先过 `FilterTransitionSafety.oscillationCycles(_:)`，
`.calmed` 档下恒为 0（`oscillationCycles(99) == 0` 有判据）。

## ⚠️⚠️ 频率：本转场**自己钉死**动画时长，不跟随调用方

一次转场里发生 `cycles` 次明暗往复 ⇒ **感知频率 = `cycles ÷ 时长`**。

⚠️ **上一版把这条账写进文档就算完，那不够**（PR #289 终审 I-3）：最常见的写法
`withAnimation { shown.toggle() }`（`.default` ≈ 0.35 s）在默认 `cycles = 3` 下给出
**≈ 8.6 次/秒**、depth 0.75 的往复——对**未**开启「减弱闪烁灯光」的光敏用户，
那是库自己的默认路径在伤人。库不该把「不这样写会伤到用户」的责任放在文档里。

⇒ `FlickerChrome` 用 `.animation(_:value:)` 把这段转场钉在 `FlickerPace.duration(cycles:)` 上
（显式动画 modifier 覆盖调用方事务里的那条 ambient 动画）：

| | 值 |
|---|---|
| `FlickerPace.maximumFlashesPerSecond` | **2.5**（WCAG 2.3.1 的 3 次/秒线下留一档余量） |
| `FlickerPace.duration(cycles:)` | `max(calmedDuration, cycles / 2.5)` |
| 默认 `cycles = 3` | **1.2 秒**，即 2.5 次/秒 |
| 压制档 `cycles = 0` | `calmedDuration` = 0.35 秒的普通淡出 |

```swift
// 下面两句给出**同样**的闪烁速率（2.5 次/秒）—— 时长由转场自己决定
withAnimation { shown.toggle() }
withAnimation(.easeInOut(duration: 0.2)) { shown.toggle() }

// 调高 cycles 只会把转场**拉长**，抬不高速率
withAnimation { shownMore.toggle() }   // .flicker(cycles: 8) ⇒ 3.2 秒
```

⚠️ **代价，逐条照录**：

1. **调用方对这条转场的时长失去控制**。这是有意的——闪烁有内在节奏，
   「快到不安全」那一档不该是可选项。同簇另外三种转场**不**钉时长
   （它们没有"频率"这回事），本条只改 `flicker`。
2. **没走 SwiftUI 自己的 `Transition.animation(_:)`**：它存在，但返回**不透明类型**
   ⇒ `extension Transition where Self == FlickerTransition` 那套点语法入口点与
   `Host.member` 登记键都得跟着变形。本形态把公开 API 形状原样留住，
   只在 chrome 内部加一行 modifier。
3. **单测看不见时序**：本仓的 harness（`ImageRenderer`）拍的是静态帧，
   「这段动画真的跑了 1.2 秒」在 macOS 单测里**不可观测**。机器判据只有两半——
   纯函数的速率上界（`flickerPaceStaysUnderTheFlashRateLimit`）与
   `chromeBodiesArePinnedVerbatim` 逐字钉住的那一行 `.animation(...)`。
   **时序本身靠 `#Preview` 人工确认；这条限度如实登记，不假称已验证。**

⚠️ 即便 SwiftUI 在调用方事务结束时提前把视图摘掉（截断本条转场），安全性质仍然成立：
截断只会**少放几次**闪烁，抬不高**速率**——速率就是 `cycles ÷ duration` 这条比值本身。

⚠️ 那道 a11y 闸与这条节奏是**独立的两层**：闸管"要不要闪"，`FlickerPace` 管"闪多快"。

⚠️ WCAG 的通用闪光阈值还要求闪光区域达到一定占比才构成风险；
本转场作用在**调用方给的那一块内容**上，用在小徽章上与用在整屏上不是同一件事。
**用作全屏转场时，请自行核对面积。**

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

`#Preview("FlickerTransition")` 在同文件内。⚠️ 它的按钮**故意**写了一个很短的
`withAnimation(.easeInOut(duration: 0.25))`：预览里看到的仍然是 1.2 秒、3 次往复
——那正是"默认路径安全"这条性质的人工验证点。
