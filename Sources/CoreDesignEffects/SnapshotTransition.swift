//
//  SnapshotTransition.swift
//  CoreDesignEffects
//
//  快门 / 显影转场 / A shutter-and-develop (instant photo) transition.
//

import CoreDesign
import SwiftUI

// MARK: - 转场本体

/// 视图像一张即显相纸那样出现：先是一下快门白场，随后从洗白的低对比逐渐"显影"到常态。
///
/// ```swift
/// if showsShot {
///     shot.transition(.snapshot)
/// }
/// ```
///
/// ## Reduce Motion / 减弱闪烁灯光：**只读「减弱闪烁灯光」**，判据与 `filmExposure` 同族
///
/// ⚠️ `#266` 要求的「逐个判断」在本转场上的结论：
///
/// - **前庭（光流）**：无位移 / 旋转 / 缩放 ⇒ 与 Reduce Motion 无关，**有意不读**它。
///   ⚠️⚠️ 与 `filmExposure` 同：这条「有意不读」只有在 `properties.hasMotion == false`
///   时才落得了地，否则框架会在 Reduce Motion 下把整条转场换成 `.opacity`（终审 C-4）。
/// - **光敏**：快门白场是全簇**最陡**的一次亮度上冲——它被刻意做成一个窄窗
///   （`shutterWidth = 0.25` 的升余弦），窄意味着**陡**。窗形是 **0 → 峰 → 0**，
///   按 WCAG 2.3.1 的定义（"an increase followed by a decrease"）**这就是一次 general flash**。
///   ⇒ **单次**使用不构成 2.3.1 违规，理由是**频率**：一次转场只放 1 次 flash，
///   而阈值的第一条通过条件是「任意一秒内 general flash 不超过 3 次」。
///   ⚠️ **有边界**：一秒内触发 4 次以上本转场（列表批量插入、照片墙逐格出现）
///   就越过 3 次/秒线，届时 `full` 档 0.7 的峰值幅度也远高于「10% 相对亮度」那条合取项。
///   **批量场景请自行核对触发频率。**
///   压制它的理由与 `filmExposure` 逐字相同：**用户显式打开了「减弱闪烁灯光」**，
///   而这是全簇最陡的一下亮冲，幅度这一侧比 `filmExposure` 更该管。
///   ⚠️ 上两版这里先把 0.1 写成一条独立的幅度阈值、再写「单向 ⇒ 不满足『一对反向变化』」，
///   **两句都是误述**；逐字更正见 `FilterTransitionSafety.calmedBrightnessCeiling`
///   （PR #289 终审 I-1 与第 2 轮 I-1）。
///
/// ⇒ 与 `filmExposure` 走**同一道闸、同一个上限**
///（`FilterTransitionSafety.exposure(dimFlashingLights:)` ⇒ `calmedBrightnessCeiling`）。
/// ⚠️ **不是 no-op**：显影（饱和度 / 对比度从洗白回到常态）与淡入淡出全部保留，
/// 去掉的只有那一下白场。
///
/// ## ⚠️ 曲线是非单调的 ⇒ 绘制层**必须** `Animatable`
///
/// 白场只在 `progress ∈ (0.5, 1)` 这个窗里有值，峰值在 `0.75`，而**可达相位只有 0 与 1**
/// ——两端都恰为 0。绘制层不 `Animatable` 的话，SwiftUI 把 `.brightness` 的输出从 0 插到 0，
/// **快门一次都不会发生**且全套测试照绿（`#253` `ParticleTransition` 的原形态）。
/// 判据：`FilterTransitionTests.snapshotOnlyFlashesInsideTheShutterWindow`
/// + `snapshotDrawsTheShutterMidFlight`。
///
/// ## a11y 分工（FR-13）
///
/// 无装饰层——滤镜直接作用在调用方内容上。"这块内容出现 / 消失了"由调用方通告。
public struct SnapshotTransition: Transition {

    /// 快门白场的强度（`0...1` 的亮度增量）。
    public let intensity: Double

    /// 默认快门强度。
    /// ⚠️ `nonisolated` 的理由见 `BlurTransition.defaultRadius`（probe 的隔离契约）。
    public nonisolated static let defaultIntensity: Double = 0.7

    /// ⚠️⚠️ 理由逐字同 `FilmExposureTransition.properties`（终审 C-4）：协议默认值
    /// `hasMotion == true` 会让框架在 Reduce Motion 下把整条转场替换成 opacity。
    /// 判据：`FilterTransitionTests.everyTransitionOptsOutOfTheFrameworkMotionSubstitution`。
    public nonisolated static let properties = TransitionProperties(hasMotion: false)

    public init(intensity: Double = SnapshotTransition.defaultIntensity) {
        self.intensity = intensity
    }

    public func body(content: Content, phase: TransitionPhase) -> some View {
        content.modifier(SnapshotChrome(phase: phase, intensity: self.intensity))
    }
}

/// 读环境、裁档位，把**结论**（一个已经压过的白场峰值）交给绘制层。
/// 纪律与 `FilmExposureChrome` 逐字相同，判据同一条
///（`FilterTransitionTests.safetySignalsAreOnlyConsumedByTheSharedGate`）。
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

/// 给定进度画出一帧。**不读环境、不读相位**。`Animatable` 的理由见类型文档。
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

/// 快门 / 显影的成像曲线。四条曲线在进度 0（`.identity`）上**全部取中性值**。
nonisolated enum SnapshotDevelop {

    /// 快门白场的中心进度。
    ///
    /// ⚠️ 取 0.75 而不是 0.5：插入时进度从 1 走到 0，白场因此落在**动作的前段**
    /// ——先按快门、再显影，与真实即显相机的次序一致。
    static let shutterCenter: Double = 0.75

    /// 白场窗口的半宽。
    static let shutterWidth: Double = 0.25

    /// 显影期的饱和度洗白系数。
    static let washOut: Double = 1.25

    /// 显影期的对比度下降幅度。
    static let contrastDrop: Double = 0.45

    /// 内容不透明度的收束速度（越大越晚开始淡出）。
    static let fadeSlope: Double = 3

    /// 亮度增量：只在 `|p − shutterCenter| < shutterWidth` 这个窗里非零。
    static func brightness(progress: Double, peak: Double) -> Double {
        let p = FilterTransitionPhase.clamped01(progress)
        let k = FilterTransitionPhase.clamped01(peak)
        let distance = abs(p - Self.shutterCenter)
        guard distance < Self.shutterWidth else { return 0 }
        // 升余弦窗：中心 1、两端 0，一阶连续（不留硬边）。
        return k * 0.5 * (1 + cos(.pi * distance / Self.shutterWidth))
    }

    /// 饱和度。进度 0 ⇒ 1（中性）；显影前完全无彩。
    static func saturation(progress: Double) -> Double {
        Swift.max(0, 1 - Self.washOut * FilterTransitionPhase.clamped01(progress))
    }

    /// 对比度。进度 0 ⇒ 1（中性）。
    static func contrast(progress: Double) -> Double {
        1 - Self.contrastDrop * FilterTransitionPhase.clamped01(progress)
    }

    /// 内容不透明度。
    ///
    /// ⚠️ 前 2/3 段保持完全不透明，只在最后一小段收掉——否则白场发生时内容已经半透明，
    /// 快门那一下就看不见了。
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
    ///
    /// ⚠️ 与无参 `static var snapshot` 按 `Host.member` 去重，**算同一种转场**。
    /// ⚠️ 传进来的值仍会被「减弱闪烁灯光」这道闸压制——调用方**调不高**安全上限。
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
