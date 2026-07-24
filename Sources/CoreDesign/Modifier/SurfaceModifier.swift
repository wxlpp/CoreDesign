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
    /// 页面级画布。
    case canvas
    /// 内容表面：卡片、分组容器——**浮于画布之上**（背景取 `surfaceRaised`）。
    /// 注意列表行**不**用本 kind：`ListRow` 刻意用 `.surface(.canvas)` 贴画布（见本文件下方注释），
    /// 照旧文案「列表行」接到 `.content` 会得到浮起卡片、违背 #125 的裁决。
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
        case .canvas: .clear
        case .content: .borderMuted
        case .control: .borderSubtle
        case .floating: .borderMuted
        case .overlay: .borderDefault
        case .canvasSubtle: .borderMuted
        case .panel: .borderDefault
        case .sidebar: .clear
        case .card: .borderMuted
        }
    }

    /// 该 kind 对应的圆角 token / Corner radius token for this kind.
    var cornerRadius: CGFloat {
        switch self {
        case .canvas: CoreRadius.none
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
    var bordered: Bool = true

    func body(content: Content) -> some View {
        let shape = CoreShape.rounded(self.kind.cornerRadius)
        // `bordered: false` 时描边取 `.clear`——走同一条 overlay 路径（保持视图标识稳定），
        // `.clear` 不产生任何像素，效果等同去描边。用于贴近 iOS 系统分组容器（无描边、
        // 靠填充色对比定界）。
        let borderColor = self.bordered ? self.kind.border : Color.clear
        // strokeBorder 内描边（路径在形状内部），避免后续 clipShape 把居中描边的外侧一半裁掉
        // 导致视觉上 1pt 变细。strokeBorder + clipShape 组合保证边框完整可见。
        //
        // Task #125 视觉终审发现：`.canvas` / `.sidebar` 这类**页面级容器**此前也带
        // `borderDefault` 描边 + 圆角裁剪，于是 `ListRow`（用 `.surface(.canvas)`）
        // 每一行都被渲染成一个独立的圆角描边盒子——深色模式下行背景与页面背景同色，
        // 看起来就是一摞空的描边框，与 `ListRow` 文档承诺的「无默认卡片化」直接矛盾。
        //
        // 页面级容器本就不该有边框和圆角（`.sidebar` 的 `CoreRadius.none` 早已体现
        // 这个判断，只是 `.canvas` 没跟上）。二者的 border 现取 `.clear`、`.canvas`
        // 的圆角取 `.none`。仍走同一条 overlay 路径而不是加分支——保持视图标识稳定，
        // 且 `.clear` 描边不产生任何像素。
        return content
            .background(shape.fill(self.kind.background))
            .overlay(shape.strokeBorder(borderColor, lineWidth: CoreBorderWidth.thin))
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
    /// - Parameters:
    ///   - kind: 容器语义类别 / Container semantic kind.
    ///   - bordered: 是否画描边，默认 `true`。置 `false` 只保留背景 + 圆角、去描边——
    ///     贴近 iOS 系统分组容器（无描边、靠填充色对比定界）。
    /// - Returns: 已应用 surface 装饰的视图 / The view with surface decoration applied.
    func surface(_ kind: SurfaceKind, bordered: Bool = true) -> some View {
        self.modifier(SurfaceModifier(kind: kind, bordered: bordered))
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
