import SwiftUI
import Testing
@testable import CoreDesign

@Suite("Sidebar components")
@MainActor
struct SidebarComponentsTests {
    @Test("sidebar section constructs with text content")
    func sidebarSectionConstructsWithTextContent() {
        let section = SidebarSection(title: "Core", showsChevron: false) {
            Text("Today")
        }

        #expect(type(of: section) == SidebarSection<Text>.self)
    }

    @Test("sidebar navigation row constructs selected")
    func sidebarNavigationRowConstructsSelected() {
        let row = SidebarNavigationRow(
            systemImage: "calendar",
            title: "Today",
            isSelected: true,
            action: {}
        )

        #expect(type(of: row) == SidebarNavigationRow<AnyView>.self)
    }

    @Test("sidebar utility row constructs with trailing image")
    func sidebarUtilityRowConstructsWithTrailingImage() {
        let row = SidebarUtilityRow(
            systemImage: "checkmark.circle",
            title: "Tasks",
            trailingSystemImage: "plus",
            action: {}
        )

        #expect(type(of: row) == SidebarUtilityRow.self)
    }

    @Test("sidebar document row constructs")
    func sidebarDocumentRowConstructs() {
        let row = SidebarDocumentRow(
            systemImage: "doc.text",
            title: "Exam Sprint",
            detail: "47 days",
            action: {}
        )

        #expect(type(of: row) == SidebarDocumentRow.self)
    }

    @Test("sidebar tag row constructs")
    func sidebarTagRowConstructs() {
        let row = SidebarTagRow(title: "Math", action: {})

        #expect(type(of: row) == SidebarTagRow.self)
    }

    @Test("sidebar footer constructs")
    func sidebarFooterConstructs() {
        let footer = SidebarStatusFooter(
            title: "Local first",
            detail: "Read-only sync"
        )

        #expect(type(of: footer) == SidebarStatusFooter.self)
    }
}
