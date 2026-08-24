//
//  AvatarGroup.swift
//  CoreDesign
//

import SwiftUI

// MARK: - AvatarGroupLayout

/// `AvatarGroup` 的**排布形态**——与 `avatars:` 槽**正交**：本枚举决定「这组头像怎么排」，
/// `avatars:` 提供「排什么」。
///
/// 判定依据：`docs/component-contract.md` §2 形态 **D2（配置枚举）**。⚠️ **为什么不是 D1**：
/// `avatars:` 是**内容槽**（装的是调用方自己的头像、组件对其无视觉主张、且无默认画法），
/// 公约的「外观槽 ≠ 内容槽」判据**明文排除**内容槽 ⇒ 它不构成扩展点。
///
/// ⚠️ **正交性的代价**（与 `StepsPresentation` / `TimelineLayout` 同一处置）：`max` 在
/// `.countOnly` 下**语义落空** —— 该形态不渲染任何头像，「最多显示几个」无处安放，传了
/// **静默不生效**；存储层仍原样保留，切回其余形态时不丢配置。
/// ⚠️ 其余三种形态下 `max` **仍然生效**。
public enum AvatarGroupLayout: Sendable, Equatable {
    /// 默认：头像按 `controlSize` 递增的负 offset 交叠（现状形态）。
    case overlapped
    /// 并排不重叠 + 溢出计数。
    /// 业界来源：Google Docs 协作者栏 / Microsoft Teams 成员条。
    case spaced
    /// 网格平铺。
    /// 业界来源：Slack Huddle 参与者网格 / Google Meet 头像平铺 / Discord 语音频道头像平铺。
    case grid
    /// 纯计数徽标：N 个头像塌成 1 个计数 —— 判定时判「**槽**」的依据正是这一点。
    /// 业界来源：GitHub Contributors 计数 / Linear assignee 计数。
    /// ⚠️ 本形态下不渲染任何头像，`max` 不生效（见上方正交性说明）。
    case countOnly
}

// MARK: - AvatarGroup

