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

    // MARK: - style 四件套（Issue #224）
    //
    // 本组测试此前只有一个 `plainStyleOptsOutOfGlass`，函数体末尾是 `_ = styled`
    // ——**纯编译检查、无任何运行时断言**，却顶着一个承诺行为（"opts out of glass"）
    // 的名字。#224 拆成两个各自诚实的测试。

    @MainActor
    @Test("style modifier 接得通——纯编译检查，不验证外观")
    func plainStyleModifierCompiles() {
        // ⚠️ **本测试只能做到这一步**：`.segmentedControlStyle(_:)` 返回 `some View`，
        // 四件套接通即编译通过。它**不验证** plain 是否真的没有玻璃——那个命题由下面
        // 的 `plainStyleTakesDifferentRenderPathThanGlass` 承担（且仅限 iOS）。
        // 名字如实反映能力边界，不再用 "opts out of glass" 这种承诺行为的措辞。
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
        // iOS 上 `GlassSegmentedControlStyle` 走 `NativeGlassSegmentedControl`
        // （UIKit `UISegmentedControl` 桥接），`PlainSegmentedControlStyle` 走
        // SwiftUI 回退路径——**两者 body 类型不同**，这是"plain 退出玻璃路径"
        // 在类型层面可观测的证据。
        //
        // ⚠️ 能做到的边界：`SwiftUISegmentedControl` 与
        // `SegmentedControlBackgroundModifier` 都是 `private`，`@testable` 也够不到，
        // 因此**无法直接断言 `glass == false`**。macOS 上两个 style 都回落到
        // `SwiftUISegmentedControl`（仅 `glass` 私有属性不同）、类型相同，故本测试
        // 限定 iOS。玻璃材质本身是否渲染出来，只有截图能回答（Issue #225）。
        let config = SegmentedControlStyleConfiguration(
            segments: [
                .init(index: 0, title: "A", isSelected: true),
                .init(index: 1, title: "B", isSelected: false),
            ],
            select: { _ in }
        )
        let glassBody = GlassSegmentedControlStyle().makeBody(configuration: config)
        let plainBody = PlainSegmentedControlStyle().makeBody(configuration: config)
        #expect(
            type(of: glassBody) != type(of: plainBody),
            "iOS 上两个 style 产出了同一 body 类型——plain 没有走独立的渲染路径"
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
