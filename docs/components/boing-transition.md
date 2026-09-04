# BoingTransition（`.boing`）

弹性缩放转场 / An elastic pop transition。`CoreDesignEffects/BoingTransition.swift`，Issue #267。

> 六条转场共用的形态与契约见
> [`transition-cluster-3d-elastic.md`](transition-cluster-3d-elastic.md)。

## API

```swift
public struct BoingTransition: Transition {
    public let strength: MicroInteractionStrength
    public init(strength: MicroInteractionStrength = .regular)
    public func body(content: Content, phase: TransitionPhase) -> some View
}

public extension Transition where Self == BoingTransition {
    static var boing: BoingTransition { get }
    static func boing(strength: MicroInteractionStrength) -> BoingTransition
}
```

## ⚠️⚠️ 「弹」这件事只能靠 `Animatable`，不能靠调用方的 `.bouncy`

`TransitionPhase` 是 3 case frozen enum ⇒ `body(content:phase:)` 只拿得到 `-1` / `0` / `1`。
**如果只把最终的 scale 交给 SwiftUI 去插值，两端之间得到的是一条直线——缩放永远不会
超过 1，"弹"从未发生**，而纯函数判据对那种实现**照样绿**。

⇒ `BoingMotion` conform `Animatable`、`animatableData` 绑在**相位值**上：
SwiftUI 逐帧把相位插到中间，本文件再把它过一遍阻尼余弦（`TransitionCurve.elastic`）。

**也不指望调用方写 `withAnimation(.bouncy)`**：那把"这个转场叫 boing"变成了调用点的
责任，且换一条曲线就不弹了。

承重判据 `boingOvershootSurvivesInterpolation` 钉的是**渲染出来的那一帧**：
把两端的 `animatableData` 插到 `amount = 0.45`（⇒ 相位 `-0.55`，阻尼余弦已翻负号），
渲染，要求它的**内容占地面积大于恒等帧**。实测变异：把 `Boing.scale` 改成线性
⇒ 该判据与 `elasticCurvesActuallyOvershoot` 同时判红；撤掉 `Animatable` 一致性
⇒ 该判据 + `motionModifiersAnimateOnThePhaseValue` +
`interpolationIsContinuousNotAnEndpointJump` 三条同时判红。

## 曲线

```
scale(v) = 1 - elastic(v, amplitude: A, cycles: 1.25)
elastic  = A · (1-u)² · cos(2π · 1.25 · u)，u = 1 - |v|
```

| 相位值 | 缩放 |
|---|---|
| `±1` | `1 - A`（`.regular` ⇒ 0.4） |
| 峰值（`v ≈ ±0.55`） | ≈ `1.17`（**过冲**） |
| `0` | **`1`**（精确） |

⚠️ 衰减窗 `(1-u)²` **不能换成 `exp(-ku)`**：指数在 `u == 1` 处不为 0，恒等相位会留下
一点点残余缩放——那是**永久**的。实测变异（换成 `exp(-3u)`）⇒
`identityPhaseIsExactlyNeutral` 与 `identityFrameIsIndistinguishableFromPlainContent`
同时判红。

`cycles = 1.25`：调大会让"弹"变成"抖"；调到 `< 0.5` 则余弦在窗口内不换号、过冲消失
（`elasticCurvesActuallyOvershoot` 判红）。

## 强度

复用 `MicroInteractionStrength`（本仓唯一的强度枚举），但**不复用它的 `scaleDelta`**：
那三个数是 0.06 / 0.14 / 0.24，量级是"轻轻胀一下"，`.regular` 用 0.14 意味着入场起手就是
0.86 倍——和不做缩放没有区别。映射另写在 `Boing.amplitude(for:)`：
`.subtle` 0.35 / `.regular` 0.6 / `.pronounced` 0.85。
