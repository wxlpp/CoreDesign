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

// MARK: - SegmentedControl

/// Native Primer segmented control.
///
/// The component keeps GitHub-like utility and density while rendering as an
/// Apple-native control surface. The base uses a restrained Liquid Glass shell
/// by default; only the selected segment gets a lightly raised thumb.
public struct SegmentedControl<Item: Hashable>: View {
    /// 创建分段控件。
    ///
    /// - Parameters:
    ///   - items: 选项数据源；`Item` 必须 `Hashable`，用于 `selection` 比较与
    ///     `ForEach` 标识。
    ///   - selection: 当前选中项的双向绑定。
    ///   - glass: 是否使用 Liquid Glass 外壳；默认 `true`。
    ///   - title: 把 `Item` 映射到展示文字的闭包。
    public init(
        items: [Item],
        selection: Binding<Item>,
        glass: Bool = true,
        title: @escaping (Item) -> String
    ) {
        self.items = items
        self._selection = selection
        self.glass = glass
        self.title = title
    }

    /// 视图主体：横向 HStack 排列分段，外框走 `surfaceInteractive` 容器，
    /// thumb 通过 `matchedGeometryEffect` 在选中分段间无缝滑动。
    @ViewBuilder
    public var body: some View {
        #if os(iOS)
        if self.glass {
            NativeGlassSegmentedControl(
                items: self.items,
                selection: self.$selection,
                title: self.title
            )
            // `maxWidth: .infinity` 让控件填充父容器宽度。`UISegmentedControl` 自带
            // intrinsic content size 会让 SwiftUI 默认采用紧凑宽度；在窄约束容器
            // （≤240pt 的 sidebar / inspector 列、固定宽度的工具栏槽）里会观察到
            // 分段控件不撑满。`.frame(height:)` 已经处理纵向，这里补齐横向行为。
            .frame(maxWidth: .infinity)
            .frame(height: CoreControlMetrics.height(for: .regular))
            .sensoryFeedback(.selection, trigger: self.selection)
        } else {
            self.swiftUISegmentedControl
        }
        #else
        self.swiftUISegmentedControl
        #endif
    }

    private var swiftUISegmentedControl: some View {
        let shape = Capsule(style: .continuous)
        return HStack(spacing: CoreSpacing.xxs) {
            ForEach(self.items, id: \.self) { item in
                self.segment(for: item)
            }
        }
        .padding(CoreSpacing.xxs)
        // `maxWidth: .infinity` 必须在 `SegmentedControlBackgroundModifier` 之前 —
        // SwiftUI `.background` / `.overlay` 按修饰链顺序对当时内容尺寸取背景框，
        // 若把宽度撑开放在 background 之后，胶囊 / 描边会停留在 intrinsic 宽度，
        // 形成"内容撑满 + 背景没撑满"的视觉错位。每个 segment 内部已有
        // `.frame(maxWidth: .infinity)`，但外层 HStack 仍需显式声明，以在部分
        // 父容器（VStack / Grid）里得到稳定的横向铺满行为。
        .frame(maxWidth: .infinity)
        .modifier(SegmentedControlBackgroundModifier(shape: shape, glass: self.glass))
        .frame(height: CoreControlMetrics.height(for: .regular))
        .sensoryFeedback(.selection, trigger: self.selection)
    }

    @Binding private var selection: Item
    @Namespace private var namespace

    private let items: [Item]
    private let glass: Bool
    private let title: (Item) -> String

    @ViewBuilder
    private func segment(for item: Item) -> some View {
        let isSelected = self.selection == item
        // 用 Button 而非 Text+onTapGesture：让 SwiftUI fallback 路径继承
        // 系统按钮的键盘激活 / focus ring / pressed 状态 / hover 反馈，
        // 对 macOS 键盘用户和辅助技术尤其重要。`.plain` 抹掉系统按钮默认装饰，
        // 由我们的 background thumb 与 foregroundStyle 主导视觉。
        Button {
            self.select(item)
        } label: {
            Text(self.title(item))
                .coreFont(.bodyMedium)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? Color.contentPrimary : Color.contentSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .background {
                    if isSelected {
                        self.selectedThumb
                            .matchedGeometryEffect(id: "SegmentedControl.thumb", in: self.namespace)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var selectedThumb: some View {
        let shape = Capsule(style: .continuous)
        if self.glass {
            // `.fill(.clear)` 是有意的：thumb 叠在 SegmentedControlBackgroundModifier
            // 的玻璃外壳之上，再加底色会让两层玻璃变浑浊。仅靠 .glassEffect + 细描边
            // + 小阴影区分选中态——与 FloatingGlass / TelegramGlass 那种"玻璃覆盖
            // 在不透明 tint 之上"的形态有意不同。
            shape
                .fill(.clear)
                .glassEffect(.regular.interactive(), in: shape)
                .overlay(
                    shape.strokeBorder(
                        Color.borderSubtle,
                        lineWidth: CoreBorderWidth.hairline
                    )
                )
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

    private func select(_ item: Item) {
        withAnimation(.easeInOut(duration: 0.18)) {
            self.selection = item
        }
    }
}

#if os(iOS)
private struct NativeGlassSegmentedControl<Item: Hashable>: UIViewRepresentable {
    let items: [Item]
    @Binding var selection: Item
    let title: (Item) -> String

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
        uiView.configure(titles: self.items.map(self.title))

        // selection 不在 items 时回退到 `noSegment`：避免 UI 显示第一个分段被选中
        // 而 binding 仍持有 items 外值导致状态错位的"假选中"。
        let selectedIndex = self.items.firstIndex(of: self.selection) ?? UISegmentedControl.noSegment
        if uiView.control.selectedSegmentIndex != selectedIndex {
            uiView.control.selectedSegmentIndex = selectedIndex
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
            guard index >= 0, index < self.parent.items.count else { return }
            self.parent.selection = self.parent.items[index]
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
                .background(
                    self.shape
                        .fill(.clear)
                        .glassEffect(.regular.interactive(), in: self.shape)
                )
                .overlay(
                    self.shape.strokeBorder(Color.borderSubtle, lineWidth: CoreBorderWidth.hairline)
                )
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
