//
//  GlassOrb.swift
//  CoreDesignShaders
//

import CoreDesign
import SwiftUI

// MARK: - GlassOrbModifier

/// 玻璃珠放大镜：一个跟手的圆形透镜，在圆内做随距离衰减的放大。
///
/// ## ⚠️ 形态选择：internal modifier + `public extension View`，**不是** `public struct: View`
///
/// AD-E 原写「11 个 `layerEffect` 落成 `public struct … : ViewModifier` + `public extension View`」，
/// 而 `CoreDesignShaders` 里两种形态都在树上（`RefractiveGlass` 是 internal modifier +
/// `public extension View`；`GlassSymbol` 是 `public struct: View`）。本件按**语义**选前者：
///
/// - `GlassSymbol` 之所以是 `View`，是因为它**自带内容**（`Image(systemName:)` + 渐变背衬）
///   —— 没有那层背衬折射就不成立，它必须拥有自己的内容。
/// - 本件**不产生任何内容**：它只重采样调用方给的内容层（`layer.sample`）。
///   做成 `View` 就得凭空要一个 `@ViewBuilder content:`，那是把 modifier 硬写成容器。
/// ⇒ 与 `RefractiveGlass` 同族，落 `entryPoints` 而不是 `components`。
///
/// ## ⚠️ modifier 类型本身有意是 `internal`
///
/// 与 `RefractiveGlassModifier` 同一条：公开面只有 `View.glassOrb(...)` 与两个语义枚举。
/// 把 `ViewModifier` 类型也 public 出去，等于承诺 `.modifier(GlassOrbModifier(...))`
/// 这条调用形态永远可用，而它不是本仓的调用惯例（`Modifier/` 目录的约定逐字写着
/// 「以 `View` 扩展形式暴露，而不是要求调用方写 `.modifier(...)`」）。
///
/// ## Provenance
///
/// ⚠️⚠️ **本件的 shader 是一次移植，不是自研。** 上游是
/// [Inferno](https://github.com/twostraws/Inferno) 的 `WarpingLoupe.metal`（Paul Hudson 等，**MIT**）
/// —— 逐条差异与移植档位见 `CoreDesignShaders.metal` 的 `coreDesignGlassOrb` 文档注释，
/// MIT 全文见 `ACKNOWLEDGEMENTS.md` 的《Inferno》一节。
///
/// ⚠️ **一条已知的残余风险，落地时如实记下**（`docs/shader-provenance.md`《#280 的落地前核验》③）：
/// 「Warping Loupe 不在 Inferno 的移植清单内 ⇒ 推论为 Inferno 原创」这条**推论的前提被 #280 下调**
/// —— Inferno 的 LICENSE 清单（6 组）与 README 清单（7 条）**互不一致**，且两份清单**从未声称穷尽**
/// （LICENSE 写 "**Many** shaders were ported"、README 写 "**Some**"）⇒ 清单不能当穷尽名单用。
/// 支持不掉档的是另外三条：整仓 MIT 授权、`warpingLoupe` 函数体**零魔数**（无指纹可追）、
/// 其文档自述派生自 Inferno 自有的 `SimpleLoupe`。
/// ⇒ 若 "Warping Loupe" 其实是一个未登记的、来自非 MIT 来源的移植，Inferno 对它就是无权再许可，
/// 我们跟着错。**该风险不是再查一轮能消除的，是接受并记录的**；本条即那份记录。
struct GlassOrbModifier: ViewModifier {

    let magnification: GlassOrbMagnification
    let size: GlassOrbSize

    /// ⚠️ **手势位置是 `@State` 而不是 `@GestureState`**：后者在手指抬起时**自动复位**，
    /// 放大镜会"啪"地跳回中心。放大镜是一个被放下的工具，不是一个按住才在的效果。
    @State private var focus: CGPoint?

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        // ⚠️ `visualEffect` 的闭包是 `@Sendable`：先在 MainActor 上下文里把值取出来。
        let library = ShaderLibrary.bundle(.module)
        let radius = Float(self.size.radius)
        let magnification = self.magnification.factor
        let softness = Self.softness(reduceTransparency: self.reduceTransparency)
        let focus = self.focus
        let maxOffset = self.size.radius

