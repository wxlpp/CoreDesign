//
//  RefractiveGlass.swift
//  CoreDesignShaders
//

import CoreDesign
import SwiftUI

// MARK: - RefractiveGlassModifier

/// 把内容渲染成一片折射玻璃：圆角矩形区域内做透镜位移 + 边缘高光。
///
/// ⚠️ **与 Apple 的 `.glassEffect()` 是两回事，别混**：
/// · `.glassEffect()` 是 iOS 26 的 **Liquid Glass** 材质，系统实现、随外观自动适配，
///   本仓 `BottomInputBar` / `Carousel` / `SegmentedControl` 用的是它；
/// · 本 modifier 是**自研的 Metal 折射**，把内容当被折射的背景做几何弯折。
/// **需要系统材质就用 `.glassEffect()`**；本 modifier 只在需要可控折射强度/色散时用。
/// ⇒ 命名刻意避开 `glass` 单独成词，防止与系统 API 混淆。
struct RefractiveGlassModifier: ViewModifier {

    let corner: CGFloat
    let strength: RefractiveGlassStrength
    let rim: Color

    func body(content: Content) -> some View {
        content.visualEffect { view, proxy in
            view.layerEffect(
                ShaderLibrary.bundle(.module).coreDesignRefractiveGlass(
                    .float2(proxy.size),
                    .float(self.corner),
                    .float(self.strength.refraction),
                    .float(self.strength.dispersion),
                    .color(self.rim)
                ),
                maxSampleOffset: CGSize(
                    width: CGFloat(self.strength.refraction) * 2,
                    height: CGFloat(self.strength.refraction) * 2
                )
            )
        }
    }
}

// MARK: - Strength

/// 折射强度。⚠️ 语义枚举，不暴露"位移像素数 + 色散系数"两个裸旋钮。
public enum RefractiveGlassStrength: Sendable, CaseIterable {
    case subtle, regular, pronounced

    var refraction: Float {
        switch self {
        case .subtle: 6
        case .regular: 14
        case .pronounced: 26
        }
    }

    /// 色散（三通道分离）。⚠️ `subtle` 档为 0——弱折射配色散会显脏。
    var dispersion: Float {
        switch self {
        case .subtle: 0
        case .regular: 0.25
        case .pronounced: 0.45
        }
    }
}

// MARK: - View

public extension View {

    /// 把本视图渲染成一片折射玻璃。
    ///
    /// ```swift
    /// Image("photo")
    ///     .resizable()
    ///     .refractiveGlass(corner: CoreRadius.large)
    /// ```
    ///
    /// ⚠️ **不吃时间**：折射由几何驱动而非动画，因此不需要 Reduce Motion 降级
    /// （按 FR-12，`layerEffect` 类冻结时间输入、保留空间输入——这里没有时间输入）。
    ///
    /// - Parameters:
    ///   - corner: 玻璃面板的圆角。默认取本仓的 `CoreRadius.medium`。
    ///   - strength: 折射强度档位。
    ///   - rim: 边缘高光色。默认由 `Color.accent` 推导；传 `.clear` 关掉高光。
    ///     ⚠️ 不能走 `.tint` 通路的理由见 `Plasma.init`。
    func refractiveGlass(
        corner: CGFloat = CoreRadius.medium,
        strength: RefractiveGlassStrength = .regular,
        rim: Color = .accent.opacity(0.55)
    ) -> some View {
        self.modifier(
            RefractiveGlassModifier(corner: corner, strength: strength, rim: rim)
        )
    }
}

// MARK: - Preview

#Preview("RefractiveGlass") {
    VStack(spacing: 24) {
        ForEach(Array(RefractiveGlassStrength.allCases.enumerated()), id: \.offset) { _, s in
            ZStack {
                LinearGradient(
                    colors: [.accent, .accentSubtleBackground],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Text("CoreDesign").font(.largeTitle.bold())
            }
            .frame(height: 120)
            .refractiveGlass(strength: s)
            .overlay(alignment: .topLeading) {
                Text(String(describing: s)).font(.caption.monospaced()).padding(6)
            }
        }
    }
    .padding()
}
