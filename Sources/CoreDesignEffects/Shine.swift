//
//  Shine.swift
//  CoreDesignEffects
//

import CoreDesign
import SwiftUI

/// 一次性高光扫过，**遮罩到内容形状**。典型用途：解锁、升级、徽章点亮。
///
/// ⚠️ 与 `CoreDesign` 的 `.skeletonShimmer()` 不是一回事：那个是骨架屏的**持续**扫光
/// （`TimelineView` 驱动、表示"加载中"），本效果是 `trigger` 驱动的**一次性**高光
/// （表示"这件事刚发生"）。
private struct ShineModifier<T: Equatable & Sendable>: ViewModifier {
    let trigger: T
    let highlight: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let isReduced = self.reduceMotion
        let highlight = self.highlight

        return content
            .overlay {
                GeometryReader { proxy in
                    let travel = proxy.size.width + proxy.size.height

                    LinearGradient(
                        colors: [.clear, highlight, .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: travel * 0.35)
                    .rotationEffect(.degrees(28))
                    .keyframeAnimator(initialValue: -travel, trigger: self.trigger) { view, x in
                        view.offset(x: isReduced ? travel : x)
                    } keyframes: { _ in
                        KeyframeTrack {
                            LinearKeyframe(-travel, duration: 0.05)
                            CubicKeyframe(travel, duration: 0.65)
                        }
                    }
                }
                // ⚠️ **遮罩到内容形状**——高光只在内容内部扫过，不溢出成一个矩形块。
                // 这是本效果与"在外面盖一层渐变"的区别。
                // ⚠️ 遮罩用的是 `content`（被修饰的视图），**不是 `self`**——`self` 是
                // modifier 本身，不是 `View`。
                .mask(content)
                .accessibilityHidden(true)   // 纯装饰（FR-13）
                .allowsHitTesting(false)
            }
    }
}

public extension View {

    /// `trigger` 变化时，让一道高光扫过本视图（遮罩到内容形状）。
    ///
    /// - Parameter highlight: 高光色。默认 `Color.contentPrimary` 的低透明度
    ///   ——⚠️ 不写死白色：深浅外观下"更亮"的方向相反，语义 token 会自动适配。
    func shine(
        trigger: some Equatable & Sendable,
        highlight: Color = .contentPrimary.opacity(0.35)
    ) -> some View {
        self.modifier(ShineModifier(trigger: trigger, highlight: highlight))
    }
}

#Preview("shine") {
    @Previewable @State var unlocked = 0
    VStack(spacing: 40) {
        Text("PRO")
            .font(.largeTitle.bold())
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(Color.accent, in: Capsule())
            .foregroundStyle(Color.contentOnAccent)
            .shine(trigger: unlocked)
        Button("解锁") { unlocked += 1 }
    }
    .padding(60)
}
