import CoreDesignEffects
import SwiftUI
import Testing

// MARK: - 全仓 Transition 的 `hasMotion` 花名册 / The repo-wide `hasMotion` roster（Issue #292）
//
// ## 缺陷本身
//
// `Transition` 协议有 `static var properties: TransitionProperties`，**默认
// `hasMotion == true`**（`swiftinterface` 逐字：`public init(hasMotion: Swift.Bool = true)`）。
// `hasMotion` 的文档注释**逐字**是这三句：
//
// > Whether the transition includes motion.
// > When this behavior is included in a transition, that transition will be
// > replaced by opacity when Reduce Motion is enabled.
// > Defaults to `true`.
//
// ⇒ 未声明者继承 `true`，**开启「减弱动态效果」的用户拿到的是框架替换后的 opacity，
// 而不是各转场自己写的降级形态**。本仓花大量篇幅逐个转场裁定 RM 行为、写进类型文档 /
// `docs/components/*.md` / `docs/component-registry.json` 的 `notes`，但那些裁定描述的是
// **内层门控**，而内层门控在生产中大概率不可达——框架那道闸先触发。
//
// ## 本文件是什么
//
// **一份完整花名册**：全仓 12 条 `Transition` 实现逐条钉住 `properties.hasMotion` 的取值。
//
// ⚠️ **与三簇各自那三条判据有意重叠，这不是冗余**：
// · `TransitionClusterTests.everyTransitionKeepsTheSystemGateOpen`（6 条，3D 与弹性簇）
// · `FilterTransitionTests.everyTransitionOptsOutOfTheFrameworkMotionSubstitution`（4 条，滤镜簇）
// · `MaskRevealTransitionBodyTests.transitionDeclaresItHasMotion`（1 条，mask reveal 簇）
// 三条加起来是 11 条，且**没有任何东西保证它们合起来是全集**——`ParticleTransition`
// 正是那第 12 条，它在 `#292` 之前谁都没盯着（`#253` 落地时全仓零声明）。
// 本文件把「全集」这件事变成一个**一眼可数**的表，并由
// `TransitionPropertiesGuard.everyTransitionHasARuntimeExpectation`（`CoreDesignTests`）
// 与源码扫描做交叉核对：往 `Sources/CoreDesignEffects/` 里新加一条 `Transition`
// 而没在本文件写下 `<类型名>.properties.hasMotion`，那条守卫当场判红。
//
// ## 取值按事实分类，不按簇统一
//
// **有真实几何运动 ⇒ `true`；纯成像滤镜、无几何运动 ⇒ `false`**。
// 后果是**反向**的，两类的注释不能互抄：
// · 取 `true` ⇒ 框架那道闸**先触发**，各转场手写的 RM 闸变成**不可达兜底**
//   （保留理由：防御 `hasMotion` 将来改判、`AnyTransition` 包装、平台版本差异）；
// · 取 `false` ⇒ 框架不替换，**手写闸是唯一保护**。
// 逐条的裁定理由写在各自类型的 `properties` 文档注释里，不在这里重复。

@Suite("Transition 的 hasMotion 花名册（#292）")
struct TransitionPropertiesRoster {

    /// 一个**不覆写** `properties` 的最小 `Transition`，只用来读协议默认值。
    ///
    /// ⚠️ 它是下面那条判据的**互锁**：若哪天 `Transition.properties` 的默认值变成
    /// `hasMotion == false`，那 8 条 `== true` 就对「什么都没声明」同样成立、不再证明任何事。
    ///（`FilterTransitionTests.DefaultPropertiesProbe` 是同一形态的另一份，
    /// 两份都留着——它们各自守着自己那条判据的射程，删掉一份另一条就失了互锁。）
    ///
    /// ⚠️ 本类型住在 `Tests/` 里，**不在 `TransitionPropertiesGuard` 的射程内**
    ///（那条守卫只扫 `Sources/`）。这是有意的：它的全部价值就是"不声明"。
    private struct DefaultPropertiesProbe: Transition {
        func body(content: Content, phase: TransitionPhase) -> some View { content }
    }

