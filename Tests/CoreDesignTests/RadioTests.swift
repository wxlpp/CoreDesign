import SwiftUI
import Testing
@testable import CoreDesign

/// 文件作用域声明 / File-scope declaration：`Hashable` 合成的 conformance 需要
/// `nonisolated`（本包 `.defaultIsolation(MainActor.self)`），否则局部 enum
/// 的 conformance 会被推断为 MainActor-isolated，无法满足
/// `RadioOption<SelectionValue: Hashable & Sendable>` 的 `Sendable` 约束。
nonisolated enum RadioTestPlan: Hashable, Sendable {
    case basic, pro, enterprise
}

@Suite("Radio")
struct RadioTests {
    // MARK: - RadioOption.id

    @Test("RadioOption.id equals value (Identifiable contract)")
    func radioOptionIdEqualsValue() {
        let option = RadioOption(value: "basic", title: "基础版")
        #expect(option.id == "basic")
        #expect(option.id == option.value)
    }

    @Test("RadioOption.id equals value for Int-backed selection")
    func radioOptionIdEqualsValueForInt() {
        let option = RadioOption(value: 42, title: "forty-two")
        #expect(option.id == 42)
    }

    // MARK: - RadioGroup.isSelected (pure function)

    @Test("isSelected returns true when option matches current selection")
    func isSelectedMatchesCurrentSelection() {
        let option = RadioOption(value: "pro", title: "专业版")
        #expect(RadioGroup.isSelected(option, in: "pro"))
    }

    @Test("isSelected returns false when option does not match current selection")
    func isSelectedDoesNotMatchOtherSelection() {
        let option = RadioOption(value: "pro", title: "专业版")
        #expect(!RadioGroup.isSelected(option, in: "basic"))
    }

    @Test(
        "isSelected across multiple option/selection pairs",
        arguments: [
            (option: 1, selection: 1, expected: true),
            (option: 1, selection: 2, expected: false),
            (option: 2, selection: 2, expected: true),
            (option: 3, selection: 1, expected: false),
        ]
    )
    func isSelectedAcrossInputs(option: Int, selection: Int, expected: Bool) {
        let radioOption = RadioOption(value: option, title: "\(option)")
        #expect(RadioGroup.isSelected(radioOption, in: selection) == expected)
    }

    @Test("isSelected works with an enum-backed SelectionValue")
    func isSelectedWithEnumSelection() {
        let proOption = RadioOption(value: RadioTestPlan.pro, title: "Pro")
        #expect(RadioGroup.isSelected(proOption, in: .pro))
        #expect(!RadioGroup.isSelected(proOption, in: .basic))
        #expect(!RadioGroup.isSelected(proOption, in: .enterprise))
    }

    // MARK: - RadioGroup construction (rendering smoke check)

    @MainActor
    @Test("RadioGroup constructs with vertical axis (default)")
    func radioGroupConstructsVertical() {
        let group = RadioGroup(
            selection: .constant("basic"),
            options: [
                RadioOption(value: "basic", title: "基础版"),
                RadioOption(value: "pro", title: "专业版"),
            ]
        )
        #expect(type(of: group) == RadioGroup<String>.self)
    }

    @MainActor
    @Test("RadioGroup constructs with horizontal axis")
    func radioGroupConstructsHorizontal() {
        let group = RadioGroup(
            selection: .constant(1),
            options: [
                RadioOption(value: 1, title: "小"),
                RadioOption(value: 2, title: "中"),
                RadioOption(value: 3, title: "大"),
            ],
            axis: .horizontal
        )
        #expect(type(of: group) == RadioGroup<Int>.self)
    }
}
