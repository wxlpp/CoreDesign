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

    @Test("button style factories default to non-glass")
    func buttonStyleFactoriesDefaultToNonGlass() {
        let solid: SolidButtonStyle = .solid()
        let light: LightButtonStyle = .light()

        #expect(solid.glass == false)
        #expect(light.glass == false)
    }

    // MARK: - CircularGlassButtonStyle 的档位默认值（Issue #96 / B3e）

    @Test("circular glass defaults to the large tier, not an explicit diameter")
    func circularGlassDefaultsToLargeTier() {
        let style = CircularGlassButtonStyle()
        #expect(style.size == .large)
        #expect(style.diameter == nil)
    }

    @Test("explicit diameter overrides the tier")
    func explicitDiameterOverridesTier() {
        // `.circularGlass(diameter:)` 是逃生舱：绕过 `size` 直接给值。
        let style: CircularGlassButtonStyle = .circularGlass(diameter: 44)
        #expect(style.diameter == 44)
    }

    @Test("circular glass tier accessor keeps the requested tier")
    func circularGlassTierAccessor() {
        let style: CircularGlassButtonStyle = .circularGlass(size: .small)
        #expect(style.size == .small)
        #expect(style.diameter == nil)
    }
}

// MARK: - ButtonRoleStyleRole.resolvedColor（Issue #96 / B3a）

@Suite("ButtonRoleStyleRole 三态取色")
struct ButtonRoleStyleRoleTests {
    @Test("disabled 优先于 pressed")
    func disabledWinsOverPressed() {
        let role = ButtonRoleStyleRole.primary
        #expect(role.resolvedColor(isEnabled: false, isPressed: true) == role.disabledColor)
        #expect(role.resolvedColor(isEnabled: false, isPressed: false) == role.disabledColor)
    }

    @Test("enabled 时按 pressed 分流")
    func enabledSplitsOnPressed() {
        let role = ButtonRoleStyleRole.danger
        #expect(role.resolvedColor(isEnabled: true, isPressed: true) == role.activeColor)
        #expect(role.resolvedColor(isEnabled: true, isPressed: false) == role.color)
    }

    @Test("每个 role 的三态都取自本 role 的调色板")
    func everyRoleUsesItsOwnPalette() {
        for role in [ButtonRoleStyleRole.primary, .secondary, .tertiary, .warning, .danger] {
            #expect(role.resolvedColor(isEnabled: true, isPressed: false) == role.color)
            #expect(role.resolvedColor(isEnabled: true, isPressed: true) == role.activeColor)
            #expect(role.resolvedColor(isEnabled: false, isPressed: false) == role.disabledColor)
        }
    }
}
