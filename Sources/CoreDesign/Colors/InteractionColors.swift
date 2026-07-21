import SwiftUI

// MARK: - Interaction Colors / 交互颜色（Issue #120 · ADR-3）
//
// `accent` 由固定品牌色阶 `brand5` 改为 `Color.accentColor`——库跟随调用方 App 在
// Asset Catalog 里设置的 AccentColor，而不是自带一套品牌蓝。衍生态
// （hover/pressed/disabled/subtleBackground）原本各取 `brand6`/`brand7`/`brand2`/
// `brand1` 固定色阶，在动态强调色下无从推导（宿主可以把 AccentColor 设成任意色相，
// "brand6" 不再是"它更亮一档的样子"）。改为用 `Color.mix(with:by:in:)`
// （iOS 18+ / macOS 15+，本库最低部署目标 iOS 26 / macOS 26 明显覆盖）与
// `.opacity()` 对 `accent` 本身做明度 / 不透明度调制。
//
// 不承诺跟随每视图 `.tint(_:)`：`.tint` 走的是独立于 `Color.accentColor` 的
// `ShapeStyle` 通道；要让这里的静态 `Color` token 跟随它，需要把组件配色整体改成
// `ShapeStyle` 通路，属 API 形态变更，不在本 epic（Issue #120 Technical Details /
// epic ADR-3）。
public extension Color {
    /// 交互强调色。**Issue #120 改值**：由 `brand5` 改为 `Color.accentColor`，
    /// 跟随宿主 App 的 AccentColor 资源。
    static let accent = Color.accentColor

    /// Hover 态：比基础 accent 更亮一档，用于 macOS 指针悬停 / iPadOS 指针高亮等
    /// "按下前的强调"场景。**Issue #120 改值**：原取固定色阶 `brand6`，现用 15%
    /// 白混合调制亮度——accent 现在可以是任意宿主色，没有"brand6"这种预先烘焙好
    /// 的下一档亮色可用，只能对 accent 自身做相对调制。
    static let accentHover = Color.accent.mix(with: .white, by: 0.15)

    /// 按下态：**必须比 accent 更深**（原值 `brand7` 就是加深的下一档）。**Issue #120
    /// 改值**：用黑混合调制明度，而不是降低不透明度——降 alpha 只会让颜色更透明、
    /// 露出更多背景色而"变浅"，方向与"按下应加深"相反。
    static let accentPressed = Color.accent.mix(with: .black, by: 0.25)

    /// 禁用态：**Issue #120 改值**。原取固定色阶 `brand2`（一个具体的浅色调），
    /// 现改为对 accent 本身降低不透明度——与 Apple 系统控件的禁用惯例一致（保持
    /// 色相、只降低存在感/对比度，而不是像 pressed 那样改变明度方向）。
    static let accentDisabled = Color.accent.opacity(0.35)

    /// accent 的极淡背景色，用于选中态背景等大面积、低对比场景。**Issue #120 改值**：
    /// 原取固定色阶 `brand1`，现改为对 accent 本身降低不透明度——不透明度会让底层
    /// 背景透出来，在浅色与深色画布上都能读出"淡淡的强调色调"；若改用与
    /// `accentHover` 一致的白混合调制，在深色背景上会变成一块突兀的发亮浅色色块，
    /// 不再是"淡淡的背景"。
    static let accentSubtleBackground = Color.accent.opacity(0.12)

    // MARK: - secondaryAccent（Issue #120 显式定案：保留品牌色阶）
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

    // MARK: - neutralAccent（Issue #120 显式定案：保留品牌色阶）
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

    /// 强调选中态背景。**Issue #120 改值**：原借道 `accentDisabled`（两者曾同为
    /// 固定色阶 `brand2`，纯属数值巧合）。`accentDisabled` 现改为"降低不透明度的
    /// 褪色"语义（禁用态），继续借道会把"强调选中"渲染成"看起来像禁用"的淡色块，
    /// 语义倒挂。改为实心 `accent`——对齐 Primer `accent.emphasis`
    /// （`StatusColors.statusAccentEmphasis` 文档注释描述的"selected row, active
    /// toggle"场景），与 `contentOnAccent`（白字前景）配对使用。
    static var selectionBackgroundEmphasis: Color {
        .accent
    }

    static var hoverBackground: Color {
        .secondaryFill
    }

    static var pressedBackground: Color {
        .tertiaryFill
    }

    static var disabledBackground: Color {
        .quaternaryFill
    }

    static var disabledForeground: Color {
        .contentDisabled
    }
}
