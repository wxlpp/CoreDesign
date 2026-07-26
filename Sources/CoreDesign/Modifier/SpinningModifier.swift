//
//  SpinningModifier.swift
//  CoreDesign
//

import SwiftUI

// MARK: - SpinningModifier

/// 为任意内容整体叠加一层加载遮罩（吸收 Semi Design `Spin` 能力，Issue #172）。
///
/// `isActive == true` 时：底层内容对交互与 VoiceOver 都不可达
/// （`.allowsHitTesting(false)` + `.accessibilityHidden(true)`），上覆半透明
/// `.regularMaterial` 遮罩 + 居中的 `ProgressIndicator`（`text` 非 nil 时带文案）。
/// `isActive == false` 时内容原样渲染——遮罩视图整体条件渲染，不常驻空遮罩。
///
/// **不直接包装系统 `ProgressView`**——遮罩内的 loading 视觉复用已经处理好
/// tint 的 `ProgressIndicator` 组件（本 Issue 第一部分产出），因此本文件**不落入**
/// `ProgressIndicator.swift` 的 FR-3a 例外范围：本文件若需要强调色，须正常走
/// `.tint`（当前实现无此需求）。
///
/// ```swift
/// ContentView()
///     .spinning(viewModel.isLoading)
///
/// ContentView()
///     .spinning(viewModel.isLoading, text: "Refreshing…")
/// ```
public struct SpinningModifier: ViewModifier {
    public let isActive: Bool
    public let text: LocalizedStringKey?

    public init(isActive: Bool, text: LocalizedStringKey? = nil) {
        self.isActive = isActive
        self.text = text
    }

    public func body(content: Content) -> some View {
        content
            // 遮罩激活时底层内容禁止交互——与下面的 accessibilityHidden 互相独立，
            // 各自覆盖各自的语义面（命中测试 vs. VoiceOver 可达性）。
            .allowsHitTesting(!self.isActive)
            .accessibilityHidden(self.isActive)
            .overlay {
                if self.isActive {
                    ZStack {
                        // `ContainerRelativeShape()` 而非 `Rectangle()`（Phase 3 / #173
                        // 收口项：直角材质遮罩会溢出圆角内容轮廓，如包在 `Card` 外时遮罩
                        // 四角比卡片本身更方）。`ContainerRelativeShape` 在调用方未显式声明
                        // `.containerShape(_:)` 时优雅退化为矩形（与旧行为一致，非破坏性），
                        // 调用方若想让遮罩贴合自身圆角，只需外加
                        // `.containerShape(CoreShape.rounded(CoreRadius.medium))` 一类声明，
                        // 不需要改本组件；`.clipShape` 是调用方侧的另一个可选逃生舱。
                        ContainerRelativeShape()
                            .fill(.regularMaterial)
                        self.indicator
                    }
                    .transition(.opacity)
                }
            }
            .animation(.default, value: self.isActive)
    }

    @ViewBuilder
    private var indicator: some View {
        if let text = self.text {
            ProgressIndicator(text: text)
        } else {
            ProgressIndicator()
        }
    }
}

public extension View {
    /// 为内容整体叠加加载遮罩。见 `SpinningModifier`。
    ///
    /// - Parameters:
    ///   - isActive: 是否显示遮罩。
    ///   - text: 遮罩内 `ProgressIndicator` 的可选文案，默认 `nil`（不带文案）。
    func spinning(_ isActive: Bool, text: LocalizedStringKey? = nil) -> some View {
        self.modifier(SpinningModifier(isActive: isActive, text: text))
    }
}

#Preview("spinning — Light") {
    SpinningModifierPreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("spinning — Dark") {
    SpinningModifierPreviewGallery()
        .preferredColorScheme(.dark)
}

private struct SpinningModifierPreviewGallery: View {
    var body: some View {
        VStack(spacing: CoreSpacing.xl) {
            VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                Text("isActive: false（正常渲染，无遮罩）")
                    .coreFont(.footnote)
                    .foregroundStyle(Color.contentSecondary)
                self.card
                    .spinning(false)
            }

            VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                Text("isActive: true（无文案）")
                    .coreFont(.footnote)
                    .foregroundStyle(Color.contentSecondary)
                self.card
                    .spinning(true)
            }

            VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                Text("isActive: true（带文案）")
                    .coreFont(.footnote)
                    .foregroundStyle(Color.contentSecondary)
                self.card
                    .spinning(true, text: "Refreshing…")
            }
        }
        .padding()
        .background(Color.surfaceCanvas)
    }

    private var card: some View {
        Card {
            VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                Text("卡片标题").coreFont(.headline)
                Text("被 spinning 遮罩覆盖时应保持自身尺寸不变。")
                    .coreFont(.subheadline)
                    .foregroundStyle(Color.contentSecondary)
            }
        }
    }
}
