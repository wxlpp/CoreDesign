//
//  Skeleton.swift
//  CoreDesign
//

import SwiftUI

// MARK: - Skeleton

/// **材质层**: 内容. **表面角色**: 内容.
///
/// 骨架屏容器：`isLoading` 为 `true` 时展示占位形状树，为 `false` 时展示调用方通过
/// `@ViewBuilder content` 传入的真实内容，两者用 `.animation` 平滑过渡。
///
/// 占位形状树自动套上两层叠加：`.redacted(reason: .placeholder)`（语义标记，向环境
/// 广播 `redactionReasons`，供系统 / 无障碍与未来可能的子视图识别"这是占位内容"；
/// 对 `SkeletonLine` / `SkeletonRect` / `SkeletonCircle` 这类纯色填充形状**本身没有
/// 内建的视觉效果**——`.redacted` 的自动灰条渲染只作用于 `Text` / `Image`，可见的
/// 占位观感完全来自形状自身的 `Color.skeletonBase` 填充）+ `.skeletonShimmer()`
/// （实际产生扫光动效的一层）。
///
/// 占位形状树由 `SkeletonLine` / `SkeletonRect` / `SkeletonCircle` 组合而成——三者均可
/// 独立使用，也可以任意 `HStack` / `VStack` 拼装成复合骨架布局（如"头像 + 两行文本"），
/// `Skeleton` 只负责在这棵占位树与真实内容之间做切换，不限定占位树的具体形状组合。
///
/// 取色遵循 semi-mobile-components Phase 0 定案：底色 `Color.skeletonBase`
/// （= `.fill`，系统 `systemFill`）、shimmer 高光 `Color.skeletonHighlight`
/// （= 底色 `.opacity(0.35)`），见 `Colors/FillColors.swift`——**不新增 colorset**。
///
/// ```swift
/// Skeleton(isLoading: viewModel.isLoading) {
///     HStack(alignment: .top, spacing: CoreSpacing.md) {
///         SkeletonCircle(diameter: 40)
///         SkeletonLine(lineCount: 2)
///     }
/// } content: {
///     HStack(alignment: .top, spacing: CoreSpacing.md) {
///         Avatar(url: viewModel.avatarURL)
///         VStack(alignment: .leading, spacing: CoreSpacing.xs) {
///             Text(viewModel.name)
///             Text(viewModel.subtitle).foregroundStyle(.secondary)
///         }
///     }
/// }
/// ```
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
                    // 语义标记（见类型文档），非视觉效果的来源。
                    .redacted(reason: .placeholder)
                    .skeletonShimmer()
                    // 占位形状树对 VoiceOver 无意义（形状本身不携带信息），整体收敛成
                    // 一个 "Loading" 播报——复用已在 `ProgressIndicator` 登记的键
                    // （Phase 0 附表未单列 Skeleton 专属键，此为已登记键的复用，非新增）。
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
///
/// 最后一行默认收窄到 `lastLineWidthFraction`（默认 70%），模拟真实段落"最后一行
/// 不占满整宽"的观感；`lineCount == 1` 时不生效（单行按 `1.0` 全宽渲染，与多行时的
/// "最后一行"语义冲突，避免单行占位显得像被截断）。
///
/// 收窄用外层 `GeometryReader` 量出容器宽度、再按比例算出显式 `frame(width:)`——
/// 而不是对胶囊形状做 `.scaleEffect(x:)`：非等比缩放会把两端半圆压成椭圆，
/// 在 `lineHeight` 较大（视觉上更接近真实文本行）时尤其明显失真。
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

    /// 某一行的显式宽度：末行按 `lastLineWidthFraction` 收窄，其余行占满容器宽度。
    /// `internal` 而非 `private`：供 `@testable` 单测直接断言（与
    /// `Separator.Inset.leadingAmount` 的既有先例一致）。
    func width(forLineAt index: Int, containerWidth: CGFloat) -> CGFloat {
        self.isLastLine(index) ? containerWidth * self.lastLineWidthFraction : containerWidth
    }

    /// 整个占位形状树的总高度（供外层 `GeometryReader` 给出确定高度，
    /// `GeometryReader` 自身在纵轴无内在尺寸）。
    var totalHeight: CGFloat {
        CGFloat(self.lineCount) * self.lineHeight + CGFloat(max(0, self.lineCount - 1)) * self.spacing
    }

    /// 是否为"最后一行"收窄档位——仅多行（`lineCount > 1`）时的末行生效。
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
///
/// `width == nil`（默认）时撑满父容器宽度，贴近图片 / 卡片占位常见的"跟随容器宽度"用法；
/// 指定 `width` 时按固定宽度渲染。
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
    ///
    /// 高光色取 `Color.skeletonHighlight`（Phase 0 定案，`skeletonBase.opacity(0.35)`
    /// 派生，不新增 colorset）。尊重 `accessibilityReduceMotion`——开启时跳过动画，
    /// 只保留静态占位底色，不产生持续运动。
    ///
    /// `Skeleton` 已在其占位分支自动叠加本 modifier，调用方通常不需要手动调用；
    /// 独立使用 `SkeletonLine` / `SkeletonRect` / `SkeletonCircle` 而不经过 `Skeleton`
    /// 容器时，可直接 `.skeletonShimmer()` 追加扫光效果。
    ///
    /// > Note: 内部把传入的 `content` 渲染了两次（一次作为可见基座，一次经 `.mask`
    /// > 限定渐变带的可见范围）。对本组件设计的无状态纯色形状没有副作用；若把
    /// > `.skeletonShimmer()` 用在携带 `@State` 的内容上，两份拷贝会各自持有独立状态。
    func skeletonShimmer() -> some View {
        self.modifier(SkeletonShimmerModifier())
    }
}

