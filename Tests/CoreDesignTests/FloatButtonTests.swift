import SwiftUI
import Testing
@testable import CoreDesign

// MARK: - ExtendedFloatButtonStyle（Issue #170）

@Suite("ExtendedFloatButtonStyle 档位默认值与静态工厂")
@MainActor
struct ExtendedFloatButtonStyleTests {
    @Test("默认初始化落在 .large 档")
    func defaultsToLargeTier() {
        let style = ExtendedFloatButtonStyle()
        #expect(style.size == .large)
    }

    @Test("显式档位被保留")
    func explicitTierIsPreserved() {
        let style = ExtendedFloatButtonStyle(size: .regular)
        #expect(style.size == .regular)
    }

    @Test("静态成员 .extendedFloat 默认落在 .large 档")
    func staticMemberDefaultsToLargeTier() {
        let style: ExtendedFloatButtonStyle = .extendedFloat
        #expect(style.size == .large)
    }

    @Test("静态工厂 .extendedFloat(size:) 透传档位")
    func staticFactoryPassesThroughTier() {
        for size: ControlSize in [.mini, .small, .regular, .large, .extraLarge] {
            let style: ExtendedFloatButtonStyle = .extendedFloat(size: size)
            #expect(style.size == size)
        }
    }
}
