//
//  OrbitingLogos.swift
//  CoreDesignEffects
//
//  同心轨道上巡游的 logo / Logos orbiting on concentric rings.
//

import CoreDesign
import SwiftUI

// MARK: - 驱动层（读环境、定策略、决定建不建 TimelineView）

/// 四圈同心点环持续自转，调用方的 logo 均匀落在最外环上随之巡游，
/// 每隔一小段时间轮到一个 logo **弹出放大**、把附近的点挤开，中心是调用方的视图。
///
/// ```swift
/// OrbitingLogos(brands) { brand in
///     Image(brand.assetName).resizable().scaledToFit().frame(width: 34, height: 34)
/// } center: {
///     Image("AppLogo").resizable().scaledToFit().frame(width: 64, height: 64)
/// }
/// .tint(.accent)
/// .frame(width: 300, height: 300)
/// ```
///
/// ## 平台支持（AD-E）：**SpriteKit 已被整件替换，没有平台分支**
///
/// 上游 `SWOrbitingLogos` 是一个 `SKScene`（`import SpriteKit`）。
/// ⚠️ **不落 SpriteKit 的理由不是"macOS 上编译不过"**——SpriteKit 与 `SpriteView`
/// 在 macOS 上都有。真正的理由是三条与本仓公约的正面冲突（两套渲染时钟、
/// Reduce Motion 无处插手、物理体不可测），逐条写在 `OrbitRing` 的类型文档里。
/// ⇒ 本件是**跨平台 SwiftUI 重写**：环与点用一个 `Canvas` 画，物理挤压换成
/// `OrbitRing.pushed(_:awayFrom:radius:strength:)` 这个解析位移场。
/// **iOS 与 macOS 同一份代码。** 逐条见 `docs/components/orbiting-logos.md`。
///
/// ## 取色（AD-D / FR-8）
///
/// 上游在点上写死了一条绿色渐变（`SKColor(red:…)`），暗色模式与高对比度下不会跟着变。
/// 本件：`colors` 非空 ⇒ 按环上角度在色板间取色；**为空 ⇒ 取调用方的 `.tint`**，
/// 环上的层次由**角向明暗波**给（同一个色相的明暗，不凭空造色相）。
///
/// ## Reduce Motion
///
/// **冻结在某一帧**：自转与轮播都钉死（`OrbitRing.restingPhase` /
/// `OrbitRing.restingFeature` ⇒ 没有任何 logo 处于放大态）。走**降级形态 2**。
/// ⚠️ 不是 no-op——logo 与中心视图照常显示，只是不动。
///
/// ## 后台 / 低电量（NFR-7）
///
/// 与 `AnimatedMeshGradient` / `Confetti` 共用同一道闸，**但 `.none` 档的语义在本件上
/// 是收窄的**（PR #274 终审 C-1）：
///
/// | 档 | 环 + `Canvas` + 调度器 | 调用方的 logo 与中心视图 |
/// |---|---|---|
/// | `.inactive` / `.background` | **一个像素都不画** | **照常静态显示** |
/// | 低电量 | 15 fps、每环点数减半（logo 座位跟着变稀） | 照常 |
///
/// ⚠️⚠️ **为什么不是"整层不建"**：本件的视图树里装着**调用方的内容**
///（`logo(item)` 与 `center`，两者都有意不 `accessibilityHidden`）。
/// macOS 上 `.inactive` = 窗口不是前台（**窗口完全可见**）、iPadOS 上 = 台前调度后台
/// ⇒ 返回 `EmptyView()` 会让宿主 App 的品牌 logo 与全部合作方 logo 在**可见窗口里**
/// 凭空消失、VoiceOver 也一并丢掉这些元素。本仓已就这一情形裁决过：能耗闸的
/// `.none` 语义是「一个**装饰**像素都不画」，画内容的件把内容藏掉不是停摆、是 bug
///（`BeforeAfterSlider` / `ParticleTransition` 被排除在 `energyGatedFiles` 之外用的是
/// 同一条理由）。⇒ 本件留在闸上（环是常驻渲染，该停），但 `.none` 只摘装饰层。
/// 装饰层的完整记账仍见 `EffectsEnergyState.policy`。
///
/// ## a11y（FR-13）
///
/// **点环是纯装饰**，已 `accessibilityHidden(true)` / `allowsHitTesting(false)`。
/// ⚠️ **logo 与中心视图不隐藏**：它们是调用方给的内容，a11y 由调用方在自己的
/// 视图上提供（这正是 FR-13 那条"承载语义的部分由调用方通告"的分工）。
public struct OrbitingLogos<Data: RandomAccessCollection, Logo: View, Center: View>: View
where Data.Element: Identifiable {

    /// 默认自转周期（秒 / 圈）。
    public static var defaultRotationPeriod: Double { OrbitRing.rotationPeriod }

    private let items: Data
    private let colors: [Color]
    private let rotationPeriod: Double
    private let logo: (Data.Element) -> Logo
    private let center: Center

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lowPowerModeOverride) private var lowPowerModeOverride
    @Environment(\.scenePhaseOverride) private var scenePhaseOverride
    @Environment(\.scenePhase) private var systemScenePhase

    /// - Parameters:
    ///   - items: 落在最外环上的条目。**空集合 ⇒ 只有点环与中心视图**，不崩。
    ///   - colors: 点环取色的色板。**默认为空 ⇒ 取调用方的 `.tint`**。
    ///   - rotationPeriod: 转一圈用多少秒。**`<= 0` ⇒ 整件冻结**（自转、轮播一并停，
    ///     且**不建调度器**）——见 `EffectsPresentation.frozenIfPeriodIsDegenerate(_:)`。
    ///   - logo: 每个条目画成什么。
    ///   - center: 中心视图。
    public init(
        _ items: Data,
        colors: [Color] = [],
        rotationPeriod: Double = OrbitingLogos.defaultRotationPeriod,
        @ViewBuilder logo: @escaping (Data.Element) -> Logo,
        @ViewBuilder center: () -> Center
    ) {
        self.items = items
        self.colors = colors
        self.rotationPeriod = rotationPeriod
        self.logo = logo
        self.center = center()
    }

    public var body: some View {
        let state = EffectsEnergyState.resolve(
            injectedScenePhase: self.scenePhaseOverride,
            systemScenePhase: self.systemScenePhase,
            injectedPowerMode: EffectsPowerMode.lifted(from: self.lowPowerModeOverride)
        )
        // ⚠️ 两道闸的顺序在这个纯函数里（先能耗、后 Reduce Motion），不在这里。
        // ⚠️ 第三道闸是"自转周期非法"：`rotationPeriod <= 0` 要的就是静止（终审 I-4）。
        let presentation = state.presentation(reduceMotion: self.reduceMotion)
            .frozenIfPeriodIsDegenerate(self.rotationPeriod)

        switch presentation {
        case .none:
            // ⚠️⚠️ **不是 `EmptyView()`**（终审 C-1）：装饰层（环 + `Canvas` + 调度器）
            // 全停，但 `logo` 与 `center` 是**调用方的内容**，藏掉它们不是停摆、是 bug。
            // 逐条理由见本类型文档《后台 / 低电量》一节。
            OrbitingLogosBody(
                items: self.items,
                colors: self.colors,
                turns: OrbitRing.restingPhase,
                feature: OrbitRing.restingFeature,
                layers: .contentOnly,
                logo: self.logo,
                center: self.center
            )
        case .resting:
            OrbitingLogosBody(
                items: self.items,
                colors: self.colors,
                turns: OrbitRing.restingPhase,
                feature: OrbitRing.restingFeature,
                layers: .full,
                logo: self.logo,
                center: self.center
            )
        case .animated:
            OrbitingLogosTimeline(
                minimumInterval: state.policy.minimumInterval,
                items: self.items,
                colors: self.colors,
                rotationPeriod: self.rotationPeriod,
                logo: self.logo,
                center: self.center
            )
        }
    }
}

