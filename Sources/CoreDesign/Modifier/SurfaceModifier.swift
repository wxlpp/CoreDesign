import SwiftUI

// MARK: - SurfaceKind

/// 容器表面语义类别 / Container surface semantic kinds.
public nonisolated enum SurfaceKind: Sendable, Equatable {
    /// 页面级画布。
    case canvas
    /// 内容表面：卡片、分组容器——**浮于画布之上**（背景取 `surfaceRaised`）。
    /// 列表行不用本 kind，`ListRow` 走 `.surface(.canvas)` 贴画布。
    case content
    /// 交互控件表面：按钮、输入框、分段控件。
    case control
    /// 浮于内容之上的表面：toast、浮动工具栏、底部栏。
    case floating
    /// 分组容器表面：背景 + 圆角、无描边，靠填充色对比定界，背景与 `.content` 同取 `surfaceRaised`。
    case grouped
    /// 兼容别名：更淡的画布。
    case canvasSubtle
    /// 贴底的静态面板容器 —— **不做菜单 / popover**（iOS α ≈ .078 / .180，无模糊，
    /// 叠在文字上会 ghosting）。菜单 / popover **不在 `SurfaceKind` 射程**，走系统
    /// `Menu` / `.popover`。取代已删除的 `.overlay`，逐条见 `#238`。
    case panel
    /// 兼容别名：侧栏容器。
    case sidebar
    /// 兼容别名：卡片容器。
    case card
}

// MARK: - SurfaceKind Token Mapping

// 有意是 internal 而不是 private：`SurfaceKindAlphaContractGuard` 要按 kind 取色（#345）。
// 改回 private 会让那条判据编译不过，而它守的是「映射层某一行被改成 .clear / 半透明」——
// token 层的判据（#342）对此假绿。
extension SurfaceKind {
    var background: Color {
        switch self {
        case .canvas: .surfaceCanvas
        case .content: .surfaceCard
        case .control: .surfaceInteractive
        case .floating: .surfaceOverlay
        case .grouped: .surfaceCard
        case .canvasSubtle: .surfaceCanvasSubtle
        case .panel: .surfacePanel
        case .sidebar: .surfaceSidebar
        case .card: .surfaceCard
        }
    }

    var border: Color {
        switch self {
        case .canvas: .clear
        case .content: .borderMuted
        case .control: .borderSubtle
        case .floating: .borderMuted
        case .grouped: .clear
        case .canvasSubtle: .borderMuted
        case .panel: .borderDefault
        case .sidebar: .clear
        case .card: .borderMuted
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .canvas: CoreRadius.none
        case .content: CoreRadius.medium
        case .control: CoreRadius.small
        case .floating: CoreRadius.large
        case .grouped: CoreRadius.medium
        case .canvasSubtle: CoreRadius.medium
        case .panel: CoreRadius.medium
        case .sidebar: CoreRadius.none
        case .card: CoreRadius.medium
        }
    }
}

// MARK: - SurfaceModifier

struct SurfaceModifier: ViewModifier {
    let kind: SurfaceKind

    func body(content: Content) -> some View {
        let shape = CoreShape.rounded(self.kind.cornerRadius)
        return content
            .background(shape.fill(self.kind.background))
            .overlay(shape.strokeBorder(self.kind.border, lineWidth: CoreBorderWidth.thin))
            .clipShape(shape)
    }
}

// MARK: - View Extension

public extension View {
    /// 一次性施加容器表面 token（背景 + 1pt 描边 + 圆角）。
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
        ("grouped", .grouped),
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

// MARK: - 半透明档位的合成对照（Issue #225）

#Preview("Surface 合成对照 — Light") {
    SurfaceCompositePreview().preferredColorScheme(.light)
}

#Preview("Surface 合成对照 — Dark") {
    SurfaceCompositePreview().preferredColorScheme(.dark)
}

private struct SurfaceCompositePreview: View {
    private let overlayKinds: [(String, SurfaceKind)] = [
        ("floating", .floating),
        ("panel", .panel),
    ]
    private let baseKinds: [(String, SurfaceKind)] = [
        ("canvas", .canvas),
        ("content", .content),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CoreSpacing.lg) {
                ForEach(self.baseKinds, id: \.0) { baseName, baseKind in
                    VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                        Text("底层 = .\(baseName)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)

                        VStack(spacing: CoreSpacing.md) {
                            ForEach(self.overlayKinds, id: \.0) { name, kind in
                                Text(".\(name) 叠在 .\(baseName) 上")
                                    .font(.footnote)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(CoreSpacing.md)
                                    .surface(kind)
                            }
                        }
                        .padding(CoreSpacing.md)
                        .surface(baseKind)
                    }
                }
            }
            .padding(CoreSpacing.lg)
        }
        .background(Color.surfaceCanvas)
    }
}
