import SwiftUI

// MARK: - Carousel

/// **材质层**: 内容. **表面角色**: 内容.
public struct Carousel<Data: RandomAccessCollection, ID: Hashable, Content: View>: View where Data.Element: Identifiable, Data.Element.ID == ID {
    private let data: Data
    private let autoAdvance: Bool
    private let interval: Duration
    private let content: (Data.Element) -> Content

    @State private var selection: ID?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        .task(id: self.selection) {
            await self.tickAutoAdvance()
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - 自动轮播

    private func tickAutoAdvance() async {
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
                        .fill(isCurrent ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.fill))
                        .frame(width: CoreSpacing.xs, height: CoreSpacing.xs)
                        .padding(.vertical, Self.pageDotHitInset)
                        .padding(.horizontal, CoreSpacing.xxs)
                        .contentShape(Rectangle())
                        .padding(.horizontal, -CoreSpacing.xxs)
                        .padding(.vertical, -Self.pageDotHitInset)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(Self.positionText(index: index + 1, count: self.ids.count)))
                .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(.horizontal, CoreSpacing.sm)
        .padding(.vertical, CoreSpacing.xs)
        .glassEffect(.regular, in: Capsule())
    }

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
