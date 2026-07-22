//
//  Tag.swift
//  CoreDesign
//

import SwiftUI

// MARK: - Tag

/// Native Primer category tag.
///
/// Control-layer category label. Color is supplied by the caller (issue
/// labels, repo-defined palettes); the chip stays compact and low chrome.
/// No default glass, no decorative material — semantics come from the
/// caller's color choice.
///
/// **Material layer**: control. **Surface role**: control.
///
/// 任意分类标签 / Tag：GitHub issue label 风格的 chip，颜色由调用方传入。
///
/// 使用场景：issue / PR 分类（`bug` / `enhancement` / `documentation` 等）、文章标签、
/// 任意需要"调用方决定调色板"的归类视觉。Primer 概念上对应 `Label`（标签 / chip），
/// 不对应 `Label`-as-icon-text 排版组件。
///
/// ## Tag ↔ Badge 边界（重要）
///
/// 本组件**只**用于"任意分类标签，颜色由调用方传"的场景；不要用 Tag 表达固定状态等级。
///
/// - **Tag**：任意分类标签，颜色由调用方传，对应 GitHub issue labels（`bug` / `wontfix`
///   等用户/仓库自定义颜色）。**没有** `TagVariant` 枚举——颜色入参 `Color` 即调色板。
/// - **Badge**：5 固定状态等级（info / success / warning / danger / neutral）的状态指示器，
///   颜色由 token 决定，调用方**不**传颜色。
///
/// 若需要的是"5 个固定状态 level"语义，请改用 `Badge`（task #30）；若需要"用户自定义/
/// 仓库自定义调色板"，本组件正合适。
///
/// ## 视觉规格
///
/// - **背景**：调用方 `color` 的 `0.12` opacity 衬底（参考 GitHub issue label 视觉——
///   低饱和度衬底 + 高对比文字）。`0.12` 是 chip 类组件常用的"可识别但不抢戏"基线
///   不饱和值，light/dark 下都能维持足够文字对比。
/// - **前景（文字 + 关闭图标）**：直接使用调用方 `color`——SwiftUI `Color` 在大多数
///   场景下随 colorScheme 自动渲染（譬如 `.blue` / `.purple` 在 dark mode 下亮度提升），
///   从而维持与衬底的对比关系。调用方若传系统 dynamic color（`Color.accentColor` 等）
///   亦自动适配。
/// - **圆角**：`CoreRadius.small`（Issue #119 起 6pt，此前 3pt）。**不**使用 `.full`——
///   这是与 Badge 的视觉区分点之一（Badge 走 `Capsule()` pill 形态）。Task #122 复核：
///   chip 实际渲染高度（footnote 行高 + 上下 `CoreSpacing.xs` padding）约 24–26pt，
///   6pt 圆角占比约 23–25%，仍明显是"圆角矩形"而非胶囊，与 Badge 的区分度保留。
/// - **字号**：`.coreFont(.footnote)`。
/// - **padding**：水平 `CoreSpacing.sm`（8pt）+ 垂直 `CoreSpacing.xs`（4pt），紧凑 chip 形态。
/// - **关闭按钮**：`removable: true` 时右侧追加 `xmark.circle.fill` 系统图标 button，
///   尺寸走 `CoreControlMetrics.iconSize(for: .small)`（14pt），点击调用 `onRemove`。
///   关闭行为通过子 button 实现，**不**侵入 label 视图本身——保持单一职责。
/// - **light / dark 行为**：背景与前景均派生自调用方 `color`，因此 light / dark 视觉差
///   完全由调用方传入的 `Color` 自身的 dynamic 行为决定。SwiftUI 系统色（`.blue` /
///   `.red` 等）会自动在 dark mode 下提升亮度；asset catalog 的 dynamic color 同理。
///
/// ## 使用示例
///
/// ```swift
/// // 简单文字标签
/// Tag("bug", color: .red)
///
/// // 可关闭的自定义 label
/// Tag(color: .purple, removable: true, onRemove: { /* ... */ }) {
///     Label("good first issue", systemImage: "star.fill")
/// }
/// ```
/// > Important: `removable: true` 时，移除按钮的**命中区向 chip 视觉边界之外溢出**
/// > （纵向约 8pt、横向约 4pt）——为满足 HIG 44pt 触控下限而有意为之，**布局尺寸不受影响**
/// > （removable 与非 removable 的 chip 高度相同，实测均为 24pt）。
/// >
/// > 因此**相邻可交互元素之间应留出 ≥8pt 间距**，否则命中区会互相重叠、形成看不见的
/// > 点击陷阱。组件自身 `#Preview` 用的 `CoreSpacing.md`(12pt) 行距是安全的。
///
public struct Tag<Label: View>: View {

