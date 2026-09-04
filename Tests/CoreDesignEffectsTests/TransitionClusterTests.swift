import CoreDesign
import Foundation
import SwiftUI
import Testing

@testable import CoreDesignEffects

// MARK: - #267：转场簇 B（3D 与弹性 6 种）
//
// flip / rotate3D / swoosh / boing / skid / move
//
// ⚠️ **本文件的判据分两类，别把第二类当成第一类**：
//
// | 类 | 观测什么 | 例 |
// |---|---|---|
// | **纯函数** | 「给定这个相位值，这条曲线返回什么」 | `identityPhaseIsExactlyNeutral` |
// | **位图** | 「那个数真的接到渲染上了」 | `phaseReachesThePixels` / `reduceMotionLeavesExactlyTheCrossFade` |
//
// 只有纯函数那一类会**恒绿**：曲线算得再对，绘制层没接上去也一样绿。
// ⇒ 每条纯函数判据都有一条位图判据与它互锁，反之亦然。这是 `#253` 终审 C-A
//（粒子在任何真实相位下都画不出来，而全套测试绿）留下的纪律。
//
// ⚠️ **`\.accessibilityReduceMotion` 不可注入**（`EnvironmentValues` 上只读，写它编译红）。
// 本簇的三层形态把它降成层 3 的一个普通 `Bool` 实参，位图路才走得通
// ——形态与理由见 `Sources/CoreDesignEffects/TransitionSupport.swift` 顶部。
// 「层 2 有没有老老实实只做这一件事」由源码判据
// `chromeOnlyRelaysReduceMotion` 接管（`MicroInteractionReduceMotionGuard`
// 的 `reduceMotionIsOnlyConsumedByTheSharedGate` 同形态）。
//
// ⚠️ **系统还有一道同向的闸**：`TransitionProperties.hasMotion` 默认 `true`，
// Apple 文档逐字写着 Reduce Motion 开启时**系统会把整个转场换成 opacity**。
// 本簇六个转场都保留该默认值（它们确实含运动）。⇒ 本文件量的是**本仓代码里**
// 那一道门控，不是系统那一道；两道的分工写在 `FlipTransition` 的类型文档里。

@Suite("转场簇 B：3D 与弹性（#267）")
@MainActor
struct TransitionClusterTests {

    // MARK: - 渲染 harness

    static let contentWidth: CGFloat = 120
    static let contentHeight: CGFloat = 80
    static let canvasWidth: CGFloat = 240
    static let canvasHeight: CGFloat = 200

    /// 被转场包裹的那块内容。**纯色块**——不含字形，避开
    /// `MicroInteractionAPITests.processWarmUp` 记的那条字形光栅化收敛坑。
    static var content: some View {
        Color.surfaceRaised.frame(width: Self.contentWidth, height: Self.contentHeight)
    }

    /// 外层画布。位移 / 缩放要有地方可去，否则被 `.frame` 裁掉就观测不到了。
    static func canvas(_ view: some View) -> some View {
        view
            .frame(width: Self.canvasWidth, height: Self.canvasHeight)
            .background(Color.contentPrimary)
    }

    private static let warmUp: Bool = {
        let probe = Self.canvas(
            Self.content.modifier(FlipMotion(phaseValue: -0.5, axis: .horizontal, isReduced: false))
        )
        for _ in 0..<8 { _ = MicroInteractionAPITests.stablePixels(probe) }
        return true
    }()

    static func render(_ modifier: some ViewModifier) -> Data? {
        _ = Self.warmUp
        return MicroInteractionAPITests.stablePixels(Self.canvas(Self.content.modifier(modifier)))
    }

    /// **对照组**：一层 modifier 都不套的裸内容。
    static func renderPlain() -> Data? {
        _ = Self.warmUp
        return MicroInteractionAPITests.stablePixels(Self.canvas(Self.content))
    }

    /// **对照组**：只做 `TransitionCurve.opacity` 那条淡入淡出的内容
    /// ——也就是「Reduce Motion 降级**应该**长的样子」。
    static func renderCrossFade(at phaseValue: Double) -> Data? {
        _ = Self.warmUp
        return MicroInteractionAPITests.stablePixels(
            Self.canvas(Self.content.opacity(TransitionCurve.opacity(phaseValue)))
        )
    }

    // MARK: - `Animatable` 插值（逐字复刻 SwiftUI 在动画事务里做的三步）

