import SwiftUI

// MARK: - Interaction Colors / 交互颜色
//
// `accent` 指向 `Color.accentColor`——库跟随调用方 App 在 Asset Catalog 里设置的
// AccentColor，而不是自带一套固定品牌蓝。衍生态（hover/pressed/disabled/
// subtleBackground）不能再各取固定色阶（宿主可以把 AccentColor 设成任意色相，
// 一个固定色阶不再是"它更亮一档的样子"），改为用 `Color.mix(with:by:in:)`
// （iOS 18+ / macOS 15+，本库最低部署目标 iOS 26 / macOS 26 明显覆盖）与
// `.opacity()` 对 `accent` 本身做明度 / 不透明度调制。
//
// 不承诺跟随每视图 `.tint(_:)`：`.tint` 走的是独立于 `Color.accentColor` 的
// `ShapeStyle` 通道；要让这里的静态 `Color` token 跟随它，需要把组件配色整体改成
// `ShapeStyle` 通路，属 API 形态变更，暂不在本库范围内。
public extension Color {
    /// 交互强调色，跟随宿主 App 的 AccentColor 资源。
    static let accent = Color.accentColor

    /// Hover 态：**离背景更远一档**，用于 macOS 指针悬停 / iPadOS 指针高亮等
    /// "按下前的强调"场景。
    ///
    /// > Important: 混合基色取 `.primary`（浅色模式≈黑、深色模式≈白）而非固定的黑或白。
    /// > 旧的 brand 色阶是**外观自适应反转**的——实测 `brand6` 浅色 `#0062D6`（比
    /// > `brand5 #0077FA` 深）、深色 `#65B2FC`（比 `brand5 #3295FB` 浅）。也就是说
    /// > 旧行为是"朝远离背景的方向走一档"，而不是恒定变亮或恒定变暗。用固定的白/黑
    /// > 混合会在其中一个模式下把 accent 推向背景色、收窄对比度。`.primary` 一个基色
    /// > 即可复现这一双向行为。
    static let accentHover = Color.accent.mix(with: .primary, by: 0.15)

    /// 按下态：比 hover **更远离背景一档**。混合基色同 `accentHover` 取 `.primary`
    /// 以复现"离背景更远一档"的双向行为——加深只在浅色模式成立，深色模式下同样的
    /// 固定色阶反而是提亮的；恒定压暗会在深色模式把 accent 推向纯黑画布
    /// （`systemGroupedBackground` dark = `#000000`），方向相反。不用降 alpha 的原因是
    /// 降 alpha 只会露出更多背景、削弱存在感，两个模式下都不对。
    ///
    /// > 已知副作用：macOS 的 `.primary`（`NSColor.labelColor`）自带 α≈0.85，混合后
    /// > `accentHover` α≈0.976、`accentPressed` α≈0.961。iOS 的 `UIColor.label` 全不透明，
    /// > 不受影响。这 2–4% 的 alpha 下滑视觉不可辨，但严格说它确实不是"完全不降 alpha"。
    static let accentPressed = Color.accent.mix(with: .primary, by: 0.25)

    /// 禁用态：对 accent 本身降低不透明度——与 Apple 系统控件的禁用惯例一致（保持
    /// 色相、只降低存在感/对比度，而不是像 pressed 那样改变明度方向）。
    static let accentDisabled = Color.accent.opacity(0.35)

    /// accent 的极淡背景色，用于选中态背景等大面积、低对比场景。对 accent 本身
    /// 降低不透明度——不透明度会让底层背景透出来，在浅色与深色画布上都能读出
    /// "淡淡的强调色调"；若改用与 `accentHover` 一致的白混合调制，在深色背景上会
    /// 变成一块突兀的发亮浅色色块，不再是"淡淡的背景"。
    static let accentSubtleBackground = Color.accent.opacity(0.12)

    // MARK: - secondaryAccent（显式定案：保留品牌色阶）
    //
    // **显式定案：保留**，不随 accent 动态化。Apple HIG 没有"第二强调色"的系统概念
    // ——只有单一的 `AccentColor`，没有可改指的系统对应物。`secondaryAccent` 服务于
    // `ButtonRoleStyleRole.secondary`（"次要按钮"角色），是 CoreDesign 自有的一套
    // 品牌色阶，语义上独立于宿主 App 的 AccentColor：即使宿主把 AccentColor 换成
    // 任意颜色，"次要按钮"仍应保持库自身统一的视觉身份，而不是跟着宿主强调色变化
    // ——这与 `accent` 本身"就该跟随宿主"的诉求是两回事。`light-blue-5` 等 colorset
    // 已经带 light/dark 双值，明暗自适应链路与系统色等价，只是取值来自 CoreDesign
    // 自己的调色板而非 `UIColor`/`NSColor` 系统族。
    static let secondaryAccent = Color.lightBlue5
    static let secondaryAccentHover = Color.lightBlue6
    static let secondaryAccentPressed = Color.lightBlue7
    static let secondaryAccentDisabled = Color.lightBlue2

    // MARK: - neutralAccent（显式定案：保留品牌色阶）
    //
    // **显式定案：保留** `grey5` 一系，不改指真正的系统灰（如
    // `Color(uiColor: .systemGray)` / `NSColor.systemGray`）。`grey-5` 等 colorset
    // 已经带 light/dark 双值，本身就"跟随系统外观"；换成 `systemGray` 只是换一套
    // 灰阶数值，不会带来行为上"更系统"的差异，反而会让 `ButtonRoleStyleRole.tertiary`
    // 的四档灰阶（5/6/7/2）与库内其它可能直接引用 `Color.grey5` 的地方产生两套灰、
    // 对不上号。保留同一套 `ColorGrade` 灰阶，是"内部一致性优先"的选择，而非
    // 遗漏判断。
    static let neutralAccent = Color.grey5
    static let neutralAccentHover = Color.grey6
    static let neutralAccentPressed = Color.grey7
    static let neutralAccentDisabled = Color.grey2

    /// 常规选中态背景：低调的强调色淡染。
    static var selectionBackground: Color {
        .accentSubtleBackground
    }

    /// 强调选中态背景：实心 `accent`，与 `contentOnAccent`（白字前景）配对使用，
    /// 用于选中行 / 激活开关等需要强对比的场景。**不**借道 `accentDisabled`——
    /// 后者是"降低不透明度的褪色"语义（禁用态），借道会把"强调选中"渲染成
    /// "看起来像禁用"的淡色块，语义倒挂。
    static var selectionBackgroundEmphasis: Color {
        .accent
    }

    /// 中性 hover 底色。委托给 `FillColors`，那一层已由系统色支撑，本层无需改指。
    /// 这一族与 accent 族无关，不参与强调色的动态推导。
    static var hoverBackground: Color {
        .secondaryFill
    }

    /// 中性按下底色。委托给 `FillColors`，那一层已由系统色支撑，本层无需改指。
    /// 这一族与 accent 族无关，不参与强调色的动态推导。
    static var pressedBackground: Color {
        .tertiaryFill
    }

    /// 禁用态底色。委托给 `FillColors`，那一层已由系统色支撑，本层无需改指。
    /// 这一族与 accent 族无关，不参与强调色的动态推导。
    static var disabledBackground: Color {
        .quaternaryFill
    }

    /// 禁用态前景色。委托给 `ContentColors`，那一层已由系统色支撑，本层无需改指。
    /// 这一族与 accent 族无关，不参与强调色的动态推导。
    static var disabledForeground: Color {
        .contentDisabled
    }
}
