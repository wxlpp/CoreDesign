//
//  LiquidChrome.swift
//  CoreDesignShaders
//

import CoreDesign
import SwiftUI

/// 液态铬背景。域扭曲后的坐标喂给正弦带，形成金属反射那种窄亮高光带 + 宽暗过渡。
///
/// ⚠️ **自研实现**。与 `InkSmoke` / `FractalClouds` 同属域扭曲噪声派生，差别在
/// **扭曲后的用法**：那两个把扭曲结果直接当密度，本类型把它喂给正弦带并额外加一层
/// 高光收窄（`pow(1 - |raw - 0.5| * 2, 3)`）——金属感来自这里，不是来自噪声本身。
///
/// ⚠️ 带边用 `fwidth` 做屏幕空间抗锯齿，避免高频带在缩放下出现摩尔纹。
public struct LiquidChrome: View {

    /// 带的疏密。⚠️ 语义枚举。
    public enum Density: Sendable, CaseIterable {
        case wide, regular, fine

        var field: (scale: Float, bands: Float, flow: Float) {
            switch self {
            case .wide: (2.0, 6, 0.8)
            case .regular: (3.0, 11, 1.2)
            case .fine: (4.0, 18, 1.6)
            }
        }
    }

    private let tint: Color
    private let density: Density
    private let motion: ShaderMotion

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init(
        tint: Color = .accent,
        density: Density = .regular,
        motion: ShaderMotion = .calm
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
            library.coreDesignLiquidChrome(
                .float2(size), .float(t),
                .float(field.scale), .float(field.bands), .float(field.flow),
                .color(ramp.low), .color(ramp.mid), .color(ramp.high)
            )
        }
    }
}

#Preview("LiquidChrome") {
    VStack(spacing: 0) {
        ForEach(Array(LiquidChrome.Density.allCases.enumerated()), id: \.offset) { _, d in
            LiquidChrome(density: d)
                .overlay(alignment: .topLeading) {
                    Text(String(describing: d)).font(.caption.monospaced()).padding(8)
                }
        }
    }
    .ignoresSafeArea()
}
