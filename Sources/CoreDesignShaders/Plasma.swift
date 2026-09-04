//
//  Plasma.swift
//  CoreDesignShaders
//

import CoreDesign
import SwiftUI

/// 程序化等离子背景。适合作 onboarding / paywall / 启动页的底层。
///
/// ```swift
/// ZStack {
///     Plasma().ignoresSafeArea()
///     content
/// }
/// ```
///
/// ⚠️⚠️ **不再声称「自研实现，非移植」**（第 3 轮终审 C-1）。两处都得改：
///
/// 1. **上一版的「射程限定」引了本 shader 根本没用到的原语**——它写着
///    「用到的共享原语（`wangHash` / `hash21` / `hash22`）有明确出处」，
///    而 `coreDesignPlasma` 的函数体**一次 hash 都没调**，只用 `cd::ramp3`。
///    这与上一轮被判掉的 ashima 引用是**同一个错误的镜像**：引用了一个
///    署名干净但实际没用到的来源。
/// 2. **四相正弦叠加不是无出处的「经典配方」**：`sin(x)` / `sin(y)` /
///    `sin((x+y)/2)` / `sin(dist)` 四项与 Lode Vandevenne《Lode's Computer
///    Graphics Tutorial — Plasma》里被无数 demoscene / Shadertoy 版本转抄的公式
///    `sin(dist(x,y,cx,cy)/8) + sin(x/16) + sin(y/8) + sin((x+y)/16)`
///    **逐项对应**，差别只是把除数参数化成 `frequency`、每项加了不同时间相位。
///    按本仓写死的判据（「改常量不构成独立」）——**与 `InkSmoke` 被降级同理**。
///    ⚠️ 「经典配方」四个字是**没有出处的肯定式借用声明**，正是 #249 裁定要求
///    转成正向判决的那一类。⇒ 出处待 #249 裁定表收录。
///    ⚠️⚠️ **#281 补上许可实查**：plasma 页页脚的 `All rights reserved` **只管散文**；
///    `https://lodev.org/cgtutor/legal.html` 把教程**代码**单独授权为 **BSD-2-Clause**
///    ⇒ 与本仓 MIT 分发兼容。**义务：保留版权通知 + 两条条件 + 免责声明全文**
///    （一句「参考自 Lode 的教程」不满足 BSD 第 1 条）。
///    ⚠️ 有利的一半同样如实记：他那组具体取值（中心、除数）**本仓一个都没用**
///    ——四项全部参数化、各带不同时间相位 ⇒ 取的是思路层。通知照给，成本为零。
///
/// 本仓自有的部分是参数化（`Density` 语义档位）与经 `ShaderRamp` 的三档取色。
/// 差异化依据见 `docs/shader-provenance.md`《第三条出路：自研实现》。
public struct Plasma: View {

    /// 视觉密度。⚠️ 一个语义枚举，而不是"频率 + 叠加层数"两个裸旋钮。
    public nonisolated enum Density: Sendable, CaseIterable {
        case subtle, regular, dense

        var field: (frequency: Float, octaves: Float) {
            switch self {
            case .subtle: (4.0, 1)
            case .regular: (7.0, 2)
            case .dense: (11.0, 3)
            }
        }
    }

    private let tint: Color
    private let density: Density
    private let motion: ShaderMotion

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// - Parameter tint: 调色基色，三档斜坡由它推导。默认 `Color.accent`。
    ///
    ///   ⚠️ **这里不能走 `.tint` 通路，与 `.core` control style 的规矩不同**——那条规矩
    ///   成立的前提是 `ShapeStyle` 能直接喂给 SwiftUI 绘制；Metal 需要**具体的颜色分量**，
    ///   而 SwiftUI **没有公开 API 能把 `.tint` 读成 `Color`**。⇒ 只能走 FR-8 的第①条
    ///   合法来源「调用方参数」，默认值取第③条「语义 token」。**这不是漏了 `.tint` 通路。**
    public init(
        tint: Color = .accent,
        density: Density = .regular,
        motion: ShaderMotion = .regular
    ) {
        self.tint = tint
        self.density = density
        self.motion = motion
    }

    public var body: some View {
        let ramp = ShaderRamp(tint: self.tint, reduceTransparency: self.reduceTransparency)
        let field = self.density.field

        // ⚠️ `ShaderLibrary.bundle(.module)` 在这里（`body`，MainActor 上下文）先取成值，
        // 不在下面的闭包里取——那个闭包是 `@Sendable` 的，`Bundle.module` 是 MainActor
        // 隔离的（#261 终审 I-1）。
        let library = ShaderLibrary.bundle(.module)

        return ProceduralBackground(base: ramp.low, motion: self.motion) { size, t in
            library.coreDesignPlasma(
                .float2(size),
                .float(t),
                .float(field.frequency),
                .float(field.octaves),
                .color(ramp.low),
                .color(ramp.mid),
                .color(ramp.high)
            )
        }
    }
}

#Preview("Plasma") {
    VStack(spacing: 0) {
        ForEach(Array(Plasma.Density.allCases.enumerated()), id: \.offset) { _, d in
            Plasma(density: d)
                .overlay(alignment: .topLeading) {
                    Text(String(describing: d)).font(.caption.monospaced()).padding(8)
                }
        }
    }
    .ignoresSafeArea()
}
