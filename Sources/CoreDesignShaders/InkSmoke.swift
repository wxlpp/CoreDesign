//
//  InkSmoke.swift
//  CoreDesignShaders
//

import CoreDesign
import SwiftUI

/// 墨烟背景。两级域扭曲 + 陡对比，读起来是丝缕而非团块。
///
/// ⚠️ **自研实现**。与 `FractalClouds` 同属噪声派生，差别在**扭曲级数与对比曲线**：
/// 云是一级扭曲 + 线性斜坡，烟是两级扭曲 + `smoothstep(0.28, 0.72)` 的陡对比。
/// 参考实现同 `FractalClouds`（webgl-noise 系，MIT）。
public struct InkSmoke: View {

    /// 丝缕强度。⚠️ 语义枚举。
    public enum Density: Sendable, CaseIterable {
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
