//
//  AsyncButton.swift
//  CoreDesign
//

import SwiftUI

// MARK: - AsyncButton

/// 把 async 闭包封装成按钮的视图组件。
///
/// 自动管理 loading 期间的 spinner、防双击、视图消失时取消 Task。与既有 4 个
/// `ButtonStyle`(`.solid` / `.light` / `.borderless` / `.circularGlass`)正交,
/// 调用方依旧用 `.buttonStyle(...)` 设置外观。
///
/// ## 错误处理
///
/// 抛错版本(`() async throws -> Void`)按下列优先级分派业务错误:
///
/// 1. 显式 `onError` 闭包 → 调用 onError(error)
/// 2. 否则,环境里挂了 `\.toastHost` → `toastHost.show(error.localizedDescription, level: .danger)`
/// 3. 否则 → 静默(匹配 Toast 系统的"未挂 host 即无声忽略"原则)
///
/// `CancellationError` 始终静默,不视为业务故障。
///
/// 详细设计见 `docs/superpowers/specs/2026-05-13-async-button-design.md`。
public struct AsyncButton<Label: View>: View {

    @State private var task: Task<Void, Never>?
    @State private var isRunning = false

    @Environment(\.toastHost) private var toastHost

    private let kind: ActionKind
    private let label: Label

    /// 非抛错 init。
    public init(
        action: @escaping @MainActor @Sendable () async -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.kind = .nonThrowing(action)
        self.label = label()
    }

    /// 抛错 init。
    ///
    /// - Parameter onError: 业务错误回调。`nil` 时若环境里挂了 `\.toastHost` 则
    ///   以 `.danger` level 自动弹 toast；都未提供则静默。
    public init(
        action: @escaping @MainActor @Sendable () async throws -> Void,
        onError: (@MainActor @Sendable (Error) -> Void)? = nil,
        @ViewBuilder label: () -> Label
    ) {
        self.kind = .throwing(action: action, onError: onError)
        self.label = label()
    }

    public var body: some View {
        Button {
            guard !self.isRunning else { return }
            // 同步置 true，避免 Task 启动前的同一 runloop 内多次点击竞态——
            // .allowsHitTesting 与 guard 均依赖 isRunning，必须在创建 Task
            // *之前* 翻转。
            self.isRunning = true
            self.task = Task { @MainActor in
                defer {
                    self.isRunning = false
                    self.task = nil
                }
                await self.run()
            }
        } label: {
            // ZStack + label 透明占位:running 时 label 隐藏但保留布局占位（防止
            // 按钮 frame 抖动），spinner 在 ZStack 中心覆盖。对 .circularGlass
            // 等 fixed-frame style（CircularGlassButtonStyle.swift:24 强制
            // 40pt 直径）也能保证不溢出——spinner 居中替代 icon，圆形外壳完好。
            ZStack {
                self.label
                    .opacity(self.isRunning ? 0 : 1)
                    .accessibilityHidden(self.isRunning)
                if self.isRunning {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.small)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityElement(children: .combine)
            .animation(.snappy(duration: 0.16), value: self.isRunning)
        }
        .allowsHitTesting(!self.isRunning)
        .modifier(LoadingAccessibilityModifier(isLoading: self.isRunning))
        .onDisappear { self.task?.cancel() }
    }

    @MainActor
    private func run() async {
        switch self.kind {
        case .nonThrowing(let action):
            await action()
        case .throwing(let action, let onError):
            await Self._runThrowing(
                action,
                onError: onError,
                toastHost: self.toastHost
            )
        }
    }

    /// 抛错路径的核心分派:CancellationError 静默,其余按 onError → toastHost
    /// → silent 顺序兜底。抽成静态函数便于在 `AsyncButtonTests` 中直接 `await`,
    /// 不需要驱动 SwiftUI view 树。前缀下划线遵循 Swift 隐式 SPI 约定。
    @MainActor
    internal static func _runThrowing(
        _ action: @MainActor @Sendable () async throws -> Void,
        onError: (@MainActor @Sendable (Error) -> Void)?,
        toastHost: ToastHost?
    ) async {
        do {
            try await action()
        } catch is CancellationError {
            // 静默 —— 视图消失或主动取消,不视为业务故障
        } catch {
            if let onError {
                onError(error)
            } else {
                toastHost?.show(error.localizedDescription, level: .danger)
            }
        }
    }
}

// MARK: - ActionKind

private enum ActionKind {
    case nonThrowing(@MainActor @Sendable () async -> Void)
    case throwing(
        action: @MainActor @Sendable () async throws -> Void,
        onError: (@MainActor @Sendable (Error) -> Void)?
    )
}

// MARK: - LoadingAccessibilityModifier

/// 仅在 loading 期间附加 `accessibilityValue("Loading")`；idle 态完全不设 value，
/// 避免 VoiceOver 朗读空字符串或多一次停顿。
private struct LoadingAccessibilityModifier: ViewModifier {
    let isLoading: Bool

