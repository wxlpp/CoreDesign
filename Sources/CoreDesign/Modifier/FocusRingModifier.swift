//
//  FocusRingModifier.swift
//  CoreDesign
//
//  Source of truth: docs/PRIMER_VERSION.md
//
//  本文件提供跨平台 `View.focusRing(visible:color:width:cornerRadius:)` modifier。
//  This file ships a cross-platform `View.focusRing(visible:color:width:cornerRadius:)`
//  modifier.
//
//  - iOS / iPadOS / visionOS: 完整实现 — `.overlay(RoundedRectangle().stroke())`
//    纯视觉焦点环，由 SwiftUI `@FocusState` 等外部状态驱动 `visible` 入参。
//  - macOS: 当前是占位实现（与 iOS 相同的视觉 overlay 兜底）。
//    完整 NSFocusRing 系统集成由 issue #9 (Task 8 in epic) 填充——
//    见 `.claude/epics/coredesign-v2-tokens/9.md`。届时 macOS 分支会替换为
//    `NSViewRepresentable` 包装 + `focusRingType = .exterior` + `becomeFirstResponder`
//    同步路径，使 Accessibility Inspector 识别为系统 focus ring。
//
//  调用方两端写法完全一致；`#if` 仅出现在 modifier 内部。
//

import SwiftUI

// MARK: - FocusRingModifier

/// 视觉焦点环 ViewModifier。`visible == false` 时 stroke 透明（`.clear`），
/// 仍走 overlay 路径以避免 layout 抖动 / identity 跳变；overlay 不参与父布局，
/// 因此对外不占空间。
///
/// A visual focus-ring `ViewModifier`. When `visible == false` the stroke uses
/// `.clear`, still routed through the same overlay so SwiftUI sees a stable
/// view identity (no layout jitter). The overlay is non-participating in the
/// parent layout, so the modifier is layout-neutral either way.
struct FocusRingModifier: ViewModifier {
    var visible: Bool
    var color: Color
    var width: CGFloat
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: self.cornerRadius)
                    .stroke(
                        self.visible ? self.color : .clear,
                        lineWidth: self.width
                    )
            )
    }
}

// MARK: - View.focusRing

public extension View {
    /// 给视图添加一个 Primer 风格的焦点环。
    ///
    /// Adds a Primer-aligned focus ring to a view.
    ///
    /// - Parameters:
    ///   - visible: 是否显示焦点环；通常由 `@FocusState` 或外部状态绑定 / Whether
    ///     the ring is shown; typically driven by `@FocusState` or external state.
    ///   - color: 描边色，默认 `.borderFocus` / Stroke color, defaults to `.borderFocus`.
    ///   - width: 描边宽度，默认 `CoreBorderWidth.thick` (2pt) / Stroke width.
    ///   - cornerRadius: 圆角，默认 `CoreRadius.medium` (6pt) / Corner radius.
    /// - Returns: 套上了焦点环 overlay 的视图 / The view wrapped with the focus-ring overlay.
    ///
    /// 调用示例 / Example usage:
    ///
    /// ```swift
    /// @FocusState private var isFocused: Bool
    /// TextField("Email", text: $email)
    ///     .focused($isFocused)
    ///     .focusRing(visible: self.isFocused)
    /// ```
    func focusRing(
        visible: Bool = true,
        color: Color = .borderFocus,
        width: CGFloat = CoreBorderWidth.thick,
        cornerRadius: CGFloat = CoreRadius.medium
    ) -> some View {
        // 双平台分支：当前 iOS / macOS 实现一致；macOS 是占位，等 issue #9 替换。
        // Dual-platform branch: iOS and macOS share the same overlay today;
        // the macOS branch is a placeholder pending issue #9.
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // TODO(issue #9 / Task 8 in epic): replace with NSViewRepresentable +
        // NSFocusRing (`focusRingType = .exterior`) + becomeFirstResponder bridge.
        return self.modifier(
            FocusRingModifier(
                visible: visible,
                color: color,
                width: width,
                cornerRadius: cornerRadius
            )
        )
        #else
        return self.modifier(
            FocusRingModifier(
                visible: visible,
                color: color,
                width: width,
                cornerRadius: cornerRadius
            )
        )
        #endif
    }
}

// MARK: - Preview

#if DEBUG && canImport(UIKit)
private struct FocusRingPreviewHost: View {
    @FocusState private var focusedField: Field?
    @State private var emailText: String = ""
    @State private var nameText: String = ""

    private enum Field: Hashable {
        case email
        case name
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.lg) {
            Text("FocusRingModifier — iOS Preview")
                .font(.headline)

            VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                Text("Email (focused → ring visible)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("you@example.com", text: self.$emailText)
                    .textFieldStyle(.plain)
                    .padding(CoreSpacing.sm)
                    .focused(self.$focusedField, equals: .email)
                    .focusRing(visible: self.focusedField == .email)
            }

            VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                Text("Name (focused → ring visible)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Your name", text: self.$nameText)
                    .textFieldStyle(.plain)
                    .padding(CoreSpacing.sm)
                    .focused(self.$focusedField, equals: .name)
                    .focusRing(visible: self.focusedField == .name)
            }

            VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                Text("visible: false → 透明且不占布局 / transparent, layout-neutral")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Static label")
                    .padding(CoreSpacing.sm)
                    .focusRing(visible: false)
            }

            Spacer()
        }
        .padding(CoreSpacing.lg)
    }
}

#Preview("FocusRingModifier — iOS") {
    FocusRingPreviewHost()
}
#endif
