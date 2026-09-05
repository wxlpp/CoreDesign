import CoreDesignEffects
import SwiftUI

// `CoreDesignEffects` 的 nonisolated 消费面（#247 建结构）。
//
// ⚠️ **本文件目前只有模块标识这一条**——`CoreDesignEffects` 现在是**骨架 target**
// （#245 建，不含任何组件）。36 个动效 API 落地后，**由 `shipswift-effects` 的 A-7
// 按 API 单位清单逐个补齐调用点**。
//
// ⚠️ **A-7 的验收措辞不要写成「覆盖全部**公开**值类型」**——那是自指的：漏写
// `public` 的类型压根不算「公开」，probe 自然不覆盖它，`FR-5` 就没人查。
// **按 API 单位清单点名。**
//
//  ⚠️ **A-7 补调用点时必须按类型形态分流**（#260 终审 Important-2）——不是所有 API 单位
//  都能进本文件：
//
//  | 类型形态 | 落哪 | 为什么 |
//  |---|---|---|
//  | 值类型 / 配置类型 / 数据入参（枚举、struct 参数、图表数据点…） | **本文件**（`nonisolated func`） | 它们是调用方在自己模型层构造的东西，被 `MainActor` 隔离会让下游在后台线程准备数据时用不了——**这只有本 probe 看得见** |
//  | `View` struct / `public extension View` 的 modifier / style | **`PublicVisibility.swift`**（`@MainActor func`） | 本包开了 `.defaultIsolation(MainActor.self)`，View 的 `init` 与 modifier 函数**天然是 MainActor 隔离的**；从 `nonisolated func` 里构造它们必然编译失败，除非给所有 View init 标 `nonisolated`——**那不是我们要的契约** |
//
//  ⇒ 「按 API 单位清单点名」的意思是：**每个单位在这两个文件之一必有引用**，
//  不是"全部塞进本文件"。`PublicVisibility.swift` 的文件头已经写明了这个分工
//  （那边守**可见性**、这边守**隔离**）。
//
//  ⚠️ **"漏 `public` 会在这里炸出来"只覆盖类型名与被实际构造的 `init`**——
//  `body` 漏 `public` 不影响下游把它当 View 用，probe 结构上抓不到。
//  那一条靠 `scripts/api-surface-diff.sh` 或别的守卫。

nonisolated func readEffectsModuleName() -> String {
    CoreDesignEffects.moduleName
}

// MARK: - NFR-7 的能耗值类型（Issue #252）
//
// ⚠️ 这三个类型走**本文件**而不是 `PublicVisibility.swift`，按文件头的分流表：
// 它们是**值类型 / 配置类型**，`nonisolated` 是它们的承重契约。
// 若哪天有人把 `EffectsEnergyState` 上的 `nonisolated` 拿掉，本函数当场编译红
// （`main actor-isolated ... can not be referenced from a nonisolated context`）。
//
// ⚠️⚠️ **这里曾写着「`shipswift-shaders` 的 17 个 `colorEffect` 会在渲染参数准备阶段
// 用它们」——那句话与两个能耗键下沉的立论直接打架，已按事实改写**
// （#252 PR #269 第 2 轮终审 I-B）。
//
// 下沉（`\.lowPowerModeOverride` / `\.scenePhaseOverride` 搬进 `CoreDesign`）的**全部理由**
// 是「键留在 Effects 会逼只想要 shader 的消费者链上整个 Effects product」。而这三个类型
// **仍然住在 `CoreDesignEffects`**：B-2 若真去消费它们，就得 `import CoreDesignEffects`，
// 那条依赖一条都没省下——两句不能同时为真。
//
// ⇒ **事实是**：B-2 只消费 `CoreDesign` 的那两个键（`Bool?` / `ScenePhase?`），
// **自行派生**自己那套渲染参数；`EffectsEnergyState` / `EffectsRenderPolicy` /
// `EffectsPowerMode` 是**动效层的**语义面，本 probe 是它们在模块外的**唯一**消费者
// （守的是 `nonisolated` 这条契约，不是"下游真的会这样用"的示范）。
//
// ⚠️ **未了结的残余**（已同步登记在 `EffectsRenderPolicy` 的裁决记录里）：
// `EffectsRenderPolicy` 自己把策略分成「通用」（`drawsAnything` / `minimumInterval`
// ——任何常驻渲染件都要）与「effects 专用」（`particleScale` / `usesGlow`），
// 而本轮只下沉了**原始信号**，被标为「通用」的那半张策略表仍在 Effects。
// ⇒ B-2 要么重新派生一遍（本仓反复在堵的"两处各写一遍必然漂移"），
// 要么就这半张表再裁决一次。**本轮不解决跨 epic 归属，只如实留痕。**

