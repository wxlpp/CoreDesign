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
    public nonisolated static let defaultCount: Int              // 800
    public nonisolated static let defaultRotationPeriod: Double  // 24（秒 / 圈）
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
- `colors` **为空** ⇒ 回落到调用方的 **`.tint`**，**不凭空造色相**，只把调用方那一个
  色相铺成有景深的点云。

**不给"好看的默认色板"**：那是品牌决定，`.spray` / `.confetti` /
`AnimatedMeshGradient` 已就同一件事立过规矩。

⚠️⚠️ **两条路的量程必须逐字相同**（PR #274 终审 C-2）。`0.4.x` 之前空色板那条路走的是
`Rectangle().fill(.tint).mask { Canvas }`，遮罩色写的是 `Color.primary`，注释宣称
"`.primary` 恒不透明、与写死白色等效"——**实测为假**（macOS 26，明暗两端）：

```
Color.primary  light a=0.8471 | dark a=0.8471
Color.white    light a=1.0000 | dark a=1.0000
```

`Color.primary` 映射到 `label` / `labelColor`，是 **0.847 alpha**。`mask` 吃的正是 alpha
⇒ `.tint` 那条路上每个点的实际不透明度是 `0.8471 × alpha(depth:)`（景深区间
`0.28…1.0` 实际成了 `0.237…0.847`），比显式色板那条路（`tone.opacity(alpha)`，满量程）
**暗 15%**，而所有位图判据都是 `a != b` ⇒ 一条都抓不到。

⇒ 现在两条路都直接给 `Canvas` 上色（`.tint` / 色板色），不再有遮罩，也少一层离屏合成。
`Color.white` 走不通是因为 `EffectsColorLiteralGuard` 把它列在色相表里——那大概正是
当初选 `Color.primary` 的原因，但记下的理由是错的、结果也是错的。

判据：
- `CrossPlatformRenderTests.spheresFollowTheCallerTint`（空色板下换 `.tint` 位图必须变；
  给了色板则必须**不**变）；
- `CrossPlatformRenderTests.tintPathMatchesSinglePalette`（**承重**：空色板 + `.tint(X)`
  与 `colors: [X]` 必须渲成**同一张图**——谁再吃掉一层 alpha 就判红）。

## 与上游的有意分歧：插值走 `.perceptual`，不是 sRGB 分量 lerp

⚠️ **这条此前漏在"照录差异"清单之外**（PR #274 终审 I-3）。

上游 `SWDotSphere` 用 `UIColor(color).getRed(&r,&g,&b,&a)` 拆分量再线性插值，那等价于
**`.device`**；本仓改走 `Color.mix(with:by:in:)`，用的是 **`.perceptual`**（Oklab 系）。
实测 red→blue @ `t = 0.5`：

```
perceptual  r=0.6728 g=0.4743 b=0.6589
device      r=0.5000 g=0.3765 b=0.6176   ← 上游给的
```

中间调**肉眼可辨**：perceptual 保色度，device 会经过一段发闷的深紫。
本仓**有意选 perceptual**（换色是一次观感过渡，保色度更像"洗过去"一层色），
且色彩空间在 `SphereField.tone` 里**显式写出**——不吃 SwiftUI 的隐式默认，
否则 Apple 哪天改了默认值，本件的观感会静默换掉而没有任何东西变红。

⚠️ **半透明色板下两者性质不同**：`mix` 保留不透明色的 RGB、只 lerp alpha
（实测 `opaque × clear @ 0.5 → r=1.0, a=0.5`），而分量 lerp 会连 RGB 一起 lerp
⇒ 传 `.accent.opacity(0.3)` 这类色板的调用方，看到的中间调与上游**不同**。

判据：`SphereFieldTests.toneMixesInPerceptualSpace`。

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
| `rotationPeriod` 非法（`<= 0` / `NaN` / `±∞`） | **整件冻结**：呈现降到 `.resting`（相位钉在 `SphereField.restingPhase`、色波钉在 `restingWave`），且**不建 `TimelineView`** |
| 容器尺寸为 0 | 世界半径为 0，投影显式退化到 `depth = 1`，不放 NaN 进 `Canvas` |

⚠️ **`rotationPeriod <= 0` 这一条在 `0.4.x` 之前不是真的**（PR #274 终审 I-4）：
`SphereField.phase(period: 0)` 只让**自转**冻结，而 `SphereField.wave(at:)`
**不吃** `rotationPeriod` ⇒ 非空色板时色波仍每 10.5s 循环；更要紧的是呈现档仍是
`.animated` ⇒ `TimelineView(.animation)` 照常构建、display link 满帧跑，**只为产出
同一批帧**，白付 NFR-1 / NFR-7 的代价。而且 `restingPhase = 0.125` 的存在理由正是
"0 那一帧螺旋的接缝正对着观察者，看起来像没做任何事"，`<= 0` 恰好把调用方送到相位 0。
⇒ 现在由 `EffectsPresentation.frozenIfPeriodIsDegenerate(_:)` 这道**第三闸**统一降到
`.resting`，文档那句"退化为静止"才成立。

⚠️ **`NaN` 与 `±∞` 同样算非法**（PR #274 第 2 轮终审 I-C）：这道闸最初写作
`rotationPeriod <= 0`，而 `NaN <= 0` 与 `inf <= 0` **都是 `false`** ⇒ 两者当场绕过
（实测 `presentation=.animated` 而 `turns == 0`）。`+∞` 尤其不是臆造的输入——
调用方写 `rotationPeriod: .infinity` 表达"永不自转"是很自然的写法。
现在的判据是"**有限且为正**才算合法"。

判据：`SphereFieldTests` 的四条 + `CrossPlatformRenderTests.degenerateInputsDoNotCrash`
+ `DegeneratePeriodTests.degeneratePeriodFreezesAnimated`（纯函数真值表）
+ `CrossPlatformRenderTests.degeneratePeriodRendersTheRestingFrame`
（端到端：公开包装器渲出的**正是**那张钉死的静止帧）。

## a11y（FR-13）

点云是**纯装饰**，已 `accessibilityHidden(true)` / `allowsHitTesting(false)`。
它不承载任何语义——语义由它背后 / 上面的内容提供。

## ⚠️ 登记

⚠️ **`#270` 已收口，本节整段改写**（上句原写「不进 `components`，因为扫描根仍是单根」）：
`ComponentRegistryGuard` 的扫描根已扩成 `GuardScanRoots.allRoots`（三个 target），
`public struct DotSphere` 由 `PublicTypeCollector` 正常采到，**已按判定法登记进**
`docs/component-registry.json` 的 `components`：
`kind: prescriptive` / `decidedBy: tiebreaker` / `needsExtensionPoint: false`。
判定理由（步骤 2 先过「候选形态的作用域」条款：字形球面由已登记的兄弟条目 `CharSphere`
真实承担 ⇒ 该候选不计入；其余候选是同一球面换画法 ⇒ 装饰 ⇒ 不计入 ≥2 ⇒ 举得犹豫）
逐字写在该条目的 `notes` 里。
本件仍**没有** `public extension View` / `Transition` 成员 ⇒ `entryPoints` 零改动。
