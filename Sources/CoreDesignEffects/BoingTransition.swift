//
//  BoingTransition.swift
//  CoreDesignEffects
//
//  弹性缩放转场 / An elastic pop transition.
//

import CoreDesign
import SwiftUI

// MARK: - 转场本体

/// 视图弹进来：从很小放大、**越过原尺寸**再回落坐定；离开时反过来。
///
/// ```swift
/// if unlocked {
///     Badge("PRO").transition(.boing)
/// }
/// ```
///
/// ## ⚠️⚠️ 「弹」这件事只能靠 `Animatable`，不能靠调用方的 `.bouncy`
///
/// `TransitionPhase` 是 3 case frozen enum ⇒ `body(content:phase:)` 只拿得到
/// `-1` / `0` / `1` 三个值。如果只把最终的 scale 交给 SwiftUI 去插值，
/// 两端之间得到的是一条**直线**——过冲整个消失，"弹"从未发生。
///
/// ⇒ `BoingMotion` conform `Animatable`、`animatableData` 绑在**相位值**上：
/// SwiftUI 逐帧把相位插到中间，本文件再把它过一遍阻尼余弦
///（`TransitionCurve.elastic`）⇒ 过冲画得出来。
///
/// ⚠️ **不指望调用方写 `withAnimation(.bouncy)`**：那把"这个转场叫 boing"这件事
/// 变成了调用点的责任，且换一条曲线就不弹了。判据
/// `TransitionClusterTests.boingOvershootSurvivesInterpolation` 钉的正是"**渲染出来的那一帧**
/// 比恒等帧更大"，它对"只靠调用方曲线"的实现判红。
///
/// ## Reduce Motion
///
/// 缩放门控到 `1`，只剩淡入淡出。走**降级形态 2**。
/// ⚠️ **缩放算运动**——`#250` 第 1 轮的 `Jump` 正是漏门控了 `scaleEffect`。
/// 系统那道 `TransitionProperties.hasMotion` 闸与本层门控的分工，见 `FlipTransition`。
public struct BoingTransition: Transition {

    /// 弹多狠。
    ///
    /// ⚠️ **复用 `MicroInteractionStrength`**（本仓唯一的强度枚举），但**不复用它的
    /// `scaleDelta`**：那三个数是 0.06 / 0.14 / 0.24，量级是"轻轻胀一下"，
    /// 用在整段入场上根本看不出弹性。映射另写在 `Boing.amplitude(for:)`，理由记在那里。
    public let strength: MicroInteractionStrength

    public init(strength: MicroInteractionStrength = .regular) {
        self.strength = strength
    }

    /// 系统那道 Reduce Motion 闸：**必须是 `true`**。理由与判据见 `FlipTransition.properties`。
    public nonisolated static var properties: TransitionProperties { .init(hasMotion: true) }

    public func body(content: Content, phase: TransitionPhase) -> some View {
        content.modifier(
            BoingChrome(
                phaseValue: TransitionCurve.value(of: phase),
                amplitude: Boing.amplitude(for: self.strength)
            )
        )
    }
}

// MARK: - 层 2：读 Reduce Motion

/// 唯一职责：把 `\.accessibilityReduceMotion` 降成一个普通 `Bool` 实参。见 `FlipChrome`。
struct BoingChrome: ViewModifier {

    let phaseValue: Double
    let amplitude: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.modifier(
            BoingMotion(
                phaseValue: self.phaseValue,
                amplitude: self.amplitude,
                isReduced: self.reduceMotion
            )
        )
    }
}

// MARK: - 层 3：绘制（纯输入 + Animatable）

struct BoingMotion: ViewModifier, Animatable {

    var phaseValue: Double
    let amplitude: Double
    let isReduced: Bool

    var animatableData: Double {
        get { self.phaseValue }
        set { self.phaseValue = newValue }
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(self.isReduced ? 1 : Boing.scale(at: self.phaseValue, amplitude: self.amplitude))
            .opacity(TransitionCurve.opacity(self.phaseValue))
    }
}

// MARK: - 几何（纯函数）

nonisolated enum Boing {

    /// 阻尼余弦走几个周期。1.25 ⇒ 一次明显的过冲 + 一次很小的回弹。
    ///
    /// ⚠️ 调大它会让"弹"变成"抖"；调到 < 0.5 则余弦在窗口内不换号，过冲消失
    /// （判据 `TransitionClusterTests.elasticCurvesActuallyOvershoot` 会判红）。
    static let cycles: Double = 1.25

    /// 强度 → 弹性振幅（也就是两端缩到 `1 - amplitude`）。
    ///
    /// ⚠️ **不用 `MicroInteractionStrength.scaleDelta`**：那三个数（0.06 / 0.14 / 0.24）
    /// 是给"胀一下再回去"的微交互调的；入场转场要从"几乎看不见"长到原尺寸，
    /// `.regular` 用 0.14 的话起手就是 0.86 倍——和不做缩放没有区别。
    static func amplitude(for strength: MicroInteractionStrength) -> Double {
        switch strength {
        case .subtle: 0.35
        case .regular: 0.6
        case .pronounced: 0.85
        }
    }

    /// 相位值 → 缩放。**恒等恰为 1**，两端 `1 - amplitude`，中途越过 1（过冲）。
    static func scale(at phaseValue: Double, amplitude: Double) -> CGFloat {
        CGFloat(1 - TransitionCurve.elastic(phaseValue, amplitude: amplitude, cycles: Self.cycles))
    }
}

// MARK: - 公开入口点（`Transition` 的静态成员）

public extension Transition where Self == BoingTransition {

    /// 弹性缩放转场。
    ///
    /// ```swift
    /// Badge("PRO").transition(.boing)
    /// ```
    static var boing: BoingTransition { BoingTransition() }

    /// 弹性缩放转场，可指定强度。
    ///
    /// ⚠️ 与无参 `boing` 按 `Host.member` 去重，**算同一种转场**（#251）。
    static func boing(strength: MicroInteractionStrength) -> BoingTransition {
        BoingTransition(strength: strength)
    }
}

#Preview("boing") {
    @Previewable @State var shown = true
    VStack(spacing: CoreSpacing.xxl) {
        ZStack {
            if shown {
                Text("BOING")
                    .font(.largeTitle.bold())
                    .padding(CoreSpacing.xxl)
                    .surface(.content)
                    .transition(.boing(strength: .pronounced))
            }
        }
        .frame(height: 140)

        Button("切换") { withAnimation(.easeInOut(duration: 0.7)) { shown.toggle() } }
    }
    .padding(CoreSpacing.huge)
}
