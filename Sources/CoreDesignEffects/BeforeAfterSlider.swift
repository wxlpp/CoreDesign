//
//  BeforeAfterSlider.swift
//  CoreDesignEffects
//
//  前后对比滑块 / A draggable before-after comparison slider.
//

import CoreDesign
import SwiftUI

// MARK: - 本 target 的 chrome 文案入口

// ⚠️ **本 target 必须自带 `Resources/en.lproj/Localizable.strings` 才拿得到译文**
//（`CoreDesignCharts` 的评审 C-5 立的同一条）：没有资源目录时
// `LocalizedStringResource("Before")` 只能落到 `Bundle.main`（宿主 App）
// ⇒ 本包**永远无法为自己的 chrome 文案提供翻译**。
//
// ⚠️ **别把这条写成「没有 `Package.swift` 里的 `resources:` 就没有 `Bundle.module`」**
// ——那句话在 `CoreDesignCharts` 上已被实测证伪：本包设了 `defaultLocalization: "en"`，
// SwiftPM 会自动把 `*.lproj` 当本地化资源收进去。那一行是**显式声明**，不是必需品；
// 真正不可省的是**资源文件本身**与下面的 `bundle:` 实参。

extension LocalizedStringResource {

    /// 本 target 自带 chrome 文案的唯一入口（公约 §4 **A 类** ⇒ `LocalizedStringResource`）。
    ///
    /// ⚠️ `bundle:` 不能省——省了就回到 `Bundle.main`，等于没做本地化。
    ///
    /// ⚠️ **刻意 `internal`**：它把 key 绑死在本 target 的 `Bundle.module`，下游传自己的
    /// key 必然查不到，而查不到时 Foundation **原样返回 key、不报错** ⇒ 提为 `public`
    /// 只会让下游静默丢本地化（`ChartSupport.chart(_:)` 记着同一条裁决）。
    static func effectsChrome(_ key: String.LocalizationValue) -> Self {
        LocalizedStringResource(key, bundle: .atURL(Bundle.module.bundleURL))
    }
}

// MARK: - 标签取值域

/// `BeforeAfterSlider` 两侧标签的取值域。
///
/// ## ⚠️ 为什么不是 `showLabels: Bool`（J-1 / FR-6）
///
/// 上游 ShipSwift 的签名是 `showLabels: Bool`。本仓公约第 3 节禁止裸配置 `Bool`，
/// 而 `shipswift-harvest` 的 **FR-6** 逐字点名了这个参数：「上游的 `showLabels: Bool` /
/// `autoReset: Bool` / `isActive: Binding<Bool>` **一律不得照搬**」。
///
/// ⚠️ **本枚举也不是"把 Bool 换成两 case enum"**——那是公约第 3 节点名的**头号反例**
///（`docs/component-contract.md`「把 Bool 换成两 case enum **不是**替代路径」）。
/// 它是**三档且带载荷**的取值域：`Bool` 表达不了「显示，但用调用方给的文案」这一档，
/// 而那一档正是这个组件现实中最常用的形态（"原图 / 修图后"、"Draft / Final"）。
/// ⇒ 走的是「专用参数 + 取值域枚举」这条替代路径，**没有**动用本 epic 的豁免预算。
///
/// ## 文案类型：两档各按公约走各自的类别
///
/// | 档 | 文案来源 | 公约 §4 类别 | 类型 |
/// |---|---|---|---|
/// | `.standard` | **写在本组件源码里**，调用方看不见也改不了 | **A 类** | `LocalizedStringResource`（经本 target 的 `Bundle.module`） |
/// | `.shown(before:after:)` | 调用方传入的界面文案 | **B 类** | `LocalizedStringKey`（公约第 4 节裁决：新增 B 类用 LSK） |
///
/// ⚠️ **两档用不同类型不是不一致，正是公约要求的**：A 类与 B 类在公约里本来就落在
/// 不同的类型列上。把默认文案也做成 `LocalizedStringKey` 会让它去查**宿主 App** 的表
/// ——本包自己的译文永远命不中；反过来把调用方参数做成 `LocalizedStringResource`
/// 又与第 4 节「新增 B 类参数用 `LocalizedStringKey`」的成文裁决相反
///（`.rise(text:)` 正是按那条落的）。
public enum BeforeAfterSliderLabels {

