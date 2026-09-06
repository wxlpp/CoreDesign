import SwiftUI

// MARK: - SpinningPresentation

/// `spinning` 的**呈现形态**。
public enum SpinningPresentation: Sendable, Equatable {
    /// 默认：材质遮罩铺满内容 + 居中指示器（现状形态）。
    case overlay
    /// 容器顶边的细进度条，不铺遮罩。
    /// 业界来源：NProgress / YouTube 顶条 / GitHub Turbo。
    case topBar
    /// 原位行内指示器，不铺遮罩。
    /// 业界来源：Ant Design Spin 的非包裹用法 / MUI CircularProgress。
    case inline
}

// MARK: - SpinningModifier

/// 为任意内容叠加加载指示（吸收 Semi Design `Spin` 能力，Issue #172）。
public struct SpinningModifier: ViewModifier {
    public let isActive: Bool
    public let text: LocalizedStringKey?
    public let presentation: SpinningPresentation
    /// spinner 取色，透传给 `ProgressIndicator`。⚠️ 不能靠外加 `.tint(_:)`
    /// ——理由见 `ProgressIndicator.tint`。
    public let tint: Color

    /// - Parameters:
    ///   - isActive: 是否显示。
    ///   - text: 指示器的可选文案。⚠️ `.topBar` 形态下**不生效** —— 顶条没有文案位；
    ///     存储层仍原样保留，切回其余形态时不丢配置（与 `Steps` / `Timeline` /
    ///     `AvatarGroup` 同一处置）。
    ///   - presentation: 呈现形态，默认 `.overlay`（现状形态）⇒ **现有调用方零影响**。
    public init(
        isActive: Bool,
        text: LocalizedStringKey? = nil,
        presentation: SpinningPresentation = .overlay,
        tint: Color = .accent
    ) {
        self.isActive = isActive
        self.text = text
        self.presentation = presentation
        self.tint = tint
    }

    public func body(content: Content) -> some View {
        switch self.presentation {
        case .overlay: self.overlayBody(content)
        case .topBar: self.topBarBody(content)
        case .inline: self.inlineBody(content)
        }
    }

    private func topBarBody(_ content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if self.isActive {
                    TopBarIndicator(tint: self.tint)
                        .transition(.opacity)
                }
            }
            .animation(.default, value: self.isActive)
    }

    private func inlineBody(_ content: Content) -> some View {
        HStack(spacing: CoreSpacing.sm) {
            content
            if self.isActive {
                self.indicator
                    .transition(.opacity)
            }
        }
        .animation(.default, value: self.isActive)
    }

    private func overlayBody(_ content: Content) -> some View {
        content
            .allowsHitTesting(!self.isActive)
            .accessibilityHidden(self.isActive)
            .overlay {
                if self.isActive {
                    ZStack {
                        ContainerRelativeShape()
                            .fill(.regularMaterial)
                        self.indicator
                    }
                    .transition(.opacity)
                }
            }
            .animation(.default, value: self.isActive)
    }

    @ViewBuilder
    private var indicator: some View {
        if let text = self.text {
            ProgressIndicator(text: text, tint: self.tint)
        } else {
            ProgressIndicator(tint: self.tint)
        }
    }
}

struct TopBarIndicator: View {
    let tint: Color

    static let barWidthRatio: CGFloat = 0.3
    static let period: TimeInterval = 1.1
    private static let trackOpacity: Double = 0.2

    var body: some View {
        GeometryReader { proxy in
            let barWidth = proxy.size.width * Self.barWidthRatio
            ZStack(alignment: .leading) {
                Capsule().fill(self.tint.opacity(Self.trackOpacity))

                TimelineView(.animation) { context in
                    Capsule()
                        .fill(self.tint)
                        .frame(width: barWidth)
                        .offset(x: Self.offset(at: context.date, trackWidth: proxy.size.width))
                }
            }
        }
        .frame(height: Self.height)
        .clipped()
        .accessibilityElement()
        .accessibilityLabel(Text("Loading", bundle: .module))
        .accessibilityAddTraits(.updatesFrequently)
    }

