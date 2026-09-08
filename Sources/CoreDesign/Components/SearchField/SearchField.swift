import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

// MARK: - SearchField

/// 搜索 / 筛选控件，内部是**平台原生**搜索框
/// （iOS `UISearchTextField` / macOS `NSSearchField`）。
///
/// 放弃手搓实现的理由：放大镜、清除按钮、占位文案、焦点态、RTL 镜像、Dynamic Type
/// 与 iOS 26 的系统观感全部由平台提供，手搓版只是它的仿件。
///
/// ⚠️ **有意不用 `.searchable(text:)`**：那是 navigation 作用域的，由系统决定放进
/// 导航栏 / 工具栏；本组件是可内联摆放的独立控件（筛选栏 / 侧栏列）。
/// 该替代方案在 `docs/component-registry.json` 的本组件条目里已评估并否决。
///
/// ⚠️ **原生控件不随 frame 撑满**：iOS 实测 `intrinsicContentSize.height = 28`，
/// 在 28 / 36 / 44 三档 frame 下绘制带恒为同一高度且垂直居中；macOS `NSSearchField`
/// 同形（`.large` intrinsic 28）。⇒ 视觉高度取控件自然高，**44pt 触控下限由外层
/// 包装层承担**（见 `body` 里的 `frame(minHeight:)` + `contentShape`）。
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
        NativeSearchField(
            text: self.$text,
            placeholder: self.placeholder,
            onSubmit: self.onSubmit,
            focusRequests: self.focusRequests
        )
        .frame(maxWidth: .infinity)
        .frame(minHeight: CoreControlMetrics.height(for: .regular))
        .contentShape(Rectangle())
        .onTapGesture { self.focusRequests += 1 }
    }

    @Binding private var text: String
    private let placeholder: String
    private let onSubmit: ((String) -> Void)?

    /// 单调递增的聚焦请求计数。包装层的 44pt 命中区被点到时 +1，
    /// 由 representable 转成 `becomeFirstResponder()`——原生控件只占中间那一条，
    /// 不重建这条链的话，命中区上下缘点了不会聚焦。
    @State private var focusRequests: Int = 0
}

// MARK: - NativeSearchField

#if canImport(UIKit)
private struct NativeSearchField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onSubmit: ((String) -> Void)?
    let focusRequests: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UISearchTextField {
        let field = UISearchTextField()
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged(_:)), for: .editingChanged)
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateUIView(_ field: UISearchTextField, context: Context) {
        context.coordinator.parent = self
        field.placeholder = self.placeholder
        if field.text != self.text {
            field.text = self.text
        }
        if context.coordinator.lastFocusRequest != self.focusRequests {
            context.coordinator.lastFocusRequest = self.focusRequests
            if self.focusRequests > 0, !field.isFirstResponder {
                field.becomeFirstResponder()
            }
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: NativeSearchField
        var lastFocusRequest: Int = 0

        init(_ parent: NativeSearchField) {
            self.parent = parent
        }

        @objc func editingChanged(_ field: UITextField) {
            self.parent.text = field.text ?? ""
        }

        func textFieldShouldReturn(_ field: UITextField) -> Bool {
            self.parent.onSubmit?(field.text ?? "")
            return true
        }
    }
}
#else
private struct NativeSearchField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onSubmit: ((String) -> Void)?
    let focusRequests: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.controlSize = .large
        field.delegate = context.coordinator
        field.target = context.coordinator
        field.action = #selector(Coordinator.submitted(_:))
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateNSView(_ field: NSSearchField, context: Context) {
        context.coordinator.parent = self
        field.placeholderString = self.placeholder
        if field.stringValue != self.text {
            field.stringValue = self.text
        }
        if context.coordinator.lastFocusRequest != self.focusRequests {
            context.coordinator.lastFocusRequest = self.focusRequests
            if self.focusRequests > 0 {
                field.window?.makeFirstResponder(field)
            }
        }
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: NativeSearchField
        var lastFocusRequest: Int = 0

        init(_ parent: NativeSearchField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            self.parent.text = field.stringValue
        }

        @objc func submitted(_ field: NSSearchField) {
            self.parent.onSubmit?(field.stringValue)
        }
    }
}
#endif

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
                Text("With text (system clear button visible)")
                    .coreFont(.caption)
                    .foregroundStyle(Color.contentMuted)
                SearchField(text: self.$filledText, placeholder: "Search") { submitted in
                    print("submitted: \(submitted)")
                }
            }

            VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                Text("Tap anywhere in the 44pt hit area → focuses")
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
