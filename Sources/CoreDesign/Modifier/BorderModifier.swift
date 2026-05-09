//
//  BorderModifier.swift
//  CoreDesign
//
//  Created by 王晓龙 on 2025/1/30.
//

import Foundation
import SwiftUI

// MARK: - BorderModifier

struct BorderModifier: ViewModifier {
    var style: AnyShapeStyle
    var width: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(self.style, lineWidth: self.width)
            )
    }
}

public extension View {
    func bordered(style: some ShapeStyle = Color.borderDefault, width: CGFloat = 1) -> some View {
        self.modifier(BorderModifier(style: AnyShapeStyle(style), width: width))
    }

    func bordered(color: Color = .borderDefault, width: CGFloat = 1) -> some View {
        self.modifier(BorderModifier(style: AnyShapeStyle(color), width: width))
    }
}
