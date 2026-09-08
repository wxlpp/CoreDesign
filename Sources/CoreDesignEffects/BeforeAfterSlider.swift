import CoreDesign
import SwiftUI

// MARK: - 本 target 的 chrome 文案入口

extension LocalizedStringResource {
    static func effectsChrome(_ key: String.LocalizationValue) -> Self {
        LocalizedStringResource(key, bundle: .atURL(Bundle.module.bundleURL))
    }
}

// MARK: - 标签取值域

/// `BeforeAfterSlider` 两侧标签的取值域。
public enum BeforeAfterSliderLabels {
    /// 不显示标签。
    case hidden

    /// 显示**组件自带**的默认文案（"Before" / "After"，公约 §4 A 类）。
    case standard

    /// 显示**调用方给定**的文案（公约 §4 B 类）。
    case shown(before: LocalizedStringKey, after: LocalizedStringKey)

    static let defaultBefore: LocalizedStringResource = .effectsChrome("Before")

    static let defaultAfter: LocalizedStringResource = .effectsChrome("After")
}

enum BeforeAfterSliderChrome {
    static let accessibilityTitle: LocalizedStringResource =
        .effectsChrome("Before and after comparison")
}

// MARK: - 入场摆动与几何（纯函数，生产代码与判据共用同一份）

nonisolated struct BeforeAfterIntroSweep: Equatable, Sendable {
    let peak: CGFloat
    let settle: CGFloat
    let duration: Double
}

nonisolated enum BeforeAfterSweep {
    static let initialFraction: CGFloat = 0.5

    static let sweepPeak: CGFloat = 0.78

    static let sweepDuration: Double = 0.55

    static let handleHitSize: CGFloat = 44

    static let handleDiameter: CGFloat = 28

    static let dividerWidth: CGFloat = CoreBorderWidth.thick

    static func introSweep(reduceMotion: Bool) -> BeforeAfterIntroSweep? {
        guard !reduceMotion else { return nil }
        return BeforeAfterIntroSweep(
            peak: Self.sweepPeak,
            settle: Self.initialFraction,
            duration: Self.sweepDuration
        )
    }

    static func settlesAfterSweep(hasInteracted: Bool) -> Bool { !hasInteracted }

    /// 入场扫动的三态。⚠️ **不能用 Bool**：`#330` 第一版用 `introPlayed: Bool`，把「重放一次」
    /// 换成了**持久错态** —— 扫到 peak 之后、回程之前视图 disappear，`Task.sleep` 抛出、
    /// 回程不执行，而布尔已置真 ⇒ 把手**永远停在 peak**，只有用户拖一下才恢复。
    /// LazyVStack 快速滚动让 cell 停留不足 `sweepDuration` 是常态，不是边角。
    enum IntroPhase: Equatable, Sendable {
        case pending
        case sweeping
        case done
    }

    enum IntroAction: Equatable, Sendable {
        case idle
        case sweep
        case settleOnly
    }

    /// ⚠️ `.sweeping` 一律判 `.settleOnly`，**与 `sweep` 是否为 nil 无关** ——
    /// 隐藏期间用户打开 Reduce Motion 时 `introSweep(reduceMotion:)` 返回 nil，
    /// 若在这里跟着返回 `.idle`，把手就又卡在 peak 上了。
    static func introAction(phase: IntroPhase, sweep: BeforeAfterIntroSweep?) -> IntroAction {
        switch phase {
        case .done: .idle
        case .sweeping: .settleOnly
        case .pending: sweep == nil ? .idle : .sweep
        }
    }

    static func fraction(dragX: CGFloat, width: CGFloat) -> CGFloat {
        guard width > 0 else { return Self.initialFraction }
        return Self.clamp01(dragX / width)
    }

    static func revealWidth(fraction: CGFloat, width: CGFloat) -> CGFloat {
        Self.clamp01(fraction) * max(0, width)
    }

    static func leadingInset(fraction: CGFloat, width: CGFloat) -> CGFloat {
        max(0, Self.revealWidth(fraction: fraction, width: width) - Self.handleHitSize / 2)
    }

    static func clamp01(_ value: CGFloat) -> CGFloat { min(1, max(0, value)) }
}

