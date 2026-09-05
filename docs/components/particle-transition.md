# ParticleTransition

粒子消散 / 汇聚转场 / A particle dispersal transition.

`.transition(.particle)`（`CoreDesignEffects/ParticleTransition.swift`，Issue #253）。
⚠️ **`Transition` 形态**——不是容器视图，也不是 `View` 上的 modifier。

```swift
import CoreDesign
import CoreDesignEffects
```

⚠️ **两个 import 一个都不能少**：全仓 `@_exported` 为 0。

## API

```swift
public struct ParticleTransition: Transition {
    public let count: Int
    public let colors: [Color]
    public static let defaultCount: Int          // 18
    public init(count: Int = ParticleTransition.defaultCount, colors: [Color] = [])
    public func body(content: Content, phase: TransitionPhase) -> some View
}

public extension Transition where Self == ParticleTransition {
    static var particle: ParticleTransition { get }
    static func particle(count: Int = ParticleTransition.defaultCount,
                         colors: [Color] = []) -> ParticleTransition
}
```

## ⚠️ 形态判定与登记

四个 API 单位（`TypewriterText` / `AnimatedMeshGradient` / `BeforeAfterSlider` /
`ParticleTransition`）里只有这一个以 `Transition` 结尾。本仓（与 #251 的 16 个转场）
对这一形态的约定是：**`Transition` 协议实现 + `extension Transition where Self == …`
的静态成员**，支持 `.transition(.particle)` 点语法。

⇒ 静态成员 `Transition.particle` 是一个**公开入口点**：它不是类型，
`ComponentRegistryGuard` 的组件条目结构上覆盖不到它
⇒ 已登记进 `docs/component-registry.json` 的 `entryPoints`
（`target` = `CoreDesignEffects`、`host` = `Transition`、`member` = `particle` + `notes`），
由 `ExtensionEntryPointGuard` 做双向差集（漏登记与幽灵条目两个方向都判红）。
⚠️ 无参 `static var particle` 与含参 `static func particle(count:colors:)` 按
`Host.member` 去重，**算同一条**（口径同 #251：计数单位是「一种 transition」）。

⚠️ `public struct ParticleTransition` 本身**不**进 `components` 数组，但 `#270` 起**理由变了**：
`ComponentRegistryGuard` 的扫描根已由单根 `Sources/CoreDesign` 扩成
`GuardScanRoots.allRoots`（三个 target），**扫描根不再是理由**；
真正的理由是 `PublicTypeCollector` 只采 `public struct: View / ViewModifier`，
而它是 `public struct: Transition` ⇒ 结构上仍不进 `components`。
公开表面由上面那条 `entryPoints` 覆盖，不是漏登记。

## 取色（FR-8）

粒子取色池默认**为空 ⇒ 全部取调用方的 `.tint`**，与 `.spray` / `.confetti` 共用同一个
取色函数（`[Color].particleStyle(at:)`）。**不给彩虹默认色板**——那是品牌决定。

判据：`ParticleTransitionTests.particlesFollowCallerTint`（空色板下换 `.tint` 位图必须变；
给了色板则必须**不**变）。

## 相位契约

`TransitionPhase` 是 **3 case frozen enum** ⇒ `body(content:phase:)` 只可能拿到这三个值，
`ParticleBurst.progress` 的**可达取值只有 `{0, 1}`**：

| 相位 | 进度 | 内容不透明度 | 内容缩放 | 粒子 |
|---|---|---|---|---|
| `.willAppear`（`value == -1`） | 1 | 0 | 0.88 | **一颗都不画**（见下） |
| `.identity`（`value == 0`） | **0** | 1 | **1** | **一颗都不画** |
| `.didDisappear`（`value == 1`） | 1 | 0 | 1.12 | **一颗都不画**（见下） |

⚠️ **粒子只出现在两个端点之间的插值上**，三个真实相位一颗都不画——这是**正确形态**，
不是缺陷：`progress == 0` 是转场停住后长期停留的那一帧（画一颗都是永久残留）；
`progress == 1` 是"完全进入前 / 完全离开后"，内容不透明度也恰为 0
（`lifetime` 上界 `0.9975 < 1` ⇒ 粒子 alpha 在这一端同样恒为 0），
那一端留着可见粒子就是一次 pop。

⚠️ **上一版这张表在两个端点写的是「满」，而那是假的**（#253 PR #273 终审 C-A）：
当时的 `ParticleBurstLayer` 是普通 `View`——不 conform `Animatable`、无 `TimelineView`
⇒ **中间进度根本到不了**（SwiftUI 只插值可动画属性，不插值 `Canvas` 的绘制内容），
而两个端点的 alpha 恒为 0 ⇒ **粒子层是死代码**：三个相位下直接渲
`ParticleTransitionChrome`，与「无粒子层版本」**逐字节相同**。用户实际只看到内容自身的
`scaleEffect` + `opacity`，「一圈粒子飞散」从未发生过。

## 粒子靠什么动起来：`Animatable`

`ParticleBurstLayer` 现在 conform `Animatable`，`animatableData` 就是 `progress`
⇒ SwiftUI 在一次动画事务里把它从端点 A 插到端点 B，并**逐帧重求 `body`**，
`Canvas` 每帧拿到一个新的中间进度。

