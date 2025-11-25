//
//  ColorExtension.swift
//  CoreDesign
//
//  Created by 王晓龙 on 2025/1/29.
//

import Foundation
import SwiftUI

extension Color {
    private static let predefinedColors: [Color] = [
        .red, .green, .blue, .orange, .purple, .pink, .yellow, .cyan, .mint, .indigo
    ]

    public init(text: String) {
        let utf8Values = text.utf8.map { UInt32($0) }
        let sum = utf8Values.reduce(0, +)
        let index = Int(sum % UInt32(Color.predefinedColors.count))
        self = Color.predefinedColors[index]
    }
}
