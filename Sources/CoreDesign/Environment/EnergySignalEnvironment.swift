//
//  EnergySignalEnvironment.swift
//  CoreDesign
//
//  两个**通用**能耗 / 生命周期信号的可注入 EnvironmentValues 键
//  / Injectable environment keys for the two generic energy & lifecycle signals.
//

import SwiftUI

// MARK: - 为什么要有"可注入"这一层

// `shipswift-effects` 的 PRD **NFR-7** 逐字要求：常驻渲染的效果（`colorEffect` 背景、
// Confetti、ScanningOverlay）必须**定义**并**可测**它们在 App 进入后台、以及低电量模式下
// 的行为。⚠️ 并且逐字写明「**不接受"或文档声明"**」——那会让这条退化成文档要求。
//
// 而这两个信号在单测里**都不可直接切换**：
// · `ProcessInfo.processInfo.isLowPowerModeEnabled` 是只读的系统状态；
// · `\.scenePhase` 由 SwiftUI 的 `Scene` 供给，`ImageRenderer` 下没有 Scene 可驱动。
//
// ⇒ 这里把两个信号做成**可注入的 `EnvironmentValues` 键**（**默认从系统读**，注入值优先）。
// 测试注入伪值 ⇒ 渲染行为可断言，判据落在机器上而不是文档里。
//
// ## ⚠️ 为什么这两个键住在 `CoreDesign` 而不是 `CoreDesignEffects`
//
// （#252 PR #269 第 1 轮终审 S-2 的**已裁决**处置。⚠️ 裁决的**完整记录**——冲突原文、
// 两条出路、选中哪条——随 `#271` 下沉时**删除**了，不是搬走：同目录的 `EnergyPolicy.swift`
// 只留结论摘要。要读原文去 `main` 上的 `Sources/CoreDesignEffects/EffectsEnergy.swift`。
// 旧名到新名的对照见 `docs/BREAKING-CHANGES.md`。）
//
// 这两个信号是**任何**常驻渲染件都要的通用能耗输入，不是动效层专有：
// `shipswift-shaders` 的 B-2（17 个 `colorEffect` 背景）同样要按它们降级。
// 键若留在 Effects，B-2 就必须 `import CoreDesignEffects`，于是**只想要 shader 的消费者
// 也被迫链上整个 Effects product**——与 `Package.swift` 拆 product 的逐字理由
// 「只想要系统原生观感的消费者不必背上动效与图表」直接抵触。
// `CoreDesign` 是 Effects / Charts / Shaders 共同的依赖底座 ⇒ 键放这里，
// B-2 只需 `import CoreDesign`。跨模块可见性证明见
// `scripts/downstream-probe` 的 `EnergySignalEnvironment.swift`（**该文件只 `import
// CoreDesign`**——这正是"下沉到底了"这件事的机器判据；库内断言证不了它，
// internal 在同模块内一样能过）。
//
// ⚠️ **下沉的不只是这两个信号**：由它们派生的**通用**策略表（`RenderPolicy` /
// `EnergyState` / `MotionPresentation`，见同目录 `EnergyPolicy.swift`）也在 `CoreDesign`。
// 只有键而没有那张表的话，B-2 仍要自己复刻一遍"两道闸的顺序"，下沉只兑现一半。
// ⚠️ **界线在"通不通用"，不在"在不在这一层"**：effects 专用的旋钮
//（`usesGlow` / `particleScale` / 自转退化保护）仍在 `CoreDesignEffects/EffectsEnergy.swift`，
// 以 `extension` 挂回下沉后的类型。
//
// ## ⚠️ 为什么低电量键是 `Bool?` 而不是一个枚举
//
// 用户裁决（2026-09-04）：**用 `Bool`**。理由是键在这一层的身份变了——它不再是
// "动效层的能耗档位"，而是 `ProcessInfo.processInfo.isLowPowerModeEnabled` 这个
// **系统读数本身**的可注入镜像，而那个读数的形状就是 `Bool`。让通用底座去定义一个
// "档位枚举"，等于把动效层的语义分级摊派给所有消费者（shader 那 17 个背景没有"档位"，
// 只有"要不要省电"）。需要更细分级的模块**自己**在上面包一层。
// ⚠️ **今天没有任何模块真的包了这一层**：Effects 那个二态枚举 `#271` 实测已无人读其 case、
// 随之删除（见 `docs/BREAKING-CHANGES.md`）⇒ 这句话是留给未来的余地，不是既成事实。
//
// ⚠️ **这条不欠 Bool 纪律的账，且这句是实查结论不是推断**：本仓的
// `BoolExemptionGuard` / `docs/bool-exemptions.json` 对两种声明处置不同——
// · public **函数 / init / subscript / enum case 参数**：`BoolParameterScanner` 的
//   `collect(_:decl:modifiers:at:)` 把它们收进 `hits` ⇒ 命中判据、要豁免、抬棘轮基线；
// · public **属性**（`EnvironmentValues.lowPowerModeOverride` 正是属性）：
//   `BoolParameterScanner.visit(_: VariableDeclSyntax)` 明写「public 的 Bool **属性**：
//   只清点，不判据（裁决 (d)）」，收进 `publicBoolProperties`，而
//   `BoolExemptionGuard` 对该集合**只 `print`、不断言、无基线**。
// ⇒ 本键写成 `Bool?` 净增豁免 **0** 条，`maxEntries` / `sourceSites` 一动不动。
// ⚠️ 别把这条读宽了：它只对**属性**成立。谁将来把这个键包成
// `public func f(lowPowerMode: Bool)`，那条就命中判据、要一条署名豁免。

