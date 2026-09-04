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
/// 判据：`FilterTransitionTests.flickerActuallyOscillates` 一条里两半互锁——
/// 先证未压制时曲线上真的存在**上升段**（一条普通淡出永远不会有），
/// 再证**经那道闸取到的** `cycles` 下没有上升段、且逐点等于 `1 − p`；
/// 少了前一半，后一半是恒真的。
/// ⚠️ 上一版这里引用的是 `calmedFlickerIsMonotone`，那个符号**从来不存在**
///（`grep -c` = 0，终审 I-4）——断言写在 `flickerActuallyOscillates` 内部。
///
/// ## ⚠️⚠️ 频率：本转场**自己钉死**动画时长，不跟随调用方
///
/// 一次转场里发生 `cycles` 次明暗往复 ⇒ 感知频率 = `cycles ÷ 时长`。
/// ⚠️ **上一版把这条账写进文档就算完，那是不够的**（终审 I-3）：最常见的写法
/// `withAnimation { shown.toggle() }`（`.default` ≈ 0.35 s）在默认 `cycles = 3` 下给出
/// **≈ 8.6 次/秒**、depth 0.75 的往复——对**未**开启「减弱闪烁灯光」的光敏用户，
/// 那是库自己的默认路径在伤人。「不这样写会伤到用户」不能由文档兜底。
///
/// ⇒ `FlickerChrome` 用 `.animation(_:value:)` 把这段转场钉在
/// `FlickerPace.duration(cycles:)` 上（显式动画 modifier 覆盖调用方事务里的 ambient 动画）
/// ⇒ 感知频率恒 ≤ `FlickerPace.maximumFlashesPerSecond`（2.5 次/秒，WCAG 2.3.1 的 3 次/秒
/// 线下留一档余量），**与调用方写了多短的时长无关**。默认 3 次 ⇒ 1.2 秒。
/// 代价、限度与「为什么不走 `Transition.animation(_:)`」逐条记在 `FlickerPace` 的类型文档里。
///
/// ⚠️ 那道 a11y 闸仍然在：开启「减弱闪烁灯光」或「减弱动态效果」的用户拿到的是
/// 单调淡出（`cycles = 0` ⇒ 时长回落到 `FlickerPace.calmedDuration`）。
/// 两者是**独立**的两层——闸管"要不要闪"，`FlickerPace` 管"闪多快"。
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

    /// ⚠️⚠️ **`false` 是一次显式裁决，不是照抄另外三个**（终审 C-4）：留 `true` 会让框架
    /// 在 Reduce Motion 下把整条转场换成 `.opacity`，与本文件那道手写闸重复，
    /// 且会把手写闸在那条路径上变成**死代码**（判据仍钉着它，屏幕上却不走它）；
    /// 何况 `hasMotion` 对**只开「减弱闪烁灯光」**的用户零保护，当不了主保护。
    /// 取 `false` ⇒ 手写闸是唯一保护，文档、判据与屏幕上发生的事三者一致。
    /// 两条路的完整权衡见 `FilterTransitionSupport.swift` 的
    /// 《`TransitionProperties.hasMotion`》一节。
    public static let properties = TransitionProperties(hasMotion: false)

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
/// 对本文件同时数 `self.dimFlashingLights` 与 `self.reduceMotion` 两个计数，
/// 而 `accessibilityKeyPathsLiveOnlyInsideThePinnedChromes` 再扫**不可改名的键路径本身**
///（改个变量名就能绕过按字面子串的计数——终审 C-3 实证过）。
///
/// ⚠️⚠️ **`.animation(_:value:)` 那一行是承重的**（终审 I-3）：它把闪烁的
/// **速率**从调用方手里收回来，理由与代价见 `FlickerPace`。它挂在**闸的输出**
/// `cycles` 上而不是 `self.cycles` ⇒ 压制档拿到的是一次普通时长的淡出，
/// 而不是被拉长到 1.2 秒的淡出。
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

// MARK: - 节奏（把闪烁的**速率**从调用方手里收回来）

