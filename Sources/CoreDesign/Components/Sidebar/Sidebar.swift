//
//  Sidebar.swift
//  CoreDesign
//

import SwiftUI

// MARK: - Sidebar Text Style

/// 侧栏内容的语义文字色别名。
///
/// 映射到第 3 层语义文字色（`contentPrimary` / `contentMuted` / `contentSubtle`），
/// 使自定义侧栏内容与内置行保持视觉一致。**用这些别名，不要直接取色相。**
///
/// 自定义侧栏内容时复用，保证与内置
/// row 一致。
public enum SidebarTextStyle {
    public static let primary = Color.contentPrimary
    public static let secondary = Color.contentMuted
    public static let tertiary = Color.contentSubtle
}

// MARK: - Sidebar Section

/// 带标题的侧栏分组容器。
///
/// 在 leading 对齐的行内容堆叠之上渲染一个 section header（标题 + 可选展开
/// chevron + 装饰性溢出字形）。
///
/// **材质层**: 容器. **表面角色**: 侧栏.
///
/// 侧栏分组容器 / SidebarSection：标题 + 可选 chevron 头部 + 内容行堆叠。
public struct SidebarSection<Content: View>: View {
    public init(
        title: String,
        showsChevron: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.showsChevron = showsChevron
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.sm) {
            HStack(spacing: CoreSpacing.xs) {
                Text(self.title)
                    .coreFont(.headline)
                    .foregroundStyle(SidebarTextStyle.primary)

                if self.showsChevron {
                    Image(systemName: "chevron.forward")
                        .coreFont(.footnote)
                        .foregroundStyle(SidebarTextStyle.secondary)
                        // 纯装饰：标题已表达分组语义，避免 VoiceOver 朗读
                        // "chevron right" 噪音 / Decorative chevron.
                        .accessibilityHidden(true)
                }

                Spacer()

                Image(systemName: "ellipsis")
                    .coreFont(.callout)
                    .foregroundStyle(SidebarTextStyle.tertiary)
                    // 装饰性占位符，当前无 action；对 VoiceOver 隐藏避免
                    // 暴露成无标签图片 / Decorative placeholder, no action.
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, CoreSpacing.sm)

            VStack(alignment: .leading, spacing: CoreSpacing.xxs) {
                self.content
            }
        }
    }

    private let title: String
    private let showsChevron: Bool
    private let content: Content
}

// MARK: - Sidebar Rows

// MARK: OptionalLineLimit (helper)

/// 条件性 lineLimit / Conditional line limit。
///
/// `.lineLimit(nil)` 会**显式重置**祖先设过的值，与「不写 lineLimit」不等价。
/// 本 modifier 在 `limit == nil` 时原样返回 content，保证三个不限行的 row
/// 与收敛前逐字等价。
private struct OptionalLineLimit: ViewModifier {
    let limit: Int?

    func body(content: Content) -> some View {
        if let limit = self.limit {
            content.lineLimit(limit)
        } else {
            content
        }
    }
}

// MARK: - SidebarRow (shared skeleton)

/// 四种 sidebar row 的共享骨架 / Shared skeleton for the four sidebar rows.
///
/// 收敛自原先四份逐字重复的实现。差异全部由调用方经
/// `leading` / `trailing` 两个 `@ViewBuilder` 与 `isSelected` 表达：
///
/// - `leading`：图标或 `#` 字形，字号各 row 不同（`body` / `title2`）
/// - `trailing`：可选尾部内容；**a11y 语义由调用方决定**——`SidebarDocumentRow`
///   的 detail 承载信息须可读，`SidebarUtilityRow` / `SidebarTagRow` 的是纯装饰
///   须 `.accessibilityHidden(true)`。骨架不代为决定。
/// - `isSelected`：仅 `SidebarNavigationRow` 使用，驱动 floating-glass 背景与
///   `.isSelected` 辅助技术 trait。
private struct SidebarRow<Leading: View, Trailing: View>: View {
    let title: String
    let titleLineLimit: Int?
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let leading: Leading
    @ViewBuilder let trailing: Trailing

