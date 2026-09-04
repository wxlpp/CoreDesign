# SwooshTransition（`.swoosh`）

带动态模糊的穿行转场 / A directional swoosh with motion blur。
`CoreDesignEffects/SwooshTransition.swift`，Issue #267。

> 六条转场共用的形态与契约见
> [`transition-cluster-3d-elastic.md`](transition-cluster-3d-elastic.md)。

## API

```swift
public struct SwooshTransition: Transition {
    public let edge: Edge
    public let travel: TransitionTravel
    public init(edge: Edge = .trailing, travel: TransitionTravel = .regular)
    public func body(content: Content, phase: TransitionPhase) -> some View
}

public extension Transition where Self == SwooshTransition {
    static var swoosh: SwooshTransition { get }
    static func swoosh(edge: Edge = .trailing,
                       travel: TransitionTravel = .regular) -> SwooshTransition
}
```

## 「穿行」不是「同侧进出」

位移取**有符号**的相位值：`.willAppear` 从 `edge` 那一侧进来、`.didDisappear`
朝**对侧**出去，读作"一样东西被推走、另一样顶上来"（同 SwiftUI 自带的 `.push`）。
`.move` / `.skid` 则是同侧进出。⚠️ 两种语义都要，别合并成一个带 Bool 开关的转场（J-1）。

实测变异：把 `Swoosh.travel` 里的钳位换成 `TransitionCurve.distance`（取绝对值）
⇒ `directionSemanticsMatchTheDocumentedTable` 判红。

## 几何

| 量 | 两端 | 恒等 |
|---|---|---|
| 位移 | `±travel.points`，方向按 `edge` | **`.zero`** |
| 沿运动方向拉伸 | `1 + 0.16` | **`1`** |
| 动态模糊 | `6pt` | **`0`** |
| 不透明度 | `0` | `1` |

## ⚠️ 模糊落在守卫的盲区里，靠位图判据兜底

`blur(` **不在** `MicroInteractionReduceMotionGuard.motionCalls` 的关键字表里
（它不是位移 / 旋转 / 缩放）⇒ 那份守卫对它无话可说。但模糊是这条转场"速度感"的一半，
Reduce Motion 下留着它就等于把"快速掠过"这个观感留给了明确要求减弱动态效果的用户。

⇒ 本文件仍然逐表达式门控它，由
`TransitionClusterTests.reduceMotionLeavesExactlyTheCrossFade`
（降级那一帧与「只加 `.opacity`」的对照组**逐字节**相同）钉住。

实测变异：把 `.blur(radius: self.isReduced ? 0 : …)` 的门控去掉
⇒ `MicroInteractionReduceMotionGuard` 的三条 RM 判据**全绿**，只有上面那条相等断言判红。
`scaleEffect(x:y:)` 的拉伸同理。

## `TransitionTravel`

`.short` 36pt / `.regular` 80pt / `.long` 160pt。

⚠️ 与 `MicroInteractionStrength` 并列而**不复用**它：那个枚举的 `displacement`
是 4 / 9 / 16 pt，量级是"抖一下"；转场要把内容整个送出视野，量级差一个数量级。
硬塞进同一个枚举会逼其中一边接受不合适的数。
