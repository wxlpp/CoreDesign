import Testing
@testable import CoreDesign

@Suite("Button style defaults")
@MainActor
struct ButtonStyleDefaultTests {
    // MARK: - solid / light 的公开表面（#41 裁决 3：glass 存储属性已删除）

    @Test("solid / light 只按 role 参数化，直接构造与工厂两条路给出同一个 role")
    func solidAndLightAreParameterizedByRoleOnly() {
        #expect(SolidButtonStyle().role == .primary)
        #expect(LightButtonStyle().role == .primary)
        #expect(SolidButtonStyle(role: .danger).role == .danger)
        #expect(LightButtonStyle(role: .secondary).role == .secondary)

        let solid: SolidButtonStyle = .solid(role: .warning)
        let light: LightButtonStyle = .light(role: .tertiary)
        #expect(solid.role == .warning)
        #expect(light.role == .tertiary)
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

    // MARK: - 三态调色板互不相同（Issue #120）

    @Test("每个 role 的 color / activeColor / disabledColor 三态互不相同")
    func everyRoleHasThreeDistinctTones() {
        for role in [ButtonRoleStyleRole.primary, .secondary, .tertiary, .warning, .danger] {
            #expect(role.color != role.activeColor, "\(role) 的 color 与 activeColor 撞色")
            #expect(role.color != role.disabledColor, "\(role) 的 color 与 disabledColor 撞色")
            #expect(role.activeColor != role.disabledColor, "\(role) 的 activeColor 与 disabledColor 撞色")
        }
    }
}
