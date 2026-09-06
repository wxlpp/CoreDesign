import SwiftUI

// MARK: - AsyncButton

/// 把 async 闭包封装成按钮的视图组件。
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
            self.isRunning = true
            self.task = Task { @MainActor in
                defer {
                    self.isRunning = false
                    self.task = nil
                }
                await self.run()
            }
        } label: {
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

    @MainActor
    internal static func _runThrowing(
        _ action: @MainActor @Sendable () async throws -> Void,
        onError: (@MainActor @Sendable (Error) -> Void)?,
        toastHost: ToastHost?
    ) async {
        do {
            try await action()
        } catch is CancellationError {
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

private struct LoadingAccessibilityModifier: ViewModifier {
    let isLoading: Bool

    func body(content: Content) -> some View {
        if self.isLoading {
            content.accessibilityValue(Text("Loading", bundle: .module))
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
    @_disfavoredOverload
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
    @_disfavoredOverload
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
