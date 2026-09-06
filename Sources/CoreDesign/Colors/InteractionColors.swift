import SwiftUI

// MARK: - Interaction Colors / 交互颜色

public extension Color {
    /// 交互强调色，跟随宿主 App 的 AccentColor 资源。
    static let accent = Color.accentColor

    /// Hover 态：**离背景更远一档**，用于 macOS 指针悬停 / iPadOS 指针高亮等
    /// "按下前的强调"场景。
    static let accentHover = Color.accent.mix(with: .primary, by: 0.15)

    /// 按下态：比 hover **更远离背景一档**。混合基色同 `accentHover` 取 `.primary`
    /// 以复现"离背景更远一档"的双向行为——加深只在浅色模式成立，深色模式下同样的
    /// 固定色阶反而是提亮的；恒定压暗会在深色模式把 accent 推向纯黑画布
    /// （`systemGroupedBackground` dark = `#000000`），方向相反。不用降 alpha 的原因是
    /// 降 alpha 只会露出更多背景、削弱存在感，两个模式下都不对。
    static let accentPressed = Color.accent.mix(with: .primary, by: 0.25)

    /// 禁用态：对 accent 本身降低不透明度——与 Apple 系统控件的禁用惯例一致（保持
    /// 色相、只降低存在感/对比度，而不是像 pressed 那样改变明度方向）。
    static let accentDisabled = Color.accent.opacity(0.35)

    /// accent 的极淡背景色，用于选中态背景等大面积、低对比场景。对 accent 本身
    /// 降低不透明度——不透明度会让底层背景透出来，在浅色与深色画布上都能读出
    /// "淡淡的强调色调"；若改用与 `accentHover` 一致的白混合调制，在深色背景上会
    /// 变成一块突兀的发亮浅色色块，不再是"淡淡的背景"。
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

    /// 强调选中态背景：实心 `accent`，与 `contentOnAccent`（白字前景）配对使用，
    /// 用于选中行 / 激活开关等需要强对比的场景。**不**借道 `accentDisabled`——
    /// 后者是"降低不透明度的褪色"语义（禁用态），借道会把"强调选中"渲染成
    /// "看起来像禁用"的淡色块，语义倒挂。
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
