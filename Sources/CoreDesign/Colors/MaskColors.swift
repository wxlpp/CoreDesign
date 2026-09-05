//
//  MaskColors.swift
//  CoreDesign
//
//  纯 alpha 遮罩的基色 / The opaque base colour for pure-alpha masks.
//

import SwiftUI

// MARK: - Mask Colors / 遮罩基色（Issue #276）
//
// 本文件只有一个 token，而且它**不是一个颜色决定**：`.mask { … }` 读的是遮罩内容的
// **alpha 通道**，RGB 通道根本不参与合成。macOS 26 实测（`ImageRenderer`、40 × 20、
// 取中心像素）：
//
//     Rectangle().fill(.orange).mask { Color.black }  → rgba=(255, 141, 40, 255)
//     Rectangle().fill(.orange).mask { Color.white }  → rgba=(255, 141, 40, 255)
//     逐字节相同 = true
//
// ⇒ 遮罩基色唯一承重的性质是 **α = 1**；写白还是写黑没有任何可观测差别。
//
// ## 它为什么必须存在
//
// Effects 层此前一律拿 `Color.primary` 当遮罩基色，注释宣称
//「`.primary` 恒为不透明 ⇒ 与写死 `.white` 等效，但它是语义色」。
// ⚠️ **这句话的两个半句都不成立**：
//
//     macOS 26（AppKit labelColor）：Color.primary  light a=0.8471 | dark a=0.8471
//     iOS 26（UIKit label）：        Color.primary  light a=1.0000 | dark a=1.0000
//     两端平台：                     Color.white    light a=1.0000 | dark a=1.0000
//
// · 前半句「恒为不透明」是**平台相关的事实错误**——它在 iOS 上恰好成立，
//   在 macOS 上是错的，而那句注释写的是**无条件**形式；
//   ⚠️ 这一行是 Issue #276 正文**没有**的，本轮 iOS 腿实测出来的，
//   登记在 `MaskOpaqueTokenTests.primaryAlphaIsPlatformDependent`。
// · 后半句「但它是语义色」在**两个**平台上都没有价值——语义色的好处是 RGB 随外观走，
//   而 mask 只吃 alpha，那份好处落在一个不参与合成的通道上。
//   ⇒ 这是本仓「结论对、理由假」缺陷族的一个标本：理由整条是空的。
//
// 后果是每一处这样的遮罩在 **macOS 上**额外乘了 0.847。实测（macOS，红叠蓝、完全揭示）：
//
//     无遮罩              rgba=(255, 56, 60, 255)
//     mask(Color.primary) rgba=(216, 68, 90, 255)   ← 底下的蓝透上来了 = ghosting
//     mask(Color.white)   rgba=(255, 56, 60, 255)   ← 与无遮罩逐字节相同
//
// ⚠️ **严重性照录，别读大也别读小**：#276 写的「已发布组件里可见的 ghosting」
// **只在 macOS 腿上成立**；iOS 上旧代码渲染是对的。修它的理由因此不是"iOS 上坏了"，
// 而是「依赖一个未文档化、平台相关的 α」本身就是缺陷，且本包是双平台库。
//
// ## 为什么落在 `CoreDesign` 而不是 `CoreDesignEffects`
//
// `EffectsColorLiteralGuard` 的 `hueNames` 含 `white` / `black`、`numericColorLabels`
// 含 `white` ⇒ **颜色**写法里能写死 α = 1 的三种（`Color.black` / `Color.white` /
// `Color(white: 1)`）在新 target 里全被判红，而该守卫**至今没有例外台账**
//（「用削弱判据来消化一个例外」正是它文件头点名禁止的形态）。
//
// ⚠️⚠️ **上一句刻意限定在「颜色写法」上，别把它读成全称句**（#276 终审 F3 实测反例）：
// **未填色的 `Shape`** 放进遮罩同样是 α = 1，而且它**不含任何颜色字面量**
// ⇒ `EffectsColorLiteralGuard` 碰不到它。本轮 macOS 实测（红叠蓝、40 × 20 取全图字节）：
//
//     light: bare == mask { Rectangle() }  true  | bare == mask { Color.primary }  false
//     dark : bare == mask { Rectangle() }  true  | bare == mask { Color.primary }  false
//
// 仓内已有**生产**先例：`Sources/CoreDesign/Components/Rating/Rating.swift` 的
// `star(at:)` 就是 `.mask(alignment: .leading) { Rectangle().frame(...) }`。
// ⇒ 本 token 的必要性**只对色标那一族成立**：`ProcessingSweep` 的 `Gradient(colors:)`
// 与 `AnimatedMeshGradient` 的 `MeshGradient` 要的是 `[Color]`，未填色的 `Shape`
// 塞不进去，那一族除本 token 外确实无路可走。结论（token 必要）不变，理由收窄。
// 而该守卫的扫描根**有意不含** `Sources/CoreDesign`，`CLAUDE.md`《分层色彩系统》也
// 明写「缺少需要的语义 token，应在对应文件中补充新名称」——`Color.specularHighlight`
//（`FillColors.swift`，同样是 `Color.white` 派生）是现成先例。
// `MaskReveal.swift` 的文件头已经把这条路径论证完并留了空位，本 token 就是那个空位。
//
// ⚠️ **α = 1 这条契约必须有判据守着**，否则本 token 会重蹈 `.primary` 的覆辙
//（那处也是"注释宣称不透明"、没有任何判据核对）。落点：
// `Tests/CoreDesignTests/MaskOpaqueTokenTests.swift` 在明暗两端各解析一次。
public extension Color {
    /// 纯 alpha 遮罩的**不透明**基色（`α = 1`）。
    ///
    /// 用在「拿一个色填出形状 / 渐变，再 `.mask { … }` 上去」这一族写法里，
    /// 例如 `AnimatedMeshGradient` 的 alpha 网格与 `ProcessingSweep` 的扫光渐变。
    ///
    /// ⚠️ **它承诺的只有 α = 1**。RGB 取白是任意的——`.mask` 不读 RGB（见文件头实测），
    /// 所以**不要**把它当"白色"用在任何会真的画出来的地方（那种需求走
    /// `contentInverse` / `specularHighlight` 这些有对比度论证的 token）。
    ///
    /// ⚠️ **不要换成 `.primary` / `.contentPrimary` / 任何系统语义色**：它们映射到
    /// `label`，macOS 实测 α = 0.8471，会让"完全揭示"只揭示到 85%（Issue #276）。
    /// ⚠️ iOS 上 `label` 实测 α = 1.0 ⇒ 换成它在 iOS 腿上**看不出问题**，
    /// 这正是这枚缺陷当初能溜过去的原因，不是"其实没关系"。
    static var maskOpaque: Color {
        .white
    }
}
