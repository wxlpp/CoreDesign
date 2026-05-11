//
//  ProgressBar.swift
//  CoreDesign
//

import SwiftUI

// MARK: - ProgressBar

/// 水平进度条。
///
/// 灰色底轨 + 可配置彩色填充 + 可选左侧 label 文本。
public struct ProgressBar: View {
    public let value: Double  // 0.0...1.0
    public let tint: Color?
    public let label: String?

    public init(value: Double, tint: Color? = nil, label: String? = nil) {
        // 非有限输入 (NaN / ±infinity) 直接归 0，避免后续 layout / accessibility 计算 trap。
        let sanitized = value.isFinite ? value : 0
        self.value = min(max(sanitized, 0), 1)
        self.tint = tint
        self.label = label
    }

    public var body: some View {
        HStack(spacing: CoreSpacing.sm) {
            if let label = self.label {
                Text(label)
                    .font(CoreTypography.bodySmallFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: CoreRadius.small)
                        .fill(Color.surfaceCanvasInset)
                    RoundedRectangle(cornerRadius: CoreRadius.small)
                        .fill(self.tint ?? .accent)
                        .frame(width: geometry.size.width * CGFloat(self.value))
                }
            }
            .frame(height: CoreSpacing.xs)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(Int(self.value * 100))% complete")
    }
}

#Preview {
    VStack(spacing: 16) {
        ProgressBar(value: 0.0)
        ProgressBar(value: 0.5, label: "50%")
        ProgressBar(value: 1.0, tint: .statusSuccessEmphasis, label: "Done")
    }
    .padding()
}
