//
//  Tag.swift
//  CoreDesign
//

import SwiftUI

// MARK: - Tag

/// 任意分类标签 / Tag：GitHub issue label 风格的 chip / pill，颜色由调用方传入。
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
/// - **圆角**：`CoreRadius.small`（3pt）。**不**使用 `.full`——这是与 Badge 的视觉区分点
///   之一（Badge 走 `CoreRadius.full` pill 形态）。
/// - **字号**：`CoreTypography.bodySmallFont`（12pt regular）。
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
public struct Tag<Label: View>: View {

    // MARK: - Init

    /// 创建一个任意 label 视图的 Tag。
    ///
    /// - Parameters:
    ///   - color: 调色板。同时驱动衬底（`color.opacity(0.12)`）与前景文字 / 关闭图标（直接用 `color`）。
    ///   - removable: 是否在右侧渲染 `xmark.circle.fill` 关闭按钮。默认 `false`。
    ///   - onRemove: `removable == true` 且按钮被点击时回调。`removable == false` 时被忽略。
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
                .font(CoreTypography.bodySmallFont)
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
                .contentShape(Rectangle())
                .padding(CoreSpacing.xxs)
                .accessibilityLabel(Text("Remove tag"))
            }
        }
        .padding(.horizontal, CoreSpacing.sm)
        .padding(.vertical, CoreSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: CoreRadius.small)
                .fill(self.color.opacity(Self.backgroundOpacity))
        )
    }

    // MARK: - Tokens

    /// 衬底不透明度。GitHub label 视觉常用的 ~12% 基线不饱和值——可识别但不抢戏，
    /// 在 light / dark 两端都能维持足够的文字对比。集中常量避免在 body 内出现魔法数字。
    // 泛型类型不支持 static stored property；computed var 是唯一的常量表达方式。
    private static var backgroundOpacity: Double { 0.12 }

    /// 关闭按钮 icon 边长。走 `CoreControlMetrics.iconSize(for: .small)` = 14pt，
    /// 与 `bodySmallFont`（12pt）视觉等重——SF Symbol 视觉重心略低于 cap height，
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
