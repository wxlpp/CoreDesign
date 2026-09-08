import SwiftUI

// MARK: - BottomInputBar Defaults

/// 组件源码提供的兜底文案。
public enum BottomInputBarDefaults {
    /// 输入框占位文字的兜底。
    public static var placeholder: String { String(localized: "iMessage", bundle: .module) }
}

// MARK: - BottomInputBar

/// 浮层输入条。
public struct BottomInputBar: View {
    /// 直接构造浮层输入条。
    ///
    /// - Parameters:
    ///   - isShowingSuggestions: 建议条显隐的双向绑定，由调用方持有。
    ///   - placeholder: 输入框占位文字。
    ///   - wandEnabled: 是否显示魔杖按钮。
    ///   - sendEnabled: 发送动作是否可用（不禁用整条输入栏）。
    ///   - showMenuButton: 是否显示左侧菜单按钮。
    ///   - isRunning: 宿主任务是否在运行；为 `true` 时发送按钮变为停止按钮。
    ///   - autoFocus: 出现时是否自动聚焦输入框。
    ///   - externalFocus: 外层持有的 `@FocusState` 绑定，用于驱动 / 观测焦点。
    ///   - onActivate: 输入框获得焦点时的回调。
    ///   - onStop: `isRunning` 为 `true` 时点击停止按钮的回调。
    ///   - onSubmit: 提交回调，参数为当前文本。
    public init(
        isShowingSuggestions: Binding<Bool>,
        placeholder: String = BottomInputBarDefaults.placeholder,
        wandEnabled: Bool = true,
        sendEnabled: Bool = true,
        showMenuButton: Bool = true,
        isRunning: Bool = false,
        autoFocus: Bool = false,
        externalFocus: FocusState<Bool>.Binding? = nil,
        onActivate: (() -> Void)? = nil,
        onStop: (() -> Void)? = nil,
        onSubmit: @escaping (String) -> Void
    ) {
        self._isShowingSuggestions = isShowingSuggestions
        self.placeholder = placeholder
        self.wandEnabled = wandEnabled
        self.sendEnabled = sendEnabled
        self.showMenuButton = showMenuButton
        self.isRunning = isRunning
        self.autoFocus = autoFocus
        self.externalFocus = externalFocus
        self.onActivate = onActivate
        self.onStop = onStop
        self.onSubmit = onSubmit
    }

    @Binding var isShowingSuggestions: Bool

    let placeholder: String
    let wandEnabled: Bool
    let sendEnabled: Bool
    let showMenuButton: Bool
    let isRunning: Bool
    let autoFocus: Bool
    let externalFocus: FocusState<Bool>.Binding?
    let onActivate: (() -> Void)?
    let onSubmit: (String) -> Void
    let onStop: (() -> Void)?

    public var body: some View {
        self.mainRow
            .padding(.horizontal, CoreSpacing.md)
            .padding(.vertical, CoreSpacing.sm)
            .animation(.snappy(duration: 0.18), value: self.canSend)
            .animation(.snappy(duration: 0.18), value: self.isRunning)
            .animation(.snappy(duration: 0.2), value: self.isShowingSuggestions)
            .onAppear {
                if self.autoFocus, !self.isInputFocused {
                    self.isInputFocused = true
                }
            }
    }

    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool
    @State private var isExpanded = false

    private var trimmedInputText: String {
        self.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSend: Bool {
        !self.trimmedInputText.isEmpty && self.sendEnabled
    }

    private var mainRow: some View {
        HStack(alignment: .bottom, spacing: CoreSpacing.sm + CoreSpacing.xxs) {
            if self.showMenuButton {
                self.menuButton
            }
            self.textFieldContainer
            self.trailingButton
        }
    }

    @ViewBuilder
    private var trailingButton: some View {
        if !self.trimmedInputText.isEmpty {
            self.sendButton
                .disabled(!self.canSend)
                .opacity(self.canSend ? 1 : 0.4)
        } else if self.isRunning, self.onStop != nil {
            self.stopButton
        } else if self.wandEnabled {
            self.suggestionButton
        }
    }

    private var menuButton: some View {
        CoreMenuButton(
            isExpanded: self.$isExpanded,
            style: self.isInputFocused ? .circular : .labeled
        )
        .backgroundStyle(.green)
    }

    private var textFieldContainer: some View {
        HStack(alignment: .bottom, spacing: CoreSpacing.sm) {
            TextField(self.placeholder, text: self.$inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .padding(.vertical, CoreSpacing.sm)
                .padding(.leading, CoreSpacing.sm)
                .focused(self.$isInputFocused)
                .focusedExternally(self.externalFocus)
                .simultaneousGesture(TapGesture().onEnded { self.activateInput() })
        }
        .padding(.horizontal, CoreSpacing.xxs)
        .modifier(BottomInputBarGlassModifier())
    }

    private var suggestionButton: some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) {
                self.isShowingSuggestions.toggle()
            }
        } label: {
            Image(systemName: "wand.and.sparkles.inverse")
                .coreFont(.headline)
        }
        .buttonStyle(.circularGlass)
        .accessibilityLabel(Text("Suggestions", bundle: .module))
        .accessibilityAddTraits(self.isShowingSuggestions ? .isSelected : [])
    }

    private var sendButton: some View {
        Button {
            self.submitMessage()
        } label: {
            Image(systemName: "paperplane")
                .coreFont(.headline)
        }
        .foregroundStyle(.white)
        .backgroundStyle(.green)
        .buttonStyle(.circularGlass)
        .accessibilityLabel(Text("Send", bundle: .module))
    }

    private var stopButton: some View {
        Button(role: .destructive) {
            self.onStop?()
        } label: {
            Image(systemName: "stop.fill")
                .coreFont(.headline)
        }
        .foregroundStyle(.white)
        .backgroundStyle(.red)
        .buttonStyle(.circularGlass)
        .accessibilityLabel(Text("Stop", bundle: .module))
    }

    private func submitMessage() {
        guard self.canSend else {
            return
        }
        self.onSubmit(self.trimmedInputText)
        self.inputText = ""
        self.isInputFocused = false
        self.isShowingSuggestions = false
    }

    private func activateInput() {
        self.onActivate?()
        if !self.isInputFocused {
            self.isInputFocused = true
        }
    }
}

