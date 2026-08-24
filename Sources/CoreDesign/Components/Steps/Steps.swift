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
    /// ⚠️ **段与文案表达的是两件事，不是同一件事的两种写法**（PR #206 第 2 轮 review 要求
    /// 定案）：段填充判据是 `index < currentIndex`（**已完成**几步），caption / 无障碍
    /// 文案是 `currentIndex + 1`（**当前在**第几步）。所以 `currentIndex == 2, count == 4`
    /// 时是「2 段填充 + 读 3 of 4」—— 已完成 2 步、正在第 3 步，二者同时为真，互补而非矛盾。
    /// 采用这个口径而不是让文案跟着填充数走，是为了与 `.steps` / `.navigation` 逐步播报的
    /// 「2 of 4」（`positionText`，也是 1-based 当前步）**逐字一致**：同一组数据换个
    /// `presentation`，VoiceOver 的读法不该变。
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
        .modifier(CollapsedErrorValue(hasError: self.hasErrorStep))
    }

    /// `.segmentedBar` 的单段取色：error 走 danger，已完成走 `.tint`，其余走
    /// `Color.dividerDefault`（与连线同一套「完成/未完成」视觉语义）。
    private func segmentFill(for index: Int, item: StepItem) -> AnyShapeStyle {
        switch Self.segmentState(index: index, currentIndex: self.currentIndex, isError: item.isError) {
        case .error: AnyShapeStyle(Color.statusDangerEmphasis)
        case .filled: AnyShapeStyle(.tint)
        case .empty: AnyShapeStyle(Color.dividerDefault)
        }
    }

    /// `.segmentedBar` 单段的三态。非 `public`（同 `StepsProgress` 的可测试性取舍）。
    enum SegmentState: Equatable {
        case error
        case filled
        case empty
    }

    /// `.segmentedBar` 的单段判据。纯函数。
    ///
    /// ⚠️ **这个函数存在的唯一理由是可断言性**（PR #206 第 2 轮 review 抓到）：上一版把
    /// 判据直接写在 `segmentFill` 里返回 `AnyShapeStyle`，`ShapeStyle` 断言不了，于是
    /// 「守它」的测试只能改去断言 `progress(for:currentIndex:)` —— 而那个函数在 `main`
    /// 上就是对的、从没被改过。实测：把判据改回错误的 `index - 1`，整个测试套件**照样
    /// 403 全绿**。判据必须自己是可断言的，否则守卫是装饰。
    ///
    /// ⚠️ 判据是 `index < currentIndex`（即 `progress(for: index) == .done`）—— **每段对应
    /// 它自己那一步**。原错位写法在 `index > 0` 时取 `index - 1`，于是第 `index` 段跟着
    /// **前一步**走，`currentIndex == 1` 时未完成的第 1 段会因第 0 步已完成而被填充。
    static func segmentState(index: Int, currentIndex: Int, isError: Bool) -> SegmentState {
        if isError { return .error }
        return Self.progress(for: index, currentIndex: currentIndex) == .done ? .filled : .empty
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
        // ⚠️ 走 `.tint`（`TintShapeStyle`）不写死 `Color.accentColor` —— 后者读的是宿主 App
        // 的 asset，**不读** SwiftUI 的逐视图 `.tint(_:)` 环境值，于是
        // `Steps(..., presentation: .navigation).tint(.orange)` 会出现「指示器变了、当前块
        // 底色没变」的分裂（PR #206 review 抓到）。CLAUDE.md「`.core` style 的强调色必须走
        // `.tint` 通路」是同一条约定，本文件 `connectorFill(after:)` / `dotIndicator` 亦同。
        return self.progress(for: index) == .current
            ? AnyShapeStyle(TintShapeStyle.tint.opacity(0.12))
            : AnyShapeStyle(Color.clear)
    }

    /// `.text`：N 个指示器槽与标题槽连同连线塌成一个文本槽（Typeform 的「1 of 5」形态）。
    ///
    /// ⚠️ 本呈现下 `items` 的**逐条内容不被渲染**，只用其 `count` 与当前索引 —— 这正是
    /// 判定时把该候选判为「**槽**」（N 个槽塌成 1 个）的原因。
    ///
    /// ⚠️ **已知的信息损失，明文承认**（PR #206 第 2 轮 review 要求定案）：因为显示序号被
    /// 夹进 `1...count`，本形态下「停在最后一步」（`currentIndex == count - 1`）与「全部完成」
    /// （`currentIndex == count`，`init` 文档明列的正式用法）产出**同一段文案**，不可区分。
    /// 这是「N 个槽塌成 1 个文本槽」的固有代价：一个文本槽装不下「当前位置」+「是否全部完成」
    /// 两位信息。需要区分这两个状态的调用方应改用 `.segmentedBar`（末段填充与否可见）或
    /// `.steps`，而不是在本形态上加旁路。
    private var textBody: some View {
        self.progressCaption
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: self.progressText))
            .modifier(CollapsedErrorValue(hasError: self.hasErrorStep))
    }

    /// `.segmentedBar` / `.text` 这两种**塌成单个 element** 的呈现的 `accessibilityValue`。
    ///
    /// ⚠️ PR #206 review 抓到的无障碍回归：这两种呈现把整棵树塌成一个 label 只带
    /// `progressText`，于是 `StepItem.isError` 对 VoiceOver **完全消失** —— 而
    /// `.steps` / `.navigation` 走 `applyStepAccessibility(_:index:)` 是逐步播报
    /// 已登记键 `"Error"` 的。红色段 / 纯文本摘要在视觉上还能看出出错，读屏用户则拿不到
    /// 任何线索。⇒ 在**不展开**塌陷（那会毁掉这两种呈现的存在理由）的前提下，用容器级
    /// `accessibilityValue` 把「这组步骤里存在错误步」这一位信息补回来。
    ///
    /// ⚠️ 复用 `applyStepAccessibility` 那条通路的**同一个**已登记键 `"Error"`，不另造
    /// 「有错误」之类的新文案 —— 同一组数据在四种呈现下 VoiceOver 用词不该分裂。
    private var hasErrorStep: Bool {
        self.items.contains(where: \.isError)
    }

    /// 塌陷呈现的错误态 `accessibilityValue` 文案。纯函数，便于单测锁定「无错误步 ⇒ nil」。
    static func collapsedValueText(hasError: Bool) -> String? {
        hasError ? String(localized: "Error", bundle: .module) : nil
    }

    /// `.segmentedBar` 与 `.text` 共用的进度文案。
    private var progressCaption: some View {
        Text(verbatim: self.progressText)
            .coreFont(.footnote)
            .foregroundStyle(Color.contentSecondary)
    }

    /// 进度文案与无障碍标签共用的文本（A 类：文案写在组件源码里，调用方不传）。
    ///
    /// ⚠️ 公约第 3 节规定 A 类**应用 `LocalizedStringResource`**，但本仓目前**零先例**，
    /// 该迁移由 `wxlpp/oh-my-story#49` 统一做（公约缺口 G-4：「A 类有规定、无判据、
    /// 无参考实现」）。⇒ 本组件**不单独引入新模式** —— 一个组件先迁会让本仓同时存在两套
    /// A 类写法，而 #49 要收的正是这种分裂。迁移时本处随其余 A 类文案一并改。
    private var progressText: String {
        Self.progressSummary(currentIndex: self.currentIndex, total: self.items.count)
    }

    /// `.segmentedBar` / `.text` 的进度摘要。纯函数，便于单测锁定越界与退化边界
    /// （`.text` 呈现的**全部**可观察产出就是这一个字符串，见 `StepsTests`）。
    ///
    /// ⚠️ **复用 Phase 0 已登记键** `"%@ of %@"`（`positionText(current:total:)`），
    /// 不另造 `"Step %@ of %@"`：后者在 `Resources/en.lproj/Localizable.strings` 里
    /// **没有条目**，`String(localized:bundle:)` 会静默 fallback 到 key 自身，英文下输出
    /// 恰好像对的、直到非英文本地化才暴露（PR #206 review 抓到，与 `positionText` /
    /// `Rating.accessibilityValueText` 那条「漏传 bundle 静默 fallback」是同族陷阱）。
    /// ⇒ 顺带让 `.text` 的产出与逐步 `accessibilityValue` 的「2 of 4」**逐字一致**。
    ///
    /// ⚠️ **显示序号对越界 `currentIndex` 做 clamp**：`init` 文档明说存储层不 clamp、
    /// 允许传 `items.count`（全部完成）乃至负值，`progress(for:)` 对越界仍能正确求值；
    /// 但**显示用**的序号必须落在 `1...total` —— 负索引会读成「-3 of 3」，而裸
    /// `currentIndex + 1` 在 `Int.max` 上直接 trap（PR #206 review 抓到）。先夹到
    /// `0...(total - 1)` 再 `+ 1`，两端都不会溢出。
    /// `total == 0`（空 `items`）退化为「0 of 0」，不构造出不存在的第 1 步。
    static func progressSummary(currentIndex: Int, total: Int) -> String {
        guard total > 0 else { return Self.positionText(current: 0, total: 0) }
        let step = min(max(currentIndex, 0), total - 1) + 1
        return Self.positionText(current: step, total: total)
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

/// `.segmentedBar` / `.text` 的错误态 `accessibilityValue` 挂载器（`private`，仅本文件）。
///
/// ⚠️ 无错误步时**整个不挂载**，而不是挂一个空字符串 —— 后者会让 VoiceOver 在 label
/// 之后读出一个空值停顿，且把「没有错误」和「有一个读不出名字的值」混为一谈。这与
/// `applyStepAccessibility(_:index:)` 对逐步 value 的处理（`nil` 时走不挂载分支）同口径。
private struct CollapsedErrorValue: ViewModifier {
    let hasError: Bool

    func body(content: Content) -> some View {
        if let value = Steps.collapsedValueText(hasError: self.hasError) {
            content.accessibilityValue(Text(verbatim: value))
        } else {
            content
        }
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

                // MARK: `#60` 形态 D2 新增的三种呈现
                // ⚠️ PR #206 review 指出新形态只有 `_ = body` 构造测试、预览仍只画默认形态。
                // 以下逐形态 + 边界数据补齐。
                // 本仓的快照流水线**只生成 PNG、不做基线比对** —— `scripts/run-snapshots.sh`
                // 经 `App/Tests/SnapshotTests.swift`（`SnapshottingTests`）收集 `#Preview` 出图，但没有
                // 「与基线逐像素比对然后判红」的那一步 ⇒ **它检测不了视觉回归**，只是把图摆出来供人看。
                // 且默认模式只保留 `App/Sources/Previews.swift` 驱动的 `CoreDesignPreview_*`，库内
                // `#Preview` 产出的 `CoreDesign_*` 会被 `find -delete` 删掉（要留得加 `KEEP_LIBRARY_SNAPSHOTS=1`，
                // 且只落本地 scratch）。⇒ 新形态**已同步注册进 `App/Sources/Previews.swift`**，否则进不了流水线。

                self.section("分段条 · segmentedBar") {
                    Steps(items: Self.basicItems, currentIndex: 2, presentation: .segmentedBar)
                }

                self.section("分段条 · 含错误态（红段 + VoiceOver 播报 Error）") {
                    Steps(items: Self.errorItems, currentIndex: 2, presentation: .segmentedBar)
                }

                self.section("分段条 · 边界：currentIndex 越界为负") {
                    Steps(items: Self.basicItems, currentIndex: -3, presentation: .segmentedBar)
                }

                self.section("导航式 · navigation · 横向") {
                    Steps(items: Self.basicItems, currentIndex: 1, axis: .horizontal, presentation: .navigation)
                }

                self.section("导航式 · navigation · 纵向 · 含错误态") {
                    Steps(items: Self.errorItems, currentIndex: 2, axis: .vertical, presentation: .navigation)
                }

                self.section("导航式 · .tint(.orange)（当前块底色须跟着变）") {
                    Steps(items: Self.basicItems, currentIndex: 1, presentation: .navigation)
                        .tint(.orange)
                }

                self.section("纯文本 · text") {
                    Steps(items: Self.basicItems, currentIndex: 1, presentation: .text)
                }

                self.section("纯文本 · 边界：currentIndex == count —— 与停在末步产出相同（已知损失）") {
                    Steps(items: Self.basicItems, currentIndex: Self.basicItems.count, presentation: .text)
                }

                self.section("纯文本 · 边界：空 items") {
                    Steps(items: [], currentIndex: 0, presentation: .text)
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
