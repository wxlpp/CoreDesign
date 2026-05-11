import SwiftUI
import Testing
@testable import CoreDesign

@Suite("EventRow")
struct EventRowTests {
    @Test("init stores parameters with pill content")
    func initWithPill() {
        let row = EventRow(actor: "renovate", action: "force-pushed from", timeAgo: "2d") {
            Text("abc")
        }
        #expect(row.actor == "renovate")
        #expect(row.action == "force-pushed from")
        #expect(row.timeAgo == "2d")
    }

    @Test("init stores parameters without pill")
    func initWithoutPill() {
        let row = EventRow(actor: "evan", action: "commented", timeAgo: "1h") {
            EmptyView()
        }
        #expect(row.actor == "evan")
        #expect(row.action == "commented")
    }
}
