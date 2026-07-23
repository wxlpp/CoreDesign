//
//  Separator.swift
//  CoreDesign
//

import SwiftUI

// MARK: - Separator

/// 可控 inset 的分隔线。默认 **hairline 宽度**（1 物理像素，随 `displayScale`），
/// 颜色走 `Color.separator` 系统色，随系统外观 / 对比度设置自动更新。
///
/// `inset` 复刻 iOS 分组列表的分隔线惯例：行间分隔线从 leading 缩进一段，
/// 与「图标之后的文本」对齐，而非贯穿整行。
///
/// ```swift
/// Separator()                       // 贯穿
/// Separator(inset: .leading(CoreSpacing.xl))  // leading 缩进 24pt
/// ```
public struct Separator: View {
    /// 分隔线的 leading 缩进方式。
    public enum Inset: Equatable, Sendable {
        /// 无缩进，分隔线贯穿父容器整宽。
        case none
        /// 从 leading 缩进指定量（pt）。
        case leading(CGFloat)

        /// leading 缩进量（pt）。`internal` 而非 `fileprivate`：供 `@testable` 断言映射。
        var leadingAmount: CGFloat {
            switch self {
            case .none: 0
            case let .leading(amount): amount
            }
        }
    }

    @Environment(\.displayScale) private var displayScale

    private let inset: Inset

    public init(inset: Inset = .none) {
        self.inset = inset
    }

    public var body: some View {
        Rectangle()
            .fill(Color.separator)
            // hairline：1 物理像素。`displayScale` 保证 @2x/@3x 屏上都是最细的一线，
            // 而非固定 1pt（在 @3x 上会显粗）。
            .frame(height: 1.0 / self.displayScale)
            .frame(maxWidth: .infinity)
            .padding(.leading, self.inset.leadingAmount)
    }
}

#Preview("Separator — Light") {
    SeparatorPreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("Separator — Dark") {
    SeparatorPreviewGallery()
        .preferredColorScheme(.dark)
}

private struct SeparatorPreviewGallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.lg) {
            VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                Text("贯穿").coreFont(.footnote).foregroundStyle(.secondary)
                Separator()
            }
            VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                Text("leading 缩进（xl = 24pt）").coreFont(.footnote).foregroundStyle(.secondary)
                Separator(inset: .leading(CoreSpacing.xl))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.surfaceCanvas)
    }
}
