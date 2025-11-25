//
//  StarShape.swift
//  CoreDesign
//
//  Created by 王晓龙 on 2025/1/30.
//

import SwiftUI

public struct StarShape: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.width / 2, y: rect.height / 2)
        let points = (0 ..< 5).map { index -> CGPoint in
            let angle = (Double(index) * (360.0 / 5.0) - 90) * Double.pi / 180
            let pointX = center.x + rect.width / 2 * cos(angle)
            let pointY = center.y + rect.height / 2 * sin(angle)
            return CGPoint(x: pointX, y: pointY)
        }

        var path = Path()
        path.move(to: points[0])
        for index in 1 ..< 5 {
            path.addLine(to: points[(index * 2) % 5])
        }
        path.closeSubpath()
        return path
    }
}

#Preview {
    StarShape()
        .stroke(Color.blue, lineWidth: 2)
        .frame(width: 100, height: 100)
}
