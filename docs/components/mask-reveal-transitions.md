# Mask reveal 转场簇

`iris` / `wipe` / `blinds` / `clock` / `glare` / `dissolve` 六种「揭示型」转场 /
Six mask-reveal transitions.

`.transition(.iris)`（`CoreDesignEffects/MaskReveal.swift` +
`CoreDesignEffects/MaskRevealTransitions.swift`，Issue #268）。
⚠️ **`Transition` 形态**——不是容器视图，也不是 `View` 上的 modifier。

```swift
import CoreDesign
import CoreDesignEffects
```

⚠️ **两个 import 一个都不能少**：全仓 `@_exported` 为 0。

## API

```swift
public struct MaskRevealTransition: Transition {
    public static let defaultBlindCount: Int    // 8
    public static let defaultCellSize: CGFloat  // 24
    public static let defaultWipeAngle: Angle   // 0°
    public static let defaultGlareAngle: Angle  // 35°
    public func body(content: Content, phase: TransitionPhase) -> some View
}

public extension Transition where Self == MaskRevealTransition {
    static var iris: MaskRevealTransition { get }
    static func iris(anchor: UnitPoint = .center) -> MaskRevealTransition

    static var wipe: MaskRevealTransition { get }
    static func wipe(angle: Angle = MaskRevealTransition.defaultWipeAngle) -> MaskRevealTransition

    static var blinds: MaskRevealTransition { get }
    static func blinds(count: Int = MaskRevealTransition.defaultBlindCount) -> MaskRevealTransition

    static var clock: MaskRevealTransition { get }
    static func clock(direction: SpinDirection = .clockwise) -> MaskRevealTransition

    static var glare: MaskRevealTransition { get }
    static func glare(angle: Angle = MaskRevealTransition.defaultGlareAngle) -> MaskRevealTransition

    static var dissolve: MaskRevealTransition { get }
    static func dissolve(cellSize: CGFloat = MaskRevealTransition.defaultCellSize) -> MaskRevealTransition
}
```

⚠️ **没有 public init**：调用方只经由这十二个静态成员拿实例。`init` 一旦公开，
几何族枚举 `MaskRevealKind` 也得跟着公开，而它是纯实现细节（随几何实现变，
不该冻进 API）。本仓「public 类型必须有 public init」的惯例针对的是**组件**
（调用方要构造它），转场不属于那一类。

⚠️ **六种共用一个类型**。计数单位是「**一种 transition**」而不是「一个静态成员」
（`#251`）：登记表按 `Host.member` 去重 ⇒ `docs/component-registry.json` 的
`entryPoints` 里是 **6 条**（`Transition.iris` … `Transition.dissolve`），
含参重载与无参形式合并算一条。

## 六种各是什么

| 名字 | 几何 | 参数 |
|---|---|---|
| `.iris` | 圆形光圈从 anchor 向外张开，半径自动取到最远角 | `anchor: UnitPoint`（默认 `.center`） |
| `.wipe` | 一条直边沿指定方向扫过 | `angle: Angle`（默认 `0°` 左→右；`90°` 上→下，SwiftUI 的 y 轴向下） |
| `.blinds` | 若干条横向百叶各自从自己的中线向上下张开 | `count: Int`（默认 8；`0` / 负数钳到 1） |
| `.clock` | 扇形扫针从 12 点方向扫一圈 | `direction: SpinDirection`（默认 `.clockwise`） |
| `.glare` | 斜掠的直边扫过，揭示边上骑一条柔光带 | `angle: Angle`（默认 `35°`） |
| `.dissolve` | 网格逐格按确定性伪随机次序浮现 | `cellSize: CGFloat`（默认 24pt） |

⚠️ **`.glare` 与 `.wipe` 共用同一条半平面数学**，差别是**默认角度**与**柔光带**
（`Color.specularHighlight`，第 3 层 token）。两者是调用方眼里两个名字、
登记表里两条条目；若把两者的默认角度改成一样，默认参数下就分不出它们了
——`MaskRevealGeometryTests.entryPointsMapToTheirOwnKind` 有一条互锁钉着这件事。

