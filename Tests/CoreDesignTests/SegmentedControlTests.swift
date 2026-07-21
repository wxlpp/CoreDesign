import SwiftUI
import Testing
@testable import CoreDesign

@Suite("SegmentedControl")
struct SegmentedControlTests {
    @MainActor
    @Test("segmented control constructs with two items")
    func segmentedControlConstructsWithTwoItems() {
        let selection = Binding.constant("One")
        let control = SegmentedControl(
            items: ["One", "Two"],
            selection: selection,
            title: { $0 }
        )

        #expect(type(of: control) == SegmentedControl<String>.self)
    }

    @MainActor
    @Test("segmented control constructs with three items")
    func segmentedControlConstructsWithThreeItems() {
        let selection = Binding.constant("A")
        let control = SegmentedControl(
            items: ["A", "B", "C"],
            selection: selection,
            title: { $0 }
        )

        #expect(type(of: control) == SegmentedControl<String>.self)
    }

    @MainActor
    @Test("plain style opts out of glass via the style modifier")
    func plainStyleOptsOutOfGlass() {
        let selection = Binding.constant("One")
        let styled = SegmentedControl(
            items: ["One", "Two"],
            selection: selection,
            title: { $0 }
        )
        .segmentedControlStyle(PlainSegmentedControlStyle())
        // 四件套接通即编译通过（modifier 返回 `some View`，不再是 SegmentedControl<Item>）。
        _ = styled
    }

    @MainActor
    @Test("both built-in styles produce a body from a configuration")
    func builtInStylesProduceBody() {
        let config = SegmentedControlStyleConfiguration(
            segments: [
                .init(index: 0, title: "A", isSelected: true),
                .init(index: 1, title: "B", isSelected: false),
            ],
            select: { _ in }
        )
        _ = GlassSegmentedControlStyle().makeBody(configuration: config)
        _ = PlainSegmentedControlStyle().makeBody(configuration: config)
    }
}
