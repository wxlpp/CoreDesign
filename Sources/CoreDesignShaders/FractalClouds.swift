//
//  FractalClouds.swift
//  CoreDesignShaders
//

import CoreDesign
import SwiftUI

/// 分形云层背景。FBM + 域扭曲。
///
/// ⚠️⚠️ **不是自研实现**（PR #261 第 2 轮终审 C-2 改判）。真实来源：
/// **整数 hash** = Thomas Wang（Nathan Reed 2013 的 GPU 版本）；
/// **格点 seed 素数** = Teschner et al. 2003；
/// **域扭曲**（本件为单级，指纹弱于 `InkSmoke`）结构上仍属 iq《Domain Warping》一族。
///
/// ⚠️ **初版把参考实现记成 webgl-noise 系（ashima / stegu / glsl-noise，MIT）是错的**
/// ——那三个是 simplex + permutation 表，本实现是**值噪声**（四角 hash 双线性插值），
/// 与它们没有任何一行对应关系。⇒ 那条引用已删除，不是"改得更准"而是**它本就不成立**。
/// 本仓自有的部分是参数化与调色。
public struct FractalClouds: View {

    /// 云的细腻程度。⚠️ 语义枚举，不暴露"scale + octaves + warp"三个裸旋钮。
    public nonisolated enum Density: Sendable, CaseIterable {
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

        // ⚠️ `ShaderLibrary.bundle(.module)` 在这里（`body`，MainActor 上下文）先取成值，
        // 不在下面的闭包里取——那个闭包是 `@Sendable` 的，`Bundle.module` 是 MainActor
        // 隔离的（#261 终审 I-1）。
        let library = ShaderLibrary.bundle(.module)

        return ProceduralBackground(base: ramp.low, motion: self.motion) { size, t in
            library.coreDesignFractalClouds(
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
