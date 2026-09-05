//
//  Halftone.swift
//  CoreDesignShaders
//

import CoreDesign
import SwiftUI

// MARK: - HalftoneModifier

/// 半调网屏：把内容层按网格取样，用**点的大小**表示明暗，输出成油墨 + 纸两色的印刷观感。
///
/// ## ⚠️ 形态选择：internal modifier + `public extension View`
///
/// 与 `GlassOrb` 同一条理由（详见 `GlassOrbModifier` 的同名小节）：本件**不产生内容**，
/// 只重排调用方内容层的像素 ⇒ 结构上进 `entryPoints` 而不是 `components`。
/// 反例是 `GlassSymbol`：它必须自带符号与渐变背衬，效果才成立，所以它是 `public struct: View`。
///
/// ## Provenance
///
/// ⚠️⚠️ **本件的 shader 是一次移植。** 上游是
/// [paper-design/shaders](https://github.com/paper-design/shaders) 的
/// `packages/shaders/src/shaders/halftone-dots.ts`，**Apache-2.0**。
/// 保留的结构、逐条修改标注（§4(b)）与"为什么没有移植 CMYK 那一半"都写在
/// `CoreDesignShaders.metal` 的 `coreDesignHalftone` 文档注释里；
/// LICENSE 全文 / `NOTICE` / 第三方 MIT 通知在 `ACKNOWLEDGEMENTS.md`。
///
/// ⚠️ **ShipSwift 自己在 `SWHalftone.metal:350` 写着 "simplified port"** —— 它也是移植，
/// 不是原创，本仓不因"ShipSwift 有一份"就把上游当成 ShipSwift。
///
/// ⚠️ **paper 完全没有兑现第三方 MIT 通知义务**（其 `NOTICE` 全文只有
/// 「Powered by Paper Shaders」两行，一手核）：`halftone` 一族的 hash 追到
/// **Inigo Quilez**（`0.3183099`）与 **Dave Hoskins**（`19.19`），两位都是 MIT。
/// ⇒ 那两份通知**由本仓自己补**，已落在 `ACKNOWLEDGEMENTS.md`。
/// ⚠️ 本次移植**没有复制那些 hash**（`coreDesignHalftone` 一个 hash 都不调用），
/// 通知仍照给 —— 义务跟着 `Halftone` 这个档位走，宁可多给。
struct HalftoneModifier: ViewModifier {

    let dot: HalftoneDot
    let ink: Color
    let paper: Color

    /// 单色网屏的惯例角度：**45°**。
    ///
    /// ⚠️ 这是印刷业的通行取值（单色半调把网屏转到 45°，是因为正交网格在 0° 上
    /// 会与画面的水平/垂直边缘共振出可见的行列纹）—— **事实性惯例，不是谁的表达**。
    /// ⚠️ 写成 `static let` 而不是 public 参数：本仓的调参惯例是语义档位单一来源，
    /// 一个裸的"角度弧度数"不属于公开面。要做四色分色（各通道不同角度）时再谈。
    static let screenAngle: Float = .pi / 4

    func body(content: Content) -> some View {
        // ⚠️ `visualEffect` 的闭包是 `@Sendable`：先在 MainActor 上下文里把值取出来。
        let library = ShaderLibrary.bundle(.module)
        let cell = Float(self.dot.cell)
        let dotScale = self.dot.dotScale
        let angle = Self.screenAngle
        let ink = self.ink
        let paper = self.paper
        // 取样点是**本格格心**：格空间里距离 ≤ √2/2，旋转保长 ⇒ 用户空间逐轴 ≤ 0.707 · cell。
        // 声明整格 `cell` ⇒ **1.41× 余量**。
        // ⚠️ **这条余量绑在"正交网格 + 格心取样"这个形态上，不是一劳永逸的**（终审 S-2）：
        // 换六边形网格、或加上游那种 `u_gridNoise` 的 ±0.5 格抖动，上界会到约 1.21 · cell
        // ⇒ **越界**，而 `maxSampleOffset` 越界不报错、只是采样被静默截断。
        // 对称的另一条在 `GlassOrbModifier` 里（那一条已由"向 1.0 插值"的形式本身保证）。
        let maxOffset = self.dot.cell

        return content.visualEffect { view, proxy in
            view.layerEffect(
                library.coreDesignHalftone(
                    .float2(proxy.size),
                    .float(cell),
                    .float(angle),
                    .float(dotScale),
                    .color(ink),
                    .color(paper)
                ),
                maxSampleOffset: CGSize(width: maxOffset, height: maxOffset)
            )
        }
    }
}

