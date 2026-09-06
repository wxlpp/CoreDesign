import SwiftUI

// MARK: - AvatarGroupLayout

/// `AvatarGroup` 的**排布形态**——与 `avatars:` 槽**正交**：本枚举决定「这组头像怎么排」，
/// `avatars:` 提供「排什么」。
public enum AvatarGroupLayout: Sendable, Equatable {
    /// 默认：头像按 `controlSize` 递增的负 offset 交叠（现状形态）。
    case overlapped
    /// 并排不重叠 + 溢出计数。
    /// 业界来源：Google Docs 协作者栏 / Microsoft Teams 成员条。
    case spaced
    /// 网格平铺。
    /// 业界来源：Slack Huddle 参与者网格 / Google Meet 头像平铺 / Discord 语音频道头像平铺。
    case grid
    /// 纯计数徽标：N 个头像塌成 1 个计数；本形态不渲染任何头像，`max` 不生效。
    case countOnly
}

// MARK: - AvatarGroup

/// **材质层**: 内容. **表面角色**: 内容.
public struct AvatarGroup<Avatars: View>: View {
    let max: Int
    let layout: AvatarGroupLayout
    @ViewBuilder let avatars: () -> Avatars

    /// - Parameters:
    ///   - max: 最多显示几个头像，超出部分折成 `+N`。⚠️ `.countOnly` 形态下不生效。
    ///   - layout: 排布形态，默认 `.overlapped`（现状形态）⇒ **现有调用方零影响**。
    ///   - avatars: 头像内容槽。⚠️ 这是**内容槽**不是外观槽（见 `AvatarGroupLayout` 说明）。
    public init(
        max: Int = 3,
        layout: AvatarGroupLayout = .overlapped,
        @ViewBuilder avatars: @escaping () -> Avatars
    ) {
        self.max = Swift.max(0, max)
        self.layout = layout
        self.avatars = avatars
    }

    @Environment(\.controlSize) private var controlSize

    private var overlapOffset: CGFloat {
        switch self.controlSize {
        case .mini, .small: return -6
        case .regular: return -8
        case .large, .extraLarge: return -10
        @unknown default: return -8
        }
    }

    public var body: some View {
        Group(subviews: self.avatars()) { subviews in
            let visible = subviews.prefix(self.max)
            let overflow = subviews.count - self.max

            switch self.layout {
            case .overlapped, .spaced:
                self.linearRow(visible: visible, overflow: overflow)
            case .grid:
                self.gridBody(visible: visible, overflow: overflow)
            case .countOnly:
                self.countBadge(total: subviews.count)
            }
        }
    }

    @ViewBuilder
    private func linearRow(
        visible: SubviewsCollection.SubSequence, overflow: Int
    ) -> some View {
        HStack(spacing: self.layout == .overlapped ? self.overlapOffset : CoreSpacing.xxs) {
            ForEach(Array(zip(visible.indices, visible)), id: \.0) { _, subview in
                self.styledAvatar(subview)
            }
            if overflow > 0 {
                self.overflowBadge(overflow)
            }
        }
    }

