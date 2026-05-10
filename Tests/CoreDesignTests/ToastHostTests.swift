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
// 使用 short duration（0.05–0.2 秒）保证测试快速完成；不测视图层渲染。

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
        // 等待动画完成 + advance
        try? await Task.sleep(for: .seconds(ToastDefaults.dismissAnimationDuration + 0.1))
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
        try? await Task.sleep(for: .seconds(ToastDefaults.dismissAnimationDuration + 0.1))
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
        // 等待 a 自动 dismiss + 动画 + advance 到 b
        try? await Task.sleep(for: .seconds(0.05 + ToastDefaults.dismissAnimationDuration + 0.15))
        #expect(host.queue.first?.message == "b")
        #expect(host.queue.count == 1)
        #expect(host.isDismissing == false)
    }

    @Test("duration 从 start of display 起算（不是 enqueue）")
    func durationCountsFromStartOfDisplay() async {
        let host = ToastHost()
        let a = ToastItem(message: "a", duration: 0.2)
        let b = ToastItem(message: "b", duration: 0.2)
        host.show(a)
        host.show(b)
        // 等待 0.1s：a 仍在显示（0.2s 还没到），b 在队尾等待
        try? await Task.sleep(for: .seconds(0.1))
        #expect(host.queue.first?.id == a.id)
        // 等到 a 完成 dismiss 动画 + b 开始 sleep 倒计时
        try? await Task.sleep(for: .seconds(0.15 + ToastDefaults.dismissAnimationDuration))
        // b 应该开始显示，且 b 的 duration 倒计时是从此刻起算（不是从最初 enqueue 起算）
        #expect(host.queue.first?.id == b.id)
        // 等 b 走完自身 duration + 动画
        try? await Task.sleep(for: .seconds(0.2 + ToastDefaults.dismissAnimationDuration + 0.05))
        #expect(host.queue.isEmpty)
    }
}