    func body(content: Content) -> some View {
        if self.isLoading {
            content.accessibilityValue(Text("Loading"))
        } else {
            content
        }
    }
}

// MARK: - Text label conveniences

public extension AsyncButton where Label == Text {

    /// LocalizedStringKey + 非抛错。
    init(
        _ titleKey: LocalizedStringKey,
        action: @escaping @MainActor @Sendable () async -> Void
    ) {
        self.init(action: action) { Text(titleKey) }
    }

    /// StringProtocol + 非抛错。
    init<S: StringProtocol>(
        _ title: S,
        action: @escaping @MainActor @Sendable () async -> Void
    ) {
        self.init(action: action) { Text(title) }
    }

    /// LocalizedStringKey + 抛错 + 可选 onError。
    init(
        _ titleKey: LocalizedStringKey,
        action: @escaping @MainActor @Sendable () async throws -> Void,
        onError: (@MainActor @Sendable (Error) -> Void)? = nil
    ) {
        self.init(action: action, onError: onError) { Text(titleKey) }
    }

    /// StringProtocol + 抛错 + 可选 onError。
    init<S: StringProtocol>(
        _ title: S,
        action: @escaping @MainActor @Sendable () async throws -> Void,
        onError: (@MainActor @Sendable (Error) -> Void)? = nil
    ) {
        self.init(action: action, onError: onError) { Text(title) }
    }
}

// MARK: - Previews (development only — snapshot 脚本会删除 CoreDesign_*.png)

#Preview("AsyncButton — 全部 ButtonStyle") {
    VStack(spacing: 12) {
        AsyncButton("Solid") {
            try? await Task.sleep(for: .seconds(1.5))
        }
        .buttonStyle(.solid())

        AsyncButton("Light") {
            try? await Task.sleep(for: .seconds(1.5))
        }
        .buttonStyle(.light())

        AsyncButton("Borderless") {
            try? await Task.sleep(for: .seconds(1.5))
        }
        .buttonStyle(.borderless())

        AsyncButton {
            try? await Task.sleep(for: .seconds(1.5))
        } label: {
            Image(systemName: "arrow.clockwise")
        }
        .buttonStyle(.circularGlass)
    }
    .padding()
}

#Preview("AsyncButton — 抛错 + onError") {
    struct Harness: View {
        @State private var lastError: String = "(none)"
        var body: some View {
            VStack(spacing: 12) {
                AsyncButton("Throws") {
                    try await Task.sleep(for: .seconds(0.6))
                    struct DemoError: LocalizedError {
                        var errorDescription: String? { "Demo failure" }
                    }
                    throw DemoError()
                } onError: { error in
                    self.lastError = error.localizedDescription
                }
                .buttonStyle(.solid(role: .primary))

                Text("Last error: \(self.lastError)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
    return Harness()
}

#Preview("AsyncButton — 抛错 + 自动 toast fallback") {
    // 上层挂 .toastHost,onError 留空 → 自动弹 toast(level: .danger)
    VStack(spacing: 12) {
        AsyncButton("Throws (no onError)") {
            try await Task.sleep(for: .seconds(0.6))
            struct DemoError: LocalizedError {
                var errorDescription: String? { "Auto toast on failure" }
            }
            throw DemoError()
        }
        .buttonStyle(.solid(role: .danger))
    }
    .padding()
    .toastHost(edge: .top)
}

#Preview("AsyncButton — disabled / running 并存") {
    VStack(spacing: 12) {
        AsyncButton("Always disabled") {
            try? await Task.sleep(for: .seconds(1.5))
        }
        .buttonStyle(.solid())
        .disabled(true)

        AsyncButton("Normal") {
            try? await Task.sleep(for: .seconds(1.5))
        }
        .buttonStyle(.solid())
    }
    .padding()
}
