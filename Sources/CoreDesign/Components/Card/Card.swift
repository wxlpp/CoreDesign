import SwiftUI

// MARK: - CardKind

/// `Card` 的容器观感取值域——**刻意只有两个 case**。
public nonisolated enum CardKind: Sendable, Equatable {
    /// 带描边的内容卡片（默认）——完整 `.surface(.content)`：背景 + 描边 + 圆角。
    case content
    /// 分组容器观感——背景 + 圆角、**无描边**，靠填充色对比定界，与
    /// `InsetGroupedSection` 的卡片外观一致。等价于 #41 之前的 `bordered: false`。
    case grouped

    var surfaceKind: SurfaceKind {
        switch self {
        case .content: .content
        case .grouped: .grouped
        }
    }
}

// MARK: - Card

/// `.surface(.content)` 的**具名封装** + 默认内边距——iOS 分组卡片/内容容器的最薄外壳。
public struct Card<Content: View>: View {
    private let padding: CGFloat
    private let alignment: Alignment
    private let kind: CardKind
    private let elevation: CoreElevation.Level
    private let content: Content

    /// - Parameters:
    ///   - padding: 内容四周内边距，默认 `CoreSpacing.lg`（16pt，对齐 iOS 分组卡片惯例）。
    ///   - alignment: 撑满宽度内的内容对齐，默认 `.leading`。
    ///   - kind: 容器观感，默认 `.content`（背景 + 描边 + 圆角）。`.grouped` 只保留
    ///     背景 + 圆角、**去掉描边**——贴近 iOS 系统分组容器
    ///     （`secondarySystemGroupedBackground` 靠填充色对比定界、无描边）。
    ///   - elevation: 投影档位，默认 `.small`（一层很浅的抬升）。传 `.none` 即退回无投影。
    ///     ⚠️ **本参数背离本仓的 surface 分层规则**（`docs/DESIGN-FOUNDATION.md`
    ///     「层级交给 material + separator」，静置内容不浮起）。这是逐条确认过的
    ///     单点越界，只作用在 `Card` 这一层——`.surface(_:)` 本身不受影响。
    ///     ⚠️ 用 `CoreElevation.Level` 而非 `Bool`：本仓有 Bool 参数纪律
    ///     （`BoolExemptionGuard`），且档位比布尔更能表达「浮多高」。
    ///   - content: 卡片内容。
    public init(
        padding: CGFloat = CoreSpacing.lg,
        alignment: Alignment = .leading,
        kind: CardKind = .content,
        elevation: CoreElevation.Level = .small,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.alignment = alignment
        self.kind = kind
        self.elevation = elevation
        self.content = content()
    }

    public var body: some View {
        self.content
            .padding(self.padding)
            .frame(maxWidth: .infinity, alignment: self.alignment)
            .surface(self.kind.surfaceKind)
            .coreShadow(self.elevation)
    }
}

#Preview("Card — Light") {
    CardPreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("Card — Dark") {
    CardPreviewGallery()
        .preferredColorScheme(.dark)
}

private struct CardPreviewGallery: View {
    var body: some View {
        VStack(spacing: CoreSpacing.lg) {
            Card {
                VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                    Text("Card 标题").coreFont(.headline)
                    Text("卡片浮于画布之上，深浅双模式都与背景拉开。")
                        .coreFont(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Card(padding: CoreSpacing.md) {
                Text("紧凑内边距（md）").coreFont(.subheadline)
            }
            Card(kind: .grouped) {
                Text("无描边（kind: .grouped）——贴近系统分组容器").coreFont(.subheadline)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.surfaceCanvas)
    }
}
