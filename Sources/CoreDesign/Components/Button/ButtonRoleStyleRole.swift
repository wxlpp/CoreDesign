import Foundation
import SwiftUI

public nonisolated enum ButtonRoleStyleRole: Sendable, Equatable {
    case primary
    case secondary
    case tertiary
    case warning
    case danger

    @MainActor
    public var color: Color {
        switch self {
        case .primary:
            .accent
        case .secondary:
            .secondaryAccent
        case .tertiary:
            .neutralAccent
        case .warning:
            .warning
        case .danger:
            .danger
        }
    }

    @MainActor
    public var activeColor: Color {
        switch self {
        case .primary:
            .accentPressed
        case .secondary:
            .secondaryAccentPressed
        case .tertiary:
            .neutralAccentPressed
        case .warning:
            .warningActive
        case .danger:
            .dangerActive
        }
    }

    @MainActor
    public var disabledColor: Color {
        switch self {
        case .primary:
            .accentDisabled
        case .secondary:
            .secondaryAccentDisabled
        case .tertiary:
            .neutralAccentDisabled
        case .warning:
            .warningDisable
        case .danger:
            .dangerDisable
        }
    }

    /// 压在本 role 底色之上的前景色。
    ///
    /// **五个 role 的底色全部随外观翻转明暗**——`.primary` 是墨色 accent，
    /// 其余四个取自 `ColorGrade`，而 `ColorGrade` 是明暗镜像的（grade N 浅色 ==
    /// grade 9−N 深色）⇒ 前景必须跟着翻转，一律走 `contentOnAccent`（`systemBackground`）。
    ///
    /// iOS 腿实测对比度（白字 vs 反转），是这条裁决的依据：
    ///
    /// | role | 浅色 | 深色·白字 | 深色·反转 |
    /// |---|---|---|---|
    /// | `secondaryAccent` | 9.52:1 | **1.65:1** | 12.73:1 |
    /// | `neutralAccent` | 5.00:1 | 3.35:1 | 6.27:1 |
    /// | `warning` | 2.42:1 | **1.84:1** | 11.39:1 |
    /// | `danger` | 3.73:1 | **2.73:1** | 7.69:1 |
    ///
    /// 浅色档两方案同值（那一档 `systemBackground` 就是白）；深色档白字全部低于
    /// WCAG AA 的 4.5:1，其中三个低于 3:1。
    ///
    /// ⚠️ **本属性存在的意义是留住这个接缝**，不是因为今天五个 role 取值不同：
    /// 压在**固定**饱和色上的前景（`StateLabel` 的 `statusDangerEmphasis` 等、
    /// `Form` 里调用方传入的 tile 底色）必须保持白，走 `contentOnEmphasis`。
    /// 将来若有 role 落在固定色上，在这里分流，不要去改 `contentOnAccent` 本身。
    @MainActor
    public var onColor: Color {
        switch self {
        case .primary, .secondary, .tertiary, .warning, .danger:
            .contentOnAccent
        }
    }

    /// 按交互状态解析出最终颜色 / Resolve the color for a given interaction state.
    ///
    /// ⚠️ 本重载走**静态回退** `Color.accent`，不跟随 `View.coreAccent(_:)`。
    /// 视图层应改调 `resolvedColor(accent:isEnabled:isPressed:)` 并传入
    /// `@Environment(\.coreAccent)`。保留本签名是为了不打断既有调用方。
    ///
    /// - Parameters:
    ///   - isEnabled: 通常来自 `@Environment(\.isEnabled)`。
    ///   - isPressed: 通常来自 `ButtonStyle.Configuration.isPressed`。
    @MainActor
    public func resolvedColor(isEnabled: Bool, isPressed: Bool) -> Color {
        self.resolvedColor(accent: .accent, isEnabled: isEnabled, isPressed: isPressed)
    }

    /// 按交互状态解析出最终颜色，`.primary` role 的三态由传入的 `accent` 现场派生。
    ///
    /// - Parameters:
    ///   - accent: 当前强调色，通常来自 `@Environment(\.coreAccent)`。
    ///   - isEnabled: 通常来自 `@Environment(\.isEnabled)`。
    ///   - isPressed: 通常来自 `ButtonStyle.Configuration.isPressed`。
    @MainActor
    public func resolvedColor(accent: Color, isEnabled: Bool, isPressed: Bool) -> Color {
        guard case .primary = self else {
            if !isEnabled { return self.disabledColor }
            return isPressed ? self.activeColor : self.color
        }
        if !isEnabled { return Color.accentDisabled(from: accent) }
        return isPressed ? Color.accentPressed(from: accent) : accent
    }
}
