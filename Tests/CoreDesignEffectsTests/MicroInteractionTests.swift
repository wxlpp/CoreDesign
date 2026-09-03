import SwiftUI
import Testing

/// ⚠️ **必须显式 `nonisolated`**——本 target 设了 `defaultIsolation(MainActor)`，
/// 它作用于**整个 target**，把枚举提到文件作用域**并不够**：conformance 照样是
/// MainActor 隔离的。实测报 `#IsolatedConformances`。
private nonisolated enum TriggerPhase: Equatable, Sendable { case idle, done }

@testable import CoreDesignEffects

@Suite("MicroInteractionStrength 语义档位")
struct MicroInteractionStrengthTests {

    // ⚠️ 断言的是**档位之间的关系**，不是具体数值——数值是可调的实现细节，
    // 而"更强 ⇒ 位移更大"是这个枚举的语义承诺。

    @Test("三条轴都随档位单调递增")
    func monotonic() {
        let all = MicroInteractionStrength.allCases
        #expect(zip(all, all.dropFirst()).allSatisfy { $0.displacement < $1.displacement })
        #expect(zip(all, all.dropFirst()).allSatisfy { $0.scaleDelta < $1.scaleDelta })
        #expect(zip(all, all.dropFirst()).allSatisfy { $0.particleCount < $1.particleCount })
    }

    @Test("粒子数至少 1 —— 0 会让 spray 静默什么都不画")
    func particleCountIsPositive() {
        #expect(MicroInteractionStrength.allCases.allSatisfy { $0.particleCount >= 1 })
    }

    @Test("SpinDirection 的 sign 互为相反数")
    func spinDirection() {
        #expect(SpinDirection.clockwise.sign == -SpinDirection.counterClockwise.sign)
        #expect(SpinDirection.clockwise.sign > 0)
    }
}

@Suite("微交互的 API 契约")
@MainActor
struct MicroInteractionAPITests {

    // ⚠️ **诚实标注：本 suite 是「编译契约」级，不是行为验证**（#262 终审 I2）。
    // 它钉住的是「八个入口存在、可链式组合、trigger 接受任意 `Equatable`」——
    // 这些**在编译期**成立即通过，`#expect(v is any View)` 那句本身是恒真的。
    //
    // ⚠️ **抓不到**：叠加时的实际视觉行为、Reduce Motion 下的降级效果、参数默认值。
    // 那些在 macOS 单测里**不可观测**（需要真实渲染与环境注入）⇒ 靠 `#Preview` 人工验证。
    // 250.md 里「叠加互不干扰……有测试」「Reduce Motion……测试可证」两项
    // **本 PR 未真正满足**，已在 task 文件标注，不打勾。
    //
    // ⚠️ **Bool 纪律（J-1）不在本 suite 覆盖范围内**——真正的守卫是
    // `BoolExemptionGuard`，它要等 #246 扩到本 target 才生效。初版曾有一条
    // `#expect(Bool(true))` 的 `noBoolParameters`，会以"J-1 已覆盖"的名义出现在
    // 测试报告里，已删除。

    @Test("八个入口全部存在且可链式组合")
    func allEntryPointsCompose() {
        // 全部叠在同一个视图上 —— 同时也验证它们互不冲突（US-1 的"可叠加"）。
        let composed = Text("x")
            .shake(trigger: 1)
            .jump(trigger: 1)
            .spin(trigger: 1)
            .ping(trigger: 1)
            .spray(trigger: 1, symbol: "heart.fill")
            .rise(trigger: 1, text: "+1")
            .haptic(.success, trigger: 1)
            .shine(trigger: 1)
        #expect(composed is any View)
    }

    @Test("trigger 接受任意 Equatable & Sendable，不只是 Int")
    func triggerIsGeneric() {
        // ⚠️ `TriggerPhase` 是**文件作用域 + 显式 `nonisolated`**——见其声明处的说明。
        let v = Text("x")
            .shake(trigger: TriggerPhase.done)
            .spin(trigger: "string")
            .ping(trigger: 3.14)
        #expect(v is any View)
    }

}
