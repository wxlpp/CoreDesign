import SwiftUI
import Testing
@testable import CoreDesign

@Suite("Tag")
struct TagTests {
    @MainActor
    @Test("tag constructs with text and color")
    func tagConstructsWithTextAndColor() {
        let tag = Tag("bug", color: .red)
        #expect(type(of: tag) == Tag<Text>.self)
    }

    @MainActor
    @Test("removable tag constructs without crash")
    func removableTagConstructs() {
        let tag = Tag("wontfix", color: .gray, removable: true) {}
        #expect(type(of: tag) == Tag<Text>.self)
    }
}
