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

⚠️ **本件强制为正方形**（`aspectRatio(1, contentMode: .fit)`）：环是圆的，非等比容器里
画出来的是椭圆环。给它 `320 × 200` 会得到 `200 × 200` 的内容 + 上下留白（信箱边）。
需要非方形版面的，请自己决定裁剪 / 定位，本件不猜。

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

⚠️ **两条路都直接给 `Canvas` 上色，不再走 `Rectangle().fill(.tint).mask { … }`**
（PR #274 终审 C-2）：旧写法用 `Color.primary` 当遮罩色，而 `.primary` 实测 `a = 0.8471`
（不是注释宣称的"恒不透明"）⇒ `.tint` 那条路比显式色板那条路暗 15%。
逐条实测数字见 [`dot-sphere.md`](dot-sphere.md) 的《取色》一节。

判据：`CrossPlatformRenderTests.orbitFollowsTheCallerTint`
+ `tintPathMatchesSinglePalette`（**承重**：两条路必须渲成同一张图）。

## Reduce Motion

**冻结在某一帧**：自转钉在 `OrbitRing.restingPhase`、轮播钉在
`OrbitRing.restingFeature`（⇒ `popScale == 1`，谁都不放大）。走**降级形态 2**。

⚠️ **不是 no-op**：logo 与中心视图照常显示，只是不动。

## 后台 / 低电量（NFR-7）

| 档 | 环 + `Canvas` + 调度器 | 调用方的 `logo` 与 `center` |
|---|---|---|
| `.inactive` / `.background` | **一个像素都不画** | **照常静态显示** |
| 低电量 | 15 fps、每环点数减半（23 → 12） | 照常显示，**座位跟着变稀的环挪** |

两道闸的顺序在共用纯函数 `EffectsEnergyState.presentation(reduceMotion:)` 里；
第三道是"周期非法"闸（见下面《退化输入》）。

⚠️⚠️ **`.none` 档在本件上是收窄的：只摘装饰，不摘内容**（PR #274 终审 C-1）。

`0.4.x` 之前 `.none` 返回 `EmptyView()` ⇒ 宿主 App 的品牌 logo 与全部合作方 logo
在**完全可见的窗口里**凭空消失，VoiceOver 也一并丢掉这些元素——而 macOS 上 `.inactive`
就是"窗口不是前台"（窗口照常显示），iPadOS 上是台前调度后台。本仓已就这一情形裁决过，
`MicroInteractionReduceMotionGuard.energyGatedFiles` 逐字：

> 能耗闸的 `.none` 语义是「一个像素都不画」，而它们画的是**内容**，
> 把内容隐藏不是停摆、是 bug。

那正是 `BeforeAfterSlider` / `ParticleTransition` 被**刻意排除**在能耗闸之外的理由。
本件画的同样是内容（`logo(item)` / `center`，两者都**有意不** `accessibilityHidden`）
⇒ 规则收窄为：**`.none` 摘掉的是装饰层与调度器，内容层静态留下**。
之前那句"需要规避的宿主 App 自行注入 `\.scenePhaseOverride = .active`"是在**记录症状**，
并把一个已判定为 bug 的默认行为的 opt-out 推给每个消费方 —— 已删。
装饰层（环）的完整记账仍见 `EffectsEnergyState.policy`。

⚠️ **低电量下 logo 必须跟着环挪**（终审 S-3）：低电量时每环只画 `round(23 × 0.5) = 12`
个点，座位数若还钉在标称的 23，logo 会悬在环点**之间**——本件"logo 坐在环上巡游"的
整个视觉立意就没了。`OrbitRing.logoAngle(logoIndex:logoCount:dotsPerRing:turns:)` 把
座位数收成参数，绘制层传的是**这一档真的画出来的**点数。

判据：`CrossPlatformRenderTests.pausedKeepsCallerContentInOrbitingLogos`（内容还在）
+ `orbitPresentationBranchesAreWiredCorrectly`（装饰层不建）
+ `logoSeatsFollowTheThinnedRing`（把环画成 `.clear`，位图上只剩 logo，低电量下必须挪位）
+ `OrbitRingTests.logoAnglesSitOnRealSeatsAndNeverCollide`。

## 退化输入

| 输入 | 行为 |
|---|---|
| `items` 为空 | 只画点环与中心视图，不崩 |
| 条目数 `<=` 外环座位数 | 每个 logo 一个专属环点，**两两不同** |
| 条目数 `>` 外环座位数（默认 23） | **改按角度均分**，不再吸附到环点——但仍然两两不重叠 |
| `rotationPeriod <= 0` | **整件冻结**：呈现降到 `.resting`，自转与轮播一并停，且**不建 `TimelineView`** |
| 点与被点名的 logo 重合 | 位移方向无定义 ⇒ 显式返回原位，不放 NaN 进 `Canvas` |

⚠️ **"条目数 > 座位数"这一行此前写的是「按 slot 取模，不越界」，那没描述真正的后果**
（PR #274 终审 S-4）：`slot` 的步长是 `dotsPerRing / logoCount`，`logoCount = 24` 时
步长 `< 1` ⇒ `slot(0) == slot(1) == 0`，**两个 logo 在屏幕上完全重叠**。
旧判据只测了 4 与 99 两个数量，正好跨过中间这一段。
⇒ 超出座位数时改为按角度均分：logo 不再落在点上（本来也没有那么多点可坐），
但至少互不重叠、仍然摊开整整一圈。

⚠️ **`rotationPeriod <= 0` 这一条在 `0.4.x` 之前不是真的**（终审 I-4）：
`OrbitRing.turns(period: 0)` 只让自转冻结，而 `OrbitRing.feature(at:logoCount:)`
**不吃** `rotationPeriod` ⇒ logo 仍每 2.4s 弹一次；呈现档仍是 `.animated`
⇒ `TimelineView(.animation)` 照常建、满帧跑只为产出同一批帧。
现在由 `EffectsPresentation.frozenIfPeriodIsDegenerate(_:)` 这道第三闸统一降到 `.resting`。

判据：`OrbitRingTests` 的七条 + `CrossPlatformRenderTests.degenerateInputsDoNotCrash`
+ `DegeneratePeriodTests.degeneratePeriodFreezesAnimated`
+ `CrossPlatformRenderTests.degeneratePeriodRendersTheRestingFrame`。

## a11y（FR-13）

- **点环是纯装饰** ⇒ `accessibilityHidden(true)` / `allowsHitTesting(false)`；
- ⚠️ **logo 与中心视图不隐藏**：它们是调用方给的内容，a11y **由调用方在自己的视图上
  提供**（这正是 FR-13 那条"承载语义的部分由调用方通告"的分工）。本件不代劳、也不猜文案。

⚠️ 上面这一条正是《后台 / 低电量》里 `.none` 只摘装饰的**直接依据**：能耗闸如果把
整件删掉，被删掉的会包括这些**没有隐藏、承载语义**的元素。

## ⚠️ 登记

同两个球面件：不进 `components`（扫描根仍是单根 `Sources/CoreDesign`），
也没有扩展成员 ⇒ `entryPoints` 零改动。
