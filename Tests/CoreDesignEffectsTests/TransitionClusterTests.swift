import CoreDesign
import Foundation
import SwiftUI
import Testing

@testable import CoreDesignEffects

// MARK: - #267：转场簇 B（3D 与弹性 6 种）

@Suite("转场簇 B：3D 与弹性（#267）")
@MainActor
struct TransitionClusterTests {
    // MARK: - 渲染 harness

    static let contentWidth: CGFloat = 120
    static let contentHeight: CGFloat = 80
    static let canvasWidth: CGFloat = 240
    static let canvasHeight: CGFloat = 200

    static var content: some View {
        Color.surfaceRaised.frame(width: Self.contentWidth, height: Self.contentHeight)
    }

    static func canvas(_ view: some View) -> some View {
        view
            .frame(width: Self.canvasWidth, height: Self.canvasHeight)
            .background(Color.contentPrimary)
    }

    // MARK: 一帧位图（带**短**失败信息）

    struct Frame: Equatable, Hashable, CustomStringConvertible {
        let bytes: Data

        static func == (lhs: Frame, rhs: Frame) -> Bool { lhs.bytes == rhs.bytes }

        func hash(into hasher: inout Hasher) { hasher.combine(self.bytes) }

        func firstDifference(from other: Frame) -> Int? {
            for (offset, pair) in zip(self.bytes, other.bytes).enumerated() where pair.0 != pair.1 {
                return offset
            }
            return self.bytes.count == other.bytes.count
                ? nil
                : min(self.bytes.count, other.bytes.count)
        }

        var description: String { "帧(\(self.bytes.count) 字节，指纹 \(Self.digest(self.bytes)))" }

        static func digest(_ data: Data) -> String {
            var hash: UInt64 = 0xcbf2_9ce4_8422_2325
            for byte in data {
                hash ^= UInt64(byte)
                hash = hash &* 0x0000_0100_0000_01b3
            }
            return String(hash, radix: 16)
        }
    }

    // MARK: 暖机

    private static let warmUp: Bool = {
        for probe in Self.probes {
            for _ in 0..<8 {
                _ = probe.rawRender(-0.75, false)
                _ = probe.rawRender(-0.75, true)
            }
        }
        for _ in 0..<8 {
            _ = Self.rawPlain()
            _ = Self.rawCrossFade(at: -0.75)
        }
        return true
    }()

    // MARK: 三个取样入口（`raw*` 不暖机，只给 `warmUp` 自己用）

    static func rawRender(_ modifier: some ViewModifier) -> Frame? {
        MicroInteractionAPITests.stablePixels(Self.canvas(Self.content.modifier(modifier))).map(Frame.init)
    }

    static func render(_ modifier: some ViewModifier) -> Frame? {
        _ = Self.warmUp
        return Self.rawRender(modifier)
    }

    static func rawPlain() -> Frame? {
        MicroInteractionAPITests.stablePixels(Self.canvas(Self.content)).map(Frame.init)
    }

    static func renderPlain() -> Frame? {
        _ = Self.warmUp
        return Self.rawPlain()
    }

    static func rawCrossFade(at phaseValue: Double) -> Frame? {
        MicroInteractionAPITests.stablePixels(
            Self.canvas(Self.content.opacity(TransitionCurve.opacity(phaseValue)))
        ).map(Frame.init)
    }

    static func renderCrossFade(at phaseValue: Double) -> Frame? {
        _ = Self.warmUp
        return Self.rawCrossFade(at: phaseValue)
    }

    // MARK: - `Animatable` 插值（逐字复刻 SwiftUI 在动画事务里做的三步）

    static func animatableProgress(_ modifier: Any) -> Double? {
        (modifier as? any Animatable)?.animatableData as? Double
    }

    static func interpolatedPixels(_ start: Any, towards end: Any, amount: Double) -> Frame? {
        guard let from = start as? (any ViewModifier & Animatable),
              let to = end as? (any Animatable) else { return nil }
        return Self.blendAndRender(from, towards: to, amount: amount)
    }

    private static func blendAndRender<M: ViewModifier & Animatable>(
        _ start: M, towards end: any Animatable, amount: Double
    ) -> Frame? {
        guard let target = end.animatableData as? M.AnimatableData else { return nil }
        var out = start
        var data = start.animatableData
        data.interpolate(towards: target, amount: amount)
        out.animatableData = data
        return Self.render(out)
    }

    // MARK: - 六个转场的统一探针

    struct Probe {
        let name: String
        let file: String
        let rawRender: (Double, Bool) -> Frame?
        let interpolate: (Double, Double, Double) -> Frame?
        let animatable: (Double) -> Double?
        let applied: (TransitionPhase) -> Frame?
        let directional: Bool

        func render(_ phaseValue: Double, _ isReduced: Bool) -> Frame? {
            _ = TransitionClusterTests.warmUp
            return self.rawRender(phaseValue, isReduced)
        }

        var transitionType: String { self.file.replacingOccurrences(of: ".swift", with: "") }

        var chromeType: String { self.file.replacingOccurrences(of: "Transition.swift", with: "Chrome") }

        var motionType: String { self.file.replacingOccurrences(of: "Transition.swift", with: "Motion") }
    }

