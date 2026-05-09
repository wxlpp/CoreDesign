//
//  BookCover.swift
//  CoreDesign
//
//  Created by AnyWriter on 2026/4/14.
//

import SwiftUI
#if canImport(UIKit)
    import UIKit
#endif
#if canImport(AppKit)
    import AppKit
#endif

// MARK: - BookCover

public struct BookCover: View {
    public init(data: Data?, title: String) {
        self.data = data
        self.title = title
    }

    public static let aspectRatio: CGFloat = 2.0 / 3.0

    public var body: some View {
        Group {
            if let data, let image = Self.image(from: data) {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                BookCoverPlaceholder(title: self.title)
            }
        }
        .aspectRatio(Self.aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 3)
    }

    private let data: Data?
    private let title: String

    private static func image(from data: Data) -> Image? {
        #if canImport(UIKit)
            if let ui = UIImage(data: data) {
                return Image(uiImage: ui)
            }
        #elseif canImport(AppKit)
            if let ns = NSImage(data: data) {
                return Image(nsImage: ns)
            }
        #endif
        return nil
    }
}

// MARK: - BookCoverPlaceholder

public struct BookCoverPlaceholder: View {
    public init(title: String) {
        self.title = title
    }

    public var body: some View {
        let displayTitle = self.title.isEmpty ? "未命名" : self.title
        GeometryReader { proxy in
            let base = Color(text: displayTitle)
            ZStack {
                LinearGradient(
                    colors: [base, base.opacity(0.78)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                VStack {
                    Spacer(minLength: 0)
                    Text(displayTitle)
                        .font(.system(size: max(proxy.size.width * 0.13, 12), weight: .bold))
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .minimumScaleFactor(0.4)
                        .padding(.horizontal, proxy.size.width * 0.12)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .aspectRatio(BookCover.aspectRatio, contentMode: .fit)
    }

    private let title: String
}

// MARK: - BookCoverRenderer

@MainActor
public enum BookCoverRenderer {
    public static func generatePlaceholderData(title: String, width: CGFloat = 320) -> Data? {
        let size = CGSize(width: width, height: width / BookCover.aspectRatio)
        let content = BookCoverPlaceholder(title: title)
            .frame(width: size.width, height: size.height)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 1
        #if canImport(UIKit)
            return renderer.uiImage?.pngData()
        #elseif canImport(AppKit)
            guard let cg = renderer.cgImage else {
                return nil
            }
            let rep = NSBitmapImageRep(cgImage: cg)
            return rep.representation(using: .png, properties: [:])
        #else
            return nil
        #endif
    }
}

#Preview {
    HStack(spacing: 16) {
        BookCover(data: nil, title: "万历十五年")
            .frame(width: 120)
        BookCover(data: nil, title: "A Short Title")
            .frame(width: 120)
        BookCover(data: nil, title: "三体：黑暗森林")
            .frame(width: 120)
    }
    .padding()
}
