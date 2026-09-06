import SwiftUI
import Testing
@testable import CoreDesign

@Suite("Shared Foundation — semi-mobile-components Phase 0")
struct SharedFoundationTests {
    static let bundle = Bundle.module

    private func plural(_ key: String, _ n: Int) -> String {
        String(format: Self.bundle.localizedString(forKey: key, value: nil, table: nil), n)
    }

    // MARK: - 复数键（.stringsdict）

    @Test("Rating 星数复数键：one/other 形态正确")
    func ratingStarsPlural() {
        #expect(plural("%lld stars", 1) == "1 star")
        #expect(plural("%lld stars", 3) == "3 stars")
    }

    @Test("AvatarGroup 总数复数键：one/other 形态正确")
    func avatarGroupTotalPlural() {
        #expect(plural("%lld avatars", 1) == "1 avatar")
        #expect(plural("%lld avatars", 5) == "5 avatars")
    }

    @Test("Steps 步数复数键：one/other 形态正确")
    func stepsPlural() {
        #expect(plural("%lld steps", 1) == "1 step")
        #expect(plural("%lld steps", 4) == "4 steps")
    }

    // MARK: - 简单字符串键（.strings）

    @Test("Phase 0 预登记的 accessibility 字符串键已注册进资源 bundle")
    func accessibilityLabelKeysResolve() {
        let keys = [
            "Rating", "Verification code",
            "Info", "Success", "Warning", "Error",
            "%@ of %@",
        ]
        for key in keys {
            #expect(Self.bundle.localizedString(forKey: key, value: "\u{0}", table: nil) != "\u{0}")
        }
    }

    // MARK: - 骨架屏取色 token（可引用性 · 非 colorset 派生）

    @Test("Skeleton 取色 token 可引用，且高光在明暗两端合成后都比底色亮")
    @MainActor
    func skeletonColorTokensAreUsable() {
        let backdrop = 0.5
        func compositedLuminance(_ color: Color, _ scheme: ColorScheme) -> Double {
            var env = EnvironmentValues()
            env.colorScheme = scheme
            let c = color.resolve(in: env)
            let hue = 0.2126 * Double(c.red) + 0.7152 * Double(c.green) + 0.0722 * Double(c.blue)
            let alpha = Double(c.opacity)
            return hue * alpha + backdrop * (1 - alpha)
        }
        for scheme in [ColorScheme.light, .dark] {
            let base = compositedLuminance(Color.skeletonBase, scheme)
            let highlight = compositedLuminance(Color.skeletonHighlight, scheme)
            #expect(highlight > base,
                    "\(scheme) 下 skeletonHighlight 合成亮度 \(highlight) 不高于 skeletonBase \(base) —— shimmer 会扫出一道暗带而不是高光")
        }
    }

    @Test("specularHighlight 在明暗两端都必须是「亮」的，且不透明度足以看见")
    @MainActor
    func specularHighlightIsActuallyBright() {
        func luminance(_ scheme: ColorScheme) -> (Double, Double) {
            var env = EnvironmentValues()
            env.colorScheme = scheme
            let c = Color.specularHighlight.resolve(in: env)
            return (0.2126 * Double(c.red) + 0.7152 * Double(c.green) + 0.0722 * Double(c.blue),
                    Double(c.opacity))
        }
        for scheme in [ColorScheme.light, .dark] {
            let (lum, alpha) = luminance(scheme)
            #expect(lum > 0.8, "\(scheme) 下色相亮度只有 \(lum) —— 它会读作暗带而不是高光")
            #expect(alpha >= 0.25, "\(scheme) 下不透明度只有 \(alpha) —— 高光看不见")
            #expect(alpha < 1, "\(scheme) 下不透明度是 \(alpha) —— 不透明会把内容整块盖掉")
        }
    }
}
