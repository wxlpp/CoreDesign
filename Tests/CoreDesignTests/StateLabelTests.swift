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
}
