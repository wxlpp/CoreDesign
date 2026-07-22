//
//  FocusRingModifier.swift
//  CoreDesign
//
//  本文件提供跨平台 `View.focusRing(visible:color:width:cornerRadius:)` modifier。
//
//  - iOS / iPadOS / visionOS: 完整实现 —— `.overlay(圆角矩形.stroke())`
//    纯视觉焦点环，由 SwiftUI `@FocusState` 等外部状态驱动 `visible` 入参。
//  - macOS: 同样走 SwiftUI overlay 兜底（与 iOS 一致）。**这是显式评估后的
//    最终决策**，不是占位。
//
//  ## 为什么不走 NSFocusRing 系统集成
//
//  曾评估把 macOS 分支换成 `NSViewRepresentable` 包装 `NSView` 子类
//  （`focusRingType = .exterior`、`drawFocusRingMask()` 渲染圆角 mask），
//  通过 `window.makeFirstResponder(nsView)` 同步 SwiftUI 的 `visible` 状态，
//  让 Accessibility Inspector 把焦点环识别为系统 focus indicator。
//
//  实施时编译 + Swift 6 严格并发都干净，但存在一个**架构正确性问题**：
//  `makeFirstResponder(nsView)` 会从真实 focused 控件（TextField / NSTextView 等）
//  **抢走** first responder，破坏键盘输入；并且会和 SwiftUI 的 `@FocusState`
//  形成"焦点拉锯"——SwiftUI 把焦点设到 field，本 modifier 又立刻挪到 wrapper view。
//
//  这不是 Swift 6 并发问题，而是 NSFocusRing 这条 AppKit 路径与 SwiftUI
//  焦点模型的根本不兼容（first-responder 是单点资源）。绕开此问题需要以下
//  三条路径之一：
//
//  1. **本仓采用** —— macOS 也走纯 overlay。代价：Accessibility Inspector
//     不识别为 system focus ring，但视觉仍在；已记录为已知限制。
//  2. 用 AppKit 的 focus-ring 绘制 API（`NSGraphicsContext` + draw routine）
//     在不夺取 first responder 的情况下手绘系统样式 —— 工作量大，且仍要
//     处理 secondary key view 的语义。
//  3. 限制本桥的使用范围到非交互 view（不会被 first responder 的元素），
//     用强约束方式规避问题 —— 调用面被严重收窄，实用性差。
//
//  调用方两端写法完全一致——`focusRing(...)` 在 iOS / macOS 共享同一 SwiftUI
//  overlay 实现，无需调用方写 `#if`。本文件内的条件编译只保留在 `#Preview`
//  上（`#if canImport(UIKit)` 用来区分 SwiftUI 平台 SDK），不涉及 modifier 主体。
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
                // 用 `CoreShape.rounded` 统一出口——裸构造圆角矩形未指定 `style` 时
                // 隐式取 `.circular`，与全仓其余圆角元素的 `.continuous`（squircle）
                // 不一致，在方形转角附近与宿主视图的圆角描边会有肉眼可见的错位。
                CoreShape.rounded(self.cornerRadius)
                    .stroke(
                        self.visible ? self.color : .clear,
                        lineWidth: self.width
                    )
            )
    }
}

// MARK: - View.focusRing

public extension View {
    /// 给视图添加一个焦点环。
    ///
    /// 为视图添加聚焦环。
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
        // 双平台共享同一 SwiftUI overlay 实现。macOS 不尝试 NSFocusRing 系统
        // 集成（详见文件顶部 doc-comment 的评估结论）：NSFocusRing 的
        // first-responder 需求与 SwiftUI `@FocusState` 焦点模型不兼容，
        // 故 macOS 也走纯 overlay。
        return self.modifier(
            FocusRingModifier(
                visible: visible,
                color: color,
                width: width,
                cornerRadius: cornerRadius
            )
        )
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
