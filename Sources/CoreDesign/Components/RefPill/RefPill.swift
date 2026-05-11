//
//  RefPill.swift
//  CoreDesign
//

import SwiftUI

// MARK: - RefPill

/// 代码引用 pill。
///
/// 灰底 + 等宽字体 + 细边框，用于显示分支名、commit SHA、tag 等技术引用。
/// 支持单引用（`RefPill("main")`）和双引用箭头连接（`RefPill(base: "main", head: "feat/foo")`）。
public struct RefPill: View {
    let singleRef: String?
    let base: String?
    let head: String?

    public init(_ ref: String) {
        self.singleRef = ref
        self.base = nil
        self.head = nil
    }

    public init(base: String, head: String) {
        self.singleRef = nil
        self.base = base
        self.head = head
    }

    public var body: some View {
        HStack(spacing: CoreSpacing.xs) {
            Image(systemName: "arrow.triangle.branch")
                .font(.caption2)
            if let ref = self.singleRef {
                Text(ref)
                    .font(.caption.monospaced())
            } else if let base = self.base, let head = self.head {
                Text(base)
                    .font(.caption.monospaced())
                Image(systemName: "arrow.left")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(head)
                    .font(.caption.monospaced())
            }
        }
        .padding(.horizontal, CoreSpacing.sm)
        .padding(.vertical, CoreSpacing.xxs)
        .background(
            RoundedRectangle(cornerRadius: CoreRadius.small)
                .fill(Color.surfaceCanvasInset)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CoreRadius.small)
                .strokeBorder(Color.borderMuted, lineWidth: CoreBorderWidth.thin)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(self.accessibilityText)
        .accessibilityAddTraits(.isStaticText)
    }

    private var accessibilityText: String {
        if let ref = self.singleRef {
            return ref
        } else if let base = self.base, let head = self.head {
            return "\(base) from \(head)"
        }
        return ""
    }
}

#Preview {
    VStack(spacing: 12) {
        RefPill("main")
        RefPill(base: "main", head: "feat/foo")
        RefPill("a1b2c3d4e5f6")
    }
    .padding()
}