private struct SkeletonShimmerModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if self.reduceMotion {
            // 减弱动态效果：只保留静态占位底色，不叠加持续运动的扫光。
            content
        } else {
            content
                .overlay {
                    // `.periodic(from:by:)` 而非 `.animation`：骨架屏典型用法是列表里
                    // 多行同时渲染（每行各自持有一个 `TimelineView`），`.animation` 会
                    // 让每个实例都以屏幕最高刷新率重算；扫光周期本身是 1.4s 的慢扫，
                    // ~30fps（33ms 一帧）已远超肉眼可辨分辨率，多实例场景下更省电。
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
                    // 把渐变带遮罩到与占位形状相同的轮廓，扫光不会溢出形状边界。
                    .mask(content)
                    .allowsHitTesting(false)
                }
        }
    }
}

/// Shimmer 扫光的相位计算，从 `ViewModifier.body` 中抽出成纯函数——`internal` 而非
/// `private`：供 `@testable` 单测直接断言数值（渲染树本身无法用 Swift Testing 断言），
/// 与 `Separator.Inset.leadingAmount` 的既有先例一致。
enum SkeletonShimmerMath {
    /// 扫光周期（秒）。1.4s——足够慢以避免视觉抖动，足够快以持续传达"加载中"。
    static let duration: TimeInterval = 1.4

    /// 给定时间点与容器宽度，返回渐变带的横向偏移量：周期性地从 `-width` 扫到 `+width`，
    /// 到达终点后从头重复（`TimelineView(.periodic)` 每 tick 重新求值，无需 `repeatForever`）。
    ///
    /// `width <= 0` 时返回 `0`（尚未布局出真实宽度前的占位帧，不产生跳变）。
    ///
    /// > Note: 假定 `date.timeIntervalSinceReferenceDate >= 0`（`TimelineView` 提供的
    /// > 时间点恒成立）。早于参考日期（2001-01-01）的输入会让 `truncatingRemainder`
    /// > 结果为负、越过 `[-width, width]` 边界——调用方均来自 `TimelineView`，实际不可达。
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
                            Text("CoreDesign 是一个 SwiftUI 设计系统")
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
                                Text("CoreDesign 维护者").coreFont(.footnote).foregroundStyle(.secondary)
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
