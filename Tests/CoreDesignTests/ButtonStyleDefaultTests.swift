import Testing
@testable import CoreDesign

@Suite("Button style defaults")
@MainActor
struct ButtonStyleDefaultTests {
    // MARK: - solid / light 的公开表面（#41 裁决 3：glass 存储属性已删除）
    //
    // ⚠️ 原先这里有四条 `@Test` 盯着 `glass` 存储属性（默认 false / 显式 true 可用 /
    // 两个工厂默认 false）。#41 按公约第 3 节终局条款 (b) 把 `glass` 整个删掉了——
    // 跨仓实测对外零调用点（App/ 零命中、scripts/downstream-probe 零命中、StoryUI
    // 全仓零命中，`glass:` 的命中全在 .build/checkouts 里的 vendored 本库副本），
    // (b) 成立 ⇒ 前两条与第四条失去被测对象、第三条被测行为整个消失。
    // 删测试而不是留一个恒真的壳：留壳会让「这个开关还在被守着」这句话变成假话。
    //
    // 换上一条**仍然承重**的断言：两个 style 的公开表面现在只按 role 参数化。
    // 它挡的是「有人顺手给 SolidButtonStyle 再加一个布尔外观开关」——新增的
    // 存储属性不会让这条红，但新增的 **init 形参**会让 J-1 立刻红
    //（BoolExemptionGuard 的双向差集），两道合起来覆盖住这个回归面。

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
