import SwiftUI
import Testing
@testable import CoreDesign

// semi-mobile-components Phase 0（#161）——共享地基预登记项的回归测试。
// 覆盖 Phase 0 预登记的 accessibility 复数键 / 字符串键，以及骨架屏取色 token 的公开可见性。
// 不触碰共享 suite（TouchTargetTests / DynamicTypeLayoutTests）——这些留给 013。
@Suite("Shared Foundation — semi-mobile-components Phase 0")
struct SharedFoundationTests {
    // 直接对 CoreDesign 资源 bundle 做解析验证。
    //
    // 为什么不用 `String(localized:bundle:)`：在 macOS 的 `swift test` 腿上，`String(localized:)`
    // 不会对 SwiftPM 资源 bundle 里的 `.stringsdict` 套用 `one` 复数规则（只在 iOS 腿生效——
    // 属 CLAUDE.md 记载的「macOS swift test 对 iOS 行为假绿」盲区）。而底层
    // `Bundle.localizedString(forKey:value:table:)` + `String(format:)` 在两端都正确解析，
    // 因此用它来验证 Phase 0 的交付物「键已注册且 one/other 内容正确」。组件（Rating/Steps）
    // 在各自 Issue 里通过 `String(localized:)` 消费这些键，其运行时渲染由 iOS Simulator 腿验证。
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
        // ⚠️ `.countOnly`（`#60`）消费的键。**必须在这里断言**，不能在 `AvatarGroupTests`
        // 里用 `String(localized:)` 自比自 —— 那样左右两边走同一条 fallback，键注册与否
        // 结果一样绿（PR #206 第 2 轮 review 抓到的恒真测试）。本 suite 走
        // `Bundle.localizedString`，才真正区分「已注册」与「fallback」，见文件头注释。
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
        // value: "\u{0}" 作哨兵——键缺失时 localizedString 返回哨兵值。断言「返回值 != 哨兵」
        // 即证「键已注册」，且**不**把「en 值恒等于 key」也捆进来（日后微调某个 en 值不该让本测试误红）。
        let keys = [
            "Rating", "Verification code",               // 组件标签
            // 注意："Add tag" 曾在 Phase 0 预登记，Phase 3（#173）收口时确认
            // TagInput 未消费（verbatim 渲染 placeholder，仿 SearchField 先例），
            // 已连同本条断言一并从 Localizable.strings 移除——不在此处保留死键。
            "Info", "Success", "Warning", "Error",       // Timeline 节点状态
            "%@ of %@",                                   // 通用位置/数值键
        ]
        for key in keys {
            #expect(Self.bundle.localizedString(forKey: key, value: "\u{0}", table: nil) != "\u{0}")
        }
    }

    // MARK: - 骨架屏取色 token（可引用性 · 非 colorset 派生）

    /// ⚠️ **上一版这里是一句 `#expect(Bool(true))`**（PR #262 第 2 轮 review 指出；
    /// 缺陷本身自 #161 Phase 0 就在，**不是 #262 引入**）。恒真断言会在测试报告里
    /// 以「Skeleton 取色 token 已覆盖」的名义出现，而它一个性质都没钉住。
    /// ⇒ 换成可观测判据：`skeletonHighlight` 是 `skeletonBase` 向白提亮派生的
    ///（`mix(with: .white, by: 0.5)`，#162 裁决），那么在明暗两端**它盖在同一块
    /// 底衬上都必须更亮**。这条会对「派生方向被写反」「提亮系数被改成 0」判红。
    ///
    /// ⚠️⚠️ **必须合成后再比，不能只比 `resolve(in:)` 的色相分量**——这正是
    /// 隔壁 `specularHighlight` 那条在第 4 轮终审 C4-4 学到的同一课（未预乘、
    /// alpha 单独放在 `opacity` 里）。实测两端取值：
    /// · light：base `#00000019`、highlight `#E1E1E18C`
    /// · dark ：base `#FFFFFF19`、highlight `#FFFFFF8C`
    /// **dark 下两者色相同为纯白**，差别整个落在 alpha（0.098 → 0.549）上
    /// ⇒ 只比色相亮度时 dark 判红（1.0 不 > 1.0），而那是判据错、不是 token 错。
    ///
    /// 底衬取中性灰 0.5：纯黑底会让 light 的 base 退化成 0（断言变得平凡），
    /// 纯白底会让 dark 两者都合成到 1.0（断言恒假）。
    @Test("Skeleton 取色 token 可引用，且高光在明暗两端合成后都比底色亮")
    @MainActor
    func skeletonColorTokensAreUsable() {
        // 注意：`@testable import` 下 internal 符号一样可解析，本测试**只**证明
        // 「token 存在且编译可用」，不构成真正的 public 可见性护栏——后者由
        // `scripts/downstream-probe` 从外部包 `consumeSkeletonColorTokens()` 守。
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

    /// ⚠️ **这条断言的目标是钉住「它是高光、不是暗带」这个性质本身**
    ///（PR #262 终审 I-2 / C4-4）。
    ///
    /// `.shine()` 的默认高光初版是 `Color.contentPrimary.opacity(0.35)` ——
    /// `contentPrimary` 就是 `.label`，**浅色外观下近黑** ⇒ 扫过去的是一道黑带。
    /// 本仓 #162 / 评审 #176 已就同一件事出过一次裁决（`skeletonHighlight`）。
    ///
    /// ⚠️⚠️ **上一版的断言比它宣称的弱**（第 4 轮终审 C4-4 实测）：`resolve(in:)`
    /// 返回的是**未预乘**分量，alpha 单独放在 `opacity` 里 ⇒ `.white.opacity(0.02)`
    ///（功能上等于没有高光）的 luminance 同样是 1.0，照样通过。
    /// 而且只在默认（浅色）环境下求值 ⇒ 一个「浅色下白、深色下黑」的动态 token
    ///（正是 #162 那条裁决的**镜像形态**）会静默通过。
    /// ⇒ 本版：**两种 colorScheme 各求一次** + **把 alpha 纳入判据**。
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
            // ⚠️ alpha 必须纳入：色相再白，透明度 0.02 也等于没有高光。
            #expect(alpha >= 0.25, "\(scheme) 下不透明度只有 \(alpha) —— 高光看不见")
            #expect(alpha < 1, "\(scheme) 下不透明度是 \(alpha) —— 不透明会把内容整块盖掉")
        }
    }
}
