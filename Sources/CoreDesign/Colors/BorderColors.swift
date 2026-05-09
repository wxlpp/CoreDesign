import SwiftUI

public extension Color {
    static var borderSubtle: Color {
        .separator.opacity(0.35)
    }

    static var borderDefault: Color {
        .separator
    }

    static var borderStrong: Color {
        .opaqueSeparator
    }

    static var dividerDefault: Color {
        .separator
    }

    static var dividerOpaque: Color {
        .opaqueSeparator
    }

    static var focusRing: Color {
        .accent
    }
}
