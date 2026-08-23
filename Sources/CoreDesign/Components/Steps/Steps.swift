//
//  Steps.swift
//  CoreDesign
//

import SwiftUI

// MARK: - StepItem

/// 单个步骤的数据模型：标题（必填）+ 可选描述 + 错误标记。
///
/// `isError == true` 时该节点的指示器颜色**忽略**由 `currentIndex` 派生的进行态
/// （pending / current / done），固定走 `StatusLevel.danger` 对应的 `StatusColors`
/// 映射（`statusDangerEmphasis` 填充 / `contentOnDanger` 前景），与仓库内其它
/// Phase 1 组件的错误态处理口径一致。
public struct StepItem: Sendable, Identifiable, Equatable {
    public let id: UUID
    public let title: String
    public let description: String?
    public let isError: Bool

    /// - Parameters:
    ///   - title: 步骤标题，必填。
    ///   - description: 步骤描述，可选。
    ///   - isError: 是否为错误态，默认 `false`。错误态节点的指示器颜色固定走
    ///     `StatusColors` danger 映射，忽略 `currentIndex` 派生的进行态。
    ///   - id: 稳定标识，默认新建 `UUID`——调用方持有自己的模型时可传入自定义 id
    ///     以在列表更新时保持 diff 稳定。
    public init(title: String, description: String? = nil, isError: Bool = false, id: UUID = UUID()) {
        self.title = title
        self.description = description
        self.isError = isError
        self.id = id
    }
}

// MARK: - StepsAxis

/// `Steps` 排列方向。
public enum StepsAxis: Sendable, Equatable {
    case horizontal
    case vertical
}

// MARK: - StepsIndicatorStyle

/// `Steps` 指示器展示样式——纯展示配置，不携带进行态语义，可安全公开
/// （区别于下方 `Steps.StepsProgress`，后者才是需要收敛为非公开的状态语义类型）。
public enum StepsIndicatorStyle: Sendable, Equatable {
    /// 圆点指示器：pending 描边空心圆 / current & done 实心 `.tint` 圆点 /
    /// error 实心 danger 圆点。
    case dot
    /// 数字指示器：pending 描边空心圆 + 序号 / current 实心 `.tint` 圆 + 白色序号 /
    /// done 实心 `.tint` 圆 + 白色 checkmark / error 实心 danger 圆 + 白色感叹号。
    case numbered
}

// MARK: - StepsPresentation

/// `Steps` 的**整体呈现形态**——与 `StepsIndicatorStyle` **正交**：本枚举决定「这组步骤
/// 数据画成什么结构」，后者只决定「`.steps` 结构下那些离散指示器长什么样」。
///
/// ⚠️ **为什么不把这些 case 加进 `StepsIndicatorStyle`**（`#60` 形态选择的自查结论）：
/// 那个枚举的语义是「离散指示器长什么样」，其消费者 `indicatorDiameter` 的注释逐字是
/// 「横向连线的中央空档宽度取此值」——整个骨架预设了「每步一个指示器 + 连线」。而下面三种
/// 新形态里，`.segmentedBar` 没有离散指示器、`.navigation` 去掉连线、`.text` 连 `items`
/// 循环都不适用 ⇒ 它们改的**不是指示器样式，是整个 body 结构**。塞进去会污染既有语义。
///
/// 判定依据：`docs/component-contract.md` §2 形态 **D2（配置枚举）**——本组件的候选形态是
/// 封闭集合（本仓自己枚举的三个业界形态 + 现状），故用枚举承载而非发 public 协议。
/// public 协议受祖父条款约束、**发布后不可撤**，枚举加 case 可演进。
///
/// ⚠️ **正交性的代价**：`indicatorStyle` 只在 `.steps` 下有意义，其余三种呈现里**不生效**；
/// `axis` 同理只对 `.steps` 与 `.navigation` 有意义。这是**有意的静默**——传了不生效不是
/// 错误、只是无效，因此不加运行期断言；本文档即约定。
public enum StepsPresentation: Sendable, Equatable {
    /// 默认：离散指示器 + 连线（现状形态，`axis` 与 `indicatorStyle` 均在此形态下生效）。
    case steps
    /// 分段式进度条：N 个离散位置塌成一条连续条，已完成的段填充。
    /// 业界来源：Ant Design Steps 的 percent 形态 / Google 表单底部按页分段的进度条。
    case segmentedBar
    /// 导航式步骤条：去掉公共轴线与连线，每一步成为彼此直接拼接的块。
    /// 业界来源：Ant Design Steps `type="navigation"` / Shopify Polaris 结账步骤导航。
    case navigation
    /// 纯文本：N 个指示器槽与标题槽连同连线塌成一个文本槽。
    /// 业界来源：Typeform 的「1 of 5」进度文案。
    case text
}

