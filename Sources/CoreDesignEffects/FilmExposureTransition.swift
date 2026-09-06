import CoreDesign
import SwiftUI

// MARK: - 转场本体

/// 视图进出时像一格胶片被过度曝光：亮度先冲上去、饱和度与对比度一路洗白，然后消失。
public struct FilmExposureTransition: Transition {
    /// 过曝峰值的强度（`0...1` 的亮度增量）。
    public let intensity: Double

    /// 默认过曝强度。
    /// 默认过曝强度。
    public nonisolated static let defaultIntensity: Double = 0.55

    /// 显式退出框架在 Reduce Motion 下的 opacity 替换（协议默认值是 `true`）。
    public nonisolated static let properties = TransitionProperties(hasMotion: false)

    public init(intensity: Double = FilmExposureTransition.defaultIntensity) {
        self.intensity = intensity
    }

    public func body(content: Content, phase: TransitionPhase) -> some View {
        content.modifier(FilmExposureChrome(phase: phase, intensity: self.intensity))
    }
}

struct FilmExposureChrome: ViewModifier {
    let phase: TransitionPhase
    let intensity: Double

    @Environment(\.accessibilityDimFlashingLights) private var dimFlashingLights

    func body(content: Content) -> some View {
        let safety = FilterTransitionSafety.exposure(dimFlashingLights: self.dimFlashingLights)
        return content.modifier(FilmExposureFilm(
            progress: FilterTransitionPhase.progress(phase: self.phase),
            peak: safety.exposurePeak(self.intensity)
        ))
    }
}

struct FilmExposureFilm: ViewModifier, Animatable {
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
            .saturation(FilmExposure.saturation(progress: progress))
            .contrast(FilmExposure.contrast(progress: progress))
            .brightness(FilmExposure.brightness(progress: progress, peak: peak))
            .opacity(FilmExposure.contentOpacity(progress: progress))
    }
}

// MARK: - 曲线（纯函数，生产代码与判据共用同一份）

nonisolated enum FilmExposure {
    static let washOut: Double = 0.85

    static let contrastDrop: Double = 0.35

    static func brightness(progress: Double, peak: Double) -> Double {
        let p = FilterTransitionPhase.clamped01(progress)
        let k = FilterTransitionPhase.clamped01(peak)
        return k * 4 * p * (1 - p)
    }

    static func saturation(progress: Double) -> Double {
        1 - Self.washOut * FilterTransitionPhase.clamped01(progress)
    }

    static func contrast(progress: Double) -> Double {
        1 - Self.contrastDrop * FilterTransitionPhase.clamped01(progress)
    }

    static func contentOpacity(progress: Double) -> Double {
        let p = FilterTransitionPhase.clamped01(progress)
        return 1 - p * p
    }
}

// MARK: - 公开入口点（`Transition` 的静态成员）

public extension Transition where Self == FilmExposureTransition {
    /// 胶片过曝转场。
    static var filmExposure: FilmExposureTransition { FilmExposureTransition() }

    /// 胶片过曝转场，可指定过曝强度。
    static func filmExposure(
        intensity: Double = FilmExposureTransition.defaultIntensity
    ) -> FilmExposureTransition {
        FilmExposureTransition(intensity: intensity)
    }
}

#Preview("FilmExposureTransition") {
    @Previewable @State var shown = true
    VStack(spacing: CoreSpacing.xxl) {
        ZStack {
            if shown {
                VStack(spacing: CoreSpacing.sm) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 44))
                    Text("Roll 03")
                        .font(.headline)
                }
                .padding(CoreSpacing.xxl)
                .background(Color.surfaceRaised, in: RoundedRectangle(cornerRadius: CoreRadius.large))
                .transition(.filmExposure)
            }
        }
        .frame(height: 160)

        Button("切换") { withAnimation(.easeInOut(duration: 0.7)) { shown.toggle() } }
    }
    .padding(CoreSpacing.huge)
}
