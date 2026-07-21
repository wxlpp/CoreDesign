//
//  CoreFontModifier.swift
//  CoreDesign
//

import SwiftUI

// MARK: - CoreFontModifier

/// 施加一个 `CoreTypography.Token`：字号 + lineSpacing 随 Dynamic Type 缩放，tracking 固定。
///
/// 为何是 modifier 而非 `Font` 常量：缩放靠 `@ScaledMetric`，它需要 View 上下文。
/// 旧的 `CoreTypography.*Font`（`.system(size:)` 固定值）**不缩放**——那正是 B2a 要修的。
private struct CoreFontModifier: ViewModifier {
    let token: CoreTypography.Token
    @ScaledMetric private var scaledSize: CGFloat
    @ScaledMetric private var scaledLineSpacing: CGFloat

    init(_ token: CoreTypography.Token) {
        self.token = token
        let spec = token.spec
        // 缩放档：以 token 基准 pt 为「标准尺寸下的值」，随 spec.textStyle 的曲线缩放。
        // 固定档（captionSmall）：ScaledMetric 照存但 body 不读它，用 spec.size 原值。
        self._scaledSize = ScaledMetric(wrappedValue: spec.size, relativeTo: spec.textStyle)
        self._scaledLineSpacing = ScaledMetric(wrappedValue: spec.lineSpacing, relativeTo: spec.textStyle)
    }

    func body(content: Content) -> some View {
        let spec = self.token.spec
        let size = spec.scales ? self.scaledSize : spec.size
        let lineSpacing = spec.scales ? self.scaledLineSpacing : spec.lineSpacing
        let font: Font = spec.monospaced
            ? .system(size: size, weight: spec.weight).monospaced()
            : .system(size: size, weight: spec.weight)
        return content
            .font(font)
            .lineSpacing(lineSpacing)
            .tracking(spec.tracking)
    }
}

// MARK: - View extension

public extension View {
    /// 施加 CoreDesign 排版 token（字号 + lineSpacing 随 Dynamic Type 缩放）。
    ///
    /// 取代旧的 `.font(CoreTypography.xxxFont)` + 手写 `.lineSpacing()`——三件套
    /// （font / lineSpacing / tracking）收进单一调用点。
    func coreFont(_ token: CoreTypography.Token) -> some View {
        self.modifier(CoreFontModifier(token))
    }
}
