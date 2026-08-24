//
//  SpinningModifier.swift
//  CoreDesign
//

import SwiftUI

// MARK: - SpinningPresentation

/// `spinning` 的**呈现形态**。
///
/// 判定依据：`docs/component-contract.md` §2 形态 **D2（配置枚举）**。⚠️ **D1 事实上不可用**：
/// 本类型是 `ViewModifier` 而非 `View`，没有可挂 `@ViewBuilder` 外观槽的 `init` 参数位
///（`body(content:)` 的 `content` 是被修饰的内容，属**内容槽**，公约明文排除）。
/// ⇒ D 的两个子形态里只剩 D2。
///
/// ⚠️ 候选 1「骨架屏占位替换」**已被兄弟 `Skeleton` 正当排除**（其 `notes` 自述是占位/真实
/// 内容切换容器），故本枚举只承载候选 2 / 3 + 现状。
public enum SpinningPresentation: Sendable, Equatable {
    /// 默认：材质遮罩铺满内容 + 居中指示器（现状形态）。
    case overlay
    /// 容器顶边的细进度条，不铺遮罩。
    /// 业界来源：NProgress / YouTube 顶条 / GitHub Turbo。
    case topBar
    /// 原位行内指示器，不铺遮罩。
    /// 业界来源：Ant Design Spin 的非包裹用法 / MUI CircularProgress。
    case inline
}

// MARK: - SpinningModifier

/// 为任意内容叠加加载指示（吸收 Semi Design `Spin` 能力，Issue #172）。
///
/// ⚠️ 上面这段组件说明**必须紧贴本 struct**：它原先写在 `SpinningPresentation` 的文档块
/// 正上方且两块之间没有分隔，于是 Swift 把**整块**注释归给了那个枚举，`SpinningModifier`
/// 自己反而没有组件级 DocC（PR #206 review 抓到）。改动本文件头部时别把两块又并回去。
///
/// **交互与无障碍契约按 `presentation` 分岔**（`#60` 引入 `.topBar` / `.inline` 后不再
/// 全局成立，PR #206 review 抓到原文档把 `.overlay` 的阻塞语义写成了整个 modifier 的）：
///
/// - `.overlay`（默认）：`isActive == true` 时底层内容对交互与 VoiceOver **都不可达**
///   （`.allowsHitTesting(false)` + `.accessibilityHidden(true)`），上覆半透明
///   `.regularMaterial` 遮罩 + 居中的 `ProgressIndicator`（`text` 非 nil 时带文案）。
///   `isActive == false` 时内容原样渲染——遮罩视图整体条件渲染，不常驻空遮罩。
/// - `.topBar` / `.inline`：**非阻塞**。底层内容始终可交互、对 VoiceOver 始终可达；
///   激活时只在顶边加一条细进度条 / 在行内追加一个指示器。表达的是「后台正在加载、
///   内容仍可用」，而不是「此刻不可操作」。
///
/// **不直接包装系统 `ProgressView`**——遮罩内的 loading 视觉复用已经处理好
/// tint 的 `ProgressIndicator` 组件（本 Issue 第一部分产出），因此本文件**不落入**
/// `ProgressIndicator.swift` 的 FR-3a 例外范围：本文件若需要强调色，须正常走
/// `.tint`（当前实现无此需求）。
///
/// ```swift
/// ContentView()
///     .spinning(viewModel.isLoading)
///
/// ContentView()
///     .spinning(viewModel.isLoading, text: "Refreshing…")
///
/// ContentView()
///     .spinning(viewModel.isLoading, presentation: .topBar)
/// ```
public struct SpinningModifier: ViewModifier {
    public let isActive: Bool
    public let text: LocalizedStringKey?
    public let presentation: SpinningPresentation

    /// - Parameters:
    ///   - isActive: 是否显示。
    ///   - text: 指示器的可选文案。⚠️ `.topBar` 形态下**不生效** —— 顶条没有文案位；
    ///     存储层仍原样保留，切回其余形态时不丢配置（与 `Steps` / `Timeline` /
    ///     `AvatarGroup` 同一处置）。
    ///   - presentation: 呈现形态，默认 `.overlay`（现状形态）⇒ **现有调用方零影响**。
    public init(
        isActive: Bool,
        text: LocalizedStringKey? = nil,
        presentation: SpinningPresentation = .overlay
    ) {
        self.isActive = isActive
        self.text = text
        self.presentation = presentation
    }

    public func body(content: Content) -> some View {
        switch self.presentation {
        case .overlay: self.overlayBody(content)
        case .topBar: self.topBarBody(content)
        case .inline: self.inlineBody(content)
        }
    }

