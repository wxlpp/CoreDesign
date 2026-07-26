//
//  Carousel.swift
//  CoreDesign
//

import SwiftUI

// MARK: - Carousel

/// **材质层**: 内容. **表面角色**: 内容.
///
/// 走马灯——**单一跨端实现**：`ScrollView(.horizontal)` + `.scrollTargetBehavior(.paging)` +
/// `scrollPosition(id:)` 驱动分页滚动，**不使用** iOS-only 的 `TabView(.page)`
/// （`PageTabViewStyle` 在 macOS 上不可用，会违反 epic NFR-2「双端单一实现，不留单端公开
/// 符号」）。手势滑动直接复用原生 `ScrollView` 手势，无需自定义 `DragGesture`；取舍记录见
/// `docs/components/carousel.md`。
///
/// ## 自动轮播与手动滑动的协调
///
/// 自动轮播由 `.task(id: selection)` 驱动（issue #171 Technical Details 方案 2，非方案 1 的
/// `.onScrollPhaseChange` 拖拽态探测）：`selection` 每次变化——无论来自用户滑动手势结算，
/// 还是本组件自身的定时推进——都会让 SwiftUI **取消旧 task、以新 id 重启**，因此手动滑动后
/// 自动获得"重新计时"的效果，不需要额外的 `@State private var isUserInteracting` 标志位。
/// 计时逻辑本身（睡眠 `interval` 后推进、末尾回绕到首个）抽成 `nextID(after:in:)` 静态纯
/// 函数，可脱离 SwiftUI 运行时单测（见 `Tests/CoreDesignTests/CarouselTests.swift`）。
///
/// ```swift
/// Carousel(items, autoAdvance: true, interval: .seconds(4)) { item in
///     CardView(item)
/// }
///
/// Carousel(items, autoAdvance: false) { item in
///     CardView(item)
/// }
/// ```
public struct Carousel<Data: RandomAccessCollection, ID: Hashable, Content: View>: View where Data.Element: Identifiable, Data.Element.ID == ID {
    private let data: Data
    private let autoAdvance: Bool
    private let interval: Duration
    private let content: (Data.Element) -> Content

    @State private var selection: ID?

    /// Reduce Motion 开启时不启动自动轮播（WCAG 2.2.2：>5s 自动更新内容须可暂停；
    /// 走马灯没有终端用户级暂停手段，故按系统偏好关掉自动推进，仅保留手势/页点跳转）。
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 页点命中区内衬：把 `CoreSpacing.xs`(4pt) 视觉圆点的隐形命中 frame 撑到 44pt（`(44-4)/2`）。
    private static var pageDotHitInset: CGFloat {
        (CoreControlMetrics.height(for: .regular) - CoreSpacing.xs) / 2
    }

    /// - Parameters:
    ///   - data: 走马灯页数据源，元素须 `Identifiable`。
    ///   - autoAdvance: 是否自动轮播，默认 `true`。置 `false` 时完全不启动定时循环，
    ///     仅保留手势滑动与页点跳转。
    ///   - interval: 自动轮播间隔，默认 4 秒。`autoAdvance == false` 时不生效。
    ///   - content: 单页内容构建闭包。
    public init(
        _ data: Data,
        autoAdvance: Bool = true,
        interval: Duration = .seconds(4),
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.data = data
        self.autoAdvance = autoAdvance
        self.interval = interval
        self.content = content
        // 初始选中首个元素，而非留 nil——否则页点指示器与 VoiceOver 位置播报在首帧
        // 没有"当前页"可言。`@State` 初值只在这个 View 值第一次被 SwiftUI 实例化时生效。
        self._selection = State(initialValue: data.first?.id)
    }