```swift
if showsBadge {
    Badge("PRO")
        .transition(.iris)
}

// 含参形态
content.transition(.wipe(angle: .degrees(90)))
content.transition(.blinds(count: 5))
content.transition(.clock(direction: .counterClockwise))
content.transition(.dissolve(cellSize: 12))
```

## ⚠️ 为什么是「裁剪」而不是「遮罩」

上游这一族是 **alpha 遮罩**（拿一个不透明色填出形状、`.mask { … }`）。本仓
**不能照抄**，两条各自独立的硬理由：

1. **本仓没有"保证 α = 1"的可用颜色。**
   - `Color.primary` / `Color.contentPrimary` 映射到系统 `label`，macOS 浅色外观下
     实测 **α ≈ 0.8471**（issue #276）。拿它当遮罩，"完全揭示"那一端只揭示到 85%，
     而且**不会报错**——转场看起来能用，只是内容永远偏淡一档。
     ⚠️ **平台限定**（#276 收尾时 iOS 腿实测）：**iOS / UIKit 的 `label` 明暗两端
     实测 α = 1.0** ⇒「只揭示到 85%」只在 macOS 腿上成立。结论不变：一个平台相关、
     未文档化的 α 不能当"保证 α = 1 的颜色"用。
   - `Color.black` / `Color.white` / `Color(white: 1)` 会被 `EffectsColorLiteralGuard`
     判红，而该守卫至今没有例外台账。
   - `ColorGrade` 资源色在 macOS `swift test` 下全部解析为透明（issue #275）。

   ⚠️⚠️ **上一版这里把本条写成"三条路全堵死"，那是错的，照录更正**（终审 S-1）：
   `EffectsColorLiteralGuard` 的扫描根**有意不含** `Sources/CoreDesign`
   （它扫的是 `GuardScanRoots.newTargetRoots`，只有 Effects / Charts）⇒ 在
   `Sources/CoreDesign/Colors/` 加一个第 3 层不透明 token 再从 Effects 引用
   **不会命中该守卫**。本仓已有现成先例：`glare` 用的 `Color.specularHighlight`
   就是 `Sources/CoreDesign/Colors/FillColors.swift` 里的 `Color.white.opacity(0.45)`,
   `CLAUDE.md` 也明写「缺少需要的语义 token，应在对应文件中补充新名称」；#275
   对这类字面量派生 token 同样不适用（它说的是资源色）。
   ⇒ **正确的记账是：遮罩路线可行，只是代价更高**（要新开一个第 3 层 token，
   且"α 恒为 1"这件事本身还得有判据守着）；**选裁剪的真正理由是下面第 2 条。**

   ⚠️⚠️ **那个"更高的代价"现在已经付过了，本条第一句因此要重读**（#276）：
   `Color.maskOpaque`（`Sources/CoreDesign/Colors/MaskColors.swift`）已经存在，
   契约就是 α = 1，由 `MaskOpaqueTokenTests` 在明暗两端守着。⇒ 本仓**现在有**一个
   "保证 α = 1"的可用颜色，上面那句「本仓没有」只对 #276 之前的树成立。
   本簇**仍然选裁剪**，但理由只剩下面第 2 条与"硬边是可接受代价"，
   不再包括"没有可用的不透明色"。

2. **裁剪的判据可以是纯函数。** `Path.contains(_:)` 让"这一点此刻揭示了没有"成为
   一个不经过渲染栈、两端平台一致、可穷举采样的布尔值。

**代价照录**：裁剪的边缘是硬的，做不出上游那种羽化过渡。`glare` 的柔光带因此是一层
**叠加**而不是遮罩的一部分——它的半透明是有意的装饰，不承载"揭示了多少"这个信息。

## ⚠️ 恒等相位是**真的**恒等