        return content
            .visualEffect { view, proxy in
                let centre = Self.focusPoint(gesture: focus, in: proxy.size)
                return view.layerEffect(
                    library.coreDesignGlassOrb(
                        .float2(proxy.size),
                        .float2(centre),
                        .float(radius),
                        .float(magnification),
                        .float(softness)
                    ),
                    // 圆内 `|delta| < radius` 且 `|totalZoom - 1| ≤ 1`
                    // ⇒ 位移上界就是 `radius`；圆外 `totalZoom == 1`，位移为 0。
                    maxSampleOffset: CGSize(width: maxOffset, height: maxOffset)
                )
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { self.focus = $0.location }
            )
    }

    /// 放大中心。**手势未发生时落在视图正中**。
    ///
    /// ⚠️ **抽成 `static` 纯函数是为了可断言**（沿用 `ProceduralBackground.elapsed` /
    /// `GlassSymbol.isDecorative` 的成法）：手势位置与 `@Environment` 一样，
    /// 脱离视图层级注入不了，写在 `body` 里这条契约就是零覆盖。
    ///
    /// ⚠️⚠️ **本函数刻意不接受 `reduceMotion`**（FR-12 的下半条）：放大镜跟手是**交互**，
    /// 不是动效。Reduce Motion 要冻结的是**时间**输入，而本件根本没有时间输入
    /// （见 `coreDesignGlassOrb` 的形参表：没有 `time`）。
    /// ⇒ **本 task 只声称 FR-12 的空间输入那一半**（手势不因 Reduce Motion 改变），
    /// 时间那一半在本批（`GlassOrb` / `Halftone` 两件）上**为空**，不作声称。
    /// 判据形态是「`.metal` 的签名里没有时间形参」，由
    /// `ShaderEntryPointGuard.contentLayerEffectsHaveNoTimeInput` 带反恒真对照钉住。
    nonisolated static func focusPoint(gesture: CGPoint?, in size: CGSize) -> CGPoint {
        gesture ?? CGPoint(x: size.width / 2, y: size.height / 2)
    }

    /// Reduce Transparency 下的柔化系数。
    ///
    /// ⚠️⚠️ **这里与 SC 原文的措辞有一处偏离，写在明处**：SC 写「`GlassOrb` 降级为**不透明**形态」，
    /// 而 `coreDesignGlassOrb` **全程不产生半透明像素**（它只把内容层重采样，alpha 原样透传）
    /// ⇒ 「变得不透明」在本件上没有对应的失效面，照字面兑现会变成一条恒真的空判据。
    ///
    /// 本件对该偏好的实际兑现是**取消变焦柔化**：`softness == 0` 时圆内放大倍率是常数、
    /// 边界是硬边 —— 观感从"一颗玻璃珠"（材质暗示）退化成"一枚均匀放大镜"（无材质暗示），
    /// 而**放大功能完整保留**。
    /// ⚠️ 之所以不照 `GlassSymbol` 那样直接 `isEnabled: false` 整个关掉：那里关掉的是**装饰**，
    /// 这里关掉的会是**功能**（放大镜是用来看清内容的）。
    /// ⚠️ **这条判断需要评审拍板**，PR 正文已点名。
    nonisolated static func softness(reduceTransparency: Bool) -> Float {
        reduceTransparency ? 0 : 1
    }
}

// MARK: - 语义档位

