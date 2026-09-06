import SwiftUI

// MARK: - CoreFontModifier

private struct CoreFontModifier: ViewModifier {
    let token: CoreTypography.Token

    func body(content: Content) -> some View {
        content.font(self.token.font)
    }
}

// MARK: - View extension

public extension View {
    /// 施加 CoreDesign 排版 token（直接取系统文本样式，随 Dynamic Type 缩放）。
    func coreFont(_ token: CoreTypography.Token) -> some View {
        self.modifier(CoreFontModifier(token: token))
    }
}
