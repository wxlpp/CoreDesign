//
//  FractalClouds.swift
//  CoreDesignShaders
//

import CoreDesign
import SwiftUI

/// 分形云层背景。FBM + 域扭曲。
///
/// ⚠️ **自研实现**，但 FBM 原语参考了许可已核的公开实现
/// （[ashima](https://github.com/ashima/webgl-noise) / [stegu](https://github.com/stegu/webgl-noise)
/// / [glsl-noise](https://github.com/hughsk/glsl-noise)，均 **MIT**）。
/// ⚠️ 本仓实现用的是**值噪声**（四角 hash 双线性插值）而非 simplex——更简单、
/// 对本用途足够，且不复制那些实现的具体表达。见 `docs/shader-provenance.md`。
public struct FractalClouds: View {

    /// 云的细腻程度。⚠️ 语义枚举，不暴露"scale + octaves + warp"三个裸旋钮。
    public enum Density: Sendable, CaseIterable {
        case soft, regular, turbulent

        var field: (scale: Float, octaves: Float, warp: Float) {
            switch self {
            case .soft: (2.5, 3, 0.6)
            case .regular: (4.0, 4, 1.1)
            case .turbulent: (6.0, 5, 1.8)
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

        ProceduralBackground(base: ramp.low, motion: self.motion) { size, t in
            ShaderLibrary.bundle(.module).coreDesignFractalClouds(
                .float2(size), .float(t),
                .float(field.scale), .float(field.octaves), .float(field.warp),
                .color(ramp.low), .color(ramp.mid), .color(ramp.high)
            )
        }
    }
}

#Preview("FractalClouds") {
    VStack(spacing: 0) {
        ForEach(Array(FractalClouds.Density.allCases.enumerated()), id: \.offset) { _, d in
            FractalClouds(density: d)
                .overlay(alignment: .topLeading) {
                    Text(String(describing: d)).font(.caption.monospaced()).padding(8)
                }
        }
    }
    .ignoresSafeArea()
}
