import SwiftUI
import Testing
@testable import CoreDesign

@Suite("UnderlinedTabBar")
struct UnderlinedTabBarTests {
    @MainActor
    @Test("tab bar constructs with two items")
    func tabBarConstructsWithTwoItems() {
        let selection = Binding.constant("A")
        let bar = UnderlinedTabBar(
            items: ["A", "B"],
            selection: selection,
            title: { $0 }
        )

        #expect(type(of: bar) == UnderlinedTabBar<String, EmptyView>.self)
    }

    @MainActor
    @Test("tab bar constructs with three items")
    func tabBarConstructsWithThreeItems() {
        let selection = Binding.constant("Issues")
        let bar = UnderlinedTabBar(
            items: ["Issues", "PRs", "Discussions"],
            selection: selection,
            title: { $0 }
        )

        #expect(type(of: bar) == UnderlinedTabBar<String, EmptyView>.self)
    }
}
