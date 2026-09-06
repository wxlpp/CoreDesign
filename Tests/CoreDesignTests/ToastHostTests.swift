import Testing
import Foundation
@testable import CoreDesign

// MARK: - ToastHost state machine tests

@Suite("ToastHost queue state machine", .serialized)
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
        host.show("first", duration: 5)
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
        host.dismiss(UUID())
        #expect(host.queue.count == countBefore)
    }

    @Test("dismiss(id:) 正在显示的 item 进入 dismissing 状态")
    func dismissCurrentEntersDismissingState() async {
        let host = ToastHost()
        let a = ToastItem(message: "a", duration: 5)
        host.show(a)
        host.dismiss(a.id)
        #expect(host.isDismissing == true)
        try? await Task.sleep(for: .seconds(ToastDefaults.dismissAnimationDuration + 1.0))
        #expect(host.queue.isEmpty)
        #expect(host.isDismissing == false)
    }

    @Test("dismiss(id:) 重复触发不 double-fire")
    func repeatedDismissIsIdempotent() async {
        let host = ToastHost()
        let a = ToastItem(message: "a", duration: 5)
        host.show(a)
        host.dismiss(a.id)
        host.dismiss(a.id)
        host.dismiss(a.id)
        #expect(host.isDismissing == true)
        try? await Task.sleep(for: .seconds(ToastDefaults.dismissAnimationDuration + 1.0))
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
        try? await Task.sleep(for: .seconds(0.05 + ToastDefaults.dismissAnimationDuration + 1.2))
        #expect(host.queue.first?.message == "b")
        #expect(host.queue.count == 1)
        #expect(host.isDismissing == false)
    }

    @Test("duration 从 start of display 起算（不是 enqueue）")
    func durationCountsFromStartOfDisplay() async {
        let host = ToastHost()
        let a = ToastItem(message: "a", duration: 0.3)
        let b = ToastItem(message: "b", duration: 2.0)
        host.show(a)
        host.show(b)
        try? await Task.sleep(for: .seconds(0.1))
        #expect(host.queue.first?.id == a.id)
        try? await Task.sleep(for: .seconds(0.2 + ToastDefaults.dismissAnimationDuration + 0.6))
        #expect(host.queue.first?.id == b.id)
        try? await Task.sleep(for: .seconds(1.55 + ToastDefaults.dismissAnimationDuration + 0.8))
        #expect(host.queue.isEmpty)
    }
}
