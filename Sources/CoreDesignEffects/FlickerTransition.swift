//
//  FlickerTransition.swift
//  CoreDesignEffects
//
//  闪烁转场 / A flicker (faulty-tube) transition.
//

import CoreDesign
import SwiftUI

// MARK: - 转场本体

/// 视图像一支接触不良的灯管那样忽明忽暗地出现 / 消失。
///
/// ```swift
/// if showsSign {
///     neonSign.transition(.flicker)
/// }
/// ```
///
/// ## ⚠️⚠️ Reduce Motion / 减弱闪烁灯光：**两个都读**，这是全簇唯一一个
///
/// `#266` 逐字点名本转场（「`flicker` 尤其——闪烁是 WCAG 明确点名的诱因」）。
/// 逐个判断的结论：
///
/// - **光敏（主要）**：WCAG 2.3.1《Three Flashes or Below Threshold》直接管这件事。
///   ⇒ 读 `\.accessibilityDimFlashingLights`——那是系统为光敏性提供的**正确**信号。
/// - **前庭 / 非必要动画（次要）**：往复闪烁是全簇唯一会在**一次转场里来回好几遍**的
///   效果，它落在「减弱动态效果」想关掉的那一类里（重复的、非必要的动画）。
///   ⇒ **也**读 `\.accessibilityReduceMotion`。
/// - **任一开启即压制**（`FilterTransitionSafety.oscillation(dimFlashingLights:reduceMotion:)`）：
///   两个偏好在系统设置里是**各自独立**的开关，取「或」才能覆盖只开了其中一个的用户。
///
/// 压制后 `cycles` 归 0 ⇒ 曲线退化为**单调淡出** `1 − p`。
/// ⚠️ **不是 no-op**：转场仍然发生（内容仍然淡入 / 淡出），去掉的只有往复。
/// 判据：`FilterTransitionTests.calmedFlickerIsMonotone` 与
/// `flickerActuallyOscillates` 互锁——后者证明未压制时真的在往复，
/// 否则前者是恒真的。
///
/// ## ⚠️ 已知限度：闪烁**频率**由调用方的动画时长决定，本类型控制不了
///
/// 一次转场里发生 `cycles` 次明暗往复，而这段动画有多长**写在调用方的
/// `withAnimation(_:)` 里**——`Transition` 拿不到任何时间源（同 `ParticleTransition`
/// 记的那条：它只被喂三个离散相位，不知道时长与曲线）。
/// ⇒ 感知频率 = `cycles ÷ 时长`。默认 `cycles = 3`，**要落在 WCAG 的 3 次/秒线下，
/// 调用方的动画时长需 ≥ 1 秒**（本类型文档与 `docs/components/flicker-transition.md`
/// 都写明了这条，`#Preview` 用的就是 1.1 秒）。
/// ⚠️ 这条限度**不能**靠"把默认调小"绕开——`cycles = 1` 就不是闪烁了。
/// 真正兜底的是上面那道闸：开启「减弱闪烁灯光」的用户拿到的是单调淡出，
/// 与调用方写了多短的时长无关。
///
/// ## a11y 分工（FR-13）
///
/// 无装饰层——滤镜直接作用在调用方内容上。"这块内容出现 / 消失了"由调用方通告。
public struct FlickerTransition: Transition {

    /// 一次转场里的明暗往复次数。
    public let cycles: Int

    /// 默认往复次数。
    /// ⚠️ `nonisolated` 的理由见 `BlurTransition.defaultRadius`（probe 的隔离契约）。
    public nonisolated static let defaultCycles: Int = 3

    public init(cycles: Int = FlickerTransition.defaultCycles) {
        self.cycles = cycles
    }

    public func body(content: Content, phase: TransitionPhase) -> some View {
        content.modifier(FlickerChrome(phase: phase, cycles: self.cycles))
    }
}

/// 读**两个**环境键、裁档位，把**结论**（一个已经压过的往复次数）交给绘制层。
///
/// ⚠️ 纪律与 `FilmExposureChrome` 同：绘制层不再看见原始信号，调用点不许自己
/// 再判一遍。判据 `FilterTransitionTests.safetySignalsAreOnlyConsumedByTheSharedGate`
/// 对本文件同时数 `self.dimFlashingLights` 与 `self.reduceMotion` 两个计数。
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
        return content.modifier(FlickerFilm(
            progress: FilterTransitionPhase.progress(phase: self.phase),
            cycles: safety.oscillationCycles(self.cycles)
        ))
    }
}

/// 给定进度画出一帧。**不读环境、不读相位**。
///
/// ⚠️⚠️ **`Animatable` 是本转场唯一能让往复真的发生的东西**：
/// 曲线在两个**可达相位**上分别是 1 与 0，中间的每一次明暗全靠 SwiftUI 对
/// `animatableData` 的插值逐帧重求 `body` 得到。不 `Animatable` 的话，
/// `.opacity` 的输出被直接从 1 插到 0 ⇒ **就是一次普通淡出**，
/// 闪烁一次都不会发生，而所有测试照样绿（`#253` `ParticleTransition` 的原形态）。
/// 判据：`FilterTransitionTests.flickerDrawsDifferentFramesMidFlight`。
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

/// 闪烁的成像曲线。
nonisolated enum FlickerWave {

    /// 每次熄灭把不透明度压到基线的多少（`0` = 不闪，`1` = 全灭）。
    ///
    /// ⚠️ **有意 < 1**：全灭会让内容在转场中途整块消失一瞬，那既更刺眼、
    /// 也更像"渲染出错"而不是"灯管在闪"。
    static let depth: Double = 0.75

    /// 给定进度与往复次数的内容不透明度。
    ///
    /// - Parameter cycles: **已经过安全档位压制的**次数（`0` ⇒ 无往复，退化为单调淡出）。
    ///   负数按 0 处理——库代码对非法入参不抛断言（epic 的 AD-F）。
    ///
    /// ⚠️ 进度 0（`.identity`）恒为 1：`base = 1`、`wave = 0.5 − 0.5·cos(0) = 0`
    /// ⇒ 转场停住之后常驻态完全不透明，不留残留。
    static func opacity(progress: Double, cycles: Int) -> Double {
        let p = FilterTransitionPhase.clamped01(progress)
        let base = 1 - p
        guard cycles > 0 else { return base }
        let wave = 0.5 - 0.5 * cos(2 * .pi * Double(cycles) * p)
        return Swift.max(0, base * (1 - Self.depth * wave))
    }
}

// MARK: - 公开入口点（`Transition` 的静态成员）

public extension Transition where Self == FlickerTransition {

    /// 闪烁转场。
    ///
    /// ⚠️ 调用方的动画时长需 ≥ 1 秒才能让默认的 3 次往复落在 WCAG 的 3 次/秒线下，
    /// 见 `FlickerTransition` 的类型文档《已知限度》。
    static var flicker: FlickerTransition { FlickerTransition() }

    /// 闪烁转场，可指定往复次数。
    ///
    /// ⚠️ 与无参 `static var flicker` 按 `Host.member` 去重，**算同一种转场**。
    /// ⚠️ 传进来的值仍会被那道 a11y 闸压制到 0——调用方**绕不过**它。
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

        // ⚠️ 1.1 秒不是随手取的：默认 3 次往复 ÷ 1.1 秒 < 3 次/秒（WCAG 2.3.1）。
        Button("切换") { withAnimation(.easeInOut(duration: 1.1)) { shown.toggle() } }
    }
    .padding(CoreSpacing.huge)
}
