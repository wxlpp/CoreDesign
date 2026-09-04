# SkidTransition（`.skid`）

刹车打滑转场 / A skidding slide-in。`CoreDesignEffects/SkidTransition.swift`，Issue #267。

> 六条转场共用的形态与契约见
> [`transition-cluster-3d-elastic.md`](transition-cluster-3d-elastic.md)。

## API

```swift
public struct SkidTransition: Transition {
    public let edge: Edge
    public let travel: TransitionTravel
    public init(edge: Edge = .leading, travel: TransitionTravel = .regular)
    public func body(content: Content, phase: TransitionPhase) -> some View
}

public extension Transition where Self == SkidTransition {
    static var skid: SkidTransition { get }
    static func skid(edge: Edge = .leading,
                     travel: TransitionTravel = .regular) -> SkidTransition
}
```

## 与 `.swoosh` / `.move` 的分界

| | 方向 | 曲线 | 附带 |
|---|---|---|---|
| `.move` | 同侧进出 | 线性 | 无 |
| `.skid` | **同侧**进出 | **阻尼余弦**（冲过头再回） | 甩尾旋转 |
| `.swoosh` | 穿行（进出异侧） | 线性 | 动态模糊 + 拉伸 |

位移与甩尾角共用 `TransitionCurve.elastic`（`cycles = 0.8`，冲过头一次再刹住、不来回抖），
它吃的是取过绝对值的 `distance` ⇒ **同侧**：从哪来、回哪去。

甩尾与位移**同相**（同一条 `elastic`）⇒ 冲过头的时候车身也跟着往回甩，
而不是各自为政。最大甩尾角 7°；竖直方向进出时符号取反，否则看起来像在"倒着甩"。

## 与 `.boing` 是同一条曲线

只是作用在**位移与旋转**而不是缩放上。曲线在 `TransitionSupport.swift` 只有一份，
不各写一遍——过冲同样只能靠层 3 的 `Animatable` 绑有符号相位值，理由逐字同
[`boing-transition.md`](boing-transition.md)。

## Reduce Motion

位移与旋转**各自**带三元门控，一并归到恒等值，只剩淡入淡出。

实测变异：把 `.offset(` 的门控去掉
⇒ `MicroInteractionReduceMotionGuard.everyMotionCallIsGated` 与
`TransitionClusterTests.reduceMotionLeavesExactlyTheCrossFade` 同时判红
（这一处运动**在**守卫的关键字表里，与 `swoosh` 的模糊不同）。

另：把 `SkidTransition.swift` 从 `approvedFormTwo` 名单里拿掉
⇒ `formTwoListMatchesReality` 与 `motionFilesDegradeConsistently` 判红
——这就是"守卫真的看得见这些新文件"的活证据。
