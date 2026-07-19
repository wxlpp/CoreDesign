import SwiftUI

public extension Color {
    static let accent = Color.brand5
    static let accentHover = Color.brand6
    static let accentPressed = Color.brand7
    static let accentDisabled = Color.brand2
    static let accentSubtleBackground = Color.brand1

    #if Blossom
    static let secondaryAccent = Color.violet5
    static let secondaryAccentHover = Color.violet6
    static let secondaryAccentPressed = Color.violet7
    static let secondaryAccentDisabled = Color.violet2
    #else
    static let secondaryAccent = Color.lightBlue5
    static let secondaryAccentHover = Color.lightBlue6
    static let secondaryAccentPressed = Color.lightBlue7
    static let secondaryAccentDisabled = Color.lightBlue2
    #endif

    static let neutralAccent = Color.grey5
    static let neutralAccentHover = Color.grey6
    static let neutralAccentPressed = Color.grey7
    static let neutralAccentDisabled = Color.grey2

    static var selectionBackground: Color {
        .accentSubtleBackground
    }

    /// 强调选区背景。与 `accentDisabled` 共值（同为 `brand2`）——两者语义不同但视觉档位
    /// 一致，走同层别名而非直接引用第 1 层原子色，以免 accent 重定向时漏改。
    static var selectionBackgroundEmphasis: Color {
        .accentDisabled
    }

    static var hoverBackground: Color {
        .secondaryFill
    }

    static var pressedBackground: Color {
        .tertiaryFill
    }

    static var disabledBackground: Color {
        .quaternaryFill
    }

    static var disabledForeground: Color {
        .contentDisabled
    }
}
