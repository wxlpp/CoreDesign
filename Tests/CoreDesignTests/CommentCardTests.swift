import SwiftUI
import Testing
@testable import CoreDesign

@Suite("CommentCard")
struct CommentCardTests {
    @Test("init with required params, not minimized")
    func initNotMinimized() {
        let card = CommentCard(author: "evan", timestamp: "2h ago") {
            Text("Hello world")
        }
        #expect(card.author == "evan")
        #expect(card.role == nil)
        #expect(card.timestamp == "2h ago")
        #expect(card.isMinimized == nil)
    }

    @Test("init with role and minimized binding")
    func initWithRole() {
        let card = CommentCard(
            author: "bot",
            role: "Bot",
            timestamp: "1d ago",
            isMinimized: Binding.constant(true)
        ) {
            Text("auto-generated")
        }
        #expect(card.author == "bot")
        #expect(card.role == "Bot")
        #expect(card.isMinimized?.wrappedValue == true)
    }
}
