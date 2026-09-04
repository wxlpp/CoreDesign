//
//  FilmExposureTransition.swift
//  CoreDesignEffects
//
//  胶片过曝转场 / A film over-exposure transition.
//

import CoreDesign
import SwiftUI

// MARK: - 转场本体

/// 视图进出时像一格胶片被过度曝光：亮度先冲上去、饱和度与对比度一路洗白，然后消失。
///
/// ```swift
/// if showsPhoto {
///     photo.transition(.filmExposure)
/// }
/// ```
///
/// ## Reduce Motion / 减弱闪烁灯光：**只读「减弱闪烁灯光」**
///
/// ⚠️ `#266` 要求的「逐个判断」在本转场上的结论：
///
/// - **前庭（光流）**：没有位移 / 旋转 / 缩放，一处都没有 ⇒ 与 Reduce Motion 无关。
///   **有意不读** `\.accessibilityReduceMotion`：读了会让只开启「减弱动态效果」的用户
///   白白丢掉一条无害的成像效果，而真正需要保护的（只开启「减弱闪烁灯光」的那批）
///   仍然拿不到保护——张冠李戴的信号比没有信号更糟。
/// - **光敏**：过曝峰值是一次**大面积亮度上冲**。它是**单向、一次性**的，
///   不构成 WCAG 2.3.1 所定义的「闪烁」（那要求每秒 ≥ 3 次），
///   但同一条款的通用闪光阈值同时看**相对亮度变化幅度**（≥ 0.1 视为大面积闪光）
///   ⇒ 峰值本身仍在射程内。
///
/// ⇒ 读 `\.accessibilityDimFlashingLights`，开启时把峰值压到
/// `FilterTransitionSafety.calmedBrightnessCeiling`（0.08）**以下**。
/// ⚠️ **不是 no-op**：饱和度洗白、对比度下降、淡出全部保留，
/// 用户仍然看得出"这是一次胶片式的曝光"，只是不再有那一下亮冲。
///
/// ## ⚠️ 曲线是非单调的 ⇒ 绘制层**必须** `Animatable`
///
/// 亮度曲线 `peak · sin(π·p)` 在两个**可达相位**（进度 0 与 1）上**都恰为 0**，
/// 峰值只出现在中间。而 `TransitionPhase` 是 3 case frozen enum ⇒
/// `body(content:phase:)` 永远拿不到中间进度。
/// ⇒ 若绘制层不是 `Animatable`，SwiftUI 只会把 `.brightness` 的**输出**从 0 插到 0
/// ——过曝**一次都不会发生**，而所有测试照样绿（这正是 `#253` 的 `ParticleTransition`
/// 踩过的坑，逐字见 `ParticleBurstLayer` 的类型文档）。
/// 判据：`FilterTransitionTests.filmExposureOnlyBlowsOutMidFlight`（曲线两端为 0、
/// 中间为正）+ `filmExposureDrawsTheBlowOutMidFlight`（把 SwiftUI 的插值步骤原样跑一遍，
/// 中间那一帧的位图必须与两个端点都不同）。
///
/// ## a11y 分工（FR-13）
///
/// 无装饰层——滤镜直接作用在调用方内容上，没有可 `accessibilityHidden(true)` 的东西。
/// "这块内容出现 / 消失了"的通告由调用方提供。
public struct FilmExposureTransition: Transition {

    /// 过曝峰值的强度（`0...1` 的亮度增量）。
    public let intensity: Double

    /// 默认过曝强度。
    /// ⚠️ `nonisolated` 的理由见 `BlurTransition.defaultRadius`（probe 的隔离契约）。
    public nonisolated static let defaultIntensity: Double = 0.55

    public init(intensity: Double = FilmExposureTransition.defaultIntensity) {
        self.intensity = intensity
    }

