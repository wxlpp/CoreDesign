import SwiftUI

// MARK: - Tag

/// 控件层的分类标签。颜色由调用方提供（标签色、自定义色板等），chip 保持紧凑、
/// 低 chrome。**无默认玻璃、无装饰性材质**——语义完全来自调用方选的颜色。
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

    private static var backgroundOpacity: Double { 0.12 }

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