// MARK: - 语义档位

/// 网点粗细。⚠️ 语义枚举，不暴露裸的"格宽 + 点半径"两个旋钮。
///
/// 三档的关系是本枚举的语义承诺（格子越粗、单点越大），由
/// `HalftoneStopTests.dotStopsAreMonotonic` 钉住。
public nonisolated enum HalftoneDot: Sendable, CaseIterable {
    case fine, regular, coarse

    /// 网格边长（点）。
    nonisolated var cell: CGFloat {
        switch self {
        case .fine: 4
        case .regular: 8
        case .coarse: 16
        }
    }

    /// 最黑处的点半径，单位是**格宽的倍数**。
    ///
    /// ⚠️ 上界是 `√2 / 2 ≈ 0.707`（点内切到格角）——超过它相邻格的点会互相吞掉，
    /// 纯黑区域糊成一片、半调的意义消失。三档都留了余量。
    nonisolated var dotScale: Float {
        switch self {
        case .fine: 0.52
        case .regular: 0.58
        case .coarse: 0.64
        }
    }
}

// MARK: - View

public extension View {

    /// 把本视图印成半调网屏。
    ///
    /// ```swift
    /// Image("portrait").resizable().scaledToFit()
    ///     .halftone()
    ///
    /// Text("SALE").font(.system(size: 120, weight: .black))
    ///     .halftone(dot: .coarse, ink: .accent)
    /// ```
    ///
    /// - **不吃时间**：半调是对内容层的**空间**重排，没有时间输入
    ///   ⇒ 按 FR-12 无需 Reduce Motion 降级（没有可冻结的东西）。
    /// - **Reduce Transparency**：本 modifier **不模拟任何半透明材质**
    ///   —— 半调是对内容层的**空间重排**（点的大小编码明暗），不是玻璃 / 毛玻璃那类
    ///   "让你看见后面有东西"的材质暗示 ⇒ 该偏好在本件上没有对应的失效面，无降级。
    ///   ⚠️⚠️ **理由只能挂在这一条上，不能挂在"不产生半透明像素"上**（#303 终审 I-1）：
    ///   上一版逐字写着「本 modifier 不产生任何半透明材质（输出只在 `ink` 与 `paper`
    ///   两色之间插值）」，而那句**已被实测证伪** —— 默认 `paper: .clear` 是预乘全零，
    ///   `mix(paper, ink, coverage)` 的 alpha **就是** `coverage`，而 `coverage` 经
    ///   `cd::edgeWidth` 抗锯齿是**连续量**：对不透明纯黑内容施 `.halftone(dot: .coarse)`，
    ///   64×64 共 4096 像素实测 **opaque 2974 / clear 606 / partial 516**
    ///   ⇒ 12.6% 半透明 + 14.8% 全透明。**输出确实带 alpha 梯度**，只是那不是"材质"。
    /// - **a11y**：本 modifier **不隐藏任何东西**，理由同 `View.glassOrb(size:magnification:)`。
    ///
    /// - Parameters:
    ///   - dot: 网点粗细档位。
    ///   - ink: 油墨色。默认 `Color.contentPrimary`（随系统外观 / 对比度自动适配）。
    ///     ⚠️ 不能走 `.tint` 通路 —— shader 读不到环境里的 `.tint`（沿用 #261 的形态）。
    ///   - paper: 纸色。**默认 `.clear`** = 印在透明背景上，只有墨点是实心的；
    ///     传一个实色即得到"整块纸"的观感。
    func halftone(
        dot: HalftoneDot = .regular,
        ink: Color = .contentPrimary,
        paper: Color = .clear
    ) -> some View {
        self.modifier(HalftoneModifier(dot: dot, ink: ink, paper: paper))
    }
}

// MARK: - Preview

#Preview("Halftone") {
    VStack(spacing: 20) {
        ForEach(Array(HalftoneDot.allCases.enumerated()), id: \.offset) { _, d in
            LinearGradient(
                colors: [.contentPrimary, .surfaceCanvas],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 90)
            .halftone(dot: d)
            .overlay(alignment: .topLeading) {
                Text(verbatim: String(describing: d))
                    .font(.caption.monospaced())
                    .padding(6)
            }
        }

        Text(verbatim: "SALE")
            .font(.system(size: 96, weight: .black))
            .halftone(dot: .coarse, ink: .accent)
    }
    .padding()
}
