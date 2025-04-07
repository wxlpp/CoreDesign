//
//  Avatar.swift
//  CoreDesign
//
//  Created by 王晓龙 on 2025/1/29.
//

import SwiftUI

public struct Avatar: View {
    let name: String

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
            context.draw(Text(firstCharacter).font(.system(size: 30, weight: .bold)).foregroundStyle(Color.white), at: CGPoint(x: size.width / 2, y: size.height / 2))
        }
        .resizable()
        .aspectRatio(contentMode: .fill)
    }
}

extension Avatar {
    public struct VStack<Content: View>: View {
        var spacing: CGFloat = 0

        var content: () -> Content

        public init(spacing: CGFloat, @ViewBuilder content: @escaping () -> Content) {
            self.spacing = spacing
            self.content = content
        }

        public var body: some View {
            OverlayVStack(spacing: self.spacing) {
                self.content()
            }
        }
    }

    public struct HStack<Content: View>: View {
        var spacing: CGFloat = 0

        var content: () -> Content

        public init(spacing: CGFloat, @ViewBuilder content: @escaping () -> Content) {
            self.spacing = spacing
            self.content = content
        }

        public var body: some View {
            OverlayHStack(spacing: self.spacing) {
                self.content()
            }
        }
    }
}

#Preview {
    Avatar(name: "A").frame(width: 100, height: 100).clipShape(StarShape())
    Avatar.VStack(spacing: 20) {
        Group {
            Avatar(name: "A")
            Avatar(name: "b")
            Avatar(name: "王")
            Avatar(name: "abcd")
        }
        .frame(width: 40, height: 40)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.systemBackground, lineWidth: 2))
    }
    Avatar.HStack(spacing: 20) {
        Group {
            Avatar(name: "A")
            Avatar(name: "b")
            Avatar(name: "王")
            Avatar(name: "abcd")
        }
        .frame(width: 40, height: 40)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.systemBackground, lineWidth: 2))
    }
}
