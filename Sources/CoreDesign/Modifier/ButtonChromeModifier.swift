//
//  ButtonChromeModifier.swift
//  CoreDesign
//

import SwiftUI

// MARK: - ButtonChromeModifier

/// 按钮的通用 chrome / Shared button chrome：字号 + 内边距 + 命中区域。
///
/// 这四行原本在 `SolidButtonStyle`（glass / 非 glass 各一）与 `LightButtonStyle`
/// （同样各一）中逐字重复，`CoreBorderlessButtonStyle` 则只有其中两行 padding
/// （审计项 B3d）。
///
/// > 收敛的另一重意义：`CoreControlMetrics.font(for:)` 在按钮体系内的调用点从
/// > 4 处降到 1 处。Issue #95 要把它改成 `fontToken(for:)` + `.coreFont()` 以恢复
/// > Dynamic Type，届时只需改本文件一行。**不要把 font 调用重新散回各 style。**
private struct ButtonChromeModifier<S: Shape>: ViewModifier {
    let shape: S
    let controlSize: ControlSize

    func body(content: Content) -> some View {
        content
            .font(CoreControlMetrics.font(for: self.controlSize))
            .padding(.horizontal, CoreControlMetrics.horizontalPadding(for: self.controlSize))
            .padding(.vertical, CoreControlMetrics.verticalPadding(for: self.controlSize))
            .contentShape(self.shape)
    }
}

// MARK: - View extension

extension View {
    /// 套用按钮通用 chrome（字号 / 内边距 / 命中区域）。
    ///
    /// **有意保持 internal**：这是四个 style 的内部收敛产物，四者都在包内。
    /// 一次纯重构不应顺手对外承诺一个未经设计评审的 modifier——尤其它的
    /// `controlSize` 走显式传参，与仓库其它 modifier 从环境读取的习惯不同。
    /// 若日后要公开，走独立的 API 设计评审。
    ///
    /// - Parameters:
    ///   - shape: 命中区域形状（胶囊、圆形等）。
    ///   - controlSize: 尺寸档，通常来自 `@Environment(\.controlSize)`。
    func buttonChrome(shape: some Shape, controlSize: ControlSize) -> some View {
        self.modifier(ButtonChromeModifier(shape: shape, controlSize: controlSize))
    }
}