    // MARK: - Init

    /// 创建一个任意 label 视图的 Tag。
    ///
    /// - Parameters:
    ///   - color: 调色板。同时驱动衬底（`color.opacity(0.12)`）与前景文字 / 关闭图标（直接用 `color`）。
    ///   - removable: 是否在右侧渲染 `xmark.circle.fill` 关闭按钮。默认 `false`。
    ///   - onRemove: `removable == true` 且按钮被点击时回调。`removable == false` 时被忽略。
    ///     `onRemove == nil` 时按钮仍可见但 `.disabled(true)`，提醒调用方提供回调。
    ///   - label: 标签主体，常为 `Text` 或 `Label`。
    public init(
        color: Color,
        removable: Bool = false,
        onRemove: (() -> Void)? = nil,
        @ViewBuilder label: () -> Label
    ) {
        self.color = color
        self.removable = removable
        self.onRemove = onRemove
        self.label = label()
    }

    public var body: some View {
        HStack(spacing: CoreSpacing.xs) {
            self.label
                .coreFont(.footnote)
                .foregroundStyle(self.color)

            if self.removable {
                Button {
                    self.onRemove?()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: Self.removeIconSize))
                        .foregroundStyle(self.color)
                }
                .buttonStyle(.plain)
                .disabled(self.onRemove == nil)
                // Issue #123：原先只有 `.padding(CoreSpacing.xxs)` + `contentShape`，
                // 命中区域 = 14pt 图标 + 2×2pt = 约 18×18pt，仅为 HIG 44pt 下限的 41%。
                //
                // **修法必须不影响布局**——这是与 CheckBox / UnderlinedTabItem 的关键区别。
                // 那两者的 `.frame(minHeight:)` 加在组件**唯一的整条 body** 外层，整个可点
                // 单元一起变高是可接受的取舍。而移除按钮只是 chip 内的一个**子视图**：
                // HStack 高度取子视图最大值，直接给它加 44pt frame 会把整条 chip（连同旁边
                // 完全没变的 label）一起撑起来——实测 24pt → 52pt，2.1 倍，且同一行里的
                // 非 removable tag 仍是 21pt，高度严重错配。
                //
                // 故用「对称 padding 撑开命中区、再用负 padding 抵消布局影响」的标准写法。
                // 尺寸实测（iOS Simulator，`ImageRenderer`）：
                //
                //     图标裸尺寸（`.font(.system(size: 14))` 的字形盒）  16×16
                //     + `CoreSpacing.xxs`（2pt，视觉内边距，参与布局）    20×20
                //     + `CoreSpacing.md`（12pt，命中区扩展）             44×44  ← HIG 下限
                //
                // 注意 **图标字号 14pt 渲染出来是 16pt 的盒**，不是 14——早先版本按 14 推算
                // 得出 `13pt slop`，实际只有 40–42pt，够不到下限。数值一律以实测为准。
                //
                // > **调用方需知**：命中区比 chip 的视觉边界向外溢出——纵向约
                // > `12 − CoreSpacing.xs(4) = 8pt`、横向约 `12 − CoreSpacing.sm(8) = 4pt`。
                // > 对小尺寸关闭按钮这是 Apple 自己也在用的常规做法，但**相邻可交互元素
                // > 之间应留出 ≥8pt 间距**，否则命中区会互相重叠形成看不见的点击陷阱。
                //
                // > 代价：`ImageRenderer` 量的是布局 frame，量不到这个 44pt 命中区，
                // > 因此无法用 `TouchTargetTests` 的方式加断言。见该文件头「例外（四）」。
                .padding(CoreSpacing.xxs)
                .padding(CoreSpacing.md)
                .contentShape(Rectangle())
                .padding(-CoreSpacing.md)
                .accessibilityLabel(Text("Remove tag", bundle: .module))
            }
        }
        .padding(.horizontal, CoreSpacing.sm)
        .padding(.vertical, CoreSpacing.xs)
        .background(
            CoreShape.rounded(CoreRadius.small)
                .fill(self.color.opacity(Self.backgroundOpacity))
        )
    }

    // MARK: - Tokens

    /// 衬底不透明度。GitHub label 视觉常用的 ~12% 基线不饱和值——可识别但不抢戏，
    /// 在 light / dark 两端都能维持足够的文字对比。集中常量避免在 body 内出现魔法数字。
    // 泛型类型不支持 static stored property；computed var 是唯一的常量表达方式。
    private static var backgroundOpacity: Double { 0.12 }

    /// 关闭按钮 icon 边长。走 `CoreControlMetrics.iconSize(for: .small)` = 14pt，
    /// 与 `.coreFont(.footnote)` 视觉等重——SF Symbol 视觉重心略低于 cap height，
    /// 稍大边长才能感觉与字母 x-height 等高。集中常量避免散落字面量。
    private static var removeIconSize: CGFloat { CoreControlMetrics.iconSize(for: .small) }

    private let color: Color
    private let removable: Bool
    private let onRemove: (() -> Void)?
    private let label: Label
}

