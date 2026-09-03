//
//  InkSmoke.swift
//  CoreDesignShaders
//

import CoreDesign
import SwiftUI

/// 墨烟背景。两级域扭曲 + 陡对比，读起来是丝缕而非团块。
///
/// ⚠️⚠️ **不是自研实现**（PR #261 第 2 轮终审 C-2 改判）。逐层交代真实来源：
/// - **域扭曲的级联结构**派生自 Inigo Quilez《Domain Warping》的公开片段
///   （三级 `q` / `r` 级联，连变量名都保留；本仓只把倍率参数化、换了偏移常数）；
/// - **整数 hash** 是 Thomas Wang 的构造（Nathan Reed 2013 的 GPU 版本）；
/// - **格点 seed 的素数三元组**出自 Teschner et al. 2003。
///
/// ⚠️ **初版这里写的参考实现是 webgl-noise 系（ashima / stegu / glsl-noise，MIT）
/// ——那三个是 simplex + permutation 表，与本实现没有任何一行对应关系。**
/// 等于引用了一个许可干净但**实际没用到**的来源，而真正的影响源一个没写。
/// 本仓自有的部分只是**参数化与调色**：扭曲级数、`smoothstep(0.28, 0.72)` 的陡对比、
/// 以及经 `ShaderRamp` 的三档取色。
public struct InkSmoke: View {

    /// 丝缕强度。⚠️ 语义枚举。
    public nonisolated enum Density: Sendable, CaseIterable {
        case faint, regular, heavy

        var field: (scale: Float, octaves: Float, wisp: Float) {
            switch self {
            case .faint: (3.0, 3, 0.8)
            case .regular: (4.5, 4, 1.4)
            case .heavy: (6.5, 5, 2.2)
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
            library.coreDesignInkSmoke(
                .float2(size), .float(t),
                .float(field.scale), .float(field.octaves), .float(field.wisp),
                .color(ramp.low), .color(ramp.mid), .color(ramp.high)
            )
        }
    }
}

#Preview("InkSmoke") {
    VStack(spacing: 0) {
        ForEach(Array(InkSmoke.Density.allCases.enumerated()), id: \.offset) { _, d in
            InkSmoke(density: d)
                .overlay(alignment: .topLeading) {
                    Text(String(describing: d)).font(.caption.monospaced()).padding(8)
                }
        }
    }
    .ignoresSafeArea()
}