自定义 `Transition` 的修饰器在被修饰视图的**整个生命周期**里都生效（转场停住之后
相位是 `.identity`，修饰器并不会被摘掉）。一个"裁到自身 bounds"的 `clipShape` 会
**永久**吃掉阴影 / 溢出子视图，而且是在转场结束**之后**才吃掉——最难归因的那一类。

⇒ 解法分两段：

- **最后 15%**（揭示进度越过 `haloOnset` = 0.85）：裁剪路径外并上一圈向外张开的外框，
  张开量按内容对角线走，只增不减；
- **恒等相位本身**（`progress == 1`，以及 Reduce Motion 的遮罩全开）：直接短路到
  `MaskReveal.openPath(in:)`，余量是与内容尺寸**无关**的 `openReach`（一百万 pt）。

⚠️⚠️ **第二段是终审 I-2 补的，上一版这里写的是绝对句、而它是假的**：上一版恒等相位
也按内容对角线派生余量 ⇒ 「裁剪对任何溢出内容都不再有作用」**只在一条对角线以内成立**。
实测（4×4 的内容，恒等相位）：`contains(-4pt above) = true`、
`contains(-30pt above) = false` ⇒ 一个 20×20 的图标配 `.shadow(radius: 30)`，
阴影在**转场结束之后**仍被永久吃掉——正是这段设计要消灭的那类缺陷，
只是把阈值从 0 抬到了一条对角线。同一限度当时也落在 Reduce Motion 的 `openPath` 上。

⚠️ 现在这句话仍然是**有界**的（`openReach` 是个大常数，不是无穷），只是界与内容脱钩了。

⚠️ **代价照录**（#291 第 2 轮 Sug-2）：短路只发生在**端点**、不碰任何中间进度，
但这不等于"没有副作用"。`progress` 逼近 1 的那一段余量仍按内容对角线走
（`progress = 0.99` 时 ≈ 0.93 条对角线），到 `progress == 1` 一步跳到 `openReach`
⇒ **超过一条自身对角线的溢出内容是在最后一帧一次性「弹」出来的，而不是渐显**
（移除转场则在第一帧「弹」进去随即被裁）。这是选「端点短路、不碰插值」这条路线的
必然代价，比上一版「转场结束后永久吃掉」严格更好，因此**有意不改实现**；
写在这里是为了让收到「转场收尾闪一下」这类反馈的人省一次归因。
三条判据钉住它：
`MaskRevealGeometryTests.identityClipsNothingRegardlessOfContentSize`（对 160×120 /
60×24 / 4×4 三种尺寸各采到 `openReach * 0.9`，恒等相位与 Reduce Motion 两条路都走）、
`MaskRevealRenderTests.identityIsBytewiseIdentityEvenWithOverflow`、
以及 `…ForTinyContentWithHugeOverflow`（4×4 内容 + 73pt 溢出，上一版在它上面判红）。

⚠️ 初版用的是"整条路径按中心整体放大"，实测**对非中心对称的几何族不单调**：
`blinds` 的每条百叶、`dissolve` 的每个格子都有自己的中心，整体放大把它们推离
bounds 中心，已经揭示的采样点会掉进缝里 ⇒ 最后 15% 一次闪烁。现行写法只增不减。

## 动画为什么是连续的

`TransitionPhase` 是 **3 case frozen enum** ⇒ 相位 → 进度的映射可达取值只有
`{0, 1}`。中间进度**全部**来自 SwiftUI 对 `MaskRevealChrome.animatableData` 的插值
——`MaskRevealChrome` 因此必须 `Animatable`。若它只是普通 `ViewModifier`，用户看到的
是"整块内容凭空出现"，而三个真实相位上的位图断言**照样全绿**（这枚缺陷在
`ParticleTransition` 上真实发生过一次）。

⚠️ **不用 `TimelineView` / `keyframeAnimator`**：`Transition` 拿不到任何时间源，
它只被喂三个离散相位，既不知道调用方的 `withAnimation` 用了多长、什么曲线。
自建时间线会与 SwiftUI 自己的转场时钟成两套时序。

