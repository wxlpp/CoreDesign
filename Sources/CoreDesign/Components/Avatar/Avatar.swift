//
//  Avatar.swift
//  CoreDesign
//
//  Created by 王晓龙 on 2025/1/29.
//

import SwiftUI

// MARK: - Avatar

public struct Avatar: View {
    public init(name: String) {
        self.name = name
    }

    public var body: some View {
        let size = CGSize(width: 50, height: 50)
        let firstCharacter = String(name.prefix(1).uppercased())

        Image(size: size, label: Text(self.name)) { context in
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Color(text: self.name))
            )
            context.draw(
                Text(firstCharacter)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Color.white),
                at: CGPoint(x: size.width / 2, y: size.height / 2)
            )
        }
        .resizable()
        .aspectRatio(contentMode: .fill)
    }

    let name: String
}

#Preview {
    Avatar(name: "A").frame(width: 100, height: 100).clipShape(Circle())
}
