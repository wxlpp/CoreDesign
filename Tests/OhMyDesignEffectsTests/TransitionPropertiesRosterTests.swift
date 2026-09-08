import OhMyDesignEffects
import SwiftUI
import Testing

// MARK: - 全仓 Transition 的 `hasMotion` 花名册 / The repo-wide `hasMotion` roster（Issue #292）

@Suite("Transition 的 hasMotion 花名册（#292）")
struct TransitionPropertiesRoster {
    private struct DefaultPropertiesProbe: Transition {
        func body(content: Content, phase: TransitionPhase) -> some View { content }
    }

    @Test("全仓 12 条 Transition 都据实声明 hasMotion（8 真 / 4 假，逐条）")
    func everyTransitionDeclaresItsMotionHonestly() {
        #expect(TransitionProperties(hasMotion: false).hasMotion == false,
                "`hasMotion` 恒为 true —— 下面 4 条 `== false` 不作数")
        #expect(TransitionProperties(hasMotion: true).hasMotion == true,
                "`hasMotion` 恒为 false —— 下面 8 条 `== true` 不作数")
        #expect(Self.DefaultPropertiesProbe.properties.hasMotion, """
        `Transition.properties` 的协议默认值不再是 `hasMotion == true`
        —— 本文件与三簇文档里所有「默认值是 true，所以未声明者被框架换成 opacity」
        的论证都要重新走一遍。
        """)

        // MARK: 有真实几何运动 ⇒ `true`（8 条）

        #expect(FlipTransition.properties.hasMotion, Self.gateNote("`.flip`"))
        #expect(Rotate3DTransition.properties.hasMotion, Self.gateNote("`.rotate3D`"))
        #expect(SwooshTransition.properties.hasMotion, Self.gateNote("`.swoosh`"))
        #expect(BoingTransition.properties.hasMotion, Self.gateNote("`.boing`"))
        #expect(SkidTransition.properties.hasMotion, Self.gateNote("`.skid`"))
        #expect(PolarMoveTransition.properties.hasMotion, Self.gateNote("`.move`"))
        #expect(MaskRevealTransition.properties.hasMotion, Self.gateNote("`.iris` / `.wipe` / …"))
        #expect(ParticleTransition.properties.hasMotion, Self.gateNote("`.particle`"))

        // MARK: 纯成像滤镜、无几何运动 ⇒ `false`（4 条）

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