    /// 不显示标签。
    case hidden

    /// 显示**组件自带**的默认文案（"Before" / "After"，公约 §4 A 类）。
    case standard

    /// 显示**调用方给定**的文案（公约 §4 B 类）。
    case shown(before: LocalizedStringKey, after: LocalizedStringKey)

    /// 默认的"之前"文案。
    ///
    /// ⚠️ **`internal` 且是 `LocalizedStringResource`**：它是 A 类兜底文案的
    /// 「可独立标注的缺省实体」（公约 #43-1 的正典形态，对照 StoryUI 的
    /// `ChapterStatus.defaultLabel`）。提为 `public` 会把一份 `Bundle.module` 绑死的
    /// key 交给下游，下游拿它查自己的表必然 miss 而且不报错。
    static let defaultBefore: LocalizedStringResource = .effectsChrome("Before")

    /// 默认的"之后"文案。见 `defaultBefore`。
    static let defaultAfter: LocalizedStringResource = .effectsChrome("After")
}

/// 本组件自带的 a11y chrome 文案（公约 §4 **A 类**）。
///
/// ⚠️ **单独放在一个非泛型类型上不是风格选择**：`BeforeAfterSlider` 是泛型，
/// 而 Swift 不允许泛型类型持有 static stored property
///（实测 `error: static stored properties not supported in generic types`）。
///
/// ⚠️ **提成常量而不是写在 `.accessibilityLabel(...)` 的实参里**：
/// `AccessibilityStringLiteralGuard` 扫的是 `.accessibility*(` 调用里的**字符串字面量**，
/// 而这里要的是一份走 `Bundle.module` 的 A 类 chrome 文案。提出来两边都不打架。
enum BeforeAfterSliderChrome {
    static let accessibilityTitle: LocalizedStringResource =
        .effectsChrome("Before and after comparison")
}

// MARK: - 入场摆动与几何（纯函数，生产代码与判据共用同一份）

/// 一次入场摆动的参数。**`nil` 表示不摆**（Reduce Motion）。
nonisolated struct BeforeAfterIntroSweep: Equatable, Sendable {
    /// 摆到的位置（归一化 `0...1`）。
    let peak: CGFloat
    /// 摆回并停住的位置。
    let settle: CGFloat
    /// 单程时长（秒）。
    let duration: Double
}