// MARK: - Steps

/// **材质层**: 内容. **表面角色**: 内容.
///
/// 横向 / 纵向排列的步骤条，支持点状（`.dot`）/ 数字（`.numbered`）两种指示器样式。
///
/// 进行态（pending 未完成 / current 当前 / done 完成）由 `currentIndex` 在组件内部
/// 派生（`Steps.progress(for:currentIndex:)`），**不新增公开的进行态语义枚举**——
/// `StepsProgress` 保持非 `public`（详见该类型声明处注释：可测试性理由与 `Rating`
/// 的非-`private` 存储属性同源），下游调用方只能通过 `currentIndex: Int` 驱动，
/// 读不到内部进行态类型本身，不扩大公开 API 表面。
///
/// 完成态 / 当前态指示器强调色经 `.tint`（`TintShapeStyle`）取——不写死
/// `Color.accent`，调用方外加 `.tint(_:)` 会让完成 / 当前节点真的变色。
/// 错误态（`StepItem.isError == true`）**忽略** `progress(for:)` 的结果，
/// 固定走 `StatusLevel.danger` 对应的 `StatusColors` 映射（`statusDangerEmphasis`
/// 填充 + `contentOnDanger` 前景）。纵向 / 横向连线复用 `Color.dividerDefault`
/// （`BorderColors`，即系统 `separator`）——见
/// `.claude/epics/semi-mobile-components/phase0-decisions.md` §1 取色决策。
///
/// Accessibility：指示器行本身对 VoiceOver 隐藏（视觉冗余，进行态已经由文字行的
/// `accessibilityValue` 表达）；每一步的文字行是一个独立 accessibility element，
/// label 为 `title`（+ `description`，见 `Steps.accessibilityLabelText`）。当前步骤
/// （`index == currentIndex`）额外携带 `accessibilityValue`，用 Phase 0 预登记的
/// 位置键 `"%@ of %@"`（`Steps.positionText(current:total:)`，`bundle: .module`
/// 必传——见 phase0-decisions.md §2）播报「2 of 4」；错误态额外播报已登记键
/// `"Error"`，二者可同时出现（当前步骤同时也是错误态时用 `, ` 拼接）。
///
/// > Note: Phase 0 额外预登记了复数摘要键 `"%lld steps"`（`.stringsdict`），意图是给
/// > 整个 `Steps` 控件一个总步数摘要播报。Phase 3（#173）收口裁决：**不消费**，保留
/// > 为已注册但未使用的键——每一步已单独播报「2 of 4」形式的位置信息（含总数），
/// > 额外在容器层再插入一个「共 N 步」摘要 element 会产生双重播报，且需要重新设计
/// > 整个 accessibility 树的 `.contain`/`.ignore` 分层（当前逐步 element 已独立、
/// > 未被容器统一包裹），收益与改动/回归面不成比例，故不在本次范围内展开。若未来
/// > 确有「先给总览再逐步导航」的产品需求，`"%lld steps"` 键已就绪可直接复用。
public struct Steps: View {
    let items: [StepItem]
    let currentIndex: Int
    let axis: StepsAxis
    let indicatorStyle: StepsIndicatorStyle
    let presentation: StepsPresentation