// MARK: - View focusedExternally helper

private extension View {
    @ViewBuilder
    func focusedExternally(_ binding: FocusState<Bool>.Binding?) -> some View {
        if let binding {
            self.focused(binding)
        } else {
            self
        }
    }
}

// MARK: - BottomInputBarGlassEffectShape

struct BottomInputBarGlassEffectShape: InsettableShape {
    var insetAmount: CGFloat = 0

    private static let minimumHitTargetSide: CGFloat = 44

    func path(in rect: CGRect) -> Path {
        let insetRect = rect.insetBy(dx: self.insetAmount, dy: self.insetAmount)
        let cornerRadius: CGFloat = insetRect.height <= Self.minimumHitTargetSide ? insetRect.height / 2 : CoreRadius.large
        return Path(roundedRect: insetRect, cornerRadius: cornerRadius)
    }

    func inset(by amount: CGFloat) -> BottomInputBarGlassEffectShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
}

// MARK: - BottomInputBarGlassModifier

private struct BottomInputBarGlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        let shape = BottomInputBarGlassEffectShape()
        return content
            .background(
                shape
                    .fill(.background.opacity(0.64))
                    .glassEffect(.regular, in: shape)
            )
            .overlay(
                shape.strokeBorder(Color.borderSubtle, lineWidth: CoreBorderWidth.hairline)
            )
    }
}

// MARK: - BottomInputBarSuggestionsView

struct BottomInputBarSuggestionsView: View {
    let isShowingSuggestions: Bool
    let suggestions: [String]
    let onTapSuggestion: (String) -> Void

    var body: some View {
        if self.isShowingSuggestions && !self.suggestions.isEmpty {
            let hasLongText = self.suggestions.contains { $0.count > 8 }
            let hasMany = self.suggestions.count > 6
            Group {
                if hasLongText {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                            ForEach(self.suggestions, id: \.self) { self.suggestionChip($0) }
                        }
                        .padding(.horizontal, CoreSpacing.md)
                        .padding(.vertical, CoreSpacing.xs + CoreSpacing.xxs)
                    }
                    .frame(maxHeight: 200)
                } else if hasMany {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: CoreSpacing.sm) {
                            ForEach(self.suggestions, id: \.self) {
                                self.suggestionChip($0)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.horizontal, CoreSpacing.md)
                        .padding(.vertical, CoreSpacing.xs + CoreSpacing.xxs)
                    }
                    .frame(maxHeight: 160)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: CoreSpacing.sm) {
                            ForEach(self.suggestions, id: \.self) { self.suggestionChip($0) }
                        }
                        .padding(.horizontal, CoreSpacing.md)
                        .padding(.vertical, CoreSpacing.xs + CoreSpacing.xxs)
                    }
                }
            }
        }
    }

    private func suggestionChip(_ suggestion: String) -> some View {
        Button {
            self.onTapSuggestion(suggestion)
        } label: {
            Text(suggestion)
                .bottomInputBarChip()
        }
        .foregroundStyle(.primary)
    }
}

// MARK: - BottomInputBarModifier

struct BottomInputBarModifier: ViewModifier {
    init(
        suggestions: [String],
        placeholder: String,
        autoShowSuggestions: Bool,
        wandEnabled: Bool,
        sendEnabled: Bool,
        showMenuButton: Bool,
        isRunning: Bool,
        showShuffleButton: Bool,
        autoFocus: Bool,
        externalFocus: FocusState<Bool>.Binding?,
        onActivate: (() -> Void)?,
        onStop: (() -> Void)?,
        onSubmit: @escaping (String) -> Void
    ) {
        self._isShowingSuggestions = State(
            initialValue: autoShowSuggestions && !suggestions.isEmpty
        )
        self.suggestions = suggestions
        self.placeholder = placeholder
        self.autoShowSuggestions = autoShowSuggestions
        self.wandEnabled = wandEnabled
        self.sendEnabled = sendEnabled
        self.showMenuButton = showMenuButton
        self.isRunning = isRunning
        self.showShuffleButton = showShuffleButton
        self.autoFocus = autoFocus
        self.externalFocus = externalFocus
        self.onActivate = onActivate
        self.onStop = onStop
        self.onSubmit = onSubmit
    }

