import SwiftUI

// MARK: - TagInput

/// `Binding<[String]>` 驱动的标签输入框：已有标签以 chip 形式展示，末尾内联一个
/// 文本输入框，回车或逗号提交新标签，点击 chip 上的删除按钮移除标签。
public struct TagInput: View {
    // MARK: - Init

    /// 创建标签输入框。
    ///
    /// - Parameters:
    ///   - tags: 已提交标签的双向绑定，按添加顺序排列。
    ///   - placeholder: 输入框空态占位文案，默认 `"Add tag"`（Phase 0 已登记的
    ///     accessibility 字符串）。
    ///   - tagColor: chip 调色板，直接透传给 `Tag(color:)`，默认
    ///     `Color.contentSecondary`（中性文本色）。
    ///   - allowDuplicates: 是否允许提交与已有标签完全相同（大小写敏感）的候选，
    ///     默认 `false`。
    ///   - onCommit: 每次成功提交一个新标签后调用，参数为归一化后的标签文本。
    ///     未提供时忽略。
    public init(
        tags: Binding<[String]>,
        placeholder: String = "Add tag",
        tagColor: Color = .contentSecondary,
        allowDuplicates: Bool = false,
        onCommit: ((String) -> Void)? = nil
    ) {
        self._tags = tags
        self.placeholder = placeholder
        self.tagColor = tagColor
        self.allowDuplicates = allowDuplicates
        self.onCommit = onCommit
    }

    public var body: some View {
        FlowLayout(spacing: CoreSpacing.sm) {
            ForEach(Array(self.tags.enumerated()), id: \.offset) { index, tag in
                Tag(tag, color: self.tagColor, removable: true) {
                    self.tags = Self.removingTag(at: index, from: self.tags)
                }
            }

            TextField(self.placeholder, text: self.$draft)
                .textFieldStyle(.plain)
                .coreFont(CoreControlMetrics.fontToken(for: .regular))
                .foregroundStyle(Color.contentPrimary)
                .frame(minWidth: Self.minimumInputWidth)
                .frame(minHeight: CoreControlMetrics.height(for: .regular))
                .accessibilityLabel(Text(self.placeholder))
                .onSubmit {
                    self.commitDraft()
                }
                .onChange(of: self.draft) { _, newValue in
                    self.handleDraftChange(newValue)
                }
        }
    }

    // MARK: - Actions

    private func commitDraft() {
        self.commitIfPossible(self.draft)
        self.draft = ""
    }

    private func handleDraftChange(_ newValue: String) {
        let (segments, remainder) = Self.splitDraftOnSeparator(newValue)
        guard segments.isEmpty == false else { return }
        for segment in segments {
            self.commitIfPossible(segment)
        }
        self.draft = remainder
    }

    private func commitIfPossible(_ raw: String) {
        guard let normalized = Self.tagToCommit(raw, into: self.tags, allowDuplicates: self.allowDuplicates) else {
            return
        }
        self.tags.append(normalized)
        self.onCommit?(normalized)
    }

    // MARK: - Pure logic (unit-tested via TagInputTests)

    static func normalizedTag(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func tagToCommit(_ raw: String, into existing: [String], allowDuplicates: Bool) -> String? {
        guard let normalized = normalizedTag(raw) else { return nil }
        if allowDuplicates == false && existing.contains(normalized) {
            return nil
        }
        return normalized
    }

    static func splitDraftOnSeparator(_ draft: String) -> (segments: [String], remainder: String) {
        guard draft.contains(Self.separator) else { return ([], draft) }
        let parts = draft
            .split(separator: Self.separator, omittingEmptySubsequences: false)
            .map(String.init)
        return (Array(parts.dropLast()), parts.last ?? "")
    }

    static func removingTag(at index: Int, from tags: [String]) -> [String] {
        guard tags.indices.contains(index) else { return tags }
        var result = tags
        result.remove(at: index)
        return result
    }

    // MARK: - Tokens

    private static var separator: Character { "," }

    private static var minimumInputWidth: CGFloat { 80 }

    // MARK: - Storage

    @Binding private var tags: [String]
    private let placeholder: String
    private let tagColor: Color
    private let allowDuplicates: Bool
    private let onCommit: ((String) -> Void)?

    @State private var draft: String = ""
}

// MARK: - Preview

#if DEBUG
private struct TagInputPreviewHost: View {
    @State private var emptyTags: [String] = []
    @State private var manyTags: [String] = [
        "bug", "enhancement", "help wanted", "documentation",
        "good first issue", "dependencies", "question", "wontfix"
    ]
    @State private var duplicateAttemptTags: [String] = ["bug", "enhancement"]

    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.lg) {
            VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                Text("空态")
                    .coreFont(.caption)
                    .foregroundStyle(Color.contentMuted)
                TagInput(tags: self.$emptyTags, placeholder: "Add tag")
            }

            VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                Text("多标签换行态")
                    .coreFont(.caption)
                    .foregroundStyle(Color.contentMuted)
                TagInput(tags: self.$manyTags, placeholder: "Add tag")
                    .frame(width: 280)
            }

            VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                Text("尝试重复标签态（allowDuplicates: false，输入 \"bug\" 不会追加）")
                    .coreFont(.caption)
                    .foregroundStyle(Color.contentMuted)
                TagInput(tags: self.$duplicateAttemptTags, placeholder: "Add tag", allowDuplicates: false)
            }

            Spacer()
        }
        .padding(CoreSpacing.lg)
    }
}

#Preview("TagInput — Light") {
    TagInputPreviewHost()
        .preferredColorScheme(.light)
}

#Preview("TagInput — Dark") {
    TagInputPreviewHost()
        .preferredColorScheme(.dark)
}
#endif
