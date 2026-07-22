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

    // MARK: - 三态调色板互不相同（Issue #120）
    //
    // Issue #120 把 `ButtonRoleStyleRole.primary` 的调色板改为对动态 `accent` 做
    // `mix`/`opacity` 调制而非固定色阶。这里断言每个 role 的 `color` /
    // `activeColor` / `disabledColor` 三者结构上互不相同——`Color` 是 Equatable，
    // 对同一表达式重复求值会得到结构相同的值，因此这条断言能捕获"调制没生效、
    // 三态退化为同一个颜色"这类回归（尤其是 pressed 若被误改成降低不透明度，
    // 有可能与 disabled 撞色）。真实的浅色/深色差异无法在 `swift test` 里直接
    // 渲染断言，但 `accent` 走 `Color.accentColor`、`secondaryAccent`/`neutralAccent`
    // 走带 light/dark 双值的 colorset、`warning`/`danger` 走同样带双值的 colorset，
    // 三者的明暗自适应链路本身已由 SwiftUI / colorset 机制保证。
    @Test("每个 role 的 color / activeColor / disabledColor 三态互不相同")
    func everyRoleHasThreeDistinctTones() {
        for role in [ButtonRoleStyleRole.primary, .secondary, .tertiary, .warning, .danger] {
            #expect(role.color != role.activeColor, "\(role) 的 color 与 activeColor 撞色")
            #expect(role.color != role.disabledColor, "\(role) 的 color 与 disabledColor 撞色")
            #expect(role.activeColor != role.disabledColor, "\(role) 的 activeColor 与 disabledColor 撞色")
        }
    }
}
