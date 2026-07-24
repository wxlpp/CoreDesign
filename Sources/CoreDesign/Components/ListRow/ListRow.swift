//
//  ListRow.swift
//  CoreDesign
//

import SwiftUI

// MARK: - ListRow

/// 内容层组件。保持安静、易扫视、稳定：**无默认玻璃、无默认卡片化**。hover 态用
/// 克制的填充色（`Color.surfaceCanvasSubtle`），默认背景落在 `View.surface(.canvas)` 上。
/// **不提供选中态**——需要的话由调用方在外层自行组合。
///
/// **材质层**: 内容. **表面角色**: 画布.
///
/// **使用场景**：issue / PR 列表、章节大纲、文件 / 资源条目等需要"左侧装饰 +
/// 中间标题 + 右侧附件"三块布局的列表项（桌面端 GitHub UI 中导航 / 侧栏的统一行容器）。
///
/// > 想要 **iOS 设置页观感**（圆角色块图标 + 分组卡片 + 自动分隔线 inset）请用
/// > `SettingsRow` + `InsetGroupedSection`,而非本组件——ListRow 面向内容 / 桌面列表,
/// > 默认贴画布、无卡片化。
///
/// **API 形态**：
/// - **三泛型** `ListRow<Leading, Trailing, Label>`，每槽位独立类型；
/// - **Designated init 全标签** `init(leading:label:trailing:)`——三个 `@ViewBuilder`
///   闭包均带显式标签，避免 SwiftUI 多尾随闭包推断歧义；
/// - **Convenience inits 只补缺省槽位**（`where Leading == EmptyView` /
///   `where Trailing == EmptyView` / 双 `EmptyView`），调用方写
///   `ListRow(label: { Text("..." )})` 不必再手填 `EmptyView()`。**不引入**多个
///   无标签闭包重载。
///
/// **关键参数语义**：
/// - `leading` —— 左侧装饰位（icon / Avatar / status dot），可省略；
/// - `label` —— 中间内容主体，调用方自由组合（譬如 `VStack` 标题 + 副标题）；
/// - `trailing` —— 右侧附件位（chevron / Badge / 时间戳），可省略。
///
/// **视觉规格**：
/// - 默认背景 `View.surface(.canvas)`；hover 态背景 `Color.surfaceCanvasSubtle`；
/// - hover 通过 SwiftUI `.onHover(perform:)` 自管 `@State`（SwiftUI 无原生 hover
///   state binding）；
/// - leading ↔ label / label ↔ trailing 间距 `CoreSpacing.md`；
/// - 高度 `frame(minHeight: CoreControlMetrics.height(for: .regular))`——不固定
///   height，让多行 label 自然撑开（per `CoreControlMetrics` doc-comment 推荐）。
///
/// **light / dark 行为**：背景 / hover 背景 / 文字均走语义色 token，
/// 双模式自动切换，组件本体无 `colorScheme` 分支逻辑。
///
/// **hover 取值的取舍**：hover 态用 `Color.surfaceCanvasSubtle` 而非
/// `Color.hoverBackground`。后者虽已存在于 `InteractionColors.swift`，但它是系统
/// fill 色，语义上是「叠加在内容之上的填充」，与列表行需要的「整行换一层表面色」
/// 不是一回事。本库当前没有专门的 hover fill token，故直接借用表面色——这是
/// **取值层的有意取舍**，不是 token 缺失的代偿。若将来引入专门的 hover token，
/// 可回评此处。
public struct ListRow<Leading: View, Trailing: View, Label: View>: View {

    // MARK: - Designated init

    /// 创建带 leading / label / trailing 三槽位的列表行。
    ///
    /// 三个 `@ViewBuilder` 闭包均带显式标签——这是 designated init 形态约束，
    /// 用于规避 SwiftUI 多尾随闭包推断歧义。
    ///
    /// - Parameters:
    ///   - leading: 左侧装饰位 view builder（icon / Avatar / status dot）。
    ///   - label: 中间内容主体 view builder（标题 / 标题 + 副标题）。
    ///   - trailing: 右侧附件位 view builder（chevron / Badge / 时间戳）。
    public init(
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder label: () -> Label,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.leading = leading()
        self.trailing = trailing()
        self.label = label()
    }

    // MARK: - Body

    public var body: some View {
        HStack(spacing: CoreSpacing.none) {
            if Leading.self != EmptyView.self {
                self.leading
                Spacer().frame(width: CoreSpacing.md)
            }
            self.label
                .frame(maxWidth: .infinity, alignment: .leading)
            if Trailing.self != EmptyView.self {
                Spacer().frame(width: CoreSpacing.md)
                self.trailing
            }
        }
        .padding(.horizontal, CoreControlMetrics.horizontalPadding(for: .regular))
        .padding(.vertical, CoreControlMetrics.verticalPadding(for: .regular))
        .frame(minHeight: CoreControlMetrics.height(for: .regular))
        .contentShape(Rectangle())
        .background {
            if self.isHovered {
                Color.surfaceCanvasSubtle
            }
        }
        .surface(.canvas)
        .onHover { hovering in
            self.isHovered = hovering
        }
    }

