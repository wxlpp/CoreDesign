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
/// ⚠️ **非泛型**——理由见 `TriggerRelay`。
private struct ShineCore: ViewModifier {
    let fire: Int
    let highlight: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let isReduced = self.reduceMotion
        let highlight = self.highlight

        // ⚠️ **Reduce Motion 下不画光带，降级为脉冲**（#262 终审 I1）。
        // 初版把光带停在出界位置 ⇒ RM 下**零反馈**，与本模块"降级不是什么都不做"的
        // 原则自相矛盾。
        guard !isReduced else {
            return AnyView(content.reduceMotionFallback(active: true, trigger: self.fire))
        }

        return AnyView(content
            .overlay {
                GeometryReader { proxy in
                    let travel = proxy.size.width + proxy.size.height

                    LinearGradient(
                        colors: [.clear, highlight, .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: travel * 0.35, height: travel)
                    .rotationEffect(.degrees(28))
                    .keyframeAnimator(initialValue: -travel, trigger: self.fire) { view, x in
                        view.offset(x: x)
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
            })
    }
}

public extension View {

    /// `trigger` 变化时，让一道高光扫过本视图（遮罩到内容形状）。
    ///
    /// ⚠️⚠️ **已知限度：本 modifier 会把被修饰内容的视图树实例化两次**
    ///（#262 第 3 轮终审 I-3，评审用计数视图实测：裸视图 body 求值 1 次、
    /// 加 `.shine()` 后 **2 次**）。成因是 `content` 同时被用作「被修饰视图」与
    /// 「遮罩」——`.mask(content)`。
    ///
    /// 后果不只是性能：内容里带副作用的 modifier 会跑两遍
    /// （`onAppear` 打点、`task {}`、`@FocusState` 自动聚焦——CLAUDE.md 记的
    /// `BottomInputBar.autoFocus` 就是这类）。而本模块鼓励叠加，
    /// `view.haptic(.success, trigger: n).shine(trigger: n)` 会把 `sensoryFeedback`
    /// 一并复制进遮罩副本。
    /// ⇒ **不要把带副作用的 modifier 放在 `.shine()` 之内。**
    ///
    /// ⚠️ 同一成因还让 `.shine()` 成为八个效果里**唯一改变静息位图**的一个
    /// （`mask` 强制内容离屏合成 ⇒ 抗锯齿变化），已由
    /// `MicroInteractionAPITests.shineIsTheKnownException` 钉住。
    ///
    /// - Parameter highlight: 高光色，默认 `Color.specularHighlight`（第 3 层 token）。
    ///
    ///   ⚠️ **初版默认值是 `Color.contentPrimary.opacity(0.35)`，理由还写反了**
    ///   （「深浅外观下更亮的方向相反，语义 token 会自动适配」）：`contentPrimary`
    ///   就是 `.label`，浅色外观下近黑 ⇒ 浅色下扫过去的是一道 **35% 的黑带**。
    ///   `label` 保证的是「与背景**对比**」，**不是**「比背景**亮**」。
    ///   本仓 #162 / 评审 #176 已就同一件事出过裁决（见 `Color.specularHighlight`）。
    func shine(
        trigger: some Equatable,
        highlight: Color = .specularHighlight
    ) -> some View {
        self.modifier(
            TriggerRelay(trigger: trigger) { ShineCore(fire: $0, highlight: highlight) }
        )
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
