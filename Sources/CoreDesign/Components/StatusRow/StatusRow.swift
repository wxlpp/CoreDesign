//
//  StatusRow.swift
//  CoreDesign
//

import SwiftUI

// MARK: - StatusResult

/// CI 检查结果状态。
public nonisolated enum StatusResult: Sendable, Equatable {
    case success
    case failure
    case pending
    case skipped
}

extension StatusResult {
    /// 单个结果的图标 / 前景色 / 可读标签三元组（审计项 B8f）。
    ///
    /// 收敛前 `StatusRow` 有三个平行 switch（resultIcon / resultColor / resultLabel）；
    /// 现由 `spec` 一次穷举返回。
    struct Spec {
        let icon: String
        let color: Color
        let label: String
    }

    /// `@MainActor`：`color` 读 status token Color（MainActor 隔离）。
    @MainActor
    var spec: Spec {
        switch self {
        case .success:
            Spec(icon: "checkmark.circle.fill", color: .statusSuccessForeground, label: "Passed")
        case .failure:
            Spec(icon: "xmark.circle.fill", color: .statusDangerForeground, label: "Failed")
        case .pending:
            Spec(icon: "clock", color: .statusAttentionForeground, label: "Pending")
        case .skipped:
            // #93：原写 `.secondary` 会解析到已删的第 4 层同名别名（`lightBlue5` /
            // Blossom `violet5`）而非中性次要色，skipped 图标渲染成浅蓝/紫罗兰。
            // 用语义层 `.contentSecondary` 明确表达「中性次要色」。
            Spec(icon: "minus.circle", color: .contentSecondary, label: "Skipped")
        }
    }
}

// MARK: - StatusRow

/// Native Primer status row.
///
/// Content-layer row. CI status entry (icon + label + duration + result).
/// Color carries semantics; chrome stays minimal. No glass, no cardification.
///
/// **Material layer**: content. **Surface role**: content.
///
/// CI 检查状态行。图标 + label 内容 + 耗时 + 结果指示器。双层 init 形态对齐
/// `Badge` / `Tag`：`@ViewBuilder` designated init 可插图标 / 富文本，
/// `where Label == Text` 便利 init 收 `String`（审计项 D6b）。
public struct StatusRow<Label: View>: View {
    let label: Label
    let duration: String
    let result: StatusResult

    /// 以任意 label 视图构造。
    public init(duration: String, result: StatusResult, @ViewBuilder label: () -> Label) {
        self.duration = duration
        self.result = result
        self.label = label()
    }

    public var body: some View {
        HStack(spacing: CoreSpacing.sm) {
            Image(systemName: self.result.spec.icon)
                .foregroundStyle(self.result.spec.color)
                .coreFont(.caption)
                // 评审 Suggestion 4：泛型化后改 `.combine`，显式隐藏 icon 防 SF Symbol 名
                // 泄漏进 VoiceOver name（对齐 Banner.swift:215）。
                .accessibilityHidden(true)

            self.label
                .coreFont(.bodySmall)
                .lineLimit(1)

            Spacer()

            Text(self.duration)
                .coreFont(.bodySmall)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
                // duration 已由 accessibilityValue 承载，隐藏避免 combine 重复朗读。
                .accessibilityHidden(true)
        }
        .padding(.horizontal, CoreSpacing.md)
        .padding(.vertical, CoreSpacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(self.result.spec.label), \(self.duration)")
    }
}

// MARK: - StatusRow convenience init

public extension StatusRow where Label == Text {
    /// 文本 StatusRow 便利构造（保留原签名，既有调用点不变）。
    init(label: String, duration: String, result: StatusResult) {
        self.init(duration: duration, result: result) {
            Text(label)
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        StatusRow(label: "build (arm64)", duration: "2m 14s", result: .success)
        Divider()
        StatusRow(label: "test (macOS)", duration: "3m 01s", result: .success)
        Divider()
        StatusRow(label: "lint", duration: "0m 12s", result: .failure)
        Divider()
        StatusRow(label: "deploy (preview)", duration: "—", result: .pending)
        Divider()
        StatusRow(label: "analyze", duration: "—", result: .skipped)
    }
    .padding()
    .background(Color.surfaceCanvas)
}
