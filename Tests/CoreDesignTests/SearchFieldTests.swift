import SwiftUI
import Testing
@testable import CoreDesign

@Suite("SearchField")
struct SearchFieldTests {
    @MainActor
    @Test("search field constructs with default placeholder")
    func searchFieldConstructsWithDefaultPlaceholder() {
        let field = SearchField(text: .constant(""))
        #expect(type(of: field) == SearchField.self)
    }

    @MainActor
    @Test("search field constructs with submit handler")
    func searchFieldConstructsWithSubmitHandler() {
        let field = SearchField(text: .constant("query"), placeholder: "Filter") { _ in }

        #expect(type(of: field) == SearchField.self)
    }
}
