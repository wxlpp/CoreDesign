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
/// > Note: 9 个旧名（`displayLarge` 等）与 10 个旧 `*Font` static var 曾以
/// > `@available(*, deprecated, renamed:)` / `deprecated(message:)` 别名保留，供调用点
/// > 按 warning 逐点迁移；Task #121 完成全部调用点迁移后已删除这两组别名。
public nonisolated enum CoreTypography {

    // MARK: - Token（Dynamic Type 入口）

    /// 排版 token，经 `.coreFont(_:)` 施加。每一档直接对应一个 Apple 系统文本样式，
    /// 字号 / 行高 / 字重 / Dynamic Type 缩放全部由系统决定。
    ///
    /// `Sendable`（Issue #123 补）：caseless 枚举本身平凡线程安全，显式声明让
    /// `Testing` 的 `@Test(arguments:)` 能把它跨 `@MainActor` 隔离边界传参
    /// （`DynamicTypeLayoutTests.everyTypographyTokenScalesWithDynamicType`）。
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
