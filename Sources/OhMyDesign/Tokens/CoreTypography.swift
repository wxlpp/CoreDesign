import CoreGraphics
import SwiftUI

// MARK: - CoreTypography

/// 字体 token，对齐 Apple HIG 的系统文本样式（`Font.TextStyle`）标度。
public nonisolated enum CoreTypography {
    // MARK: - Token（Dynamic Type 入口）

    /// 排版 token，经 `.coreFont(_:)` 施加。每一档直接对应一个 Apple 系统文本样式，
    /// 字号 / 行高 / 字重 / Dynamic Type 缩放全部由系统决定。
    public enum Token: CaseIterable, Sendable {
        case largeTitle
        case title
        case title2
        case title3
        case headline
        case body
        case callout
        case subheadline
        case footnote
        case caption
        case captionMono
        case caption2

        /// 对应的系统文本样式（Dynamic Type 缩放基准）。
        public var textStyle: Font.TextStyle {
            switch self {
            case .largeTitle: .largeTitle
            case .title: .title
            case .title2: .title2
            case .title3: .title3
            case .headline: .headline
            case .body: .body
            case .callout: .callout
            case .subheadline: .subheadline
            case .footnote: .footnote
            case .caption: .caption
            case .captionMono: .caption
            case .caption2: .caption2
            }
        }

        /// 是否为等宽字体。目前仅 `captionMono` 为真。
        public var isMonospaced: Bool {
            self == .captionMono
        }

        /// 直接取系统文本样式 `Font`，随 Dynamic Type 缩放。
        public var font: Font {
            self.isMonospaced
                ? .system(self.textStyle, design: .monospaced)
                : .system(self.textStyle)
        }
    }
}
