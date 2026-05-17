//
//  MenuButton.swift
//  CoreDesign
//
//  Created by Evan Wang on 2026/3/31.
//

import SwiftUI

// MARK: - MenuIconView

/// 三线 ↔ X 自绘动画图标，progress 0 = 汉堡菜单，1 = 关闭 X
private struct MenuIconView: View, @MainActor Animatable {
    var progress: Double

    var animatableData: Double {
        get { self.progress }
        set { self.progress = newValue }
    }

    var body: some View {
        Canvas { context, canvasSize in
            let centerX = canvasSize.width / 2
            let centerY = canvasSize.height / 2
            let halfLength = canvasSize.width * 0.42
            let lineGap = canvasSize.height * 0.28
            let progressValue = CGFloat(progress)
            let angle = Double.pi / 4 * Double(progressValue)
            let style = StrokeStyle(lineWidth: lineWidth, lineCap: .round)

            func segment(centerX: CGFloat, centerY: CGFloat, angle: Double) -> Path {
                let cosine = CGFloat(cos(angle))
                let sine = CGFloat(sin(angle))
                var path = Path()
                path.move(to: CGPoint(x: centerX - halfLength * cosine, y: centerY - halfLength * sine))
                path.addLine(to: CGPoint(x: centerX + halfLength * cosine, y: centerY + halfLength * sine))
                return path
            }

            context.stroke(
                segment(centerX: centerX, centerY: centerY - lineGap * (1 - progressValue), angle: angle),
                with: .foreground, style: style
            )

            context.opacity = 1 - Double(progressValue)
            context.stroke(
                segment(centerX: centerX, centerY: centerY, angle: 0),
                with: .foreground, style: style
            )
            context.opacity = 1

            context.stroke(
                segment(centerX: centerX, centerY: centerY + lineGap * (1 - progressValue), angle: -angle),
                with: .foreground, style: style
            )
        }
        .frame(width: self.size, height: self.size)
    }

    /// 图标基线尺寸（pt），随 Dynamic Type 缩放。
    ///
    /// 刻意使用 `CoreControlMetrics.iconSize(for: .regular)` (16pt)——而非与外框
    /// `MenuButtonStyleModifier.controlSize` (`.large` = 40pt) 同档的 `.large` (20pt)——
    /// 是为了维持 16/40 ≈ 0.4 的 icon-to-button-height 比例，匹配 SF Symbol 在容器内的
    /// 视觉重量预期（Apple HIG "icon ≈ 容器 40%"）。若改用 `.large` (20pt)，icon 将占
    /// 按钮 50%，视觉过重、破坏与输入栏 trailing 圆形按钮的平衡。
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = CoreControlMetrics.iconSize(for: .regular)

    private var lineWidth: CGFloat {
        self.size / 12
    }
}

// MARK: - MenuButtonStyle

/// 通过测量同环境下 Text 的渲染高度来传递字体尺寸
enum MenuButtonStyle {
    case labeled
    case circular
}

// MARK: - MenuButtonStyleModifier

private struct MenuButtonStyleModifier: ViewModifier {
    let style: MenuButtonStyle

    func body(content: Content) -> some View {
        switch self.style {
        case .labeled:
            content
                .padding(.horizontal, CoreSpacing.sm)
                .frame(minHeight: self.controlSize)
                .contentShape(Capsule())
                .background(
                    Capsule()
                        .fill(.background)
                        .padding(CoreSpacing.xxs)
                        .glassEffect()
                )
                .overlay(
                    Capsule()
                        .strokeBorder(Color.borderSubtle, lineWidth: CoreBorderWidth.hairline)
                )
        case .circular:
            content
                .frame(width: self.controlSize, height: self.controlSize)
                .contentShape(Circle())
                .background(
                    Circle()
                        .fill(.background)
                        .padding(CoreSpacing.xxs)
                        .glassEffect()
                )
                .overlay(
                    Circle()
                        .strokeBorder(Color.borderSubtle, lineWidth: CoreBorderWidth.hairline)
                )
        }
    }

    /// 控件外框尺寸。匹配 SwiftUI `ControlSize.large` 的 Primer 规格
    /// (`CoreControlMetrics.height(for: .large)` = 40pt)，与输入栏 trailing 圆形按钮保持视觉等高。
    private let controlSize: CGFloat = CoreControlMetrics.height(for: .large)
}

// MARK: - MenuButton

struct MenuButton: View {
    @Binding var isExpanded: Bool

    var style: MenuButtonStyle = .labeled

    var body: some View {
        let icon = MenuIconView(progress: self.isExpanded ? 1.0 : 0.0)

        let inner = HStack(spacing: 8) {
            icon
            if self.style == .labeled {
                Text("菜单")
            }
        }

        inner
            .modifier(MenuButtonStyleModifier(style: self.style))
            .foregroundStyle(.white)
            .scaleEffect(self.isLongPressing ? 0.94 : 1.0)
            .onLongPressGesture(minimumDuration: 0.18, maximumDistance: 10, pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.12)) {
                    self.isLongPressing = pressing
                }
                if !pressing && self.longPressTriggered {
                    withAnimation(.spring(duration: 0.3)) {
                        self.isExpanded.toggle()
                    }
                    triggerMenuFeedback()
                    self.longPressTriggered = false
                }
            }, perform: {
                // long-press activated (minimumDuration reached)
                self.longPressTriggered = true
            })
            .onTapGesture {
                withAnimation(.spring(duration: 0.3)) {
                    self.isExpanded.toggle()
                }
                triggerMenuFeedback()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("菜单")
            .accessibilityAddTraits(.isButton)
    }

    @State private var isLongPressing = false
    @State private var longPressTriggered = false
}

/// 触觉反馈助手——`UIImpactFeedbackGenerator` 的 `init(style:)` / `prepare()` /
/// `impactOccurred()` 在 iOS 上都标记为 `@MainActor`（Swift 6 strict concurrency 下
/// 是硬性约束，main 上的 build 之前就因此失败）。`MenuButton` 的两处调用点
/// （`onLongPressGesture` / `onTapGesture` 闭包）本身就是 SwiftUI gesture 回调、
/// 在 MainActor 上跑，故把整个 helper 标 `@MainActor` 是 zero-cost 的精确隔离——
/// 无 Task hop、无 await、调用语义不变。
@MainActor
private func triggerMenuFeedback() {
    #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    #endif
}

#Preview {
    VStack(spacing: 16) {
        MenuButton(isExpanded: .constant(true), style: .labeled)
            .font(.headline)
            .backgroundStyle(.red)

        MenuButton(isExpanded: .constant(false), style: .circular)
            .font(.headline)
            .backgroundStyle(.red)
    }
}