    /// `.topBar`：顶边细进度条，**不铺遮罩**。
    ///
    /// ⚠️ **不禁用底层交互、不隐藏无障碍** —— 这正是它与 `.overlay` 的语义差别：顶条表达
    /// 「后台正在加载」，内容仍可用；遮罩表达「此刻不可操作」。若照抄 `.overlay` 的
    /// `allowsHitTesting(false)`，就把一个非阻塞形态做成了阻塞形态。
    ///
    /// ⚠️ 顶条由 `TopBarIndicator` **自绘**，不用 `ProgressView().progressViewStyle(.linear)`
    /// —— 详见该类型的文档，那里记着为什么（PR #206 第 2 轮 review 抓到）。
    private func topBarBody(_ content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if self.isActive {
                    TopBarIndicator()
                        .transition(.opacity)
                }
            }
            .animation(.default, value: self.isActive)
    }

    /// `.inline`：原位行内指示器，**不铺遮罩**。
    ///
    /// ⚠️ 同 `.topBar`：非阻塞形态，不禁用交互。
    ///
    /// ⚠️ **`HStack` 常驻，`isActive == false` 时也包着内容** —— 这是有意的，不是漏改
    /// （PR #206 review 提出改为「非激活直接返回 `content`」）。改成 `if/else` 两个分支后，
    /// `isActive` 每次翻转都会换掉 `content` 的**视图身份**，SwiftUI 随之销毁重建被修饰的
    /// 整棵子树：`@State` 清零、输入焦点丢失、进行中的动画被打断。代价远大于「多包一层
    /// 单子视图 `HStack`」带来的对齐差异（单子视图的 `HStack` 把收到的 proposal 原样转交，
    /// 只有垂直对齐基准从容器默认变为 `.center`）。⇒ 记在文档里，不改结构。
    private func inlineBody(_ content: Content) -> some View {
        HStack(spacing: CoreSpacing.sm) {
            content
            if self.isActive {
                self.indicator
                    .transition(.opacity)
            }
        }
        .animation(.default, value: self.isActive)
    }

    /// `.overlay`：材质遮罩铺满 + 居中指示器（现状形态）。
    private func overlayBody(_ content: Content) -> some View {
        content
            // 遮罩激活时底层内容禁止交互——与下面的 accessibilityHidden 互相独立，
            // 各自覆盖各自的语义面（命中测试 vs. VoiceOver 可达性）。
            .allowsHitTesting(!self.isActive)
            .accessibilityHidden(self.isActive)
            .overlay {
                if self.isActive {
                    ZStack {
                        // `ContainerRelativeShape()` 而非 `Rectangle()`（Phase 3 / #173
                        // 收口项：直角材质遮罩会溢出圆角内容轮廓，如包在 `Card` 外时遮罩
                        // 四角比卡片本身更方）。`ContainerRelativeShape` 在调用方未显式声明
                        // `.containerShape(_:)` 时优雅退化为矩形（与旧行为一致，非破坏性），
                        // 调用方若想让遮罩贴合自身圆角，只需外加
                        // `.containerShape(CoreShape.rounded(CoreRadius.medium))` 一类声明，
                        // 不需要改本组件；`.clipShape` 是调用方侧的另一个可选逃生舱。
                        ContainerRelativeShape()
                            .fill(.regularMaterial)
                        self.indicator
                    }
                    .transition(.opacity)
                }
            }
            .animation(.default, value: self.isActive)
    }

    @ViewBuilder
    private var indicator: some View {
        if let text = self.text {
            ProgressIndicator(text: text)
        } else {
            ProgressIndicator()
        }
    }
}

