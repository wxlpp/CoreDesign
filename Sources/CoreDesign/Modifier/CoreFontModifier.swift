//
//  CoreFontModifier.swift
//  CoreDesign
//

import SwiftUI

// MARK: - CoreFontModifier

/// 施加一个 `CoreTypography.Token`：直接取系统文本样式 `Font`，随 Dynamic Type 缩放。
///
/// Issue #119 之前，token 携带手写的 size / weight 基准，靠 `@ScaledMetric` 在 View
/// 上下文里手动模拟缩放。现在 `Token` 直接对应 `Font.TextStyle`，缩放交给系统本身，
/// 本 modifier 只保留 `.coreFont(_:)` 的调用形态——它是全库统一的文字入口，形态变更
/// 会波及每个组件文件，因此形态本身不变，只是内部实现大幅简化。
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
