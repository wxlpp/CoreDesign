//
//  SurfaceModifier.swift
//  CoreDesign
//

import SwiftUI

// MARK: - SurfaceKind

/// 容器表面语义类别 / Container surface semantic kinds.
///
/// 命名维度统一为"具体容器 / 具体容器变体"（按 PRD G-2 修正后的命名），
/// 不引入裸修饰词（如 `.subtle`、`.muted`）；每个 case 直接对应一种容器角色。
///
/// 每个 kind 通过 `View.surface(_:)` 派生出一组
/// `(background, border, cornerRadius)` 三件套，全部从 token 派生，
/// 调用方无需手写"圆角矩形 fill + overlay stroke"三件套。
public nonisolated enum SurfaceKind: Sendable, Equatable {
    /// Page-level canvas.
    case canvas
    /// 普通内容表面：列表行、卡片、非浮起容器。
    case content
    /// 交互控件表面：按钮、输入框、分段控件。
    case control
    /// 浮于内容之上的表面：toast、浮动工具栏、底部栏。
    case floating
    /// 覆盖层表面，如菜单与 popover。
    case overlay
    /// 兼容别名：更淡的画布。
    case canvasSubtle
    /// 兼容别名：面板容器。
    case panel
    /// 兼容别名：侧栏容器。
    case sidebar
    /// 兼容别名：卡片容器。
    case card
}

// MARK: - SurfaceKind Token Mapping

private extension SurfaceKind {
    /// 该 kind 对应的背景色 token / Background color token for this kind.
    var background: Color {
        switch self {
        case .canvas: .surfaceCanvas
        case .content: .surfaceCard
        case .control: .surfaceInteractive
        case .floating: .surfaceOverlay
        case .overlay: .surfacePanel
        case .canvasSubtle: .surfaceCanvasSubtle
        case .panel: .surfacePanel
        case .sidebar: .surfaceSidebar
        case .card: .surfaceCard
        }
    }

    /// 该 kind 对应的边框色 token / Border color token for this kind.
    var border: Color {
        switch self {
        case .canvas: .borderDefault
        case .content: .borderMuted
        case .control: .borderSubtle
        case .floating: .borderMuted
        case .overlay: .borderDefault
        case .canvasSubtle: .borderMuted
        case .panel: .borderDefault
        case .sidebar: .borderDefault
        case .card: .borderMuted
        }
    }

    /// 该 kind 对应的圆角 token / Corner radius token for this kind.
    var cornerRadius: CGFloat {
        switch self {
        case .canvas: CoreRadius.medium
        case .content: CoreRadius.medium
        case .control: CoreRadius.small
        case .floating: CoreRadius.large
        case .overlay: CoreRadius.medium
        case .canvasSubtle: CoreRadius.medium
        case .panel: CoreRadius.medium
        case .sidebar: CoreRadius.none
        case .card: CoreRadius.medium
        }
    }
}

// MARK: - SurfaceModifier

/// 把 `(background, border, cornerRadius)` 三件套一次性应用到目标视图。
///
/// 实现思路 / Implementation:
/// 1. `background(...)` 用 `RoundedRectangle` 填充对应背景色 token。
/// 2. `overlay(...)` 叠加同形状的 1pt 描边（`CoreBorderWidth.thin`）。
/// 3. `clipShape(...)` 把 content 裁切到圆角内，避免子视图溢出边框。
///
/// > Note: 本 modifier **不叠加 shadow**——shadow 由调用方按需追加
/// > `.coreShadow(_:)`（详见 `CoreElevation`，由 Task 4 提供）。
struct SurfaceModifier: ViewModifier {
    let kind: SurfaceKind

    func body(content: Content) -> some View {
        let shape = CoreShape.rounded(self.kind.cornerRadius)
        // strokeBorder 内描边（路径在形状内部），避免后续 clipShape 把居中描边的外侧一半裁掉
        // 导致视觉上 1pt 变细。strokeBorder + clipShape 组合保证边框完整可见。
        return content
            .background(shape.fill(self.kind.background))
            .overlay(shape.strokeBorder(self.kind.border, lineWidth: CoreBorderWidth.thin))
            .clipShape(shape)
    }
}

// MARK: - View Extension

public extension View {
    /// 将容器表面 token（背景 + 1pt 边框 + 圆角）一次性应用到当前视图。
    /// 一次性施加容器表面 token（背景 + 1pt 描边 + 圆角）。
    ///
    /// 调用示例 / Usage:
    ///
    /// ```swift
    /// VStack { ... }
    ///     .padding(CoreSpacing.md)
    ///     .surface(.card)
    /// ```
    ///
    /// - Parameter kind: 容器语义类别 / Container semantic kind.
    /// - Returns: 已应用 surface 装饰的视图 / The view with surface decoration applied.
    func surface(_ kind: SurfaceKind) -> some View {
        self.modifier(SurfaceModifier(kind: kind))
    }
}

// MARK: - Previews

#Preview("Surface — Light") {
    SurfacePreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("Surface — Dark") {
    SurfacePreviewGallery()
        .preferredColorScheme(.dark)
}

private struct SurfacePreviewGallery: View {
    private let samples: [(label: String, kind: SurfaceKind)] = [
        ("canvas", .canvas),
        ("content", .content),
        ("control", .control),
        ("floating", .floating),
        ("overlay", .overlay),
        ("canvasSubtle", .canvasSubtle),
        ("panel", .panel),
        ("sidebar", .sidebar),
        ("card", .card),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(self.samples, id: \.label) { sample in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(".\(sample.label)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                        Text("SurfaceKind.\(sample.label)")
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .surface(sample.kind)
                    }
                }
            }
            .padding(20)
        }
        .background(Color.surfaceCanvas)
    }
}
