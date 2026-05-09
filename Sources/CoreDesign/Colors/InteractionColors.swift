import SwiftUI

public extension Color {
    static let accent = Color.brand5
    static let accentHover = Color.brand6
    static let accentPressed = Color.brand7
    static let accentDisabled = Color.brand2
    static let accentSubtleBackground = Color.brand1

    static let secondaryAccent = Color.lightBlue5
    static let secondaryAccentHover = Color.lightBlue6
    static let secondaryAccentPressed = Color.lightBlue7
    static let secondaryAccentDisabled = Color.lightBlue2

    static let neutralAccent = Color.grey5
    static let neutralAccentHover = Color.grey6
    static let neutralAccentPressed = Color.grey7
    static let neutralAccentDisabled = Color.grey2

    static var selectionBackground: Color {
        .accentSubtleBackground
    }

    static var selectionBackgroundEmphasis: Color {
        .brand2
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
