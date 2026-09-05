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
    public nonisolated static var defaultRotationPeriod: Double { get }   // 10（秒 / 圈）
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
（PR #274 终审 C-2）：旧写法用 `Color.primary` 当遮罩色，而 `.primary` 在 **macOS** 上
实测 `a = 0.8471`（不是注释宣称的无条件"恒不透明"）⇒ `.tint` 那条路比显式色板那条路暗 15%。
⚠️ **平台限定，上一版没有**（#276 收尾时 iOS 腿实测）：iOS / UIKit 的 `label`
实测 α = 1.0 ⇒ 这枚偏差**只在 macOS 腿上可观测**。
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

本件画的同样是内容（`logo(item)` / `center`，两者都**有意不** `accessibilityHidden`）
⇒ 规则收窄为：**`.none` 摘掉的是装饰层与调度器，内容层静态留下**。

⚠️ **收窄之后，"画内容"不再是"排除在能耗闸之外"的理由**（PR #274 第 2 轮终审 I-E）：
本件自己就是反例——它画内容，却**在** `energyGatedFiles` 名单里。
`BeforeAfterSlider` / `ParticleTransition` 现在不进名单用的是另一条理由：
**它们没有可停的常驻装饰层**（两件全文件无 `TimelineView`、无常驻调度器），
进来只会白挨一道闸。现行规则逐字见 `energyGatedFiles` 类型文档开头的《当前规则》。
之前那句"需要规避的宿主 App 自行注入 `\.scenePhaseOverride = .active`"是在**记录症状**，
并把一个已判定为 bug 的默认行为的 opt-out 推给每个消费方 —— 已删。
装饰层（环）的完整记账仍见 `EffectsEnergyState.policy`。

⚠️ **低电量下 logo 必须跟着环挪**（终审 S-3）：低电量时每环只画 `round(23 × 0.5) = 12`
个点，座位数若还钉在标称的 23，logo 会悬在环点**之间**——本件"logo 坐在环上巡游"的
整个视觉立意就没了。`OrbitRing.logoAngle(logoIndex:logoCount:dotsPerRing:turns:)` 把
座位数收成参数，绘制层传的是**这一档真的画出来的**点数。

⚠️⚠️ **但座位数只吃能耗档位、不吃 `scenePhase`**（第 2 轮终审 I-D）。
`0.4.x` 的第一版把座位数写成"`.full` 档用真的画出来的点数，否则回落到标称的 23"
⇒ **低电量下窗口一失焦，调用方的 logo 会整体跳一下**：8 个 logo 的角度从
`0, 30, 90, 120, 180, 210, 270, 300`（座位 12）跳到 `0, 31.3, 78.3, …, 313.0`（座位 23），
最大差 **11.7°**，320pt 容器上约 **28pt**。而 `.inactive` 正是 C-1 要保护的
"**窗口完全可见**"那一档——环消失是本意，logo 挪窝不是。条目数落在 13…23 之间时更糟：
两档分别走"超座位均分"与"吸附环点"**两套排布**。
⇒ 座位数改由「**若此刻在活跃档会画出几个点**」决定（`OrbitRing.seats(particleScale:)`），
与 `scenePhase` 解耦；停摆档因此与它前一刻的排布**逐点一致**。

判据：`CrossPlatformRenderTests.pausedKeepsCallerContentInOrbitingLogos`（内容还在）
+ `orbitPresentationBranchesAreWiredCorrectly`（装饰层不建）
+ `accessibilityHiddenStaysOnTheDecorationLayer`（a11y 隐藏不许上移到整件）
+ `logoSeatsFollowTheThinnedRing`（把环画成 `.clear`，位图上只剩 logo，低电量下必须挪位）
+ `seatCountFollowsPowerModeNotScenePhase`（座位数与 `scenePhase` 解耦）
+ `OrbitRingTests.logoAnglesSitOnRealSeatsAndNeverCollide`。

## 退化输入

| 输入 | 行为 |
|---|---|
| `items` 为空 | 只画点环与中心视图，不崩 |
| 条目数 `<=` 外环座位数 | 每个 logo 一个专属环点，**两两不同** |
| 条目数 `>` 外环座位数（默认 23） | **改按角度均分**，不再吸附到环点——但仍然两两不重叠 |
| `rotationPeriod` 非法（`<= 0` / `NaN` / `±∞`） | **整件冻结**：呈现降到 `.resting`，自转与轮播一并停，且**不建 `TimelineView`** |
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