/// 分隔线的**几何与入场摆动契约**。
///
/// ⚠️ **抽出来的唯一理由是可测性**（与 `ConfettiBurst` / `ProcessingSweep` / `ShineBand`
/// 同一条纪律）。特别是 `introSweep(reduceMotion:)`：
/// `\.accessibilityReduceMotion` **不可注入**，「Reduce Motion 下不摆」这条 AC
/// 在位图上结构上不可观测，只能落在纯函数 + 调用点源码两条链上。
/// ⚠️ **不要把字面量写回视图层**——那会让判据重新变成"测试自说自话"。
nonisolated enum BeforeAfterSweep {

    /// 分隔线的初始 / 静止位置：正中。
    static let initialFraction: CGFloat = 0.5

    /// 入场摆动摆到的位置。
    static let sweepPeak: CGFloat = 0.78

    /// 入场摆动的单程时长（秒）。
    static let sweepDuration: Double = 0.55

    /// 把手的**命中尺寸**（pt）。
    ///
    /// ⚠️ 这是「触控目标 ≥ 44pt」这条 a11y 承诺的落点：把手的**视觉**宽度只有
    /// `handleDiameter`，靠 `frame` + `contentShape` 撑到这个尺寸
    ///（同 `CoreDesign` 里 `Rating` / `CheckBox` 的处置）。
    /// 判据在 `BeforeAfterSliderTests.handleHitSizeConstantMeetsMinimum`（平台无关）
    /// 与 `BeforeAfterSliderTouchTargetTests`（`#if os(iOS)`，实测渲染尺寸）。
    static let handleHitSize: CGFloat = 44

    /// 把手圆钮的视觉直径（pt）。
    static let handleDiameter: CGFloat = 28

    /// 分隔线宽度。
    static let dividerWidth: CGFloat = CoreBorderWidth.thick

    /// 本次入场摆动。**`nil` ⇒ 不摆。**
    ///
    /// ⚠️⚠️ **这是 AC「Reduce Motion ⇒ 停止自动摆动，但保留拖拽」的唯一裁决点。**
    /// 「保留拖拽」这一半**不在**这个函数里，而在于：`fraction(dragX:width:)` 是纯几何、
    /// 签名里根本**没有** `reduceMotion` 这个参数 ⇒ 拖拽在结构上就无从被门控。
    /// ⚠️ 降级**不是 no-op**：摆动只是一次"这里可以拖"的提示，去掉它组件照常可用；
    /// 若连拖拽一起关掉，这个组件在开启该偏好的用户手上就废了。
    static func introSweep(reduceMotion: Bool) -> BeforeAfterIntroSweep? {
        guard !reduceMotion else { return nil }
        return BeforeAfterIntroSweep(
            peak: Self.sweepPeak,
            settle: Self.initialFraction,
            duration: Self.sweepDuration
        )
    }

    /// 入场摆动的**回程**还该不该执行。**用户已经碰过把手 ⇒ 不执行。**
    ///
    /// ⚠️⚠️ **这条是 #253 PR #273 终审 I-6 的裁决点**：回程发生在 `sweepDuration × 2 ≈ 1.1s`
    /// 之后，而 `DragGesture.onChanged` 写的是**同一个** `fraction`。上一版两者无协调
    /// ⇒ 用户在扫掠途中抓住把手拖到别处，1.1s 一到会被 `withAnimation` 拽回 0.5。
    /// 对一个"就是要你马上抓"的组件，那 1.1s 是很现实的窗口。
    /// ⚠️ 摆动只是一次"这里可以拖"的**提示**；提示绝不能覆盖用户的显式输入。
    static func settlesAfterSweep(hasInteracted: Bool) -> Bool { !hasInteracted }

    /// 手指横坐标 → 分隔线位置，钳在 `0...1`。
    /// ⚠️ 宽度为 0（首帧 `GeometryReader` 尚未量到尺寸）时返回初始位置，**不产生 NaN**。
    static func fraction(dragX: CGFloat, width: CGFloat) -> CGFloat {
        guard width > 0 else { return Self.initialFraction }
        return Self.clamp01(dragX / width)
    }

    /// 分隔线位置 → **左侧**（"之前"）那一层的揭示宽度，也就是分隔线本身的横坐标。
    ///
    /// ⚠️ **上一版这行文档写的是「"之后"那一层的揭示宽度」，与 `init` 的语义相反**
    ///（#253 PR #273 终审 C-1）：`init` 文档逐字写着 `before` 露在**左**、`after` 露在**右**，
    /// 而绘制层把 `after` mask 到了 leading ⇒ 左右整个画反、默认标签把两半都标错。
    /// 现在以 `init` 的语义为准：leading 那一段是 `before`。
    static func revealWidth(fraction: CGFloat, width: CGFloat) -> CGFloat {
        Self.clamp01(fraction) * max(0, width)
    }

    /// 把手中心左侧应留出的布局宽度。
    ///
    /// ⚠️ **位置走布局宽度而不是 `offset`**：见 `BeforeAfterSliderBody` 的类型文档。
    static func leadingInset(fraction: CGFloat, width: CGFloat) -> CGFloat {
        max(0, Self.revealWidth(fraction: fraction, width: width) - Self.handleHitSize / 2)
    }

    static func clamp01(_ value: CGFloat) -> CGFloat { min(1, max(0, value)) }
}

