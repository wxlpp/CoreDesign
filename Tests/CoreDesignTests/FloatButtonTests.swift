import SwiftUI
import Testing
@testable import CoreDesign

// MARK: - ExtendedFloatButtonStyle（Issue #170）
//
// 本样式主要是视觉合成（胶囊玻璃背景 + 内边距），可提纯的受控逻辑只有
// `size` 档位的存取与静态工厂的透传——按 170.md 的"测试重点"说明，退化为
// "样式可实例化 + 静态成员可访问"的最小编译期验证测试。

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
