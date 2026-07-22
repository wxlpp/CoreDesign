//
//  SearchField.swift
//  CoreDesign
//
//  Source of truth: docs/PRIMER_VERSION.md
//

import SwiftUI

// MARK: - SearchField

/// Native Primer search field.
///
/// A compact Apple-native search/filter control with GitHub-like utility:
/// leading search icon, optional clear action, clear focus ring, and no default
/// Liquid Glass.
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
/// **Primer utility mapping / Primer 实用性映射**：
/// 对应 Primer Web 的 `<TextInput leadingVisual={SearchIcon} trailingAction={...} />`
/// 组合（GitHub 桌面 UI 中的 issue / PR 列表筛选框，仓库左上角的 "Go to file" 入口）。
/// 本实现保留其前缀 magnifyingglass + 末尾 clear button 的实用结构。
///
/// **light / dark 行为 / light-dark behavior**：
/// - 容器底色 `Color.surfaceInteractive`、边框 `Color.borderMuted`、文字
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
/// **In-tree 渲染保证 / In-tree rendering guarantee**：本组件**不调用** SwiftUI
/// `.searchable()`——它纯粹由 `HStack + TextField` 组成，因此在任意父容器
/// （`NavigationSplitView` 的 sidebar / content / detail、`NavigationStack`、
/// 普通 `VStack`）内都会原地渲染，**不会被 SwiftUI 提升到窗口 toolbar**。
/// 对 macOS 多列工作区尤其重要：调用方放在 `NavigationSplitView { } content: { }` 内
/// 时，组件不会与右上角 toolbar 项（如 Inspector toggle）抢占位置。详见
/// "Toolbar hoist verification (macOS)" Preview / issue #83。
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
        let shape = CoreShape.rounded(CoreRadius.small)
        return HStack(spacing: CoreSpacing.sm) {
            // 聚焦命中区 / Focus hit-test region：点击放大镜 + TextField 区域才聚焦，
            // 不包含尾部 clear button——避免清空时容器 tap 立即重新聚焦的交互冲突。
            HStack(spacing: CoreSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: CoreControlMetrics.iconSize(for: .regular)))
                    .foregroundStyle(Color.contentMuted)
                    .accessibilityHidden(true)

                TextField(self.placeholder, text: self.$text)
                    .textFieldStyle(.plain)
                    .coreFont(CoreControlMetrics.fontToken(for: .regular))
                    .foregroundStyle(Color.contentPrimary)
                    .accessibilityLabel(self.placeholder.isEmpty ? "Search" : self.placeholder)
                    .focused(self.$isFocused)
                    .simultaneousGesture(TapGesture().onEnded { self.isFocused = true })
                    .onSubmit {
                        self.onSubmit?(self.text)
                    }
            }
            .contentShape(Rectangle())
            .onTapGesture { self.isFocused = true }

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
                .contentShape(Rectangle())
                .padding(.horizontal, CoreSpacing.xs)
                .accessibilityLabel(Text("Clear \(self.placeholder.isEmpty ? "search" : self.placeholder)"))
            }
        }
        .padding(.horizontal, CoreControlMetrics.horizontalPadding(for: .regular))
        .padding(.vertical, CoreControlMetrics.verticalPadding(for: .regular))
        .frame(minHeight: CoreControlMetrics.height(for: .regular))
        .background {
            shape.fill(Color.surfaceInteractive)
        }
        .overlay {
            shape.strokeBorder(Color.borderMuted, lineWidth: CoreBorderWidth.thin)
        }
        .focusRing(
            visible: self.isFocused,
            color: .borderFocus,
            width: CoreBorderWidth.thick,
            cornerRadius: CoreRadius.small
        )
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
                    .coreFont(.caption)
                    .foregroundStyle(Color.contentMuted)
                SearchField(text: self.$emptyText, placeholder: "Search")
            }

            VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                Text("With text (clear button visible)")
                    .coreFont(.caption)
                    .foregroundStyle(Color.contentMuted)
                SearchField(text: self.$filledText, placeholder: "Search") { submitted in
                    print("submitted: \(submitted)")
                }
            }

            VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                Text("Filled + focused (tap field → focus ring 2pt + clear button)")
                    .coreFont(.caption)
                    .foregroundStyle(Color.contentMuted)
                SearchField(text: self.$filledText, placeholder: "Filter items")
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

/// Toolbar hoist 验证 / Toolbar hoist verification：
///
/// 把 `SearchField` 放进 `NavigationSplitView` 的 content 列，并在 toolbar 的
/// `.primaryAction` 槽里放一个按钮。**预期**：search 框留在 content 列内（不被
/// SwiftUI 自动提升到窗口 toolbar），`.primaryAction` 按钮仍可见、可点击。
///
/// 这是 macOS 上对应原生 `.searchable()` 的反例验证——`.searchable()` 在 macOS
/// 会把 TextField hoist 到窗口标题栏，挤占 toolbar 槽位；本组件不走那条路径，
/// 因而可以与右上 toolbar 项（如 Inspector toggle）共存。Issue #83 跟踪该确认。
private struct SearchFieldNavigationHostPreview: View {
    @State private var query: String = ""
    @State private var sidebarSelection: String? = "Inbox"

    var body: some View {
        NavigationSplitView {
            List(selection: self.$sidebarSelection) {
                Text("Inbox").tag(Optional("Inbox"))
                Text("Drafts").tag(Optional("Drafts"))
                Text("Archive").tag(Optional("Archive"))
            }
            .navigationTitle("Sidebar")
        } content: {
            VStack(alignment: .leading, spacing: CoreSpacing.md) {
                SearchField(text: self.$query, placeholder: "Filter")
                List {
                    ForEach(0..<8, id: \.self) { i in
                        Text("Item \(i + 1)")
                    }
                }
                .listStyle(.inset)
            }
            .padding(CoreSpacing.md)
            .navigationTitle("Content")
        } detail: {
            Text("Detail column")
                .foregroundStyle(Color.contentMuted)
                .navigationTitle("Detail")
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    // Inspector toggle stand-in — proves the toolbar slot is unaffected.
                } label: {
                    Image(systemName: "sidebar.right")
                }
                .accessibilityLabel("Toggle Inspector")
            }
        }
    }
}

#Preview("Toolbar hoist verification (macOS) — issue #83") {
    SearchFieldNavigationHostPreview()
        .frame(minWidth: 720, minHeight: 480)
}
#endif
