//
//  StatusRow.swift
//  CoreDesign
//

import SwiftUI

// MARK: - StatusResult

/// CI 检查结果状态。
public enum StatusResult: Sendable, Equatable {
    case success
    case failure
    case pending
    case skipped
}

// MARK: - StatusRow

/// CI 检查状态行。图标 + 名称 + 耗时 + 结果指示器。
///
/// 用于平铺的检查列表（VStack），不是时间线组件。
public struct StatusRow: View {
    public let label: String
    public let duration: String
    public let result: StatusResult

    public init(label: String, duration: String, result: StatusResult) {
        self.label = label
        self.duration = duration
        self.result = result
    }

    public var body: some View {
        HStack(spacing: CoreSpacing.sm) {
            Image(systemName: self.resultIcon)
                .foregroundStyle(self.resultColor)
                .font(.caption)

            Text(self.label)
                .font(CoreTypography.bodySmallFont)
                .lineLimit(1)

            Spacer()

            Text(self.duration)
                .font(CoreTypography.bodySmallFont)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
        .padding(.horizontal, CoreSpacing.md)
        .padding(.vertical, CoreSpacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(self.resultLabel): \(self.label), \(self.duration)")
        .accessibilityValue(self.resultLabel)
    }

    private var resultIcon: String {
        switch self.result {
        case .success: return "checkmark.circle.fill"
        case .failure: return "xmark.circle.fill"
        case .pending: return "clock"
        case .skipped: return "minus.circle"
        }
    }

    private var resultColor: Color {
        switch self.result {
        case .success: return .statusSuccessForeground
        case .failure: return .statusDangerForeground
        case .pending: return .statusAttentionForeground
        case .skipped: return .secondary
        }
    }

    private var resultLabel: String {
        switch self.result {
        case .success: return "Passed"
        case .failure: return "Failed"
        case .pending: return "Pending"
        case .skipped: return "Skipped"
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
    .background(Color.systemBackground)
}
