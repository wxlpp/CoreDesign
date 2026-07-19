//
//  FunctionalColor.swift
//  CoreDesign
//
//  Created by 王晓龙 on 2025/2/1.
//

import Foundation
import SwiftUI

extension Color {
    @available(*, deprecated, message: "A1 probe: shadows SwiftUI builtin")
    static let primary: Color = .brand5
    @available(*, deprecated, message: "A1 probe: shadows SwiftUI builtin")
    static let primaryActive: Color = .brand7
    @available(*, deprecated, message: "A1 probe: shadows SwiftUI builtin")
    static let primaryDisable: Color = .brand2
    @available(*, deprecated, message: "A1 probe: shadows SwiftUI builtin")
    static let primaryHover: Color = .brand6

    #if Blossom
    @available(*, deprecated, message: "A1 probe: shadows SwiftUI builtin")
    static let secondary: Color = .violet5
    @available(*, deprecated, message: "A1 probe: shadows SwiftUI builtin")
    static let secondaryActive: Color = .violet7
    @available(*, deprecated, message: "A1 probe: shadows SwiftUI builtin")
    static let secondaryDisable: Color = .violet2
    @available(*, deprecated, message: "A1 probe: shadows SwiftUI builtin")
    static let secondaryHover: Color = .violet6
    #else
    @available(*, deprecated, message: "A1 probe: shadows SwiftUI builtin")
    static let secondary: Color = .lightBlue5
    @available(*, deprecated, message: "A1 probe: shadows SwiftUI builtin")
    static let secondaryActive: Color = .lightBlue7
    @available(*, deprecated, message: "A1 probe: shadows SwiftUI builtin")
    static let secondaryDisable: Color = .lightBlue2
    @available(*, deprecated, message: "A1 probe: shadows SwiftUI builtin")
    static let secondaryHover: Color = .lightBlue6
    #endif

    @available(*, deprecated, message: "A1 probe: shadows SwiftUI builtin")

    static let tertiary: Color = .grey5
    @available(*, deprecated, message: "A1 probe: shadows SwiftUI builtin")
    static let tertiaryActive: Color = .grey7
    @available(*, deprecated, message: "A1 probe: shadows SwiftUI builtin")
    static let tertiaryDisable: Color = .grey2
    @available(*, deprecated, message: "A1 probe: shadows SwiftUI builtin")
    static let tertiaryHover: Color = .grey6
}

extension Color {
    static let success: Color = .green5
    static let info: Color = .blue5

    static let warning: Color = .orange5
    static let warningActive: Color = .orange7
    static let warningDisable: Color = .orange2
    static let warningHover: Color = .orange6

    static let danger: Color = .red4
    static let dangerActive: Color = .red7
    static let dangerDisable: Color = .red2
    static let dangerHover: Color = .red6
}
