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
// ⇒ 本函数是那条 warning 的**观测点**，⚠️ **不是判据**：上一版这里写「本函数就是
// 那条警告的常驻判据（`swift build` 要求零新警告）」——**那句话是错的，照录更正**
// （#291 第 2 轮 Imp-1）。CI 的 `downstream-probe` job（`.github/workflows/ci.yml`）
// 跑的是 `cd scripts/downstream-probe && swift build`，**不带**
// `-Xswiftc -warnings-as-errors`（全仓 `ci.yml` 里一处都没有）⇒ **新增 warning
// 不会让它变红**。最直接的反证：本包**今天就带着 5 条既存 warning 而 CI 是绿的**
// （#290）。⇒ 谁把上面这些 `nonisolated` 拿掉，probe 多一条 warning、CI 照样绿；
// 今天这件事只能靠人读 build 输出。
//
// ⚠️ 把它做实的动作是给那一步加 `-Xswiftc -warnings-as-errors`，但**今天做不了**：
// 那 5 条既存 warning 会让 CI 立刻变红，而它们属 #290、不在 #268 范围
// ⇒ **那是 #290 的收尾判据**；在它落地之前，本函数只是观测点。
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
