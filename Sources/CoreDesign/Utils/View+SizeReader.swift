//
//  View+SizeReader.swift
//  any-writer
//
//  Created by GitHub Copilot on 2026/3/31.
//

import SwiftUI

// MARK: - ViewSizePreferenceKey

private struct ViewSizePreferenceKey: @MainActor PreferenceKey {
    @MainActor static var defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

// MARK: - SizeReaderModifier

private struct SizeReaderModifier: ViewModifier {
    @Binding var size: CGSize

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: ViewSizePreferenceKey.self, value: proxy.size)
                }
            )
            .onPreferenceChange(ViewSizePreferenceKey.self) { newSize in
                guard self.lastSize != newSize else {
                    return
                }
                self.lastSize = newSize
                self.size = newSize
            }
    }

    @State private var lastSize: CGSize = .zero
}

extension View {
    /// Reads the rendered size of this view and reports changes.
    /// - Parameter size: A binding to store the current rendered size.
    /// - Returns: A view that reports its current size.
    func getSize(_ size: Binding<CGSize>) -> some View {
        modifier(SizeReaderModifier(size: size))
    }
}