// MARK: - 揭示裁剪（**裁剪**，不是 alpha 遮罩）

/// 把内容裁到 leading 侧 `width` 宽的那一段。
///
/// ⚠️⚠️ **为什么是 `clipShape` 而不是 `.mask { … }`**（Issue #276）：
/// 上一版走的是 `.mask(alignment: .leading) { Color.primary.frame(width: reveal) }`，
/// 注释宣称「`mask` 吃的是 alpha 通道，`.primary` 恒为不透明 ⇒ 与写死 `.white` 等效，
/// 但它是语义色」。**实测为假，照录更正**：`Color.primary` 映射到 `label` /
/// `labelColor`，**macOS 26** 明暗两端实测 **α = 0.8471**。这里是一张**完整揭示遮罩**、
/// 而且没有 `.opacity()` ⇒ 露出的「之前」那半在 macOS 上一直是以 84.7% 合成在
/// 「之后」那半上，也就是 macOS 腿上**可见的 ghosting**（对比越强的两张图越明显）。
/// ⚠️ **iOS 26 上 `label` 实测 α = 1.0 ⇒ iOS 腿上没有这枚 ghosting**
/// ——#276 正文写的「已发布组件里可见」在 iOS 上不成立，本轮 iOS 腿实测更正
/// （`MaskOpaqueTokenTests.primaryAlphaIsPlatformDependent`）。
/// 修它的理由因此不是"iOS 上坏了"，而是依赖一个未文档化、平台相关的 α 本身就是缺陷。
/// macOS 26 实测（红叠蓝、完全揭示、取中心像素）：
///
///     无遮罩              rgba=(255, 56, 60, 255)
///     mask(Color.primary) rgba=(216, 68, 90, 255)   ← 蓝透上来了
///     clipShape           rgba=(255, 56, 60, 255)   ← 与无遮罩逐字节相同
///
/// ⇒ **本处不换遮罩基色、直接不用遮罩**：`MaskReveal.swift` 的文件头已经把这条裁断
/// 写死了——「裁剪不涉及 alpha，揭示出来的像素就是内容原样的像素，不存在
///『揭示到 85%』这种状态」。同时顺带去掉一层离屏合成（与 PR #274 在
/// `SphereSurface` / `OrbitingLogos` 上的成法同向）。
/// ⚠️ 需要**空间上变化**的 alpha 场那一族（`AnimatedMeshGradient` 的网格、
/// `ProcessingSweep` 的两条扫光渐变）裁剪替代不了，那里走 `Color.maskOpaque`。
///
/// ## ⚠️ 换成裁剪之后**边缘的抗锯齿行为变了**，这一条本 PR 之前没记账
///
///（#276 终审 F7 提出，本轮在本仓 macOS 腿上复现）：上面那张表只证明了「**完全揭示**
/// 时与不遮逐字节相同」，它**没有**覆盖非整数揭示宽度。实测（macOS，红叠蓝、
/// 40 × 20 × scale 1，取第 20 列像素；旧写法 = `.mask(alignment: .leading) {
/// Rectangle().frame(width:) }`）：
///
///     width=20.0  clip[20]=(0,157,255)     mask[20]=(0,157,255)    逐字节相同 = true
///     width=20.5  clip[20]=(147,118,173)   mask[20]=(255,81,76)    逐字节相同 = false
///     width=20.3  clip[20]=(68,140,221)    mask[20]=(0,157,255)    逐字节相同 = false
///
/// ⇒ `clipShape` 给出**亚像素混合**（边界那一列按覆盖率在红蓝之间插值），
/// 旧遮罩则把宽度**吸附到整像素**（20.3 → 不揭示该列、20.5 → 整列揭示）。
/// ⚠️ **这条差别在生产路径上总是生效**：`reveal = fraction × width`，拖拽中它几乎
/// 恒为分数。观感上大概率是改进（拖动更平滑，不再逐像素跳），但它是一处
/// **未被判据检查、此前也未被记录**的行为变化，故照录在此。
/// ⚠️ 上面的 RGB 绝对值依赖位图读回时的色彩空间转换，**别把它们当契约**；
/// 承重的只有那一列的三个 `逐字节相同` 布尔值（整数宽度相同 / 分数宽度不同）。
///
/// 判据：`BeforeAfterSliderTests.endpointRenderIsIndependentOfTheHiddenLayer`
/// —— ⚠️ 它钉的是**端点**（`fraction = 1`），上面这条亚像素差异**不在它射程内**。
struct BeforeAfterRevealClip: Shape {

