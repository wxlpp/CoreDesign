import CoreGraphics
import Testing
@testable import CoreDesign

@Suite("BookCover")
struct BookCoverTests {
    @Test("placeholder renderer accepts an explicit display scale")
    @MainActor
    func placeholderRendererAcceptsExplicitDisplayScale() {
        let data = BookCoverRenderer.generatePlaceholderData(
            title: "Test Book",
            width: 96,
            displayScale: 1
        )

        #expect(data != nil)
    }
}
