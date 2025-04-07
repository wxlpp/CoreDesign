//
//  BorderModifier.swift
//  CoreDesign
//
//  Created by 王晓龙 on 2025/1/30.
//

import Foundation
import SwiftUI

struct BorderModifier: ViewModifier {
    var color: Color
    var width: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(self.color, lineWidth: self.width)
            )
    }
}

extension View {
    public func bordered(color: Color = .red, width: CGFloat = 1) -> some View {
        self.modifier(BorderModifier(color: color, width: width))
    }
}
