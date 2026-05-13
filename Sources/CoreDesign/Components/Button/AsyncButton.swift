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
