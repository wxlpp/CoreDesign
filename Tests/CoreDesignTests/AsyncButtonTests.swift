import SwiftUI
import Testing
@testable import CoreDesign

@Suite("AsyncButton")
@MainActor
struct AsyncButtonTests {

    @Test("非抛错 init 能正常构造")
    func nonThrowingInitCompiles() {
        _ = AsyncButton(action: { }) {
            Text("Tap")
        }
    }

    @Test("wrapThrowingAction:业务错误透传给 onError")
    func wrapBusinessErrorCallsOnError() async {
        struct DemoError: Error, Equatable {
            let code: Int
        }

        var captured: Error?
        let wrapped = AsyncButton<Text>._wrapThrowingAction(
            { throw DemoError(code: 42) },
            onError: { captured = $0 }
        )

        await wrapped()

        #expect((captured as? DemoError) == DemoError(code: 42))
    }

    @Test("wrapThrowingAction:CancellationError 被静默吞下,不调 onError")
    func wrapCancellationErrorSilent() async {
        var called = false
        let wrapped = AsyncButton<Text>._wrapThrowingAction(
            { throw CancellationError() },
            onError: { _ in called = true }
        )

        await wrapped()

        #expect(called == false)
    }

    @Test("wrapThrowingAction:onError 为 nil 时业务错误被静默,不崩溃")
    func wrapNilOnErrorIsSilent() async {
        struct DemoError: Error {}
        let wrapped = AsyncButton<Text>._wrapThrowingAction(
            { throw DemoError() },
            onError: nil
        )

        await wrapped()  // 不应崩溃
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
        struct DemoError: Error {}
        _ = AsyncButton("Submit",
                        action: { throw DemoError() },
                        onError: { _ in })
        let title: String = "Submit"
        _ = AsyncButton(title,
                        action: { throw DemoError() },
                        onError: { _ in })
        // onError 省略
        _ = AsyncButton("Submit", action: { throw DemoError() })
    }
}