    /// 取出 `animatableData`。**撤掉 `Animatable` 一致性 ⇒ 返回 `nil` ⇒ 判据运行时红**
    ///（而不是整个测试 target 编译不过——后者在变异实证里读不出是哪条判据在咬，
    /// `ParticleTransitionTests.interpolatedLayer` 记着同一条）。
    static func animatableProgress(_ modifier: Any) -> Double? {
        (modifier as? any Animatable)?.animatableData as? Double
    }

    /// 取两端的 `animatableData`、按 `amount` 插值、写回，再渲染那一帧。
    static func interpolatedPixels(_ start: Any, towards end: Any, amount: Double) -> Data? {
        guard let from = start as? (any ViewModifier & Animatable),
              let to = end as? (any Animatable) else { return nil }
        return Self.blendAndRender(from, towards: to, amount: amount)
    }

    private static func blendAndRender<M: ViewModifier & Animatable>(
        _ start: M, towards end: any Animatable, amount: Double
    ) -> Data? {
        guard let target = end.animatableData as? M.AnimatableData else { return nil }
        var out = start
        var data = start.animatableData
        data.interpolate(towards: target, amount: amount)
        out.animatableData = data
        return Self.render(out)
    }

    // MARK: - 六个转场的统一探针

    /// 把「构造第 N 个转场的层 3」这件事收成闭包，六条判据因此可以**逐个转场**跑同一套。
    ///
    /// ⚠️ **不能直接存 `any ViewModifier`**：`View.modifier(_:)` 的返回类型
    /// `ModifiedContent<Self, T>` 提到了 `T`，存在类型开箱在这种签名上不成立
    ///（实测编译红）⇒ 存的是"渲染到位图"的闭包。
    struct Probe {
        let name: String
        let file: String
        /// `(phaseValue, isReduced) -> 位图`
        let render: (Double, Bool) -> Data?
        /// `(from, to, amount) -> 插值那一帧的位图`
        let interpolate: (Double, Double, Double) -> Data?
        /// `phaseValue -> 该 modifier 的 animatableData`
        let animatable: (Double) -> Double?
        /// 进出两侧是否**异向**（穿行）。`false` = 同侧进出。
        let directional: Bool
    }

