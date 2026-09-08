import SwiftUI
import Testing
@testable import OhMyDesign

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

    @Test("SidebarUtilityRow：presentation 默认 .iconLeading（行为兼容）")
    func sidebarUtilityRowDefaultsToIconLeading() {
        let row = SidebarUtilityRow(systemImage: "gearshape", title: "Settings") {}
        #expect(row.presentation == .iconLeading)
    }

    @Test("SidebarUtilityRow：.textOnly 下 systemImage 仍原样保留（不生效 ≠ 被改写）")
    func sidebarUtilityRowKeepsSystemImageInTextOnly() {
        let row = SidebarUtilityRow(
            systemImage: "gearshape",
            title: "Settings",
            trailingSystemImage: "chevron.forward",
            presentation: .textOnly
        ) {}
        #expect(row.systemImage == "gearshape", ".textOnly 下 systemImage 仍应原样保留")
        #expect(row.trailingSystemImage == "chevron.forward")
        #expect(row.presentation == .textOnly)
    }

    @Test("SidebarUtilityRowPresentation：两个 case 可区分（Equatable 非退化）")
    func sidebarUtilityRowPresentationEquatableIsNotDegenerate() {
        #expect(SidebarUtilityRowPresentation.iconLeading != SidebarUtilityRowPresentation.textOnly)
        #expect(SidebarUtilityRowPresentation.textOnly == SidebarUtilityRowPresentation.textOnly)
    }

    @MainActor
    @Test("SidebarUtilityRow：两种 presentation 的 body 均可求值")
    func sidebarUtilityRowAllPresentationsRender() {
        for presentation in [SidebarUtilityRowPresentation.iconLeading, .textOnly] {
            let row = SidebarUtilityRow(
                systemImage: "gearshape", title: "Settings", presentation: presentation
            ) {}
            _ = row.body
        }
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
