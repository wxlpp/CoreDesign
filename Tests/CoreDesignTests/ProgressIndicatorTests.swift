import SwiftUI
import Testing
@testable import CoreDesign

@Suite("ProgressIndicator")
struct ProgressIndicatorTests {
    @Test("init creates without runtime errors")
    func initCreatesInstance() {
        let indicator = ProgressIndicator()
        #expect(indicator != nil)
    }
}