    /// - Parameters:
    ///   - items: 步骤列表。
    ///   - currentIndex: 当前所在步骤索引（0-based），驱动内部进行态派生：
    ///     `index < currentIndex` → done，`index == currentIndex` → current，
    ///     其余 → pending。不做范围 clamp——调用方可传出界值（如
    ///     `items.count` 表示「全部完成」），`progress(for:)` 对越界索引仍能
    ///     正确求值（全部落 `.done`）。
    ///   - axis: 排列方向，默认 `.horizontal`。⚠️ 只对 `.steps` 与 `.navigation` 呈现有意义。
    ///   - indicatorStyle: 指示器样式，默认 `.dot`。⚠️ **只对 `.steps` 呈现有意义**——其余
    ///     呈现里没有离散指示器可言，传了不生效（见 `StepsPresentation` 的正交性说明）。
    ///   - presentation: 整体呈现形态，默认 `.steps`（现状形态）⇒ **现有调用方零影响**。
    public init(
        items: [StepItem],
        currentIndex: Int,
        axis: StepsAxis = .horizontal,
        indicatorStyle: StepsIndicatorStyle = .dot,
        presentation: StepsPresentation = .steps
    ) {
        self.items = items
        self.currentIndex = currentIndex
        self.axis = axis
        self.indicatorStyle = indicatorStyle
        self.presentation = presentation
    }

    // MARK: - Progress derivation

    /// 进行态。刻意不标 `private`——见 `Steps` 类型文档「不新增公开的进行态语义
    /// 枚举」一段：`private` 会连 `@testable import` 也读不到，而本组件的核心验收
    /// 标准之一就是「`currentIndex` → 进行态派生的边界值（含首尾索引）」单测。
    /// 退一档到默认 `internal`——仍不是 `public`，不出现在下游可见的公开 API 表面
    /// （SwiftPM 模块边界外不可见），只是同 module 的测试 target 能直接引用。与
    /// `Rating.swift` 对存储属性采用的同一取舍（该文件顶部注释详述）。
    enum StepsProgress: Equatable {
        case pending
        case current
        case done
    }

    /// 纯函数：由 `index` 与 `currentIndex` 求进行态。
    ///
    /// 边界值：`index == currentIndex` → `.current`；`index < currentIndex` →
    /// `.done`（含 `currentIndex` 越界到 `items.count` 时首尾索引全部落
    /// `.done` 的退化场景）；其余（`index > currentIndex`，含 `currentIndex`
    /// 为负数时首索引落此分支）→ `.pending`。
    static func progress(for index: Int, currentIndex: Int) -> StepsProgress {
        if index < currentIndex {
            .done
        } else if index == currentIndex {
            .current
        } else {
            .pending
        }
    }

    private func progress(for index: Int) -> StepsProgress {
        Self.progress(for: index, currentIndex: self.currentIndex)
    }

    // MARK: - Indicator metrics

    private static let dotDiameter: CGFloat = 12
    private static let numberedDiameter: CGFloat = 28

    /// 当前样式的指示器直径——横向连线的中央空档宽度取此值，使半段止于指示器边缘。
    private var indicatorDiameter: CGFloat {
        switch self.indicatorStyle {
        case .dot: Self.dotDiameter
        case .numbered: Self.numberedDiameter
        }
    }

    // MARK: - Body

    public var body: some View {
        switch self.presentation {
        case .steps:
            switch self.axis {
            case .horizontal: self.horizontalBody
            case .vertical: self.verticalBody
            }
        case .segmentedBar: self.segmentedBarBody
        case .navigation: self.navigationBody
        case .text: self.textBody
        }
    }

