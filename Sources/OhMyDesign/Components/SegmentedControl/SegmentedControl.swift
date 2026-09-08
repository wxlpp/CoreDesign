import SwiftUI
#if os(iOS)
import UIKit
#endif

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
public protocol SegmentedControlStyle {
    associatedtype Body: View

    @ViewBuilder
    @MainActor @preconcurrency
    func makeBody(configuration: Self.Configuration) -> Body

    typealias Configuration = SegmentedControlStyleConfiguration
}

// MARK: - SegmentedControl

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
    var ink: Bool = false

    @Environment(\.coreAccent) private var resolvedAccent
    @Namespace private var namespace

    var body: some View {
        let shape = Capsule(style: .continuous)
        return HStack(spacing: CoreSpacing.xxs) {
            ForEach(self.configuration.segments) { segment in
                self.segmentView(segment)
            }
        }
        .padding(CoreSpacing.xxs)
        .frame(maxWidth: .infinity)
        .modifier(SegmentedControlBackgroundModifier(shape: shape, glass: self.glass))
        .frame(height: CoreControlMetrics.height(for: .regular))
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
                .foregroundStyle(self.foregroundStyle(for: segment))
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

    private func foregroundStyle(
        for segment: SegmentedControlStyleConfiguration.Segment
    ) -> Color {
        guard segment.isSelected else { return .contentSecondary }
        return self.ink ? .contentOnAccent : .contentPrimary
    }

    @ViewBuilder
    private var selectedThumb: some View {
        let shape = Capsule(style: .continuous)
        if self.ink {
            shape.fill(self.resolvedAccent)
        } else if self.glass {
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
    public nonisolated init() {}

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
    public nonisolated init() {}

    public func makeBody(configuration: Configuration) -> some View {
        SwiftUISegmentedControl(configuration: configuration, glass: false)
    }
}

/// 墨色外观：选中段是实心 `coreAccent` 胶囊 + 反色文字（`contentOnAccent`）。
///
/// ⚠️ **不是默认**——默认仍是 `GlassSegmentedControlStyle`。web 版设计系统用墨色胶囊
/// 是因为浏览器渲染不了 Liquid Glass，那是渲染基座的代偿而非升级。
///
/// ⚠️ 走 SwiftUI 回退路径，**不走** iOS 的 `NativeGlassSegmentedControl`：后者的选中态
/// 只有 `selectedSegmentTintColor` 一个入口，塞不进「实心填充 + 反色文字」。
public struct InkSegmentedControlStyle: SegmentedControlStyle {
    public nonisolated init() {}

    public func makeBody(configuration: Configuration) -> some View {
        SwiftUISegmentedControl(configuration: configuration, glass: false, ink: true)
    }
}

// MARK: - Style convenience

public extension SegmentedControlStyle where Self == GlassSegmentedControlStyle {
    /// 默认外观：Liquid Glass 外壳。
    nonisolated static var glass: GlassSegmentedControlStyle { GlassSegmentedControlStyle() }
}

public extension SegmentedControlStyle where Self == PlainSegmentedControlStyle {
    /// 纯色外壳外观。
    nonisolated static var plain: PlainSegmentedControlStyle { PlainSegmentedControlStyle() }
}

public extension SegmentedControlStyle where Self == InkSegmentedControlStyle {
    /// 墨色外观：实心 accent 胶囊 + 反色文字。
    nonisolated static var ink: InkSegmentedControlStyle { InkSegmentedControlStyle() }
}

// MARK: - Environment entry

extension EnvironmentValues {
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
