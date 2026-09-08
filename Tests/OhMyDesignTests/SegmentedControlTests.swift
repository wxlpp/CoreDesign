import SwiftUI
import Testing
@testable import OhMyDesign

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

    // MARK: - style 四件套（Issue #224）

    @MainActor
    @Test("style modifier 接得通——纯编译检查，不验证外观")
    func plainStyleModifierCompiles() {
        let selection = Binding.constant("One")
        let styled = SegmentedControl(
            items: ["One", "Two"],
            selection: selection,
            title: { $0 }
        )
        .segmentedControlStyle(PlainSegmentedControlStyle())
        _ = styled
    }

    #if os(iOS)
    @MainActor
    @Test("iOS：plain 与 glass 走不同的渲染路径（body 类型不同）")
    func plainStyleTakesDifferentRenderPathThanGlass() {
        let config = SegmentedControlStyleConfiguration(
            segments: [
                .init(index: 0, title: "A", isSelected: true),
                .init(index: 1, title: "B", isSelected: false),
            ],
            select: { _ in }
        )
        let glassBody = GlassSegmentedControlStyle().makeBody(configuration: config)
        let plainBody = PlainSegmentedControlStyle().makeBody(configuration: config)
        let glassType = String(describing: type(of: glassBody))
        let plainType = String(describing: type(of: plainBody))
        #expect(
            glassType.contains("NativeGlassSegmentedControl"),
            "glass style 的 body 不含 UIKit 桥接类型——渲染路径变了：\(glassType)"
        )
        #expect(
            !plainType.contains("NativeGlassSegmentedControl"),
            "plain style 的 body 含 UIKit 桥接类型——它没有退出玻璃路径：\(plainType)"
        )
    }
    #endif

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