/// 闪烁的**时间**契约：一次转场持续多久，由本转场自己钉死。
///
/// ⚠️⚠️ **这是终审 I-3 的处置**：上一版把「感知频率 = `cycles` ÷ 调用方时长」这条账
/// 写进文档、把安全责任留给调用方，而库的**默认路径本身**不安全
///（`withAnimation { … }` 的 `.default` ≈ 0.35 s × 默认 3 次 ⇒ ≈ 8.6 次/秒）。
///
/// ⇒ `FlickerChrome` 用 `.animation(_:value:)` 把这段转场钉在 `duration(cycles:)` 上。
/// 显式动画 modifier 覆盖调用方事务里的那条 ambient 动画 ⇒ 感知频率
/// = `cycles ÷ duration(cycles)` ≤ `maximumFlashesPerSecond`，与调用方无关。
///
/// ⚠️ **代价与限度，逐条照录**：
/// 1. **调用方对这条转场的时长失去控制**：`withAnimation(.easeInOut(duration: 0.2))`
///    不再能缩短它。这是有意的——闪烁有内在节奏，"快到不安全"那一档不该是可选项。
///    另外三种转场**不**钉时长（它们没有"频率"这回事），本条只改 `flicker`。
/// 2. **没有走 SwiftUI 自己的 `Transition.animation(_:)`**：它存在
///    （`public func animation(_:) -> some Transition`），但返回**不透明类型**
///    ⇒ `extension Transition where Self == FlickerTransition` 那套点语法入口点
///    与 `Host.member` 登记键都得跟着变形。本形态把公开 API 形状原样留住，
///    只在 chrome 内部加一行 modifier。
/// 3. **单测看不见时序**：本仓的 harness（`ImageRenderer`）拍的是静态帧，
///    「这段动画真的跑了 1.2 秒」在 macOS 单测里**不可观测**。本条的机器判据只有两半
///    ——纯函数的速率上界（`FilterTransitionTests.flickerPaceStaysUnderTheFlashRateLimit`）
///    与 `chromeBodiesArePinnedVerbatim` 逐字钉住的那一行 `.animation(...)`。
///    时序本身靠 `#Preview` 人工确认；这条限度如实登记，**不假称已验证**。
/// ⚠️ 即便 SwiftUI 在调用方事务结束时提前把视图摘掉（截断本条转场），
/// 安全性质仍然成立：截断只会**少放几次**闪烁，抬不高**速率**——
/// 速率就是 `cycles ÷ duration` 这条比值本身，而它已经被钉死。
nonisolated enum FlickerPace {

    /// 允许的最高闪光速率（次 / 秒）。
    ///
    /// ⚠️ WCAG 2.3.1 的通用闪光阈值线是 **3 次/秒**；取 2.5 留一档余量，
    /// 免得缓入缓出的动画曲线把中段的瞬时速率顶到线上。
    static let maximumFlashesPerSecond: Double = 2.5

    /// 无往复时（压制档 `cycles == 0`）的时长——一次普通的淡入淡出。
    ///
    /// ⚠️ **不能取 0**：0 会让压制档变成硬跳变，而那道闸的结论是
    /// 「仍然淡入淡出，只去掉往复」，不是"删掉这条转场"。
    static let calmedDuration: Double = 0.35

    /// 给定（**已经过安全闸压制的**）往复次数的转场时长，单位秒。
    ///
    /// - Parameter cycles: 负数按 0 处理——库代码对非法入参不抛断言（epic 的 AD-F）。
    static func duration(cycles: Int) -> Double {
        let n = Double(Swift.max(0, cycles))
        return Swift.max(Self.calmedDuration, n / Self.maximumFlashesPerSecond)
    }
}

// MARK: - 公开入口点（`Transition` 的静态成员）

public extension Transition where Self == FlickerTransition {

    /// 闪烁转场。
    ///
    /// ⚠️ 本转场**自己钉死动画时长**（默认 3 次往复 ⇒ 1.2 秒，即 2.5 次/秒），
    /// 调用方 `withAnimation(_:)` 里的时长对它不生效——理由与代价见 `FlickerPace`。
    static var flicker: FlickerTransition { FlickerTransition() }

    /// 闪烁转场，可指定往复次数。
    ///
    /// ⚠️ 与无参 `static var flicker` 按 `Host.member` 去重，**算同一种转场**。
    /// ⚠️ 传进来的值仍会被那道 a11y 闸压制到 0——调用方**绕不过**它。
    /// ⚠️ 调高 `cycles` 只会把转场**拉长**（`FlickerPace.duration(cycles:)`），
    /// **抬不高速率**——调用方同样绕不过 2.5 次/秒这条线。
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

        // ⚠️ 这里**故意写一个很短的时长**：本转场自己把节奏钉在
        // `FlickerPace.duration(cycles: 3)` = 1.2 秒上，调用方的 0.25 秒对它不生效。
        // 预览里看到的仍然是 1.2 秒、3 次往复 —— 那正是 I-3 要的「默认路径安全」。
        Button("切换") { withAnimation(.easeInOut(duration: 0.25)) { shown.toggle() } }
    }
    .padding(CoreSpacing.huge)
}
