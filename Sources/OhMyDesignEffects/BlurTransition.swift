import OhMyDesign
import SwiftUI

// MARK: - 转场本体

/// 视图进出时内容失焦并淡出（进入时反向合焦）。
public struct BlurTransition: Transition {
    /// 完全进入前 / 完全离开后的模糊半径（pt）。
    public let radius: CGFloat

    /// 默认模糊半径。
    public nonisolated static let defaultRadius: CGFloat = 12

    /// 显式退出框架在 Reduce Motion 下的 opacity 替换（协议默认值是 `true`）。
    public nonisolated static let properties = TransitionProperties(hasMotion: false)

    public init(radius: CGFloat = BlurTransition.defaultRadius) {
        self.radius = radius
    }

    public func body(content: Content, phase: TransitionPhase) -> some View {
        content.modifier(BlurTransitionChrome(phase: phase, radius: self.radius))
    }
}

struct BlurTransitionChrome: ViewModifier {
    let phase: TransitionPhase
    let radius: CGFloat

    func body(content: Content) -> some View {
        let progress = FilterTransitionPhase.progress(phase: self.phase)
        return content
            .blur(radius: BlurFilm.radius(progress: progress, maximum: self.radius))
            .opacity(BlurFilm.contentOpacity(progress: progress))
    }
}

// MARK: - 曲线（纯函数，生产代码与判据共用同一份）

nonisolated enum BlurFilm {
    static func radius(progress: Double, maximum: CGFloat) -> CGFloat {
        let sane = maximum.isFinite ? Swift.max(maximum, 0) : 0
        return sane * CGFloat(FilterTransitionPhase.clamped01(progress))
    }

    static func contentOpacity(progress: Double) -> Double {
        1 - FilterTransitionPhase.clamped01(progress)
    }
}

// MARK: - 公开入口点（`Transition` 的静态成员）

public extension Transition where Self == BlurTransition {
    /// 失焦转场。
    static var blur: BlurTransition { BlurTransition() }

    /// 失焦转场，可指定模糊半径。
    static func blur(radius: CGFloat = BlurTransition.defaultRadius) -> BlurTransition {
        BlurTransition(radius: radius)
    }
}

#Preview("BlurTransition") {
    @Previewable @State var shown = true
    VStack(spacing: CoreSpacing.xxl) {
        ZStack {
            if shown {
                Text("Focus")
                    .font(.largeTitle.bold())
                    .padding(CoreSpacing.xxl)
                    .background(Color.surfaceRaised, in: RoundedRectangle(cornerRadius: CoreRadius.large))
                    .transition(.blur)
            }
        }
        .frame(height: 140)

        Button("切换") { withAnimation(.easeInOut(duration: 0.55)) { shown.toggle() } }
    }
    .padding(CoreSpacing.huge)
}