    @ViewBuilder
    private func gridBody(
        visible: SubviewsCollection.SubSequence, overflow: Int
    ) -> some View {
        let columns = Swift.max(1, Swift.min(self.max, visible.count))
        LazyVGrid(
            columns: Array(repeating: GridItem(.fixed(self.avatarSize), spacing: CoreSpacing.xxs), count: columns),
            spacing: CoreSpacing.xxs
        ) {
            ForEach(Array(zip(visible.indices, visible)), id: \.0) { _, subview in
                self.styledAvatar(subview)
            }
            if overflow > 0 {
                self.overflowBadge(overflow)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func countBadge(total: Int) -> some View {
        Text(verbatim: total.formatted())
            .coreFont(.caption)
            .foregroundStyle(.secondary)
            .frame(width: self.avatarSize, height: self.avatarSize)
            .background(Circle().fill(Color.surfaceCanvasInset))
            .overlay(Circle().strokeBorder(Color.borderMuted, lineWidth: CoreBorderWidth.thin))
            .accessibilityLabel(AvatarGroupAccessibility.totalLabel(for: total))
    }

    private func styledAvatar(_ subview: SubviewsCollection.Element) -> some View {
        subview
            .clipShape(Circle())
            .overlay(
                Circle()
                    .strokeBorder(Color.surfaceCanvas, lineWidth: CoreBorderWidth.thin)
            )
    }

    private func overflowBadge(_ overflow: Int) -> some View {
        Text("+\(overflow)")
            .coreFont(.caption)
            .foregroundStyle(.secondary)
            .frame(width: self.avatarSize, height: self.avatarSize)
            .background(Circle().fill(Color.surfaceCanvasInset))
            .overlay(Circle().strokeBorder(Color.borderMuted, lineWidth: CoreBorderWidth.thin))
            .accessibilityLabel(AvatarGroupAccessibility.overflowLabel(for: overflow))
    }

    private var avatarSize: CGFloat {
        switch self.controlSize {
        case .mini: return 20
        case .small: return 24
        case .regular: return 32
        case .large: return 40
        case .extraLarge: return 48
        @unknown default: return 32
        }
    }
}

enum AvatarGroupAccessibility {
    static func overflowLabel(for count: Int) -> String {
        String(localized: "\(count) more avatars", bundle: .module)
    }

    static func totalLabel(for count: Int) -> String {
        String(localized: "\(count) avatars", bundle: .module)
    }
}

// MARK: - Preview

#Preview("AvatarGroup — Light") {
    AvatarGroupPreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("AvatarGroup — Dark") {
    AvatarGroupPreviewGallery()
        .preferredColorScheme(.dark)
}

private struct AvatarGroupPreviewGallery: View {
    @ViewBuilder
    private var sampleAvatars: some View {
        Circle().fill(.blue).frame(width: 32, height: 32)
        Circle().fill(.green).frame(width: 32, height: 32)
        Circle().fill(.red).frame(width: 32, height: 32)
        Circle().fill(.orange).frame(width: 32, height: 32)
        Circle().fill(.purple).frame(width: 32, height: 32)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CoreSpacing.lg) {
                self.section("交叠 · overlapped（默认，max: 3 ⇒ 溢出 +2）") {
                    AvatarGroup { self.sampleAvatars }
                }

                self.section("交叠 · 无溢出（max: 5）") {
                    AvatarGroup(max: 5) { self.sampleAvatars }
                }

                self.section("并排 · spaced（max: 3 ⇒ 溢出 +2）") {
                    AvatarGroup(max: 3, layout: .spaced) { self.sampleAvatars }
                }

                self.section("网格 · grid（max: 3 ⇒ 3 列 + 溢出徽标）") {
                    AvatarGroup(max: 3, layout: .grid) { self.sampleAvatars }
                }

                self.section("网格 · 列数被内容数压低（max: 8、内容 5）") {
                    AvatarGroup(max: 8, layout: .grid) { self.sampleAvatars }
                }

                self.section("纯计数 · countOnly（读作「一共 5 个」，max 不生效）") {
                    AvatarGroup(max: 3, layout: .countOnly) { self.sampleAvatars }
                }

                self.section("纯计数 · 边界：单数（须读「1 avatar」而非「1 avatars」）") {
                    AvatarGroup(layout: .countOnly) {
                        Circle().fill(.blue).frame(width: 32, height: 32)
                    }
                }

                self.section("小尺寸 · .controlSize(.small)") {
                    AvatarGroup(max: 2, layout: .spaced) { self.sampleAvatars }
                        .controlSize(.small)
                }
            }
            .padding()
        }
        .background(Color.surfaceCanvas)
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: CoreSpacing.sm) {
            Text(verbatim: title)
                .coreFont(.caption)
                .foregroundStyle(Color.contentSecondary)
            content()
        }
    }
}
