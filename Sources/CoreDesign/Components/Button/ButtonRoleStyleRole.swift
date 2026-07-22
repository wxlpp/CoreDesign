//
//  ButtonRoleStyleRole.swift
//  CoreDesign
//
//  Created by 王晓龙 on 2025/2/2.
//

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
    /// 三态优先级：disabled > pressed > normal。此前 `SolidButtonStyle`、
    /// `LightButtonStyle`、`CoreBorderlessButtonStyle` 各自持有一份逐字相同的
    /// 实现，现收敛到本枚举——它本就是三个调色板属性的唯一来源。
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
