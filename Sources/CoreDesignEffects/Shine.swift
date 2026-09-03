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
                    // ⚠️⚠️ **动画量必须是无量纲进度，不能直接用 `travel`**
                    //（第 4 轮终审 C4-1，实测出来的真 bug）：
                    // `keyframeAnimator` 只在**首次求值**时固化 `initialValue`，
                    // 而那一刻 `GeometryReader` 的 `proxy.size` 还是 `.zero`
                    // ⇒ `travel == 0` ⇒ 初值是 **0 而不是 -travel**
                    // ⇒ **光带静息时停在内容正上方，不是界外**，且每次动画结束还会回到
                    // 这个值 ⇒ **永久驻留**的一道浅色斜切。
                    // 实测：`PRO` 胶囊左缘有常驻斜切、`star.fill` 整体被洗淡
                    //（7×16 字形上 max Δ 0.47，与 `.opacity(0.4)` 同量级）。
                    //
                    // ⚠️ 我上一轮把它误判成「`.mask` 强制离屏合成 ⇒ 抗锯齿差异」，
                    // 并据此写了一条「已知例外」测试——**那条测试实际在保护这个 bug**。
                    // 三个对照实验证伪了那个成因：高光设 `.clear` ⇒ 与裸视图逐字节相同；
                    // `Color.clear.mask(content)` ⇒ 逐字节相同；而差异像素**全在字形内部、
                    // 全部变亮**，是一层半透明白盖上去，不是抗锯齿。
                    //
                    // ⇒ 进度归一化到 [-1, 1]，`travel` 在**闭包内**相乘——⚠️ 措辞更正（第 5 轮终审 I5-5）：`travel` 是 `GeometryReader` body 里的 `let`、
                    // **按值捕获**，它随 body **每次求值**更新（不是每帧重算）。
                    // 修复真正成立的理由是另一个：`initialValue` 改成了**无量纲常量 -1**，
                    // 因此不再依赖首次求值时的 size。
                    //   拿得到真实 size。
                    .keyframeAnimator(initialValue: CGFloat(-1), trigger: self.fire) { view, progress in
                        view.offset(x: progress * travel)
                    } keyframes: { _ in
                        KeyframeTrack {
                            LinearKeyframe(-1.0, duration: 0.05)
                            CubicKeyframe(1.0, duration: 0.65)
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

/// `Shine { }` —— **容器视图形态**的一次性高光，包住内容即可用。
///
/// ```swift
/// Shine {
///     Text("PRO").padding().background(Color.accent, in: Capsule())
/// }
/// ```
///
/// ## 为什么它与 `.shine(trigger:)` **并存**（#262 第 1 轮 review 的裁定）
///
/// #250 的 AC 逐字列了 `Shine { }`，且它是八个 API 里**唯一大写**的一项——
/// 大小写不是笔误，是形态：其余七个是 modifier，这一个是容器视图。
/// 初版只落了 `.shine(trigger:)` 并在任务记账里以「`.mask(content)` 在 `ViewModifier`
/// 里可行 ⇒ 上游『必须 wrapper』的前提不成立」为由记为有意偏离——
/// ⚠️ **那条理由回答的是「能不能用 modifier 实现」，而 AC 约束的是「公开 API 长什么样」**，
/// 两者不是同一个问题，所以它不构成偏离 AC 的依据。
///
/// ⇒ 补上容器形态，且**不删** `.shine(trigger:)`，因为二者语义不同：
///
/// - `Shine { }`：**「这块内容刚出现」** —— 出现时扫一次，无需调用方持有状态。
/// - `.shine(trigger:)`：**「这件事刚发生」** —— 由 `trigger` 值变化驱动，
///   可重复触发，且与其余七个微交互同形态、可自由叠加。
///
/// 容器内部**直接复用** `.shine(trigger:)`，没有第二套实现——
/// Reduce Motion 降级、`.mask(content)` 的已知限度全部继承自它。
///
/// ⚠️ 因此 `Shine { }` 同样受下面那条「视图树实例化两次」的限度约束：
/// **不要把带副作用的 modifier 放进 `Shine { }` 之内。**
public struct Shine<Content: View>: View {

    private let highlight: Color
    private let content: Content

    /// ⚠️ 只吃 `Int`——与 `TriggerRelay` 同一约定：泛型不进动画路径。
    @State private var fire = 0

    /// - Parameter highlight: 高光色，默认 `Color.specularHighlight`（第 3 层 token）。
    public init(
        highlight: Color = .specularHighlight,
        @ViewBuilder content: () -> Content
    ) {
        self.highlight = highlight
        self.content = content()
    }

    public var body: some View {
        self.content
            .shine(trigger: self.fire, highlight: self.highlight)
            // ⚠️ `&+=` 而非 `+=`：与 `TriggerRelay` 同一理由（溢出崩比少放一次动画糟）。
            .onAppear { self.fire &+= 1 }
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

#Preview("Shine 容器形态") {
    Shine {
        Text("PRO")
            .font(.largeTitle.bold())
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(Color.accent, in: Capsule())
            .foregroundStyle(Color.contentOnAccent)
    }
    .padding(60)
}