    /// 揭示宽度（点）。超出 / 低于 `rect` 的部分被钳住 ⇒ 不会画出负宽矩形。
    var width: CGFloat

    /// ⚠️ 让 `reveal` 可动画：拖拽中 `fraction` 是连续变化的，
    /// 没有它这一层在动画里会跳变（`.mask` 那一版靠 `frame` 的隐式动画拿到了这一条）。
    var animatableData: CGFloat {
        get { self.width }
        set { self.width = newValue }
    }

    func path(in rect: CGRect) -> Path {
        Path(CGRect(
            x: rect.minX,
            y: rect.minY,
            width: min(max(0, self.width), rect.width),
            height: rect.height
        ))
    }
}

// MARK: - 把手

/// 分隔线 + 圆钮。**命中区靠 `frame` + `contentShape` 撑到 `handleHitSize`。**
///
/// ⚠️ `contentShape` 施加在**最外层**、盖住完整 frame ——`TouchTargetTests` 的
/// 文件头逐字写着「`ImageRenderer` 量的是布局 frame，它等于命中区的前提正是这个」。
/// 本类型满足该前提，因此 `BeforeAfterSliderTouchTargetTests` 量到的数是可信的。
struct BeforeAfterSliderHandle: View {

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.contentOnAccent)
                .frame(width: BeforeAfterSweep.dividerWidth)
            Circle()
                .fill(Color.contentOnAccent)
                .frame(width: BeforeAfterSweep.handleDiameter, height: BeforeAfterSweep.handleDiameter)
                .overlay {
                    Image(systemName: "arrow.left.and.right")
                        .font(.system(size: CoreControlMetrics.iconSize(for: .mini), weight: .semibold))
                        .foregroundStyle(Color.contentPrimary)
                }
        }
        .frame(minWidth: BeforeAfterSweep.handleHitSize, minHeight: BeforeAfterSweep.handleHitSize)
        .contentShape(Rectangle())
    }
}

// MARK: - 绘制层（不含手势与状态）

/// 给定分隔线位置画出一帧。**不持有状态、不装手势**——因此可以被单测钉在任意位置上渲染。
///
/// ## ⚠️ 为什么揭示与把手位置都走**布局宽度**，一个 `offset` 都不用
///
/// `MicroInteractionReduceMotionGuard` 的 `everyMotionCallIsGated` 要求：不走早退的文件里，
/// **每一处**运动变换（`offset(` / `position(` / `scaleEffect(` …）的实参都必须自带
/// `isReduced` 门控。而本组件的分隔线位置是**由用户手势驱动的空间输入**——
/// PRD 的 **FR-12** 逐字要求它在 Reduce Motion 下**保留**（「冻结其时间输入，但保留由
/// 用户手势/倾斜驱动的空间输入……冻结它会让组件不可用」）。
/// ⇒ 「给这个 `offset` 加一个 `isReduced` 三元」在语义上是错的：真分支该填什么都不对。
///
/// 布局定位（`Color.clear.frame(width:)` 把把手推到位、`mask` 的矩形按宽度裁）
/// **不是**为了绕开那条判据，它本来就是这类"按比例分割"的常规写法，且顺带让本文件里
/// 一个 `motionCalls` 关键字都不出现。⇒ 本文件因此登记在
/// `MicroInteractionReduceMotionGuard.approvedNoMotion` 名单上。
///
/// ⚠️⚠️ **那条登记不等于"这个组件不动"**——入场摆动会让分隔线滑过去。
/// 它与三个"处理中"薄封装（`ScanningOverlay` / `GlowSweep` / `LightSweep`）同一处置：
/// 名单里的豁免由**两条**判据在别处接管，缺一条就是个洞：
/// · `BeforeAfterSliderTests.sliderPositionsByLayoutNotByTransform`
///   —— 本文件里不得出现任何 `motionCalls` 关键字（豁免的前提本身）；
/// · `BeforeAfterSliderTests.reduceMotionIsOnlyConsumedByTheSweepGate`
///   —— `reduceMotion` 只许喂给 `BeforeAfterSweep.introSweep(reduceMotion:)`。
struct BeforeAfterSliderBody<Before: View, After: View>: View {