nonisolated func resolveEffectsRenderPolicy() -> EffectsRenderPolicy {
    EffectsEnergyState.resolve(
        injectedScenePhase: nil,
        systemScenePhase: .active,
        injectedPowerMode: EffectsPowerMode.current
    ).policy
}

nonisolated func readEffectsPolicyKnobs() -> (Bool, Bool, Double?, Double) {
    let policy = EffectsRenderPolicy.reduced
    return (policy.drawsAnything, policy.usesGlow, policy.minimumInterval, policy.particleScale)
}

// MARK: - 文本与展示动效的值类型（Issue #253）
//
// ⚠️ 按文件头的分流表，`#253` 的四个 API 单位只有**值类型**这一档落在本文件：
// · `TypewriterSpeed` —— `public nonisolated enum`，调用方会在自己的配置层构造它
//   （"这段引导语用哪一档速度"这种决定不该被逼上主线程）。
// · `ParticleTransition.defaultCount` —— `public static let`，同上。
// 其余三个（`TypewriterText` / `AnimatedMeshGradient` / `BeforeAfterSlider` 三个 View、
// 以及 `Transition.particle` 这个静态成员）是 **View / 转场形态**，
// 从 `nonisolated func` 里构造它们必然编译失败 ⇒ 它们的可见性由
// `PublicVisibility.swift` 那侧的 `@MainActor func` 守，不进本文件。
//
// ⚠️ 若哪天有人把 `TypewriterSpeed` 上的 `nonisolated` 拿掉，本函数当场编译红
// （`main actor-isolated ... can not be referenced from a nonisolated context`）
// ——那正是本 probe 唯一看得见的那类回归。

nonisolated func readTypewriterSpeedKnobs() -> [Double] {
    TypewriterSpeed.allCases.map(\.secondsPerCharacter)
}

nonisolated func readParticleTransitionDefaultCount() -> Int {
    ParticleTransition.defaultCount
}

// MARK: - #254 的公开值类型（跨平台改造）
//
// ⚠️ 四件的公开面里**只有这四个常量是值类型**，其余全是 `View`（在
// `PublicVisibility.swift`，`@MainActor`）。按文件头的分流表，它们走本文件：
// 它们是调用方在自己模型 / 配置层会读的东西，被 `MainActor` 隔离会让下游
// 在后台线程准备参数时用不了——**这只有本 probe 看得见**。
nonisolated func readCrossPlatformDefaults() -> [Double] {
    [
        Double(DotSphere.defaultCount),
        DotSphere.defaultRotationPeriod,
        Double(CharSphere.defaultCount),
        CharSphere.defaultRotationPeriod,
    ]
}

// MARK: - #266 滤镜类转场的公开值类型