    private var horizontalBody: some View {
        // 每一步是一个**等宽列**（指示器居中于其标题正上方）——指示器与文字共用同一套等宽
        // 布局，避免「指示器行用弹性连线、文字行用等宽列」两套几何导致的中心错位（首/末步最重）。
        // 连线画在指示器的 background：左半连上一步、右半连下一步，相邻列半段在列边界相接成
        // 连续线；首列无左半、末列无右半。background HStack 的 `spacing` 取指示器直径——中央
        // 留出与指示器等宽的空档，使两半段**止于指示器边缘**而非从空心 pending 指示器（描边圆、
        // 内腔透明）的内部穿过（实心 current/done/error 也一并受益、观感更贴 Semi）。
        let last = self.items.count - 1
        return HStack(alignment: .top, spacing: 0) {
            ForEach(Array(self.items.enumerated()), id: \.element.id) { index, _ in
                VStack(spacing: CoreSpacing.sm) {
                    self.indicator(for: index)
                        .frame(maxWidth: .infinity)
                        .background {
                            HStack(spacing: self.indicatorDiameter) {
                                Rectangle()
                                    .fill(index > 0 ? self.connectorFill(after: index - 1) : AnyShapeStyle(Color.clear))
                                    .frame(height: CoreBorderWidth.thick)
                                Rectangle()
                                    .fill(index < last ? self.connectorFill(after: index) : AnyShapeStyle(Color.clear))
                                    .frame(height: CoreBorderWidth.thick)
                            }
                        }
                        // 指示器对 VoiceOver 隐藏——进行态已由下方文字的 accessibilityValue
                        // 表达，重复播报图形化圆点/数字/checkmark 只增噪音。
                        .accessibilityHidden(true)

                    self.applyStepAccessibility(
                        self.stepText(for: index, alignment: .center)
                            .multilineTextAlignment(.center),
                        index: index
                    )
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var verticalBody: some View {
        VStack(spacing: 0) {
            ForEach(Array(self.items.enumerated()), id: \.element.id) { index, _ in
                self.applyStepAccessibility(
                    HStack(alignment: .top, spacing: CoreSpacing.md) {
                        VStack(spacing: 0) {
                            self.indicator(for: index)
                            if index < self.items.count - 1 {
                                self.connector(after: index)
                                    .frame(width: CoreBorderWidth.thick)
                                    .frame(minHeight: CoreSpacing.lg)
                                    .frame(maxHeight: .infinity)
                            }
                        }
                        .accessibilityHidden(true)

                        self.stepText(for: index, alignment: .leading)
                            .padding(.bottom, index < self.items.count - 1 ? CoreSpacing.md : 0)

                        Spacer(minLength: 0)
                    },
                    index: index
                )
            }
        }
    }

    // MARK: - Alternative presentations（`#60` 形态 D2）

    /// `.segmentedBar`：N 个离散位置塌成一条连续条，每段对应一步、已完成的段填充。
    ///
    /// ⚠️ 取色复用 `connectorFill(after:)` 的同一套决策（done 走 `.tint`、其余走
    /// `Color.dividerDefault`），使四种呈现的「完成/未完成」语义在视觉上一致。
    /// ⚠️ 段高取 `CoreSpacing.xs` 而非连线的 `CoreBorderWidth.thick` —— 这里是**进度条**
    /// 不是连线，需要可读的填充面积。
    private var segmentedBarBody: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.sm) {
            HStack(spacing: CoreSpacing.xxs) {
                ForEach(Array(self.items.enumerated()), id: \.element.id) { index, item in
                    Capsule()
                        .fill(self.segmentFill(for: index, item: item))
                        .frame(height: CoreSpacing.xs)
                }
            }
            self.progressCaption
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: self.progressText))
    }

    /// `.segmentedBar` 的单段取色：error 走 danger，其余复用连线的 done/pending 决策。
    private func segmentFill(for index: Int, item: StepItem) -> AnyShapeStyle {
        if item.isError { return AnyShapeStyle(Color.statusDangerEmphasis) }
        return self.connectorFill(after: index - 1 >= 0 ? index - 1 : index)
    }

    /// `.navigation`：去掉公共轴线与连线，每一步是彼此直接拼接的块。
    ///
    /// ⚠️ `axis` 在本呈现下**仍有意义**（横向拼接 vs 纵向堆叠），这是它与 `.segmentedBar`
    /// / `.text` 的区别 —— 后两者的 `axis` 无处安放。
    @ViewBuilder
    private var navigationBody: some View {
        switch self.axis {
        case .horizontal:
            HStack(spacing: CoreSpacing.xxs) {
                ForEach(Array(self.items.enumerated()), id: \.element.id) { index, _ in
                    self.navigationBlock(for: index)
                }
            }
        case .vertical:
            VStack(alignment: .leading, spacing: CoreSpacing.xxs) {
                ForEach(Array(self.items.enumerated()), id: \.element.id) { index, _ in
                    self.navigationBlock(for: index)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    /// `.navigation` 的单块：无指示器、无连线，靠背景与文字色承载进行态。
    private func navigationBlock(for index: Int) -> some View {
        let item = self.items[index]
        // ⚠️ 无障碍复用既有的 `applyStepAccessibility(_:index:)`——四种呈现共用同一套
        // 语义标注，不为新呈现另造一套（否则同一组数据在不同呈现下 VoiceOver 读法会分裂）。
        return self.applyStepAccessibility(
            self.stepText(for: index, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, CoreSpacing.md)
                .padding(.vertical, CoreSpacing.sm)
                .background(self.navigationBlockFill(for: index, item: item))
                .clipShape(RoundedRectangle(cornerRadius: CoreRadius.small, style: .continuous)),
            index: index
        )
    }

    /// `.navigation` 单块背景：当前步用 `.tint` 的弱化底，其余透明——不引入新 token。
    private func navigationBlockFill(for index: Int, item: StepItem) -> AnyShapeStyle {
        if item.isError { return AnyShapeStyle(Color.statusDangerEmphasis.opacity(0.12)) }
        return self.progress(for: index) == .current
            ? AnyShapeStyle(Color.accentColor.opacity(0.12))
            : AnyShapeStyle(Color.clear)
    }

    /// `.text`：N 个指示器槽与标题槽连同连线塌成一个文本槽（Typeform 的「1 of 5」形态）。
    ///
    /// ⚠️ 本呈现下 `items` 的**逐条内容不被渲染**，只用其 `count` 与当前索引 —— 这正是
    /// 判定时把该候选判为「**槽**」（N 个槽塌成 1 个）的原因。
    private var textBody: some View {
        self.progressCaption
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: self.progressText))
    }

    /// `.segmentedBar` 与 `.text` 共用的进度文案。
    private var progressCaption: some View {
        Text(verbatim: self.progressText)
            .font(.footnote)
            .foregroundStyle(Color.contentSecondary)
    }

    /// 进度文案与无障碍标签共用的文本（A 类：文案写在组件源码里，调用方不传）。
    ///
    /// ⚠️ **本地化写法跟随本仓现行实践** `String(localized:bundle:.module)`
    /// （`AvatarGroup.swift:91` 的 `"\(count) more avatars"`、`PinCode.swift:280` 的
    /// `"\(index) of \(count)"` 同款）。
    /// ⚠️ 公约第 3 节规定 A 类**应用 `LocalizedStringResource`**，但本仓目前**零先例**，
    /// 该迁移由 `wxlpp/oh-my-story#49` 统一做（公约缺口 G-4：「A 类有规定、无判据、
    /// 无参考实现」）。⇒ 本组件**不单独引入新模式** —— 一个组件先迁会让本仓同时存在两套
    /// A 类写法，而 #49 要收的正是这种分裂。迁移时本处随其余 A 类文案一并改。
    private var progressText: String {
        let step = min(self.currentIndex + 1, self.items.count)
        return String(localized: "Step \(step.formatted()) of \(self.items.count.formatted())", bundle: .module)
    }

    // MARK: - Indicator rendering

    @ViewBuilder
    private func indicator(for index: Int) -> some View {
        switch self.indicatorStyle {
        case .dot:
            self.dotIndicator(for: index)
        case .numbered:
            self.numberedIndicator(for: index)
        }
    }

    @ViewBuilder
    private func dotIndicator(for index: Int) -> some View {
        let item = self.items[index]
        Group {
            if item.isError {
                Circle().fill(Color.statusDangerEmphasis)
            } else {
                switch self.progress(for: index) {
                case .pending:
                    Circle().strokeBorder(Color.dividerDefault, lineWidth: CoreBorderWidth.thick)
                case .current, .done:
                    Circle().fill(.tint)
                }
            }
        }
        .frame(width: Self.dotDiameter, height: Self.dotDiameter)
    }

    @ViewBuilder
    private func numberedIndicator(for index: Int) -> some View {
        let item = self.items[index]
        ZStack {
            if item.isError {
                Circle().fill(Color.statusDangerEmphasis)
                Image(systemName: "exclamationmark")
                    .coreFont(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.contentOnDanger)
            } else {
                switch self.progress(for: index) {
                case .pending:
                    Circle().strokeBorder(Color.dividerDefault, lineWidth: CoreBorderWidth.thin)
                    Text("\(index + 1)")
                        .coreFont(.footnote)
                        .foregroundStyle(Color.contentTertiary)
                case .current:
                    Circle().fill(.tint)
                    Text("\(index + 1)")
                        .coreFont(.footnote)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.contentOnAccent)
                case .done:
                    Circle().fill(.tint)
                    Image(systemName: "checkmark")
                        .coreFont(.footnote)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.contentOnAccent)
                }
            }
        }
        .frame(width: Self.numberedDiameter, height: Self.numberedDiameter)
    }

    /// 相邻两步之间的连线：`index`（左 / 上侧）步骤已完成（`.done`）时走 `.tint`
    /// （呼应完成态指示器强调色），否则走 `Color.dividerDefault`
    /// （phase0-decisions.md §1 连线取色决策）。
    ///
    /// > Note: 连线宽度取 `CoreBorderWidth.thick`（本文件 `horizontalBody` 的 background
    /// > `HStack` 半段与 `verticalBody` 的 `.frame(width:)`），而非 phase0-decisions §1
    /// > 所述的 separator hairline——指示性连线需要比分隔线更强的存在感，与 `Timeline`
    /// > 竖向连线取 `CoreBorderWidth.thin`（同样偏离 hairline，理由相同）同源。这是对
    /// > 「连线宽度对齐 Separator」决策的**有意偏离**，Phase 3 / #173 收口统一记录于此
    /// > 与 `Timeline.swift` 两处（互相引用，非各自孤立决定）。
    @ViewBuilder
    private func connector(after index: Int) -> some View {
        if self.progress(for: index) == .done {
            Rectangle().fill(.tint)
        } else {
            Rectangle().fill(Color.dividerDefault)
        }
    }

    /// 连线取色（`connector(after:)` 的 `ShapeStyle` 形态，供横向布局的背景半段填充复用）：
    /// 「第 index 步之后」的连线——该步已完成走 `.tint`（不写死 `Color.accent`），否则走
    /// `Color.dividerDefault`（phase0-decisions.md §1 连线取色决策）。
    private func connectorFill(after index: Int) -> AnyShapeStyle {
        self.progress(for: index) == .done
            ? AnyShapeStyle(.tint)
            : AnyShapeStyle(Color.dividerDefault)
    }

    // MARK: - Text rendering

    @ViewBuilder
    private func stepText(for index: Int, alignment: HorizontalAlignment) -> some View {
        let item = self.items[index]
        VStack(alignment: alignment, spacing: CoreSpacing.xxs) {
            Text(item.title)
                .coreFont(.subheadline)
                .foregroundStyle(self.titleColor(for: index))
            if let description = item.description, !description.isEmpty {
                Text(description)
                    .coreFont(.footnote)
                    .foregroundStyle(Color.contentSecondary)
            }
        }
    }

    private func titleColor(for index: Int) -> Color {
        let item = self.items[index]
        if item.isError {
            return .statusDangerForeground
        }
        switch self.progress(for: index) {
        case .pending:
            return .contentTertiary
        case .current, .done:
            return .contentPrimary
        }
    }

    // MARK: - Accessibility

    @ViewBuilder
    private func applyStepAccessibility<Content: View>(_ content: Content, index: Int) -> some View {
        let item = self.items[index]
        let base = content
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Self.accessibilityLabelText(title: item.title, description: item.description))
        if let valueText = Self.accessibilityValueText(
            index: index,
            currentIndex: self.currentIndex,
            total: self.items.count,
            isError: item.isError
        ) {
            base.accessibilityValue(Text(verbatim: valueText))
        } else {
            base
        }
    }

