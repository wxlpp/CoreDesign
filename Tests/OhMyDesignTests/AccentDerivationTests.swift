import SwiftUI
import Testing
@testable import OhMyDesign

// MARK: - accent 衍生族的方向性守卫（Issue #120）

@Suite("accent 衍生族方向性")
struct AccentDerivationTests {
    private nonisolated static func luminance(_ c: Color.Resolved) -> Float {
        0.2126 * c.red + 0.7152 * c.green + 0.0722 * c.blue
    }

    private nonisolated static func env(_ scheme: ColorScheme) -> EnvironmentValues {
        var e = EnvironmentValues()
        e.colorScheme = scheme
        return e
    }

    @Test("pressed 在浅色下变亮、在深色下变暗——即始终朝向背景")
    func pressedMovesTowardBackground() {
        let light = Self.env(.light), dark = Self.env(.dark)
        let accentLight = Self.luminance(Color.accent.resolve(in: light))
        let pressedLight = Self.luminance(Color.accentPressed.resolve(in: light))
        let accentDark = Self.luminance(Color.accent.resolve(in: dark))
        let pressedDark = Self.luminance(Color.accentPressed.resolve(in: dark))

        #expect(pressedLight > accentLight, "浅色模式按下应朝白背景变亮，实测 \(pressedLight) 未高于 \(accentLight)")
        #expect(pressedDark < accentDark, "深色模式按下应朝黑背景变暗，实测 \(pressedDark) 未低于 \(accentDark)")
    }

    @Test("hover 与 pressed 同向，且 pressed 走得更远")
    func hoverAndPressedShareDirection() {
        for scheme in [ColorScheme.light, .dark] {
            let e = Self.env(scheme)
            let a = Self.luminance(Color.accent.resolve(in: e))
            let h = Self.luminance(Color.accentHover.resolve(in: e))
            let p = Self.luminance(Color.accentPressed.resolve(in: e))
            #expect(abs(h - a) < abs(p - a), "\(scheme)：pressed 应比 hover 离 accent 更远")
            #expect((h - a).sign == (p - a).sign, "\(scheme)：hover 与 pressed 方向应一致")
        }
    }

    @Test("混合只动明度、不显著降 alpha")
    func derivationPreservesOpacity() {
        for scheme in [ColorScheme.light, .dark] {
            let e = Self.env(scheme)
            for (name, color) in [("accentHover", Color.accentHover), ("accentPressed", Color.accentPressed)] {
                let alpha = color.resolve(in: e).opacity
                #expect(alpha > 0.95, "\(name) 在 \(scheme) 下 alpha 降到 \(alpha)——混合不应显著降透明度")
            }
        }
    }

    @Test("混合基色未被提前解析——四档在浅色与深色下取值不同")
    func derivationIsAppearanceAdaptive() {
        let light = Self.env(.light), dark = Self.env(.dark)
        for (name, color) in [("accentHover", Color.accentHover), ("accentPressed", Color.accentPressed)] {
            #expect(
                color.resolve(in: light) != color.resolve(in: dark),
                "\(name) 在两种外观下解析结果相同——混合基色被提前解析成固定值了"
            )
        }
    }
}
