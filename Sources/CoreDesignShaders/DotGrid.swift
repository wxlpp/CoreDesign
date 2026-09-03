//
//  DotGrid.swift
//  CoreDesignShaders
//

import CoreDesign
import SwiftUI

/// 规则点阵背景，可选同心波呼吸。
///
/// ⚠️ **自研实现，非移植**——网格 + 圆点是最基础的程序化图案，属思路层。
/// ⚠️ **上一版的「射程限定」引了本 shader 没用到的原语**（第 3 轮终审 C-1）：
/// 它写着用到 `wangHash` / `hash21` / `hash22`，而 `coreDesignDotGrid` 的函数体
/// **一次 hash 都没调**，只用 `cd::edgeWidth`（`fwidth` 的下限兜底）。
/// 真实构成是「格点取模 + 到圆心距离 + `smoothstep` 抗锯齿圆盘」——
/// 抗锯齿圆盘的写法是公开做法，逐项交代见 `CoreDesignShaders.metal` 原语区。
/// ⚠️ 点的边缘用 `fwidth` 做屏幕空间抗锯齿，因此在任何分辨率下边宽一致
/// （不是固定像素值）。
public struct DotGrid: View {

    /// 点距。⚠️ 语义枚举，不暴露"格数 + 半径"两个裸旋钮。
    public nonisolated enum Spacing: Sendable, CaseIterable {
        case loose, regular, tight

        var metrics: (spacing: Float, radius: Float) {
            switch self {
            case .loose: (10, 0.16)
            case .regular: (18, 0.18)
            case .tight: (30, 0.22)
            }
        }
    }

    private let tint: Color
    private let spacing: Spacing
    private let motion: ShaderMotion

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// - Parameter motion: `.still` 时**完全静态**（呼吸振幅为 0），适合作纹理底。
    public init(
        tint: Color = .accent,
        spacing: Spacing = .regular,
        motion: ShaderMotion = .still
    ) {
        self.tint = tint
        self.spacing = spacing
        self.motion = motion
    }

    public var body: some View {
        let ramp = ShaderRamp(tint: self.tint, reduceTransparency: self.reduceTransparency)
        let metrics = self.spacing.metrics
        let pulse: Float = self.motion == .still ? 0 : 1

        // ⚠️ `ShaderLibrary.bundle(.module)` 在这里（`body`，MainActor 上下文）先取成值，
        // 不在下面的闭包里取——那个闭包是 `@Sendable` 的，`Bundle.module` 是 MainActor
        // 隔离的（#261 终审 I-1）。
        let library = ShaderLibrary.bundle(.module)

        return ProceduralBackground(base: ramp.low, motion: self.motion) { size, t in
            library.coreDesignDotGrid(
                .float2(size), .float(t),
                .float(metrics.spacing), .float(metrics.radius), .float(pulse),
                .color(ramp.low), .color(ramp.mid)
            )
        }
    }
}

#Preview("DotGrid") {
    VStack(spacing: 0) {
        ForEach(Array(DotGrid.Spacing.allCases.enumerated()), id: \.offset) { _, s in
            DotGrid(spacing: s, motion: .calm)
                .overlay(alignment: .topLeading) {
                    Text(String(describing: s)).font(.caption.monospaced()).padding(8)
                }
        }
    }
    .ignoresSafeArea()
}
