import SwiftUI

// MARK: - StateLabelStyle

/// 通用状态标签的语义样式。
public nonisolated enum StateLabelStyle: Sendable, Equatable {
    case active
    case draft
    case completed
    case cancelled
    case inProgress
    case error
}

extension StateLabelStyle {
    struct Spec {
        let icon: String
        let background: Color
        let defaultLabel: String
    }

    @MainActor
    var spec: Spec {
        switch self {
        case .active:
            Spec(icon: "circle.fill", background: .statusSuccessEmphasis, defaultLabel: "Active")
        case .draft:
            Spec(icon: "circle.dashed", background: .statusAttentionEmphasis, defaultLabel: "Draft")
        case .completed:
            Spec(icon: "checkmark.circle.fill", background: .statusDoneEmphasis, defaultLabel: "Completed")
        case .cancelled:
            Spec(icon: "xmark.circle.fill", background: .statusDangerEmphasis, defaultLabel: "Cancelled")
        case .inProgress:
            Spec(icon: "arrow.triangle.2.circlepath", background: .statusAttentionEmphasis, defaultLabel: "In Progress")
        case .error:
            Spec(icon: "exclamationmark.triangle.fill", background: .statusDangerEmphasis, defaultLabel: "Error")
        }
    }
}

// MARK: - StateLabel

/// **材质层**: 控件. **表面角色**: 控件.
public struct StateLabel<Label: View>: View {
    let style: StateLabelStyle
    let label: Label

    /// 以任意 label 视图构造。
    public init(style: StateLabelStyle, @ViewBuilder label: () -> Label) {
        self.style = style
        self.label = label()
    }

    public var body: some View {
        HStack(spacing: CoreSpacing.xs) {
            Image(systemName: self.style.spec.icon)
                .coreFont(.caption)
                .accessibilityHidden(true)
            self.label
                .coreFont(.footnote)
        }
        .foregroundStyle(Color.contentOnEmphasis)
        .padding(.horizontal, CoreSpacing.sm)
        .padding(.vertical, CoreSpacing.xxs)
        .background(
            Capsule(style: .continuous)
                .fill(self.style.spec.background)
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - StateLabel convenience init

public extension StateLabel where Label == Text {
    /// 文本 StateLabel 便利构造。`label == nil` 时用 style 的默认文案。
    init(style: StateLabelStyle, label: String? = nil) {
        self.init(style: style) {
            Text(label ?? style.spec.defaultLabel)
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        StateLabel(style: .active)
        StateLabel(style: .draft)
        StateLabel(style: .completed)
        StateLabel(style: .cancelled)
        StateLabel(style: .inProgress)
        StateLabel(style: .error)
        StateLabel(style: .inProgress, label: "Saving…")
        StateLabel(style: .error, label: "Save failed")
    }
    .padding()
}
