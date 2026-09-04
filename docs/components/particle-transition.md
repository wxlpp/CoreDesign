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

⚠️ `public struct ParticleTransition` 本身**不**进 `components` 数组：
`ComponentRegistryGuard.coreDesignSources` 仍是单根 `Sources/CoreDesign`，
塞进去会被判成幽灵条目（同 #250 `Shine` / #252 三容器的处置；该口子由 issue #270 收口）。

## 取色（FR-8）

粒子取色池默认**为空 ⇒ 全部取调用方的 `.tint`**，与 `.spray` / `.confetti` 共用同一个
取色函数（`[Color].particleStyle(at:)`）。**不给彩虹默认色板**——那是品牌决定。

判据：`ParticleTransitionTests.particlesFollowCallerTint`（空色板下换 `.tint` 位图必须变；
给了色板则必须**不**变）。

## 相位契约

| 相位 | 进度 | 内容不透明度 | 内容缩放 | 粒子 |
|---|---|---|---|---|
| `.willAppear`（`value == -1`） | 1 | 0 | 0.88 | 满 |
| `.identity`（`value == 0`） | **0** | 1 | **1** | **一颗都不画** |
| `.didDisappear`（`value == 1`） | 1 | 0 | 1.12 | 满 |

⚠️ **`.identity` 必须恒为恒等**：那是转场结束后停住的那一帧，也是用户实际长期看到的
那一帧（`ShineBand.terminalProgress` / `ConfettiBurst.opacity` 都记着同一条教训）。
判据 `ParticleTransitionTests.identityFrameDrawsNothing` 带互锁：中途（progress 0.4）
必须画得出粒子，否则那条相等断言是恒真的。

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
