import Testing
import Foundation
@testable import CoreDesign

// MARK: - ToastHost state machine tests
//
// 这些测试覆盖 epic ADR #16 的 3 条 Hard AC：
// 1. dismiss timing：duration 从 start of display 起算
// 2. append 状态机：dismissing 中 / 显示中 show(...) 都 append 到队尾
// 3. dismiss(id:) 对排队 / 正在显示 / 不存在 id 的不同行为
//
// 时间敏感用例用 short duration（0.05–0.3 秒），非时间敏感用例用 duration: 5
// 防止自动 dismiss 干扰；不测视图层渲染。
//
// 时序余量 / Timing buffers（R1 fix）：
// 这些测试依赖 `Task.sleep` 真实墙钟时间，余量 buffer 取 0.3–0.5 秒以
// 容忍慢速 CI / 高 CPU 负载下的调度抖动。**不**引入 `Clock` 注入（属于
// 更大重构，此次 spike 不展开）。如果未来仍出现 flake，再考虑：
// 1) 注入 `any Clock` 抽象；或 2) 使用 Swift Testing 的 `.tags(.flaky)`
// 在 CI 上单独标记 / 重试。当前实现的取舍：保持测试简洁，余量给足。

@Suite("ToastHost queue state machine")
@MainActor
struct ToastHostTests {

    @Test("空队列 show(...) 立即开始显示")
    func showOnEmptyStartsImmediately() async {
        let host = ToastHost()
        host.show("hi")
        #expect(host.queue.count == 1)
        #expect(host.queue.first?.message == "hi")
        #expect(host.isDismissing == false)
    }

    @Test("显示中 show(...) append 到队尾，不打断当前")
    func showWhileDisplayingAppends() async {
        let host = ToastHost()
        host.show("first", duration: 5)  // 长 duration 避免测试期间自动消失
        host.show("second")
        host.show("third")
        #expect(host.queue.count == 3)
        #expect(host.queue.first?.message == "first")
        #expect(host.queue.last?.message == "third")
        #expect(host.isDismissing == false)
    }

    @Test("dismiss(id:) 排队中的 item 直接移除")
    func dismissQueuedRemovesWithoutAffectingCurrent() async {
        let host = ToastHost()
        let a = ToastItem(message: "a", duration: 5)
        let b = ToastItem(message: "b", duration: 5)
        let c = ToastItem(message: "c", duration: 5)
        host.show(a)
        host.show(b)
        host.show(c)
        host.dismiss(b.id)
        #expect(host.queue.count == 2)
        #expect(host.queue.map(\.id) == [a.id, c.id])
        #expect(host.isDismissing == false)
    }

    @Test("dismiss(id:) 不存在的 id 是 no-op，不崩溃")
    func dismissUnknownIdIsNoop() async {
        let host = ToastHost()
        host.show("only", duration: 5)
        let countBefore = host.queue.count
        host.dismiss(UUID())  // 不存在
        #expect(host.queue.count == countBefore)
    }

    @Test("dismiss(id:) 正在显示的 item 进入 dismissing 状态")
    func dismissCurrentEntersDismissingState() async {
        let host = ToastHost()
        let a = ToastItem(message: "a", duration: 5)
        host.show(a)
        host.dismiss(a.id)
        #expect(host.isDismissing == true)
        // 等待动画完成 + advance；buffer 0.4s 容忍 CI 调度抖动
        try? await Task.sleep(for: .seconds(ToastDefaults.dismissAnimationDuration + 0.4))
        #expect(host.queue.isEmpty)
        #expect(host.isDismissing == false)
    }

    @Test("dismiss(id:) 重复触发不 double-fire")
    func repeatedDismissIsIdempotent() async {
        let host = ToastHost()
        let a = ToastItem(message: "a", duration: 5)
        host.show(a)
        host.dismiss(a.id)
        host.dismiss(a.id)  // 重复 — 应该 no-op（已 dismissing）
        host.dismiss(a.id)
        #expect(host.isDismissing == true)
        // buffer 0.4s 容忍 CI 调度抖动
        try? await Task.sleep(for: .seconds(ToastDefaults.dismissAnimationDuration + 0.4))
        #expect(host.queue.isEmpty)
        #expect(host.isDismissing == false)
    }

    @Test("自动 dismiss 后 advance 到下一条")
    func autoDismissAdvancesToNext() async {
        let host = ToastHost()
        let a = ToastItem(message: "a", duration: 0.05)
        let b = ToastItem(message: "b", duration: 5)
        host.show(a)
        host.show(b)
        // 等待 a 自动 dismiss + 动画 + advance 到 b；buffer 0.5s 容忍 CI 抖动
        try? await Task.sleep(for: .seconds(0.05 + ToastDefaults.dismissAnimationDuration + 0.5))
        #expect(host.queue.first?.message == "b")
        #expect(host.queue.count == 1)
        #expect(host.isDismissing == false)
    }

    @Test("duration 从 start of display 起算（不是 enqueue）")
    func durationCountsFromStartOfDisplay() async {
        let host = ToastHost()
        // 使用稍长的 duration（0.3s）拉开窗口，余量 buffer 给足，避免慢速 CI flake
        let a = ToastItem(message: "a", duration: 0.3)
        let b = ToastItem(message: "b", duration: 0.3)
        host.show(a)
        host.show(b)
        // 等待 0.1s：a 仍在显示（0.3s 还没到），b 在队尾等待
        try? await Task.sleep(for: .seconds(0.1))
        #expect(host.queue.first?.id == a.id)
        // 等到 a 完成自身 duration（剩余 0.2s）+ 动画 + advance 到 b
        try? await Task.sleep(for: .seconds(0.2 + ToastDefaults.dismissAnimationDuration + 0.3))
        // b 应该开始显示，且 b 的 duration 倒计时是从此刻起算（不是从最初 enqueue 起算）
        #expect(host.queue.first?.id == b.id)
        // 等 b 走完自身 duration + 动画；buffer 0.4s 给足
        try? await Task.sleep(for: .seconds(0.3 + ToastDefaults.dismissAnimationDuration + 0.4))
        #expect(host.queue.isEmpty)
    }
}