/// **材质层**: 内容. **表面角色**: 内容.
///
/// 堆叠头像组。
///
/// **无玻璃**——靠 `CoreBorderWidth.thin` 细描边分隔堆叠的头像与溢出计数 pill。
///
/// 前 N 个 avatar 交叠显示，超出 `max` 的部分显示 "+N" 计数 pill。
/// 使用 `Group(subviews:)` 遍历子视图。
///
/// ⚠️ 上面这段组件说明**必须紧贴本 struct**：它原先写在 `AvatarGroupLayout` 的文档块
/// 正上方且两块之间没有分隔，于是 Swift 把**整块**注释归给了那个枚举，`AvatarGroup`
/// 自己反而没有组件级 DocC（PR #206 review 抓到）。改动本文件头部时别把两块又并回去。
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

    /// 头像交叠量 / Avatar overlap offset（按 controlSize 递增负 offset）。
    /// 元素尺寸 ramp，刻意与 `CoreControlMetrics` 同构（裸字面量 switch），
    /// 不路由到 `CoreSpacing`——后者是间距刻度，且负值 / 20pt 无对应档位。
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
                // ⚠️ 两者只差 spacing —— 交叠是负 offset、并排是正间距。共用同一段布局，
                // 不为「并排」另写一份 HStack（否则头像样式与溢出徽标要维护两处）。
                self.linearRow(visible: visible, overflow: overflow)
            case .grid:
                self.gridBody(visible: visible, overflow: overflow)
            case .countOnly:
                // ⚠️ 不渲染任何头像 —— 这正是判定时判「槽」（N 个槽塌成 1 个）的依据。
                self.countBadge(total: subviews.count)
            }
        }
    }

    /// `.overlapped` / `.spaced` 共用的线性排布。
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

    /// `.grid`：头像网格平铺。列数取 `max` 与内容数的较小值，保证不出现空列。
    @ViewBuilder
    private func gridBody(
        visible: SubviewsCollection.SubSequence, overflow: Int
    ) -> some View {
        // ⚠️ `.fixedSize(horizontal:)` 在下方 —— `LazyVGrid` 会接受被提议的**全部**宽度并把
        // `.fixed` 列按 `alignment`（缺省 `.center`）摆在中间，于是 `.grid` 会横跨整行并居中，
        // 而 `.overlapped` / `.spaced` 走 `HStack` 是贴合内容的。同一组件四种形态的对齐行为
        // 不该分裂（PR #206 第 2 轮 review 抓到）。
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

    /// `.countOnly`：N 个头像塌成一个总数徽标。
    ///
    /// ⚠️ 显示的是**总数**（`subviews.count`）而非溢出数 —— 与 `+N` 徽标语义不同：
    /// 后者是「还有 N 个没显示」，这里是「一共 N 个」。
    private func countBadge(total: Int) -> some View {
        Text(verbatim: total.formatted())
            .coreFont(.caption)
            .foregroundStyle(.secondary)
            .frame(width: self.avatarSize, height: self.avatarSize)
            .background(Circle().fill(Color.surfaceCanvasInset))
            .overlay(Circle().strokeBorder(Color.borderMuted, lineWidth: CoreBorderWidth.thin))
            .accessibilityLabel(AvatarGroupAccessibility.totalLabel(for: total))
    }

    /// 单个头像的样式 —— 四种形态共用，保证同一头像在任何排布下长得一致。
    private func styledAvatar(_ subview: SubviewsCollection.Element) -> some View {
        subview
            .clipShape(Circle())
            .overlay(
                Circle()
                    .strokeBorder(Color.surfaceCanvas, lineWidth: CoreBorderWidth.thin)
            )
    }

    /// `+N` 溢出徽标 —— `.overlapped` / `.spaced` / `.grid` 共用。
    private func overflowBadge(_ overflow: Int) -> some View {
        Text("+\(overflow)")
            .coreFont(.caption)
            .foregroundStyle(.secondary)
            .frame(width: self.avatarSize, height: self.avatarSize)
            .background(Circle().fill(Color.surfaceCanvasInset))
            .overlay(Circle().strokeBorder(Color.borderMuted, lineWidth: CoreBorderWidth.thin))
            .accessibilityLabel(AvatarGroupAccessibility.overflowLabel(for: overflow))
    }

    /// 头像直径 / Avatar diameter（按 controlSize，20…48pt）。
    /// 同上：元素尺寸 ramp，与 `CoreControlMetrics` 同构，不套 spacing token。
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

    /// `.countOnly` 形态的总数标签。
    ///
    /// ⚠️ 与 `overflowLabel` 语义**不同**，不可复用：后者是「还有 N 个**没显示**」，
    /// 这里是「一共 N 个」。VoiceOver 读错会让用户以为还有更多头像被折叠。
    ///
    /// ⚠️ **复数走 `.stringsdict` 规则表**，键 `%lld avatars`（`one` / `other`），与上方
    /// `overflowLabel` 消费的 `%lld more avatars` 同一机制。注册守卫在
    /// `SharedFoundationTests` 的复数键块。
    ///
    /// ⚠️ 本条修过两次，第一次修错了，记在这里防第三次：Copilot 抓到 `count == 1` 会读出
    /// 「1 avatars」是对的，但当时的修法是在 Swift 侧写 `count == 1 ? "1 avatar" : ...`
    /// **两个新字面键**，理由写成「本仓没有 `.stringsdict`」—— 该文件一直都在，就在本函数
    /// 上方三行的 `overflowLabel` 脚下。那两个键谁都没注册，`String(localized:bundle:)`
    /// 静默 fallback 到 key 自身，英文下看着对、换语言整条不翻译，正是本 PR 自己在
    /// `Steps.progressSummary` 处写下的那个陷阱。⇒ 收回单键、走规则表。
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

/// ⚠️ PR #206 review 指出 `.spaced` / `.grid` / `.countOnly` 只有 storage/body 求值测试、
/// 预览仍只画默认 `.overlapped`，于是尺寸、溢出与无障碍渲染无人可见。以下逐形态 +
/// 溢出边界补齐。
///
/// 本仓的快照流水线**只生成 PNG、不做基线比对** —— `scripts/run-snapshots.sh`
/// 经 `App/Tests/SnapshotTests.swift`（`SnapshottingTests`）收集 `#Preview` 出图，但没有
/// 「与基线逐像素比对然后判红」的那一步 ⇒ **它检测不了视觉回归**，只是把图摆出来供人看。
/// 且默认模式只保留 `App/Sources/Previews.swift` 驱动的 `CoreDesignPreview_*`，库内
/// `#Preview` 产出的 `CoreDesign_*` 会被 `find -delete` 删掉（要留得加 `KEEP_LIBRARY_SNAPSHOTS=1`，
/// 且只落本地 scratch）。⇒ 新形态**已同步注册进 `App/Sources/Previews.swift`**，否则进不了流水线。
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