## Reduce Motion

**遮罩全开、内容不透明度跟着进度走**——退化成一次纯淡入淡出（`#251` 给整簇定的
「位移 / 旋转类降级为淡入淡出」）。⚠️ **不是 no-op**：转场承载的是"这块内容出现 /
消失了"这个信息，抹掉它会让开启该偏好的用户看到界面瞬间跳变。

⚠️⚠️ **上一版这里写「裁决点是 `MaskReveal.plan(…)` 这一个纯函数」——那句话在运行时
是假的，照录更正**（终审 I-5）。实际上有**两道闸，框架那道在前**：

| 闸 | 谁 | 何时生效 |
|---|---|---|
| **第一道（真正生效的那道）** | SwiftUI，看 `MaskRevealTransition.properties.hasMotion` | 本簇显式声明 `hasMotion == true`；Apple 文档逐字「*that transition will be replaced by opacity when Reduce Motion is enabled*」⇒ RM 打开时框架**直接把整条转场换成 `.opacity`**，`MaskRevealTransition.body` 根本不被调用 |
| 第二道（兜底） | `MaskReveal.plan(kind:progress:isReduced:)`（刻意 `internal`：一旦 `public`，裸 `Bool` 参数会命中 `BoolExemptionGuard`） | 只在框架**没有**替换时才轮得到 |

⇒ 经 `.transition(.iris)` 这条正常路径，`plan` **永远看不到 `isReduced == true`**。
两道闸的结论是**同一个观感**（纯淡入淡出），因此用户看到的东西与本节开头描述的一致。

内层那条路径**显式裁定为保留**（防御 `hasMotion` 将来被改判、`AnyTransition` 包装、
以及别的平台 / 版本上替换时机不同），完整理由写在 `MaskRevealTransition` 的类型文档里。
`MaskRevealSourceGuard.reduceMotionIsOnlyConsumedByThePlan` 钉的是**内层这道闸**
不被绕过；`MaskRevealTransitionBodyTests.transitionDeclaresItHasMotion` 钉住
`properties` 是显式声明（`true` 与 SDK 默认值相同，不显式写出来下一个人就看不见框架闸）。

## 退化输入

| 输入 | 行为 |
|---|---|
| `blinds(count: 0)` / 负数 | 钳到 1（否则是一条不报错的死转场） |
| `dissolve(cellSize: 0)` / 负数 / `.nan` / `.infinity` | 回落到默认 24pt |
| `dissolve(cellSize:)` 过小 | 自动放大到让格数落在 `dissolveMaximumCells`（2000）以内 |
| 零尺寸 bounds | 路径为空，不崩 |
| 进度越界（弹性曲线插出 `<0` / `>1`） | 钳进 `0...1` |

## a11y

裁剪**不改变** accessibility tree——被裁掉的内容仍在树上（这与 `.opacity(0)` 相同，
是 SwiftUI 的既有语义，本簇不另作处理）；"这块内容出现了"由调用方通告。
`.glare` 的柔光带是纯装饰，已 `accessibilityHidden(true)` / `allowsHitTesting(false)`。

## 已知代价

- **每一个用过这簇转场的视图会长期多背一个 `clipShape`**：修饰器在恒等相位并不会被
  摘掉。`dissolve` 尤其——它的路径在恒等相位是几十个矩形子路径（默认 24pt 格、
  160×120 内容约 35 格）。这是让 SwiftUI 有东西可插值的必要代价：门控里一旦掺进相位，
  恒等那一端会把整层摘掉，进场的收尾与出场的起手都被截断。
- **`Path.contains(_:)` 在顶点上退化**：`clock` 的扇形顶点在内容中心，水平射线正穿过
  它时 `contains` 的答案不稳定。这是**采样判据的限度、不是 `clock` 的缺陷**（渲染出来
  的像素没有这个问题）；判据的采样网格因此取偶数边长，格心永远不落在中线上。