    static let probes: [Probe] = [
        Probe(
            name: "flip",
            file: "FlipTransition.swift",
            render: { v, r in Self.render(FlipMotion(phaseValue: v, axis: .horizontal, isReduced: r)) },
            interpolate: { from, to, amount in
                Self.interpolatedPixels(
                    FlipMotion(phaseValue: from, axis: .horizontal, isReduced: false),
                    towards: FlipMotion(phaseValue: to, axis: .horizontal, isReduced: false),
                    amount: amount
                )
            },
            animatable: { Self.animatableProgress(FlipMotion(phaseValue: $0, axis: .horizontal, isReduced: false)) },
            directional: true
        ),
        Probe(
            name: "rotate3D",
            file: "Rotate3DTransition.swift",
            render: { v, r in
                Self.render(Rotate3DMotion(phaseValue: v, degrees: 75, axis: .tilted, isReduced: r))
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
            directional: true
        ),
        Probe(
            name: "swoosh",
            file: "SwooshTransition.swift",
            render: { v, r in
                Self.render(SwooshMotion(phaseValue: v, edge: .trailing, points: 80, isReduced: r))
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
            directional: true
        ),
        Probe(
            name: "boing",
            file: "BoingTransition.swift",
            render: { v, r in Self.render(BoingMotion(phaseValue: v, amplitude: 0.6, isReduced: r)) },
            interpolate: { from, to, amount in
                Self.interpolatedPixels(
                    BoingMotion(phaseValue: from, amplitude: 0.6, isReduced: false),
                    towards: BoingMotion(phaseValue: to, amplitude: 0.6, isReduced: false),
                    amount: amount
                )
            },
            animatable: { Self.animatableProgress(BoingMotion(phaseValue: $0, amplitude: 0.6, isReduced: false)) },
            directional: false
        ),
        Probe(
            name: "skid",
            file: "SkidTransition.swift",
            render: { v, r in Self.render(SkidMotion(phaseValue: v, edge: .leading, points: 80, isReduced: r)) },
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
            directional: false
        ),
        Probe(
            name: "move",
            file: "PolarMoveTransition.swift",
            render: { v, r in
                Self.render(PolarMoveMotion(phaseValue: v, radians: .pi / 2, distance: 80, isReduced: r))
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
            directional: false
        ),
    ]

    // MARK: - ① 相位契约（纯函数）

    /// ⚠️⚠️ **承重**：恒等相位是转场停住之后**长期停留**的那一帧。
    /// 它上面留下任何残余（半度旋转、0.98 倍缩放、1pt 位移、一点点模糊）都是**永久**的
    /// ——而且静态截图上几乎看不出来，只有这条判据能抓。
    ///
    /// ⚠️ 断言写 `==` 而不是"约等于"：六条曲线在恒等处都是**精确**归零的
    /// （`elastic` 的衰减窗 `(1-u)²` 在 `u == 1` 处恰为 0；其余都是 `× distance(0)`），
    /// 用容差会把"衰减窗换成 `exp(-ku)`"这类退化放过去。
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

    /// **互锁**：两个端点必须**不是**恒等值，否则上一条只是在说"这些函数恒返回恒等值"。
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

    /// 「穿行」与「同侧进出」是本簇三条位移转场的**语义分界**，各自的文档都写了。
    /// 这条把那张表钉住：改错一处（比如给 `swoosh` 的位移套上 `abs`）当场判红。
    @Test("穿行 / 同侧：flip / rotate3D / swoosh 两端异号，skid / move 两端同值")
    func directionSemanticsMatchTheDocumentedTable() {
        // 异向（`.willAppear` 与 `.didDisappear` 落在相反的位置）。
        #expect(Flip.angle(at: -1) == -Flip.angle(at: 1), "flip 两端不是异号 —— 翻进来和翻出去成了同一个动作")
        #expect(Rotate3D.angle(at: -1, degrees: 75) == -Rotate3D.angle(at: 1, degrees: 75),
                "rotate3D 两端不是异号")
        #expect(Swoosh.travel(at: -1, along: .trailing, points: 80).width
                == -Swoosh.travel(at: 1, along: .trailing, points: 80).width,
                "swoosh 两端不是异号 —— 它就退化成同侧进出（那是 .move 的语义）")

        // 同侧（两端落在同一个位置）。
        #expect(Skid.travel(at: -1, along: .leading, points: 80)
                == Skid.travel(at: 1, along: .leading, points: 80),
                "skid 两端不同 —— 它被改成穿行了")
        #expect(PolarMove.travel(at: -1, radians: .pi / 2, distance: 80)
                == PolarMove.travel(at: 1, radians: .pi / 2, distance: 80),
                "move 两端不同 —— 它被改成穿行了")
        #expect(Boing.scale(at: -1, amplitude: 0.6) == Boing.scale(at: 1, amplitude: 0.6),
                "boing 两端不同 —— 缩放不该有方向")
    }

    /// ⚠️ **过冲是 `.boing` / `.skid` 之所以叫这两个名字的全部理由**。
    /// 没有它，`boing` 就是 SwiftUI 自带的 `.scale`、`skid` 就是 `.move`。
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

    /// ⚠️⚠️ **承重**：上面那些曲线算得再对，绘制层没接上去也一样绿。
    /// `#253` 终审 C-A 逐字记着这个失效形态（粒子层在任何真实相位下都画不出一颗，
    /// 而全套测试通过）。
    @Test("六个转场：端点那一帧与恒等那一帧的位图必须不同（相位真的接到像素上）")
    func phaseReachesThePixels() throws {
        let plain = try #require(Self.renderPlain(), "对照组渲染失败")
        #expect(plain.contains(where: { $0 != 0 }), "对照组位图全 0 —— 下面的相等 / 不等断言都不作数")

        for probe in Self.probes {
            let identity = try #require(probe.render(0, false), "\(probe.name)：恒等帧渲染失败")
            for v in [-1.0, -0.5, 0.5, 1.0] {
                let moved = try #require(probe.render(v, false), "\(probe.name)：相位 \(v) 渲染失败")
                #expect(moved != identity, """
                \(probe.name) 在相位 \(v) 与恒等相位渲染出**同一张**位图
                —— 相位没有接到绘制层上，这条转场对用户不存在。
                """)
            }

            // ⚠️⚠️ **上面那条单独用是弱的**：六个转场都叠了 `TransitionCurve.opacity`，
            // 光靠不透明度变化就能让「与恒等帧不同」成立 ⇒ 把某条几何函数整个改成恒返回
            // 恒等值（旋转恒 0、位移恒 0），上面那条**照样绿**。
            // ⇒ 再与「只有淡入淡出」的对照组比一次：运动那一半必须也在像素上留下痕迹。
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

    /// 「穿行 / 同侧」那张表的**位图**那一半（纯函数那一半是
    /// `directionSemanticsMatchTheDocumentedTable`）。
    ///
    /// 同侧进出的三条（boing / skid / move）在 `±v` 两个相位上位移、缩放、不透明度
    /// **全部相同** ⇒ 位图必须逐字节相同；穿行的三条必须不同。
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

    /// ⚠️⚠️ **承重**：恒等相位必须与「一层 modifier 都不套」**逐字节相同**。
    ///
    /// 这是 `identityPhaseIsExactlyNeutral` 的位图那一半：曲线归零了，
    /// 不代表绘制层没有另外加一点什么（一个 `perspective`、一次多余的合成、
    /// 一个写死的 0.98 缩放）。转场停住之后用户长期看到的就是这一帧。
    @Test("恒等相位与裸内容逐字节相同（转场不改变常驻态的样子）")
    func identityFrameIsIndistinguishableFromPlainContent() throws {
        let plain = try #require(Self.renderPlain(), "对照组渲染失败")
        #expect(plain.contains(where: { $0 != 0 }), "对照组位图全 0 —— 相等断言恒真")

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

    /// ⚠️ **`animatableData` 必须绑在相位值上**。绑到别的字段、或撤掉 `Animatable`
    /// 一致性，本条运行时红。
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

    /// ⚠️⚠️⚠️ **承重（`#267` 任务书点名的雷区之二）：动画是连续插值，不是端点跳变。**
    ///
    /// `TransitionPhase` 只有三个值 ⇒ 中间帧**全部**来自 SwiftUI 对 `animatableData`
    /// 的插值。本条把那一步原样跑一遍（取两端、`interpolate(towards:amount:)`、写回、渲染），
    /// 要求三个不同的插值点：
    ///
    /// 1. 彼此都不同 —— 否则曲线在中段是平的，看起来就是"跳一下"；
    /// 2. 都与两个端点不同 —— 否则那一帧其实还停在端点上；
    /// 3. 与"直接用中间相位值构造"的那一帧**逐字节相同** —— 否则 `animatableData`
    ///    虽然在，但没有绑在真正参与绘制的量上（插值改不动画面）。
    @Test("插值出的中间帧连续可辨，且与直接构造的同相位帧逐字节相同")
    func interpolationIsContinuousNotAnEndpointJump() throws {
        for probe in Self.probes {
            let start = try #require(probe.render(-1, false), "\(probe.name)：起点渲染失败")
            let end = try #require(probe.render(0, false), "\(probe.name)：终点渲染失败")

            var frames: [Double: Data] = [:]
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

    /// ⚠️⚠️ **承重**：`boing` 的过冲必须**渲染得出来**，而不只是纯函数里算得出来。
    ///
    /// 这正是「只把最终 scale 交给 SwiftUI 插值」那种实现会输的地方：
    /// 那样两端之间是一条直线，缩放**永远不会超过 1**，"弹"从未发生
    /// ——而 `elasticCurvesActuallyOvershoot`（纯函数）对它**照样绿**。
    @Test("boing 的过冲活到了渲染：中间帧比恒等帧更大")
    func boingOvershootSurvivesInterpolation() throws {
        // amount = 0.45 ⇒ 中间相位 -0.55 ⇒ 阻尼余弦已翻负号 ⇒ 缩放 > 1。
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

        // 过冲 ⇒ 内容比恒等态**更大** ⇒ 画布上属于内容色的像素更多。
        let identityArea = Self.contentFootprint(in: identity)
        let overshootArea = Self.contentFootprint(in: overshoot)
        #expect(overshootArea > identityArea, """
        过冲帧的内容面积（\(overshootArea)）不大于恒等帧（\(identityArea)）
        —— 缩放在中间帧没有超过 1，`boing` 退化成了一次普通的 `.scale` 转场。
        """)
    }

    /// 数一张位图里**与背景不同**的像素数 —— 也就是内容的占地面积。
    ///
    /// ⚠️ **背景色取位图第一个像素**，不写死颜色、也不按亮度二分：
    /// 内容是 `Color.surfaceRaised`、背景是 `Color.contentPrimary`，两者的明暗关系
    /// **随外观翻转**（浅色下内容更亮，深色下更暗）⇒ 任何亮度阈值都会在另一种外观下判反。
    /// 画布 240×200、内容 120×80 居中 ⇒ 第一个像素必然是背景。
    ///
    /// ⚠️ 只用来比较**同一组** harness 渲染出的两张图的相对大小，不是通用工具。
    static func contentFootprint(in data: Data) -> Int {
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

    /// ⚠️⚠️⚠️ **承重**：AC「位移 / 旋转类降级为淡入淡出，测试可证」。
    ///
    /// 三句话，缺一条另外两条就都可以被绕过：
    ///
    /// 1. **降级真的改变了什么** —— 否则门控是摆设；
    /// 2. **降级后剩下的恰好是那条淡入淡出** —— 与"只加 `.opacity`"的对照组**逐字节相同**。
    ///    ⚠️ 这一条同时守住了 `blur(` / `scaleEffect(x:y:)` 这些
    ///    `MicroInteractionReduceMotionGuard.motionCalls` **关键字表里没有**的东西：
    ///    留一处没门控，位图就不等于纯淡入淡出；
    /// 3. **降级不是 no-op** —— 降级后的两个相位仍然彼此不同（内容还在进出），
    ///    这是 `#250` 第 1 轮被打回的那条。
    @Test("Reduce Motion：运动全部去掉，剩下的恰好是那条淡入淡出（且不是 no-op）")
    func reduceMotionLeavesExactlyTheCrossFade() throws {
        // ⚠️ **取样点有意避开 ±1**：那两处 `TransitionCurve.opacity` 恰为 0，
        // 开与关都渲成一张空背景 ⇒ 「降级真的改变了什么」在那里**恒假**，
        // 而「降级 == 纯淡入淡出」在那里**恒真**（两张空图）。两条断言一起失效。
        // ±1 处的契约由 `endpointsAreNotNeutral` 的 `opacity(v) == 0` 那一条管。
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

            // 不是 no-op：降级之后内容仍然在进出。
            let atIdentity = try #require(probe.render(0, true))
            let atEndpoint = try #require(probe.render(-0.5, true))
            #expect(atIdentity != atEndpoint, """
            \(probe.name)：Reduce Motion 下不同相位渲染出同一张位图 —— 降级成了 no-op，
            开启该偏好的用户会看到界面瞬间跳变（#250 第 1 轮因此被打回）。
            """)
        }
    }

    /// ⚠️ **源码那一条链**：层 2 只许把环境值**原样往下递**，不许自己再判一次。
    ///
    /// 形态逐字取自 `MicroInteractionReduceMotionGuard.reduceMotionIsOnlyConsumedByTheSharedGate`
    /// ——那条守的是能耗闸文件，本条守本簇六个转场（它们不走能耗闸，落在那条的射程之外）。
    /// 只要有人在层 2 写下 `let isReduced = self.reduceMotion` 再自己分支，本条判红。
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

            // ⚠️ 堵掉「去掉 `self.` 就逃逸」：上面两个计数都是按字面子串数的。
            // 复用守卫里那份实现，不另抄一遍。
            let strays = MicroInteractionReduceMotionGuard.bareReduceMotionOccurrences(in: code)
            #expect(strays.isEmpty, """
            \(probe.file) 里这些 `reduceMotion` 既不是声明、也不是实参标签、更不是
            `self.reduceMotion`：\n\(strays.joined(separator: "\n"))
            —— 去掉 `self.` 就能绕过上面按字面子串的计数。
            """)
        }
    }

    /// 层 2 **只做转发**：它的类型体里不许出现任何绘制。
    ///
    /// ⚠️ 形态同 `ProcessingSweepTests.containersDelegateToDriver` /
    /// `CrossPlatformRenderTests.spheresDelegateToSharedSurface`：薄封装自建一套、
    /// 绕过降级，是本仓已经发生过的失效形态。
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

    /// 本簇**有意**不走早退形态：新领一张早退豁免必须改守卫名单，diff 里可见。
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

    // MARK: - ⑤ 公开入口点

    @Test("十二个静态成员都在，且可用于真实视图")
    func entryPointsExistAndRender() {
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

    /// 参数真的存进去了（不是被默认值吞掉）。
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

    /// ⚠️⚠️ **`.move` 与系统的 `.move(edge:)` 是重载，不是覆盖。**
    ///
    /// `SwiftUICore` 自带 `MoveTransition` 与 `Transition.move(edge:)`。本仓的类型
    /// 因此**不叫** `MoveTransition`（同名会让同时 import 两边的下游歧义——而库自己
    /// `swift build` 是绿的，这是最坏的失效形态）。本条把那张解析表钉住。
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

    // MARK: - ⑥ 共享枚举

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
}