    // MARK: - Storage

    private let leading: Leading
    private let trailing: Trailing
    private let label: Label

    @State private var isHovered: Bool = false
}

// MARK: - Convenience inits (only fill missing slots)

public extension ListRow where Leading == EmptyView {
    /// 无 leading 槽位的便利 init（`Leading == EmptyView`）。
    ///
    /// 仅补齐缺省槽位，不引入无标签闭包重载。
    ///
    /// - Parameters:
    ///   - label: 中间内容主体 view builder。
    ///   - trailing: 右侧附件位 view builder。
    init(
        @ViewBuilder label: () -> Label,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.init(leading: { EmptyView() }, label: label, trailing: trailing)
    }
}

public extension ListRow where Trailing == EmptyView {
    /// 无 trailing 槽位的便利 init（`Trailing == EmptyView`）。
    ///
    /// 仅补齐缺省槽位，不引入无标签闭包重载。
    ///
    /// - Parameters:
    ///   - leading: 左侧装饰位 view builder。
    ///   - label: 中间内容主体 view builder。
    init(
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder label: () -> Label
    ) {
        self.init(leading: leading, label: label, trailing: { EmptyView() })
    }
}

public extension ListRow where Leading == EmptyView, Trailing == EmptyView {
    /// 仅 label 的便利 init（`Leading == EmptyView, Trailing == EmptyView`）。
    ///
    /// 仅补齐缺省槽位，不引入无标签闭包重载。
    ///
    /// - Parameter label: 中间内容主体 view builder。
    init(@ViewBuilder label: () -> Label) {
        self.init(
            leading: { EmptyView() },
            label: label,
            trailing: { EmptyView() }
        )
    }
}

// MARK: - Previews

#Preview("ListRow — Light") {
    ListRowPreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("ListRow — Dark") {
    ListRowPreviewGallery()
        .preferredColorScheme(.dark)
}

private struct ListRowPreviewGallery: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CoreSpacing.lg) {
                Self.section(title: "full (leading + label + trailing)") {
                    ListRow(
                        leading: {
                            Image(systemName: "doc.text")
                                .frame(
                                    width: CoreControlMetrics.iconSize(for: .regular),
                                    height: CoreControlMetrics.iconSize(for: .regular)
                                )
                                .foregroundStyle(Color.contentMuted)
                        },
                        label: {
                            VStack(alignment: .leading, spacing: CoreSpacing.xxs) {
                                Text("README.md")
                                    .coreFont(.callout)
                                    .foregroundStyle(Color.contentPrimary)
                                Text("Updated 2 hours ago")
                                    .coreFont(.footnote)
                                    .foregroundStyle(Color.contentMuted)
                            }
                        },
                        trailing: {
                            Image(systemName: "chevron.forward")
                                .frame(
                                    width: CoreControlMetrics.iconSize(for: .regular),
                                    height: CoreControlMetrics.iconSize(for: .regular)
                                )
                                .foregroundStyle(Color.contentMuted)
                        }
                    )
                }

                Self.section(title: "no leading (label + trailing)") {
                    ListRow(
                        label: {
                            Text("Notification settings")
                                .coreFont(.callout)
                                .foregroundStyle(Color.contentPrimary)
                        },
                        trailing: {
                            Image(systemName: "chevron.forward")
                                .frame(
                                    width: CoreControlMetrics.iconSize(for: .regular),
                                    height: CoreControlMetrics.iconSize(for: .regular)
                                )
                                .foregroundStyle(Color.contentMuted)
                        }
                    )
                }

                Self.section(title: "no trailing (leading + label)") {
                    ListRow(
                        leading: {
                            Image(systemName: "person.crop.circle")
                                .frame(
                                    width: CoreControlMetrics.iconSize(for: .regular),
                                    height: CoreControlMetrics.iconSize(for: .regular)
                                )
                                .foregroundStyle(Color.contentMuted)
                        },
                        label: {
                            VStack(alignment: .leading, spacing: CoreSpacing.xxs) {
                                Text("octocat")
                                    .coreFont(.callout)
                                    .foregroundStyle(Color.contentPrimary)
                                Text("Member since 2011")
                                    .coreFont(.footnote)
                                    .foregroundStyle(Color.contentMuted)
                            }
                        }
                    )
                }

                Self.section(title: "label only") {
                    ListRow {
                        Text("All issues")
                            .coreFont(.callout)
                            .foregroundStyle(Color.contentPrimary)
                    }
                }
            }
            .padding(CoreSpacing.lg)
        }
        .background(Color.surfaceCanvas)
    }

    @ViewBuilder
    private static func section<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: CoreSpacing.xs) {
            Text(title)
                .coreFont(.captionMono)
                .foregroundStyle(.secondary)
            content()
        }
    }
}
