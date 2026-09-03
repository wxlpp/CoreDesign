import SwiftUI
import Testing

/// ⚠️ **本类型刻意 *不* 标 `nonisolated`、*不* 声明 `Sendable`。**
///
/// 这是**第 5 项修复的钉子**（终审 I-6）：初版这里写的是
/// `private nonisolated enum TriggerPhase: Equatable, Sendable`，理由是"不加会报
/// `#IsolatedConformances`"——那在**修复前**成立，修复后不再成立。于是那条测试用的
/// 三个 trigger（显式 `Sendable` 的枚举、`String`、`Double`）**全都是 `Sendable`**
/// ⇒ 把代码回退成「泛型直接进动画 modifier」这枚变异，**测试照样绿**。
///
/// 现在它是一个 **MainActor 隔离 conformance** 的类型：只有 `TriggerRelay` 那层中继
/// 把泛型挡在动画 modifier 之外，它才编得过。**回退即编译失败**——这正是要钉住的性质。
private enum IsolatedTrigger: Equatable { case idle, done }

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

    /// 静息态渲染尺寸。⚠️ `nsImage` 是 macOS 专有，iOS 腿要走 `uiImage`——
    /// 本仓成法见 `ToastPresentationRenderTests` 的同名 helper。
    static func renderedSize(_ view: some View) -> CGSize? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        #if canImport(UIKit)
        return renderer.uiImage?.size
        #else
        return renderer.nsImage?.size
        #endif
    }

    // ⚠️ **本 suite 现在有真断言了**（#262 终审 I-4 / S-1）。
    //
    // 初版这里写着「在 macOS 单测里不可观测 ⇒ 靠 #Preview 人工验证」，并据此把
    // 两条 AC 记为未满足。**那个判断是错的**：
    // · 「叠加互不干扰」用 `ImageRenderer` 的**静息尺寸相等**就能测——本仓已有
    //   9 个文件在用这套 harness（`ToastPresentationRenderTests` 等）；
    // · 「Reduce Motion 降级」由 `MicroInteractionReduceMotionGuard`（源码扫描）
    //   机器守住，那正是本仓的主流测试形态。
    //
    // ⚠️ **真正不可观测的只是动画的中间帧**——`ImageRenderer` 拍的是静态帧，
    // 本仓 `ToastPresentationRenderTests` 已经把这条限度写死。记账应当写
    // 「动画中间帧不可观测」，而不是把整个 Reduce Motion 归入不可测。
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
        // ⚠️ 初版这里是 `#expect(composed is any View)` —— **静态恒真**
        //（编译器会给 `'is' test is always true`），与上一轮删掉的
        // `#expect(Bool(true))` 是同一种病，只是加了诚实注释。已换成真断言：
        // 静息态下叠满 8 个 modifier，**渲染尺寸必须与裸视图一致**
        //（不移位、不撑大）——这是 US-1「可叠加、互不干扰」真正可观测的那一半。
        let bare = Self.renderedSize(Text("x"))
        let stacked = Self.renderedSize(composed)
        // ⚠️ **非空断言不可省**：两边都渲染失败（都是 nil）时 `bare == stacked` 恒真，
        // 那就又是一条假绿——正是本文件反复栽的那个跟头。
        #expect(bare != nil && stacked != nil, "渲染失败，下面的相等断言会静默变绿")
        #expect(bare == stacked, "叠加 8 个微交互后静息尺寸变了：\(String(describing: bare)) → \(String(describing: stacked))")
    }

    @Test("trigger 接受任意 Equatable —— 含 MainActor 隔离 conformance 的类型")
    func triggerIsGeneric() {
        // ⚠️ `IsolatedTrigger` **刻意是 MainActor 隔离 conformance**——见其声明处。
        // 这一行编得过，本身就是「泛型没有渗进动画 modifier」的证明。
        let v = Text("x")
            .shake(trigger: IsolatedTrigger.done)
            .spin(trigger: "string")
            .ping(trigger: 3.14)
        // 同上：换成可观测断言，不留恒真表达式。
        let stacked = Self.renderedSize(v)
        #expect(stacked != nil)
        #expect(stacked == Self.renderedSize(Text("x")))
    }

}
