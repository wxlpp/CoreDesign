//
//  Starfield.swift
//  CoreDesignShaders
//

import CoreDesign
import SwiftUI

/// 程序化星空背景。网格分格 + 每格一颗随机星，亮度按距离衰减、相位各自独立。
///
/// ⚠️ **自研实现，非移植**——网格 hash + 亮度衰减是程序化星空的公开做法，属思路层。
public struct Starfield: View {

    /// 星密度。⚠️ 一个语义枚举，而不是"格数"这个裸数值。
    public enum Density: Sendable, CaseIterable {
        case sparse, regular, dense

        var cells: Float {
            switch self {
            case .sparse: 14
            case .regular: 24
            case .dense: 38
            }
        }
    }

    private let tint: Color
    private let density: Density
    private let motion: ShaderMotion

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// - Parameters:
    ///   - tint: 星的颜色。天空色由它推导（`ShaderRamp.low`）。默认 `Color.accent`。
    ///     ⚠️ 不能走 `.tint` 通路的理由见 `Plasma.init` 的说明。
    ///   - motion: `.still` 时星**不闪烁**（不是"闪得慢"）。
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
        // ⚠️ `.still` ⇒ 闪烁振幅为 0。Reduce Motion 由 `ProceduralBackground` 冻结时间，
        // 两条路径都会让画面静止，但语义不同：前者是调用方要静态，后者是系统偏好。
        let twinkle: Float = self.motion == .still ? 0 : 1
        let cells = self.density.cells

        ProceduralBackground(base: ramp.low, motion: self.motion) { size, t in
            ShaderLibrary.bundle(.module).coreDesignStarfield(
                .float2(size), .float(t),
                .float(cells), .float(twinkle),
                .color(ramp.low), .color(ramp.high)
            )
        }
    }
}

#Preview("Starfield") {
    VStack(spacing: 0) {
        ForEach(Array(Starfield.Density.allCases.enumerated()), id: \.offset) { _, d in
            Starfield(density: d)
                .overlay(alignment: .topLeading) {
                    Text(String(describing: d)).font(.caption.monospaced()).padding(8)
                }
        }
    }
    .ignoresSafeArea()
}