/// `.topBar` 的顶边细进度条（internal）：一条 `.tint` 色的短条在顶边循环扫过。
///
/// ⚠️ **自绘而不是 `ProgressView().progressViewStyle(.linear)`**，三条理由
/// （PR #206 第 2 轮 review 抓到，上一版就是那样写的）：
///
/// 1. **它会推翻本文件与 epic 的明文决议**。`SpinningModifier` 的类型文档、
///    `docs/components/spinning.md` 的「FR-3a 例外范围说明」、
///    `.claude/epics/archived/semi-mobile-components/172.md` 三处都写着「本文件**不**直接
///    包装系统 `ProgressView`，因此**不落入** `ProgressIndicator` 的 FR-3a 例外范围」。
///    包一个进来，这三处当场失真。
/// 2. **会让同一个 API 的两个形态对 `.tint` 的响应分裂**。FR-3a 的成因正是「包装系统
///    `ProgressView` 时 `.tint(_:)` 的重载解析落到 SwiftUI 环境 accent 而非本库 accent」；
///    `.overlay` 走 `ProgressIndicator`（其内显式 `.tint(Color.accent)`）。于是
///    `.spinning(true, presentation: .topBar).tint(.orange)` 变橙、`.overlay` 不变 —— 同一
///    modifier 的两个形态行为不一致，且无人定案。
/// 3. **`.linear` 的不确定态渲染是未定案行为**。`ProgressView()` 无 `value` 即不确定态，
///    而本仓自己的 `CoreProgressViewStyle` 在不确定态是**退回系统环形 spinner** 的
///    （见该文件文档）—— 说明「线性 + 不确定」这个组合在本仓没有确定的视觉答案。押在它
///    身上，还恰好落在 `swift test` 照不到的 iOS 渲染腿上。
///
/// ⚠️ **自带 `accessibilityLabel`**：裸 `ProgressView()` 不带任何无障碍标签，切到
/// `.topBar` 后读屏用户对「开始加载 / 加载结束」拿不到任何信号 —— 而 `.overlay` 走的
/// `ProgressIndicator` 是自带 `"Loading"` 语义的。键 `"Loading"` 已在
/// `Localizable.strings` 注册，这里复用同一个，不另造文案。
/// ⚠️ `internal` 而非 `private`：`barWidthRatio` / `period` / `height` /
/// `offset(at:trackWidth:)` 要被 `@testable import` 的单测读到。与 `Steps.StepsProgress`
/// 同一取舍 —— 退一档到默认 internal，仍不出现在下游可见的公开 API 表面。
struct TopBarIndicator: View {
    /// 扫过的亮条占轨道宽度的比例。
    static let barWidthRatio: CGFloat = 0.3
    /// 扫一趟的周期（秒）。
    static let period: TimeInterval = 1.1
    /// 轨道底色相对 `.tint` 的不透明度。
    private static let trackOpacity: Double = 0.2

    var body: some View {
        GeometryReader { proxy in
            let barWidth = proxy.size.width * Self.barWidthRatio
            ZStack(alignment: .leading) {
                // ⚠️ **轨道必须常驻**：没有它时，「顶条存在」这件事完全取决于亮条此刻扫到哪 ——
                // 相位落在两端时条整个在视口外、被 `.clipped()` 裁掉，看上去就是**什么都没有**。
                // 上一版正是这样：初始 `offset(x: -barWidth)` ⇒ 静态快照里 `.topBar` 完全不可见
                // （PR #206 第 3 轮 review 预判、随后被快照实测证实）。
                Capsule().fill(.tint.opacity(Self.trackOpacity))

                TimelineView(.animation) { context in
                    Capsule()
                        // ⚠️ `.tint` 不写死 `Color.accent`（FR-12 / ADR-3）—— 与 `.overlay`
                        // 形态经 `ProgressIndicator` 得到的强调色通路保持一致。
                        .fill(.tint)
                        .frame(width: barWidth)
                        .offset(x: Self.offset(at: context.date, trackWidth: proxy.size.width))
                }
            }
        }
        .frame(height: Self.height)
        .clipped()
        .accessibilityElement()
        .accessibilityLabel(Text("Loading", bundle: .module))
    }

    /// 顶条高度。⚠️ 取 `CoreSpacing.xs`（4pt）而非 `xxs`（2pt）：2pt 在高分屏上淡到几乎看不见，
    /// 且常见顶条（NProgress / YouTube / Turbo）都在 3–4pt。形状用 `Capsule` 而不是
    /// `CoreShape.rounded(CoreRadius.small)` —— 6pt 圆角作用在 4pt 高上必然被夹成胶囊，
    /// 写一个永远取不到的半径是无效表达（PR #206 第 3 轮 review）。
    static let height: CGFloat = CoreSpacing.xs

    /// 亮条在给定时刻的水平位移。**纯函数** —— 便于单测锁定「相位覆盖整条轨道且首尾衔接」。
    ///
    /// ⚠️ 用 `TimelineView(.animation)` 按时钟求相位，**不用** `@State` + `.onAppear` +
    /// `.repeatForever`：后者的动画要在「插入」与「状态翻转」两次更新之间正确挂上才会动，
    /// 是 SwiftUI 里出名的「首帧不动」高发形态，而它一旦不动就退化成一条静止色条 —— 恰是
    /// 换掉 `ProgressView(.linear)` 想避开的结局。按时钟算则没有时序前提，也天然可测。
    static func offset(at date: Date, trackWidth: CGFloat) -> CGFloat {
        let barWidth = trackWidth * Self.barWidthRatio
        let elapsed = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: Self.period)
        let phase = CGFloat(elapsed / Self.period)
        // 从「完全在左侧视口外」扫到「完全在右侧视口外」。
        return -barWidth + (trackWidth + barWidth) * phase
    }
}

