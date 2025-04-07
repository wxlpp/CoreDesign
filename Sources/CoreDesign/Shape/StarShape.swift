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
        let points = (0 ..< 5).map { i -> CGPoint in
            let angle = (Double(i) * (360.0 / 5.0) - 90) * Double.pi / 180
            let x = center.x + rect.width / 2 * cos(angle)
            let y = center.y + rect.height / 2 * sin(angle)
            return CGPoint(x: x, y: y)
        }

        var path = Path()
        path.move(to: points[0])
        for i in 1 ..< 5 {
            path.addLine(to: points[(i * 2) % 5])
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