// MARK: - 揭示裁剪（**裁剪**，不是 alpha 遮罩）

struct BeforeAfterRevealClip: Shape {
    var width: CGFloat

    var animatableData: CGFloat {
        get { self.width }
        set { self.width = newValue }
    }

    func path(in rect: CGRect) -> Path {
        Path(CGRect(
            x: rect.minX,
            y: rect.minY,
            width: min(max(0, self.width), rect.width),
            height: rect.height
        ))
    }
}

// MARK: - 把手

struct BeforeAfterSliderHandle: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.contentOnEmphasis)
                .frame(width: BeforeAfterSweep.dividerWidth)
            Circle()
                .fill(Color.contentOnEmphasis)
                .frame(width: BeforeAfterSweep.handleDiameter, height: BeforeAfterSweep.handleDiameter)
                .overlay {
                    Image(systemName: "arrow.left.and.right")
                        .font(.system(size: CoreControlMetrics.iconSize(for: .mini), weight: .semibold))
                        // ⚠️ 把手恒为白，而 contentPrimary 深色下也是白 ⇒ 深色下图标不可见。
                        // 既有问题，非本次引入；修它需要一个「恒定深色」token，本仓没有
                        // （darkText 在 macOS 退化为随外观切换的 textColor，grey9 明暗镜像）。
                        .foregroundStyle(Color.contentPrimary)
                }
        }
        .frame(minWidth: BeforeAfterSweep.handleHitSize, minHeight: BeforeAfterSweep.handleHitSize)
        .contentShape(Rectangle())
    }
}

// MARK: - 绘制层（不含手势与状态）

struct BeforeAfterSliderBody<Before: View, After: View>: View {
    let fraction: CGFloat
    let labels: BeforeAfterSliderLabels
    let before: Before
    let after: After

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let reveal = BeforeAfterSweep.revealWidth(fraction: self.fraction, width: width)

            ZStack(alignment: .topLeading) {
                self.after
                    .frame(width: width, height: proxy.size.height)
                    .clipped()

                self.before
                    .frame(width: width, height: proxy.size.height)
                    .clipped()
                    .clipShape(BeforeAfterRevealClip(width: reveal))

                self.labelOverlay(width: width)

                HStack(spacing: 0) {
                    Color.clear
                        .frame(width: BeforeAfterSweep.leadingInset(fraction: self.fraction, width: width))
                    BeforeAfterSliderHandle()
                    Spacer(minLength: 0)
                }
            }
        }
    }

    @ViewBuilder
    private func labelOverlay(width: CGFloat) -> some View {
        switch self.labels {
        case .hidden:
            EmptyView()
        case .standard:
            self.labelPair(
                before: Text(BeforeAfterSliderLabels.defaultBefore),
                after: Text(BeforeAfterSliderLabels.defaultAfter)
            )
        case let .shown(before, after):
            self.labelPair(before: Text(before), after: Text(after))
        }
    }

    private func labelPair(before: Text, after: Text) -> some View {
        HStack {
            self.chip(before)
            Spacer(minLength: CoreSpacing.sm)
            self.chip(after)
        }
        .padding(CoreSpacing.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityHidden(true)
    }

    private func chip(_ text: Text) -> some View {
        text
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color.contentPrimary)
            .padding(.horizontal, CoreSpacing.sm)
            .padding(.vertical, CoreSpacing.xs)
            .background(Color.quaternaryFill, in: Capsule())
    }
}

// MARK: - 公开入口

/// 拖动分隔线对比"之前 / 之后"两张图的滑块。典型用途：修图前后、主题深浅、
/// 优化前后的截图对照。
public struct BeforeAfterSlider<Before: View, After: View>: View {
    private let labels: BeforeAfterSliderLabels
    private let before: Before
    private let after: After

    @State private var fraction: CGFloat = BeforeAfterSweep.initialFraction