    static let probes: [Probe] = [
        Probe(
            name: "flip",
            file: "FlipTransition.swift",
            rawRender: { v, r in Self.rawRender(FlipMotion(phaseValue: v, axis: .horizontal, isReduced: r)) },
            interpolate: { from, to, amount in
                Self.interpolatedPixels(
                    FlipMotion(phaseValue: from, axis: .horizontal, isReduced: false),
                    towards: FlipMotion(phaseValue: to, axis: .horizontal, isReduced: false),
                    amount: amount
                )
            },
            animatable: { Self.animatableProgress(FlipMotion(phaseValue: $0, axis: .horizontal, isReduced: false)) },
            applied: { Self.applied(FlipTransition(axis: .horizontal), at: $0) },
            directional: true
        ),
        Probe(
            name: "rotate3D",
            file: "Rotate3DTransition.swift",
            rawRender: { v, r in
                Self.rawRender(Rotate3DMotion(phaseValue: v, degrees: 75, axis: .tilted, isReduced: r))
            },
            interpolate: { from, to, amount in
                Self.interpolatedPixels(
                    Rotate3DMotion(phaseValue: from, degrees: 75, axis: .tilted, isReduced: false),
                    towards: Rotate3DMotion(phaseValue: to, degrees: 75, axis: .tilted, isReduced: false),
                    amount: amount
                )
            },
            animatable: {
                Self.animatableProgress(Rotate3DMotion(phaseValue: $0, degrees: 75, axis: .tilted, isReduced: false))
            },
            applied: { Self.applied(Rotate3DTransition(angle: .degrees(75), axis: .tilted), at: $0) },
            directional: true
        ),
        Probe(
            name: "swoosh",
            file: "SwooshTransition.swift",
            rawRender: { v, r in
                Self.rawRender(SwooshMotion(phaseValue: v, edge: .trailing, points: 80, isReduced: r))
            },
            interpolate: { from, to, amount in
                Self.interpolatedPixels(
                    SwooshMotion(phaseValue: from, edge: .trailing, points: 80, isReduced: false),
                    towards: SwooshMotion(phaseValue: to, edge: .trailing, points: 80, isReduced: false),
                    amount: amount
                )
            },
            animatable: {
                Self.animatableProgress(SwooshMotion(phaseValue: $0, edge: .trailing, points: 80, isReduced: false))
            },
            applied: { Self.applied(SwooshTransition(edge: .trailing, travel: .regular), at: $0) },
            directional: true
        ),
        Probe(
            name: "boing",
            file: "BoingTransition.swift",
            rawRender: { v, r in Self.rawRender(BoingMotion(phaseValue: v, amplitude: 0.6, isReduced: r)) },
            interpolate: { from, to, amount in
                Self.interpolatedPixels(
                    BoingMotion(phaseValue: from, amplitude: 0.6, isReduced: false),
                    towards: BoingMotion(phaseValue: to, amplitude: 0.6, isReduced: false),
                    amount: amount
                )
            },
            animatable: { Self.animatableProgress(BoingMotion(phaseValue: $0, amplitude: 0.6, isReduced: false)) },
            applied: { Self.applied(BoingTransition(strength: .regular), at: $0) },
            directional: false
        ),
        Probe(
            name: "skid",
            file: "SkidTransition.swift",
            rawRender: { v, r in Self.rawRender(SkidMotion(phaseValue: v, edge: .leading, points: 80, isReduced: r)) },
            interpolate: { from, to, amount in
                Self.interpolatedPixels(
                    SkidMotion(phaseValue: from, edge: .leading, points: 80, isReduced: false),
                    towards: SkidMotion(phaseValue: to, edge: .leading, points: 80, isReduced: false),
                    amount: amount
                )
            },
            animatable: {
                Self.animatableProgress(SkidMotion(phaseValue: $0, edge: .leading, points: 80, isReduced: false))
            },
            applied: { Self.applied(SkidTransition(edge: .leading, travel: .regular), at: $0) },
            directional: false
        ),
        Probe(
            name: "move",
            file: "PolarMoveTransition.swift",
            rawRender: { v, r in
                Self.rawRender(PolarMoveMotion(phaseValue: v, radians: .pi / 2, distance: 80, isReduced: r))
            },
            interpolate: { from, to, amount in
                Self.interpolatedPixels(
                    PolarMoveMotion(phaseValue: from, radians: .pi / 2, distance: 80, isReduced: false),
                    towards: PolarMoveMotion(phaseValue: to, radians: .pi / 2, distance: 80, isReduced: false),
                    amount: amount
                )
            },
            animatable: {
                Self.animatableProgress(PolarMoveMotion(phaseValue: $0, radians: .pi / 2, distance: 80, isReduced: false))
            },
            applied: { Self.applied(PolarMoveTransition(angle: .degrees(90), distance: 80), at: $0) },
            directional: false
        ),
    ]

    static func applied(_ transition: some Transition, at phase: TransitionPhase) -> Frame? {
        _ = Self.warmUp
        return MicroInteractionAPITests
            .stablePixels(Self.canvas(transition.apply(content: Self.content, phase: phase)))
            .map(Frame.init)
    }

    // MARK: - ① 相位契约（纯函数）

    @Test("恒等相位：六条曲线全部**精确**归到恒等值")
    func identityPhaseIsExactlyNeutral() {
        #expect(TransitionCurve.value(of: .identity) == 0)
        #expect(TransitionCurve.distance(0) == 0)
        #expect(TransitionCurve.opacity(0) == 1)
        #expect(TransitionCurve.elastic(0, amplitude: 0.6, cycles: 1.25) == 0)

        #expect(Flip.angle(at: 0) == 0, "flip 在恒等相位还带着旋转")
        #expect(Rotate3D.angle(at: 0, degrees: 75) == 0, "rotate3D 在恒等相位还带着旋转")
        #expect(Rotate3D.scale(at: 0) == 1, "rotate3D 在恒等相位还带着缩放")
        #expect(Swoosh.travel(at: 0, along: .trailing, points: 80) == .zero, "swoosh 在恒等相位还带着位移")
        #expect(Swoosh.stretch(at: 0, along: .trailing) == CGSize(width: 1, height: 1), "swoosh 在恒等相位还带着拉伸")
        #expect(Swoosh.blurRadius(at: 0) == 0, "swoosh 在恒等相位还糊着 —— 那是永久的")
        #expect(Boing.scale(at: 0, amplitude: 0.6) == 1, "boing 在恒等相位还带着缩放")
        #expect(Skid.travel(at: 0, along: .leading, points: 80) == .zero, "skid 在恒等相位还带着位移")
        #expect(Skid.tilt(at: 0, along: .leading) == 0, "skid 在恒等相位还歪着")
        #expect(PolarMove.travel(at: 0, radians: .pi / 2, distance: 80) == .zero, "move 在恒等相位还带着位移")
    }

