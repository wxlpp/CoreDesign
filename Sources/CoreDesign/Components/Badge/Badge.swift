//
//  Badge.swift
//  CoreDesign
//
import SwiftUI

// MARK: - BadgeVariant

/// Badge 的语义等级，决定背景 / 边框配色映射。
///
/// 五个语义档位：`info` / `success` / `warning` /
/// `danger` / `neutral`，5 个**固定 level**，颜色由 token 决定（见
/// `Sources/CoreDesign/Colors/StatusColors.swift` 与 `SurfaceColors.swift`），
/// 随系统 colorScheme 自动适配 light / dark。
///
/// - `info`：中性提示（蓝）。例：版本可用、Beta、新特性标记。
/// - `success`：成功（绿）。例："已合并"、"已通过"。
/// - `warning`：警告（橙）。例："草稿"、"即将过期"。
/// - `danger`：错误 / 风险（红）。例："已废弃"、"已关闭未合并"。
/// - `neutral`：默认中性（灰）。例：版本号、计数、未指定状态。
public nonisolated enum BadgeVariant: Sendable, Equatable {
    case info
    case success
    case warning
    case danger
    case neutral
}

// MARK: - Badge

/// Control-layer status indicator with 5 fixed semantic levels. Compact, low
/// chrome, no glass — color is the semantic carrier, not decoration. Pairs
/// with row, header, and inline-label contexts.
///
/// **Material layer**: control. **Surface role**: control.
///
/// 状态指示器。
///
/// 用于在列表项 / 标题 / 按钮旁标注一个固定 level 的语义状态（如 "Beta" / "Draft" /
/// "Deprecated" / "v1.0"）。形态固定为 pill：`Capsule(style: .continuous)` 圆角
/// （`Capsule()`）+ status background token + 可选 `CoreBorderWidth.thin`
/// 描边，内部为调用方传入的 label。
///
/// ## 与 Tag 的边界
///
/// **Badge = 状态指示器**：5 固定 `BadgeVariant` level（info / success / warning /
/// danger / neutral），颜色由 token 决定，调用方**不**传 color。任意分类（如 GitHub
/// issue labels 那样调用方自定义颜色）请用 `Tag`。
///
/// ## 视觉与 token
///
/// - 背景：`Color.secondaryFill`（neutral）/ status background token
///   （`statusAccentSubtle` / `statusSuccessSubtle` / `statusAttentionSubtle` / `statusDangerSubtle`）
/// - 边框（`outlined: true` 时）：`Color.borderMuted`（neutral）/ 对应 status border
///   token；宽度 `CoreBorderWidth.thin`
/// - 圆角：`Capsule()`（pill 形态）
/// - 字号：`.coreFont(.footnote)`（直接取系统文本样式，不手写 tracking 常量）
/// - padding：横向 `CoreSpacing.sm`，纵向 `CoreSpacing.xs`
///
/// light / dark 行为差异：所有颜色均走 semantic token，由 colorset 自动适配，无需调用方
/// 介入。
///
/// ```swift
/// Badge("Beta", variant: .info)
/// Badge("Draft", variant: .warning, outlined: true)
/// Badge(variant: .success) {
///     HStack(spacing: CoreSpacing.xxs) {
///         Image(systemName: "checkmark")
///             .accessibilityHidden(true)
///         Text("Merged")
///     }
/// }
/// ```
public struct Badge<Label: View>: View {
    /// 创建 Badge。
    ///
    /// - Parameters:
    ///   - variant: 语义等级，决定背景 / 边框配色（见 `BadgeVariant`），默认 `.neutral`。
    ///   - outlined: 是否带 `CoreBorderWidth.thin` 描边，默认 `false`（仅背景填充）。
    ///   - label: badge 主体内容，通常为 `Text`，亦可组合 SF Symbol。
    public init(
        variant: BadgeVariant = .neutral,
        outlined: Bool = false,
        @ViewBuilder label: () -> Label
    ) {
        self.variant = variant
        self.outlined = outlined
        self.label = label()
    }

    public var body: some View {
        let shape = Capsule(style: .continuous)
        return self.label
            .coreFont(.footnote)
            .padding(.horizontal, CoreSpacing.sm)
            .padding(.vertical, CoreSpacing.xs)
            .background {
                shape.fill(Self.backgroundColor(for: self.variant))
            }
            .overlay {
                if self.outlined {
                    shape.strokeBorder(Self.borderColor(for: self.variant), lineWidth: CoreBorderWidth.thin)
                }
            }
            .accessibilityElement(children: .combine)
            .clipShape(shape)
    }

