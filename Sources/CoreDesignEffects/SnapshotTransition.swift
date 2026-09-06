import CoreDesign
import SwiftUI

// MARK: - 转场本体

/// 视图像一张即显相纸那样出现：先是一下快门白场，随后从洗白的低对比逐渐"显影"到常态。
public struct SnapshotTransition: Transition {
    /// 快门白场的强度（`0...1` 的亮度增量）。
    public let intensity: Double

    /// 默认快门强度。
    /// 默认快门白场强度。
    public nonisolated static let defaultIntensity: Double = 0.7

    /// 显式退出框架在 Reduce Motion 下的 opacity 替换（协议默认值是 `true`）。
    public nonisolated static let properties = TransitionProperties(hasMotion: false)

    public init(intensity: Double = SnapshotTransition.defaultIntensity) {
        self.intensity = intensity
    }

    public func body(content: Content, phase: TransitionPhase) -> some View {
        content.modifier(SnapshotChrome(phase: phase, intensity: self.intensity))
    }
}

struct SnapshotChrome: ViewModifier {
    let phase: TransitionPhase
    let intensity: Double

    @Environment(\.accessibilityDimFlashingLights) private var dimFlashingLights

    func body(content: Content) -> some View {
        let safety = FilterTransitionSafety.exposure(dimFlashingLights: self.dimFlashingLights)
        return content.modifier(SnapshotFilm(
            progress: FilterTransitionPhase.progress(phase: self.phase),
            peak: safety.exposurePeak(self.intensity)
        ))
    }
}

struct SnapshotFilm: ViewModifier, Animatable {
    var progress: Double
    var peak: Double

    var animatableData: Double {
        get { self.progress }
        set { self.progress = newValue }
    }

    func body(content: Content) -> some View {
        let progress = self.progress
        let peak = self.peak
        return content
            .saturation(SnapshotDevelop.saturation(progress: progress))
            .contrast(SnapshotDevelop.contrast(progress: progress))
            .brightness(SnapshotDevelop.brightness(progress: progress, peak: peak))
            .opacity(SnapshotDevelop.contentOpacity(progress: progress))
    }
}

// MARK: - 曲线（纯函数，生产代码与判据共用同一份）

nonisolated enum SnapshotDevelop {
    static let shutterCenter: Double = 0.75

    static let shutterWidth: Double = 0.25

    static let washOut: Double = 1.25

    static let contrastDrop: Double = 0.45

    static let fadeSlope: Double = 3

    static func brightness(progress: Double, peak: Double) -> Double {
        let p = FilterTransitionPhase.clamped01(progress)
        let k = FilterTransitionPhase.clamped01(peak)
        let distance = abs(p - Self.shutterCenter)
        guard distance < Self.shutterWidth else { return 0 }
        return k * 0.5 * (1 + cos(.pi * distance / Self.shutterWidth))
    }

    static func saturation(progress: Double) -> Double {
        Swift.max(0, 1 - Self.washOut * FilterTransitionPhase.clamped01(progress))
    }

    static func contrast(progress: Double) -> Double {
        1 - Self.contrastDrop * FilterTransitionPhase.clamped01(progress)
    }

    static func contentOpacity(progress: Double) -> Double {
        let p = FilterTransitionPhase.clamped01(progress)
        return Swift.min(1, Swift.max(0, (1 - p) * Self.fadeSlope))
    }
}

// MARK: - 公开入口点（`Transition` 的静态成员）

public extension Transition where Self == SnapshotTransition {
    /// 快门 / 显影转场。
    static var snapshot: SnapshotTransition { SnapshotTransition() }

    /// 快门 / 显影转场，可指定白场强度。
    static func snapshot(
        intensity: Double = SnapshotTransition.defaultIntensity
    ) -> SnapshotTransition {
        SnapshotTransition(intensity: intensity)
    }
}

#Preview("SnapshotTransition") {
    @Previewable @State var shown = true
    VStack(spacing: CoreSpacing.xxl) {
        ZStack {
            if shown {
                VStack(spacing: CoreSpacing.sm) {
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 44))
                    Text("Shot 12")
                        .font(.headline)
                }
                .padding(CoreSpacing.xxl)
                .background(Color.surfaceRaised, in: RoundedRectangle(cornerRadius: CoreRadius.large))
                .transition(.snapshot)
            }
        }
        .frame(height: 160)

        Button("切换") { withAnimation(.easeInOut(duration: 0.8)) { shown.toggle() } }
    }
    .padding(CoreSpacing.huge)
}
