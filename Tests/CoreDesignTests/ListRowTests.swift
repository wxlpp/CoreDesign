import SwiftUI
import Testing
@testable import CoreDesign

@Suite("ListRow")
struct ListRowTests {
    @MainActor
    @Test("list row constructs with label only")
    func listRowConstructsWithLabelOnly() {
        let row = ListRow(label: { Text("Item") })
        #expect(type(of: row) == ListRow<EmptyView, EmptyView, Text>.self)
    }

    @MainActor
    @Test("list row constructs with leading and trailing")
    func listRowConstructsWithLeadingAndTrailing() {
        let row = ListRow(
            leading: { Image(systemName: "doc") },
            label: { Text("Item") },
            trailing: { Text(">") }
        )
        #expect(type(of: row) == ListRow<Image, Text, Text>.self)
    }
}