    public func body(content: Content, phase: TransitionPhase) -> some View {
        // ⚠️ **走 `ViewModifier` 而不是就地写**：`Transition.body(content:phase:)` 拿不到
        // `@Environment`（它不是 `View`），而安全档位必须从环境里读。
        content.modifier(FilmExposureChrome(phase: phase, intensity: self.intensity))
    }
}

/// 读环境、裁档位，把**结论**（一个已经压过的峰值）交给绘制层。
///
/// ⚠️ **绘制层不再看见原始信号**——这正是 `EffectsEnergyState.presentation(reduceMotion:)`
/// 立下的纪律：档位的结论物化成一个值，调用点不许自己再判一遍。
/// 判据：`FilterTransitionTests.safetySignalsAreOnlyConsumedByTheSharedGate`
///（本文件里 `self.dimFlashingLights` 的出现次数必须恰等于喂给
/// `FilterTransitionSafety.exposure(dimFlashingLights:)` 的次数，且不许裸写）。
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

/// 给定进度画出一帧。**不读环境、不读相位**——因此可以被单测钉在任意进度上渲染。
///
/// ⚠️⚠️ **`Animatable` 是本转场唯一能让过曝真的发生的东西**，理由见类型 `FilmExposureTransition`
/// 的文档。SwiftUI 在一次动画事务里做的正是：取两端的 `animatableData`、按 t 插值、
/// 写回视图并逐帧重求 `body`。
struct FilmExposureFilm: ViewModifier, Animatable {

    var progress: Double
    var peak: Double

    var animatableData: Double {
        get { self.progress }
        set { self.progress = newValue }
    }

    func body(content: Content) -> some View {
        // ⚠️ 先取成局部 `let`：本包开了 `.defaultIsolation(MainActor.self)`，
        // 见 `MicroInteractionSupport.swift`《写微交互前必读：隔离约束》。
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

/// 胶片过曝的成像曲线。四条曲线在进度 0（`.identity`）上**全部取中性值**。
nonisolated enum FilmExposure {

    /// 饱和度洗白的幅度（进度 1 时降到 `1 - washOut`）。
    static let washOut: Double = 0.85

    /// 对比度下降的幅度。
    static let contrastDrop: Double = 0.35

    /// 亮度增量。**两端为 0、中间为峰值**——非单调，见类型文档。
    ///
    /// ⚠️ 用抛物线 `4p(1−p)` 而不是 `sin(πp)`：两者形状几乎一样，但 `sin(.pi)` 在
    /// `Double` 上是 `1.2246e-16` 而不是 0 ⇒ 端点会留一个肉眼看不见、
    /// 但**判据看得见**的残余亮度。端点必须**精确**为 0，否则
    /// 「`.identity` 上一切中性」这条契约就只能写成"约等于"，而那种写法
    /// 迟早被人放宽成"差不多就行"。抛物线在 0 与 1 上是**精确**的 0。
    static func brightness(progress: Double, peak: Double) -> Double {
        let p = FilterTransitionPhase.clamped01(progress)
        let k = FilterTransitionPhase.clamped01(peak)
        return k * 4 * p * (1 - p)
    }

    /// 饱和度。进度 0 ⇒ 1（中性）。
    static func saturation(progress: Double) -> Double {
        1 - Self.washOut * FilterTransitionPhase.clamped01(progress)
    }

    /// 对比度。进度 0 ⇒ 1（中性）。
    static func contrast(progress: Double) -> Double {
        1 - Self.contrastDrop * FilterTransitionPhase.clamped01(progress)
    }

    /// 内容不透明度。
    ///
    /// ⚠️ 用 `1 - p²` 而不是 `1 - p`：过曝峰值在 `p = 0.5`，线性淡出会让它只剩一半
    /// 不透明度、亮冲几乎看不见。平方项把内容在前半程留得更久。
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
    ///
    /// ⚠️ 与无参 `static var filmExposure` 按 `Host.member` 去重，**算同一种转场**。
    /// ⚠️ 传进来的值仍会被「减弱闪烁灯光」这道闸压制——调用方**调不高**安全上限。
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
