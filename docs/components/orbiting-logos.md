# OrbitingLogos

同心轨道上巡游的 logo / Logos orbiting on concentric rings.

`OrbitingLogos`（`CoreDesignEffects/OrbitingLogos.swift`，Issue #254）。

```swift
import CoreDesign
import CoreDesignEffects
```

⚠️ **两个 import 一个都不能少**：全仓 `@_exported` 为 0。

## API

```swift
public struct OrbitingLogos<Data: RandomAccessCollection, Logo: View, Center: View>: View
where Data.Element: Identifiable {
    public static var defaultRotationPeriod: Double { get }   // 10（秒 / 圈）
    public init(_ items: Data,
                colors: [Color] = [],
                rotationPeriod: Double = OrbitingLogos.defaultRotationPeriod,
                @ViewBuilder logo: @escaping (Data.Element) -> Logo,
                @ViewBuilder center: () -> Center)
}
```

```swift
OrbitingLogos(brands) { brand in
    Image(brand.assetName).resizable().scaledToFit().frame(width: 34, height: 34)
} center: {
    Image("AppLogo").resizable().scaledToFit().frame(width: 64, height: 64)
}
.tint(.accent)
.frame(width: 300, height: 300)
```

四圈同心点环持续自转，`items` 均匀落在最外环上随之巡游；每隔
`OrbitRing.featureSeconds`（2.4s）轮到一个条目**弹出放大**、把附近的点挤开；
中心是调用方的视图。数据入参是泛型集合 + `Identifiable`，不绑定具体模型类型。

## 平台支持

| 平台 | 行为 |
|---|---|
| iOS 26+ | 完整可用 |
| macOS 26+ | **完整可用，与 iOS 逐行同一份代码** |

⚠️ **SpriteKit 已被整件替换掉，本件没有任何条件编译。**

上游 `SWOrbitingLogos` 是一个 `SKScene`（`import SpriteKit`）：4 环 × 23 个
`SKShapeNode`，每个点挂一个 `SKPhysicsBody`；被点名的点放大到 4 倍、**靠物理碰撞**
把邻居挤开，再用 `SKAction.move(to:)` 序列送回原位。

⚠️ **不落 SpriteKit 的理由不是"macOS 上编译不过"**——SpriteKit 与 `SpriteView`
在 macOS 上都有，那条 import 本身是跨平台的。真正的理由是三条与本仓公约的正面冲突：

1. **两套渲染时钟**：`SKScene` 自带 display link，NFR-7 的能耗闸（`drawsAnything` /
   `minimumInterval`）是靠"根本不建 `TimelineView`"实现的，管不到一个自转的场景；
2. **Reduce Motion 无处插手**：`SKAction.repeatForever` 一旦 `run` 就自己跑，
   降级要在场景内部再实现一遍，必然与本仓共用的降级形态漂移（FR-11）；
3. **物理体的位移不可测**：本仓的判据形态是纯函数 + 位图，而 `SKPhysicsBody`
   的解算结果既不是纯函数、也不进 `ImageRenderer`。

⇒ 环与点用一个 `Canvas` 画（92 个点逐个建视图会让每帧重走布局，NFR-1），
物理挤压换成**解析位移场** `OrbitRing.pushed(_:awayFrom:radius:strength:)`。

⚠️ **照录与上游的差异**（不是漏做，是取舍）：上游的挤压是"点被撞开之后再用 0.6s
缓动送回"，有惯性余韵；本实现的位移**只是当前帧的函数**，没有惯性。
换来的是逐条可测（`OrbitRingTests.pushDisplacesOnlyNearbyDots`）与跟着能耗闸走。

## 取色（AD-D / FR-8）

上游在点上写死了一条绿色渐变（`SKColor(red:green:blue:alpha:)`），暗色模式与高对比度
下不会跟着变——`EffectsColorLiteralGuard` 对这一族直接判红。本件：

- `colors` **非空** ⇒ 按环上角度在色板里取色；
- `colors` **为空** ⇒ 取调用方的 **`.tint`**，环上的层次由**角向明暗波**给
  （同一个色相的明暗，不凭空造色相）。

判据：`CrossPlatformRenderTests.orbitFollowsTheCallerTint`。

## Reduce Motion

**冻结在某一帧**：自转钉在 `OrbitRing.restingPhase`、轮播钉在
`OrbitRing.restingFeature`（⇒ `popScale == 1`，谁都不放大）。走**降级形态 2**。

⚠️ **不是 no-op**：logo 与中心视图照常显示，只是不动。

## 后台 / 低电量（NFR-7）

`.inactive` / `.background` ⇒ **整层不建**；低电量 ⇒ 降到 15 fps 且**每环点数减半**。
两道闸的顺序在共用纯函数 `EffectsEnergyState.presentation(reduceMotion:)` 里。

⚠️ **已知限度**：`.inactive` 下整件会在**可见窗口里**消失（macOS 失焦、iPadOS
台前调度都会报 `.inactive`）。本件比一块背景面更显眼——需要规避的宿主 App
自行注入 `\.scenePhaseOverride = .active`。完整记账见 `EffectsEnergyState.policy`。

## 退化输入

| 输入 | 行为 |
|---|---|
| `items` 为空 | 只画点环与中心视图，不崩 |
| 条目数 > 外环 slot 数（23） | 按 slot 取模，不越界 |
| `rotationPeriod <= 0` | 退化为静止 |
| 点与被点名的 logo 重合 | 位移方向无定义 ⇒ 显式返回原位，不放 NaN 进 `Canvas` |

判据：`OrbitRingTests` 的六条 + `CrossPlatformRenderTests.degenerateInputsDoNotCrash`。

## a11y（FR-13）

- **点环是纯装饰** ⇒ `accessibilityHidden(true)` / `allowsHitTesting(false)`；
- ⚠️ **logo 与中心视图不隐藏**：它们是调用方给的内容，a11y **由调用方在自己的视图上
  提供**（这正是 FR-13 那条"承载语义的部分由调用方通告"的分工）。本件不代劳、也不猜文案。

## ⚠️ 登记

同两个球面件：不进 `components`（扫描根仍是单根 `Sources/CoreDesign`），
也没有扩展成员 ⇒ `entryPoints` 零改动。
