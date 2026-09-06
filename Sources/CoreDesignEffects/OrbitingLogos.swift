import CoreDesign
import SwiftUI

// MARK: - 驱动层（读环境、定策略、决定建不建 TimelineView）

/// 四圈同心点环持续自转，调用方的 logo 均匀落在最外环上随之巡游，
/// 每隔一小段时间轮到一个 logo **弹出放大**、把附近的点挤开，中心是调用方的视图。
public struct OrbitingLogos<Data: RandomAccessCollection, Logo: View, Center: View>: View
where Data.Element: Identifiable {
    /// 默认自转周期（秒 / 圈）。
    public nonisolated static var defaultRotationPeriod: Double { OrbitRing.rotationPeriod }

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
    ///   - rotationPeriod: 转一圈用多少秒。**非法值（`<= 0` / `NaN` / `±∞`）⇒ 整件冻结**
    ///     （自转、轮播一并停，且**不建调度器**）——见
    ///     `MotionPresentation.frozenIfPeriodIsDegenerate(_:)`。
    ///     ⚠️ **已登记的形状缺陷**（第 2 轮终审 S-b）：这一个旋钮同时管住了"停自转"与
    ///     "停轮播"，调用方想要"环不转但 logo 照常轮播"**已无表达方式**，而这个名字
    ///     读不出"整件冻结"——一个旋钮被重载成了开关，与本仓 J-1 的口味相左。
    ///     ⇒ **如需分离，另开档位**（一个描述"这件动到什么程度"的枚举），别再往
    ///     `rotationPeriod` 上叠语义。
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
        let state = EnergyState.resolve(
            injectedScenePhase: self.scenePhaseOverride,
            systemScenePhase: self.systemScenePhase,
            lowPowerModeOverride: self.lowPowerModeOverride
        )
        let presentation = state.presentation(reduceMotion: self.reduceMotion)
            .frozenIfPeriodIsDegenerate(self.rotationPeriod)

        switch presentation {
        case .hidden:
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

enum OrbitLayers: Equatable {
    case full

    case contentOnly
}

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

    var body: some View {
        let perRing = self.ringDotCount
        let seats = self.seatCount

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

    private var energy: EnergyState {
        EnergyState.resolve(
            injectedScenePhase: self.scenePhaseOverride,
            systemScenePhase: self.systemScenePhase,
            lowPowerModeOverride: self.lowPowerModeOverride
        )
    }

    private var ringDotCount: Int {
        max(0, Int((Double(OrbitRing.dotsPerRing) * self.energy.policy.particleScale).rounded()))
    }

    private var seatCount: Int {
        let activePolicy = EnergyState(
            scenePhase: .active, isLowPower: self.energy.isLowPower
        ).policy
        return OrbitRing.seats(particleScale: activePolicy.particleScale)
    }

    private func logoPoint(at index: Int, seats: Int, side: Double, middle: CGPoint) -> CGPoint {
        guard !self.items.isEmpty else { return middle }
        let angle = OrbitRing.logoAngle(
            logoIndex: index, logoCount: self.items.count, dotsPerRing: seats, turns: self.turns
        )
        return OrbitRing.point(angle: angle, radius: OrbitRing.ringRadius(ring: 0, size: side), center: middle)
    }

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
            let tintShading = context.resolve(.style(.tint))
            for ring in 0..<OrbitRing.ringCount {
                let radius = OrbitRing.ringRadius(ring: ring, size: side)
                let diameter = OrbitRing.dotDiameter(ring: ring, size: side)
                for index in 0..<perRing {
                    let angle = OrbitRing.angle(index: index, of: perRing, turns: self.turns, ring: ring)
                    let seat = OrbitRing.point(angle: angle, radius: radius, center: middle)
                    let dot = OrbitRing.pushed(
                        seat,
                        awayFrom: featurePoint,
                        radius: side * OrbitRing.pushRadiusRatio,
                        strength: pushStrength
                    )
                    let box = CGRect(x: dot.x - diameter / 2, y: dot.y - diameter / 2,
                                     width: diameter, height: diameter)
                    let alpha = OrbitRing.alpha(angle: angle)
                    if let tone = self.dotTone(angle: angle) {
                        context.opacity = 1
                        context.fill(Path(ellipseIn: box), with: .color(tone.opacity(alpha)))
                    } else {
                        context.opacity = alpha
                        context.fill(Path(ellipseIn: box), with: tintShading)
                    }
                }
            }
        }
    }

    private func dotTone(angle: Double) -> Color? {
        guard !self.colors.isEmpty else { return nil }
        let turn = (angle / (2 * .pi)).truncatingRemainder(dividingBy: 1)
        let normalized = turn < 0 ? turn + 1 : turn
        let slot = Int(normalized * Double(self.colors.count)) % self.colors.count
        return self.colors[slot]
    }

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
    var magnitudeStep: Double {
        let span = OrbitRing.popPeak - 1
        guard span > 0 else { return 0 }
        return min(max(0, (self - 1) / span), 1)
    }
}

// MARK: - Preview

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

struct OrbitingLogosPreviewItem: Identifiable {
    let id: Int
    let symbol: String

    static let samples: [OrbitingLogosPreviewItem] = [
        "swift", "cube", "bolt", "leaf", "flame", "drop", "sparkles", "moon",
    ].enumerated().map { OrbitingLogosPreviewItem(id: $0.offset, symbol: $0.element) }
}
#endif