    @Test("两个端点都真的偏离恒等（互锁：否则上一条恒真）")
    func endpointsAreNotNeutral() {
        for v in [-1.0, 1.0] {
            #expect(TransitionCurve.opacity(v) == 0, "端点 \(v) 的不透明度不是 0")
            #expect(Flip.angle(at: v) != 0, "flip 在端点 \(v) 没有旋转")
            #expect(Rotate3D.angle(at: v, degrees: 75) != 0, "rotate3D 在端点 \(v) 没有旋转")
            #expect(Rotate3D.scale(at: v) != 1, "rotate3D 在端点 \(v) 没有缩放")
            #expect(Swoosh.travel(at: v, along: .trailing, points: 80) != .zero, "swoosh 在端点 \(v) 没有位移")
            #expect(Swoosh.blurRadius(at: v) > 0, "swoosh 在端点 \(v) 没有模糊")
            #expect(Boing.scale(at: v, amplitude: 0.6) != 1, "boing 在端点 \(v) 没有缩放")
            #expect(Skid.travel(at: v, along: .leading, points: 80) != .zero, "skid 在端点 \(v) 没有位移")
            #expect(Skid.tilt(at: v, along: .leading) != 0, "skid 在端点 \(v) 没有甩尾")
            #expect(PolarMove.travel(at: v, radians: .pi / 2, distance: 80) != .zero, "move 在端点 \(v) 没有位移")
        }
    }

