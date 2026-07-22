//
//  ProgressBar.swift
//  CoreDesign
//

import SwiftUI

// MARK: - ProgressBar

/// **材质层**: 内容. **表面角色**: 内容.
///
/// 水平进度条。
///
/// 灰色底轨 + 可配置彩色填充 + 可选左侧 label 文本。
public struct ProgressBar: View {
    let value: Double  // 0.0...1.0
    let tint: Color?
    let label: String?

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
                    .coreFont(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // track 高度固定 `CoreSpacing.xs`(4pt)，小于
                    // `CoreRadius.small`(6pt) 的直径——SwiftUI 会把圆角自动 clamp 到
                    // `min(width, height)/2`，实际渲染半径恒为 2pt（= height/2，胶囊
                    // 观感），3→6pt 的换值在这两处**不产生任何可见差异**。
                    CoreShape.rounded(CoreRadius.small)
                        .fill(Color.surfaceCanvasInset)
                    CoreShape.rounded(CoreRadius.small)
                        // 显式 `Color.accent`——避免在 `.fill(_:)` 的 ShapeStyle
                        // 上下文里解析到 SwiftUI 环境 accent。
                        .fill(self.tint ?? Color.accent)
                        .frame(width: geometry.size.width * CGFloat(self.value))
                }
            }
            .frame(height: CoreSpacing.xs)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(self.label.map(Text.init(verbatim:)) ?? Text("Progress", bundle: .module))
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
