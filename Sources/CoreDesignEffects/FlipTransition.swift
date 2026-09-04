//
//  FlipTransition.swift
//  CoreDesignEffects
//
//  卡片翻面转场 / A card-flip transition.
//

import CoreDesign
import SwiftUI

// MARK: - 转场本体

/// 视图进出时像一张卡片那样翻过去：带透视的 3D 旋转 + 淡入淡出。
///
/// ```swift
/// if showsBack {
///     Card { ... }.transition(.flip)
/// }
/// ```
///
/// ## 三层形态
///
/// `FlipTransition`（存参数）→ `FlipChrome`（读 Reduce Motion）→ `FlipMotion`（绘制）。
/// 分层理由、以及本簇与 `ParticleTransition` **有意不同**的两处（不用 `AnyView` /
/// `Animatable` 绑有符号相位），见 `TransitionSupport.swift` 顶部。
///
/// ## 进出两侧朝相反方向转
///
/// 角度直接是 `phaseValue × 90°`：`.willAppear` ⇒ `-90°`、`.identity` ⇒ `0°`、
/// `.didDisappear` ⇒ `+90°`。⚠️ 这是**有符号**的，`abs` 之后进出两侧会塌成同一个数
/// ——那样"翻进来"和"翻出去"看起来是同一个动作倒放，卡片翻面的方向感就没了。
///
/// ## Reduce Motion
///
/// 旋转门控到 `0°`，只剩 `TransitionCurve.opacity` 的淡入淡出
///（#251 给整簇定的「位移 / 旋转类降级为淡入淡出」）。⚠️ **不是 no-op**。
/// 走**降级形态 2**（保留呈现、去掉运动、不叠透明度脉冲）。
///
/// ## ⚠️ 系统还有一道同向的闸，别把它当成本转场不必降级的理由
///
/// `Transition.properties` 默认是 `TransitionProperties(hasMotion: true)`，Apple 文档
/// 逐字写着 *"When true, the transition is replaced by opacity when Reduce Motion is
/// enabled"* ⇒ 系统**也**会替换掉整个转场。本簇六个转场**都保留默认值**（它们确实含运动，
/// 谎报 `hasMotion: false` 会把系统那道闸关掉）。
///
/// ⇒ 于是同一件事有两道闸：系统那道在外、本文件的三元门控在内。**两道都要**：
/// · 系统那道是 SwiftUI 的实现细节，替换发生在哪一层、对 `.combined(with:)` /
///   `AnyTransition` 包装是否仍然成立，都不在契约里；
/// · 本仓的 `MicroInteractionReduceMotionGuard` 量的是**本文件里每一处运动有没有门控**,
///   它是机器能查的那一道。
/// ⇒ 内层门控是**冗余**的、不是**多余**的，这条区别照录在此，免得下一个人把它删了。
public struct FlipTransition: Transition {

    /// 绕哪个轴翻。命名按"内容看起来往哪个方向转"，见 `TransitionAxis3D`。
    public let axis: TransitionAxis3D

    /// 两端的翻转角（度）。90° = 恰好侧对镜头。
    ///
    /// ⚠️ `public` 且住在本类型上：`ParticleTransition.defaultCount` 记着同一条纪律
    ///（`public` 签名的默认实参不许引用 internal 符号）。
    /// ⚠️ **`nonisolated` 是必需的、不是装饰**：本包开了 `.defaultIsolation(MainActor.self)`，
    /// 而下面的几何函数住在 `nonisolated enum Flip` 里 ⇒ 不标就是
    /// `main actor-isolated static property … can not be referenced from a nonisolated context`
    ///（实测一条警告；Swift 6 语言模式下这类跨隔离读迟早会升级成错误）。
    public nonisolated static let quarterTurn: Double = 90

    public init(axis: TransitionAxis3D = .horizontal) {
        self.axis = axis
    }

    public func body(content: Content, phase: TransitionPhase) -> some View {
        content.modifier(FlipChrome(phaseValue: TransitionCurve.value(of: phase), axis: self.axis))
    }
}

// MARK: - 层 2：读 Reduce Motion

/// 唯一职责：把 `\.accessibilityReduceMotion` 降成一个普通 `Bool` 实参。
///
/// ⚠️ **本层不做任何绘制**——判据 `TransitionTests.chromeOnlyFeedsReduceMotionDown`
/// 逐文件数 `self.reduceMotion` 的出现次数必须恰好等于 `isReduced: self.reduceMotion`
/// 的次数：任何"顺手在这里再判一次"的写法都会判红（形态同
/// `MicroInteractionReduceMotionGuard.reduceMotionIsOnlyConsumedByTheSharedGate`）。
struct FlipChrome: ViewModifier {

    let phaseValue: Double
    let axis: TransitionAxis3D

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.modifier(
            FlipMotion(phaseValue: self.phaseValue, axis: self.axis, isReduced: self.reduceMotion)
        )
    }
}

// MARK: - 层 3：绘制（纯输入 + Animatable）

/// 给定相位值画出一帧。**不读环境、不读时间**——因此判据可以把同一个相位分别用
/// `isReduced: true` / `false` 渲两遍逐字节比较。
struct FlipMotion: ViewModifier, Animatable {

    var phaseValue: Double
    let axis: TransitionAxis3D
    let isReduced: Bool

    /// ⚠️ 绑在**有符号**的相位值上，理由见 `TransitionSupport.swift` 顶部。
    var animatableData: Double {
        get { self.phaseValue }
        set { self.phaseValue = newValue }
    }

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(self.isReduced ? 0 : Flip.angle(at: self.phaseValue)),
                axis: self.axis.vector,
                perspective: Flip.perspective
            )
            .opacity(TransitionCurve.opacity(self.phaseValue))
    }
}

// MARK: - 几何（纯函数）

nonisolated enum Flip {

    /// 透视强度。0 = 正交投影（翻起来像被压扁的矩形，没有"卡片"感）。
    static let perspective: CGFloat = 0.55

    /// 相位值 → 翻转角（度）。**恒等恰为 0**，两端 ±`quarterTurn`。
    ///
    /// ⚠️ 钳位走 `TransitionCurve.distance` 那条同款理由：带过冲的动画曲线会让
    /// `animatableData` 越过 ±1，不钳会翻过 90° 露出背面。
    static func angle(at phaseValue: Double) -> Double {
        let clamped = max(-1, min(1, phaseValue))
        return clamped * FlipTransition.quarterTurn
    }
}

// MARK: - 公开入口点（`Transition` 的静态成员）

public extension Transition where Self == FlipTransition {

    /// 卡片翻面转场（水平翻）。
    ///
    /// ```swift
    /// Card { ... }.transition(.flip)
    /// ```
    static var flip: FlipTransition { FlipTransition() }

    /// 卡片翻面转场，可指定翻转轴。
    ///
    /// ⚠️ 与无参 `flip` 按 `Host.member` 去重，**算同一种转场**（#251：计数单位是
    /// 「一种 transition」不是「一个静态成员」）。
    static func flip(axis: TransitionAxis3D) -> FlipTransition {
        FlipTransition(axis: axis)
    }
}

#Preview("flip") {
    @Previewable @State var shown = true
    VStack(spacing: CoreSpacing.xxl) {
        ZStack {
            if shown {
                Text("FLIP")
                    .font(.largeTitle.bold())
                    .padding(CoreSpacing.xxl)
                    .surface(.content)
                    .transition(.flip)
            }
        }
        .frame(height: 140)

        Button("切换") { withAnimation(.easeInOut(duration: 0.6)) { shown.toggle() } }
    }
    .padding(CoreSpacing.huge)
}
