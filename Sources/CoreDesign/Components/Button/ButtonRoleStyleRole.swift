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
    /// ⚠️ 只有 `.primary` 坐在 `accent` 上、随主题反转（`contentOnAccent`）；
    /// 其余四个 role 的底色是**固定饱和色**，前景保持白（`contentOnEmphasis`）——
    /// 一刀切会让 `.danger` / `.warning` 在深色下变成黑字压红 / 橙底。
    @MainActor
    public var onColor: Color {
        switch self {
        case .primary:
            .contentOnAccent
        case .secondary, .tertiary, .warning, .danger:
            .contentOnEmphasis
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