    let fraction: CGFloat
    let labels: BeforeAfterSliderLabels
    let before: Before
    let after: After

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let reveal = BeforeAfterSweep.revealWidth(fraction: self.fraction, width: width)

            ZStack(alignment: .topLeading) {
                // ⚠️⚠️ **叠放顺序与遮罩方向都是承重的**（#253 PR #273 终审 C-1）。
                // 唯一的语义权威是 `BeforeAfterSlider.init` 的文档：
                //「`before` 露在分隔线**左侧**、`after` 露在**右侧**」，
                // `labelPair` 的 chip 顺序（左 before / 右 after）也是照这条来的。
                // ⇒ 底层铺满 `after`（露在右半），上层的 `before` mask 到 leading 的 `reveal`。
                //
                // ⚠️ 上一版反着写（`after` 叠在上、mask 到 leading）⇒ 左半画 `after`、
                // 右半画 `before`，而 chip 顺序没跟着反 ⇒ **默认 `.standard` 标签把两半都标错**，
                // 且当时全套测试全绿——没有任何判据钉过"哪边是哪个"。
                // ⇒ 判据补在 `BeforeAfterSliderTests.beforeIsOnTheLeadingSide`（逐像素取色）。
                self.after
                    .frame(width: width, height: proxy.size.height)
                    .clipped()

                self.before
                    .frame(width: width, height: proxy.size.height)
                    .clipped()
                    // ⚠️ **裁剪，不是 alpha 遮罩**——理由与实测逐字记在
                    // `BeforeAfterRevealClip` 上（Issue #276）。
                    .clipShape(BeforeAfterRevealClip(width: reveal))

                self.labelOverlay(width: width)

                HStack(spacing: 0) {
                    // ⚠️ 把手靠**布局宽度**推到位——见类型文档。
                    Color.clear
                        .frame(width: BeforeAfterSweep.leadingInset(fraction: self.fraction, width: width))
                    BeforeAfterSliderHandle()
                    Spacer(minLength: 0)
                }
            }
        }
    }

    @ViewBuilder
    private func labelOverlay(width: CGFloat) -> some View {
        switch self.labels {
        case .hidden:
            EmptyView()
        case .standard:
            self.labelPair(
                before: Text(BeforeAfterSliderLabels.defaultBefore),
                after: Text(BeforeAfterSliderLabels.defaultAfter)
            )
        case let .shown(before, after):
            self.labelPair(before: Text(before), after: Text(after))
        }
    }

    private func labelPair(before: Text, after: Text) -> some View {
        HStack {
            self.chip(before)
            Spacer(minLength: CoreSpacing.sm)
            self.chip(after)
        }
        .padding(CoreSpacing.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // ⚠️ 标签是**冗余装饰**：它说的话与整体 `accessibilityValue` 重复，
        // 且 VoiceOver 应当听到的是"对比滑块，62%"而不是两个孤立的词。
        .accessibilityHidden(true)
    }

    private func chip(_ text: Text) -> some View {
        text
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color.contentPrimary)
            .padding(.horizontal, CoreSpacing.sm)
            .padding(.vertical, CoreSpacing.xs)
            .background(Color.quaternaryFill, in: Capsule())
    }
}

