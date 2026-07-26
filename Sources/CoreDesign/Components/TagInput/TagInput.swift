//
//  TagInput.swift
//  CoreDesign
//

import SwiftUI

// MARK: - TagInput

/// `Binding<[String]>` 驱动的标签输入框：已有标签以 chip 形式展示，末尾内联一个
/// 文本输入框，回车或逗号提交新标签，点击 chip 上的删除按钮移除标签。
///
/// **复用边界**：折行复用 `FlowLayout`——输入框作为其最后一个子视图，随标签数量
/// 自然换行到新行；chip 单元复用 `Tag(_:color:removable:onRemove:)`，拿到现成的
/// 44pt 命中区删除按钮与已登记的 `"Remove tag"` 本地化键，**不重造**删除交互。
/// `Tag` 的调色板由调用方任意 `Color` 决定，本组件默认传 `Color.contentSecondary`
/// （中性文本色）而非某个具体色相——标签输入场景通常不需要 GitHub-label 式的
/// 分类配色，`tagColor` 参数把选择权交还调用方。
///
/// **提交规则**：
/// - trim 首尾空白/换行后为空字符串的候选**不提交**（`normalizedTag(_:)`）。
/// - `allowDuplicates == false`（默认）时，与已有标签**完全相等**（大小写敏感，
///   不做归一化）的候选不重复添加；`true` 时允许重复。
/// - 提交后清空输入框（含 Return 提交与逗号快速录入两条路径）。
///
/// **逗号快速录入**：输入框内容包含 `,` 时即时拆分——除最后一段外的每一段都各自
/// 按 trim + 去重规则提交，最后一段（可能仍在输入中）保留在输入框内。例如输入
/// `"bug, enhancement,"` 会连续提交 `"bug"` 与 `"enhancement"`，输入框归零；
/// 输入 `"bug,enh"` 只提交 `"bug"`，`"enh"` 留在输入框继续编辑。这是在
/// `TextField` 原生 `onSubmit`（Return）之外的**增强路径**，非替代。
///
/// **chip 迭代与去重安全**：`ForEach(Array(self.tags.enumerated()), id: \.offset)`——
/// 按下标而非标签值本身取 id，避免 `allowDuplicates: true` 时同名标签在 `ForEach`
/// 中产生 id 碰撞（SwiftUI 要求 id 在同一 `ForEach` 内唯一）。删除操作
/// （`removingTag(at:from:)`）同样按下标定位，因此"删除第二个同名 chip"精确
/// 命中该下标而非误删同名的第一个。
///
/// **无障碍**：输入框 `.accessibilityLabel(Text(self.placeholder))`——`placeholder`
/// 是调用方任意字符串（非受限于 Phase 0 登记表），走 verbatim 渲染，与
/// `SearchField.placeholder` 的处理方式一致。chip 删除按钮的无障碍标签完全来自
/// `Tag` 内建的 `"Remove tag"`（已在 Phase 0 登记），本组件不重复声明。
///
/// ## 使用示例
///
/// ```swift
/// @State private var tags: [String] = ["bug", "enhancement"]
///
/// TagInput(tags: $tags, placeholder: "Add tag") { committed in
///     print("committed: \(committed)")
/// }
/// ```
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
        FlowLayout(spacing: CoreSpacing.xs) {
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

    /// Return 提交路径：整段输入框内容作为单个候选提交，随后清空。
    private func commitDraft() {
        self.commitIfPossible(self.draft)
        self.draft = ""
    }

    /// 逗号快速录入路径：拆分出的完整段落逐一提交，末段写回输入框。
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

    /// trim 首尾空白/换行；结果为空字符串时返回 `nil`（不提交）。
    static func normalizedTag(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// 归一化 + 去重判断的合并入口：`raw` trim 后为空返回 `nil`；
    /// `allowDuplicates == false` 且 `existing` 中已存在完全相同（大小写敏感）
    /// 的标签时也返回 `nil`；否则返回可提交的归一化标签文本。
    static func tagToCommit(_ raw: String, into existing: [String], allowDuplicates: Bool) -> String? {
        guard let normalized = normalizedTag(raw) else { return nil }
        if allowDuplicates == false && existing.contains(normalized) {
            return nil
        }
        return normalized
    }

    /// 按 `,` 拆分输入框草稿：除最后一段外均视为"已输入完整"的候选段落，
    /// 最后一段（哪怕为空）作为仍在编辑中的剩余文本返回。不含 `,` 时
    /// `segments` 为空、`remainder` 即原始输入。
    static func splitDraftOnSeparator(_ draft: String) -> (segments: [String], remainder: String) {
        guard draft.contains(Self.separator) else { return ([], draft) }
        let parts = draft
            .split(separator: Self.separator, omittingEmptySubsequences: false)
            .map(String.init)
        return (Array(parts.dropLast()), parts.last ?? "")
    }

    /// 按下标移除 `tags` 中的一个元素；下标越界时原样返回，不崩溃。
    /// 按下标而非标签值定位——`allowDuplicates: true` 时同名标签也能精确删除
    /// 目标那一个，而非总是命中同名的第一个。
    static func removingTag(at index: Int, from tags: [String]) -> [String] {
        guard tags.indices.contains(index) else { return tags }
        var result = tags
        result.remove(at: index)
        return result
    }

    // MARK: - Tokens

    /// 逗号快速录入的分隔符。
    private static var separator: Character { "," }

    /// 输入框最小宽度，避免 `FlowLayout` 在标签较多时把输入框压缩到不可用宽度。
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
