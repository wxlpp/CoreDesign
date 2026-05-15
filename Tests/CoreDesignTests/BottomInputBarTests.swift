import SwiftUI
import Testing
@testable import CoreDesign

@Suite("BottomInputBar")
struct BottomInputBarTests {
    @MainActor
    @Test("bottom input bar constructs with defaults")
    func bottomInputBarConstructsWithDefaults() {
        let bar = BottomInputBar(
            isShowingSuggestions: .constant(false),
            onSubmit: { _ in }
        )

        #expect(type(of: bar) == BottomInputBar.self)
    }

    @MainActor
    @Test("bottom input bar constructs with placeholder and run state")
    func bottomInputBarConstructsWithPlaceholderAndRunState() {
        let bar = BottomInputBar(
            isShowingSuggestions: .constant(true),
            placeholder: "Type a message",
            isRunning: true,
            onSubmit: { _ in }
        )

        #expect(type(of: bar) == BottomInputBar.self)
    }
}
