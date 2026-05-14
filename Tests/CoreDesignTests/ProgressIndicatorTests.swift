import SwiftUI
import Testing
@testable import CoreDesign

@Suite("ProgressIndicator")
@MainActor
struct ProgressIndicatorTests {
    @Test("init creates without runtime errors")
    func initCreatesInstance() {
        _ = ProgressIndicator()
    }
}
