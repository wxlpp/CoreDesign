# Rotate3DTransition（`.rotate3D`）

空间翻滚转场 / A free-axis 3D tumble。`CoreDesignEffects/Rotate3DTransition.swift`，Issue #267。

> 六条转场共用的形态与契约见
> [`transition-cluster-3d-elastic.md`](transition-cluster-3d-elastic.md)。

## API

```swift
public struct Rotate3DTransition: Transition {
    public let angle: Angle
    public let axis: TransitionAxis3D
    public nonisolated static let defaultDegrees: Double   // 75
    public init(angle: Angle = .degrees(Rotate3DTransition.defaultDegrees),
                axis: TransitionAxis3D = .tilted)
    public func body(content: Content, phase: TransitionPhase) -> some View
}

public extension Transition where Self == Rotate3DTransition {
    static var rotate3D: Rotate3DTransition { get }
    static func rotate3D(angle: Angle = .degrees(Rotate3DTransition.defaultDegrees),
                         axis: TransitionAxis3D = .tilted) -> Rotate3DTransition
}
```

## 几何

| 相位值 | 旋转角 | 缩放 | 不透明度 |
|---|---|---|---|
| `±1` | `±angle` | `Rotate3D.depthScale` = 0.82 | 0 |
| `0` | **`0°`** | **`1`** | 1 |

默认 75° 而**不取 90°**：那正好是 `.flip` 的取值，两条转场会在默认形态上撞脸；
75° 留出一点正面，翻滚感更强而不至于完全侧对镜头。透视 `0.7`。

## ⚠️ 两处运动各自带门控

旋转与缩放**各写一处** `self.isReduced ? 恒等值 : …`。
「缩放也算运动」这一条正是 `#250` 第 1 轮 `Jump` 的原缺陷形态
（`offset` 门控了、`scaleEffect` 没门控，而当时的守卫**全绿放行**）
⇒ 由 `MicroInteractionReduceMotionGuard.everyMotionCallIsGated` 逐实参检查，
再由 `reduceMotionLeavesExactlyTheCrossFade` 的位图相等断言兜底。

实测变异：把 `Rotate3D.scale` 的恒等值从 `1` 改成 `0.99`（肉眼看不出的永久形变）
⇒ `identityPhaseIsExactlyNeutral` 与 `identityFrameIsIndistinguishableFromPlainContent`
两条同时判红。

## `TransitionAxis3D`

命名按**内容看起来往哪个方向转**，不是按数学轴名——这一条容易记反：

| case | 转轴 | 读作 |
|---|---|---|
| `.horizontal` | `(0, 1, 0)` | 内容水平翻过去 |
| `.vertical` | `(1, 0, 0)` | 内容垂直翻过去 |
| `.depth` | `(0, 0, 1)` | 内容在自己平面内打转 |
| `.tilted` | `(1, 1, 0)` | 斜向翻滚 |

判据 `sharedEnumsAreWellFormed` 钉住 `.horizontal` 的转轴是竖直的 Y 轴，
以及四个向量两两不同。