⚠️ **不用 `TimelineView`（`Confetti` 的成法）**：`Confetti` 有明确的 `burstStart: Date`
可以锚定一段自驱窗口，而 `Transition` **拿不到任何时间源**——它只被喂三个离散相位，
既不知道调用方的 `withAnimation` 用了多长、什么曲线，也没有"何时开始"这个事实。
自建时间线会与 SwiftUI 自己的转场时钟**两套时序**，且恒等相位会留一个常驻 display link。
`.keyframeAnimator` 同理（也要自己声明时长）。`animatableData` 是唯一"跟着 SwiftUI 时钟走"的选项。

⚠️ **代价照录**：overlay 的门控因此只能是 `self.count > 0`，**不能**再带 `progress > 0`
——插值的前提是那个视图整段动画都在树上；带上 `progress` 会在恒等那一端把整层摘掉
（进场的收尾、出场的起手都被截断），且 `if` 翻转会给子树套上默认 `.opacity` 转场。
⇒ 恒等相位现在仍会留一个 `Canvas`，它每次绘制空跑 `count` 次循环、逐颗 `alpha == 0` 早退。

### 判据

- `ParticleTransitionTests.chromeDrawsParticlesMidFlight`（**承重**）——把 SwiftUI 的
  插值步骤原样跑一遍（取两端 `animatableData`、`interpolate(towards:amount:)`、写回），
  结果必须画得出粒子，且必须与直接用中间进度构造的层**逐字节相同**。
  走存在类型 `any View & Animatable` ⇒ 撤掉 `Animatable` 一致性是**运行时判红**。
- `ParticleTransitionTests.particleLayerSurvivesTheWholeTransition`——源码钉住
  overlay 门控恰为 `self.count > 0`，且 `body(content:)` 里不出现 `progress > 0`。
- `ParticleTransitionTests.chromeAtRealPhasesDrawsNothing`——三个真实相位下 chrome
  与「粒子数为 0」版逐字节相同（把 `identityFrameDrawsNothing` 从绘制层抬到 chrome 本体；
  上一版那条从不经过 chrome，对 `if drawsParticles` 分支**零可见性**）。
- `ParticleTransitionTests.identityFrameDrawsNothing`——绘制层那一层，带"中途必须画得出"的互锁。

⚠️⚠️ **仍未被机器守住的一格**：「SwiftUI 的转场机制**确实**会拾取这个 `animatableData`
并逐帧重求 `body`」是一个**运行期动画事实**，`ImageRenderer` 拍静态帧、结构上观测不到。
判据钉到的是「插值这一步的输入输出正确」+「视图整段在树上」，两者合起来是修复的必要条件，
**不是充分条件**。真正的确认只能靠 `App/` 预览宿主肉眼看。⇒ 登记为已知限度。

粒子位置全部由 `index` 派生的**确定性伪随机**给出，不用 `random`——否则每次重绘粒子都会跳，
且测试无法复现（`Spray` / `Confetti` 已就同一件事立过规矩）。

## Reduce Motion

**不放粒子、不缩放，只留内容自身的淡入淡出**（与 #251 给整个转场簇定的
「位移 / 旋转类降级为淡入淡出」一致）。⚠️ **不是 no-op**：转场承载的是"这块内容出现 /
消失了"这个信息，抹掉它会让开启该偏好的用户看到界面瞬间跳变。
走**降级形态 2**（保留呈现、去掉运动、不叠透明度脉冲）。

实现走**早退**（`guard !isReduced`，与 `.ping` / `.spray` / `.shine` 同形态），
文件同时登记在 `MicroInteractionReduceMotionGuard` 的 `approvedEarlyExit` 与
`approvedFormTwo` 两份名单上（双向差集守着，新领一张豁免必须改那两份名单）。

⚠️ **Reduce Motion 必须从环境里读，而 `Transition.body(content:phase:)` 拿不到
`@Environment`**（它不是 `View`）⇒ 实际绘制走一个**非泛型**的 `ViewModifier`
（`ParticleTransitionChrome`），与 `TriggerRelay` 同一条纪律：泛型进动画路径会带出
`capture of non-Sendable type 'T.Type'` 一族问题。

## 后台 / 低电量（NFR-7）

⚠️ **本转场不接能耗闸**：NFR-7 管的是常驻渲染件，而转场由 SwiftUI 的动画驱动、瞬态，
没有自己的调度器。

## a11y 分工（FR-13）

粒子层是**纯装饰**，已 `accessibilityHidden(true)` / `allowsHitTesting(false)`。
⚠️ **"这块内容出现了"由调用方通告**——本转场不知道被它包裹的是什么。

## 使用示例 / Usage

```swift
import CoreDesign
import CoreDesignEffects
import SwiftUI

struct UnlockBadge: View {
    @State private var unlocked = false

    var body: some View {
        VStack {
            if unlocked {
                Text("PRO")
                    .font(.largeTitle.bold())
                    .padding(.horizontal, CoreSpacing.xxl)
                    .padding(.vertical, CoreSpacing.md)
                    .background(Color.accent, in: Capsule())
                    .foregroundStyle(Color.contentOnAccent)
                    .transition(.particle)
            }
            Button("Unlock") {
                withAnimation(.easeInOut(duration: 0.6)) { unlocked.toggle() }
            }
        }
        .tint(.accent)
    }
}
```

自定义粒子数与色板：

```swift
.transition(.particle(count: 32, colors: [.statusSuccessEmphasis, .statusAccentEmphasis]))
```

⚠️ **本文档的示例代码零机器覆盖**（与 `confetti.md` 同一条登记）。
