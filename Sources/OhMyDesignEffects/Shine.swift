import OhMyDesign
import SwiftUI

private struct ShineCore: ViewModifier {
    let fire: Int
    let highlight: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let isReduced = self.reduceMotion
        let highlight = self.highlight

        guard !isReduced else {
            return AnyView(content.reduceMotionFallback(active: true, trigger: self.fire))
        }

        return AnyView(content
            .overlay {
                GeometryReader { proxy in
                    let travel = proxy.size.width + proxy.size.height

                    ShineBand.gradient(travel: travel, highlight: highlight)
                    .keyframeAnimator(
                        initialValue: ShineBand.initialProgress,
                        trigger: self.fire
                    ) { view, progress in
                        view.offset(x: ShineBand.offset(progress: progress, travel: travel))
                    } keyframes: { _ in
                        ShineBand.track()
                    }
                }
                .mask(content)
                .accessibilityHidden(true)
                .allowsHitTesting(false)
            })
    }
}

enum ShineBand {
    nonisolated static let initialProgress: CGFloat = -1

    nonisolated static let terminalProgress: CGFloat = 1

    nonisolated static let widthRatio: CGFloat = 0.35

    nonisolated static let tilt: Angle = .degrees(28)

    nonisolated static func offset(progress: CGFloat, travel: CGFloat) -> CGFloat {
        progress * travel
    }

    static func gradient(travel: CGFloat, highlight: Color) -> some View {
        LinearGradient(
            colors: [.clear, highlight, .clear],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(width: travel * Self.widthRatio, height: travel)
        .rotationEffect(Self.tilt)
    }

    nonisolated static func track() -> some Keyframes<CGFloat> {
        KeyframeTrack {
            LinearKeyframe(Self.initialProgress, duration: 0.05)
            CubicKeyframe(Self.terminalProgress, duration: 0.65)
        }
    }
}

/// `Shine { }` —— **容器视图形态**的一次性高光，包住内容即可用。
public struct Shine<Content: View>: View {
    private let highlight: Color
    private let content: Content

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
            .onAppear { self.fire &+= 1 }
    }
}

public extension View {
    /// `trigger` 变化时，让一道高光扫过本视图（遮罩到内容形状）。
    ///
    /// ⚠️ 本 modifier 会把被修饰内容的视图树实例化两次——不要把带副作用的 modifier
    /// （`onAppear` 打点 / `task {}` / `@FocusState`）放在 `.shine()` 之内。
    ///
    /// - Parameter highlight: 高光色，默认 `Color.specularHighlight`（第 3 层 token）。
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
