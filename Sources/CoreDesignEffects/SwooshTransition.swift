import CoreDesign
import SwiftUI

// MARK: - 转场本体

/// 视图**穿行而过**：从一侧飞进来、从另一侧飞出去，途中带一层随速度增强的动态模糊。
public struct SwooshTransition: Transition {
    /// 进场从哪一侧来（出场去对侧）。
    public let edge: Edge

    /// 行程档位。
    public let travel: TransitionTravel

    public init(edge: Edge = .trailing, travel: TransitionTravel = .regular) {
        self.edge = edge
        self.travel = travel
    }

    /// 系统那道 Reduce Motion 闸：**必须是 `true`**。理由与判据见 `FlipTransition.properties`。
    public nonisolated static var properties: TransitionProperties { .init(hasMotion: true) }

    public func body(content: Content, phase: TransitionPhase) -> some View {
        content.modifier(
            SwooshChrome(
                phaseValue: TransitionCurve.value(of: phase),
                edge: self.edge,
                points: self.travel.points
            )
        )
    }
}

// MARK: - 层 2：读 Reduce Motion

struct SwooshChrome: ViewModifier {
    let phaseValue: Double
    let edge: Edge
    let points: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.modifier(
            SwooshMotion(
                phaseValue: self.phaseValue,
                edge: self.edge,
                points: self.points,
                isReduced: self.reduceMotion
            )
        )
    }
}

// MARK: - 层 3：绘制（纯输入 + Animatable）

struct SwooshMotion: ViewModifier, Animatable {
    var phaseValue: Double
    let edge: Edge
    let points: CGFloat
    let isReduced: Bool

    var animatableData: Double {
        get { self.phaseValue }
        set { self.phaseValue = newValue }
    }

    func body(content: Content) -> some View {
        let stretch = Swoosh.stretch(at: self.phaseValue, along: self.edge)
        let travel = Swoosh.travel(at: self.phaseValue, along: self.edge, points: self.points)
        return content
            .scaleEffect(
                x: self.isReduced ? 1 : stretch.width,
                y: self.isReduced ? 1 : stretch.height
            )
            .offset(
                x: self.isReduced ? 0 : travel.width,
                y: self.isReduced ? 0 : travel.height
            )
            .blur(radius: self.isReduced ? 0 : Swoosh.blurRadius(at: self.phaseValue))
            .opacity(TransitionCurve.opacity(self.phaseValue))
    }
}

// MARK: - 几何（纯函数）

nonisolated enum Swoosh {
    static let maximumBlur: CGFloat = 6

    static let maximumStretch: CGFloat = 0.16

    static func travel(at phaseValue: Double, along edge: Edge, points: CGFloat) -> CGSize {
        let clamped = CGFloat(max(-1, min(1, phaseValue)))
        let unit = TransitionCurve.direction(of: edge)
        return CGSize(width: -unit.width * clamped * points, height: -unit.height * clamped * points)
    }

    static func stretch(at phaseValue: Double, along edge: Edge) -> CGSize {
        let amount = Self.maximumStretch * CGFloat(TransitionCurve.distance(phaseValue))
        let unit = TransitionCurve.direction(of: edge)
        return CGSize(
            width: 1 + amount * abs(unit.width),
            height: 1 + amount * abs(unit.height)
        )
    }

    static func blurRadius(at phaseValue: Double) -> CGFloat {
        Self.maximumBlur * CGFloat(TransitionCurve.distance(phaseValue))
    }
}

// MARK: - 公开入口点（`Transition` 的静态成员）

public extension Transition where Self == SwooshTransition {
    /// 带动态模糊的穿行转场（默认从右侧进、左侧出）。
    static var swoosh: SwooshTransition { SwooshTransition() }

    /// 带动态模糊的穿行转场，可指定进场边与行程。
    static func swoosh(edge: Edge = .trailing, travel: TransitionTravel = .regular) -> SwooshTransition {
        SwooshTransition(edge: edge, travel: travel)
    }
}

#Preview("swoosh") {
    @Previewable @State var index = 0
    VStack(spacing: CoreSpacing.xxl) {
        ZStack {
            Text(verbatim: "#\(index)")
                .font(.largeTitle.bold())
                .padding(CoreSpacing.xxl)
                .surface(.content)
                .transition(.swoosh)
                .id(index)
        }
        .frame(height: 140)

        Button("下一页") { withAnimation(.easeInOut(duration: 0.5)) { index += 1 } }
    }
    .padding(CoreSpacing.huge)
}
