//
//  SegmentedControl.swift
//  CoreDesign
//
//  Created by AnyWriter on 2026/4/14.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

/// 分段控件玻璃壳的共享构造（审计项 B8g）。
///
/// `selectedThumb` 的 glass 分支与 `SegmentedControlBackgroundModifier` 的 glass
/// 分支此前各自复制同一段「透明填充 + 交互玻璃 + 细描边」；抽此一处，thumb 侧再叠
/// `.coreShadow(.small)`。
@ViewBuilder
private func segmentedGlassChrome<S: InsettableShape>(_ shape: S) -> some View {
    shape
        .fill(.clear)
        .glassEffect(.regular.interactive(), in: shape)
        .overlay(
            shape.strokeBorder(Color.borderSubtle, lineWidth: CoreBorderWidth.hairline)
        )
}

// MARK: - SegmentedControlStyleConfiguration

/// 传给 `SegmentedControlStyle.makeBody` 的上下文：类型擦除的分段数据 + 选择回调。
///
/// `Item` 泛型在此收敛为「index + 展示文字 + 选中态」，让 style 能同时驱动 iOS 原生
/// `UISegmentedControl`（收 `[String]` + index）与 SwiftUI 回退路径（按 index 重建）。
public struct SegmentedControlStyleConfiguration {
    /// 单个分段的类型擦除表示。
    public struct Segment: Identifiable {
        public let index: Int
        public let title: String
        public let isSelected: Bool
        public var id: Int { self.index }

        public init(index: Int, title: String, isSelected: Bool) {
            self.index = index
            self.title = title
            self.isSelected = isSelected
        }
    }

    public let segments: [Segment]
    /// 选中第 `index` 段的回调（由 `SegmentedControl` 注入，内部做 `withAnimation` + 越界保护）。
    public let select: (Int) -> Void

    public init(segments: [Segment], select: @escaping (Int) -> Void) {
        self.segments = segments
        self.select = select
    }
}

// MARK: - SegmentedControlStyle

/// `SegmentedControl` 视觉外观的扩展点，形态对齐 `BannerStyle` / Apple `ButtonStyle`。
///
/// 实现该协议提供新外观，通过 `View.segmentedControlStyle(_:)` 注入子树。内置
/// `GlassSegmentedControlStyle`（默认，Liquid Glass 外壳）与 `PlainSegmentedControlStyle`
/// （纯色外壳）。此前的 `glass: Bool` 布尔 hack 升级为本协议（审计项 D7）。
public protocol SegmentedControlStyle {
    associatedtype Body: View

    @ViewBuilder
    @MainActor @preconcurrency
    func makeBody(configuration: Self.Configuration) -> Body

    typealias Configuration = SegmentedControlStyleConfiguration
}

// MARK: - SegmentedControl

/// Native Primer segmented control.
///
/// GitHub-like density on an Apple-native control surface. 外观由环境注入的
/// `SegmentedControlStyle` 决定，默认 `GlassSegmentedControlStyle`。
public struct SegmentedControl<Item: Hashable>: View {
    /// 创建分段控件。
    ///
    /// - Parameters:
    ///   - items: 选项数据源；`Item: Hashable`，用于 `selection` 比较与标识。
    ///   - selection: 当前选中项的双向绑定。
    ///   - title: 把 `Item` 映射到展示文字。
    public init(
        items: [Item],
        selection: Binding<Item>,
        title: @escaping (Item) -> String
    ) {
        self.items = items
        self._selection = selection
        self.title = title
    }

    public var body: some View {
        let segments = self.items.enumerated().map { index, item in
            SegmentedControlStyleConfiguration.Segment(
                index: index,
                title: self.title(item),
                isSelected: item == self.selection
            )
        }
        let configuration = SegmentedControlStyleConfiguration(segments: segments) { index in
            guard self.items.indices.contains(index) else { return }
            self.select(self.items[index])
        }
        return AnyView(self.style.makeBody(configuration: configuration))
    }

    @Binding private var selection: Item
    @Environment(\.segmentedControlStyle) private var style

    private let items: [Item]
    private let title: (Item) -> String

    private func select(_ item: Item) {
        withAnimation(.easeInOut(duration: 0.18)) {
            self.selection = item
        }
    }
}

// MARK: - SwiftUI body（两个内置 style 共用）

private struct SwiftUISegmentedControl: View {
    let configuration: SegmentedControlStyleConfiguration
    let glass: Bool

    @Namespace private var namespace

