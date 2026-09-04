# PolarMoveTransition（`.move`）

任意极角的平移转场 / A polar (angle + distance) move。
`CoreDesignEffects/PolarMoveTransition.swift`，Issue #267。

> 六条转场共用的形态与契约见
> [`transition-cluster-3d-elastic.md`](transition-cluster-3d-elastic.md)。

## API

```swift
public struct PolarMoveTransition: Transition {
    public let angle: Angle
    public let distance: CGFloat
    public nonisolated static let defaultDegrees: Double   // 90（向下）
    public init(angle: Angle = .degrees(PolarMoveTransition.defaultDegrees),
                distance: CGFloat = TransitionTravel.regular.points)
    public func body(content: Content, phase: TransitionPhase) -> some View
}

public extension Transition where Self == PolarMoveTransition {
    static var move: PolarMoveTransition { get }
    static func move(angle: Angle = .degrees(PolarMoveTransition.defaultDegrees),
                     distance: CGFloat = TransitionTravel.regular.points) -> PolarMoveTransition
}
```

```swift
HintBubble().transition(.move(angle: .degrees(-60), distance: 120))
```

极角：0° 指向右、90° 指向下（SwiftUI 的 y 轴朝下）。

## ⚠️⚠️ 类型名不叫 `MoveTransition`，这不是笔误

`SwiftUICore` **已有** `public struct MoveTransition` 与
`extension Transition where Self == MoveTransition { static func move(edge:) }`。

同名类型在下游同时 `import SwiftUI` 与 `import CoreDesignEffects` 时会**歧义**
——而本模块内部靠 shadowing 照样编译得过，也就是说**库自己 `swift build` 全绿、
红的是调用方**。这是最坏的失效形态。⇒ 类型名取 `PolarMoveTransition`
（极坐标：角 + 距离，正是它与系统那个的差别）。

**静态成员仍叫 `move`**，与系统那个构成**重载**而不是覆盖：

| 写法 | 解析到 |
|---|---|
| `.move(edge: .top)` | `SwiftUICore.MoveTransition`（系统的，**不受影响**） |
| `.move(angle:distance:)` | `PolarMoveTransition` |
| `.move` | `PolarMoveTransition`（系统没有无参形态） |

实参标签不同 ⇒ 重载解析无歧义。

> ⚠️⚠️ **守住这张表的是 `scripts/downstream-probe`，不是库内判据。**
>
> 这里原先写着「`TransitionClusterTests.systemMoveEdgeStillResolvesToSwiftUI`
> ……哪天有人把我们的签名改成 `move(edge:)` 就会判红」——**实测是假的**（#267 终审 C-4）：
> 把那条回归注进去（新增 `static func move(edge: Edge) -> PolarMoveTransition`），
> `swift build` 报 `Build complete!`、`TransitionClusterTests` 全过，
> 而**同一份源码在真实外部消费者 target 上**报 `error: ambiguous use of 'move(edge:)'`。
> 原因是那条判据写的是 `let system: MoveTransition = .move(edge: .top)`
> ——**显式结果类型标注按返回类型消歧了**；真实调用方写的是无标注的
> `.transition(.move(edge: .top))`。
>
> ⇒ 真正的守卫在 `scripts/downstream-probe/Sources/DownstreamProbe/TransitionClusterProbe.swift`
> （跨模块，才复现得出下游的形态），两条各守一半：
> · `systemMoveEdgeKeepsResolvingToSwiftUI` —— `-> MoveTransition` 的返回位置，
>   守**类型名**冲突（把本类型改回 `MoveTransition` ⇒
>   `'MoveTransition' is ambiguous for type lookup in this context`）；
> · `systemMoveEdgeIsUnambiguousWithoutAnyAnnotation` —— 无标注的
>   `.transition(.move(edge: .top))`，守**实参标签**冲突。
>
> 库内那条判据只剩「我们没把系统那个截胡」这一句，射程仅限于此。

## 几何

线性、**同侧**、无附加效果：

```
travel(v) = distance(v) · d · (cos θ, sin θ)      // distance(v) = |v| 钳在 0...1
```

| 相位值 | 位移 | 不透明度 |
|---|---|---|
| `±1` | 满距离（同一个方向） | 0 |
| `0` | **`.zero`** | 1 |

要过冲用 [`.skid`](skid-transition.md)，要穿行 + 动态模糊用 [`.swoosh`](swoosh-transition.md)。

实测变异：把 `distance` 钳位换成有符号的 `max(-1, min(1, v))`（同侧变穿行）
⇒ `directionSemanticsMatchTheDocumentedTable`（纯函数）与
`directionSemanticsReachThePixels`（位图）同时判红。
