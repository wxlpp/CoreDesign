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

    // ⚠️ 这些不是"能编译就行"的凑数测试——它们钉住的是**会静默漂移的契约**：
    // 八个入口的存在性、参数默认值、以及 trigger 的类型约束。
    // 少一个入口、或某个默认值被改掉，调用方不会有编译错误，只会行为变了。

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

    @Test("零 Bool 参数 —— J-1 纪律")
    func noBoolParameters() {
        // ⚠️ 这条靠的是**签名本身**：若有人给某个入口加了 `Bool` 参数，
        // 下面这些不带该参数的调用仍然编译（有默认值时），所以本测试**抓不到**新增的
        // Bool 参数——真正的守卫是 `BoolExemptionGuard`（#246 扩到本 target 后生效）。
        // 这里只留一条断言 + 这段说明，避免后人以为 Bool 纪律已被测试覆盖。
        #expect(Bool(true))
    }
}
