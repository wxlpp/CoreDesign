//
//  ListRow.swift
//  CoreDesign
//
//  Source of truth: docs/PRIMER_VERSION.md
//

import SwiftUI

// MARK: - ListRow

/// 列表行 / GitHub 风格的列表行容器。
///
/// **使用场景**：issue / PR 列表、章节大纲、设置项、文件 / 资源条目等需要"左侧
/// 装饰 + 中间标题 + 右侧附件"三块布局的列表项。Primer 概念上对应 `ActionList.Item`
/// （桌面端 GitHub UI 中导航 / 设置侧栏的统一行容器）。
///
/// **API 形态**（per epic ADR #15 init 形态约束）：
/// - **三泛型** `ListRow<Leading, Trailing, Label>`，每槽位独立类型；
/// - **Designated init 全标签** `init(leading:trailing:label:)`——三个 `@ViewBuilder`
///   闭包均带显式标签，避免 SwiftUI 多尾随闭包推断歧义；
/// - **Convenience inits 只补缺省槽位**（`where Leading == EmptyView` /
///   `where Trailing == EmptyView` / 双 `EmptyView`），调用方写
///   `ListRow(label: { Text("..." )})` 不必再手填 `EmptyView { }`。**不引入**多个
///   无标签闭包重载（per epic ADR #15）。
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
/// **light / dark 行为**：背景 / hover 背景 / 文字均走 v2-tokens 语义色，
/// 双模式自动切换，组件本体无 `colorScheme` 分支逻辑。
///
/// **Hover token debt**: hover 态使用 `Color.surfaceCanvasSubtle` 而非
/// `Color.hoverBackground`：后者已存在于 `InteractionColors.swift` 但取值是系统
/// fill 未对齐 Primer。本组件直接用 `surfaceCanvasSubtle` 是**取值层取舍**，不是
/// token 缺失代偿。详见 PRD `coredesign-v2-components.md` §Notes hover token debt。
/// 后续 InteractionColors Primer 对齐 epic 后回评。
public struct ListRow<Leading: View, Trailing: View, Label: View>: View {

    // MARK: - Designated init

    /// 创建带 leading / label / trailing 三槽位的列表行。
    ///
    /// 三个 `@ViewBuilder` 闭包均带显式标签——这是 designated init 形态约束
    /// （per epic ADR #15），用于规避 SwiftUI 多尾随闭包推断歧义。
    ///
    /// - Parameters:
    ///   - leading: 左侧装饰位 view builder（icon / Avatar / status dot）。
    ///   - trailing: 右侧附件位 view builder（chevron / Badge / 时间戳）。
    ///   - label: 中间内容主体 view builder（标题 / 标题 + 副标题）。
    public init(
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder label: () -> Label
    ) {
        self.leading = leading()
        self.trailing = trailing()
        self.label = label()
    }

    // MARK: - Body

    public var body: some View {
        HStack(spacing: CoreSpacing.md) {
            self.leading
            self.label
                .frame(maxWidth: .infinity, alignment: .leading)
            self.trailing
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

// MARK: - Convenience inits (only fill missing slots; per ADR #15)

public extension ListRow where Leading == EmptyView {
    /// 无 leading 槽位的便利 init（`Leading == EmptyView`）。
    ///
    /// 仅补齐缺省槽位，不引入无标签闭包重载（per epic ADR #15）。
    ///
    /// - Parameters:
    ///   - trailing: 右侧附件位 view builder。
    ///   - label: 中间内容主体 view builder。
    init(
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder label: () -> Label
    ) {
        self.init(leading: { EmptyView() }, trailing: trailing, label: label)
    }
}

public extension ListRow where Trailing == EmptyView {
    /// 无 trailing 槽位的便利 init（`Trailing == EmptyView`）。
    ///
    /// 仅补齐缺省槽位，不引入无标签闭包重载（per epic ADR #15）。
    ///
    /// - Parameters:
    ///   - leading: 左侧装饰位 view builder。
    ///   - label: 中间内容主体 view builder。
    init(
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder label: () -> Label
    ) {
        self.init(leading: leading, trailing: { EmptyView() }, label: label)
    }
}

public extension ListRow where Leading == EmptyView, Trailing == EmptyView {
    /// 仅 label 的便利 init（`Leading == EmptyView, Trailing == EmptyView`）。
    ///
    /// 仅补齐缺省槽位，不引入无标签闭包重载（per epic ADR #15）。
    ///
    /// - Parameter label: 中间内容主体 view builder。
    init(@ViewBuilder label: () -> Label) {
        self.init(
            leading: { EmptyView() },
            trailing: { EmptyView() },
            label: label
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
                        trailing: {
                            Image(systemName: "chevron.right")
                                .frame(
                                    width: CoreControlMetrics.iconSize(for: .regular),
                                    height: CoreControlMetrics.iconSize(for: .regular)
                                )
                                .foregroundStyle(Color.contentMuted)
                        },
                        label: {
                            VStack(alignment: .leading, spacing: CoreSpacing.xxs) {
                                Text("README.md")
                                    .font(CoreTypography.bodyMediumFont)
                                    .foregroundStyle(Color.contentPrimary)
                                Text("Updated 2 hours ago")
                                    .font(CoreTypography.bodySmallFont)
                                    .foregroundStyle(Color.contentMuted)
                            }
                        }
                    )
                }

                Self.section(title: "no leading (label + trailing)") {
                    ListRow(
                        trailing: {
                            Image(systemName: "chevron.right")
                                .frame(
                                    width: CoreControlMetrics.iconSize(for: .regular),
                                    height: CoreControlMetrics.iconSize(for: .regular)
                                )
                                .foregroundStyle(Color.contentMuted)
                        },
                        label: {
                            Text("Notification settings")
                                .font(CoreTypography.bodyMediumFont)
                                .foregroundStyle(Color.contentPrimary)
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
                                    .font(CoreTypography.bodyMediumFont)
                                    .foregroundStyle(Color.contentPrimary)
                                Text("Member since 2011")
                                    .font(CoreTypography.bodySmallFont)
                                    .foregroundStyle(Color.contentMuted)
                            }
                        }
                    )
                }

                Self.section(title: "label only") {
                    ListRow {
                        Text("All issues")
                            .font(CoreTypography.bodyMediumFont)
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
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            content()
        }
    }
}