// MARK: - String convenience init

public extension Tag where Label == Text {
    /// 文本标签便利构造。
    ///
    /// 等价于 `Tag(color:removable:onRemove:) { Text(text) }`，省略 ViewBuilder 噪音。
    /// 适合最常见的"GitHub label 文本 + 颜色"用法。
    ///
    /// - Parameters:
    ///   - text: 标签文字。
    ///   - color: 调色板，行为同 designated init。
    ///   - removable: 是否渲染关闭按钮，默认 `false`。
    ///   - onRemove: 关闭按钮回调。
    init(
        _ text: String,
        color: Color,
        removable: Bool = false,
        onRemove: (() -> Void)? = nil
    ) {
        self.init(color: color, removable: removable, onRemove: onRemove) {
            Text(text)
        }
    }
}

// MARK: - Preview

#Preview("Tag · light") {
    VStack(alignment: .leading, spacing: CoreSpacing.md) {
        // 静态分类（GitHub bug-red / enhancement-blue / good-first-issue-purple / documentation-cyan）
        HStack(spacing: CoreSpacing.sm) {
            Tag("bug", color: .red)
            Tag("enhancement", color: .blue)
            Tag("good first issue", color: .purple)
            Tag("documentation", color: .cyan)
        }

        // 可关闭分支（不同颜色证明 any-palette）
        HStack(spacing: CoreSpacing.sm) {
            Tag("blue", color: .blue, removable: true, onRemove: {})
            Tag("purple", color: .purple, removable: true, onRemove: {})
            Tag("orange", color: .orange, removable: true, onRemove: {})
        }

        // 自定义 label（带 SF Symbol）
        Tag(color: .green, removable: true, onRemove: {}) {
            SwiftUI.Label("verified", systemImage: "checkmark.seal.fill")
        }
    }
    .padding(CoreSpacing.lg)
    .preferredColorScheme(.light)
}

#Preview("Tag · dark") {
    VStack(alignment: .leading, spacing: CoreSpacing.md) {
        HStack(spacing: CoreSpacing.sm) {
            Tag("bug", color: .red)
            Tag("enhancement", color: .blue)
            Tag("good first issue", color: .purple)
            Tag("documentation", color: .cyan)
        }

        HStack(spacing: CoreSpacing.sm) {
            Tag("blue", color: .blue, removable: true, onRemove: {})
            Tag("purple", color: .purple, removable: true, onRemove: {})
            Tag("orange", color: .orange, removable: true, onRemove: {})
        }

        Tag(color: .green, removable: true, onRemove: {}) {
            SwiftUI.Label("verified", systemImage: "checkmark.seal.fill")
        }
    }
    .padding(CoreSpacing.lg)
    .preferredColorScheme(.dark)
}