// ⚠️ 按文件头的分流表，`#266` 的四种转场只有**默认值常量**这一档落在本文件：
// 它们是调用方在自己配置层会读的东西（"这块卡片用多大的失焦半径"），
// 被 `MainActor` 隔离会让下游在后台线程准备参数时用不了——**这只有本 probe 看得见**。
// 四个 `Transition` 静态成员（`.blur` / `.filmExposure` / `.snapshot` / `.flicker`）
// 是**转场形态**，从 `nonisolated func` 里构造必然编译失败 ⇒ 它们在
// `PublicVisibility.swift`（`@MainActor`）那侧。
//
// ⚠️ **安全档位那套（`FilterTransitionSafety`）有意不在这里**：它是 `internal`
// ——理由与 `EffectsPresentation` 逐字相同（`public` 会让它的裸 `Bool` 参数命中
// `BoolExemptionGuard`，要一条署名豁免并抬棘轮，而本 epic 的净增预算只有 2 条）。
nonisolated func readFilterTransitionDefaults() -> (Double, Double, Double, Int) {
    (
        Double(BlurTransition.defaultRadius),
        FilmExposureTransition.defaultIntensity,
        SnapshotTransition.defaultIntensity,
        FlickerTransition.defaultCycles
    )
}

// MARK: - #268 的公开值类型（mask reveal 转场簇）
//
// ⚠️⚠️ **这四个常量是本 probe 在 #268 上唯一看得见、而库自身四条验证命令结构上
// 看不见的东西**（#268 终审 I-3）：本包开了 `.defaultIsolation(MainActor.self)`,
// 而 `CoreDesignEffects` 也开了 —— 不给它们标 `nonisolated` 时，从**本文件这样的
// `nonisolated` 上下文**读一个默认值会拿到：
//
//     warning: main actor-isolated static property 'defaultWipeAngle'
//              can not be referenced from a nonisolated context
//
// 而库自身的 `swift build` / `swift test` 全跑在被隔离的 target **内部**，全绿。
// ⇒ 本函数是那条 warning 的**常驻判据**。⚠️ **这句话曾一度为假，历程照录**：
// 更早的一版写「本函数就是那条警告的常驻判据（`swift build` 要求零新警告）」，
// 经 #291 第 2 轮 Imp-1 查实为假后**降级**成「观测点，不是判据」——因为当时
// CI 的 `downstream-probe` job 跑的是不带 `-Xswiftc -warnings-as-errors` 的
// `swift build`，最直接的反证就是本包**当时带着 5 条既存 warning 而 CI 是绿的**
// （#290）。
//
// ⇒ **#290 把那 5 条消掉、并给 `.github/workflows/ci.yml` 的 probe 那步加上了
// `-Xswiftc -warnings-as-errors`**，这句话才重新为真：今天谁把上面这些
// `nonisolated` 拿掉，probe 多一条 warning ⇒ 那一步**判红**。
// 加严真的会响这件事本身也有 fixture 守着，见
// `scripts/downstream-probe/selftest-warnings-as-errors.sh`（AD-E：新守卫必须
// 带一个能触发红的 fixture，否则不知道它真的会响）。
//
// ⚠️ 六种转场的十二个入口点是**转场形态**，在 `PublicVisibility.swift`
// （`@MainActor func consumeMaskRevealTransitions()`）——分流理由见本文件头的表。
nonisolated func readMaskRevealTransitionDefaults() -> (Int, CGFloat, Double, Double) {
    (
        MaskRevealTransition.defaultBlindCount,
        MaskRevealTransition.defaultCellSize,
        MaskRevealTransition.defaultWipeAngle.radians,
        MaskRevealTransition.defaultGlareAngle.radians
    )
}

// MARK: - #250 的公开值类型（8 个微交互 modifier）
//
// ⚠️ 按文件头的分流表，`#250` 的 8 个 API 单位里**只有两个枚举**落在本文件：
// `MicroInteractionStrength`（7 个 modifier 的档位入参）与 `SpinDirection`
// （`.spin` 与 `.clock` 共用的方向枚举）。它们是调用方在**自己的配置层**构造的东西
// ——「这个按钮抖多狠」「这个刷新图标往哪转」不该被逼上主线程。
// 8 个 modifier 本身是 `public extension View` 的方法 ⇒ 天然 MainActor 隔离，
// 在 `PublicVisibility.swift`（`consumeMicroInteractionModifiers`）。
//
// ⚠️ **`SpinDirection` 不只服务 `.spin`**：`Transition.clock(direction:)`（#268）
// 的实参也是它 ⇒ 它掉 `nonisolated` 会同时打断两个 API 单位的下游配置层。
//
// ⚠️ 与 `TransitionTravel` / `TransitionAxis3D` 同一形态（见 `TransitionClusterProbe.swift`
// 里那段实测记录）：`allCases` + `==` 这两条路径分别踩 key path 与 isolated conformance，
// 是本 probe 唯一看得见的那类回归。
nonisolated func readMicroInteractionStrengths() -> [Bool] {
    MicroInteractionStrength.allCases.map { $0 == .regular }
}

