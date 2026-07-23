//
//  BorderModifier.swift
//  CoreDesign
//
//  Created by 王晓龙 on 2025/1/30.
//

import Foundation
import SwiftUI

// MARK: - BorderModifier

/// 在视图外缘叠加一圈描边 / Overlay a border stroke on the view's edge.
///
/// 用 `strokeBorder` 而非 `stroke`：前者向**内**画线，描边完整落在
/// 形状边界内；后者以路径为中心向两侧各画半个线宽，会溢出 `width / 2`。全仓其余
/// 描边（`SurfaceModifier`、`TelegramGlassButtonModifier`、`ButtonBackgroundModifier`）
/// 用的都是 `strokeBorder`，本 modifier 现与之对齐。
///
/// 形状泛型化：原先写死圆角矩形（半径固定取 `CoreRadius.none`），
/// `cornerRadius: 0` 时既误导又无法用于 `Capsule`。约束取 `InsettableShape` 而非
/// `Shape`——`strokeBorder` 只对前者可用。
struct BorderModifier<S: InsettableShape, Style: ShapeStyle>: ViewModifier {
    var shape: S
    var style: Style
    var width: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay(
                self.shape
                    .strokeBorder(self.style, lineWidth: self.width)
            )
    }
}

public extension View {
    /// 叠加一圈描边 / Add a border.
    ///
    /// > 原先还有一个 `bordered(color:width:)` 重载，因 `Color` 已 conform
    /// > `ShapeStyle` 而与本方法完全重叠；两者参数又全带默认值，裸写 `.bordered()`
    /// > 构成重载歧义。该重载已删除。
    ///
    /// - Parameters:
    ///   - style: 描边样式，任意 `ShapeStyle`（含 `Color` 与渐变）。
    ///   - width: 线宽，默认 `CoreBorderWidth.thin`。
    ///   - shape: 描边形状，默认 `Rectangle()`（直角矩形）；pill 传 `Capsule()`、圆形传 `Circle()`。
    func bordered(
        style: some ShapeStyle = Color.borderDefault,
        width: CGFloat = CoreBorderWidth.thin,
        shape: some InsettableShape = Rectangle()
    ) -> some View {
        self.modifier(BorderModifier(shape: shape, style: style, width: width))
    }
}