/// 放大镜的尺寸。⚠️ 语义枚举，不暴露裸的"半径像素数"。
///
/// ⚠️⚠️ **每一档的直径都必须 ≥ 44pt**：这枚透镜是**被拖动的手柄**（`DragGesture` 直接挂在
/// 它所在的内容上，用户按住哪里镜就去哪里），因此它自身就是触控目标。
/// 该地板由 `GlassOrbStopTests.touchTargetFloor` 钉住 —— ⚠️ 那条测试**有意写在
/// `CoreDesignShadersTests` 内**，**不得**并进 `CoreDesignTests.TouchTargetTests`：
/// 后者会把 `CoreDesignShaders` 拖进 `CoreDesignTests` 的依赖图，判红 NFR-5②
///（`CoreDesignTests` 的 `target_dependencies` 须恰为 `["CoreDesign"]`）。
public nonisolated enum GlassOrbSize: Sendable, CaseIterable {
    case small, regular, large

    /// 半径（点）。⚠️ 最小一档 24pt ⇒ 直径 48pt > 44pt 地板。
    nonisolated var radius: CGFloat {
        switch self {
        case .small: 24
        case .regular: 44
        case .large: 72
        }
    }

    /// 直径（点）—— 触控目标就是它。
    nonisolated var diameter: CGFloat { self.radius * 2 }
}

/// 放大倍率。⚠️ 语义枚举，同上。
public nonisolated enum GlassOrbMagnification: Sendable, CaseIterable {
    case gentle, regular, strong

    nonisolated var factor: Float {
        switch self {
        case .gentle: 1.6
        case .regular: 2.4
        case .strong: 4.0
        }
    }
}

// MARK: - View

public extension View {

    /// 在本视图上放一枚跟手的玻璃珠放大镜。
    ///
    /// ```swift
    /// Text("CoreDesign").font(.largeTitle)
    ///     .glassOrb()
    ///
    /// Image("map").resizable()
    ///     .glassOrb(size: .large, magnification: .strong)
    /// ```
    ///
    /// - 手势：`DragGesture(minimumDistance: 0)`，按下即定位，**抬手后停在原处**。
    ///   未发生手势时落在视图正中。
    /// - **Reduce Motion**：本 modifier **没有时间输入**（放大由几何与手势驱动），
    ///   按 FR-12 属"冻结时间、保留空间"里空间的那一半 ⇒ 手势跟随**不受**该偏好影响。
    /// - **Reduce Transparency**：取消变焦柔化，退化成均匀放大镜（功能保留），
    ///   理由见 `GlassOrbModifier.softness(reduceTransparency:)`。
    /// - **a11y**：本 modifier **不隐藏任何东西**。FR-13 管的是"shader 装饰层"
    ///   （本 target 里是 `ProceduralBackground` 那一族自带内容的装饰背景）；
    ///   本件作用在**调用方的内容**上，把它移出 a11y 树会连内容一起吃掉。
    ///   ⚠️ 本批（`GlassOrb` / `Halftone`）**不新增任何装饰层** ⇒ FR-13 在本批上无对象。
    ///
    /// - Parameters:
    ///   - size: 透镜尺寸档位。⚠️ 每档直径都 ≥ 44pt（它是被拖动的手柄）。
    ///   - magnification: 放大倍率档位。
    func glassOrb(
        size: GlassOrbSize = .regular,
        magnification: GlassOrbMagnification = .regular
    ) -> some View {
        self.modifier(GlassOrbModifier(magnification: magnification, size: size))
    }
}

// MARK: - Preview

#Preview("GlassOrb") {
    VStack(spacing: 20) {
        Text(verbatim: "CoreDesign")
            .font(.system(size: 44, weight: .bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .background(Color.surfaceRaised)
            .glassOrb()

        ForEach(Array(GlassOrbSize.allCases.enumerated()), id: \.offset) { _, s in
            LinearGradient(
                colors: [.accent, .accentSubtleBackground],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 100)
            .overlay {
                Text(verbatim: String(describing: s))
                    .font(.title.bold())
            }
            .glassOrb(size: s, magnification: .strong)
        }
    }
    .padding()
}
