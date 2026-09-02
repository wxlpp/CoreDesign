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
    ///
    /// ⚠️ **浅色下叠在白色表面（`.content` / `.card` / `.grouped`）之上时，本档
    /// 无法只靠底色浮起来**——浅色的 `.content` 已是纯白，**不存在比它更亮的
    /// 不透明色**；iOS 浅色靠**阴影**表达抬起，而本 kind 只提供一个背景色。
    ///
    /// ⇒ 那种场景**必须**二选一：追加 `.coreShadow(_:)`，或改用 `floatingGlass`
    /// （材质浮层，本库既有的正确观感参照）。叠在 `.canvas` 上则不需要——
    /// 白卡浮于灰画布本身就是 iOS 的系统惯例。
    ///
    /// 深色下本档走半透明填充、靠叠加提亮表达抬起，两种底色上都成立。
    /// 取值与实测详见 `Color.surfaceOverlay` 的文档（Issue #225）。
    case floating
    /// 覆盖层表面，如菜单与 popover。
    case overlay
    /// 分组容器表面：贴近 iOS 系统分组容器——**背景 + 圆角、无描边**，靠填充色对比定界。
    /// 背景与 `.content` 同取 `surfaceRaised`（`secondarySystemGroupedBackground`），
    /// 因此在深浅双模式下都与 `Color.surfaceCanvas` 拉开、不会塌缩隐形（Issue #140）。
    ///
    /// ⚠️ **它是一等容器角色，不是 `.content` 的减法变体**（#41 裁决 1）：iOS 自己把这种
    /// 形态叫 `.insetGrouped`，本仓也已有同名组件 `InsetGroupedSection` 在用它。
    /// 取这个名字而不是 `.contentPlain`，依据是「该 case 是否**独立成立为一种容器角色**」
    /// ——`.contentPlain` 离开 `.content` 就没法定义，是变体名不是角色名。
    ///
    /// ⚠️ **只建这一个组合，不铺满 9×2 的积空间**：`bordered` 曾与全部 9 个 kind 正交，
    /// 但实测 7 处产品调用点 100% 落在 `.content` 上（见 `docs/component-contract.md` 附录 A.3
    /// 与 #41 spec 的调用点表）。按用到的点建模，不按可能的组合建模。
    case grouped
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
        case .grouped: .surfaceCard
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
        case .grouped: .clear
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
        case .grouped: CoreRadius.medium
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
        //
        // ⚠️ **#41 裁决 1：`bordered: Bool` 已删除**。原先「`bordered: false` 时描边取
        // `.clear`」这条分支，现在由 `SurfaceKind.grouped`（border 直接就是 `.clear`）
        // 表达——把压扁的取值域还原成语义类型，见公约第 3 节替代路径 3.1。
        // 描边一律走同一条 overlay 路径（保持视图标识稳定），`.clear` 不产生任何像素。
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
            .overlay(shape.strokeBorder(self.kind.border, lineWidth: CoreBorderWidth.thin))
            .clipShape(shape)
    }
}

// MARK: - View Extension

public extension View {
    /// 一次性施加容器表面 token（背景 + 1pt 描边 + 圆角）。
    ///
    /// 调用示例 / Usage:
    ///
    /// ```swift
    /// VStack { ... }
    ///     .padding(CoreSpacing.md)
    ///     .surface(.card)
    ///
    /// // 无描边的分组容器观感（原 `.surface(.content, bordered: false)`）
    /// VStack { ... }
    ///     .surface(.grouped)
    /// ```
    ///
    /// ⚠️ **`bordered: Bool` 已于 #41 删除**：它不是二值旋钮，而是在 `.content` 的两种
    /// 容器观感之间做选择（实测 7 处产品调用点 100% 传 `false` 且 100% 落在 `.content`
    /// 上）——正是公约第 3 节替代路径 3.1「把压扁的取值域还原成语义类型」的教科书形态。
    /// 迁移：`.surface(.content, bordered: false)` → `.surface(.grouped)`；
    /// `.surface(kind, bordered: true)` → `.surface(kind)`。
    ///
    /// ⚠️ **`.floating` 在浅色 + 白底上的已知限制**：浅色下 `.content` 已是纯白，
    /// 不存在更亮的不透明色，故 `.surface(.floating)` 叠在白色表面上**只靠底色
    /// 浮不起来**（叠在 `.canvas` 灰画布上则成立）。那种场景须追加
    /// `.coreShadow(_:)` 或改用 `floatingGlass`。详见 `SurfaceKind.floating`。
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

/// 把三个**半透明**档位分别叠在两种底层档位之上，并排对照。
///
/// ⚠️ **为什么必须新增这个预览**：`SurfacePreviewGallery` 只把每档平铺在**单一**
/// `surfaceCanvas` 底上，产不出「`.floating` 叠 `.content`」这类合成图。
/// 而 #220 把 `.floating` / `.overlay` / `.panel` 改指填充族后，三档的 RGB 几乎相同
/// （`#787880` / `#767680` / `#747480`）、**区分几乎全靠 α**——
/// `SurfaceContrastTests` 的逐位判据对它们会**平凡通过**，
/// 「叠上去到底浮没浮起来」只有这张图能回答。
#Preview("Surface 合成对照 — Light") {
    SurfaceCompositePreview().preferredColorScheme(.light)
}

#Preview("Surface 合成对照 — Dark") {
    SurfaceCompositePreview().preferredColorScheme(.dark)
}

private struct SurfaceCompositePreview: View {
    private let overlayKinds: [(String, SurfaceKind)] = [
        ("floating", .floating),
        ("overlay", .overlay),
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