// MARK: - 可注入的 EnvironmentValues 键 / Injectable environment keys

// ⚠️ **扩展本身刻意写成 `extension` 而不是 `public extension`**：后者会让成员上的
// `public` 变成"冗余修饰符"。实测得到的**原样是一条 `warning:`**
// （`'public' modifier is redundant for property declared in a public extension`），
// **只有带上 `-Xswiftc -warnings-as-errors` 时才升级成编译红**
// ——而本仓的本地验证与 `verification-before-completion` 恰好都带这个 flag，
// 所以在我们的工作流里它确实是"红"。不带 flag 时它只是一条警告，别把这句读成无条件的。
// 而这两个键的 `public` 是一条**跨 epic 承重契约**，必须写在成员上、在 diff 里看得见
// ——本仓 `\.toastHost` 用的也是这个形态（`extension EnvironmentValues` + `@Entry public var`）。
extension EnvironmentValues {

    /// **可注入**的低电量模式。`nil`（默认）⇒ 从 `ProcessInfo.processInfo.isLowPowerModeEnabled` 读。
    ///
    /// ```swift
    /// // 测试 / 预览里伪造低电量：
    /// ScanningOverlay { card }.environment(\.lowPowerModeOverride, true)
    /// ```
    ///
    /// ⚠️ **显式 `public`，不靠 `public extension` 推导**：`@Entry` 宏展开时是否继承
    /// 外层扩展的访问级别是隐式行为（本仓 `\.toastHost` 已为同一件事显式标注过），
    /// 而 `CoreDesignEffects` 与 `shipswift-shaders` 的 B-2 都要跨模块读这个键——
    /// 推导一旦不成立，断的是一条**跨 epic 契约**，且要等到另一个 epic 才会被发现。
    ///
    /// ⚠️ **默认值是 `nil` 而不是当前系统读数**：`nil` 的语义是"**没有人注入**"，
    /// 与"注入了 `false`"必须可区分——后者是宿主 App 明确说"按常规供电渲染"
    /// （例如它自己订阅了 `NSProcessInfoPowerStateDidChange`），不该被系统读数覆盖。
    /// 真正的"从系统读"发生在**唯一**的解析点
    /// `EnergyState.resolve(injectedScenePhase:systemScenePhase:lowPowerModeOverride:)`
    /// ——`#271` 起它与本键同在 `CoreDesign`。
    ///
    /// ⚠️ **名字里没有 `effects`**（本轮下沉时重估）：旧名 `\.effectsPowerMode` 是它住在
    /// `CoreDesignEffects` 时的名字，下沉后该前缀名实不符——它不再是动效层专有。
    /// `Override` 后缀承载的正是那个三态语义：**没有 override ⇒ 读系统**。
    ///
    /// ⚠️ **它不是响应式的**：`ProcessInfo` 的低电量状态变化会发
    /// `NSProcessInfoPowerStateDidChange` 通知，但读系统那一步只在消费点被求值时跑一次，
    /// 不会因为该通知而让视图失效。需要"用户中途打开低电量模式就立刻降级"的宿主 App，
    /// 应当自己订阅该通知并注入本键——这也正是它存在的第二个用途（第一个是可测）。
    /// 逐效果的响应性差异（哪些旋钮每帧重解析、哪些不）见 `ProcessingSweepBody` 的类型文档。
    @Entry public var lowPowerModeOverride: Bool? = nil

    /// **可注入**的场景阶段。`nil`（默认）⇒ 从系统的 `\.scenePhase` 读。
    ///
    /// ```swift
    /// // 测试 / 预览里伪造"App 进了后台"：
    /// ScanningOverlay { card }.environment(\.scenePhaseOverride, .background)
    /// ```
    ///
    /// ⚠️ **为什么不直接注入 SwiftUI 自己的 `\.scenePhase`**：那个键的语义是
    /// "宿主 Scene 现在处于哪个阶段"，覆盖它会连带影响调用方视图里**任何**读
    /// `\.scenePhase` 的代码（包括宿主自己的业务逻辑）。本库只想影响**自己的**
    /// 装饰层，故另开一个键、且默认让位给系统值。
    /// ⇒ 名字读作"CoreDesign 系组件认的那个 scene phase override"，
    /// **不是**"覆盖 SwiftUI 的 `\.scenePhase`"——它对宿主自己的代码一无所知。
    @Entry public var scenePhaseOverride: ScenePhase? = nil
}
