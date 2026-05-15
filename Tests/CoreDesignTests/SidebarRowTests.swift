import SwiftUI
import Testing
@testable import CoreDesign

@Suite("SidebarRow")
@MainActor
struct SidebarRowTests {
    @Test("sidebar row constructs unselected")
    func sidebarRowConstructsUnselected() {
        let row = SidebarRow(isSelected: false) {
            Text("Inbox")
        }
        #expect(type(of: row) == SidebarRow<Text>.self)
    }

    @Test("sidebar row constructs selected")
    func sidebarRowConstructsSelected() {
        let row = SidebarRow(isSelected: true) {
            Text("Inbox")
        }
        #expect(type(of: row) == SidebarRow<Text>.self)
    }
}