// MARK: - 公开入口

/// 拖动分隔线对比"之前 / 之后"两张图的滑块。典型用途：修图前后、主题深浅、
/// 优化前后的截图对照。
///
/// ```swift
/// BeforeAfterSlider {
///     Image(.original).resizable().scaledToFill()
/// } after: {
///     Image(.edited).resizable().scaledToFill()
/// }
/// .frame(height: 240)
/// .clipShape(CoreShape.rounded(CoreRadius.large))
/// ```
///
/// ## 标签
///
/// 三档取值域，见 `BeforeAfterSliderLabels`——**不是** `showLabels: Bool`（J-1 / FR-6）。
/// 默认 `.standard`（组件自带的 "Before" / "After"，走本 target 的 `Bundle.module`）。
///
/// ## Reduce Motion
///
/// **停止自动摆动，但保留拖拽**（AC 逐字）。开启该偏好时不做入场摆动，分隔线直接停在
/// 正中；拖拽手势原样可用——PRD 的 **FR-12** 逐字要求保留"由用户手势驱动的空间输入"，
/// 冻结它会让这个组件不可用。裁决点是纯函数
/// `BeforeAfterSweep.introSweep(reduceMotion:)`。
///
/// ## 入场摆动**不会覆盖用户的拖拽**
///
/// 摆动是一次性的"这里可以拖"提示，前后共约 `sweepDuration × 2 ≈ 1.1s`。
/// 用户在这段窗口里抓住把手时，回程**不再执行**（`BeforeAfterSweep.settlesAfterSweep`）
/// ——否则显式输入会被一个提示动画拽回正中（#253 PR #273 终审 I-6）。
///
/// ## 后台 / 低电量（NFR-7）
///
/// ⚠️ **本组件不接能耗闸，这是一条判定不是遗漏**：NFR-7 管的是**常驻渲染**的效果
///（持续调度的那一类）。本组件的入场摆动是**一次性**的（`.task` 里一次
/// `withAnimation`，之后没有任何调度器），其余时间它是一张静止的图 + 一个手势
/// ——与 `.ping` / `.spray` 这些 trigger 驱动的一次性微交互同类。
/// ⚠️ 另一半理由与 `TypewriterText` 相同：能耗闸的 `.none` 语义是**一个像素都不画**，
/// 而这里画的是调用方的**内容**，把它隐藏不是"停摆"，是 bug。
///
/// ## a11y
///
/// 整块合成为一个**可调节**元素：VoiceOver 上下轻扫即可移动分隔线
///（`accessibilityAdjustableAction`），值播报为百分比。
/// ⚠️ 标签层已 `accessibilityHidden(true)`——它与那个百分比说的是同一件事。
public struct BeforeAfterSlider<Before: View, After: View>: View {

    private let labels: BeforeAfterSliderLabels
    private let before: Before
    private let after: After

    /// 分隔线位置。**由拖拽与入场摆动共同推进。**
    @State private var fraction: CGFloat = BeforeAfterSweep.initialFraction

    /// 用户是否已经碰过把手。**入场摆动的回程要先看它**——见
    /// `BeforeAfterSweep.settlesAfterSweep(hasInteracted:)`（终审 I-6）。
    @State private var hasInteracted = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameters:
    ///   - labels: 两侧标签的取值域，默认 `.standard`。见 `BeforeAfterSliderLabels`。
    ///   - before: 分隔线**左侧**露出的内容（"之前"）。
    ///   - after: 分隔线**右侧**露出的内容（"之后"）。
    public init(
        labels: BeforeAfterSliderLabels = .standard,
        @ViewBuilder before: () -> Before,
        @ViewBuilder after: () -> After
    ) {
        self.labels = labels
        self.before = before()
        self.after = after()
    }

