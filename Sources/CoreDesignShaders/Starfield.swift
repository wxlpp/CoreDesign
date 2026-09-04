//
//  Starfield.swift
//  CoreDesignShaders
//

import CoreDesign
import SwiftUI

/// 程序化星空背景。网格分格 + 每格一颗随机星，亮度按距离衰减、相位各自独立。
///
/// ⚠️⚠️ **不再声称「自研实现，非移植」**（第 5 轮终审 I-2）：那是一个**肯定式**声称，
/// 在 `docs/shader-provenance.md` 落地前**没有任何正向裁定支持它**，与已被判掉的
/// 「公开构造」型断言在证据地位上完全对称。
/// 且指纹并不弱：`cell = floor(uv*grid)` + `local = fract(uv*grid) - 0.5` +
/// `hash22(cell)` 抖动 + `hash21(cell + k)` 亮度 + `step` 熄灭 + `smoothstep` 辉光 +
/// `sin(time·w + hash·6.2831853)` 闪烁——是网格星空模板的逐项形态
/// （`id`/`gv` 只是被改名成 `cell`/`local`）。而本仓刚把「连变量名都保留」当作复制证据、
/// 把「只改常量」判为不构成独立——**改名 + 改常量当然更不构成独立**。
/// ⇒ 裁定交 #249。
/// ⚠️ **本类型不作任何原创声称**（上一版此处还留着「"自研"的射程仅限组合与参数化」，
/// #281 一并删掉——追到不兼容上游之后，连"组合是自研的"这句也不该再说）。
/// 本 shader 调用 `cd::hash21` / `cd::hash22`（已逐函数核对），它们有明确出处
/// （Wang·Reed 的整数 hash / Teschner et al. 2003 的素数三元组），
/// 见 `CoreDesignShaders.metal` 原语区。
///
/// ⚠️⚠️⚠️ **#281 追溯结论：本类型已被 `docs/shader-provenance.md` 判为 `不落地`。**
///
/// 上面那段「是网格星空模板的逐项形态」当时**没有具名到人**——#281 具名到了：
/// **Martijn Steinrucken（BigWings / *The Art of Code*）《Starfield Tutorial》(2020)**，
/// 源码头逐字 `// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0
/// Unported License.` ⇒ **CC BY-NC-SA 3.0，与 CoreDesign 的 MIT 分发不兼容**
/// （既禁商用，又有传染性 share-alike）。命中 provenance 表兜底的
/// 「**追到不兼容**」分支 ⇒ `不落地`。
///
/// ⚠️ **决定性旁证**：`CoreDesignShaders.metal` 文件头记着 `hash21` 第一版用的是
/// `123.34 / 456.21 / 45.32`——**正是同一份 CC BY-NC-SA 文件里 `Hash21` 的常量，
/// 逐字符一致** ⇒ 接触与复制均有直接证据。
///
/// ⚠️ **上一版也有过度归因的一半，一并更正**：`step` 熄灭门限与 `smoothstep` 圆盘辉光
/// **追不到任何上游**（BigWings 用的是 `.05/d` 反距离辉光，且没有 `step` 门限）。
/// 真正对应的是网格分解、每格 hash 抖动、与闪烁相位那一行。
///
/// ⚠️ **撤回未执行，由 owner 拍板**；在此之前本类型**阻断 `epic → main`**。
/// 撤回范围与唯一的替代方案见 `docs/shader-provenance.md`《`Starfield` 的追溯》。
public struct Starfield: View {

    /// 星密度。⚠️ 一个语义枚举，而不是"格数"这个裸数值。
    public nonisolated enum Density: Sendable, CaseIterable {
        case sparse, regular, dense

        var cells: Float {
            switch self {
            case .sparse: 14
            case .regular: 24
            case .dense: 38
            }
        }
    }

    private let tint: Color
    private let density: Density
    private let motion: ShaderMotion

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// - Parameters:
    ///   - tint: 星的颜色。天空色由它推导（`ShaderRamp.low`）。默认 `Color.accent`。
    ///     ⚠️ 不能走 `.tint` 通路的理由见 `Plasma.init` 的说明。
    ///   - motion: `.still` 时星**不闪烁**（不是"闪得慢"）。
    public init(
        tint: Color = .accent,
        density: Density = .regular,
        motion: ShaderMotion = .calm
    ) {
        self.tint = tint
        self.density = density
        self.motion = motion
    }

    public var body: some View {
        let ramp = ShaderRamp(tint: self.tint, reduceTransparency: self.reduceTransparency)
        // ⚠️ `.still` ⇒ 闪烁振幅为 0。Reduce Motion 由 `ProceduralBackground` 冻结时间，
        // 两条路径都会让画面静止，但语义不同：前者是调用方要静态，后者是系统偏好。
        let twinkle: Float = self.motion == .still ? 0 : 1
        let cells = self.density.cells

        // ⚠️ `ShaderLibrary.bundle(.module)` 在这里（`body`，MainActor 上下文）先取成值，
        // 不在下面的闭包里取——那个闭包是 `@Sendable` 的，`Bundle.module` 是 MainActor
        // 隔离的（#261 终审 I-1）。
        let library = ShaderLibrary.bundle(.module)

        return ProceduralBackground(base: ramp.low, motion: self.motion) { size, t in
            library.coreDesignStarfield(
                .float2(size), .float(t),
                .float(cells), .float(twinkle),
                .color(ramp.low), .color(ramp.high)
            )
        }
    }
}

#Preview("Starfield") {
    VStack(spacing: 0) {
        ForEach(Array(Starfield.Density.allCases.enumerated()), id: \.offset) { _, d in
            Starfield(density: d)
                .overlay(alignment: .topLeading) {
                    Text(String(describing: d)).font(.caption.monospaced()).padding(8)
                }
        }
    }
    .ignoresSafeArea()
}