// MARK: - 调度层

/// 唯一建 `TimelineView` 的地方。**只有 `.animated` 档才会被构造。**
struct OrbitingLogosTimeline<Data: RandomAccessCollection, Logo: View, Center: View>: View
where Data.Element: Identifiable {

    let minimumInterval: Double?
    let items: Data
    let colors: [Color]
    let rotationPeriod: Double
    let logo: (Data.Element) -> Logo
    let center: Center

    var body: some View {
        TimelineView(.animation(minimumInterval: self.minimumInterval)) { context in
            OrbitingLogosBody(
                items: self.items,
                colors: self.colors,
                turns: OrbitRing.turns(at: context.date, period: self.rotationPeriod),
                feature: OrbitRing.feature(at: context.date, logoCount: self.items.count),
                layers: .full,
                logo: self.logo,
                center: self.center
            )
        }
    }
}

// MARK: - 绘制层（纯相位函数，不含任何调度）

/// 这一帧画哪些层。
///
/// ⚠️ **不是 Bool**（同 `SphereMark` 的 J-1 / AD-C 理由）：两档的区别不是
/// "要不要环"这个开关，而是**这一帧代表什么**——`.contentOnly` 是"装饰全停、
/// 调用方的内容留下"（NFR-7 的 `.none` 档在一个画内容的件上的正确形态），
/// `.full` 是"整件照画"。
enum OrbitLayers: Equatable {

    /// 环 + 内容，整件照画。
    case full

    /// **只画调用方的 `logo` 与 `center`**，一个装饰像素都不画。
    case contentOnly
}

