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
/// 详细设计见 `docs/superpowers/specs/2026-05-13-async-button-design.md`。
public struct AsyncButton<Label: View>: View {

    @State private var task: Task<Void, Never>?
    @State private var isRunning = false

    private let action: @MainActor @Sendable () async -> Void
    private let label: Label

    /// 非抛错 init。
    public init(
        action: @escaping @MainActor @Sendable () async -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.action = action
        self.label = label()
    }

    /// 抛错 init。CancellationError 静默吞下;业务错误转发给 onError(可选)。
    public init(
        action: @escaping @MainActor @Sendable () async throws -> Void,
        onError: (@MainActor @Sendable (Error) -> Void)? = nil,
        @ViewBuilder label: () -> Label
    ) {
        self.action = Self._wrapThrowingAction(action, onError: onError)
        self.label = label()
    }

    /// 内部 wrapping 工具,供测试直接调用(不暴露给 SwiftUI 调用方使用)。
    /// 前缀下划线遵循 Swift 隐式 SPI 约定。
    ///
    /// 本函数自身不在 MainActor 上执行任何代码,只是构造并返回一个
    /// `@MainActor` 闭包,因此不需要 `@MainActor` 标注;init 在非 MainActor
    /// 环境也能同步调用它。
    internal static func _wrapThrowingAction(
        _ action: @escaping @MainActor @Sendable () async throws -> Void,
        onError: (@MainActor @Sendable (Error) -> Void)?
    ) -> @MainActor @Sendable () async -> Void {
        return { @MainActor in
            do {
                try await action()
            } catch is CancellationError {
                // 静默 —— 视图消失或主动取消,不视为业务故障
            } catch {
                onError?(error)
            }
        }
    }

    public var body: some View {
        Button {
            guard !self.isRunning else { return }
            self.task = Task { @MainActor in
                self.isRunning = true
                defer { self.isRunning = false }
                await self.action()
            }
        } label: {
            HStack(spacing: 6) {
                if self.isRunning {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.small)
                }
                self.label
            }
            .animation(.snappy(duration: 0.16), value: self.isRunning)
        }
        .allowsHitTesting(!self.isRunning)
        .accessibilityValue(self.isRunning ? Text("Loading") : Text(""))
        .onDisappear { self.task?.cancel() }
    }
}