    public var body: some View {
        GeometryReader { proxy in
            BeforeAfterSliderBody(
                fraction: self.fraction,
                labels: self.labels,
                before: self.before,
                after: self.after
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        // ⚠️ 拖拽**不经过任何 Reduce Motion 门控**（FR-12）。
                        // ⚠️ 但它必须**吃掉入场摆动的回程**（终审 I-6）：置位后
                        // `playIntroSweep` 的第二段会被 `settlesAfterSweep` 挡住。
                        self.hasInteracted = true
                        self.fraction = BeforeAfterSweep.fraction(
                            dragX: value.location.x, width: proxy.size.width
                        )
                    }
            )
        }
        // ⚠️⚠️ `reduceMotion` 在本文件里**只在这一处**被消费，判据
        //（`BeforeAfterSliderTests.reduceMotionIsOnlyConsumedByTheSweepGate`）逐次计数。
        .task { await self.playIntroSweep(BeforeAfterSweep.introSweep(reduceMotion: self.reduceMotion)) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(BeforeAfterSliderChrome.accessibilityTitle))
        .accessibilityValue(Text(Double(self.fraction), format: .percent.precision(.fractionLength(0))))
        .accessibilityAdjustableAction { direction in
            let step: CGFloat = 0.05
            switch direction {
            case .increment: self.fraction = BeforeAfterSweep.clamp01(self.fraction + step)
            case .decrement: self.fraction = BeforeAfterSweep.clamp01(self.fraction - step)
            @unknown default: break
            }
        }
    }

    /// 一次性入场摆动：摆过去 → 摆回来。**`nil` ⇒ 什么都不做（Reduce Motion）。**
    ///
    /// ⚠️ **回程受 `hasInteracted` 门控**（终审 I-6）：用户在这 ~1.1s 里抓过把手，
    /// 就不再把分隔线拽回 `settle`。裁决点是纯函数
    /// `BeforeAfterSweep.settlesAfterSweep(hasInteracted:)`。
    private func playIntroSweep(_ sweep: BeforeAfterIntroSweep?) async {
        guard let sweep else { return }
        withAnimation(.easeInOut(duration: sweep.duration)) { self.fraction = sweep.peak }
        do {
            try await Task.sleep(for: .seconds(sweep.duration))
        } catch {
            return
        }
        guard BeforeAfterSweep.settlesAfterSweep(hasInteracted: self.hasInteracted) else { return }
        withAnimation(.easeInOut(duration: sweep.duration)) { self.fraction = sweep.settle }
    }
}

#Preview("BeforeAfterSlider") {
    BeforeAfterSlider {
        Rectangle().fill(Color.surfaceRaised)
            .overlay { Image(systemName: "photo").font(.system(size: 44)).foregroundStyle(Color.contentTertiary) }
    } after: {
        Rectangle().fill(Color.secondaryFill)
            .overlay { Image(systemName: "wand.and.stars").font(.system(size: 44)).foregroundStyle(.tint) }
    }
    .frame(width: 320, height: 200)
    .clipShape(CoreShape.rounded(CoreRadius.large))
    .padding(CoreSpacing.xxl)
}

#Preview("BeforeAfterSlider — 自定义文案 / 无标签") {
    VStack(spacing: CoreSpacing.xl) {
        BeforeAfterSlider(labels: .shown(before: "Draft", after: "Final")) {
            Rectangle().fill(Color.surfaceRaised)
        } after: {
            Rectangle().fill(Color.secondaryFill)
        }
        .frame(width: 300, height: 120)

        BeforeAfterSlider(labels: .hidden) {
            Rectangle().fill(Color.surfaceRaised)
        } after: {
            Rectangle().fill(Color.secondaryFill)
        }
        .frame(width: 300, height: 120)
    }
    .padding(CoreSpacing.xxl)
}