nonisolated func readSpinDirections() -> [Bool] {
    SpinDirection.allCases.map { $0 == .clockwise }
}

// MARK: - #290 补齐的默认值常量（全仓扫描的其余命中）

// ⚠️ `OrbitingLogos.defaultRotationPeriod` 与上面 `#254` 那四个同族，只是**长在
// 泛型 View 上** ⇒ 读它必须写出三个具体的泛型实参（同 `ChartsNonisolatedUsage.swift`
// 里 `NetworkGraph<ChartsProbeNode>.recommendedNodeLimit` 那条注释记的形态）。
// 若哪天它被挪到一个非泛型的命名空间上，这行会红，那是**预期的**。
nonisolated func readOrbitingLogosDefaultRotationPeriod() -> Double {
    OrbitingLogos<[CrossPlatformProbeItem], Text, Text>.defaultRotationPeriod
}

// ⚠️ 12 条转场的 `properties` 也是**值类型那一档**：`TransitionProperties` 是纯值，
// 而 `hasMotion` 正是调用方在自己的降级判断里会读的东西（"这条转场含运动吗，
// 我要不要在 Reduce Motion 下换一条"）——那个判断不该被逼上主线程。
//
// ⚠️ 它们此前的 MainActor 隔离**不来自 `defaultIsolation` 直接命中**，而是从
// SwiftUI 的 `Transition` 协议遵从**推断**而来 ⇒ 编译器把诊断降级成 warning
// （与 `#254` / `#253` 那 5 条同一档；`SettingsRowMetrics` 那一组是 error）。
// 标 `nonisolated` 后见证不再依赖 preconcurrency 降级。
//
// ⚠️ **上一版这里写「见证与协议要求（`static var properties { get }`，nonisolated）
// 严格对齐」——实测为假，照录更正**（PR #304 终审 F-3）：协议要求本身**不是**
// `nonisolated`。SDK 逐字（`SwiftUICore.swiftinterface`）：
//
//     @preconcurrency @_Concurrency.MainActor public protocol Transition {
//       @_Concurrency.MainActor @preconcurrency static var properties: TransitionProperties { get }
//     }
//
// ⇒ 要求是 `@MainActor @preconcurrency`。把见证标 `nonisolated` 是**合法的放宽**
// （见证可以比要求更不受限，反之不行），不是「严格对齐」。它买到的东西是：
// 下游读这些 `properties` 时不再落进 `@preconcurrency` 的降级诊断——而降级本身
// 正是上面两行说的那件事，`@preconcurrency` 干的。
//
// ⚠️ 12 条**逐条**登记、不抽样：`TransitionPropertiesGuard` 守的是"有没有声明"，
// 守不到"声明能不能从 nonisolated 读"——那是本 probe 这一侧。
nonisolated func readTransitionPropertiesHasMotion() -> [Bool] {
    [
        BlurTransition.properties.hasMotion,
        BoingTransition.properties.hasMotion,
        FilmExposureTransition.properties.hasMotion,
        FlickerTransition.properties.hasMotion,
        FlipTransition.properties.hasMotion,
        MaskRevealTransition.properties.hasMotion,
        ParticleTransition.properties.hasMotion,
        PolarMoveTransition.properties.hasMotion,
        Rotate3DTransition.properties.hasMotion,
        SkidTransition.properties.hasMotion,
        SnapshotTransition.properties.hasMotion,
        SwooshTransition.properties.hasMotion,
    ]
}
