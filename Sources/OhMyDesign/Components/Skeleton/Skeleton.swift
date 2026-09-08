import SwiftUI

// MARK: - Skeleton

/// **材质层**: 内容. **表面角色**: 内容.
public struct Skeleton<Placeholder: View, Content: View>: View {
    /// 创建骨架屏容器。
    ///
    /// - Parameters:
    ///   - isLoading: `true` 展示 `placeholder`（占位形状树），`false` 展示 `content`（真实内容）。
    ///   - placeholder: 占位形状树，通常由 `SkeletonLine` / `SkeletonRect` / `SkeletonCircle`
    ///     组合而成。会被自动套上 `.redacted(reason: .placeholder)`（语义标记）与
    ///     `.skeletonShimmer()`（实际扫光动效），调用方无需自行叠加。
    ///   - content: `isLoading == false` 时展示的真实内容。
    public init(
        isLoading: Bool,
        @ViewBuilder placeholder: () -> Placeholder,
        @ViewBuilder content: () -> Content
    ) {
        self.isLoading = isLoading
        self.placeholder = placeholder()
        self.content = content()
    }

    public var body: some View {
        Group {
            if self.isLoading {
                self.placeholder
                    .redacted(reason: .placeholder)
                    .skeletonShimmer()
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("Loading", bundle: .module))
            } else {
                self.content
            }
        }
        .transition(.opacity)
        .animation(.default, value: self.isLoading)
    }

    let isLoading: Bool
    let placeholder: Placeholder
    let content: Content
}

// MARK: - SkeletonLine

/// 文本行占位形状：圆角矩形 + 固定高度，可指定条数模拟多行文本。
public struct SkeletonLine: View {
    /// - Parameters:
    ///   - lineCount: 行数，默认 `1`。小于 `1` 的输入会被 clamp 到 `1`。
    ///   - lineHeight: 每行高度（pt），默认 `12`，贴近 `.footnote` 行高。随
    ///     Dynamic Type 缩放（`@ScaledMetric(relativeTo: .footnote)`）——它代表的
    ///     是真实文本行，字号变大时占位高度也应跟着变大，否则 `isLoading` 切到
    ///     真实内容的一刻会有明显的布局跳变。
    ///   - spacing: 行间距，默认 `CoreSpacing.xs`（4pt）。
    ///   - lastLineWidthFraction: 最后一行宽度相对整宽的比例，默认 `0.7`。
    ///     仅在 `lineCount > 1` 时生效；clamp 到 `0...1`（`< 0` 会通过负宽度
    ///     产生未定义渲染，`> 1` 会溢出容器宽度，均无实际用途）。
    public init(
        lineCount: Int = 1,
        lineHeight: CGFloat = 12,
        spacing: CGFloat = CoreSpacing.xs,
        lastLineWidthFraction: CGFloat = 0.7
    ) {
        self.lineCount = max(1, lineCount)
        self._scaledLineHeight = ScaledMetric(wrappedValue: lineHeight, relativeTo: .footnote)
        self.spacing = spacing
        self.lastLineWidthFraction = min(max(lastLineWidthFraction, 0), 1)
    }

    public var body: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: self.spacing) {
                ForEach(0..<self.lineCount, id: \.self) { index in
                    CoreShape.rounded(self.lineHeight / 2)
                        .fill(Color.skeletonBase)
                        .frame(
                            width: self.width(forLineAt: index, containerWidth: proxy.size.width),
                            height: self.lineHeight
                        )
                }
            }
        }
        .frame(height: self.totalHeight)
    }

    func width(forLineAt index: Int, containerWidth: CGFloat) -> CGFloat {
        self.isLastLine(index) ? containerWidth * self.lastLineWidthFraction : containerWidth
    }

    var totalHeight: CGFloat {
        CGFloat(self.lineCount) * self.lineHeight + CGFloat(max(0, self.lineCount - 1)) * self.spacing
    }

    func isLastLine(_ index: Int) -> Bool {
        self.lineCount > 1 && index == self.lineCount - 1
    }

    let lineCount: Int
    @ScaledMetric private var scaledLineHeight: CGFloat
    let spacing: CGFloat
    let lastLineWidthFraction: CGFloat

    var lineHeight: CGFloat { self.scaledLineHeight }
}

// MARK: - SkeletonRect