    var body: some View {
        let shape = Capsule(style: .continuous)
        return HStack(spacing: CoreSpacing.xxs) {
            ForEach(self.configuration.segments) { segment in
                self.segmentView(segment)
            }
        }
        // 保留原 `swiftUISegmentedControl` 的 inset（SegmentedControl.swift:74）——
        // 让 segments/thumb 从玻璃外壳边缘缩进，形成「track 内浮起 thumb」的观感。
        // 评审 Finding 1：迁移时漏掉会让 thumb 贴外壳（所有 SwiftUI 回退渲染 = iOS
        // Plain + 全 macOS 受影响；测试只测构造，四命令/iOS 命令都抓不到）。
        .padding(CoreSpacing.xxs)
        .frame(maxWidth: .infinity)
        .modifier(SegmentedControlBackgroundModifier(shape: shape, glass: self.glass))
        .frame(height: CoreControlMetrics.height(for: .regular))
        // 保留原 fallback 路径的选择触感（SegmentedControl.swift:84）——评审 Finding 2：
        // 无 `selection` 属性，改由选中 segment 的 index 驱动 trigger（Int? 可 Equatable）。
        .sensoryFeedback(.selection, trigger: self.configuration.segments.first(where: \.isSelected)?.index)
    }

    @ViewBuilder
    private func segmentView(_ segment: SegmentedControlStyleConfiguration.Segment) -> some View {
        Button {
            self.configuration.select(segment.index)
        } label: {
            Text(segment.title)
                .coreFont(.callout)
                .fontWeight(segment.isSelected ? .semibold : .regular)
                .foregroundStyle(segment.isSelected ? Color.contentPrimary : Color.contentSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .background {
                    if segment.isSelected {
                        self.selectedThumb
                            .matchedGeometryEffect(id: "SegmentedControl.thumb", in: self.namespace)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(segment.isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var selectedThumb: some View {
        let shape = Capsule(style: .continuous)
        if self.glass {
            segmentedGlassChrome(shape)
                .coreShadow(.small)
        } else {
            shape
                .fill(Color.surfaceCanvasSubtle)
                .overlay(
                    shape.strokeBorder(Color.borderSubtle, lineWidth: CoreBorderWidth.hairline)
                )
                .coreShadow(.small)
        }
    }
}

// MARK: - Built-in styles

/// 默认外观：Liquid Glass 外壳。iOS 走原生 `UISegmentedControl` + `UIGlassEffect`，
/// 其他平台走玻璃版 SwiftUI 回退。
public struct GlassSegmentedControlStyle: SegmentedControlStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        #if os(iOS)
        NativeGlassSegmentedControl(
            titles: configuration.segments.map(\.title),
            selectedIndex: configuration.segments.first(where: \.isSelected)?.index,
            onSelect: configuration.select
        )
        .frame(maxWidth: .infinity)
        .frame(height: CoreControlMetrics.height(for: .regular))
        .sensoryFeedback(.selection, trigger: configuration.segments.firstIndex(where: \.isSelected))
        #else
        SwiftUISegmentedControl(configuration: configuration, glass: true)
        #endif
    }
}

/// 纯色外壳外观（此前 `glass: false`）。全平台走 SwiftUI 回退。
public struct PlainSegmentedControlStyle: SegmentedControlStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        SwiftUISegmentedControl(configuration: configuration, glass: false)
    }
}

// MARK: - Environment entry

extension EnvironmentValues {
    /// 当前生效的 `SegmentedControlStyle`，默认 `GlassSegmentedControlStyle`。
    @Entry var segmentedControlStyle: any SegmentedControlStyle = GlassSegmentedControlStyle()
}

public extension View {
    /// 为子树中的所有 `SegmentedControl` 设置外观（对齐 `View.bannerStyle(_:)`）。
    func segmentedControlStyle(_ style: some SegmentedControlStyle) -> some View {
        self.environment(\.segmentedControlStyle, style)
    }
}

#if os(iOS)
private struct NativeGlassSegmentedControl: UIViewRepresentable {
    let titles: [String]
    let selectedIndex: Int?
    let onSelect: (Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> NativeGlassSegmentedControlView {
        let view = NativeGlassSegmentedControlView()
        view.control.addTarget(
            context.coordinator,
            action: #selector(Coordinator.selectionChanged(_:)),
            for: .valueChanged
        )
        return view
    }

    func updateUIView(_ uiView: NativeGlassSegmentedControlView, context: Context) {
        context.coordinator.parent = self
        uiView.configure(titles: self.titles)

        let target = self.selectedIndex ?? UISegmentedControl.noSegment
        if uiView.control.selectedSegmentIndex != target {
            uiView.control.selectedSegmentIndex = target
        }

        uiView.updateForCurrentTraits()
    }

    final class Coordinator: NSObject {
        var parent: NativeGlassSegmentedControl

        init(parent: NativeGlassSegmentedControl) {
            self.parent = parent
        }

        @objc func selectionChanged(_ control: UISegmentedControl) {
            let index = control.selectedSegmentIndex
            guard index >= 0, index < self.parent.titles.count else { return }
            self.parent.onSelect(index)
        }
    }
}

private final class NativeGlassSegmentedControlView: UIView {
    let control = ImmediateFeedbackSegmentedControl(items: nil)

    private let glassView: UIVisualEffectView
    private var currentTitles: [String] = []

    override init(frame: CGRect) {
        let effect = UIGlassEffect()
        effect.isInteractive = true
        self.glassView = UIVisualEffectView(effect: effect)

        super.init(frame: frame)

        self.setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(titles: [String]) {
        guard titles != self.currentTitles else { return }
        self.currentTitles = titles

        self.control.removeAllSegments()
        for (index, title) in titles.enumerated() {
            self.control.insertSegment(withTitle: title, at: index, animated: false)
        }
    }

    func updateForCurrentTraits() {
        switch self.traitCollection.userInterfaceStyle {
        case .dark:
            self.control.selectedSegmentTintColor = .label.withAlphaComponent(0.15)
        default:
            self.control.selectedSegmentTintColor = .label.withAlphaComponent(0.08)
        }

        // 用 UIFontMetrics 让原生分段标题字号跟随 Dynamic Type 缩放，
        // 同时保留设计基线 15pt 与 weight 区分。
        let metrics = UIFontMetrics(forTextStyle: .body)
        let regularFont = metrics.scaledFont(for: UIFont.systemFont(ofSize: 15, weight: .regular))
        let selectedFont = metrics.scaledFont(for: UIFont.systemFont(ofSize: 15, weight: .semibold))

        self.control.setTitleTextAttributes(
            [
                .foregroundColor: UIColor.secondaryLabel,
                .font: regularFont,
            ],
            for: .normal
        )
        self.control.setTitleTextAttributes(
            [
                .foregroundColor: UIColor.label,
                .font: selectedFont,
            ],
            for: .selected
        )
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.glassView.cornerConfiguration = .capsule()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        self.updateForCurrentTraits()
    }

    private func setupViews() {
        self.backgroundColor = .clear

        self.glassView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(self.glassView)

        self.control.backgroundColor = .clear
        self.control.translatesAutoresizingMaskIntoConstraints = false
        self.glassView.contentView.addSubview(self.control)

        NSLayoutConstraint.activate([
            self.glassView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.glassView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            self.glassView.topAnchor.constraint(equalTo: self.topAnchor),
            self.glassView.bottomAnchor.constraint(equalTo: self.bottomAnchor),

            self.control.leadingAnchor.constraint(equalTo: self.glassView.contentView.leadingAnchor, constant: CoreSpacing.xxs),
            self.control.trailingAnchor.constraint(equalTo: self.glassView.contentView.trailingAnchor, constant: -CoreSpacing.xxs),
            self.control.topAnchor.constraint(equalTo: self.glassView.contentView.topAnchor, constant: CoreSpacing.xxs),
            self.control.bottomAnchor.constraint(equalTo: self.glassView.contentView.bottomAnchor, constant: -CoreSpacing.xxs),
        ])
    }
}

private final class ImmediateFeedbackSegmentedControl: UISegmentedControl {
    private var originalIndex: Int?

    private var shouldMoveIndicatorOnTouchDown: Bool {
        !self.traitCollection.preferredContentSizeCategory.isAccessibilityCategory
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // 隐藏 UISegmentedControl 自带的 UIImageView 装饰层（背景胶囊 + 分段间分隔
        // image），交由外层 `UIVisualEffectView(UIGlassEffect)` 容器统一提供玻璃
        // 材质——避免内置背景叠在外层玻璃上造成"玻璃中夹玻璃"的浑浊视觉。
        //
        // **已知风险**：依赖 UISegmentedControl 内部视图层级。尝试过
        // `setBackgroundImage(UIImage(), for:barMetrics:)` / `setDividerImage(...)`
        // 的 public API 路径，但在 iOS 26 上不能完全压制原生 Glass 背景图；遍历
        // UIImageView 是当前已知唯一可靠手段，后续 iOS 版本若改动私有层级需要
        // 复测此处。`selectedSegmentTintColor` 通过另一条路径渲染（不是
        // UIImageView 子视图），所以选中态仍可见。
        for subview in self.subviews where subview is UIImageView {
            subview.alpha = 0
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else {
            super.touchesBegan(touches, with: event)
            return
        }

        if self.shouldMoveIndicatorOnTouchDown {
            self.originalIndex = self.selectedSegmentIndex
            self.selectedSegmentIndex = self.segmentIndex(at: touch.location(in: self))
        }

        super.touchesBegan(touches, with: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else {
            super.touchesMoved(touches, with: event)
            return
        }

        if self.shouldMoveIndicatorOnTouchDown {
            self.selectedSegmentIndex = self.segmentIndex(at: touch.location(in: self))
        }

        super.touchesMoved(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if self.shouldMoveIndicatorOnTouchDown, let originalIndex {
            if self.selectedSegmentIndex != originalIndex {
                self.sendActions(for: .valueChanged)
            }
        }
        self.originalIndex = nil
        super.touchesEnded(touches, with: event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if self.shouldMoveIndicatorOnTouchDown, let originalIndex {
            self.selectedSegmentIndex = originalIndex
        }
        self.originalIndex = nil
        super.touchesCancelled(touches, with: event)
    }

    private func segmentIndex(at point: CGPoint) -> Int {
        guard self.numberOfSegments > 0, self.bounds.width > 0 else { return UISegmentedControl.noSegment }
        let segmentWidth = self.bounds.width / CGFloat(self.numberOfSegments)
        return min(max(Int(point.x / segmentWidth), 0), self.numberOfSegments - 1)
    }
}
#endif

private struct SegmentedControlBackgroundModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    let glass: Bool

    func body(content: Content) -> some View {
        if self.glass {
            // `.fill(.clear)`：让 .glassEffect 自己提供材质，不在底下叠任何 tint
            // ——SegmentedControl 走的是"纯玻璃容器"形态，配合 thumb 那层玻璃
            // 形成一致的两层玻璃叠加视觉，而不是 FloatingGlass / BottomInputBar 那
            // 种"玻璃覆盖在 .background.opacity(0.64) 之上"的混合形态。
            // 因为没有 tint 底色需要从玻璃壳下"透出"，所以也不需要 `glassInset`
            // 的内缩（它专门服务于 Telegram 分层按钮的纵深效果）。
            content
                .background(segmentedGlassChrome(self.shape))
        } else {
            content
                .background(
                    self.shape.fill(Color.surfaceInteractive)
                )
                .overlay(
                    self.shape.strokeBorder(Color.borderSubtle, lineWidth: CoreBorderWidth.hairline)
                )
        }
    }
}

#Preview {
    struct PreviewHost: View {
        @State private var selection = "A"
        var body: some View {
            VStack(spacing: 16) {
                SegmentedControl(
                    items: ["A", "B"],
                    selection: self.$selection,
                    title: { $0 }
                )
                SegmentedControl(
                    items: ["世界观", "设定", "大纲"],
                    selection: self.$selection,
                    title: { $0 }
                )
            }
            .padding()
        }
    }
    return PreviewHost()
}

/// 窄列填充验证：模拟 macOS 4-列工作区 sidebar / inspector 的宽度约束
/// （sidebar ≥220pt、inspector ≥260pt），确认 `SegmentedControl` 不会缩到
/// intrinsic 宽度，而是撑满列宽。详见 issue #82。
#Preview("Narrow container fill (220pt / 320pt)") {
    struct NarrowFillHost: View {
        @State private var sidebarSelection = "卷一"
        @State private var inspectorSelection = "Edit"
        var body: some View {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sidebar column — 220pt")
                        .coreFont(.caption)
                        .foregroundStyle(Color.contentMuted)
                    SegmentedControl(
                        items: ["卷一", "卷二", "卷三"],
                        selection: self.$sidebarSelection,
                        title: { $0 }
                    )
                    .frame(width: 220)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Inspector column — 320pt")
                        .coreFont(.caption)
                        .foregroundStyle(Color.contentMuted)
                    SegmentedControl(
                        items: ["Edit", "Outline", "Notes"],
                        selection: self.$inspectorSelection,
                        title: { $0 }
                    )
                    .frame(width: 320)
                }
            }
            .padding()
        }
    }
    return NarrowFillHost()
}
