import Testing
@testable import CoreDesign

@Suite("Button style defaults")
@MainActor
struct ButtonStyleDefaultTests {
    @Test("solid button style defaults to non-glass")
    func solidDefaultsToNonGlass() {
        let style = SolidButtonStyle()
        #expect(style.glass == false)
    }

    @Test("light button style defaults to non-glass")
    func lightDefaultsToNonGlass() {
        let style = LightButtonStyle()
        #expect(style.glass == false)
    }

    @Test("explicit glass remains available")
    func explicitGlassRemainsAvailable() {
        #expect(SolidButtonStyle(glass: true).glass == true)
        #expect(LightButtonStyle(glass: true).glass == true)
    }
}
