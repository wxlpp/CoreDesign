import SwiftUI

// MARK: - BadgeVariant

/// Badge 的语义等级，决定背景 / 边框配色映射。
public nonisolated enum BadgeVariant: Sendable, Equatable {
    case info
    case success
    case warning
    case danger
    case neutral
}

// MARK: - Badge

/// **材质层**: 控件. **表面角色**: 控件.
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
    static func backgroundColor(for variant: BadgeVariant) -> Color {
        switch variant {
        case .info: .statusAccentSubtle
        case .success: .statusSuccessSubtle
        case .warning: .statusAttentionSubtle
        case .danger: .statusDangerSubtle
        case .neutral: .secondaryFill
        }
    }

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