⚠️ **`NaN` 与 `±∞` 同样算非法**（第 2 轮终审 I-C）：这道闸最初写作 `rotationPeriod <= 0`，
而 `NaN <= 0` 与 `inf <= 0` **都是 `false`** ⇒ 两者当场绕过（实测 `presentation=.animated`
而 `turns == 0`：display link 满帧跑，自转相位恒为 0）。`+∞` 尤其不是臆造的输入——
调用方写 `rotationPeriod: .infinity` 表达"永不自转"是很自然的写法。
现在的判据是"**有限且为正**才算合法"。

⚠️ **已登记的形状缺陷**（第 2 轮终审 S-b）：`rotationPeriod` 这一个旋钮同时管住了
"停自转"与"停轮播"，调用方想要"环不转但 logo 照常轮播"**已无表达方式**，
而这个名字读不出"整件冻结"——一个旋钮被重载成了开关，与本仓 J-1 的口味相左。
⇒ **如需分离，另开档位**（一个描述"这件动到什么程度"的枚举），别再往 `rotationPeriod`
上叠语义。

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

⚠️ **`#270` 已收口，本节整段改写**（上句原写「不进 `components`（扫描根仍是单根）」）：
扫描根已扩成三个 target，`public struct OrbitingLogos` **已登记进**
`docs/component-registry.json` 的 `components`：
`kind: prescriptive` / `decidedBy: pendingStep2` / `needsExtensionPoint: false`。
⚠️ **`decidedBy` 不是 `tiebreaker`**（PR #297 终审 I-1，本节已改写）：`#270` 初版填的是
`tiebreaker`，而公约步骤 3 门槛的兜底句**以「重跑发生过」为前置**、步骤 2 的停止规则又写着
「枚举视为未完成 ⇒ **不得据以走任一出口**」——本条的候选枚举与来源核验**一次都没做**。
⇒ 改记 `pendingStep2`：**如实说「还没判」**，条目缓办在**可逆的那一侧**
（规定性 / 不给扩展点），落点留给承接 issue **`#299`**。
⚠️ 公约明令**不得预判**重判结论 —— 补足枚举后可能落**任一**出口，含 `semantic`（要开扩展点）。
⚠️ **本条的候选分箱也一并改了**（PR #297 终审 I-3）：`notes` 原把「换轨道形状」判成
「同一槽内的画法变化 ⇒ **装饰**」，而公约的**排布**定义是「**子视图之间的空间关系改变**」——
把 logo 从圆轨道改成椭圆 / 螺旋，改变的正是它们**彼此之间**的落点 ⇒ 命中排布、本该计入 ≥2。
「换环数」另擦到补充规则 2（槽的计数变化也算槽差异）。⇒ 本条与四个图表 /
`BeforeAfterSlider` 同组，不是「干净的 tiebreaker」。缺陷留痕见 `docs/contract-defects.md` `D-270-2`。
⚠️ 上面那条已登记的形状缺陷（`rotationPeriod` 一个旋钮管两件事）**不受此影响**：
它的处置是另开一个「动到什么程度」的**行为**档位枚举，不是样式扩展点。
本件仍没有扩展成员 ⇒ `entryPoints` 零改动。

### ⚠️ `#299` 重判：`pendingStep2` → `tiebreaker`（步骤 4；本节只增不改，上文保留为成因记录）

⚠️ **上一段是 `#270` / PR #297 当时的记录，不改写。现状**：`#299` 已按公约补做步骤 2 的
候选枚举与来源核验并重判，本条登记表字段现为
`kind: prescriptive` / `decidedBy: tiebreaker` / `needsExtensionPoint: false`
——`kind` 与扩展点与缓办期**一致**，本轮**没有**新增任何 public API。

本轮具名候选 4 个，逐条给来源或**如实标注查不到**（完整逐字理由与 URL 见
`docs/component-registry.json` 本条的 `notes`）：

