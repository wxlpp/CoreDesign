//
//  ProgressIndicator.swift
//  CoreDesign
//

import SwiftUI

// MARK: - ProgressIndicator

/// **材质层**: 内容. **表面角色**: 内容.
///
/// 通用圆形加载指示器。
///
/// 封装系统 `ProgressView`，使用 `Color.accent` 作为 tint，自动响应
/// `@Environment(\.controlSize)` 调整尺寸。
public struct ProgressIndicator: View {
    public init() {}

    @Environment(\.controlSize) private var controlSize

    public var body: some View {
        ProgressView()
            .progressViewStyle(.circular)
            // 显式 `Color.accent`——避免在 `tint(_:)` 多个 ShapeStyle 重载之间
            // 解析到 SwiftUI 自带的环境 accent，而不是 CoreDesign 的 `Color.accent`。
            .tint(Color.accent)
            .controlSize(self.controlSize)
            .accessibilityLabel(Text("Loading", bundle: .module))
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
