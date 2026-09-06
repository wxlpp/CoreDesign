import SwiftUI

// MARK: - Interaction Colors / 交互颜色

public extension Color {
    /// 交互强调色，跟随宿主 App 的 AccentColor 资源。
    static let accent = Color.accentColor

    /// Hover 态：离背景更远一档，用于指针悬停 / 高亮。
    static let accentHover = Color.accent.mix(with: .primary, by: 0.15)

    /// 按下态：比 hover 再远离背景一档；混合基色取 `.primary` 以在深浅双模式都成立。
    static let accentPressed = Color.accent.mix(with: .primary, by: 0.25)

    /// 禁用态：对 accent 降低不透明度，保持色相、只削存在感。
    static let accentDisabled = Color.accent.opacity(0.35)

    /// accent 的极淡背景色，用于选中态等大面积低对比场景；走降不透明度而非白混合。
    static let accentSubtleBackground = Color.accent.opacity(0.12)

    // MARK: - secondaryAccent（显式定案：保留品牌色阶）

    static let secondaryAccent = Color.lightBlue5
    static let secondaryAccentHover = Color.lightBlue6
    static let secondaryAccentPressed = Color.lightBlue7
    static let secondaryAccentDisabled = Color.lightBlue2

    // MARK: - neutralAccent（显式定案：保留品牌色阶）

    static let neutralAccent = Color.grey5
    static let neutralAccentHover = Color.grey6
    static let neutralAccentPressed = Color.grey7
    static let neutralAccentDisabled = Color.grey2

    /// 常规选中态背景：低调的强调色淡染。
    static var selectionBackground: Color {
        .accentSubtleBackground
    }

    /// 强调选中态背景：实心 `accent`，与 `contentOnAccent` 白字前景配对。
    static var selectionBackgroundEmphasis: Color {
        .accent
    }

    /// 中性 hover 底色。委托给 `FillColors`，那一层已由系统色支撑，本层无需改指。
    /// 这一族与 accent 族无关，不参与强调色的动态推导。
    static var hoverBackground: Color {
        .secondaryFill
    }

    /// 中性按下底色。委托给 `FillColors`，那一层已由系统色支撑，本层无需改指。
    /// 这一族与 accent 族无关，不参与强调色的动态推导。
    static var pressedBackground: Color {
        .tertiaryFill
    }

    /// 禁用态底色。委托给 `FillColors`，那一层已由系统色支撑，本层无需改指。
    /// 这一族与 accent 族无关，不参与强调色的动态推导。
    static var disabledBackground: Color {
        .quaternaryFill
    }

    /// 禁用态前景色。委托给 `ContentColors`，那一层已由系统色支撑，本层无需改指。
    /// 这一族与 accent 族无关，不参与强调色的动态推导。
    static var disabledForeground: Color {
        .contentDisabled
    }
}
