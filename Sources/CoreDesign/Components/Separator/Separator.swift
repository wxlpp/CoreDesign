//
//  Separator.swift
//  CoreDesign
//

import SwiftUI

// MARK: - Separator

/// 可控 inset 的分隔线。默认 **hairline 宽度**（1 物理像素，随 `displayScale`），
/// 颜色走第 3 层语义 token `Color.dividerDefault`（其值即系统 `separator` 色），
/// 随系统外观 / 对比度设置自动更新。用语义 token 而非直接的第 2 层 `Color.separator`：
/// 与库内既有分隔线（`UnderlinedTabBar`）一致，且日后 `dividerDefault` 若被重定向
/// 也能自动跟随（参 `borderFocus`/`borderSelected` 曾从固定蓝改指 accent 的先例）。
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
        /// 负值 clamp 到 0——负 inset 会把分隔线向 leading 外扩、溢出父容器边界，
        /// 无实际用途，视作 `.none`（贯穿）。
        var leadingAmount: CGFloat {
            switch self {
            case .none: 0
            case let .leading(amount): max(0, amount)
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
            .fill(Color.dividerDefault)
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
