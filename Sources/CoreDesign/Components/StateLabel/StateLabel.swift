//
//  StateLabel.swift
//  CoreDesign
//

import SwiftUI

// MARK: - StateLabelStyle

/// 通用状态标签的语义样式。
///
/// 颜色映射通过 `StatusColors` 系统的 emphasis 背景 + `contentOnEmphasis` 前景实现，
/// 图标 / 背景 / 默认文案统一由下方 `spec` 单次穷举给出。
public nonisolated enum StateLabelStyle: Sendable, Equatable {
    case active      // success (green) — in progress
    case draft       // attention (yellow) — not ready / WIP
    case completed   // done (purple) — finished
    case cancelled   // danger (red) — cancelled
    case inProgress  // attention (yellow) — transient / in-flight (e.g. saving)
    case error       // danger (red) — recoverable failure (e.g. save failed)
}

extension StateLabelStyle {
    /// 单个样式的图标 / 背景 / 默认文案三元组。
    ///
    /// 收敛前 `StateLabel` 有三个平行 switch（iconName / backgroundColor / defaultLabel）；
    /// 现由 `spec` 一次穷举返回。新增 case 时编译器只在此处要求穷举。
    struct Spec {
        let icon: String
        let background: Color
        let defaultLabel: String
    }

    /// `@MainActor`：`background` 读 `status*Emphasis` token Color，在
    /// `defaultIsolation(MainActor.self)` 下这些 token 是 MainActor 隔离的。
    /// 消费点（`StateLabel.body` 与便利 init）都在 MainActor，故不受限。
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
///
/// 通用状态标识 pill。大圆角 + 彩色背景 + SF Symbol 图标 + label 内容。
/// 双层 init 形态对齐 `Badge` / `Tag`：`@ViewBuilder` designated init 可插图标 /
/// 富文本，`where Label == Text` 便利 init 收 `String`。
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
                // `.combine` 会把未隐藏子元素的可访问名折进来，须显式隐藏 icon，
                // 否则 SF Symbol 名会泄漏进 VoiceOver name（与 `Banner` 对 icon
                // 的处理一致）。
                .accessibilityHidden(true)
            self.label
                .coreFont(.footnote)
        }
        // 前景统一走 `contentOnEmphasis`（白）——背景用 `status*Emphasis`（饱和填充），
        // 配对前景即 `onEmphasis`。若按 style 返回 `status*Foreground`，在 emphasis
        // 为饱和实色的前提下会与背景同色（对比度 1.00、文字不可见）。
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