    @Test("穿行 / 同侧：flip / rotate3D / swoosh 两端异号，skid / move 两端同值")
    func directionSemanticsMatchTheDocumentedTable() {
        #expect(Flip.angle(at: -1) == -Flip.angle(at: 1), "flip 两端不是异号 —— 翻进来和翻出去成了同一个动作")
        #expect(Rotate3D.angle(at: -1, degrees: 75) == -Rotate3D.angle(at: 1, degrees: 75),
                "rotate3D 两端不是异号")
        #expect(Swoosh.travel(at: -1, along: .trailing, points: 80).width
                == -Swoosh.travel(at: 1, along: .trailing, points: 80).width,
                "swoosh 两端不是异号 —— 它就退化成同侧进出（那是 .move 的语义）")

        #expect(Skid.travel(at: -1, along: .leading, points: 80)
                == Skid.travel(at: 1, along: .leading, points: 80),
                "skid 两端不同 —— 它被改成穿行了")
        #expect(PolarMove.travel(at: -1, radians: .pi / 2, distance: 80)
                == PolarMove.travel(at: 1, radians: .pi / 2, distance: 80),
                "move 两端不同 —— 它被改成穿行了")
        #expect(Boing.scale(at: -1, amplitude: 0.6) == Boing.scale(at: 1, amplitude: 0.6),
                "boing 两端不同 —— 缩放不该有方向")
    }

    @Test("弹性曲线真的越过目标（boing 放大过 1、skid 冲过头反号）")
    func elasticCurvesActuallyOvershoot() {
        let samples = stride(from: 0.0, through: 1.0, by: 0.01)

        let scales = samples.map { Boing.scale(at: $0, amplitude: 0.6) }
        let peak = scales.max() ?? 0
        #expect(peak > 1.05, "boing 的峰值缩放只有 \(peak) —— 它没有越过原尺寸，那就不是「弹」")

        let travels = samples.map { Skid.travel(at: $0, along: .leading, points: 80).width }
        let atEndpoint = Skid.travel(at: 1, along: .leading, points: 80).width
        #expect(travels.contains(where: { $0 * atEndpoint < 0 }),
                "skid 的位移从来没有反号 —— 它没有冲过头，那就不是「刹车打滑」")
    }

    // MARK: - ② 相位真的接到渲染上（位图）

    @Test("六个转场：端点那一帧与恒等那一帧的位图必须不同（相位真的接到像素上）")
    func phaseReachesThePixels() throws {
        let plain = try #require(Self.renderPlain(), "对照组渲染失败")
        #expect(plain.bytes.contains(where: { $0 != 0 }), "对照组位图全 0 —— 下面的相等 / 不等断言都不作数")

        for probe in Self.probes {
            let identity = try #require(probe.render(0, false), "\(probe.name)：恒等帧渲染失败")
            for v in [-1.0, -0.5, 0.5, 1.0] {
                let moved = try #require(probe.render(v, false), "\(probe.name)：相位 \(v) 渲染失败")
                #expect(moved != identity, """
                \(probe.name) 在相位 \(v) 与恒等相位渲染出**同一张**位图
                —— 相位没有接到绘制层上，这条转场对用户不存在。
                """)
            }

            for v in [-0.7, -0.35, 0.35, 0.7] {
                let moved = try #require(probe.render(v, false), "\(probe.name)：相位 \(v) 渲染失败")
                let fade = try #require(Self.renderCrossFade(at: v), "对照组渲染失败")
                #expect(moved != fade, """
                \(probe.name) 在相位 \(v) 与「只加 `.opacity`」的对照组渲染出同一张位图
                —— 这条转场的**运动**部分没有接到绘制层上，它现在等价于一次淡入淡出。
                """)
            }
        }
    }

    @Test("穿行 / 同侧的语义差别在像素上也成立")
    func directionSemanticsReachThePixels() throws {
        for probe in Self.probes {
            let entering = try #require(probe.render(-0.6, false), "\(probe.name)：进场帧渲染失败")
            let leaving = try #require(probe.render(0.6, false), "\(probe.name)：出场帧渲染失败")
            if probe.directional {
                #expect(entering != leaving, """
                \(probe.name) 标为穿行，但进场帧与出场帧逐字节相同
                —— 它实际是同侧进出（几何函数大概取了 `abs`）。
                """)
            } else {
                #expect(entering == leaving, """
                \(probe.name) 标为同侧进出，但进场帧与出场帧不同
                —— 它实际是穿行；要么改回来，要么把 `directional` 与类型文档一起改。
                """)
            }
        }
    }

    @Test("恒等相位与裸内容逐字节相同（转场不改变常驻态的样子）")
    func identityFrameIsIndistinguishableFromPlainContent() throws {
        let plain = try #require(Self.renderPlain(), "对照组渲染失败")
        #expect(plain.bytes.contains(where: { $0 != 0 }), "对照组位图全 0 —— 相等断言恒真")

        for probe in Self.probes {
            let identity = try #require(probe.render(0, false), "\(probe.name)：恒等帧渲染失败")
            #expect(identity == plain, """
            \(probe.name) 的恒等相位与裸内容不同 —— 转场停住之后画面被它**永久**改了。
            先看这条转场的几何函数在 `phaseValue == 0` 处是不是精确归零
            （`identityPhaseIsExactlyNeutral`），再看绘制层有没有加与相位无关的东西。
            """)
        }
    }

    // MARK: - ③ 插值（`Animatable`）

    @Test("六个层 3 modifier 都是 Animatable，且 animatableData 就是相位值")
    func motionModifiersAnimateOnThePhaseValue() {
        for probe in Self.probes {
            for v in [-1.0, -0.35, 0.0, 0.8] {
                #expect(probe.animatable(v) == v, """
                \(probe.name) 的 `animatableData` 在 phaseValue = \(v) 处读出
                \(String(describing: probe.animatable(v))) —— 要么它不是 `Animatable`
                （SwiftUI 于是只在三个离散相位上求值它，中间帧根本不存在），
                要么 `animatableData` 绑到了别的字段上。
                """)
            }
        }
    }

    @Test("插值出的中间帧连续可辨，且与直接构造的同相位帧逐字节相同")
    func interpolationIsContinuousNotAnEndpointJump() throws {
        for probe in Self.probes {
            let start = try #require(probe.render(-1, false), "\(probe.name)：起点渲染失败")
            let end = try #require(probe.render(0, false), "\(probe.name)：终点渲染失败")

            var frames: [Double: Frame] = [:]
            for amount in [0.25, 0.5, 0.75] {
                let mid = try #require(probe.interpolate(-1, 0, amount), """
                \(probe.name)：插值失败 —— 层 3 modifier 不是 `Animatable`
                （或它的 `animatableData` 不是 `Double`）⇒ SwiftUI 只会在三个离散相位上
                求值它，"动"这件事从未发生。
                """)
                let direct = try #require(probe.render(-1 + amount, false), "\(probe.name)：直构帧渲染失败")
                #expect(mid == direct, """
                \(probe.name) @ amount \(amount)：插值出的那一帧与
                直接用 phaseValue = \(-1 + amount) 构造的那一帧不同
                —— `animatableData` 没有绑在真正参与绘制的量上，插值改不动画面。
                """)
                #expect(mid != start && mid != end, """
                \(probe.name) @ amount \(amount)：插值帧与某个端点逐字节相同
                —— 动画在这一段是"跳"过去的，不是插过去的。
                """)
                frames[amount] = mid
            }
            #expect(Set(frames.values).count == frames.count, """
            \(probe.name)：三个插值点渲染出的位图有重复 —— 曲线在中段是平的，
            用户看到的仍然是一次跳变。
            """)
        }
    }

    @Test("boing 的过冲活到了渲染：中间帧比恒等帧更大")
    func boingOvershootSurvivesInterpolation() throws {
        let amount = 0.45
        let mid = -1 + amount
        let scale = Boing.scale(at: mid, amplitude: 0.6)
        #expect(scale > 1.1, "取样点选错了：phaseValue = \(mid) 处的缩放是 \(scale)，没有过冲可测")

        let identity = try #require(Self.render(BoingMotion(phaseValue: 0, amplitude: 0.6, isReduced: false)))
        let overshoot = try #require(
            Self.interpolatedPixels(
                BoingMotion(phaseValue: -1, amplitude: 0.6, isReduced: false),
                towards: BoingMotion(phaseValue: 0, amplitude: 0.6, isReduced: false),
                amount: amount
            ),
            "插值失败 —— `BoingMotion` 不是 `Animatable`，过冲永远画不出来"
        )
        #expect(overshoot != identity, "过冲那一帧与恒等帧相同 —— 缩放没有接到渲染上")

        let identityArea = Self.contentFootprint(in: identity)
        let overshootArea = Self.contentFootprint(in: overshoot)
        #expect(overshootArea > identityArea, """
        过冲帧的内容面积（\(overshootArea)）不大于恒等帧（\(identityArea)）
        —— 缩放在中间帧没有超过 1，`boing` 退化成了一次普通的 `.scale` 转场。
        """)
    }

    static func contentFootprint(in frame: Frame) -> Int {
        let data = frame.bytes
        guard data.count >= 4 else { return 0 }
        let background = [data[0], data[1], data[2], data[3]]
        var count = 0
        var index = 0
        while index + 3 < data.count {
            if data[index] != background[0] || data[index + 1] != background[1]
                || data[index + 2] != background[2] || data[index + 3] != background[3] {
                count += 1
            }
            index += 4
        }
        return count
    }

    // MARK: - ④ Reduce Motion（位图 + 源码，两条链都要）

    @Test("Reduce Motion：运动全部去掉，剩下的恰好是那条淡入淡出（且不是 no-op）")
    func reduceMotionLeavesExactlyTheCrossFade() throws {
        for probe in Self.probes {
            for v in [-0.7, -0.35, 0.35, 0.7] {
                let reduced = try #require(probe.render(v, true), "\(probe.name)：降级帧渲染失败")
                let full = try #require(probe.render(v, false), "\(probe.name)：正常帧渲染失败")
                let fade = try #require(Self.renderCrossFade(at: v), "对照组渲染失败")

                #expect(reduced != full, """
                \(probe.name) @ \(v)：Reduce Motion 开与关渲染出同一张位图
                —— 门控是摆设，运动根本没有被去掉。
                """)
                #expect(reduced == fade, """
                \(probe.name) @ \(v)：降级那一帧与「只加 `.opacity(\(TransitionCurve.opacity(v)))`」
                的对照组不同 —— 还有一处运动 / 模糊 / 拉伸没有被门控掉。
                ⚠️ 先查 `MicroInteractionReduceMotionGuard.motionCalls` **关键字表之外**的东西
                （`blur(`、`scaleEffect(x:y:)` 的某一个轴、`perspective`）：守卫看不见它们，
                只有这条相等断言看得见。
                """)
            }

            let atIdentity = try #require(probe.render(0, true))
            let atEndpoint = try #require(probe.render(-0.5, true))
            #expect(atIdentity != atEndpoint, """
            \(probe.name)：Reduce Motion 下不同相位渲染出同一张位图 —— 降级成了 no-op，
            开启该偏好的用户会看到界面瞬间跳变（#250 第 1 轮因此被打回）。
            """)
        }
    }

    @Test("层 2：reduceMotion 只许原样喂给层 3 的 isReduced:，一次都不许另作他用")
    func chromeOnlyRelaysReduceMotion() throws {
        for probe in Self.probes {
            let code = MicroInteractionReduceMotionGuard.stripComments(
                try TypewriterTextTests.source(probe.file)
            )
            let declarations = code.components(separatedBy: "@Environment(\\.accessibilityReduceMotion)").count - 1
            #expect(declarations == 1, """
            \(probe.file) 里 `@Environment(\\.accessibilityReduceMotion)` 出现 \(declarations) 次
            —— 本簇约定每个转场只有层 2 一处读它。
            """)

            let reads = code.components(separatedBy: "self.reduceMotion").count - 1
            let relayed = code.components(separatedBy: "isReduced: self.reduceMotion").count - 1
            #expect(relayed == 1, "\(probe.file) 没有把 reduceMotion 原样递给层 3 的 `isReduced:`")
            #expect(reads == relayed, """
            \(probe.file) 里 `self.reduceMotion` 出现 \(reads) 次，只有 \(relayed) 次是
            递给层 3 的 —— 多出来的是层 2 自己又判了一遍，位图判据看不见那一次
            （它测的是层 3）。
            """)

            let strays = MicroInteractionReduceMotionGuard.bareReduceMotionOccurrences(in: code)
            #expect(strays.isEmpty, """
            \(probe.file) 里这些 `reduceMotion` 既不是声明、也不是实参标签、更不是
            `self.reduceMotion`：\n\(strays.joined(separator: "\n"))
            —— 去掉 `self.` 就能绕过上面按字面子串的计数。
            """)
        }
    }

    @Test("层 2 的类型体里没有任何绘制调用（只转发）")
    func chromeDoesNothingButForward() throws {
        for probe in Self.probes {
            let code = MicroInteractionReduceMotionGuard.stripComments(
                try TypewriterTextTests.source(probe.file)
            )
            let typeName = probe.file.replacingOccurrences(of: "Transition.swift", with: "Chrome")
            guard let body = ConfettiTests.bracedRegion(after: "struct \(typeName)", in: code) else {
                Issue.record("\(probe.file)：找不到层 2 类型 `\(typeName)` 的类型体")
                continue
            }
            for call in MicroInteractionReduceMotionGuard.motionCalls where body.contains(call) {
                Issue.record("\(typeName) 里出现了运动调用 `\(call)` —— 层 2 只许转发")
            }
            for call in ["opacity(", "blur(", "background(", "overlay("] where body.contains(call) {
                Issue.record("\(typeName) 里出现了绘制调用 `\(call)` —— 层 2 只许转发")
            }
        }
    }

    @Test("六个转场文件在形态 2 名单上，且都不在早退名单上")
    func transitionFilesTakeTheTernaryGateNotAnEarlyExit() {
        for probe in Self.probes {
            #expect(MicroInteractionReduceMotionGuard.approvedFormTwo.contains(probe.file),
                    "\(probe.file) 不在形态 2 名单上")
            #expect(!MicroInteractionReduceMotionGuard.approvedEarlyExit.contains(probe.file), """
            \(probe.file) 进了早退名单 —— 本簇有意走逐表达式三元门控：
            早退是**整段豁免**，`everyMotionCallIsGated` 的射程反而更窄
            （理由见 `TransitionSupport.swift` 顶部）。
            """)
        }
    }

    // MARK: - ⑤ 层 1 → 层 2 → 层 3 的接线

    static func storedProperties(in typeBody: String) -> [String] {
        var names: [String] = []
        for rawLine in typeBody.split(separator: "\n", omittingEmptySubsequences: false) {
            var line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.contains("=") else { continue }
            for modifier in ["public ", "private "] where line.hasPrefix(modifier) {
                line = String(line.dropFirst(modifier.count))
            }
            guard line.hasPrefix("let ") || line.hasPrefix("var ") else { continue }
            let rest = line.dropFirst(4)
            guard let colon = rest.firstIndex(of: ":") else { continue }
            let name = rest[rest.startIndex..<colon].trimmingCharacters(in: .whitespaces)
            guard let first = name.first, !first.isNumber,
                  name.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else { continue }
            names.append(name)
        }
        return names
    }

    @Test("层 1 交给层 2、层 2 交给层 3，两跳都必须把每一个存储属性原样带下去")
    func transitionBodyWiresEveryStoredPropertyDownOneLayer() throws {
        for probe in Self.probes {
            let code = MicroInteractionReduceMotionGuard.stripComments(
                try TypewriterTextTests.source(probe.file)
            )

            let transitionBody = try #require(
                ConfettiTests.bracedRegion(after: "public struct \(probe.transitionType): Transition", in: code),
                "\(probe.file)：找不到层 1 类型 `\(probe.transitionType)` 的类型体"
            )
            let layerOne = try #require(
                ConfettiTests.bracedRegion(
                    after: "func body(content: Content, phase: TransitionPhase)", in: transitionBody
                ),
                "\(probe.file)：找不到层 1 的 `body(content:phase:)`"
            )

            #expect(layerOne.contains("\(probe.chromeType)("), """
            \(probe.transitionType).body 没有构造层 2 的 `\(probe.chromeType)`
            —— 读 `\\.accessibilityReduceMotion` 的那一层被绕过了，
            该转场在生产中**永远不会降级**（`#267` 终审 C-2 的变异形态）。
            """)
            #expect(!layerOne.contains("Motion("), """
            \(probe.transitionType).body 直接构造了层 3 的绘制 modifier —— 跳过了层 2。
            层 1 拿不到 `@Environment`（它不是 `View`），Reduce Motion 只能在层 2 读到。
            """)
            #expect(!layerOne.contains("isReduced"), """
            \(probe.transitionType).body 里出现了 `isReduced` —— 层 1 无从知道这件事，
            它只可能是被写死的常量（`#267` 终审 C-2 的变异正是 `isReduced: false`）。
            """)
            #expect(layerOne.contains("TransitionCurve.value(of: phase)"), """
            \(probe.transitionType).body 没有把 `phase` 过 `TransitionCurve.value(of:)`
            —— 相位契约（三个真实相位 ⇒ -1 / 0 / 1）在这一层就断了。
            """)

            let ownParameters = Self.storedProperties(in: transitionBody)
            #expect(!ownParameters.isEmpty, """
            \(probe.transitionType) 一个存储属性都没有 —— 下面那个 for 循环会空转，
            这条判据于是恒真（互锁）。
            """)
            for name in ownParameters {
                #expect(layerOne.contains("self.\(name)"), """
                \(probe.transitionType).body 没有把存储属性 `\(name)` 传给
                `\(probe.chromeType)` —— 调用方给的这个参数被丢掉了，
                该转场对 `\(name)` 的取值不再有任何反应，而位图判据（它们直接构造层 3）
                看不见这件事。
                """)
            }

            let chromeBody = try #require(
                ConfettiTests.bracedRegion(after: "struct \(probe.chromeType)", in: code),
                "\(probe.file)：找不到层 2 类型 `\(probe.chromeType)` 的类型体"
            )
            let layerTwo = try #require(
                ConfettiTests.bracedRegion(after: "func body(content: Content)", in: chromeBody),
                "\(probe.file)：找不到层 2 的 `body(content:)`"
            )

            #expect(layerTwo.contains("\(probe.motionType)("),
                    "\(probe.chromeType).body 没有构造层 3 的 `\(probe.motionType)`")
            #expect(layerTwo.contains("isReduced: self.reduceMotion"), """
            \(probe.chromeType).body 没有把 `self.reduceMotion` 原样递给层 3 的 `isReduced:`
            —— 位图判据直接构造层 3，`isReduced` 是它们自己给的，看不见这一跳。
            """)

            let relayed = Self.storedProperties(in: chromeBody)
            #expect(!relayed.isEmpty, "\(probe.chromeType) 一个存储属性都没有 —— 下面的循环空转（互锁）")
            for name in relayed {
                #expect(layerTwo.contains("self.\(name)"), """
                \(probe.chromeType).body 没有把 `\(name)` 传给 `\(probe.motionType)`
                —— 层 2 把它吞了，绘制层拿到的是写死的值。
                """)
            }
        }
    }

    @Test("六条转场都声明 hasMotion == true（系统那道 Reduce Motion 闸必须留着）")
    func everyTransitionKeepsTheSystemGateOpen() {
        #expect(TransitionProperties(hasMotion: false).hasMotion == false,
                "`hasMotion` 恒为 true —— 下面六条断言不作数")

        #expect(FlipTransition.properties.hasMotion, "`.flip` 关掉了系统那道 Reduce Motion 闸")
        #expect(Rotate3DTransition.properties.hasMotion, "`.rotate3D` 关掉了系统那道 Reduce Motion 闸")
        #expect(SwooshTransition.properties.hasMotion, "`.swoosh` 关掉了系统那道 Reduce Motion 闸")
        #expect(BoingTransition.properties.hasMotion, "`.boing` 关掉了系统那道 Reduce Motion 闸")
        #expect(SkidTransition.properties.hasMotion, "`.skid` 关掉了系统那道 Reduce Motion 闸")
        #expect(PolarMoveTransition.properties.hasMotion, "`.move` 关掉了系统那道 Reduce Motion 闸")
    }

    @Test("经 Transition.apply 走完整条链：恒等帧与裸内容逐字节相同，两端各是一张空背景")
    func realTransitionEntryPointRendersTheWholeChain() throws {
        let plain = try #require(Self.renderPlain(), "对照组渲染失败")
        #expect(plain.bytes.contains(where: { $0 != 0 }), "对照组位图全 0 —— 相等断言恒真")
        let blank = try #require(Self.renderCrossFade(at: 1), "空背景对照组渲染失败")
        #expect(blank != plain, "「不透明度 0」与裸内容渲成同一张图 —— 下面的断言不作数")

        for probe in Self.probes {
            let identity = try #require(probe.applied(.identity), "\(probe.name)：apply(.identity) 渲染失败")
            #expect(identity == plain, """
            \(probe.name) 经 `Transition.apply(content:phase:)` 在 `.identity` 上渲出的那一帧
            与裸内容不同 —— 层 1 / 层 2 里有与相位无关的残留，转场停住之后画面被**永久**改了。
            """)
            for phase in [TransitionPhase.willAppear, .didDisappear] {
                let endpoint = try #require(probe.applied(phase), "\(probe.name)：apply(\(phase)) 渲染失败")
                #expect(endpoint == blank, """
                \(probe.name) 在 \(phase) 上没有渲成一张空背景 —— `TransitionCurve.opacity(±1)`
                本该恰为 0。⚠️ 这条**不**能证明运动接上了（端点上不透明度为 0，位图对任何
                实现都一样）：那件事归 `transitionBodyWiresEveryStoredPropertyDownOneLayer`。
                """)
            }
        }
    }

    // MARK: - ⑥ 绝对方向

    static func contentCentroid(in frame: Frame) -> (x: Double, y: Double)? {
        let width = Int(Self.canvasWidth)
        let height = Int(Self.canvasHeight)
        let bytes = Array(frame.bytes)
        guard bytes.count == width * height * 4 else { return nil }
        let background = (bytes[0], bytes[1], bytes[2], bytes[3])
        var sumX = 0.0
        var sumY = 0.0
        var count = 0.0
        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                guard bytes[index] != background.0 || bytes[index + 1] != background.1
                        || bytes[index + 2] != background.2 || bytes[index + 3] != background.3
                else { continue }
                sumX += Double(x)
                sumY += Double(y)
                count += 1
            }
        }
        guard count > 0 else { return nil }
        return (sumX / count, sumY / count)
    }

    @Test("四条边的方向是绝对的：单位向量、位移、甩尾角逐个钉死（含 .top / .bottom）")
    func absoluteDirectionsMatchTheDocumentedEdges() {
        #expect(TransitionCurve.value(of: .willAppear) == -1,
                "进场相位不是 -1 —— 六条转场的进出方向全反了")
        #expect(TransitionCurve.value(of: .didDisappear) == 1,
                "出场相位不是 +1 —— 六条转场的进出方向全反了")

        #expect(TransitionCurve.direction(of: .leading) == CGSize(width: -1, height: 0))
        #expect(TransitionCurve.direction(of: .trailing) == CGSize(width: 1, height: 0))
        #expect(TransitionCurve.direction(of: .top) == CGSize(width: 0, height: -1))
        #expect(TransitionCurve.direction(of: .bottom) == CGSize(width: 0, height: 1))

        #expect(Swoosh.travel(at: -1, along: .trailing, points: 80) == CGSize(width: 80, height: 0),
                "`.swoosh(edge: .trailing)` 不是从右边进 —— 文档那张表反了")
        #expect(Swoosh.travel(at: -1, along: .leading, points: 80) == CGSize(width: -80, height: 0))
        #expect(Swoosh.travel(at: -1, along: .top, points: 80) == CGSize(width: 0, height: -80))
        #expect(Swoosh.travel(at: -1, along: .bottom, points: 80) == CGSize(width: 0, height: 80))

        #expect(Skid.travel(at: -1, along: .leading, points: 80) == CGSize(width: -80, height: 0),
                "`.skid(edge: .leading)` 不是从左边滑进来")
        #expect(Skid.travel(at: -1, along: .trailing, points: 80) == CGSize(width: 80, height: 0))
        #expect(Skid.travel(at: -1, along: .top, points: 80) == CGSize(width: 0, height: -80))
        #expect(Skid.travel(at: -1, along: .bottom, points: 80) == CGSize(width: 0, height: 80))

        #expect(Skid.tilt(at: -1, along: .leading) == -Skid.maximumTilt,
                "从左边滑进来时车身没有往左甩")
        #expect(Skid.tilt(at: -1, along: .trailing) == Skid.maximumTilt)
        #expect(Skid.tilt(at: -1, along: .top) == Skid.maximumTilt,
                "纵向进出的甩尾方向（`SkidTransition` 里那条 `-Double(unit.height)`）反了")
        #expect(Skid.tilt(at: -1, along: .bottom) == -Skid.maximumTilt)

        let right = PolarMove.travel(at: -1, radians: 0, distance: 80)
        #expect(right == CGSize(width: 80, height: 0), "`.move(angle: .degrees(0))` 不是向右")
        let down = PolarMove.travel(at: -1, radians: .pi / 2, distance: 80)
        #expect(abs(down.width) < 1e-9 && abs(down.height - 80) < 1e-9,
                "`.move(angle: .degrees(90))` 不是向下（SwiftUI 的 y 轴朝下），实测 \(down)")

        #expect(Flip.angle(at: -1) == -FlipTransition.quarterTurn)
        #expect(Flip.angle(at: 1) == FlipTransition.quarterTurn)
        #expect(Rotate3D.angle(at: -1, degrees: 75) == -75)
    }

    @Test("绝对方向在像素上也成立：内容真的画在文档说的那一侧")
    func absoluteDirectionsReachThePixels() throws {
        let plain = try #require(Self.renderPlain(), "对照组渲染失败")
        let base = try #require(Self.contentCentroid(in: plain), "对照组重心求不出来")

        var cases: [(String, Frame?, Int, Int)] = []
        for (edge, dx, dy) in [(Edge.trailing, 1, 0), (.leading, -1, 0), (.top, 0, -1), (.bottom, 0, 1)] {
            cases.append((
                "swoosh(edge: .\(edge)) @ -0.6",
                Self.render(SwooshMotion(phaseValue: -0.6, edge: edge, points: 80, isReduced: false)),
                dx, dy
            ))
        }
        cases.append((
            "skid(edge: .leading) @ -0.5（过冲段 ⇒ 冲到右边）",
            Self.render(SkidMotion(phaseValue: -0.5, edge: .leading, points: 80, isReduced: false)), 1, 0
        ))
        cases.append((
            "skid(edge: .top) @ -0.5（过冲段 ⇒ 冲到下边）",
            Self.render(SkidMotion(phaseValue: -0.5, edge: .top, points: 80, isReduced: false)), 0, 1
        ))
        cases.append((
            "move(radians: 0) @ -0.6",
            Self.render(PolarMoveMotion(phaseValue: -0.6, radians: 0, distance: 80, isReduced: false)), 1, 0
        ))
        cases.append((
            "move(radians: π/2) @ -0.6",
            Self.render(PolarMoveMotion(phaseValue: -0.6, radians: .pi / 2, distance: 80, isReduced: false)), 0, 1
        ))

        let threshold = 6.0
        for (label, frame, dx, dy) in cases {
            let rendered = try #require(frame, "\(label)：渲染失败")
            let centroid = try #require(
                Self.contentCentroid(in: rendered),
                "\(label)：重心求不出来（画布上没有非背景像素？）"
            )
            let movedX = centroid.x - base.x
            let movedY = centroid.y - base.y
            if dx != 0 {
                #expect(Double(dx) * movedX > threshold, """
                \(label)：内容的重心在 x 上偏了 \(movedX) px，方向与文档相反（期望 \(dx > 0 ? "右" : "左")）。
                ⚠️ 先看 `TransitionCurve.direction(of:)` 的四个向量是不是被整体变号了
                —— 那种改法下所有**对称性**判据都还是绿的。
                """)
            } else {
                #expect(abs(movedX) < threshold, "\(label)：x 本不该动，却偏了 \(movedX) px")
            }
            if dy != 0 {
                #expect(Double(dy) * movedY > threshold, """
                \(label)：内容的重心在 y 上偏了 \(movedY) px，方向与文档相反（期望 \(dy > 0 ? "下" : "上")）。
                """)
            } else {
                #expect(abs(movedY) < threshold, "\(label)：y 本不该动，却偏了 \(movedY) px")
            }
        }
    }

    // MARK: - ⑦ 公开入口点

    @Test("十二个静态成员都写得出来（编译期存在性），且渲染不崩")
    func entryPointsExist() {
        let views: [AnyView] = [
            AnyView(Text(verbatim: "x").transition(.flip)),
            AnyView(Text(verbatim: "x").transition(.flip(axis: .vertical))),
            AnyView(Text(verbatim: "x").transition(.rotate3D)),
            AnyView(Text(verbatim: "x").transition(.rotate3D(angle: .degrees(120), axis: .depth))),
            AnyView(Text(verbatim: "x").transition(.swoosh)),
            AnyView(Text(verbatim: "x").transition(.swoosh(edge: .top, travel: .long))),
            AnyView(Text(verbatim: "x").transition(.boing)),
            AnyView(Text(verbatim: "x").transition(.boing(strength: .pronounced))),
            AnyView(Text(verbatim: "x").transition(.skid)),
            AnyView(Text(verbatim: "x").transition(.skid(edge: .bottom, travel: .short))),
            AnyView(Text(verbatim: "x").transition(.move)),
            AnyView(Text(verbatim: "x").transition(.move(angle: .degrees(-45), distance: 40))),
        ]
        for (index, view) in views.enumerated() {
            #expect(MicroInteractionAPITests.stablePixels(view) != nil, "第 \(index) 个入口渲染失败")
        }
    }

    @Test("含参重载的实参真的落在类型上")
    func parametersAreStored() {
        #expect(FlipTransition(axis: .depth).axis == .depth)
        #expect(Rotate3DTransition(angle: .degrees(30), axis: .vertical).angle == .degrees(30))
        #expect(Rotate3DTransition().angle == .degrees(Rotate3DTransition.defaultDegrees))
        #expect(SwooshTransition(edge: .top, travel: .long).travel == .long)
        #expect(BoingTransition(strength: .subtle).strength == .subtle)
        #expect(SkidTransition(edge: .bottom, travel: .short).edge == .bottom)
        #expect(PolarMoveTransition(angle: .degrees(10), distance: 33).distance == 33)
        #expect(PolarMoveTransition().distance == TransitionTravel.regular.points)
    }

    @Test("系统的 .move(edge:) 仍解析到 SwiftUI 的 MoveTransition，我们的走 PolarMoveTransition")
    func systemMoveEdgeStillResolvesToSwiftUI() {
        let system: MoveTransition = .move(edge: .top)
        #expect(String(describing: type(of: system)) == "MoveTransition",
                "系统的 `.move(edge:)` 被我们截胡了")

        let ours: PolarMoveTransition = .move
        let alsoOurs: PolarMoveTransition = .move(angle: .degrees(45), distance: 20)
        #expect(String(describing: type(of: ours)) == "PolarMoveTransition")
        #expect(alsoOurs.distance == 20)
    }

    // MARK: - ⑧ 共享枚举

    @Test("行程档位严格递增，3D 轴向量两两不同")
    func sharedEnumsAreWellFormed() {
        let points = TransitionTravel.allCases.map(\.points)
        #expect(points == points.sorted(), "行程档位不是递增的：\(points)")
        #expect(Set(points).count == points.count, "行程档位有重复值：\(points)")

        let vectors = TransitionAxis3D.allCases.map { "\($0.vector)" }
        #expect(Set(vectors).count == vectors.count, "两个轴的向量相同：\(vectors)")

        let horizontal = TransitionAxis3D.horizontal.vector
        #expect(horizontal.x == 0 && horizontal.y == 1 && horizontal.z == 0,
                "`.horizontal` 的转轴不是竖直的 Y 轴 —— 命名是按「内容往哪转」定的，容易记反")
    }

    @Test(".tilted 未归一化是无害的：轴向量整体缩放不改变渲染出的那一帧")
    func axisVectorLengthDoesNotChangeTheRenderedRotation() throws {
        _ = Self.warmUp
        let tilted = TransitionAxis3D.tilted.vector
        let length = (tilted.x * tilted.x + tilted.y * tilted.y + tilted.z * tilted.z).squareRoot()
        #expect(length != 1, "`.tilted` 已经是单位向量了 —— 本条的前提没了，删掉它")

        func frame(_ axis: (x: CGFloat, y: CGFloat, z: CGFloat)) -> Frame? {
            MicroInteractionAPITests.stablePixels(
                Self.canvas(
                    Self.content.rotation3DEffect(
                        .degrees(Rotate3DTransition.defaultDegrees),
                        axis: axis,
                        perspective: Rotate3D.perspective
                    )
                )
            ).map(Frame.init)
        }
        let unit = (x: tilted.x / length, y: tilted.y / length, z: tilted.z / length)
        for _ in 0..<8 {
            _ = frame(tilted)
            _ = frame(unit)
        }
        let asWritten = try #require(frame(tilted), "渲染失败")
        let normalized = try #require(frame(unit), "渲染失败")
        #expect(asWritten == normalized, """
        `(1, 1, 0)` 与它归一化后的向量渲出了**不同**的一帧
        —— `rotation3DEffect` 的 `axis` 不再只是一个方向，`.tilted` 必须改成单位向量。
        """)
    }
}