/// 图片 / 卡片占位形状：矩形块，尺寸由调用方指定。
public struct SkeletonRect: View {
    /// - Parameters:
    ///   - width: 固定宽度（pt）。默认 `nil`，撑满父容器宽度。
    ///   - height: 固定高度（pt），默认 `120`。
    ///   - cornerRadius: 圆角半径，默认 `CoreRadius.medium`。
    public init(
        width: CGFloat? = nil,
        height: CGFloat = 120,
        cornerRadius: CGFloat = CoreRadius.medium
    ) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        CoreShape.rounded(self.cornerRadius)
            .fill(Color.skeletonBase)
            .frame(width: self.width, height: self.height)
            .frame(maxWidth: self.width == nil ? .infinity : nil)
    }

    let width: CGFloat?
    let height: CGFloat
    let cornerRadius: CGFloat
}

// MARK: - SkeletonCircle

/// 头像占位形状：圆形，直径由调用方指定。
public struct SkeletonCircle: View {
    /// - Parameter diameter: 直径（pt），默认 `40`，贴近 `Avatar` 常用尺寸。
    public init(diameter: CGFloat = 40) {
        self.diameter = diameter
    }

    public var body: some View {
        Circle()
            .fill(Color.skeletonBase)
            .frame(width: self.diameter, height: self.diameter)
    }

    let diameter: CGFloat
}

// MARK: - Shimmer

public extension View {
    /// 骨架屏 shimmer 扫光叠加。以 `LinearGradient` 遮罩（`.mask`）配合随时间推进的
    /// 位移，在占位形状上方持续扫过一条高亮带，传达"仍在加载"的动态反馈。
    func skeletonShimmer() -> some View {
        self.modifier(SkeletonShimmerModifier())
    }
}

private struct SkeletonShimmerModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if self.reduceMotion {
            content
        } else {
            content
                .overlay {
                    TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { timeline in
                        GeometryReader { proxy in
                            let width = proxy.size.width
                            LinearGradient(
                                colors: [.clear, Color.skeletonHighlight, .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: width)
                            .offset(x: SkeletonShimmerMath.offset(at: timeline.date, width: width))
                        }
                    }
                    .mask(content)
                    .allowsHitTesting(false)
                }
        }
    }
}

enum SkeletonShimmerMath {
    static let duration: TimeInterval = 1.4

    static func offset(at date: Date, width: CGFloat) -> CGFloat {
        guard width > 0 else { return 0 }
        let progress = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: self.duration) / self.duration
        return CGFloat(progress) * (width * 2) - width
    }
}

// MARK: - Previews

#Preview("Skeleton — Light") {
    SkeletonPreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("Skeleton — Dark") {
    SkeletonPreviewGallery()
        .preferredColorScheme(.dark)
}

private struct SkeletonPreviewGallery: View {
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CoreSpacing.xl) {
                Toggle(isOn: self.$isLoading) {
                    Text("isLoading")
                }
                .tint(Color.accent)

                self.section("line（3 行，末行收窄）") {
                    Skeleton(isLoading: self.isLoading) {
                        SkeletonLine(lineCount: 3)
                    } content: {
                        VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                            Text("OhMyDesign 是一个 SwiftUI 设计系统")
                            Text("骨架屏用于内容加载态的占位展示")
                            Text("isLoading 切换占位与真实内容")
                        }
                        .coreFont(.footnote)
                    }
                }

                self.section("rect（图片 / 卡片占位）") {
                    Skeleton(isLoading: self.isLoading) {
                        SkeletonRect(height: 120)
                    } content: {
                        CoreShape.rounded(CoreRadius.medium)
                            .fill(Color.accent.opacity(0.2))
                            .frame(height: 120)
                            .overlay(Text("真实内容").coreFont(.subheadline))
                    }
                }

                self.section("circle（头像占位）") {
                    Skeleton(isLoading: self.isLoading) {
                        SkeletonCircle(diameter: 48)
                    } content: {
                        Circle()
                            .fill(Color.accent)
                            .frame(width: 48, height: 48)
                    }
                }

                self.section("组合：头像 + 两行文本") {
                    Skeleton(isLoading: self.isLoading) {
                        HStack(alignment: .top, spacing: CoreSpacing.md) {
                            SkeletonCircle(diameter: 40)
                            SkeletonLine(lineCount: 2)
                        }
                    } content: {
                        HStack(alignment: .top, spacing: CoreSpacing.md) {
                            Circle()
                                .fill(Color.accent)
                                .frame(width: 40, height: 40)
                            VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                                Text("王晓龙").coreFont(.subheadline)
                                Text("OhMyDesign 维护者").coreFont(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
