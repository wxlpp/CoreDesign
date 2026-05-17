//
//  BottomInputBar.swift
//  CoreDesign
//
//  Created by Evan Wang on 2026/3/28.
//

import SwiftUI

// MARK: - BottomInputBar

/// Native Primer floating input bar.
///
/// The library's most prominent floating input surface. Uses iOS 26 Liquid
/// Glass via `BottomInputBarGlassModifier` (Phase 2A refactor:
/// `BottomInputBarGlassEffectShape: InsettableShape` + `strokeBorder`
/// overlay). Input ergonomics still come first — the glass is the chrome,
/// not the feature.
///
/// **Material layer**: floating. **Surface role**: floating.
struct BottomInputBar: View {
    init(
        isShowingSuggestions: Binding<Bool>,
        placeholder: String = "iMessage",
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
    /// bar 一 mount 就把焦点拉到自身的 TextField 上。**关键**：用 bar 自己的
    /// `.onAppear` 而不是父 view 的 onAppear——只有此时 `.focused($isInputFocused)`
    /// 已经绑上来，写内部 FocusState 才会真的让 TextField first-responder；父
    /// view 的 onAppear 触发时子 view 还没 mount，写 @FocusState 会被 SwiftUI 丢弃。
    /// 也不用 `.task`：.task 是 async dispatch，body 可能被排到 dismiss 之后跑，
    /// 导致键盘"收起 → 又弹起 → 再收起"的 race。
    let autoFocus: Bool
    /// 外层 view（譬如 AppShell）持有的 `@FocusState`，让外层能驱动 / 观测 bar 的
    /// 焦点状态——譬如 dismiss panel 时翻 false 主动 resign。bar 内部仍然挂自己的
    /// `@FocusState` 跟踪触摸态，两个 `.focused()` modifier 协同同步。
    let externalFocus: FocusState<Bool>.Binding?
    let onActivate: (() -> Void)?
    let onSubmit: (String) -> Void
    let onStop: (() -> Void)?

    var body: some View {
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
    @State private var textFieldSize: CGSize = .zero

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
        MenuButton(
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
                .getSize(self.$textFieldSize)
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
                .font(CoreTypography.titleSmallFont)
        }
        .buttonStyle(.circularGlass)
    }

    private var sendButton: some View {
        Button {
            self.submitMessage()
        } label: {
            Image(systemName: "paperplane")
                .font(CoreTypography.titleSmallFont)
        }
        .foregroundStyle(.white)
        .backgroundStyle(.green)
        .buttonStyle(.circularGlass)
    }

    private var stopButton: some View {
        Button(role: .destructive) {
            self.onStop?()
        } label: {
            Image(systemName: "stop.fill")
                .font(CoreTypography.titleSmallFont)
        }
        .foregroundStyle(.white)
        .backgroundStyle(.red)
        .buttonStyle(.circularGlass)
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
    /// `.focused(_:)` 的可选版——`binding` 为 nil 时跳过这层 modifier。让 BottomInputBar
    /// 既能挂自身内部 `@FocusState`、又能把外层（譬如 AppShell）传进来的可选 binding
    /// 同步上去，无外层时不污染 view tree。
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

    func path(in rect: CGRect) -> Path {
        let insetRect = rect.insetBy(dx: self.insetAmount, dy: self.insetAmount)
        let cornerRadius: CGFloat = insetRect.height <= 44 ? insetRect.height / 2 : CoreRadius.large
        return Path(roundedRect: insetRect, cornerRadius: cornerRadius)
    }

    // InsettableShape：配合 `strokeBorder` 把描边收在路径内部，避免被外部
    // clipShape / glassEffect 裁掉外侧一半（与 SurfaceModifier 边框约定一致）。
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
                .font(.subheadline)
                .padding(.horizontal, CoreSpacing.md)
                .padding(.vertical, CoreSpacing.sm)
                .glassEffect(.regular, in: Capsule())
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
            // suggestions chips 段：用 `safeAreaBar` 而非 `safeAreaInset`——iOS 26 起前者
            // 在 inset 安全区之外**会把内层 ScrollView 的 scroll edge effect 延伸**到 bar
            // 区（Liquid Glass 内容渐隐 / 模糊），后者只 inset 不带边缘效果，导致内容滑到
            // 底时硬切到 bar 边缘。
            .safeAreaBar(edge: .bottom, content: {
                VStack(alignment: .leading, spacing: CoreSpacing.xs + CoreSpacing.xxs) {
                    if self.isShowingSuggestions, self.showShuffleButton {
                        HStack {
                            Spacer()
                            Button {
                                self.onSubmit("换一批")
                            } label: {
                                Label("换一批", systemImage: "arrow.clockwise")
                                    .font(.subheadline)
                                    .padding(.horizontal, CoreSpacing.md)
                                    .padding(.vertical, CoreSpacing.sm)
                                    .glassEffect(.regular, in: Capsule())
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
                        withAnimation(.snappy(duration: 0.2)) {
                            self.isShowingSuggestions = false
                        }
                    }
                }
            })
            // 输入框段：同样走 `safeAreaBar` —— 让 NavigationStack 内每条页面的 ScrollView
            // 都自动拿到底部 inset + scroll edge effect，无需各页自行 contentMargins。
            // bar 自身 pill 上的 `.glassEffect(.regular, in: BottomInputBarGlassEffectShape())`
            // 仍负责视觉材质；safeAreaBar 不会再叠一层背景。
            .safeAreaBar(edge: .bottom, content: {
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
            })
            .onChange(of: self.suggestions) { _, newValue in
                if self.autoShowSuggestions, !newValue.isEmpty {
                    withAnimation(.snappy(duration: 0.2)) {
                        self.isShowingSuggestions = true
                    }
                } else if newValue.isEmpty, self.isShowingSuggestions {
                    withAnimation(.snappy(duration: 0.2)) {
                        self.isShowingSuggestions = false
                    }
                }
            }
            .onChange(of: self.autoShowSuggestions) { _, newValue in
                if newValue, !self.suggestions.isEmpty {
                    withAnimation(.snappy(duration: 0.2)) {
                        self.isShowingSuggestions = true
                    }
                } else if !newValue, self.isShowingSuggestions {
                    withAnimation(.snappy(duration: 0.2)) {
                        self.isShowingSuggestions = false
                    }
                }
            }
    }

    @State private var isShowingSuggestions: Bool
}

public extension View {
    func bottomInputBar(
        suggestions: [String],
        placeholder: String = "iMessage",
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