1. **多轨道分布（logo 分居不同半径的多条轨道）** —— 组件库 Magic UI 的 `OrbitingCircles`：
   props 表有 `radius`，且示例把**两个**实例以不同 `radius`（默认 160 / 显式 100）**并列**
   成同心多轨。现状本件把**全部** logo 均匀放在**最外一条**环上 ⇒ 候选改变的是 logo
   **彼此之间**的落点 ⇒ **排布** ⇒ **计入**。
   ⚠️ **`#315` 终审 S-5 更正**：示例里那两个实例是同一个 `<div>` 下的**兄弟**元素，不是
   上一版写的「嵌套」；props 表除 `radius` 外还有 `iconSize`（图标本身的尺寸，不是轨道几何），
   故「只有 `radius` 一个几何量」这句也不精确 —— 精确说法是「控制**轨道形状**的只有 `radius`」。
2. **线性无限滚动带（logo marquee）** —— Magic UI 的 `Marquee`。⚠️ **不计入**：
   Magic UI 把两者作为**两个各自独立发布的组件**，不是同一组件的两种外观；步骤 2 问的是
   「同一含义的另一个**版本**」，「换用另一个组件」不是本组件的一个版本。
3. **静态 logo 网格（logo cloud）** —— 设计体系 Tailwind Plus 的 Logo Clouds 区块（含
   “Grid” 等六种例子）。⚠️ **不计入**：同上，且它**完全没有运动**，而本件在
   `CoreDesignEffects`（表达性视觉动效层），巡游本身就是它的含义。
4. **椭圆 / 螺旋轨道** —— ⚠️⚠️ **`#315` 终审 S-3 要求给负面核验补记 URL + 状态码 + 日期；
   补记时逐条重跑，发现上一版的负面声称之一已经过期。** 这正是 PR #297 终审 I-3 把本条挪进
   缓办台账所依据的候选。逐条复核（全部 2026-09-05 重跑）：
   · **Magic UI `OrbitingCircles`**（<https://magicui.design/docs/components/orbiting-circles>，
     HTTP 200）—— 控制轨道形状的只有 `radius`，`path` 只控制轨道线**显不显示** ⇒
     该组件确实没有任何非圆形路径取值，这条结论仍成立。
   · **Framer Marketplace 的 OrbitMotion**（<https://www.framer.com/marketplace/components/orbit-motion/>）
     —— HTTP **200**，但正文只回 111 字符的导航壳 ⇒ 仍未读到实际措辞，按纪律不得引用。
   · ⚠️⚠️ **Animata “Orbiting Items 3D”**（<https://animata.design/docs/list/orbiting-items-3-d>）
     —— 本轮实测 **HTTP 200、取得到完整正文**，上一版记的 HTTP 403 **已经过期**。页面逐字：
     组件自述 “List component with orbiting items. The items orbit around the center of an
     element in 3D Ellipse.”；props 含 `radiusX`（“The radius of the ellipse on X-axis in
     percentage, relative to the container.”）、`radiusY`、`tiltAngle`（“The angle at which
     ellipse is tilted to x-axis.”）。⇒ 这是一份**可核验的来源**，且它是「**同一个组件**、
     两个 props 决定轨道是圆还是椭圆」（`radiusX == radiusY` 即圆）⇒ 同时过得了来源义务与
     `D-299-2` 那把「须是本组件的另一种长相」的尺子。
   ⇒ ⚠️⚠️ **按公约字面，本条的计入数应为 2（候选 1 + 候选 4）≥ 2 ⇒ 落出口 1**，而不是本条
   现在落盘的步骤 4。**本轮不据此翻转落点**（可逆一侧），复核结论登记在
   `docs/contract-defects.md` 的 `## #299` 节《`#315` 终审后复核》段，翻转移交 `#312`。
   ⇒ 附带结论：**I-3 的三分法归类本身没错**（椭圆 / 螺旋改的确实是彼此之间的落点 ⇒ 排布）；
   上一版说它「卡点在来源不在分箱」在**当时**的取页结果下成立，**在本轮的取页结果下不再成立**。
   ⚠️ **`#315` 终审 S-4**：上一版这里还有一句「四家基线设计体系检索后均无『环绕轨道 logo』」——
   那是**不可证伪的全称否定**且没有留下检索 URL，而本条走的是「≥3 具名候选」这一支、根本不需要
   基线名单 ⇒ **本轮删掉，不补**。

