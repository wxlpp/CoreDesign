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
// 时序余量 / Timing buffers（R1 fix；Phase 3 / #173 二次放宽）：
// 这些测试依赖 `Task.sleep` 真实墙钟时间，余量 buffer 最初取 0.3–0.5 秒；
// #173 收口时在 iOS Simulator 腿实测复现 3 个用例的偶发 flake（`xcodebuild test`
// 整套 suite 并跑时的调度抖动足以吃掉 0.4–0.5s 余量），故放宽到 0.8–1.2 秒。
// **不**引入 `Clock` 注入（属于更大重构，此次不展开）。如果未来仍出现 flake，
// 再考虑：1) 注入 `any Clock` 抽象；或 2) 使用 Swift Testing 的 `.tags(.flaky)`
// 在 CI 上单独标记 / 重试。当前实现的取舍：保持测试简洁，余量给足。

// `.serialized`（Phase 3 / #173 flake 修复）：这个 suite 里多条测试各自跑真实
// `Task.sleep` 计时器。Swift Testing 默认并行调度整个测试进程里的全部 suite/test——
// 当本 suite 与其它上百个测试同时抢占同一个（模拟器沙盒里通常单核可用的）调度器时，
// 即便单条测试内部的 buffer 放宽到 0.8–1.2s，也可能被并发抢占的调度延迟整体吃掉
// （实测：不加 `.serialized` 时，`autoDismissAdvancesToNext` /
// `durationCountsFromStartOfDisplay` 在 `xcodebuild test` 整套 suite 并跑时仍偶发
// 超时失败，即使 buffer 已放宽）。`.serialized` 让本 suite 内的测试排队执行、不与
// 彼此的计时器竞争 CPU，是比继续加大 buffer 更对症的修复。
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
        // 等待动画完成 + advance；buffer 1.0s（Phase 3 / #173：0.4s 在 iOS Simulator
        // 腿实测偶发不够——xcodebuild 并跑全量 suite 时调度抖动可能超过 0.4s，放宽到
        // 1.0s 给足余量）。
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
        host.dismiss(a.id)  // 重复 — 应该 no-op（已 dismissing）
        host.dismiss(a.id)
        #expect(host.isDismissing == true)
        // buffer 1.0s（Phase 3 / #173：与上一测试同一放宽理由）
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
        // 等待 a 自动 dismiss + 动画 + advance 到 b；buffer 1.2s（Phase 3 / #173 放宽，
        // 理由同上——实测 0.5s 在整套 suite 并跑时偶发不够）
        try? await Task.sleep(for: .seconds(0.05 + ToastDefaults.dismissAnimationDuration + 1.2))
        #expect(host.queue.first?.message == "b")
        #expect(host.queue.count == 1)
        #expect(host.isDismissing == false)
    }

    @Test("duration 从 start of display 起算（不是 enqueue）")
    func durationCountsFromStartOfDisplay() async {
        let host = ToastHost()
        // Phase 3 / #173 修复：`b` 原来也用 0.3s——中段检查点必须落在
        // 「b 开始显示」与「b 自身 duration 到期」之间的窗口内，而 a=b=0.3s 时这个
        // 窗口只有 ~0.3s 宽（[0.55, 0.85]），逼着 buffer 只能取一个极窄的「刚好够」
        // 的值（原 0.3s，处在边界上）。R1 fix 之后本文件把 buffer 普遍放宽到
        // 0.8–1.2s——但对这条测试，放宽后的 buffer 反而会**越过窗口上界**，让检查点
        // 落在 b 已经自行 dismiss 完毕之后（实测复现：`host.queue.first?.id == nil`，
        // 不是「还没到」，而是「已经没了」）。真正的修复是把 `b` 的 duration 从
        // 0.3s 放宽到 2s，把窗口从 ~0.3s 拉宽到 ~2s，让检查点有充足容错空间，
        // 而不是继续在窄窗口里精调 buffer 数值。
        let a = ToastItem(message: "a", duration: 0.3)
        let b = ToastItem(message: "b", duration: 2.0)
        host.show(a)
        host.show(b)
        // 等待 0.1s：a 仍在显示（0.3s 还没到），b 在队尾等待
        try? await Task.sleep(for: .seconds(0.1))
        #expect(host.queue.first?.id == a.id)
        // 等到 a 完成自身 duration（剩余 0.2s）+ 动画 + 0.6s buffer，落在 b 开始显示
        // （约 t=0.55s）之后、b 自身到期（约 t=2.55s）之前的宽窗口中段（约 t=1.0s）。
        try? await Task.sleep(for: .seconds(0.2 + ToastDefaults.dismissAnimationDuration + 0.6))
        // b 应该开始显示，且 b 的 duration 倒计时是从此刻起算（不是从最初 enqueue 起算）
        #expect(host.queue.first?.id == b.id)
        // 等 b 走完自身剩余 duration（约 1.55s，从上一检查点 t≈1.0s 算到 t≈2.55s）
        // + 动画 + 0.8s buffer，确认最终 dismiss。
        try? await Task.sleep(for: .seconds(1.55 + ToastDefaults.dismissAnimationDuration + 0.8))
        #expect(host.queue.isEmpty)
    }
}