    var body: some View {
        Button(action: self.action) {
            HStack(spacing: CoreSpacing.sm) {
                self.leading
                    .foregroundStyle(SidebarTextStyle.secondary)
                    .frame(width: CoreControlMetrics.iconSize(for: .large))
                    // 装饰性 leading 字形：button 的可访问名由 title 驱动，隐藏它
                    // 避免 VoiceOver 朗读 SF Symbol 名 / Decorative leading glyph.
                    .accessibilityHidden(true)

                Text(self.title)
                    .coreFont(.body)
                    .foregroundStyle(SidebarTextStyle.primary)
                    .modifier(OptionalLineLimit(limit: self.titleLineLimit))

                Spacer()

                self.trailing
            }
            // minHeight 而非固定 height，与 ListRow / SearchField 一致。
            //
            // **实际收益是长 title 换行不再被压出框**——三个 row 传
            // `titleLineLimit: nil`，标题过长会换到 2+ 行，固定 height 会把
            // 第二行裁掉。`SidebarDocumentRow` 传 `1` 且 detail 也限 1 行，
            // 对它是纯预防性改动。
            .frame(minHeight: CoreControlMetrics.height(for: .large))
            .padding(.horizontal, CoreSpacing.sm)
            .sidebarSelectedBackground(self.isSelected)
            .contentShape(CoreShape.rounded(CoreRadius.medium))
        }
        .buttonStyle(.plain)
        // 向辅助技术暴露选中态，让 VoiceOver 用户感知当前导航目标
        // （对齐 SegmentedControl）/ Expose selected state to a11y.
        .accessibilityAddTraits(self.isSelected ? .isSelected : [])
    }
}

/// 带选中态的主导航行。
///
/// 图标 + 标题的按钮行；`isSelected` 为 true 时带上浮层玻璃选中背景
/// （见 `sidebarSelectedBackground(_:)`）。
///
/// 侧栏主导航行 / SidebarNavigationRow：图标 + 标题，选中态带 floating-glass 背景。
public struct SidebarNavigationRow<Leading: View>: View {
    /// 以任意 leading 视图构造（可插图标 / 富文本）。
    public init(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void,
        @ViewBuilder leading: () -> Leading
    ) {
        self.title = title
        self.isSelected = isSelected
        self.action = action
        self.leading = leading()
    }

    public var body: some View {
        SidebarRow(
            title: self.title,
            titleLineLimit: nil,
            isSelected: self.isSelected,
            action: self.action
        ) {
            self.leading
        } trailing: {
            EmptyView()
        }
    }

    private let title: String
    private let isSelected: Bool
    private let action: () -> Void
    private let leading: Leading
}

public extension SidebarNavigationRow where Leading == AnyView {
    /// SF Symbol 便利构造（保留原签名，既有调用点不变）。
    ///
    /// `AnyView` 擦除在此可接受：leading 只是单个 `.coreFont(.body)` 图标、
    /// 无测试断言其具体类型（与 `Badge` 需保留 `Text` 精确类型的场景不同），
    /// 擦除代价可忽略，且能一比一复现改前的 body 字号观感。
    init(systemImage: String, title: String, isSelected: Bool, action: @escaping () -> Void) {
        self.init(title: title, isSelected: isSelected, action: action) {
            AnyView(Image(systemName: systemImage).coreFont(.body))
        }
    }
}

// MARK: - SidebarUtilityRowPresentation

