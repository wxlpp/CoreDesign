import SwiftUI
import Testing
@testable import CoreDesign

@Suite("AsyncButton")
@MainActor
struct AsyncButtonTests {

    @Test("非抛错 init 能正常构造")
    func nonThrowingInitCompiles() {
        _ = AsyncButton(action: { }) {
            Text("Tap")
        }
    }
}
