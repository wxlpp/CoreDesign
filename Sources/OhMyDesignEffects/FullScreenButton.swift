import OhMyDesign
import SwiftUI

/// 一张可点的卡片，点开时**几何匹配地放大成整屏**——App Store / 照片 / 音乐里
/// 那种"卡片自己长成一页"的效果，而不是从底部滑上来一个模态。
public struct FullScreenButton<Label: View, Destination: View>: View {
    static var sourceID: String { "ohmydesign.fullScreenButton" }

    private let destination: () -> Destination
    private let label: Label

    @Namespace private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameters:
    ///   - destination: 展开后的整屏内容。
    ///   - label: collapsed 状态下的卡片。
    public init(
        @ViewBuilder destination: @escaping () -> Destination,
        @ViewBuilder label: () -> Label
    ) {
        self.destination = destination
        self.label = label()
    }

    public var body: some View {
        let plan = FullScreenTransitionPlan.resolve(
            reduceMotion: self.reduceMotion,
            platformSupportsZoom: FullScreenTransitionPlan.platformSupportsZoom
        )
        NavigationLink {
            FullScreenButtonDestination(plan: plan, sourceID: Self.sourceID, namespace: self.namespace) {
                self.destination()
            }
        } label: {
            self.label
                .matchedTransitionSource(id: Self.sourceID, in: self.namespace)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 目的地

struct FullScreenButtonDestination<Content: View>: View {
    let plan: FullScreenTransitionPlan
    let sourceID: String
    let namespace: Namespace.ID
    @ViewBuilder let content: Content

    var body: some View {
        if self.plan == .zoom {
            #if os(iOS)
            self.content
                .navigationTransition(.zoom(sourceID: self.sourceID, in: self.namespace))
            #else
            self.content
            #endif
        } else {
            self.content
        }
    }
}

#Preview("FullScreenButton") {
    NavigationStack {
        FullScreenButton {
            VStack {
                Text(verbatim: "Expanded")
                    .font(.largeTitle)
                    .foregroundStyle(Color.contentPrimary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.surfaceRaised)
        } label: {
            VStack(alignment: .leading) {
                Text(verbatim: "Tap to expand")
                    .font(.headline)
                    .foregroundStyle(Color.contentPrimary)
                Text(verbatim: "FullScreenButton")
                    .font(.subheadline)
                    .foregroundStyle(Color.contentSecondary)
            }
            .padding(CoreSpacing.lg)
            .frame(width: 260, height: 200, alignment: .topLeading)
            .background(Color.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: CoreRadius.large, style: .continuous))
        }
    }
}
