import SwiftUI
import Testing
@testable import CoreDesign

@Suite("StatusRow")
struct StatusRowTests {
    @Test("init stores parameters")
    func initParams() {
        let row = StatusRow(label: "build (arm64)", duration: "2m 14s", result: .success)
        #expect(row.label == "build (arm64)")
        #expect(row.duration == "2m 14s")
        #expect(row.result == .success)
    }

    @Test("all result cases construct")
    func allResults() {
        for result in [StatusResult.success, .failure, .pending, .skipped] {
            let row = StatusRow(label: "test", duration: "0s", result: result)
            #expect(row.result == result)
        }
    }
}
