//
//  ButtonRoleStyleRole.swift
//  CoreDesign
//
//  Created by 王晓龙 on 2025/2/2.
//

import Foundation
import SwiftUI

public enum ButtonRoleStyleRole {
    case primary
    case secondary
    case tertiary
    case warning
    case danger

    var color: Color {
        switch self {
        case .primary:
            .primary
        case .secondary:
            .secondary
        case .tertiary:
            .tertiary
        case .warning:
            .warning
        case .danger:
            .danger
        }
    }

    var activeColor: Color {
        switch self {
        case .primary:
            .primaryActive
        case .secondary:
            .secondaryActive
        case .tertiary:
            .tertiaryActive
        case .warning:
            .warningActive
        case .danger:
            .dangerActive
        }
    }

    var disabledColor: Color {
        switch self {
        case .primary:
            .primaryDisable
        case .secondary:
            .secondaryDisable
        case .tertiary:
            .tertiaryDisable
        case .warning:
            .warningDisable
        case .danger:
            .dangerDisable
        }
    }
}