    let suggestions: [String]
    let placeholder: String
    let autoShowSuggestions: Bool
    let wandEnabled: Bool
    let sendEnabled: Bool
    let showMenuButton: Bool
    let isRunning: Bool
    let showShuffleButton: Bool
    let autoFocus: Bool
    let externalFocus: FocusState<Bool>.Binding?
    let onActivate: (() -> Void)?
    let onStop: (() -> Void)?
    let onSubmit: (String) -> Void

    func body(content: Content) -> some View {
        content
            .safeAreaBar(edge: .bottom, content: { self.suggestionsBar })
            .safeAreaBar(edge: .bottom, content: { self.inputBar })
            .onChange(of: self.suggestions) { _, newValue in
                if self.autoShowSuggestions, !newValue.isEmpty {
                    self.setSuggestionsVisible(true)
                } else if newValue.isEmpty, self.isShowingSuggestions {
                    self.setSuggestionsVisible(false)
                }
            }
            .onChange(of: self.autoShowSuggestions) { _, newValue in
                if newValue, !self.suggestions.isEmpty {
                    self.setSuggestionsVisible(true)
                } else if !newValue, self.isShowingSuggestions {
                    self.setSuggestionsVisible(false)
                }
            }
    }

    // MARK: - Private helpers

    private var suggestionsBar: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.xs + CoreSpacing.xxs) {
            if self.isShowingSuggestions, self.showShuffleButton {
                HStack {
                    Spacer()
                    Button {
                        self.onSubmit("换一批")
                    } label: {
                        Label("换一批", systemImage: "arrow.clockwise")
                            .bottomInputBarChip()
                    }
                    .foregroundStyle(.primary)
                }
                .padding(.horizontal, CoreSpacing.xl)
            }

            BottomInputBarSuggestionsView(
                isShowingSuggestions: self.isShowingSuggestions,
                suggestions: self.suggestions
            ) { suggestion in
                self.onSubmit(suggestion)
                self.setSuggestionsVisible(false)
            }
        }
    }

    private var inputBar: some View {
        BottomInputBar(
            isShowingSuggestions: self.$isShowingSuggestions,
            placeholder: self.placeholder,
            wandEnabled: self.wandEnabled,
            sendEnabled: self.sendEnabled,
            showMenuButton: self.showMenuButton,
            isRunning: self.isRunning,
            autoFocus: self.autoFocus,
            externalFocus: self.externalFocus,
            onActivate: self.onActivate,
            onStop: self.onStop,
            onSubmit: self.onSubmit
        )
    }

    private func setSuggestionsVisible(_ visible: Bool) {
        withAnimation(.snappy(duration: 0.2)) {
            self.isShowingSuggestions = visible
        }
    }

    @State private var isShowingSuggestions: Bool
}

public extension View {
    func bottomInputBar(
        suggestions: [String],
        placeholder: String = BottomInputBarDefaults.placeholder,
        autoShowSuggestions: Bool = false,
        wandEnabled: Bool = true,
        sendEnabled: Bool = true,
        showMenuButton: Bool = true,
        isRunning: Bool = false,
        showShuffleButton: Bool = true,
        autoFocus: Bool = false,
        externalFocus: FocusState<Bool>.Binding? = nil,
        onActivate: (() -> Void)? = nil,
        onStop: (() -> Void)? = nil,
        onSubmit: @escaping (String) -> Void
    )
        -> some View
    {
        self.modifier(
            BottomInputBarModifier(
                suggestions: suggestions,
                placeholder: placeholder,
                autoShowSuggestions: autoShowSuggestions,
                wandEnabled: wandEnabled,
                sendEnabled: sendEnabled,
                showMenuButton: showMenuButton,
                isRunning: isRunning,
                showShuffleButton: showShuffleButton,
                autoFocus: autoFocus,
                externalFocus: externalFocus,
                onActivate: onActivate,
                onStop: onStop,
                onSubmit: onSubmit
            )
        )
    }
}

#Preview {
    VStack {
        Spacer()
        Color.clear.bottomInputBar(suggestions: ["续写下一段", "换个风格", "润色文字", "生成对话"]) { text in
            print("发送: \(text)")
        }
    }
}

// MARK: - Chip 样式

private struct BottomInputBarChipModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .coreFont(.body)
            .padding(.horizontal, CoreSpacing.md)
            .padding(.vertical, CoreSpacing.sm)
            .glassEffect(.regular, in: Capsule())
    }
}

private extension View {
    func bottomInputBarChip() -> some View {
        self.modifier(BottomInputBarChipModifier())
    }
}