/// `SidebarUtilityRow` 的**呈现形态**。
///
/// 判定依据：`docs/component-contract.md` §2 形态 **D2（配置枚举）**，兑现 `#59` 判定的
/// `needsExtensionPoint: true`（登记表 `kind: semantic` / `decidedBy: step2`）。
///
/// ⚠️ **为什么是 D2 而不是 D1**（形态 D 内部无次序 —— 见公约「优先序：A > B > D > C」小节；本条是按公约
/// 「**实现 issue 对每一条必须独立做一次设计判断，不得照单实现候选清单**」作出的选择，
/// **不主张 D1 不成立**）：
/// D1（给 `leading` 开 `@ViewBuilder` 槽）**做得到同样的覆盖**，但要么把本类型泛型化成
/// `SidebarUtilityRow<Leading>`（现有 `type(of:) == SidebarUtilityRow.self` 断言即编译不过），
/// 要么走 `AnyView` 擦除并付本仓对擦除设的成文门槛。D2 只加一个带默认值的参数，
/// **类型名不变**；且开放槽会把一个封闭的候选空间（有字形 / 无字形）敞成任意视图。
///
/// ⚠️ **两个 case 各自独立成立为一种形态角色**，不是「一个布尔旋钮的两个投影」——
/// 参照公约对 `CardKind` 的裁定：「**两 case 数本身不是判据**，『是否独立成立为角色』才是」
/// （见公约「⚠️ 头号反例：把 Bool 换成两 case enum **不是**替代路径」一节）。`.textOnly` 有具名业界来源（Ant Design Menu 默认无 icon 项 /
/// macOS Finder 下拉菜单项），由 `#59` 判为**槽**差异。
// `CaseIterable` 是给护栏用的（PR #209 终审 S5）：`SidebarLeadingSlotRenderTests` 遍历
// `allCases` 做尺寸/命中区断言 ⇒ **将来新增第三个 case 会自动被现有护栏覆盖**，
// 不会因为测试里硬编码了两个 case 而漏测。
public enum SidebarUtilityRowPresentation: Sendable, Equatable, CaseIterable {
    /// 默认：leading 字形 + 标题（现状形态）。
    case iconLeading
    /// 纯文字行：**不渲染 leading 字形、也不占位**。
    ///
    /// ⚠️ `systemImage` 在本形态下**静默不生效**（传了不是错误、只是无效，与四条兄弟
    /// 组件同一处置）。⚠️ 但与它们有一处实质差异：那几条的失效参数都有默认值、可以不传，
    /// 而本类型的 `systemImage` **必填** ⇒ 每个 `.textOnly` 调用点被迫写一个永不渲染的
    /// 死参数。约定统一写 `""`，便于将来批量识别。
    ///
    /// ⚠️ 候选 2「字形移到 trailing、文字左对齐起首」由 **本 case + 既有
    /// `trailingSystemImage`** 承载（行尾那个字形走 `SidebarTextStyle.tertiary`，
    /// 语义是装饰性尾图标 —— 这比「把主字形搬到行尾」更贴其具名来源
    /// Fluent 2 trailing affordance / iOS 设置二级页面行首无图标）。
    case textOnly
}


/// 次级工具行，可选尾部装饰。
///
/// 单动作行：leading 图标 + 标题，尾部可挂一个装饰性的 `trailingSystemImage`
/// （**不是独立动作**——整行就是一个按钮）。
///
/// 侧栏工具行 / SidebarUtilityRow：图标 + 标题 + 可选装饰性 trailing 图标，整行单一 action。
public struct SidebarUtilityRow: View {
    /// - Parameters:
    ///   - systemImage: leading 字形。⚠️ `presentation == .textOnly` 时**静默不生效**
    ///     （见 `SidebarUtilityRowPresentation.textOnly`；该形态下约定统一传 `""`）。
    ///   - trailingSystemImage: 可选装饰性尾图标，默认 `nil`。⚠️ 与 `.textOnly` 组合即得
    ///     公约候选 2「字形移到 trailing、文字左对齐起首」。
    ///   - presentation: 呈现形态，默认 `.iconLeading`（现状形态）⇒ **现有调用方零影响**。
    public init(
        systemImage: String,
        title: String,
        trailingSystemImage: String? = nil,
        presentation: SidebarUtilityRowPresentation = .iconLeading,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.title = title
        self.trailingSystemImage = trailingSystemImage
        self.presentation = presentation
        self.action = action
    }

    public var body: some View {
        SidebarRow(
            title: self.title,
            titleLineLimit: nil,
            isSelected: false,
            action: self.action
        ) {
            // ⚠️ **`.textOnly` 靠这里的条件分支实现，共用骨架 `SidebarRow` 一字不动。**
            // `EmptyView` 在 `HStack` 里是**布局透明**的 —— 即使被骨架的
            // `.foregroundStyle().frame(width: iconSize).accessibilityHidden(true)` 整条包住，
            // 也既不占那格 20pt、也不吃那个 8pt 间距。实测：有字形 111.0 / `.textOnly` 83.0，
            // 差值 28.0 == `iconSize(.large) + CoreSpacing.sm`，与「骨架真条件化」逐点相同。
            // ⇒ 不必改被四条兄弟行共用的骨架，回归面为零。护栏见
            // `SidebarLeadingSlotRenderTests`。
            if self.presentation == .iconLeading {
                Image(systemName: self.systemImage)
                    .coreFont(.body)
            }
        } trailing: {
            if let trailingSystemImage = self.trailingSystemImage {
                Image(systemName: trailingSystemImage)
                    .coreFont(.body)
                    .foregroundStyle(SidebarTextStyle.tertiary)
                    // 次级装饰性 affordance：随主 button 单一 action 触发，
                    // 不单独暴露给 VoiceOver / Decorative trailing affordance.
                    .accessibilityHidden(true)
            }
        }
    }

