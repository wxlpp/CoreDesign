# DotSphere

自转的点球 / A slowly rotating sphere of dots.

`DotSphere`（`CoreDesignEffects/DotSphere.swift`，Issue #254）。

```swift
import CoreDesign
import CoreDesignEffects
```

⚠️ **两个 import 一个都不能少**：全仓 `@_exported` 为 0。

## API

```swift
public struct DotSphere: View {
    public static let defaultCount: Int              // 800
    public static let defaultRotationPeriod: Double  // 24（秒 / 圈）
    public init(count: Int = DotSphere.defaultCount,
                colors: [Color] = [],
                rotationPeriod: Double = DotSphere.defaultRotationPeriod)
}
```

```swift
ZStack {
    DotSphere()                     // 空色板 ⇒ 全部取调用方的 .tint
    content
}
.tint(.indigo)
```

## 平台支持

| 平台 | 行为 |
|---|---|
| iOS 26+ | 完整可用 |
| macOS 26+ | **完整可用，与 iOS 逐行同一份代码** |

本件**没有任何条件编译**。上游 ShipSwift 的 `SWDotSphere` 有一句
`#if canImport(UIKit) import UIKit`，它只服务一件事：`UIColor(color).getRed(&r,&g,&b,&a)`
把 `Color` 拆成 RGB 分量做插值（它自己的 `#else` 分支已经在用跨平台的
`Color.resolve(in:)`）。本仓两条纪律各堵掉那件事的一半：取色只有三个合法来源
（不许写 `Color(red:green:blue:)`，`EffectsColorLiteralGuard` 对数值构造直接判红），
插值改走 SwiftUI 自己的 `Color.mix(with:by:)` ⇒ **不需要**拆分量，那个 UIKit 依赖
连同平台分支一起消失。三维投影本身是纯算术，与 UIKit 无关。

⇒ 在 macOS 上它**不是"能编译但空转"**：同样自转、同样取色、同样接能耗闸。
判据：`PlatformSupportGuard.noPlatformOnlyImports` +
`PlatformSupportGuard.everyPlatformFenceHasAnElse`（本 target 全域扫描）。

## 取色（FR-8）

- `colors` **非空** ⇒ 按时间在色板之间循环渐变，逐点延迟让浪**从下往上洗**；
- `colors` **为空** ⇒ 回落到调用方的 **`.tint`**。这一档下点云是一张 alpha 遮罩
  （`Color.primary` 恒不透明，`mask` 只吃 alpha 通道），**不凭空造色相**，
  只把调用方那一个色相铺成有景深的点云——与 `AnimatedMeshGradient` 同一个手法。

**不给"好看的默认色板"**：那是品牌决定，`.spray` / `.confetti` /
`AnimatedMeshGradient` 已就同一件事立过规矩。

判据：`CrossPlatformRenderTests.spheresFollowTheCallerTint`（空色板下换 `.tint`
位图必须变；给了色板则必须**不**变）。

## Reduce Motion

**冻结在某一帧**：自转相位钉在 `SphereField.restingPhase`、色波钉在
`SphereField.restingWave(paletteCount:)`，球照常画。走**降级形态 2**
（保留"长什么样"、只去掉运动、不叠透明度脉冲）。

⚠️ **不是 no-op**——这是一块背景面，抹掉它等于把界面的底色拿走。

判据：`MicroInteractionReduceMotionGuard`（`SphereSurface.swift` 同时在早退名单与
形态 2 名单上，两个方向双向差集）+ `CrossPlatformRenderTests.restingPhaseStillDraws`
（静止相位画得出东西，且与别的相位不是同一张图）。

## 后台 / 低电量（NFR-7）

| 键 | 类型 | 默认 | 行为 |
|---|---|---|---|
| `\.scenePhaseOverride` | `ScenePhase?` | `nil` ⇒ 读系统 `\.scenePhase` | `.inactive` / `.background` ⇒ **整层不建** |
| `\.lowPowerModeOverride` | `Bool?` | `nil` ⇒ 读 `ProcessInfo` | `true` ⇒ 降到 15 fps，**点数减半** |

两道闸的顺序（先能耗、后 Reduce Motion）在共用纯函数
`EffectsEnergyState.presentation(reduceMotion:)` 里，与 `Confetti` /
`ProcessingSweep` / `AnimatedMeshGradient` **同一份**。

⚠️ **已知限度**：`.inactive` 下这块背景面会在**可见窗口里**变空白
（macOS 失焦、iPadOS 台前调度都会报 `.inactive`）。完整记账见
`EffectsEnergyState.policy` 的文档；需要规避的宿主 App 自行注入
`\.scenePhaseOverride = .active`。

## 退化输入

| 输入 | 行为 |
|---|---|
| `count <= 0` | 一个点都不画，不崩 |
| `count > 3000` | **截断**到 3000（不 `precondition`——库代码对数据规模抛断言就是让宿主 App crash） |
| `rotationPeriod <= 0` | 退化为静止，不是 NaN |
| 容器尺寸为 0 | 世界半径为 0，投影显式退化到 `depth = 1`，不放 NaN 进 `Canvas` |

判据：`SphereFieldTests` 的四条 + `CrossPlatformRenderTests.degenerateInputsDoNotCrash`。

## a11y（FR-13）

点云是**纯装饰**，已 `accessibilityHidden(true)` / `allowsHitTesting(false)`。
它不承载任何语义——语义由它背后 / 上面的内容提供。

## ⚠️ 登记

`public struct DotSphere` **不**进 `docs/component-registry.json` 的 `components`：
`ComponentRegistryGuard.coreDesignSources` 仍是单根 `Sources/CoreDesign`，塞进去会被
判成幽灵条目（同 #250 `Shine` / #252 三容器 / #253 三件的处置；该口子由 issue #270 收口）。
本件也**没有** `public extension View` / `Transition` 成员 ⇒ `entryPoints` 同样零改动。
