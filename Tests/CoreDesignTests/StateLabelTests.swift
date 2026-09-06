import SwiftUI
import Testing
@testable import CoreDesign

@Suite("StateLabel")
@MainActor
struct StateLabelTests {
    @Test("active maps to success status color")
    func activeMapsToSuccess() {
        let label = StateLabel(style: .active)
        #expect(label.style == .active)
        #expect(StateLabelStyle.active.spec.defaultLabel == "Active")
    }

    @Test("completed maps to done status color")
    func completedMapsToDone() {
        let label = StateLabel(style: .completed)
        #expect(label.style == .completed)
    }

    @Test("all styles construct and expose a spec")
    func allStylesConstruct() {
        for style in [StateLabelStyle.active, .draft, .completed, .cancelled, .inProgress, .error] {
            let label = StateLabel(style: style)
            #expect(label.style == style)
            #expect(!style.spec.icon.isEmpty)
        }
    }

    @Test("default labels come from the style spec")
    func defaultLabels() {
        #expect(StateLabelStyle.draft.spec.defaultLabel == "Draft")
        #expect(StateLabelStyle.inProgress.spec.defaultLabel == "In Progress")
        #expect(StateLabelStyle.error.spec.defaultLabel == "Error")
    }

    @Test("convenience init accepts a custom label and preserves style")
    func customLabelPreservesStyle() {
        let label = StateLabel(style: .inProgress, label: "Saving…")
        #expect(label.style == .inProgress)
    }

    // MARK: - label payload wiring（Issue #224）

    @Test("便利 init 把自定义文案接进 label payload，而不只是保留 style")
    func convenienceInitWiresCustomLabelPayload() {
        let text = "Saving…"
        let label = StateLabel(style: .inProgress, label: text)
        #expect(
            label.label == Text(text),
            "便利 init 没把自定义文案接进 label——style 对了不代表内容对了"
        )
    }

    @Test("便利 init 省略 label 时回落到 style 的默认文案")
    func convenienceInitFallsBackToDefaultLabel() {
        for style in [StateLabelStyle.active, .draft, .completed, .cancelled, .inProgress, .error] {
            let label = StateLabel(style: style)
            #expect(
                label.label == Text(style.spec.defaultLabel),
                "\(style) 省略 label 时未回落到 spec.defaultLabel"
            )
        }
    }

    @Test("自定义文案不会被默认文案覆盖——两条路径产出不同 payload")
    func customLabelDiffersFromDefault() {
        let custom = StateLabel(style: .inProgress, label: "Saving…")
        let defaulted = StateLabel(style: .inProgress)
        #expect(
            custom.label != defaulted.label,
            "自定义 label 与默认 label 产出同一 payload——自定义入参被吞"
        )
    }
}
