//
//  SearchField.swift
//  CoreDesign
//
//  Source of truth: docs/PRIMER_VERSION.md
//

import SwiftUI

// MARK: - SearchField

/// GitHub Primer 风格的搜索输入框 / GitHub Primer–styled search input field.
///
/// **使用场景 / Use cases**：列表 / 表格 / 侧栏顶部的关键字过滤入口；
/// 全局搜索的内联触发器；表单内"search-as-you-type"过滤场景。需要复杂的
/// 命令面板（带建议列表 / 历史记录 / scope 切换）时，应使用更高层组合
/// 而非本组件单体。
///
/// **关键参数语义 / Key parameters**：
/// - `text` —— 双向绑定的搜索文本；调用方负责派生过滤结果与持久化策略。
/// - `placeholder` —— 空文本占位提示，默认 `"Search"`；走 SwiftUI `TextField`
///   原生 placeholder 渲染（自动套 `Color.contentPlaceholder`）。
/// - `onSubmit` —— Return / Enter 提交回调；当用户按下提交键时调用，参数为
///   当前 `text`。**可选**——对纯实时过滤场景留 `nil` 即可。
///
/// **Primer 概念对应 / Primer concept mapping**：
/// 对应 Primer Web 的 `<TextInput leadingVisual={SearchIcon} trailingAction={...} />`
/// 组合（GitHub 桌面 UI 中的 issue / PR 列表筛选框，仓库左上角的 "Go to file" 入口）。
/// 本实现复刻其"凹陷 well + 前缀 magnifyingglass + 末尾 clear button"三件套形态。
///
/// **light / dark 行为 / light-dark behavior**：
/// - 容器底色 `Color.surfaceCanvasInset`、边框 `Color.borderMuted`、文字
///   `Color.contentPrimary`、icon `Color.contentMuted` 均走 v2-tokens 语义色，
///   light / dark 双模式自动切换。
/// - 焦点环走 `View.focusRing(visible:)`：iOS 与 macOS 共享同一套 SwiftUI overlay
///   实现（**不是临时分支**——是 v2-tokens issue #9 spike 的最终决议）。macOS
///   下该 overlay **不被 Accessibility Inspector 识别为系统 focus indicator**，
///   仅是视觉等价；这是 PRD SC #11 已记录的限制，详见 `FocusRingModifier.swift`
///   文件级 doc-comment。键盘 focus / 失焦切换由内部 `@FocusState` 驱动，
///   `borderFocus` 仅在聚焦时高亮 2pt 描边。
///
/// **height 策略 / height strategy**：使用 `frame(minHeight:)` 而非
/// `frame(height:)`，遵循 `CoreControlMetrics` doc-comment 推荐——避免字号偏大时
/// padding × 2 + font 超过 `height(for:)` 的 Primer 精确值导致裁切。
///
/// 调用示例 / Example usage:
///
/// ```swift
/// @State private var query: String = ""
/// SearchField(text: $query, placeholder: "Filter issues") { submitted in
///     viewModel.runSearch(submitted)
/// }
/// ```
public struct SearchField: View {
    /// 创建搜索输入框 / Creates a search input field.
    ///
    /// - Parameters:
    ///   - text: 搜索文本的双向绑定 / Two-way binding to the search text.
    ///   - placeholder: 空文本占位提示，默认 `"Search"` / Placeholder shown when
    ///     `text` is empty; defaults to `"Search"`.
    ///   - onSubmit: Return / Enter 提交回调，参数为当前 `text`，可选 / Submit
    ///     callback fired on Return; receives the current `text`. Optional.
    public init(
        text: Binding<String>,
        placeholder: String = "Search",
        onSubmit: ((String) -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.onSubmit = onSubmit
    }

    public var body: some View {
        HStack(spacing: CoreSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: CoreControlMetrics.iconSize(for: .regular)))
                .foregroundStyle(Color.contentMuted)
                .accessibilityHidden(true)

            TextField(self.placeholder, text: self.$text)
                .textFieldStyle(.plain)
                .font(CoreControlMetrics.font(for: .regular))
                .foregroundStyle(Color.contentPrimary)
                .focused(self.$isFocused)
                .onSubmit {
                    self.onSubmit?(self.text)
                }

            if self.text.isEmpty == false {
                Button {
                    self.text = ""
                    self.isFocused = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: CoreControlMetrics.iconSize(for: .regular)))
                        .foregroundStyle(Color.contentMuted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, CoreControlMetrics.horizontalPadding(for: .regular))
        .padding(.vertical, CoreControlMetrics.verticalPadding(for: .regular))
        .frame(minHeight: CoreControlMetrics.height(for: .regular))
        .background(
            RoundedRectangle(cornerRadius: CoreRadius.medium, style: .continuous)
                .fill(Color.surfaceCanvasInset)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CoreRadius.medium, style: .continuous)
                .stroke(Color.borderMuted, lineWidth: CoreBorderWidth.thin)
        )
        .focusRing(
            visible: self.isFocused,
            color: .borderFocus,
            width: CoreBorderWidth.thick,
            cornerRadius: CoreRadius.medium
        )
        .contentShape(Rectangle())
        .onTapGesture {
            self.isFocused = true
        }
    }

    @Binding private var text: String
    private let placeholder: String
    private let onSubmit: ((String) -> Void)?

    @FocusState private var isFocused: Bool
}

// MARK: - Preview

#if DEBUG
private struct SearchFieldPreviewHost: View {
    @State private var emptyText: String = ""
    @State private var filledText: String = "release notes"

    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.lg) {
            VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                Text("Empty (placeholder visible, no clear button)")
                    .font(CoreTypography.captionFont)
                    .foregroundStyle(Color.contentMuted)
                SearchField(text: self.$emptyText, placeholder: "Search")
            }

            VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                Text("With text (clear button visible)")
                    .font(CoreTypography.captionFont)
                    .foregroundStyle(Color.contentMuted)
                SearchField(text: self.$filledText, placeholder: "Search") { submitted in
                    print("submitted: \(submitted)")
                }
            }

            VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                Text("Tap to focus → focus ring 2pt borderFocus overlay")
                    .font(CoreTypography.captionFont)
                    .foregroundStyle(Color.contentMuted)
                SearchField(text: self.$emptyText, placeholder: "Filter issues")
            }

            Spacer()
        }
        .padding(CoreSpacing.lg)
    }
}

#Preview("SearchField — Light") {
    SearchFieldPreviewHost()
        .preferredColorScheme(.light)
}

#Preview("SearchField — Dark") {
    SearchFieldPreviewHost()
        .preferredColorScheme(.dark)
}
#endif
