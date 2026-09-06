import SwiftUI

// MARK: - SearchField

/// 紧凑的搜索 / 筛选控件：leading 放大镜图标 + 可选清除动作 + 明确的焦点环，
/// **无默认 Liquid Glass**。
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
            HStack(spacing: CoreSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: CoreControlMetrics.iconSize(for: .regular)))
                    .foregroundStyle(Color.contentMuted)
                    .accessibilityHidden(true)

                TextField(self.placeholder, text: self.$text)
                    .textFieldStyle(.plain)
                    .coreFont(CoreControlMetrics.fontToken(for: .regular))
                    .foregroundStyle(Color.contentPrimary)
                    .accessibilityLabel(self.placeholder.isEmpty
                        ? String(localized: "Search", bundle: .module)
                        : self.placeholder)
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
                .accessibilityLabel(Text(Self.clearLabel(for: self.placeholder)))
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

    static func clearLabel(for placeholder: String) -> String {
        let target = placeholder.isEmpty
            ? String(localized: "search", bundle: .module)
            : placeholder
        return String(localized: "Clear \(target)", bundle: .module)
    }
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
                } label: {
                    Image(systemName: "sidebar.right")
                }
                .accessibilityLabel("Toggle Inspector")
            }
        }
    }
}

#Preview("Toolbar hoist verification (macOS)") {
    SearchFieldNavigationHostPreview()
        .frame(minWidth: 720, minHeight: 480)
}
#endif
