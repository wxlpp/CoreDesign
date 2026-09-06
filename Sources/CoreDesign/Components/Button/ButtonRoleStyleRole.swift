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

    /// 按交互状态解析出最终颜色 / Resolve the color for a given interaction state.
    ///
    /// - Parameters:
    ///   - isEnabled: 通常来自 `@Environment(\.isEnabled)`。
    ///   - isPressed: 通常来自 `ButtonStyle.Configuration.isPressed`。
    @MainActor
    public func resolvedColor(isEnabled: Bool, isPressed: Bool) -> Color {
        if !isEnabled {
            return self.disabledColor
        }
        return isPressed ? self.activeColor : self.color
    }
}
