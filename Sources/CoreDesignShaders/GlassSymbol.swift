//
//  GlassSymbol.swift
//  CoreDesignShaders
//

import CoreDesign
import SwiftUI

/// 渲染成折射玻璃的 SF Symbol。适合作 App 图标位、空态插图、成就徽章。
///
/// ```swift
/// GlassSymbol("sparkles")
/// GlassSymbol("bolt.fill", tint: .orange, strength: .pronounced)
/// ```
///
/// ⚠️ **不是 `.refractiveGlass()` 的薄封装**：它额外负责符号自身的**填充与背衬**——
/// 只对一个描边符号做折射看不出效果（折射需要有内容可弯折），所以这里先把符号铺成
/// 一层由 `tint` 推导的渐变，再施加折射。
///
/// ⚠️ 与 `Card` 的取舍相反：`Card` 是薄封装、刻意不重造背景；本类型**必须**自带背衬，
/// 否则效果不成立。
public struct GlassSymbol: View {

    private let systemName: String
    private let tint: Color
    private let strength: RefractiveGlassStrength

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// - Parameters:
    ///   - systemName: SF Symbol 名。
    ///   - tint: 渐变背衬的基色。⚠️ 不能走 `.tint` 通路，理由见 `Plasma.init`。
    ///   - strength: 折射强度。
    public init(
        _ systemName: String,
        tint: Color = .accent,
        strength: RefractiveGlassStrength = .regular
    ) {
        self.systemName = systemName
        self.tint = tint
        self.strength = strength
    }

    public var body: some View {
        let ramp = ShaderRamp(tint: self.tint, reduceTransparency: self.reduceTransparency)

        Image(systemName: self.systemName)
            .resizable()
            .scaledToFit()
            .foregroundStyle(
                LinearGradient(
                    colors: [ramp.high, ramp.mid, ramp.low],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            // ⚠️ Reduce Transparency 下关掉折射：折射本质上是"透过看"，
            // 对该偏好的用户应退回实心符号（FR-12）。
            .modifier(
                ConditionalRefraction(
                    enabled: !self.reduceTransparency,
                    strength: self.strength,
                    rim: ramp.high.opacity(0.55)
                )
            )
            // 符号本身承载语义时由调用方给 label；本类型默认当装饰处理（FR-13）。
            .accessibilityHidden(true)
    }
}

/// ⚠️ 单独抽出来是因为 `if` 分支会让两条路径产生不同的 View 身份，
/// 触发不必要的重建；`ViewModifier` 里分支则保持身份稳定。
private struct ConditionalRefraction: ViewModifier {
    let enabled: Bool
    let strength: RefractiveGlassStrength
    let rim: Color

    func body(content: Content) -> some View {
        if self.enabled {
            content.refractiveGlass(corner: CoreRadius.large, strength: self.strength, rim: self.rim)
        } else {
            content
        }
    }
}

#Preview("GlassSymbol") {
    HStack(spacing: 20) {
        GlassSymbol("sparkles")
        GlassSymbol("bolt.fill", strength: .pronounced)
        GlassSymbol("cube.transparent", tint: .purple)
    }
    .frame(height: 96)
    .padding()
}
