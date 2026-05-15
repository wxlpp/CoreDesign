import SwiftUI
import Testing
@testable import CoreDesign

@Suite("Avatar")
@MainActor
struct AvatarTests {
    @Test("avatar constructs with name")
    func avatarConstructsWithName() {
        let avatar = Avatar(name: "Alice")
        #expect(avatar.name == "Alice")
    }

    @Test("avatar constructs with different name")
    func avatarConstructsWithDifferentName() {
        let avatar = Avatar(name: "Bob")
        #expect(avatar.name == "Bob")
    }
}
