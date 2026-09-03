//
//  Plasma.swift
//  CoreDesignShaders
//

import CoreDesign
import SwiftUI

/// 程序化等离子背景。适合作 onboarding / paywall / 启动页的底层。
///
/// ```swift
/// ZStack {
///     Plasma().ignoresSafeArea()
///     content
/// }
/// ```
///
/// ⚠️ **自研实现，非移植**——正弦叠加 + 调色斜坡是公开配方，属思路层。
/// 差异化依据见 `docs/shader-provenance.md`《第三条出路：自研实现》。
public struct Plasma: View {

    /// 视觉密度。⚠️ 一个语义枚举，而不是"频率 + 叠加层数"两个裸旋钮。
    public enum Density: Sendable, CaseIterable {
        case subtle, regular, dense

        var field: (frequency: Float, octaves: Float) {
            switch self {
            case .subtle: (4.0, 1)
            case .regular: (7.0, 2)
            case .dense: (11.0, 3)
            }
        }
    }

    private let tint: Color
    private let density: Density
    private let motion: ShaderMotion

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// - Parameter tint: 调色基色，三档斜坡由它推导。默认 `Color.accent`。
    ///
    ///   ⚠️ **这里不能走 `.tint` 通路，与 `.core` control style 的规矩不同**——那条规矩
    ///   成立的前提是 `ShapeStyle` 能直接喂给 SwiftUI 绘制；Metal 需要**具体的颜色分量**，
    ///   而 SwiftUI **没有公开 API 能把 `.tint` 读成 `Color`**。⇒ 只能走 FR-8 的第①条
    ///   合法来源「调用方参数」，默认值取第③条「语义 token」。**这不是漏了 `.tint` 通路。**
    public init(
        tint: Color = .accent,
        density: Density = .regular,
        motion: ShaderMotion = .regular
    ) {
        self.tint = tint
        self.density = density
        self.motion = motion
    }

    public var body: some View {
        let ramp = ShaderRamp(tint: self.tint, reduceTransparency: self.reduceTransparency)
        let field = self.density.field

        // ⚠️ `ShaderLibrary.bundle(.module)` 在这里（`body`，MainActor 上下文）先取成值，
        // 不在下面的闭包里取——那个闭包是 `@Sendable` 的，`Bundle.module` 是 MainActor
        // 隔离的（#261 终审 I-1）。
        let library = ShaderLibrary.bundle(.module)

        return ProceduralBackground(base: ramp.low, motion: self.motion) { size, t in
            library.coreDesignPlasma(
                .float2(size),
                .float(t),
                .float(field.frequency),
                .float(field.octaves),
                .color(ramp.low),
                .color(ramp.mid),
                .color(ramp.high)
            )
        }
    }
}

#Preview("Plasma") {
    VStack(spacing: 0) {
        ForEach(Array(Plasma.Density.allCases.enumerated()), id: \.offset) { _, d in
            Plasma(density: d)
                .overlay(alignment: .topLeading) {
                    Text(String(describing: d)).font(.caption.monospaced()).padding(8)
                }
        }
    }
    .ignoresSafeArea()
}
