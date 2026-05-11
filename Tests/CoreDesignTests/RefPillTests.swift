import SwiftUI
import Testing
@testable import CoreDesign

@Suite("RefPill")
struct RefPillTests {
    @Test("single ref stores value")
    func singleRef() {
        let pill = RefPill("main")
        #expect(pill.singleRef == "main")
        #expect(pill.base == nil)
        #expect(pill.head == nil)
    }

    @Test("base-head ref stores both values")
    func baseHeadRef() {
        let pill = RefPill(base: "main", head: "feat/foo")
        #expect(pill.base == "main")
        #expect(pill.head == "feat/foo")
        #expect(pill.singleRef == nil)
    }
}