    /// ⚠️⚠️ **承重：全仓 12 条 `Transition` 的 `hasMotion` 逐条钉住。**
    ///
    /// 这是「钉**性质**而非钉形状」的判据：它不关心声明写成
    /// `static let` / `static var { }` / 带不带类型标注，只关心**运行时读出来是什么**。
    /// 成本几乎为零，且能被变异证明——把任意一条的取值改回去即判红。
    ///
    /// ⚠️ **它证不了「是显式声明」**：`true` 恰好也是 SDK 默认值 ⇒ 8 条 `== true`
    /// 在「有人把整个 `properties` 删掉」这枚变异下零红。那一半归
    /// `TransitionPropertiesGuard`（`CoreDesignTests`，SwiftSyntax 结构判定）。
    @Test("全仓 12 条 Transition 都据实声明 hasMotion（8 真 / 4 假，逐条）")
    func everyTransitionDeclaresItsMotionHonestly() {
        // 互锁 ①：先证 `hasMotion` 真的是个能取两个值的量，否则下面 12 条里有 8 条恒真。
        #expect(TransitionProperties(hasMotion: false).hasMotion == false,
                "`hasMotion` 恒为 true —— 下面 4 条 `== false` 不作数")
        #expect(TransitionProperties(hasMotion: true).hasMotion == true,
                "`hasMotion` 恒为 false —— 下面 8 条 `== true` 不作数")
        // 互锁 ②：协议默认值仍是 `true`。它是「取 `false` 才是一次真正的退出」这句话的前提，
        // 也是「取 `true` 那 8 条与默认值同值、故必须另有守卫钉显式声明」这句话的前提。
        #expect(Self.DefaultPropertiesProbe.properties.hasMotion, """
        `Transition.properties` 的协议默认值不再是 `hasMotion == true`
        —— 本文件与三簇文档里所有「默认值是 true，所以未声明者被框架换成 opacity」
        的论证都要重新走一遍。
        """)

        // MARK: 有真实几何运动 ⇒ `true`（8 条）
        // 后果：框架那道闸先触发 ⇒ 各自手写的 RM 闸是**不可达兜底**。
        #expect(FlipTransition.properties.hasMotion, Self.gateNote("`.flip`"))
        #expect(Rotate3DTransition.properties.hasMotion, Self.gateNote("`.rotate3D`"))
        #expect(SwooshTransition.properties.hasMotion, Self.gateNote("`.swoosh`"))
        #expect(BoingTransition.properties.hasMotion, Self.gateNote("`.boing`"))
        #expect(SkidTransition.properties.hasMotion, Self.gateNote("`.skid`"))
        #expect(PolarMoveTransition.properties.hasMotion, Self.gateNote("`.move`"))
        #expect(MaskRevealTransition.properties.hasMotion, Self.gateNote("`.iris` / `.wipe` / …"))
        #expect(ParticleTransition.properties.hasMotion, Self.gateNote("`.particle`"))

        // MARK: 纯成像滤镜、无几何运动 ⇒ `false`（4 条）
        // 后果：框架**不**替换 ⇒ 各自手写的闸是**唯一保护**。
        #expect(BlurTransition.properties.hasMotion == false, Self.optOutNote("`.blur`"))
        #expect(FilmExposureTransition.properties.hasMotion == false, Self.optOutNote("`.filmExposure`"))
        #expect(SnapshotTransition.properties.hasMotion == false, Self.optOutNote("`.snapshot`"))
        #expect(FlickerTransition.properties.hasMotion == false, Self.optOutNote("`.flicker`"))
    }

    static func gateNote(_ name: String) -> Comment {
        Comment(rawValue: """
        \(name) 的 `hasMotion` 变成了 `false` —— 那是在对系统说"本转场不含运动"，
        Reduce Motion 下 SwiftUI 将**不再**把它替换成 `.opacity`，
        该转场的无障碍降级就只剩它自己那道手写闸。本簇的取值理由与「内层闸是不可达兜底」
        的记账写在该类型的 `properties` 文档注释里 —— 若这是有意的改动，先改那一节。
        """)
    }

    static func optOutNote(_ name: String) -> Comment {
        Comment(rawValue: """
        \(name) 没有退出框架的 Reduce Motion 替换（`hasMotion` 不再是 `false`）——
        `Transition.properties` 默认 `hasMotion == true`，其语义是「Reduce Motion 开启时
        整条转场被换成 `.opacity`」⇒ 该转场自己那道手写闸会当场变成**死代码**，
        而它是这条转场在 RM 下的**唯一**保护。完整权衡见
        `FilterTransitionSupport.swift` 的《`TransitionProperties.hasMotion`》一节。
        """)
    }
}
