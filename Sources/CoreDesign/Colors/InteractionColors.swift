import SwiftUI

// MARK: - Interaction Colors / 交互颜色

public extension Color {
    /// 交互强调色。**静态回退值**——不随 `View.coreAccent(_:)` 变；
    /// 需要跟随主题的消费点应读 `@Environment(\.coreAccent)`。
    static let accent = Color.inkPrimary

    /// Hover 态：朝背景走一档。
    /// ⚠️ 方向与 `0.9.0` 之前相反：accent 现在是明度极值（墨色），无法「更远离背景」。
    static var accentHover: Color { Color.accentHover(from: .accent) }

    /// 按下态：比 hover 再朝背景走一档。
    static var accentPressed: Color { Color.accentPressed(from: .accent) }

    /// 禁用态：对 accent 降低不透明度，保持色相、只削存在感。
    static var accentDisabled: Color { Color.accentDisabled(from: .accent) }

    /// accent 的极淡背景色，用于选中态等大面积低对比场景；走降不透明度而非白混合。
    static var accentSubtleBackground: Color { Color.accentSubtleBackground(from: .accent) }

    // MARK: - 数据色 / Data colour

    /// 图表、tag 等**靠色相携带含义**的场景专用，刻意**不跟随** `accent`——
    /// 墨色的环或标签会读成「禁用」。故意留在系统蓝上。
    static var dataAccent: Color {
        #if canImport(UIKit)
            Color(uiColor: .systemBlue)
        #else
            Color(nsColor: .systemBlue)
        #endif
    }

    /// `dataAccent` 的淡染底色。
    static var dataAccentSubtle: Color { Color.dataAccent.opacity(0.12) }

    // MARK: - secondaryAccent（显式定案：保留品牌色阶）

    static let secondaryAccent = Color.grey7
    static let secondaryAccentHover = Color.grey8
    static let secondaryAccentPressed = Color.grey9
    static let secondaryAccentDisabled = Color.grey2

    // MARK: - neutralAccent（显式定案：保留品牌色阶）

    static let neutralAccent = Color.grey5
    static let neutralAccentHover = Color.grey6
    static let neutralAccentPressed = Color.grey7
    static let neutralAccentDisabled = Color.grey2

    /// 常规选中态背景：低调的强调色淡染。
    static var selectionBackground: Color {
        .accentSubtleBackground
    }

    /// 强调选中态背景：实心 `accent`，与 `contentOnAccent` 前景配对（该前景随主题反转，不再是白字）。
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

// MARK: - 派生公式（单一来源）/ Derivation, single source

/// accent 族四个派生态的**唯一**公式来源。静态 token 与 `ButtonRoleStyleRole`
/// 都调这里——两处各写一遍必然漂，而漂了不会有任何东西报错。
extension Color {
    static func accentHover(from base: Color) -> Color {
        base.mix(with: .surfaceBase, by: 0.18)
    }

    static func accentPressed(from base: Color) -> Color {
        base.mix(with: .surfaceBase, by: 0.30)
    }

    static func accentDisabled(from base: Color) -> Color {
        base.opacity(0.22)
    }

    static func accentSubtleBackground(from base: Color) -> Color {
        base.opacity(0.08)
    }
}