public extension View {
    /// 为内容整体叠加加载遮罩。见 `SpinningModifier`。
    ///
    /// - Parameters:
    ///   - isActive: 是否显示遮罩。
    ///   - text: 指示器的可选文案，默认 `nil`（不带文案）。⚠️ `.topBar` 形态下不生效。
    ///   - presentation: 呈现形态，默认 `.overlay`（现状形态）⇒ **现有调用方零影响**。
    ///     ⚠️ `.topBar` / `.inline` 是**非阻塞**形态：不禁用底层交互、不隐藏无障碍，
    ///     语义是「后台正在加载、内容仍可用」，与 `.overlay` 的「此刻不可操作」不同。
    func spinning(
        _ isActive: Bool,
        text: LocalizedStringKey? = nil,
        presentation: SpinningPresentation = .overlay
    ) -> some View {
        self.modifier(SpinningModifier(isActive: isActive, text: text, presentation: presentation))
    }
}

#Preview("spinning — Light") {
    SpinningModifierPreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("spinning — Dark") {
    SpinningModifierPreviewGallery()
        .preferredColorScheme(.dark)
}

private struct SpinningModifierPreviewGallery: View {
    var body: some View {
        VStack(spacing: CoreSpacing.xl) {
            VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                Text("isActive: false（正常渲染，无遮罩）")
                    .coreFont(.footnote)
                    .foregroundStyle(Color.contentSecondary)
                self.card
                    .spinning(false)
            }

            VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                Text("isActive: true（无文案）")
                    .coreFont(.footnote)
                    .foregroundStyle(Color.contentSecondary)
                self.card
                    .spinning(true)
            }

            VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                Text("isActive: true（带文案）")
                    .coreFont(.footnote)
                    .foregroundStyle(Color.contentSecondary)
                self.card
                    .spinning(true, text: "Refreshing…")
            }

            // MARK: `#60` 形态 D2 新增的两种呈现
            // ⚠️ PR #206 review 指出新形态既无渲染测试、预览又只画默认 `.overlay`，
            // 于是「非阻塞」这一核心语义（内容仍可点、顶条/行内指示器位置）无人可见。
            // ⚠️ **光栅快照也证不了这条语义** —— PNG 里看不出 `allowsHitTesting` 与
            // `accessibilityHidden`。那两位只能靠 iOS 腿的交互/无障碍检查，本仓目前没有。
            // 本仓的快照流水线**只生成 PNG、不做基线比对** —— `scripts/run-snapshots.sh`
            // 经 `App/Tests/SnapshotTests.swift`（`SnapshottingTests`）收集 `#Preview` 出图，但没有
            // 「与基线逐像素比对然后判红」的那一步 ⇒ **它检测不了视觉回归**，只是把图摆出来供人看。
            // 且默认模式只保留 `App/Sources/Previews.swift` 驱动的 `CoreDesignPreview_*`，库内
            // `#Preview` 产出的 `CoreDesign_*` 会被 `find -delete` 删掉（要留得加 `KEEP_LIBRARY_SNAPSHOTS=1`，
            // 且只落本地 scratch）。⇒ 新形态**已同步注册进 `App/Sources/Previews.swift`**，否则进不了流水线。

            VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                Text(".topBar（顶边细条，内容不被遮罩、仍可交互）")
                    .coreFont(.footnote)
                    .foregroundStyle(Color.contentSecondary)
                self.card
                    .spinning(true, presentation: .topBar)
            }

            VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                Text(".inline（行内指示器；非激活时 HStack 常驻，几何不跳变）")
                    .coreFont(.footnote)
                    .foregroundStyle(Color.contentSecondary)
                HStack(spacing: CoreSpacing.lg) {
                    Text("保存中").coreFont(.callout).spinning(true, presentation: .inline)
                    Text("已保存").coreFont(.callout).spinning(false, presentation: .inline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(Color.surfaceCanvas)
    }

    private var card: some View {
        Card {
            VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                Text("卡片标题").coreFont(.headline)
                Text("被 spinning 遮罩覆盖时应保持自身尺寸不变。")
                    .coreFont(.subheadline)
                    .foregroundStyle(Color.contentSecondary)
            }
        }
    }
}