    // ⚠️ 前三个存储属性是 `internal` 而非 `private`：`@testable import` 进不去 `private`，
    // 而先例（`AvatarGroupTests` 的 `#expect(group.layout == .overlapped)`）断的正是存储层。
    // 退一档到默认 internal 仍不出现在下游可见的公开 API 表面（与 `Steps.StepsProgress` 同源取舍）。
    let systemImage: String
    let trailingSystemImage: String?
    let presentation: SidebarUtilityRowPresentation
    private let title: String
    private let action: () -> Void
}

/// 带尾部 detail 文本的文档行。
///
/// leading 图标 + 标题 + 尾部 `detail` 字符串（计数、相对日期等）；
/// `detail` 对 VoiceOver 可读，而图标被标记为装饰性隐藏。
///
/// 侧栏文档行 / SidebarDocumentRow：图标 + 标题 + 尾部 detail（计数 / 日期等）。
public struct SidebarDocumentRow: View {
    public init(
        systemImage: String,
        title: String,
        detail: String,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.title = title
        self.detail = detail
        self.action = action
    }

    public var body: some View {
        SidebarRow(
            title: self.title,
            titleLineLimit: 1,
            isSelected: false,
            action: self.action
        ) {
            Image(systemName: self.systemImage)
                .coreFont(.title2)
        } trailing: {
            // detail 承载信息（计数 / 日期），**不**隐藏，保持 VoiceOver 可读
            Text(self.detail)
                .coreFont(.callout)
                .foregroundStyle(SidebarTextStyle.tertiary)
                .lineLimit(1)
        }
    }

    private let systemImage: String
    private let title: String
    private let detail: String
    private let action: () -> Void
}

/// 以 `#` 字形开头的标签行。
///
/// 仅含标题的导航行，前缀 `#` 是装饰性的；无障碍名称只由 `title` 决定。
///
/// 侧栏标签行 / SidebarTagRow：`#` 前缀 + 标题。
public struct SidebarTagRow: View {
    public init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        SidebarRow(
            title: self.title,
            titleLineLimit: nil,
            isSelected: false,
            action: self.action
        ) {
            Text("#")
                .coreFont(.title2)
        } trailing: {
            Image(systemName: "chevron.forward")
                .coreFont(.footnote)
                .foregroundStyle(SidebarTextStyle.tertiary)
                // 装饰性指示箭头：行整体可点击，标题已表达目标
                // Decorative trailing chevron.
                .accessibilityHidden(true)
        }
    }

    private let title: String
    private let action: () -> Void
}

/// 状态点 + 标题/详情文本的页脚。
///
/// 非交互式页脚（状态点 + 两行标签），合并为**单个无障碍元素**。
/// `statusColor` 默认取语义 token `statusSuccessForeground`。
///
/// 侧栏状态页脚 / SidebarStatusFooter：状态点 + 标题/详情，默认成功语义色。
public struct SidebarStatusFooter: View {
    public init(
        title: String,
        detail: String,
        statusColor: Color = .statusSuccessForeground
    ) {
        self.title = title
        self.detail = detail
        self.statusColor = statusColor
    }

    public var body: some View {
        HStack(spacing: CoreSpacing.sm) {
            Circle()
                .fill(self.statusColor)
                .frame(
                    width: CoreSpacing.sm,
                    height: CoreSpacing.sm
                )
                // 状态点纯装饰：title / detail 已传达语义
                // Decorative status dot.
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: CoreSpacing.xxs) {
                Text(self.title)
                    .coreFont(.footnote)
                    .fontWeight(.medium)
                    .foregroundStyle(SidebarTextStyle.primary)
                Text(self.detail)
                    .coreFont(.footnote)
                    .foregroundStyle(SidebarTextStyle.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(CoreSpacing.sm)
        // 合并 title / detail 为单个可访问元素
        // Combine title + detail into one accessibility element.
        .accessibilityElement(children: .combine)
    }

    private let title: String
    private let detail: String
    private let statusColor: Color
}

// MARK: - Selected Background

private struct SidebarSelectedBackgroundModifier: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        if self.isSelected {
            // `floatingGlass(isInteractive: true)` 已提供 interactive regular
            // glass 材质 + subtle 边框；此处仅在其上叠加 selected 色描边强调
            // 选中态 + 阴影。原先额外的 `.glassEffect(.regular.interactive())`
            // 会与 floatingGlass 内部的 glass 双重渲染材质，已移除。
            // floatingGlass already applies the interactive glass; the extra
            // outer glassEffect was redundant double material — removed.
            // 单一 shape 来源：floatingGlass 与描边 overlay 共用，避免 corner
            // radius / style 改动时两处不同步 / Single shape source.
            let shape = CoreShape.rounded(CoreRadius.medium)
            content
                .floatingGlass(in: shape, isInteractive: true)
                .overlay {
                    shape
                        .strokeBorder(Color.borderSelected, lineWidth: CoreBorderWidth.thin)
                }
                .coreShadow(.medium)
        } else {
            content
        }
    }
}

