import OhMyDesign
import SwiftUI

// MARK: - 转场本体

/// 视图像一支接触不良的灯管那样忽明忽暗地出现 / 消失。
public struct FlickerTransition: Transition {
    /// 一次转场里的明暗往复次数。
    public let cycles: Int

    /// 默认往复次数。
    /// 默认明暗往复次数。
    public nonisolated static let defaultCycles: Int = 3

    /// 显式退出框架的 opacity 替换，让本文件那道手写闸成为唯一保护。
    public nonisolated static let properties = TransitionProperties(hasMotion: false)

    public init(cycles: Int = FlickerTransition.defaultCycles) {
        self.cycles = cycles
    }

    public func body(content: Content, phase: TransitionPhase) -> some View {
        content.modifier(FlickerChrome(phase: phase, cycles: self.cycles))
    }
}

struct FlickerChrome: ViewModifier {
    let phase: TransitionPhase
    let cycles: Int

    @Environment(\.accessibilityDimFlashingLights) private var dimFlashingLights
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let safety = FilterTransitionSafety.oscillation(
            dimFlashingLights: self.dimFlashingLights,
            reduceMotion: self.reduceMotion
        )
        let cycles = safety.oscillationCycles(self.cycles)
        return content
            .modifier(FlickerFilm(
                progress: FilterTransitionPhase.progress(phase: self.phase),
                cycles: cycles
            ))
            .animation(.easeInOut(duration: FlickerPace.duration(cycles: cycles)), value: self.phase)
    }
}

struct FlickerFilm: ViewModifier, Animatable {
    var progress: Double
    var cycles: Int

    var animatableData: Double {
        get { self.progress }
        set { self.progress = newValue }
    }

    func body(content: Content) -> some View {
        let progress = self.progress
        let cycles = self.cycles
        return content.opacity(FlickerWave.opacity(progress: progress, cycles: cycles))
    }
}

// MARK: - 曲线（纯函数，生产代码与判据共用同一份）

nonisolated enum FlickerWave {
    static let depth: Double = 0.75

    static func opacity(progress: Double, cycles: Int) -> Double {
        let p = FilterTransitionPhase.clamped01(progress)
        let base = 1 - p
        guard cycles > 0 else { return base }
        let wave = 0.5 - 0.5 * cos(2 * .pi * Double(cycles) * p)
        return Swift.max(0, base * (1 - Self.depth * wave))
    }
}

// MARK: - 节奏（把闪烁的**速率**从调用方手里收回来）

nonisolated enum FlickerPace {
    static let maximumFlashesPerSecond: Double = 2.5

    static let calmedDuration: Double = 0.35

    static func duration(cycles: Int) -> Double {
        let n = Double(Swift.max(0, cycles))
        return Swift.max(Self.calmedDuration, n / Self.maximumFlashesPerSecond)
    }
}

// MARK: - 公开入口点（`Transition` 的静态成员）

public extension Transition where Self == FlickerTransition {
    /// 闪烁转场。
    static var flicker: FlickerTransition { FlickerTransition() }

    /// 闪烁转场，可指定往复次数。
    static func flicker(cycles: Int = FlickerTransition.defaultCycles) -> FlickerTransition {
        FlickerTransition(cycles: cycles)
    }
}

#Preview("FlickerTransition") {
    @Previewable @State var shown = true
    VStack(spacing: CoreSpacing.xxl) {
        ZStack {
            if shown {
                Text("OPEN")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .padding(CoreSpacing.xxl)
                    .background(Color.surfaceRaised, in: RoundedRectangle(cornerRadius: CoreRadius.large))
                    .transition(.flicker)
            }
        }
        .frame(height: 160)

        Button("切换") { withAnimation(.easeInOut(duration: 0.25)) { shown.toggle() } }
    }
    .padding(CoreSpacing.huge)
}
