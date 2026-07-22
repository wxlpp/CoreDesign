//
//  CoreTypography.swift
//  CoreDesign
//

import CoreGraphics
import SwiftUI

// MARK: - CoreTypography

/// 字体 token，对齐 Apple HIG 的系统文本样式（`Font.TextStyle`）标度。
///
/// 调用方式：
///
/// ```swift
/// Text("Hello, world.")
///     .coreFont(.body)
/// ```
///
/// ## 设计取舍（Issue #119）
///
/// 早期版本对齐 GitHub Primer Primitives 的 `text.*` 标度，携带手写的 size / weight /
/// lineSpacing / tracking 四件套，并用 `@ScaledMetric` 模拟 Dynamic Type 缩放。
/// 本文件改为**直接取系统文本样式**：12 档 `Token` 一一对应 `Font.TextStyle`
/// （`largeTitle` / `title` / `title2` / `title3` / `headline` / `body` / `callout` /
/// `subheadline` / `footnote` / `caption` / `caption2`；`captionMono` 额外映射
/// `.caption` + 等宽 design）。字号、行高、字重、Dynamic Type 缩放全部交给系统本身，
/// 不再手写任何字号表——这是与旧版本的核心差异，也是本文件不再需要 `Spec` 结构体、
/// `lineSpacing` / `tracking` 常量的原因。
///
/// > Note: 9 个旧名（`displayLarge` 等）保留为 `@available(*, deprecated, renamed:)`
/// > 别名，供调用点按 warning 逐点迁移（Issue #121）。别名本身由 #121 完成迁移后删除。
public nonisolated enum CoreTypography {

    // MARK: - Token（Dynamic Type 入口）

    /// 排版 token，经 `.coreFont(_:)` 施加。每一档直接对应一个 Apple 系统文本样式，
    /// 字号 / 行高 / 字重 / Dynamic Type 缩放全部由系统决定。
    public enum Token: CaseIterable {
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

        // MARK: - Deprecated renamed aliases（Issue #119）
        //
        // 映射固定，逐字沿用 PRD FR-1 / 119.md AC 的改名表，由 Task #121 按 warning
        // 迁移调用点后删除本组别名。`caption` / `captionMono` 名字不变（同名换语义，
        // 归 Task #122），无需别名。

        @available(*, deprecated, renamed: "largeTitle")
        public static var displayLarge: Token { .largeTitle }

        @available(*, deprecated, renamed: "title")
        public static var titleLarge: Token { .title }

        @available(*, deprecated, renamed: "title2")
        public static var titleMedium: Token { .title2 }

        @available(*, deprecated, renamed: "title3")
        public static var subtitle: Token { .title3 }

        @available(*, deprecated, renamed: "headline")
        public static var titleSmall: Token { .headline }

        @available(*, deprecated, renamed: "body")
        public static var bodyLarge: Token { .body }

        @available(*, deprecated, renamed: "callout")
        public static var bodyMedium: Token { .callout }

        @available(*, deprecated, renamed: "footnote")
        public static var bodySmall: Token { .footnote }

        @available(*, deprecated, renamed: "caption2")
        public static var captionSmall: Token { .caption2 }
    }

    // MARK: - Deprecated legacy `*Font` static vars（Issue #119）
    //
    // 旧版本这 10 个 static var 经 `Token.fixedFont`（`.system(size:weight:)`，固定不缩放）
    // 实现。`fixedFont` 机制已随本次重写删除，这里改为直接返回等价新 `Token.font`
    // （系统文本样式，会随 Dynamic Type 缩放）。
    //
    // > Important: **这是一次静默行为变化**——旧实现固定字号，新实现体必然随 Dynamic
    // > Type 缩放。过渡期短（Task #125 即删除本组别名）且已知调用点只有 App 宿主的
    // > Previews / `Avatar.swift:55`，可接受；但如果你依赖其"固定字号不缩放"的旧语义，
    // > 请改用 `Token.<新名>.font` 并自行决定是否需要固定，不要继续依赖本别名。

    @available(*, deprecated, message: "改用 .coreFont(.largeTitle)；行为变化：新实现随 Dynamic Type 缩放，旧实现是固定字号。")
    public static var displayLargeFont: Font { Token.largeTitle.font }

    @available(*, deprecated, message: "改用 .coreFont(.title)；行为变化：新实现随 Dynamic Type 缩放，旧实现是固定字号。")
    public static var titleLargeFont: Font { Token.title.font }

    @available(*, deprecated, message: "改用 .coreFont(.title2)；行为变化：新实现随 Dynamic Type 缩放，旧实现是固定字号。")
    public static var titleMediumFont: Font { Token.title2.font }

    @available(*, deprecated, message: "改用 .coreFont(.headline)；行为变化：新实现随 Dynamic Type 缩放，旧实现是固定字号。")
    public static var titleSmallFont: Font { Token.headline.font }

    @available(*, deprecated, message: "改用 .coreFont(.title3)；行为变化：新实现随 Dynamic Type 缩放，旧实现是固定字号。")
    public static var subtitleFont: Font { Token.title3.font }

    @available(*, deprecated, message: "改用 .coreFont(.body)；行为变化：新实现随 Dynamic Type 缩放，旧实现是固定字号。")
    public static var bodyLargeFont: Font { Token.body.font }

    @available(*, deprecated, message: "改用 .coreFont(.callout)；行为变化：新实现随 Dynamic Type 缩放，旧实现是固定字号。")
    public static var bodyMediumFont: Font { Token.callout.font }

    @available(*, deprecated, message: "改用 .coreFont(.footnote)；行为变化：新实现随 Dynamic Type 缩放，旧实现是固定字号。")
    public static var bodySmallFont: Font { Token.footnote.font }

    @available(*, deprecated, message: "改用 .coreFont(.caption)；行为变化：新实现随 Dynamic Type 缩放，旧实现是固定字号。")
    public static var captionFont: Font { Token.caption.font }

    @available(*, deprecated, message: "改用 .coreFont(.caption2)；行为变化尤其显著：captionSmall 原本故意设计为不缩放的固定 9pt chrome 字号，新实现（caption2）会随 Dynamic Type 缩放。")
    public static var captionSmallFont: Font { Token.caption2.font }
}