public extension View {
    /// `isSelected` 为 true 时施加侧栏选中态背景。
    ///
    /// 浮层玻璃材质 + 选中色描边 + 阴影。`SidebarNavigationRow` 在用；
    /// 自定义行复用它即可与内置选中样式保持一致。
    ///
    /// 侧栏选中态背景 modifier / sidebarSelectedBackground：floating-glass + 选中描边 + 阴影。
    ///
    /// ## ⚠️ 这是刻意的风格决策，不是疏漏（Issue #136 / #226 定案）
    ///
    /// **本库的侧栏选中态刻意不追随 iOS / macOS 原生形态。** 原生是**着色填充、
    /// 无独立轮廓**（Files / Reminders / Mail 的侧栏都是这样）；本库用的是
    /// **浮层玻璃 + 全周选中色描边 + 阴影**。
    ///
    /// 这个差异被独立提出过**两次**，两次的措辞高度一致，故记录在此以免第三次：
    ///
    /// 1. **Issue #136**（`coredesign-native-foundation` 的视觉终审 #125）：
    ///    「视觉上是一圈蓝色轮廓环绕整个 pill，读起来更像**聚焦的输入框**而非
    ///    侧栏选中态」，建议对照 Files / Reminders / Mail 重新审视。
    /// 2. **Issue #225 的视觉终审**（`ios-visual-reviewer`，2026-09）：
    ///    「选中态 Home 用白卡 + 2pt 蓝描边，**读作键盘 focus ring 而非选中态**
    ///    （iOS 惯例是 tinted fill）」。
    ///
    /// **#226 的裁决：保持现状，不改行为。** 理由是本库的侧栏走的是浮层玻璃语言
    /// （与 `floatingGlass` / `BottomInputBar` 一脉），选中态用同族材质是内部一致的；
    /// 换成原生着色填充会让侧栏与库内其余浮层形态割裂。
    ///
    /// ⚠️ **但这条裁决的成本要如实记账**：两个独立评审都把它读成了「聚焦/focus ring」，
    /// 说明它与用户既有的平台直觉是冲突的——**这不是「他们看错了」，是本库选了一条
    /// 需要用户重新学习的表达**。若将来有第三次同类反馈，或本库整体向原生形态收敛，
    /// 应当重议而不是再次援引本条。对照参考仍是 Files / Reminders / Mail。
    func sidebarSelectedBackground(_ isSelected: Bool) -> some View {
        self.modifier(SidebarSelectedBackgroundModifier(isSelected: isSelected))
    }
}

#Preview {
    ScrollView {
        VStack(alignment: .leading, spacing: CoreSpacing.lg) {
            // 1) SidebarSection 容器 + 2) SidebarNavigationRow（选中 / 未选中两态）
            SidebarSection(title: "Workspace") {
                SidebarNavigationRow(systemImage: "house", title: "Home", isSelected: true) {}
                SidebarNavigationRow(systemImage: "bell", title: "Notifications", isSelected: false) {}
            }

            // 3) SidebarUtilityRow（带装饰性 trailing 图标）
            SidebarSection(title: "Tools", showsChevron: false) {
                SidebarUtilityRow(systemImage: "gearshape", title: "Settings", trailingSystemImage: "chevron.forward") {}
                SidebarUtilityRow(systemImage: "trash", title: "Trash") {}
            }

            // 4) SidebarDocumentRow（尾部 detail 可读）
            SidebarSection(title: "Documents") {
                SidebarDocumentRow(systemImage: "doc.text", title: "Design Spec", detail: "3d") {}
                SidebarDocumentRow(systemImage: "doc.richtext", title: "A very long document title that wraps", detail: "12") {}
            }

            // 5) SidebarTagRow（# 前缀）
            SidebarSection(title: "Tags") {
                SidebarTagRow(title: "swiftui") {}
                SidebarTagRow(title: "design-system") {}
            }

            // 6) SidebarStatusFooter（默认成功语义色）
            SidebarStatusFooter(title: "All systems operational", detail: "Updated just now")
        }
        .padding(CoreSpacing.md)
    }
    .background(Color.surfaceCanvas)
}
