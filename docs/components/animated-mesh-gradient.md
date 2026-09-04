# AnimatedMeshGradient

持续漂移的 3 × 3 网格渐变背景面 / A continuously drifting mesh gradient surface.

`AnimatedMeshGradient`（`CoreDesignEffects/AnimatedMeshGradient.swift`，Issue #253）。
**容器视图形态**（一个独立的 `View`，通常用作背景层）。

```swift
import CoreDesign
import CoreDesignEffects
```

⚠️ **两个 import 一个都不能少**：全仓 `@_exported` 为 0。

## API

```swift
public struct AnimatedMeshGradient: View {
    public init(colors: [Color] = [], alternateColors: [Color] = [])
}
```

## 取色：**不自带调色板**（FR-8 / AC 逐字）

上游 ShipSwift 的默认 indigo / blue / cyan 是**硬编码色相**，在暗色模式与高对比度下
不会跟着变，本仓 `EffectsColorLiteralGuard` 对这一族直接判红。
⇒ 9 个色位 × 两组**全部**由调用方传入，或者一个都不传：

| 入参 | 行为 |
|---|---|
| `colors` 非空 | 按 9 个色位**循环补齐 / 截断**后直接进 `MeshGradient` |
| `colors` 为空 | 回落到调用方的 **`.tint`** |
| `alternateColors` 非空 | 两组色板之间**往复混合**（`Color.mix(with:by:)`）——AC 里「9 色 × 2 组」的第二组 |
| `alternateColors` 为空 | 颜色不变，只有网格点在漂 |

⚠️ **`.tint` 那一档跑的是透明度而不是色相**：`Rectangle().fill(.tint)` 被一张由
`Color.primary.opacity(…)` 组成的网格**遮罩**（`mask` 吃 alpha 通道，`.primary` 恒不透明
——与写死白色等效但它是语义色，`ProcessingSweep.glowRing` 用的是同一个手法）。
⇒ 没有色板时本组件**不凭空造色相**，只把调用方那一个色相铺成有层次的面。

⚠️ **为什么不给一个"好看的默认色板"**：那是品牌决定，不是设计系统该替调用方做的。
`.spray` / `.confetti` 已就同一件事立过规矩。

判据：`AnimatedMeshGradientTests.emptyPaletteFollowsCallerTint`（空色板下换 `.tint` 位图
必须变；给了色板则必须**不**变）+ `alternatePaletteReachesRendering`。

## Reduce Motion

**冻结在某一帧**：网格点钉死在 `MeshDrift.restingPhase`，整层仍然照常绘制。
**不是 no-op**——这是一块背景面，抹掉它等于把界面的底色拿走。
走**降级形态 2**（保留"长什么样"、只去掉运动、不叠透明度脉冲）。

⚠️ `restingPhase = 0.125` 而不是 `0`：`0` 上所有内点恰好回到规则网格，那一帧看起来
像一张没做任何事的普通渐变；`0.125` 是漂移幅度接近峰值的一帧
（同 `ProcessingSweep.restingPhase` 的理由）。

## 后台与低电量（NFR-7）

本组件**是常驻渲染件**（`TimelineView` 持续驱相位），与 `ScanningOverlay` / `Confetti` 同类。

| 键 | 类型 | 默认 | 行为 |
|---|---|---|---|
| `\.scenePhaseOverride` | `ScenePhase?` | `nil` ⇒ 读系统 `\.scenePhase` | `.inactive` / `.background` ⇒ **整层不建** |
| `\.lowPowerModeOverride` | `Bool?` | `nil` ⇒ 读 `ProcessInfo.isLowPowerModeEnabled` | `true` ⇒ 降到 15 fps，并去掉柔化用的离屏模糊 |

⚠️⚠️ **顺序是承重的：先 NFR-7 的能耗闸，再 Reduce Motion 闸**。这个顺序不由本文件实现
——它在 `EffectsEnergyState.presentation(reduceMotion:)` 里，与 `ConfettiCore` /
`ProcessingSweepDriver` **共用同一份**。此前两处各写一遍时 `Confetti` 就把顺序写反了，
而当时全套测试是绿的（#252 PR #269 第 1 轮终审 I-1 / I-2）。

## ⚠️ 已知限度：`.inactive` 下这块面会从 App 切换器的快照里消失

「`.inactive` / `.background` ⇒ 一个像素都不画」是本仓既有的、有机器判据守着的停摆语义
（`EffectsRenderPolicy.drawsAnything` 的文档逐字：「调用方应当**整层不建**」）。
对 `ScanningOverlay` 那类**盖在内容上的小装饰**它无副作用；而本组件是一整块**背景面**
⇒ App 切换器里那张快照（`.inactive`）会缺掉底色。

**本轮按既有语义落地、不为一个组件另开一档**：「两处各写一遍必然漂移」正是本仓反复在堵的
形态，而 `EffectsPresentation` 的存在本身就是那次漂移的产物。
⇒ 这条**登记为已知限度**，处置属 epic 级裁决（要么给 `EffectsRenderPolicy` 增设
「停摆但保留静止帧」一档并同时改三个调用点，要么接受快照缺底色）。
需要立刻规避的宿主 App 可以自己注入 `\.scenePhaseOverride = .active`。

## a11y 分工（FR-13）

背景面是**纯装饰**，已 `accessibilityHidden(true)` / `allowsHitTesting(false)`——
语义由它背后 / 上面的内容提供。

## 使用示例 / Usage

```swift
import CoreDesign
import CoreDesignEffects
import SwiftUI

struct BrandHero: View {
    var body: some View {
        ZStack {
            AnimatedMeshGradient()          // 空色板 ⇒ 全部取调用方的 .tint
            Text("Welcome")
                .font(.largeTitle.bold())
                .foregroundStyle(Color.contentOnAccent)
        }
        .frame(height: 220)
        .clipShape(CoreShape.rounded(CoreRadius.xLarge))
        .tint(.accent)
    }
}
```

两组色板的形态：

```swift
AnimatedMeshGradient(
    colors: [.surfaceRaised, .surfaceInteractive, .tertiaryFill],
    alternateColors: [.secondaryFill, .surfaceRaised, .quaternaryFill]
)
```

⚠️ **本文档的示例代码零机器覆盖**（与 `confetti.md` 同一条登记）。