    /// `accessibilityLabel` 文案组装：`title`，若有非空 `description` 则以
    /// `"\(title): \(description)"` 拼接。纯函数，便于单测锁定拼接形状。
    static func accessibilityLabelText(title: String, description: String?) -> String {
        guard let description, !description.isEmpty else { return title }
        return "\(title): \(description)"
    }

    /// `accessibilityValue` 文案组装：当前步骤附 Phase 0 位置键 `"%@ of %@"`
    /// （`Steps.positionText(current:total:)`），错误态附已登记键 `"Error"`；
    /// 二者互不排斥（当前步骤同时是错误态时以 `", "` 拼接），均不成立时返回 `nil`
    /// （调用方据此不挂载 `accessibilityValue`）。纯函数，便于单测锁定各分支与
    /// 组合顺序。
    static func accessibilityValueText(index: Int, currentIndex: Int, total: Int, isError: Bool) -> String? {
        var parts: [String] = []
        if index == currentIndex {
            parts.append(Self.positionText(current: index + 1, total: total))
        }
        if isError {
            parts.append(String(localized: "Error", bundle: .module))
        }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    /// Phase 0 预登记的位置键 `"%@ of %@"`
    /// （`.claude/epics/semi-mobile-components/phase0-decisions.md` §2），两端为
    /// `Int.formatted()`（当前步骤为 1-based 显示，如「2 of 4」）。`bundle: .module`
    /// 必传——漏传会静默 fallback 到 key 自身格式，英文环境下输出恰好一样，测试也抓
    /// 不到，直到非英文本地化才暴露（与 `Rating.accessibilityValueText` 同一告诫）。
    static func positionText(current: Int, total: Int) -> String {
        String(localized: "\(current.formatted()) of \(total.formatted())", bundle: .module)
    }
}

// MARK: - Preview

#Preview("Steps — Light") {
    StepsPreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("Steps — Dark") {
    StepsPreviewGallery()
        .preferredColorScheme(.dark)
}

private struct StepsPreviewGallery: View {
    private static let basicItems: [StepItem] = [
        StepItem(title: "Cart", description: "Review items"),
        StepItem(title: "Shipping", description: "Add address"),
        StepItem(title: "Payment", description: "Enter card details"),
        StepItem(title: "Confirm", description: "Review & place order")
    ]

