//
//  BlurTransition.swift
//  CoreDesignEffects
//
//  失焦转场 / A defocus (blur) transition.
//

import CoreDesign
import SwiftUI

// MARK: - 转场本体

/// 视图进出时内容失焦并淡出（进入时反向合焦）。
///
/// ```swift
/// if showsCard {
///     Card { Text("Details") }.transition(.blur)
/// }
/// ```
///
/// ## Reduce Motion / 减弱闪烁灯光：**两个都不读，本转场不降级**
///
/// ⚠️ 这条结论是 `#266` 要求的「逐个判断」的结果，不是漏了：
///
/// - **前庭（光流）**：全文件没有一处位移 / 旋转 / 缩放
///   （判据 `FilterTransitionTests.filterClusterChangesImagingNotGeometry`
///   逐字断言本文件不含任何 `motionCalls` 关键字）⇒ 屏幕上没有任何东西在"移动"，
///   构不成 WCAG 2.3.3 与 Apple「减弱动态效果」所针对的那类诱因。
/// - **光敏**：两条曲线（模糊半径、不透明度）在进度上**单调且仿射**，
///   亮度不往复、不闪跳 ⇒ 与 WCAG 2.3.1 的闪光阈值无关。
/// - **降级会把它抹掉**：本转场 = 模糊 + 淡入淡出。去掉模糊剩下的就是 `.opacity`，
///   也就是说"降级"在这里等于**删掉这条转场**——那不是降级形态 1 也不是形态 2，
///   是把 API 变成一个骗人的别名。
///
/// ⇒ **不读任何 a11y 信号**，并由 `FilterTransitionTests.blurConsumesNoAccessibilitySignal`
/// 把这个决定钉在源码上：哪天有人给本文件加一处 `reduceMotion` /
/// `dimFlashingLights`，那条判据当场判红，逼人回到这段文档重新裁决。
///
/// ⚠️⚠️ **上面这条结论只有在 `properties.hasMotion == false` 时才是真的**：
/// `Transition.properties` 默认 `hasMotion == true`，而框架对该位的语义正是
/// 「Reduce Motion 开启时把这条转场**整个换成 opacity**」——那恰恰是本段说
/// 「等于删掉这条转场」的那件事。见下面 `properties` 的声明与
/// `FilterTransitionSupport.swift` 的《`TransitionProperties.hasMotion`》一节。
///
/// ## a11y 分工（FR-13）
///
/// 本转场**没有装饰层**——所有滤镜直接作用在调用方内容上，没有可以
/// `accessibilityHidden(true)` 的东西（藏掉的话藏的是调用方的内容，那是 bug）。
/// "这块内容出现 / 消失了"的通告仍由调用方提供。
public struct BlurTransition: Transition {

    /// 完全进入前 / 完全离开后的模糊半径（pt）。
    public let radius: CGFloat

    /// 默认模糊半径。
    ///
    /// ⚠️ **`public` 且住在本类型上**：它被两处 `public` 签名当默认实参用，
    /// 而 Swift 不允许默认实参引用 internal 符号（同 `ParticleTransition.defaultCount`）。
    /// ⚠️ **`nonisolated` 是承重的**：本包开了 `.defaultIsolation(MainActor.self)`，
    /// 不标的话这个常量对下游的 **nonisolated 上下文**（在后台线程准备转场参数的宿主
    /// 代码）不可达——`scripts/downstream-probe` 的
    /// `readFilterTransitionDefaults()` 是唯一看得见这件事的地方，不标就是一条
    /// `main actor-isolated static property … can not be referenced from a nonisolated
    /// context` 警告。
    /// ⚠️ **`#253` 的 `ParticleTransition.defaultCount` 今天仍带着这条警告**（本轮实测），
    /// 本簇不照抄那个形态；那一条归它自己的 follow-up，本 PR 不顺手改别人的文件。
    public nonisolated static let defaultRadius: CGFloat = 12

    /// ⚠️⚠️ **不写这一行，本类型文档的「不降级」裁决在运行时就是假的**（终审 C-4）：
    /// `Transition.properties` 的协议默认值是 `hasMotion == true`，其语义是
    /// 「Reduce Motion 开启时把这条转场替换成 opacity」⇒ 框架会替本转场做掉
    /// 它自己声明绝不能发生的那件事。判据：
    /// `FilterTransitionTests.everyTransitionOptsOutOfTheFrameworkMotionSubstitution`。
    public nonisolated static let properties = TransitionProperties(hasMotion: false)

