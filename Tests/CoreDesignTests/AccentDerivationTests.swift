import SwiftUI
import Testing
@testable import CoreDesign

// MARK: - accent 衍生族的方向性守卫（Issue #120）
//
// 旧的 accent 衍生族取固定色阶 `brand6` / `brand7`，而那些 colorset 是**外观自适应
// 反转**的——实测：
//
//     brand-5（accent）  light #0077FA   dark #3295FB
//     brand-6（hover）   light #0062D6   dark #65B2FC   ← 浅色更深、深色更浅
//     brand-7（pressed） light #004FB3   dark #98CDFD   ← 同向更极端
//
// 即旧行为是「朝**远离背景**的方向走一档」，不是恒定变暗。改用动态 `Color.accentColor`
// 后无法再取预先烘焙的色阶，改为 `mix(with: .primary, by:)`——`.primary` 浅色≈黑、
// 深色≈白，一个基色即可复现双向行为。
//
// 本文件锁定这一方向性。若有人把混合基色改回固定的 `.black` / `.white`（那会在其中
// 一个模式下把 accent 推向背景色、收窄对比度），这里会红。
//
// > 任务 AC 原文写「`brand7` 是加深，必须压暗而非降 alpha」——那只在**浅色模式**成立。
// > 「不要降 alpha」的部分仍然成立并已遵守。

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

    @Test("pressed 在浅色下变暗、在深色下变亮——即始终远离背景")
    func pressedMovesAwayFromBackground() {
        let light = Self.env(.light), dark = Self.env(.dark)
        let accentLight = Self.luminance(Color.accent.resolve(in: light))
        let pressedLight = Self.luminance(Color.accentPressed.resolve(in: light))
        let accentDark = Self.luminance(Color.accent.resolve(in: dark))
        let pressedDark = Self.luminance(Color.accentPressed.resolve(in: dark))

        #expect(pressedLight < accentLight, "浅色模式按下应变暗，实测 \(pressedLight) 未低于 \(accentLight)")
        #expect(pressedDark > accentDark, "深色模式按下应变亮以远离黑画布，实测 \(pressedDark) 未高于 \(accentDark)")
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
        // 任务 AC 要求「不要降 alpha」——降 alpha 只会露出更多背景、削弱存在感。
        // 实现用的是明度混合，本应保持不透明。唯一例外：macOS 的 `.primary`
        // （`NSColor.labelColor`）自带 α≈0.85，按线性混合公式 `(1-t)·1 + t·0.85`
        // 算得 hover(t=0.15) α≈0.976、pressed(t=0.25) α≈0.961。iOS 的 `UIColor.label`
        // 全不透明，不受影响。
        //
        // 这个 2–4% 的下滑视觉不可辨，但此前只写在注释里、没有任何断言守着。
        // 取 0.95 作下界：既容得下 macOS 的已知副作用，又能拦住「改回 opacity 调制」
        // 这类真正的降 alpha 回归。
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
