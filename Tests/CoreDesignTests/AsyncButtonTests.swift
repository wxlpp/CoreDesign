import SwiftUI
import Testing
@testable import CoreDesign

@Suite("AsyncButton")
@MainActor
struct AsyncButtonTests {

    private struct DemoError: Error, Equatable {
        let code: Int
    }

    @Test("非抛错 init 能正常构造")
    func nonThrowingInitCompiles() {
        _ = AsyncButton(action: { }) {
            Text("Tap")
        }
    }

    @Test("_runThrowing:业务错误透传给 onError(不弹 toast)")
    func runThrowingBusinessErrorCallsOnError() async {
        let host = ToastHost()
        var captured: Error?

        await AsyncButton<Text>._runThrowing(
            { throw DemoError(code: 42) },
            onError: { captured = $0 },
            toastHost: host
        )

        #expect((captured as? DemoError) == DemoError(code: 42))
        #expect(host.queue.isEmpty, "onError 命中时不应再弹 toast")
    }

    @Test("_runThrowing:onError nil + toastHost 存在 → 自动弹 .danger toast")
    func runThrowingFallsBackToToast() async {
        let host = ToastHost()

        await AsyncButton<Text>._runThrowing(
            {
                struct AutoToastError: LocalizedError {
                    var errorDescription: String? { "Demo failure" }
                }
                throw AutoToastError()
            },
            onError: nil,
            toastHost: host
        )

        #expect(host.queue.count == 1)
        #expect(host.queue.first?.level == .danger)
        #expect(host.queue.first?.message == "Demo failure")
    }

    @Test("_runThrowing:onError nil + toastHost nil → 静默,不崩")
    func runThrowingSilentWithoutHandlers() async {
        await AsyncButton<Text>._runThrowing(
            { throw DemoError(code: 1) },
            onError: nil,
            toastHost: nil
        )
        // 不应崩溃,无可观测副作用
    }

    @Test("_runThrowing:CancellationError 静默 — 不调 onError、不弹 toast")
    func runThrowingCancellationSilent() async {
        let host = ToastHost()
        var onErrorCalled = false

        await AsyncButton<Text>._runThrowing(
            { throw CancellationError() },
            onError: { _ in onErrorCalled = true },
            toastHost: host
        )

        #expect(onErrorCalled == false)
        #expect(host.queue.isEmpty)
    }

    @Test("重载解析:非抛错文本 init 编译")
    func nonThrowingTextInitsCompile() {
        // LocalizedStringKey 重载
        _ = AsyncButton("Submit", action: { })
        // StringProtocol 重载
        let title: String = "Submit"
        _ = AsyncButton(title, action: { })
        // trailing closure 形态(项目主流调用方式)——必须解析到非抛错重载
        _ = AsyncButton("Submit") { }
    }

    @Test("重载解析:抛错文本 init 编译")
    func throwingTextInitsCompile() {
        _ = AsyncButton("Submit",
                        action: { throw DemoError(code: 1) },
                        onError: { _ in })
        let title: String = "Submit"
        _ = AsyncButton(title,
                        action: { throw DemoError(code: 1) },
                        onError: { _ in })
        // onError 省略 → 走 toast / silent fallback
        _ = AsyncButton("Submit", action: { throw DemoError(code: 1) })
    }
}