    public init(radius: CGFloat = BlurTransition.defaultRadius) {
        self.radius = radius
    }

    public func body(content: Content, phase: TransitionPhase) -> some View {
        content.modifier(BlurTransitionChrome(phase: phase, radius: self.radius))
    }
}

/// 转场的实际绘制。**非泛型**（只吃 `TransitionPhase` + 一个 `CGFloat`）。
///
/// ⚠️⚠️ **本簇四个 Chrome 里只有它不套 `Animatable` 的绘制层**，理由是
/// `BlurFilm` 的两条曲线在进度上都是**仿射**的：
/// `radius = maximum · p`、`opacity = 1 − p`。对仿射 `f`，
/// 「SwiftUI 插值 `f` 的输出」与「先插值 `p` 再求 `f`」**逐点相等**
/// ⇒ 中间帧不会丢失任何形状，加一层 `Animatable` 只是多一个视图节点。
/// ⚠️ 这条豁免**有机器判据看着**：`FilterTransitionTests.blurCurvesAreAffine`
/// 逐点核对 `f((a+b)/2) == (f(a)+f(b))/2`。谁把曲线改成非仿射（比如给模糊加个
/// ease-out），那条判据当场判红——而那正是"必须加 `Animatable`"的信号，
/// 见 `FilterTransitionPhase` 的类型文档。
struct BlurTransitionChrome: ViewModifier {

    let phase: TransitionPhase
    let radius: CGFloat

    func body(content: Content) -> some View {
        let progress = FilterTransitionPhase.progress(phase: self.phase)
        return content
            .blur(radius: BlurFilm.radius(progress: progress, maximum: self.radius))
            .opacity(BlurFilm.contentOpacity(progress: progress))
    }
}

// MARK: - 曲线（纯函数，生产代码与判据共用同一份）

/// 失焦转场的成像曲线。
///
/// ⚠️ **抽出来的唯一理由是可测性**（与 `ParticleBurst` / `ConfettiBurst` 同一条纪律）：
/// 判据要能对**这条真曲线**求值，而不是在测试里重抄一遍常量。
nonisolated enum BlurFilm {

    /// 给定进度的模糊半径。
    ///
    /// - Parameter maximum: 调用方给的上限；负数 / `NaN` / `∞` 一律按 0 处理
    ///   （库代码对非法入参**不抛断言**——那是让宿主 App crash，见 epic 的 AD-F）。
    static func radius(progress: Double, maximum: CGFloat) -> CGFloat {
        let sane = maximum.isFinite ? Swift.max(maximum, 0) : 0
        return sane * CGFloat(FilterTransitionPhase.clamped01(progress))
    }

    /// 给定进度的内容不透明度。`.identity`（进度 0）⇒ 1。
    static func contentOpacity(progress: Double) -> Double {
        1 - FilterTransitionPhase.clamped01(progress)
    }
}

// MARK: - 公开入口点（`Transition` 的静态成员）

public extension Transition where Self == BlurTransition {

    /// 失焦转场。
    ///
    /// ```swift
    /// Card { Text("Details") }.transition(.blur)
    /// ```
    static var blur: BlurTransition { BlurTransition() }

    /// 失焦转场，可指定模糊半径。
    ///
    /// ⚠️ 与无参 `static var blur` 按 `Host.member` 去重，**算同一种转场**
    ///（`#251` 口径：计数单位是「一种 transition」不是「一个静态成员」）。
    static func blur(radius: CGFloat = BlurTransition.defaultRadius) -> BlurTransition {
        BlurTransition(radius: radius)
    }
}

#Preview("BlurTransition") {
    @Previewable @State var shown = true
    VStack(spacing: CoreSpacing.xxl) {
        ZStack {
            if shown {
                Text("Focus")
                    .font(.largeTitle.bold())
                    .padding(CoreSpacing.xxl)
                    .background(Color.surfaceRaised, in: RoundedRectangle(cornerRadius: CoreRadius.large))
                    .transition(.blur)
            }
        }
        .frame(height: 140)

        Button("切换") { withAnimation(.easeInOut(duration: 0.55)) { shown.toggle() } }
    }
    .padding(CoreSpacing.huge)
}