    private var ids: [ID] {
        self.data.map(\.id)
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(self.data) { element in
                        self.content(element)
                            .containerRelativeFrame(.horizontal)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: self.$selection)
            .scrollIndicators(.hidden)

            if self.ids.count > 1 {
                self.pageIndicator
                    .padding(.bottom, CoreSpacing.sm)
            }
        }
        // 方案 2（见类型文档）：`selection` 一变化就取消旧 task、以新 id 重启，
        // 手动滑动与自动推进走同一条重计时路径。
        .task(id: self.selection) {
            await self.tickAutoAdvance()
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - 自动轮播

    /// `.task(id: selection)` 驱动的单次 tick：睡眠 `interval` 后推进到下一页，写回
    /// `selection` 触发 SwiftUI 用新 id 重启本 task，形成周期循环。`Task.sleep` 抛出
    /// （视图消失 / id 再次变化导致取消）或取消标志在睡眠后为真时都直接返回，不推进。
    private func tickAutoAdvance() async {
        // Reduce Motion 关自动轮播；`interval <= .zero` 会形成 sleep(0)→推进→重启的高频自旋，防护掉。
        guard self.autoAdvance, !self.reduceMotion, self.interval > .zero else { return }
        let ids = self.ids
        guard ids.count > 1 else { return }
        do {
            try await Task.sleep(for: self.interval)
        } catch {
            return
        }
        guard !Task.isCancelled else { return }
        withAnimation {
            self.selection = Self.nextID(after: self.selection, in: ids)
        }
    }

    /// 回绕推进的纯逻辑：末尾元素后回绕到首个；当前 id 为 `nil` 或已不在 `ids` 中时
    /// 回落到首个（防御式处理外部数据在轮播期间发生变化的情况）；空集合返回 `nil`；
    /// 单元素集合恒返回该元素自身。抽成 `static` 纯函数，脱离 SwiftUI 运行时即可单测
    /// （issue #171 Technical Details 明确要求）。
    static func nextID(after current: ID?, in ids: [ID]) -> ID? {
        guard !ids.isEmpty else { return nil }
        guard let current, let index = ids.firstIndex(of: current) else { return ids.first }
        let nextIndex = ids.index(after: index)
        return nextIndex < ids.endIndex ? ids[nextIndex] : ids.first
    }

    // MARK: - 页点指示器

    private var pageIndicator: some View {
        HStack(spacing: CoreSpacing.xs) {
            ForEach(Array(self.ids.enumerated()), id: \.element) { index, id in
                let isCurrent = id == self.selection
                Button {
                    withAnimation {
                        self.selection = id
                    }
                } label: {
                    Circle()
                        // 当前页走 `.tint`（`TintShapeStyle`，反映环境 tint，不写死
                        // `Color.accent`——FR-3）；其余页走 `Color.fill`（Phase 0 §1 未
                        // 覆盖走马灯，沿用既有"细小形状叠加填充"语义，与 Steps 的
                        // pending 描边同一层级）。
                        .fill(isCurrent ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.fill))
                        .frame(width: CoreSpacing.xs, height: CoreSpacing.xs)
                        // 命中区扩到 44pt：对称 `padding` 撑开命中 frame + 负 `padding` 抵消布局
                        // （`Tag` 同款手法）——圆点视觉与胶囊布局不变，仅隐形命中区放大到 44×44。
                        // 相邻页点命中区会横向重叠，符合页点作为 scrubber 式控件的交互（精确点单点
                        // 非主交互，主交互是滑动/就近落点）。
                        .padding(Self.pageDotHitInset)
                        .contentShape(Rectangle())
                        .padding(-Self.pageDotHitInset)
                }
                .buttonStyle(.plain)
                // 「第 N / 共 M 页」——Phase 0 预登记的位置键 `"%@ of %@"`
                // （`.claude/epics/semi-mobile-components/phase0-decisions.md` §2），
                // 两端均为 `Int.formatted()`，不新增 `Localizable.strings` 键。
                .accessibilityLabel(Text(Self.positionText(index: index + 1, count: self.ids.count)))
                .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(.horizontal, CoreSpacing.sm)
        .padding(.vertical, CoreSpacing.xs)
        .glassEffect(.regular, in: Capsule())
    }

    /// 页点 accessibility label 文案组装：Phase 0 位置键 `"%@ of %@"`，两端均
    /// `Int.formatted()`。`index` 为 1-based（如「3 of 5」），与 `PinCode.positionText` /
    /// `Rating.accessibilityValueText` 同一告诫——`bundle: .module` 漏传会静默 fallback到
    /// key 自身格式，英文输出恰好一样，只有非英文本地化才暴露，故抽成纯函数便于单测锁定。
    static func positionText(index: Int, count: Int) -> String {
        String(localized: "\(index.formatted()) of \(count.formatted())", bundle: .module)
    }
}

// MARK: - Previews

#Preview("Carousel — Light") {
    CarouselPreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("Carousel — Dark") {
    CarouselPreviewGallery()
        .preferredColorScheme(.dark)
}

private struct CarouselPreviewGalleryItem: Identifiable {
    let id: Int
    let title: String
    let color: Color
}

private struct CarouselPreviewGallery: View {
    private let cards: [CarouselPreviewGalleryItem] = [
        CarouselPreviewGalleryItem(id: 0, title: "第一页", color: .blue),
        CarouselPreviewGalleryItem(id: 1, title: "第二页", color: .purple),
        CarouselPreviewGalleryItem(id: 2, title: "第三页", color: .orange),
        CarouselPreviewGalleryItem(id: 3, title: "第四页", color: .green),
        CarouselPreviewGalleryItem(id: 4, title: "第五页", color: .pink),
    ]

    private let singleCard: [CarouselPreviewGalleryItem] = [
        CarouselPreviewGalleryItem(id: 0, title: "唯一一页", color: .teal),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CoreSpacing.xl) {
                VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                    Text("自动轮播（默认 4s / 5 张卡）").coreFont(.footnote).foregroundStyle(.secondary)
                    Carousel(self.cards) { item in
                        self.card(item)
                    }
                    .frame(height: 160)
                }

                VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                    Text("autoAdvance: false（仅手势滑动 / 点击页点跳转）").coreFont(.footnote).foregroundStyle(.secondary)
                    Carousel(self.cards, autoAdvance: false) { item in
                        self.card(item)
                    }
                    .frame(height: 160)
                }

                VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                    Text("单张边界态（无页点指示器）").coreFont(.footnote).foregroundStyle(.secondary)
                    Carousel(self.singleCard, autoAdvance: false) { item in
                        self.card(item)
                    }
                    .frame(height: 160)
                }

                VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                    Text(".tint(.red) 覆盖——当前页页点随 tint 变化").coreFont(.footnote).foregroundStyle(.secondary)
                    Carousel(self.cards, autoAdvance: false) { item in
                        self.card(item)
                    }
                    .frame(height: 160)
                    .tint(.red)
                }
            }
            .padding()
        }
        .background(Color.surfaceCanvas)
    }

    private func card(_ item: CarouselPreviewGalleryItem) -> some View {
        CoreShape.rounded(CoreRadius.large)
            .fill(item.color.gradient)
            .overlay {
                Text(item.title)
                    .coreFont(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, CoreSpacing.xs)
    }
}
