import Foundation
import SwiftUI
import Testing
@testable import CoreDesign

/// NFR-7 的**通用**能耗策略表（`#271` 下沉后住在 `CoreDesign`）。
///
/// ⚠️ **为什么这套判据必须住在 `CoreDesignTests` 而不是 `CoreDesignEffectsTests`**：
/// 下沉后这些类型是 `CoreDesign` 的公开面。留在 Effects 的测试里，等于
/// 「`CoreDesign` 自己的公开面由另一个 target 的测试来守」——
/// 那个 target 一旦被拆掉 / 被 skip，这一面就静默失守。
@Suite("NFR-7 能耗状态与渲染策略（#271 下沉）")
struct EnergyPolicyTests {

    @Test("后台 / 非活跃 ⇒ 停摆；低电量 ⇒ 降级；其余 ⇒ 满帧")
    func policyMapping() {
        #expect(EnergyState(scenePhase: .active, isLowPower: false).policy == .full)
        #expect(EnergyState(scenePhase: .active, isLowPower: true).policy == .reduced)
        #expect(EnergyState(scenePhase: .inactive, isLowPower: false).policy == .paused)
        #expect(EnergyState(scenePhase: .background, isLowPower: false).policy == .paused)
    }

    @Test("注入值优先，`nil` 才从系统读")
    func injectionWinsOverSystem() {
        let injected = EnergyState.resolve(
            injectedScenePhase: .background, systemScenePhase: .active, lowPowerModeOverride: false
        )
        #expect(injected.scenePhase == .background, "注入的 scenePhase 没有盖过系统值 —— NFR-7 的判据整条落空")
        #expect(injected.policy == .paused)

        let fallback = EnergyState.resolve(
            injectedScenePhase: nil, systemScenePhase: .inactive, lowPowerModeOverride: false
        )
        #expect(fallback.scenePhase == .inactive, "注入 nil 时没有回落到系统值")

        let injectedLowPower = EnergyState.resolve(
            injectedScenePhase: .active, systemScenePhase: .active, lowPowerModeOverride: true
        )
        #expect(injectedLowPower.policy == .reduced, "注入的低电量没有生效")
    }

    /// ⚠️ **`nil` 与 `false` 必须可区分**：`false` 是「有人明确注入了『不低电量』」，
    /// `nil` 才是「没人注入、去问系统」。这正是那个环境键是 `Bool?` 而不是 `Bool` 的理由
    /// —— 写成 `Bool` 的话本条无从表达。
    @Test("`nil` 注入 ⇒ 真的去读 ProcessInfo；`false` 注入 ⇒ 不读")
    func nilFallsBackToSystemButFalseDoesNot() {
        let system = ProcessInfo.processInfo.isLowPowerModeEnabled
        let resolved = EnergyState.resolve(
            injectedScenePhase: .active, systemScenePhase: .active, lowPowerModeOverride: nil
        )
        #expect(resolved.isLowPower == system, "注入 nil 时没有从 ProcessInfo 读 —— 默认值不是系统值")

        let explicitFalse = EnergyState.resolve(
            injectedScenePhase: .active, systemScenePhase: .active, lowPowerModeOverride: false
        )
        #expect(explicitFalse.isLowPower == false, "注入 false 被当成了 nil —— 两者必须可区分")
    }

    /// ⚠️⚠️ **承重：两道闸的顺序**。能耗闸必须压过 Reduce Motion 闸——反过来写的话，
    /// 开启「减弱动态效果」的用户恰好在系统规定该停摆的状态下拿到一个还在跑动画的层。
    /// 本仓出过一次「两个调用点各写一遍就写反了」的事故，`#271` 把它下沉正是为此。
    @Test("两道闸的顺序：能耗闸压过 Reduce Motion 闸")
    func energyGateOutranksReduceMotion() {
        for isLowPower in [true, false] {
            let paused = EnergyState(scenePhase: .background, isLowPower: isLowPower)
            #expect(paused.presentation(reduceMotion: true) == .hidden)
            #expect(paused.presentation(reduceMotion: false) == .hidden,
                    "停摆状态下没有整层不画 —— 能耗闸没有压过 RM 闸")
        }
        let active = EnergyState(scenePhase: .active, isLowPower: false)
        #expect(active.presentation(reduceMotion: true) == .resting)
        #expect(active.presentation(reduceMotion: false) == .animated)
    }

    @Test("通用旋钮：停摆不画、低电量降帧、满帧不限速")
    func genericKnobs() {
        #expect(RenderPolicy.paused.drawsAnything == false)
        #expect(RenderPolicy.reduced.drawsAnything)
        #expect(RenderPolicy.full.drawsAnything)
        #expect(RenderPolicy.full.minimumInterval == nil, "满帧不该限速")
        #expect(RenderPolicy.reduced.minimumInterval == 1.0 / 15.0)
        #expect(RenderPolicy.paused.minimumInterval == nil)
    }
}
