//
//  ProgressIndicator.swift
//  CoreDesign
//

import SwiftUI

// MARK: - ProgressIndicator

/// 通用圆形加载指示器。
///
/// 封装系统 `ProgressView`，使用 Primer `accent` 色作为 tint，自动响应
/// `@Environment(\.controlSize)` 调整尺寸。
public struct ProgressIndicator: View {
    public init() {}

    @Environment(\.controlSize) private var controlSize

    public var body: some View {
        ProgressView()
            .progressViewStyle(.circular)
            .tint(.accent)
            .controlSize(self.controlSize)
            .accessibilityLabel("Loading")
    }
}

#Preview {
    VStack(spacing: 20) {
        ProgressIndicator()
            .controlSize(.small)
        ProgressIndicator()
            .controlSize(.regular)
        ProgressIndicator()
            .controlSize(.large)
    }
    .padding()
}
