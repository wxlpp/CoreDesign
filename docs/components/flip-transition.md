# FlipTransition（`.flip`）

卡片翻面转场 / A card-flip transition。`CoreDesignEffects/FlipTransition.swift`，Issue #267。

> 三层形态、相位契约、Reduce Motion 与登记口径是**六条转场共用**的，写在
> [`transition-cluster-3d-elastic.md`](transition-cluster-3d-elastic.md)，本文不重复。

## API

```swift
public struct FlipTransition: Transition {
    public let axis: TransitionAxis3D
    public nonisolated static let quarterTurn: Double   // 90
    public init(axis: TransitionAxis3D = .horizontal)
    public func body(content: Content, phase: TransitionPhase) -> some View
}

public extension Transition where Self == FlipTransition {
    static var flip: FlipTransition { get }
    static func flip(axis: TransitionAxis3D) -> FlipTransition
}
```

```swift
if showsBack {
    Card { ... }.transition(.flip)
}
```

## 几何

| 相位值 | 旋转角 | 不透明度 |
|---|---|---|
| `-1`（`.willAppear`） | `-90°` | 0 |
| `0`（`.identity`） | **`0°`** | 1 |
| `+1`（`.didDisappear`） | `+90°` | 1 → 0 |

角度直接是 `phaseValue × quarterTurn`，**有符号** ⇒ 翻进来与翻出去朝相反方向转。
取 `abs` 会让两侧塌成同一个动作倒放，卡片翻面的方向感就没了
（判据 `directionSemanticsMatchTheDocumentedTable` 钉住 `angle(-1) == -angle(1)`）。

`Flip.perspective = 0.55`：0 是正交投影，翻起来像被压扁的矩形，没有"卡片"感。

角度做了 `max(-1, min(1, phaseValue))` 钳位——带过冲的动画曲线（`.bouncy` / `.spring`）
会让 `animatableData` 越过 ±1，不钳会翻过 90° 露出背面。

## 与 `.rotate3D` 的分工

`.flip` 的角度**钉死** 90°（恰好侧对镜头）、默认水平轴、除淡入淡出外无附加效果；
`.rotate3D` 角度与轴都由调用方给（默认 75° 斜轴）并额外向纵深缩小。
两者共用 `TransitionAxis3D`，**不各自定义一份轴枚举**。

## `nonisolated static let quarterTurn`

`public` 是因为本仓约定 `public` 签名的默认实参不许引用 internal 符号
（`ParticleTransition.defaultCount` 记着同一条）。

⚠️ **`nonisolated` 是必需的、不是装饰**：本包开了 `.defaultIsolation(MainActor.self)`，
而几何函数住在 `nonisolated enum Flip` 里 ⇒ 不标就是
`main actor-isolated static property … can not be referenced from a nonisolated context`
（实测一条警告）。同一条适用于 `Rotate3DTransition.defaultDegrees` /
`PolarMoveTransition.defaultDegrees`。

## Reduce Motion

旋转经三元门控到 `0°`，只剩淡入淡出。文件在
`MicroInteractionReduceMotionGuard.approvedFormTwo` 名单上、**不在** `approvedEarlyExit` 上。
