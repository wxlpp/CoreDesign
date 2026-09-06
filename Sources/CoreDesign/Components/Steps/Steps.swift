import SwiftUI

// MARK: - StepItem

/// 单个步骤的数据模型：标题（必填）+ 可选描述 + 错误标记。
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

    enum StepsProgress: Equatable {
        case pending
        case current
        case done
    }

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

    private func segmentFill(for index: Int, item: StepItem) -> AnyShapeStyle {
        switch Self.segmentState(index: index, currentIndex: self.currentIndex, isError: item.isError) {
        case .error: AnyShapeStyle(Color.statusDangerEmphasis)
        case .filled: AnyShapeStyle(.tint)
        case .empty: AnyShapeStyle(Color.dividerDefault)
        }
    }

    enum SegmentState: Equatable {
        case error
        case filled
        case empty
    }

    static func segmentState(index: Int, currentIndex: Int, isError: Bool) -> SegmentState {
        if isError { return .error }
        return Self.progress(for: index, currentIndex: currentIndex) == .done ? .filled : .empty
    }

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

    private func navigationBlock(for index: Int) -> some View {
        let item = self.items[index]
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

    private func navigationBlockFill(for index: Int, item: StepItem) -> AnyShapeStyle {
        if item.isError { return AnyShapeStyle(Color.statusDangerEmphasis.opacity(0.12)) }
        return self.progress(for: index) == .current
            ? AnyShapeStyle(TintShapeStyle.tint.opacity(0.12))
            : AnyShapeStyle(Color.clear)
    }

    private var textBody: some View {
        self.progressCaption
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: self.progressText))
            .modifier(CollapsedErrorValue(hasError: self.hasErrorStep))
    }

    private var hasErrorStep: Bool {
        self.items.contains(where: \.isError)
    }

    static func collapsedValueText(hasError: Bool) -> String? {
        hasError ? String(localized: "Error", bundle: .module) : nil
    }

    private var progressCaption: some View {
        Text(verbatim: self.progressText)
            .coreFont(.footnote)
            .foregroundStyle(Color.contentSecondary)
    }

    private var progressText: String {
        Self.progressSummary(currentIndex: self.currentIndex, total: self.items.count)
    }

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

    @ViewBuilder
    private func connector(after index: Int) -> some View {
        if self.progress(for: index) == .done {
            Rectangle().fill(.tint)
        } else {
            Rectangle().fill(Color.dividerDefault)
        }
    }

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

    static func accessibilityLabelText(title: String, description: String?) -> String {
        guard let description, !description.isEmpty else { return title }
        return "\(title): \(description)"
    }

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

    static func positionText(current: Int, total: Int) -> String {
        String(localized: "\(current.formatted()) of \(total.formatted())", bundle: .module)
    }
}

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
