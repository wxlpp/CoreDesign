import SwiftUI
import Testing
@testable import CoreDesign

@Suite("EmptyState deprecation")
struct EmptyStateDeprecationTests {
    @MainActor
    @Test("deprecated empty state remains constructible during compatibility window")
    func deprecatedEmptyStateRemainsConstructible() {
        let view = EmptyState(systemName: "tray", title: "No items")
        #expect(String(describing: type(of: view)).isEmpty == false)
    }
}