    let variant: BadgeVariant
    let outlined: Bool
    let label: Label
}

// MARK: - Badge convenience init

public extension Badge where Label == Text {
    /// 文本 Badge 的便利构造器。
    ///
    /// - Parameters:
    ///   - text: 显示文本，自动包裹为 `Text`。
    ///   - variant: 语义等级，默认 `.neutral`。
    ///   - outlined: 是否带描边，默认 `false`。
    init(_ text: String, variant: BadgeVariant = .neutral, outlined: Bool = false) {
        self.init(variant: variant, outlined: outlined) {
            Text(text)
        }
    }
}

// MARK: - Badge color helpers (file-private)

private extension Badge {
    /// 由 `BadgeVariant` 映射到背景色 token。
    ///
    /// `neutral` 走 `secondaryFill`，其余 4 级走对应的 status background token；
    /// 新增 variant 时同步扩展此映射。
    ///
    /// > **neutral 用 `secondaryFill` 而不是某个 `SurfaceColors` token**：`surfaceCanvasSubtle`
    /// > 在浅色模式下与 `surfaceBase`（`systemBackground`）同为 `#FFFFFF`——iOS 模拟器
    /// > 实测确认，无描边的 neutral badge 放在普通页面背景上会完全不可见；换
    /// > `surfaceCanvas` 则会在深色模式与 `surfaceBase` 同为纯黑，同样的问题换个模式重现。
    /// >
    /// > 根因是选错了 token **种类**：badge 背景是叠在别人之上的一小块色，该用**填充色**
    /// > （`FillColors`，半透明、专为叠加设计），而不是**背景色**（`SurfaceColors`，专为
    /// > 充当底层而设计）。任何单一 surface token 都修不好这个问题——问题出在种类选错，
    /// > 不是某个具体 token 的取值。
    /// >
    /// > `secondaryFill` 浅色 α=0.16 / 深色 α=0.32，实测在 `surfaceBase` / `surfaceCanvas`
    /// > / `surfaceRaised` 三种父容器、两种外观下均可辨。
    static func backgroundColor(for variant: BadgeVariant) -> Color {
        switch variant {
        case .info: .statusAccentSubtle
        case .success: .statusSuccessSubtle
        case .warning: .statusAttentionSubtle
        case .danger: .statusDangerSubtle
        case .neutral: .secondaryFill
        }
    }

    /// 由 `BadgeVariant` 映射到描边色 token（仅 `outlined: true` 时使用）。
    ///
    /// `neutral` 走 `borderMuted`，其余 4 级走对应的 status border token，与背景同色系
    /// 拉开描边层次但不喧宾夺主。
    static func borderColor(for variant: BadgeVariant) -> Color {
        switch variant {
        case .info: .statusAccentBorder
        case .success: .statusSuccessBorder
        case .warning: .statusAttentionBorder
        case .danger: .statusDangerBorder
        case .neutral: .borderMuted
        }
    }
}

// MARK: - Preview

#Preview("Badge - light") {
    BadgePreviewMatrix()
        .padding(20)
        .preferredColorScheme(.light)
}

#Preview("Badge - dark") {
    BadgePreviewMatrix()
        .padding(20)
        .preferredColorScheme(.dark)
}

private struct BadgePreviewMatrix: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Filled").font(.headline)
            HStack(spacing: 8) {
                Badge("Info", variant: .info)
                Badge("Success", variant: .success)
                Badge("Warning", variant: .warning)
                Badge("Danger", variant: .danger)
                Badge("Neutral", variant: .neutral)
            }

            Text("Outlined").font(.headline)
            HStack(spacing: 8) {
                Badge("Info", variant: .info, outlined: true)
                Badge("Success", variant: .success, outlined: true)
                Badge("Warning", variant: .warning, outlined: true)
                Badge("Danger", variant: .danger, outlined: true)
                Badge("Neutral", variant: .neutral, outlined: true)
            }

            Text("With icon").font(.headline)
            HStack(spacing: 8) {
                Badge(variant: .success) {
                    HStack(spacing: 2) {
                        Image(systemName: "checkmark")
                            .accessibilityHidden(true)
                        Text("Merged")
                    }
                }
                Badge(variant: .danger, outlined: true) {
                    HStack(spacing: 2) {
                        Image(systemName: "xmark")
                            .accessibilityHidden(true)
                        Text("Closed")
                    }
                }
            }
        }
    }
}