/// 给定自转圈数与"谁被点名"画出一帧。**不读时间、不调度**
/// ——因此可以被单测钉在任意相位上渲染。
struct OrbitingLogosBody<Data: RandomAccessCollection, Logo: View, Center: View>: View
where Data.Element: Identifiable {

    let items: Data
    let colors: [Color]
    let turns: Double
    let feature: (index: Int, progress: Double)
    let layers: OrbitLayers
    let logo: (Data.Element) -> Logo
    let center: Center

    @Environment(\.lowPowerModeOverride) private var lowPowerModeOverride
    @Environment(\.scenePhaseOverride) private var scenePhaseOverride
    @Environment(\.scenePhase) private var systemScenePhase

    /// ⚠️ **本件强制为正方形**：环是圆的，非等比容器里画出来的是椭圆环。
    /// ⇒ `320 × 200` 的调用方会得到 `200 × 200` 的内容 + 上下留白（信箱边）。
    /// 这条写在 `docs/components/orbiting-logos.md` 的 API 一节（终审 S-7 ②）。
    var body: some View {
        let perRing = self.ringDotCount
        // ⚠️ **logo 必须坐在这一档真的画出来的环点上**（终审 S-3）：低电量下每环
        // 点数减半（23 → 12），座位数还钉在标称的 23 会让 logo 悬在环点之间，
        // 本件"logo 坐在环上随之巡游"的整个视觉立意就没了。
        // `.contentOnly` 档没有环可坐 ⇒ 回落到标称点数（否则停摆时 `perRing == 0`，
        // 全部 logo 会叠到角度 0 那一个位置上）。
        let seats = (self.layers == .full && perRing > 0) ? perRing : OrbitRing.dotsPerRing

        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let middle = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let featurePoint = self.logoPoint(at: self.feature.index, seats: seats,
                                              side: side, middle: middle)

            ZStack {
                if self.layers == .full {
                    self.rings(perRing: perRing, side: side, middle: middle, featurePoint: featurePoint)
                }
                self.logos(seats: seats, side: side, middle: middle)
                self.center
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    /// 这一档每环实际画多少个点。
    ///
    /// ⚠️ 它自己读能耗环境（同 `SphereSurfaceBody` / `AnimatedMeshBody` 的理由）：
    /// 降帧拍不进静态帧，密度才是低电量在位图上唯一可观测的差异。
    private var ringDotCount: Int {
        let policy = EffectsEnergyState.resolve(
            injectedScenePhase: self.scenePhaseOverride,
            systemScenePhase: self.systemScenePhase,
            injectedPowerMode: EffectsPowerMode.lifted(from: self.lowPowerModeOverride)
        ).policy
        return max(0, Int((Double(OrbitRing.dotsPerRing) * policy.particleScale).rounded()))
    }

    /// 第 `index` 个 logo 此刻在屏幕上的位置。座位数由调用方给（见 `body` 里的 `seats`）。
    private func logoPoint(at index: Int, seats: Int, side: Double, middle: CGPoint) -> CGPoint {
        guard !self.items.isEmpty else { return middle }
        let angle = OrbitRing.logoAngle(
            logoIndex: index, logoCount: self.items.count, dotsPerRing: seats, turns: self.turns
        )
        return OrbitRing.point(angle: angle, radius: OrbitRing.ringRadius(ring: 0, size: side), center: middle)
    }

    /// 四圈点环。**一个 `Canvas` 画完**——92 个点逐个建视图会让每一帧都重走布局（NFR-1）。
    private func rings(perRing: Int, side: Double, middle: CGPoint, featurePoint: CGPoint) -> some View {
        let pushStrength = side * OrbitRing.pushStrengthRatio
            * OrbitRing.popScale(progress: self.feature.progress).magnitudeStep

        return self.ringMarks(perRing: perRing, side: side, middle: middle,
                              featurePoint: featurePoint, pushStrength: pushStrength)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }

    private func ringMarks(
        perRing: Int, side: Double, middle: CGPoint, featurePoint: CGPoint, pushStrength: Double
    ) -> some View {
        Canvas { context, _ in
            guard perRing > 0, side > 0 else { return }
            for ring in 0..<OrbitRing.ringCount {
                let radius = OrbitRing.ringRadius(ring: ring, size: side)
                let diameter = OrbitRing.dotDiameter(ring: ring, size: side)
                for index in 0..<perRing {
                    let angle = OrbitRing.angle(index: index, of: perRing, turns: self.turns, ring: ring)
                    let seat = OrbitRing.point(angle: angle, radius: radius, center: middle)
                    // 上游靠 SKPhysicsBody 把邻居撞开，这里是解析位移场。
                    let dot = OrbitRing.pushed(
                        seat,
                        awayFrom: featurePoint,
                        radius: side * OrbitRing.pushRadiusRatio,
                        strength: pushStrength
                    )
                    let box = CGRect(x: dot.x - diameter / 2, y: dot.y - diameter / 2,
                                     width: diameter, height: diameter)
                    context.fill(Path(ellipseIn: box), with: .style(self.dotPaint(angle: angle)))
                }
            }
        }
    }

    /// 单个点的着色。
    ///
    /// ⚠️⚠️ **不再走 `Rectangle().fill(.tint).mask { … }` + `Color.primary` 哨兵**
    ///（PR #274 终审 C-2）：那一版的注释宣称"`.primary` 恒不透明、与写死白色等效"
    /// ——**实测为假**，`Color.primary.resolve(in:)` 明暗两端都给 `a = 0.8471`
    ///（它映射到 `label` / `labelColor`）。`mask` 吃 alpha ⇒ `.tint` 那条路上每个点的
    /// 实际不透明度是 `0.8471 × alpha(angle:)`，与显式色板那条路（`tone.opacity(alpha)`，
    /// 满量程）差 15%，而所有位图判据都是 `a != b` ⇒ 抓不到。
    /// ⇒ 直接用 `.tint` 给 `Canvas` 上色（`Color.white` 被 `EffectsColorLiteralGuard` 禁），
    /// 顺带去掉一层离屏合成。判据：`CrossPlatformRenderTests.tintPathMatchesSinglePalette`。
    private func dotPaint(angle: Double) -> AnyShapeStyle {
        let alpha = OrbitRing.alpha(angle: angle)
        guard !self.colors.isEmpty else { return AnyShapeStyle(.tint.opacity(alpha)) }
        let turn = (angle / (2 * .pi)).truncatingRemainder(dividingBy: 1)
        let normalized = turn < 0 ? turn + 1 : turn
        let slot = Int(normalized * Double(self.colors.count)) % self.colors.count
        return AnyShapeStyle(self.colors[slot].opacity(alpha))
    }

    /// 外环上的 logo。**不进 `Canvas`**：它们是调用方的视图（可能带 a11y、可能可点），
    /// 而 `Canvas` 只能画出像素。数量在个位数量级，逐个建视图不构成 NFR-1 的问题。
    private func logos(seats: Int, side: Double, middle: CGPoint) -> some View {
        ForEach(Array(self.items.enumerated()), id: \.element.id) { offset, item in
            let seat = self.logoPoint(at: offset, seats: seats, side: side, middle: middle)
            self.logo(item)
                .scaleEffect(offset == self.feature.index ? OrbitRing.popScale(progress: self.feature.progress) : 1)
                .offset(x: seat.x - middle.x, y: seat.y - middle.y)
        }
    }
}

// MARK: - 内部小工具

private extension Double {
    /// 把 pop 的缩放换算成"挤开多远"的系数：静止（1）时为 0，峰值时为 1。
    ///
    /// ⚠️ 抽成一个具名换算而不是就地写 `(self - 1) / (peak - 1)`：
    /// 它是**同一个纯函数被绘制层引用**的那条纪律的一部分——`popPeak` 只有一处定义。
    var magnitudeStep: Double {
        let span = OrbitRing.popPeak - 1
        guard span > 0 else { return 0 }
        return min(max(0, (self - 1) / span), 1)
    }
}

// MARK: - Preview

// ⚠️ **整块关进 `#if DEBUG`**（PR #274 终审 S-7 ①）：`OrbitingLogosPreviewItem`
// 是预览 / 测试夹具，此前住在发布源码里且无围栏 ⇒ 会进消费方的 release 二进制。
// `#Preview` 一起进来是**必须的**：宏展开出的 `PreviewRegistry` 在 release 下照样编译，
// 把夹具单独围起来会让 release 构建当场找不到符号。
// （形态照 `Sources/CoreDesign/Components/TagInput/TagInput.swift` 的既有 `#if DEBUG` 预览宿主。）
#if DEBUG
#Preview("OrbitingLogos · tint") {
    OrbitingLogos(OrbitingLogosPreviewItem.samples) { item in
        Image(systemName: item.symbol)
            .font(.system(size: 20))
            .foregroundStyle(Color.contentPrimary)
    } center: {
        Image(systemName: "app.dashed")
            .font(.system(size: 44))
            .foregroundStyle(Color.accent)
    }
    .tint(.accent)
    .frame(width: 320, height: 320)
    .background(Color.surfaceRaised)
}

/// `#Preview` 用的示例条目。**不是公开 API。**
struct OrbitingLogosPreviewItem: Identifiable {
    let id: Int
    let symbol: String

    static let samples: [OrbitingLogosPreviewItem] = [
        "swift", "cube", "bolt", "leaf", "flame", "drop", "sparkles", "moon",
    ].enumerated().map { OrbitingLogosPreviewItem(id: $0.offset, symbol: $0.element) }
}
#endif