    static let height: CGFloat = CoreSpacing.xs

    static func offset(at date: Date, trackWidth: CGFloat) -> CGFloat {
        let barWidth = trackWidth * Self.barWidthRatio
        let elapsed = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: Self.period)
        let phase = CGFloat(elapsed / Self.period)
        return -barWidth + (trackWidth + barWidth) * phase
    }
}

public extension View {
    /// 为内容整体叠加加载遮罩。见 `SpinningModifier`。
    ///
    /// - Parameters:
    ///   - isActive: 是否显示遮罩。
    ///   - text: 指示器的可选文案，默认 `nil`（不带文案）。⚠️ `.topBar` 形态下不生效。
    ///   - presentation: 呈现形态，默认 `.overlay`（现状形态）⇒ **现有调用方零影响**。
    ///     ⚠️ `.topBar` / `.inline` 是**非阻塞**形态：不禁用底层交互、不隐藏无障碍，
    ///     语义是「后台正在加载、内容仍可用」，与 `.overlay` 的「此刻不可操作」不同。
    /// - Parameter tint: spinner / 顶条取色，**三个形态都生效**。
    ///   ⚠️ 必须走本参数，**外加 `.tint(_:)` 三个形态一律无效**。`.overlay` / `.inline`
    ///   是因为 `ProgressIndicator` 内层显式设 tint（FR-3a）；`.topBar` 是本次改动的
    ///   **代价**——它原本吃环境 tint，为消除「同一 API 两形态取色分裂」而拉齐到参数通路。
    func spinning(
        _ isActive: Bool,
        text: LocalizedStringKey? = nil,
        presentation: SpinningPresentation = .overlay,
        tint: Color = .accent
    ) -> some View {
        self.modifier(
            SpinningModifier(isActive: isActive, text: text, presentation: presentation, tint: tint)
        )
    }
}

#Preview("spinning — Light") {
    SpinningModifierPreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("spinning — Dark") {
    SpinningModifierPreviewGallery()
        .preferredColorScheme(.dark)
}

private struct SpinningModifierPreviewGallery: View {
    var body: some View {
        VStack(spacing: CoreSpacing.xl) {
            VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                Text("isActive: false（正常渲染，无遮罩）")
                    .coreFont(.footnote)
                    .foregroundStyle(Color.contentSecondary)
                self.card
                    .spinning(false)
            }

            VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                Text("isActive: true（无文案）")
                    .coreFont(.footnote)
                    .foregroundStyle(Color.contentSecondary)
                self.card
                    .spinning(true)
            }

            VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                Text("isActive: true（带文案）")
                    .coreFont(.footnote)
                    .foregroundStyle(Color.contentSecondary)
                self.card
                    .spinning(true, text: "Refreshing…")
            }

            // MARK: `#60` 形态 D2 新增的两种呈现

            VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                Text(".topBar（顶边细条，内容不被遮罩、仍可交互）")
                    .coreFont(.footnote)
                    .foregroundStyle(Color.contentSecondary)
                self.card
                    .spinning(true, presentation: .topBar)
            }

            VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                Text(".inline（行内指示器；非激活时 HStack 常驻，几何不跳变）")
                    .coreFont(.footnote)
                    .foregroundStyle(Color.contentSecondary)
                HStack(spacing: CoreSpacing.lg) {
                    Text("保存中").coreFont(.callout).spinning(true, presentation: .inline)
                    Text("已保存").coreFont(.callout).spinning(false, presentation: .inline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(Color.surfaceCanvas)
    }

    private var card: some View {
        Card {
            VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                Text("卡片标题").coreFont(.headline)
                Text("被 spinning 遮罩覆盖时应保持自身尺寸不变。")
                    .coreFont(.subheadline)
                    .foregroundStyle(Color.contentSecondary)
            }
        }
    }
}