    @State private var hasInteracted = false

    @State private var introPhase = BeforeAfterSweep.IntroPhase.pending

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameters:
    ///   - labels: 两侧标签的取值域，默认 `.standard`。见 `BeforeAfterSliderLabels`。
    ///   - before: 分隔线**左侧**露出的内容（"之前"）。
    ///   - after: 分隔线**右侧**露出的内容（"之后"）。
    public init(
        labels: BeforeAfterSliderLabels = .standard,
        @ViewBuilder before: () -> Before,
        @ViewBuilder after: () -> After
    ) {
        self.labels = labels
        self.before = before()
        self.after = after()
    }

    public var body: some View {
        GeometryReader { proxy in
            BeforeAfterSliderBody(
                fraction: self.fraction,
                labels: self.labels,
                before: self.before,
                after: self.after
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        self.hasInteracted = true
                        self.fraction = BeforeAfterSweep.fraction(
                            dragX: value.location.x, width: proxy.size.width
                        )
                    }
            )
        }
        .task { await self.playIntroSweep(BeforeAfterSweep.introSweep(reduceMotion: self.reduceMotion)) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(BeforeAfterSliderChrome.accessibilityTitle))
        .accessibilityValue(Text(Double(self.fraction), format: .percent.precision(.fractionLength(0))))
        .accessibilityAdjustableAction { direction in
            let step: CGFloat = 0.05
            switch direction {
            case .increment: self.fraction = BeforeAfterSweep.clamp01(self.fraction + step)
            case .decrement: self.fraction = BeforeAfterSweep.clamp01(self.fraction - step)
            @unknown default: break
            }
        }
    }

    private func playIntroSweep(_ sweep: BeforeAfterIntroSweep?) async {
        switch BeforeAfterSweep.introAction(phase: self.introPhase, sweep: sweep) {
        case .idle:
            return
        case .settleOnly:
            self.introPhase = .done
            self.settleAfterIntro(duration: sweep?.duration ?? BeforeAfterSweep.sweepDuration)
        case .sweep:
            guard let sweep else { return }
            self.introPhase = .sweeping
            withAnimation(.easeInOut(duration: sweep.duration)) { self.fraction = sweep.peak }
            do {
                try await Task.sleep(for: .seconds(sweep.duration))
            } catch {
                return
            }
            self.introPhase = .done
            self.settleAfterIntro(duration: sweep.duration)
        }
    }

    private func settleAfterIntro(duration: Double) {
        guard BeforeAfterSweep.settlesAfterSweep(hasInteracted: self.hasInteracted) else { return }
        withAnimation(.easeInOut(duration: duration)) { self.fraction = BeforeAfterSweep.initialFraction }
    }
}

#Preview("BeforeAfterSlider") {
    BeforeAfterSlider {
        Rectangle().fill(Color.surfaceRaised)
            .overlay { Image(systemName: "photo").font(.system(size: 44)).foregroundStyle(Color.contentTertiary) }
    } after: {
        Rectangle().fill(Color.secondaryFill)
            .overlay { Image(systemName: "wand.and.stars").font(.system(size: 44)).foregroundStyle(.tint) }
    }
    .frame(width: 320, height: 200)
    .clipShape(CoreShape.rounded(CoreRadius.large))
    .padding(CoreSpacing.xxl)
}

#Preview("BeforeAfterSlider — 自定义文案 / 无标签") {
    VStack(spacing: CoreSpacing.xl) {
        BeforeAfterSlider(labels: .shown(before: "Draft", after: "Final")) {
            Rectangle().fill(Color.surfaceRaised)
        } after: {
            Rectangle().fill(Color.secondaryFill)
        }
        .frame(width: 300, height: 120)

        BeforeAfterSlider(labels: .hidden) {
            Rectangle().fill(Color.surfaceRaised)
        } after: {
            Rectangle().fill(Color.secondaryFill)
        }
        .frame(width: 300, height: 120)
    }
    .padding(CoreSpacing.xxl)
}