    private static let errorItems: [StepItem] = [
        StepItem(title: "Cart"),
        StepItem(title: "Shipping"),
        StepItem(title: "Payment", description: "Card declined", isError: true),
        StepItem(title: "Confirm")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CoreSpacing.xl) {
                self.section("横向 · 点状") {
                    Steps(items: Self.basicItems, currentIndex: 1, axis: .horizontal, indicatorStyle: .dot)
                }

                self.section("横向 · 数字") {
                    Steps(items: Self.basicItems, currentIndex: 2, axis: .horizontal, indicatorStyle: .numbered)
                }

                self.section("横向 · 数字 · 含错误态") {
                    Steps(items: Self.errorItems, currentIndex: 2, axis: .horizontal, indicatorStyle: .numbered)
                }

                self.section("纵向 · 点状") {
                    Steps(items: Self.basicItems, currentIndex: 1, axis: .vertical, indicatorStyle: .dot)
                }

                self.section("纵向 · 数字") {
                    Steps(items: Self.basicItems, currentIndex: 2, axis: .vertical, indicatorStyle: .numbered)
                }

                self.section("纵向 · 数字 · 含错误态") {
                    Steps(items: Self.errorItems, currentIndex: 2, axis: .vertical, indicatorStyle: .numbered)
                }

                self.section("全部完成（currentIndex == count）") {
                    Steps(
                        items: Self.basicItems,
                        currentIndex: Self.basicItems.count,
                        axis: .horizontal,
                        indicatorStyle: .numbered
                    )
                }

                self.section(".tint(.orange) 覆盖") {
                    Steps(items: Self.basicItems, currentIndex: 2, axis: .horizontal, indicatorStyle: .dot)
                        .tint(.orange)
                }
            }
            .padding()
        }
        .background(Color.surfaceCanvas)
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: CoreSpacing.sm) {
            Text(title).coreFont(.footnote).foregroundStyle(.secondary)
            content()
        }
    }
}
