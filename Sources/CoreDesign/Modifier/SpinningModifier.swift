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
/// `spinning` 的**呈现形态**。
///
/// 判定依据：`docs/component-contract.md` §2 形态 **D2（配置枚举）**。⚠️ **D1 事实上不可用**：
/// 本类型是 `ViewModifier` 而非 `View`，没有可挂 `@ViewBuilder` 外观槽的 `init` 参数位
///（`body(content:)` 的 `content` 是被修饰的内容，属**内容槽**，公约明文排除）。
/// ⇒ D 的两个子形态里只剩 D2。
///
/// ⚠️ 候选 1「骨架屏占位替换」**已被兄弟 `Skeleton` 正当排除**（其 `notes` 自述是占位/真实
/// 内容切换容器），故本枚举只承载候选 2 / 3 + 现状。
public enum SpinningPresentation: Sendable, Equatable {
    /// 默认：材质遮罩铺满内容 + 居中指示器（现状形态）。
    case overlay
    /// 容器顶边的细进度条，不铺遮罩。
    /// 业界来源：NProgress / YouTube 顶条 / GitHub Turbo。
    case topBar
    /// 原位行内指示器，不铺遮罩。
    /// 业界来源：Ant Design Spin 的非包裹用法 / MUI CircularProgress。
    case inline
}

public struct SpinningModifier: ViewModifier {
    public let isActive: Bool
    public let text: LocalizedStringKey?
    public let presentation: SpinningPresentation

    /// - Parameters:
    ///   - isActive: 是否显示。
    ///   - text: 指示器的可选文案。⚠️ `.topBar` 形态下**不生效** —— 顶条没有文案位；
    ///     存储层仍原样保留，切回其余形态时不丢配置（与 `Steps` / `Timeline` /
    ///     `AvatarGroup` 同一处置）。
    ///   - presentation: 呈现形态，默认 `.overlay`（现状形态）⇒ **现有调用方零影响**。
    public init(
        isActive: Bool,
        text: LocalizedStringKey? = nil,
        presentation: SpinningPresentation = .overlay
    ) {
        self.isActive = isActive
        self.text = text
        self.presentation = presentation
    }

    public func body(content: Content) -> some View {
        switch self.presentation {
        case .overlay: self.overlayBody(content)
        case .topBar: self.topBarBody(content)
        case .inline: self.inlineBody(content)
        }
    }

    /// `.topBar`：顶边细进度条，**不铺遮罩**。
    ///
    /// ⚠️ **不禁用底层交互、不隐藏无障碍** —— 这正是它与 `.overlay` 的语义差别：顶条表达
    /// 「后台正在加载」，内容仍可用；遮罩表达「此刻不可操作」。若照抄 `.overlay` 的
    /// `allowsHitTesting(false)`，就把一个非阻塞形态做成了阻塞形态。
    private func topBarBody(_ content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if self.isActive {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .transition(.opacity)
                }
            }
            .animation(.default, value: self.isActive)
    }

    /// `.inline`：原位行内指示器，**不铺遮罩**。
    ///
    /// ⚠️ 同 `.topBar`：非阻塞形态，不禁用交互。
    private func inlineBody(_ content: Content) -> some View {
        HStack(spacing: CoreSpacing.sm) {
            content
            if self.isActive {
                self.indicator
                    .transition(.opacity)
            }
        }
        .animation(.default, value: self.isActive)
    }

    /// `.overlay`：材质遮罩铺满 + 居中指示器（现状形态）。
    private func overlayBody(_ content: Content) -> some View {
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
    ///   - text: 指示器的可选文案，默认 `nil`（不带文案）。⚠️ `.topBar` 形态下不生效。
    ///   - presentation: 呈现形态，默认 `.overlay`（现状形态）⇒ **现有调用方零影响**。
    ///     ⚠️ `.topBar` / `.inline` 是**非阻塞**形态：不禁用底层交互、不隐藏无障碍，
    ///     语义是「后台正在加载、内容仍可用」，与 `.overlay` 的「此刻不可操作」不同。
    func spinning(
        _ isActive: Bool,
        text: LocalizedStringKey? = nil,
        presentation: SpinningPresentation = .overlay
    ) -> some View {
        self.modifier(SpinningModifier(isActive: isActive, text: text, presentation: presentation))
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
