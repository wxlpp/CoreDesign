import SwiftUI
import Testing
@testable import CoreDesign

// MARK: - coreAccent 主题化

@Suite("coreAccent 主题化")
@MainActor
struct CoreAccentThemingTests {
    @Test("环境默认值与静态回退同源——一个改了另一个没改不会有任何东西报错")
    func environmentDefaultMatchesStaticFallback() {
        #expect(
            EnvironmentValues().coreAccent == Color.accent,
            "\\.coreAccent 的默认值与 Color.accent 不同源——两处各写一遍必然漂"
        )
    }

    @Test("派生公式只有一处来源：role 现场派生的结果与静态 token 逐档相等")
    func derivationHasSingleSource() {
        let role = ButtonRoleStyleRole.primary
        #expect(
            role.resolvedColor(accent: .accent, isEnabled: true, isPressed: true) == Color.accentPressed,
            "primary 的按下态与 Color.accentPressed 不等——两处派生已经漂了（本条抓漂移，不抓重复：把公式逐字抄一遍它照绿）"
        )
        #expect(
            role.resolvedColor(accent: .accent, isEnabled: false, isPressed: false) == Color.accentDisabled,
            "primary 的禁用态与 Color.accentDisabled 不等——派生公式写了第二遍"
        )
        #expect(
            role.resolvedColor(accent: .accent, isEnabled: true, isPressed: false) == Color.accent,
            "primary 的静息态与 Color.accent 不等"
        )
    }

    @Test("传入的 accent 真的被用上——换 accent 后 primary 三态全部随之改变")
    func primaryRoleFollowsSuppliedAccent() {
        let role = ButtonRoleStyleRole.primary
        for (name, isEnabled, isPressed) in [
            ("静息", true, false), ("按下", true, true), ("禁用", false, false),
        ] {
            let ink = role.resolvedColor(accent: .accent, isEnabled: isEnabled, isPressed: isPressed)
            let red = role.resolvedColor(accent: .red, isEnabled: isEnabled, isPressed: isPressed)
            #expect(ink != red, "\(name)态没跟随传入的 accent——参数被忽略了")
        }
    }

    @Test("非 primary 的四个 role 不跟随 accent——它们有意留在自有色阶上")
    func nonPrimaryRolesIgnoreAccent() {
        for role in [
            ButtonRoleStyleRole.secondary, .tertiary, .warning, .danger,
        ] {
            #expect(
                role.resolvedColor(accent: .red, isEnabled: true, isPressed: false)
                    == role.resolvedColor(accent: .green, isEnabled: true, isPressed: false),
                "\(role) 跟随了 accent——次要/三级/警告/危险四个 role 应留在自有色阶"
            )
        }
    }

    /// 五个 role 的底色都随外观镜像（primary 是墨色，其余取自明暗镜像的 `ColorGrade`）
    /// ⇒ 前景必须一律跟着翻转。iOS 腿实测：白字压 `secondaryAccent` 深色只有 1.65:1、
    /// 压 `warning` 1.84:1，反转后分别是 12.73:1 / 11.39:1。
    @Test("五个 role 的 onColor 都随主题反转——白字在深色下压不住镜像色阶")
    func everyRoleOnColorInverts() {
        for role in [
            ButtonRoleStyleRole.primary, .secondary, .tertiary, .warning, .danger,
        ] {
            #expect(
                role.onColor == Color.contentOnAccent,
                "\(role) 的前景不是随主题反转的 contentOnAccent —— 底色是镜像色阶，固定白字在深色下压不住"
            )
        }
        #expect(
            Color.contentOnEmphasis != Color.contentOnAccent,
            "contentOnEmphasis 与 contentOnAccent 已同值 —— 那 onColor 这个接缝就失去意义了；前者服务固定饱和色底（StateLabel / Form）"
        )
    }

    /// ⚠️ 只断言「明暗取值不同」**不够**（终审 I-2 用变异证明）：把 `contentOnAccent`
    /// 改成 `.label`——与 accent **同极性**，正是「字与底同色」这个要防的 bug——
    /// 明暗两档取值照样不同，那条判据照绿。⇒ 必须断言**极性相反**。
    @Test("contentOnAccent 与 accent 极性相反——同色会让字压在同色底上看不见")
    func contentOnAccentIsOppositePolarityToAccent() {
        func luminance(_ c: Color.Resolved) -> Float {
            0.2126 * c.red + 0.7152 * c.green + 0.0722 * c.blue
        }
        for scheme in [ColorScheme.light, .dark] {
            var env = EnvironmentValues()
            env.colorScheme = scheme
            let onAccent = luminance(Color.contentOnAccent.resolve(in: env))
            let accent = luminance(Color.accent.resolve(in: env))
            #expect(
                abs(onAccent - accent) > 0.5,
                "\(scheme)：contentOnAccent 亮度 \(onAccent) 与 accent \(accent) 差不足 0.5——两者极性相同，文字会压在同色底上"
            )
        }
        var light = EnvironmentValues()
        light.colorScheme = .light
        var dark = EnvironmentValues()
        dark.colorScheme = .dark
        #expect(
            Color.contentOnAccent.resolve(in: light) != Color.contentOnAccent.resolve(in: dark),
            "contentOnAccent 在明暗下取值相同——它被写死成固定色了"
        )
    }

    @Test("dataAccent 不跟随 accent——墨色的图表环会读成禁用")
    func dataAccentIsIndependentOfAccent() {
        var light = EnvironmentValues()
        light.colorScheme = .light
        let data = Color.dataAccent.resolve(in: light)
        let accent = Color.accent.resolve(in: light)
        #expect(
            data != accent,
            "dataAccent 与 accent 解析结果相同——数据色被并进强调色了"
        )
        #expect(
            data.red != data.green || data.green != data.blue,
            "dataAccent 是消色（\(data)）——靠色相携带含义的场景需要一个有色相的值"
        )
        // ⚠️ 钉死取值（终审 S-4）：`Color.blue` 与 `Color(nsColor/uiColor: .systemBlue)`
        // 不是同一个值，spec §4.1 定的是后者。只断言「有色相」时改成 `.blue` 会照绿。
        #expect(
            Color.dataAccent == {
                #if canImport(UIKit)
                    Color(uiColor: .systemBlue)
                #else
                    Color(nsColor: .systemBlue)
                #endif
            }(),
            "dataAccent 不是平台的 systemBlue —— 别用 Color.blue，两者取值不同"
        )
    }
}

// MARK: - secondaryAccent 迁到灰阶

@Suite("secondaryAccent 色阶归属")
struct SecondaryAccentRampTests {
    /// ⚠️ 走 asset 名而不是 `resolve(in:)`：这批常量在 macOS native 腿上恒为全透明
    /// （`CLAUDE.md` 登记的 198 个），比解析值会「向绿失效」。
    @Test("secondaryAccent 四态取自 grey 色阶，不再是 lightBlue")
    func secondaryAccentUsesGreyRamp() throws {
        let expected = [
            ("secondaryAccent", Color.secondaryAccent, "grey-7"),
            ("secondaryAccentHover", Color.secondaryAccentHover, "grey-8"),
            ("secondaryAccentPressed", Color.secondaryAccentPressed, "grey-9"),
            ("secondaryAccentDisabled", Color.secondaryAccentDisabled, "grey-2"),
        ]
        for (label, color, wanted) in expected {
            let name = try #require(
                assetName(of: color),
                "\(label) 抠不出 asset 名——判据无法判定，不接受静默跳过"
            )
            #expect(name == wanted, "\(label) 取的是 \(name)，期望 \(wanted)")
        }
    }
}
