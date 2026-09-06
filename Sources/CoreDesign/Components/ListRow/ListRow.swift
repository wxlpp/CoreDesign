import SwiftUI

// MARK: - ListRow

/// 内容层列表行：无默认玻璃、无默认卡片化、不提供选中态，背景落在 `View.surface(.canvas)`。
public struct ListRow<Leading: View, Trailing: View, Label: View>: View {
    // MARK: - Designated init

    /// 创建带 leading / label / trailing 三槽位的列表行。
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