**「换环数」另核，同样是对 I-3 的实核否证**：本件的四圈同心点环是**纯装饰层**。
⚠️ **`#315` 终审 I-3 换掉了这里的论据（结论不变）**：上一版拿「低电量档下每环点数直接减半」
当依据，而那句说的**是另一个量** —— 减半的是 `dotsPerRing`（每环**点数**，23 → 12；
`OrbitingLogos.swift:268-271` × `EffectsEnergy.swift:203-210` 的 `particleScale == 0.5`），
而**环数** `OrbitRing.ringCount` 是 `static let ringCount: Int = 4`（`OrbitRing.swift:44`）、
**恒定、根本不吃电量**。⇒ 改用真正管用的依据：按补充规则 1「判『装饰』时须写明依据，源码或
a11y 的自陈不足以定性」，此处**不援引**它的 `accessibilityHidden(true)` 自陈，而看它承不承载
语义 —— **点环不映射任何调用方数据**（`items` 只喂 logo，环点位置由 `OrbitRing` 的常量几何
算出），取色只按环上角度在 `.tint` 上做明暗波 ⇒ 不表达任何内容语义 ⇒ **装饰**。补充规则 2
的对象是**槽**（「承载内容的子视图位置」），装饰层的计数变化不适用 ⇒ **不计入**。
⚠️ **反向事实一并写出（诚实枚举义务）**：`OrbitingLogos.swift:275-293` 明写「logo 必须坐在
这一档真的画出来的环点上」，`seatCount` 由 `particleScale` 经 `OrbitRing.seats(particleScale:)`
推出 ⇒ **点环的点数直接决定调用方 logo 的落点**（低电量下座位 23 → 12）。它**不推翻**「装饰」
这个结论 —— layout 依赖 ≠ 承载语义，环点仍不表达任何调用方数据 —— 但读者有权看到这一条。

⇒ **落盘时（`#315` 终审复核之前的取页结果）：过得了来源义务、且确实是「本组件的另一种长相」
的非皮肤候选数 = 1 < 2** ⇒ 命中步骤 2 的出口 3「举得犹豫 ⇒ 视为答不上来」⇒ **落步骤 4**：
`decidedBy: tiebreaker`。⚠️⚠️ **这个计数在 `#315` 终审后的复核里已经站不住**（候选 4 的来源
本轮取得到正文 ⇒ 应为 2 ≥ 2 ⇒ 出口 1）；落盘字段本轮**仍按步骤 4 不动**，翻转移交 `#312`。
**两可的理由**：轨道的**条数**业界真实可变（Magic UI 有实证），但轨道的**形状**举不出
可核验来源，而「去掉运动改成网格 / 跑马灯」在业界是**另一个组件**而非本组件的版本
—— 一侧只有一个硬候选、另一侧全部落空，够不到 ≥2 又不是干净的「举不出」。

⚠️⚠️ **一处判定口径的留痕，已登记 `D-299-2` —— 它不是旁注，是本条落点的决定性依据**
（`#315` 终审 C-1 更正了上一版「两条新缺陷都没有被用来改落点」那句全称否认）：
「候选须是**本组件的另一种长相**、而不是业界的另一个组件」这条读法是对步骤 2 问句里
「同一含义的另一个**版本**」的操作化，公约正文**没有成文写**它（成文的只有作用域条款，
而那条只认**本登记表内**的兄弟组件）。
**剔除这条读法，候选 2（`Marquee`）与候选 3（Logo Clouds）按三分法都是排布
（环形↔线性 / 环形↔网格）⇒ 计入数 1 → 3 ≥ 2 ⇒ 出口 1 ⇒ `semantic` + `needsExtensionPoint`**
—— 本条的整条落点都挂在它上面，不是边角。
⚠️ **而且公约字面并不支持那条读法**：步骤 2 的「…的**版本**吗」是**问句**，紧接其后的才是
**操作化门槛**（「能当场举出 **≥2 个业界真实存在的替代形态**」），而「替代形态」不等于
「同一组件的版本」；作用域条款只排除**本登记表内**的兄弟，`Marquee` 与 Logo Clouds 都不在。
⇒ 上一版说的「按字面走」其实是**在问句与操作化门槛之间做了一次口径选择**，不是无选择地照抄
字面 —— 这一点如实标注。
**本轮的处置**：不改落点，如实标注这是一次口径选择，并把**两条**翻转路径都写进承接 issue
`#312` —— ① `D-299-2` 的读法若被推翻（计入 3 ⇒ 出口 1）；② 候选 4 的来源已可核验
（计入 2 ⇒ 出口 1）。理由是可逆性：现状 `prescriptive` / 不给扩展点是**可撤**的一侧，
翻到出口 1 最终要发布 public 扩展点则**撤不回来**，而这两条翻转路径都还没过评审。
