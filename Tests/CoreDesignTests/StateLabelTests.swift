import SwiftUI
import Testing
@testable import CoreDesign

@Suite("StateLabel")
@MainActor
struct StateLabelTests {
    @Test("active maps to success status color")
    func activeMapsToSuccess() {
        let label = StateLabel(.active)
        #expect(label.style == .active)
        #expect(label.label == "Active")
    }

    @Test("completed maps to done status color")
    func completedMapsToDone() {
        let label = StateLabel(.completed)
        #expect(label.style == .completed)
    }

    @Test("custom label overrides default")
    func customLabel() {
        let label = StateLabel(.draft, label: "WIP")
        #expect(label.label == "WIP")
    }

    @Test("all styles construct")
    func allStylesConstruct() {
        for style in [StateLabelStyle.active, .draft, .completed, .cancelled, .inProgress, .error] {
            let label = StateLabel(style)
            #expect(label.style == style)
        }
    }

    @Test("inProgress default label is In Progress")
    func inProgressDefaultLabel() {
        let label = StateLabel(.inProgress)
        #expect(label.label == "In Progress")
    }

    @Test("error default label is Error")
    func errorDefaultLabel() {
        let label = StateLabel(.error)
        #expect(label.label == "Error")
    }

    @Test("inProgress accepts custom label (e.g. Saving…)")
    func inProgressCustomLabel() {
        let label = StateLabel(.inProgress, label: "Saving…")
        #expect(label.label == "Saving…")
    }
}
