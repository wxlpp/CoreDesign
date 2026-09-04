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
// ⚠️ **系统还有一道同向的闸**：`TransitionProperties.hasMotion` 默认 `true`
//（`swiftinterface` 逐字：`public init(hasMotion: Swift.Bool = true)`），
// 而 `hasMotion` 的文档**逐字**是：
//
// > Whether the transition includes motion.
// > When this behavior is included in a transition, that transition will be
// > replaced by opacity when Reduce Motion is enabled.
// > Defaults to `true`.
//
// ⚠️ 上一版这里写的是**转述**却声称"逐字"，已按 SDK 原文改（#267 终审 I-3）。
// ⚠️ 上一版还写着"本簇六个转场都保留该默认值"——那是一句关于**别人家默认实现**的断言，
// 而当时全仓 `grep "TransitionProperties\|hasMotion"` **零命中声明**（姊妹 PR #289 终审）。
// 现在六条**显式声明** `hasMotion: true`，由 `everyTransitionKeepsTheSystemGateOpen` 钉住。
//
// ⇒ 本文件量的是**本仓代码里**那一道门控，不是系统那一道；两道的分工——以及
// **系统那道先触发时内层三元在生产中不可达**这一面——写在 `FlipTransition` 的类型文档里。
// 两道闸的**结论一致**（都降级成一次纯淡入淡出），分歧只在"谁做的"。
// 别把本文件的 Reduce Motion 判据全绿读成"用户看到的降级是我们亲手做的"。

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

    // MARK: 一帧位图（带**短**失败信息）

    /// 一帧 RGBA8 位图。**相等语义仍是逐字节**，只是失败时不再把整张图倒进日志。
    ///
    /// ⚠️ **不要把 `Data` 直接交给 `#expect(a == b)`**（`#267` 终审 S-2，本轮实测复现）：
    /// `Data` 是 `Collection`，Swift Testing 会为它算一份"差异"并打印出来 —— 实测一次
    /// `identity == plain` 判红产出**一行 21927 字符**的 `inserted [208, 208, 208, 248, …]`，
    /// 而其中有用的信息只有「不相等」这一条。本 suite 有几十处位图相等断言，
    /// 一次红就足以淹掉整份 CI 日志。
    /// ⇒ 包一层非 `Collection` 的值类型：差异打印不再触发，`description` 只给
    /// 字节数 + 指纹，需要定位时再看 `firstDifference(from:)`。
    struct Frame: Equatable, Hashable, CustomStringConvertible {

        let bytes: Data

        /// ⚠️ **逐字节**，不是比指纹 —— 指纹只进日志。
        static func == (lhs: Frame, rhs: Frame) -> Bool { lhs.bytes == rhs.bytes }

        func hash(into hasher: inout Hasher) { hasher.combine(self.bytes) }

        /// 第一个相异字节的下标；完全相同时 `nil`。只在失败信息里求值。
        func firstDifference(from other: Frame) -> Int? {
            let mine = Array(self.bytes)
            let theirs = Array(other.bytes)
            let shared = min(mine.count, theirs.count)
            for index in 0..<shared where mine[index] != theirs[index] { return index }
            return mine.count == theirs.count ? nil : shared
        }

        var description: String { "帧(\(self.bytes.count) 字节，指纹 \(Self.digest(self.bytes)))" }

        /// FNV-1a 64 位。**只作日志标签**——判等不走它（指纹相同不蕴含字节相同）。
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

    /// ⚠️⚠️⚠️ **承重（`#267` 终审 C-3）：本 suite 用到的每一条渲染管线都必须先跑热。**
    ///
    /// 症状：`interpolationIsContinuousNotAnEndpointJump` 里
    /// 「插值出的那一帧」与「直接用同一个相位值构造的那一帧」应当逐字节相同，
    /// 而**隔离跑必红、全量跑约每 3 次红 1 次**（iOS 腿从不红）。插值出的 `Double`
    /// 与直接构造的那个**按位相同**（已实测）⇒ 不是数值问题。
    ///
    /// 根因是 `MicroInteractionAPITests.processWarmUp` 早就记下的那一条的推广形态：
    /// `ImageRenderer` 带**跨调用的进程状态**，某条渲染管线**在进程内第一次被走到**时
    /// 产出的字节与之后不同 ⇒ 「谁先被渲染谁就是那个异类」。上一版只暖了
    /// `FlipMotion`（不含 `blur`），而咬人的是 `swoosh` 的**模糊**那条管线
    ///（把 `Swoosh.maximumBlur` 改成 0 ⇒ 隔离 3/3 转绿，实测）。
    ///
    /// ⇒ **不要再手写"补上漏掉的那一条"**——那是在追症状。本闭包直接遍历
    /// `Self.probes`，把每个转场的**开 / 关降级**两条路径、以及两个对照组
    /// （裸内容 / 纯淡入淡出）各跑 8 次。新增一条转场时它自动被暖到。
    ///
    /// ⚠️ **`probes` 的闭包在这里必须走 `rawRender`（不暖机的那个）**：
    /// 走 `render` 会在 `warmUp` 自己的初始化过程中再次读 `Self.warmUp`
    /// ——那是对一个正在初始化的 `static let` 的重入访问。
    ///
    /// ⚠️ 本簇**不标 `.serialized`**（与并行的 `#266` 处置不同，理由记在此）：
    /// 上面这条 flake 在**隔离跑**（本 suite 是进程里唯一的 suite）时同样复现
    /// ⇒ 它不是"别的 suite 插进来打乱了顺序"，串行化对它无效；而本 suite 是
    /// `@MainActor` + 全同步测试，suite 内部本来就不可能交错。真正的因是
    /// 「某条管线的首帧」，修法只能是把管线跑热。
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

    /// **对照组**：一层 modifier 都不套的裸内容。
    static func rawPlain() -> Frame? {
        MicroInteractionAPITests.stablePixels(Self.canvas(Self.content)).map(Frame.init)
    }

    static func renderPlain() -> Frame? {
        _ = Self.warmUp
        return Self.rawPlain()
    }

    /// **对照组**：只做 `TransitionCurve.opacity` 那条淡入淡出的内容
    /// ——也就是「Reduce Motion 降级**应该**长的样子」。
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

    /// 取出 `animatableData`。**撤掉 `Animatable` 一致性 ⇒ 返回 `nil` ⇒ 判据运行时红**
    ///（而不是整个测试 target 编译不过——后者在变异实证里读不出是哪条判据在咬，
    /// `ParticleTransitionTests.interpolatedLayer` 记着同一条）。
    static func animatableProgress(_ modifier: Any) -> Double? {
        (modifier as? any Animatable)?.animatableData as? Double
    }

    /// 取两端的 `animatableData`、按 `amount` 插值、写回，再渲染那一帧。
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

    /// 把「构造第 N 个转场的层 3」这件事收成闭包，六条判据因此可以**逐个转场**跑同一套。
    ///
    /// ⚠️ **不能直接存 `any ViewModifier`**：`View.modifier(_:)` 的返回类型
    /// `ModifiedContent<Self, T>` 提到了 `T`，存在类型开箱在这种签名上不成立
    ///（实测编译红）⇒ 存的是"渲染到位图"的闭包。
    struct Probe {
        let name: String
        let file: String
        /// **不暖机**的 `(phaseValue, isReduced) -> 位图`。⚠️ 只给 `warmUp` 用；
        /// 判据一律走下面的 `render(_:_:)`（理由见 `warmUp`）。
        let rawRender: (Double, Bool) -> Frame?
        /// `(from, to, amount) -> 插值那一帧的位图`
        let interpolate: (Double, Double, Double) -> Frame?
        /// `phaseValue -> 该 modifier 的 animatableData`
        let animatable: (Double) -> Double?
        /// `TransitionPhase -> 经**层 1 的 `Transition.apply(content:phase:)`** 渲出的那一帧。
        ///
        /// ⚠️ 这是**唯一**一条真的从第 1 层入口进去的位图路径：`apply(content:phase:)`
        /// 是 `SwiftUICore` 上公开的非下划线成员，它内部会走 `body(content:phase:)`。
        /// 它只能喂三个真实相位（`TransitionPhase` 是 3 case frozen enum），
        /// 而其中两个端点的不透明度恰为 0 ⇒ **端点上位图是瞎的**。
        /// ⇒ 层 1→2→3 的接线由源码判据
        /// `transitionBodyWiresEveryStoredPropertyDownOneLayer` 承担，本闭包只钉恒等相位。
        let applied: (TransitionPhase) -> Frame?
        /// 进出两侧是否**异向**（穿行）。`false` = 同侧进出。
        let directional: Bool

        /// 判据用的取样入口：先把渲染管线跑热，再取像素。
        func render(_ phaseValue: Double, _ isReduced: Bool) -> Frame? {
            _ = TransitionClusterTests.warmUp
            return self.rawRender(phaseValue, isReduced)
        }

        /// 层 1 的类型名（`FlipTransition`…），由文件名推出。
        var transitionType: String { self.file.replacingOccurrences(of: ".swift", with: "") }

        /// 层 2 的类型名（`FlipChrome`…）。
        var chromeType: String { self.file.replacingOccurrences(of: "Transition.swift", with: "Chrome") }

        /// 层 3 的类型名（`FlipMotion`…）。
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

    /// 经**层 1 的公开入口** `Transition.apply(content:phase:)` 渲一帧。
    static func applied(_ transition: some Transition, at phase: TransitionPhase) -> Frame? {
        _ = Self.warmUp
        return MicroInteractionAPITests
            .stablePixels(Self.canvas(transition.apply(content: Self.content, phase: phase)))
            .map(Frame.init)
    }

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

    // MARK: - ⑤ 层 1 → 层 2 → 层 3 的接线

    /// 从一段类型体源码里取出**存储属性**的名字（`let x: T` / `public let x: T`）。
    ///
    /// ⚠️ 只认「带类型标注、整行不含 `=`、名字是合法标识符」的行 ⇒
    /// `public nonisolated static let quarterTurn: Double = 90`（静态常量，不是每实例
    /// 的参数）、`let travel = Skid.travel(…)`（函数体里的局部量）都进不来。
    /// ⚠️ **不写死一张属性清单**：写死的话「新加一个参数却忘了往下传」正是抓不到的
    /// 那一类——名单不改，判据不动。从源码里现取才有射程。
    static func storedProperties(in typeBody: String) -> [String] {
        var names: [String] = []
        for rawLine in typeBody.split(separator: "\n", omittingEmptySubsequences: false) {
            var line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.contains("=") else { continue }
            if line.hasPrefix("public ") { line = String(line.dropFirst("public ".count)) }
            guard line.hasPrefix("let ") else { continue }
            let rest = line.dropFirst("let ".count)
            guard let colon = rest.firstIndex(of: ":") else { continue }
            let name = rest[rest.startIndex..<colon].trimmingCharacters(in: .whitespaces)
            guard let first = name.first, !first.isNumber,
                  name.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else { continue }
            names.append(name)
        }
        return names
    }

    /// ⚠️⚠️⚠️ **承重（`#267` 终审 C-1 / C-2）：整层被绕过，上面每一条判据都照样绿。**
    ///
    /// 上一版的失效形态，逐字记在这里免得再来一次：本文件的 `probes` 用**字面量**
    /// 直接构造第 3 层（`FlipMotion(phaseValue:axis:isReduced:)`…），
    /// 仓库里**没有任何东西**求值过 `XTransition.body(content:phase:)` 或
    /// `XChrome.body(content:)` ⇒
    ///
    /// · 把六条 `XTransition.body` **全部**改成丢弃调用方参数（`.move` ⇒
    ///   `radians: 0, distance: 0` 即裸淡入淡出、`.swoosh` / `.skid` ⇒ `points: 0`、
    ///   `.flip(axis:)` 恒 `.horizontal`、`.rotate3D(angle:)` ⇒ `degrees: 0`、
    ///   `.boing(strength:)` 恒 `.regular`）—— `swift test` **748 全绿**；
    /// · 把 `FlipTransition.body` 改成直接套 `FlipMotion(…, isReduced: false)`
    ///   （即 `.flip` 在生产中**永不读** `\.accessibilityReduceMotion`）—— 同样 748 全绿，
    ///   连 `reduceMotionLeavesExactlyTheCrossFade` / `chromeOnlyRelaysReduceMotion` /
    ///   8 条 `MicroInteractionReduceMotionGuard` 一起绿（`FlipChrome` 类型还在文件里，
    ///   所有**扫源码**的判据继续匹配）。
    ///
    /// ⇒ 缺的不是"某个数算错"，是**整层被绕过**。位图判据在这里帮不上忙：
    /// 第 1 层唯一的公开求值入口 `Transition.apply(content:phase:)` 只吃三个真实相位，
    /// 而两个端点的不透明度恰为 0（见 `Probe.applied`）⇒ 位图在端点上是瞎的。
    /// ⇒ 本条走**源码**，按「每一个存储属性都必须**逐层往下传**」这条结构性契约钉：
    /// 上面每一枚变异都会让某个 `self.<属性>` 从对应的 `body` 里消失，或让
    /// `XChrome(` 变成 `XMotion(`。形态取自 `ProcessingSweepTests.containersDelegateToDriver`。
    @Test("层 1 交给层 2、层 2 交给层 3，两跳都必须把每一个存储属性原样带下去")
    func transitionBodyWiresEveryStoredPropertyDownOneLayer() throws {
        for probe in Self.probes {
            let code = MicroInteractionReduceMotionGuard.stripComments(
                try TypewriterTextTests.source(probe.file)
            )

            // ── 层 1：`XTransition.body(content:phase:)` ──────────────────────────
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

            // ── 层 2：`XChrome.body(content:)` ───────────────────────────────────
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

    /// ⚠️⚠️⚠️ **承重：系统那道 Reduce Motion 闸的开关，本仓从前一处都没声明过。**
    ///
    /// 姊妹 PR `#289` 的终审查实：全仓 `grep "TransitionProperties\|hasMotion"`
    /// **零命中声明** ⇒ 所有自定义 `Transition` 都在**继承**
    /// `Transition.properties` 的默认实现（`hasMotion` 默认 `true`，
    /// `swiftinterface` 逐字：`public init(hasMotion: Swift.Bool = true)`）。
    /// 而六个文件的类型文档都写着「本簇六个转场**都保留默认值**」——
    /// 那是一句关于**别人家默认实现**的断言，本仓没有任何东西证过它。
    ///
    /// ⚠️ 真正的风险不是"默认值变了"，是**有人主动写下 `hasMotion: false`**：
    /// 那会把系统那道闸整个关掉，而本仓的降级判据**一条都不会红**
    ///（它们量的是层 3 的三元门控，与 `properties` 无关）。
    /// ⇒ 六条现在都**显式声明** `hasMotion: true`，本条逐条钉住。
    /// 这是「钉**性质**」而不是「钉形状」的判据 —— 与 C-1 那族源码判据互补。
    @Test("六条转场都声明 hasMotion == true（系统那道 Reduce Motion 闸必须留着）")
    func everyTransitionKeepsTheSystemGateOpen() {
        // 互锁：先证 `hasMotion` 真的是个能取 `false` 的量，否则下面六条恒真。
        #expect(TransitionProperties(hasMotion: false).hasMotion == false,
                "`hasMotion` 恒为 true —— 下面六条断言不作数")

        #expect(FlipTransition.properties.hasMotion, "`.flip` 关掉了系统那道 Reduce Motion 闸")
        #expect(Rotate3DTransition.properties.hasMotion, "`.rotate3D` 关掉了系统那道 Reduce Motion 闸")
        #expect(SwooshTransition.properties.hasMotion, "`.swoosh` 关掉了系统那道 Reduce Motion 闸")
        #expect(BoingTransition.properties.hasMotion, "`.boing` 关掉了系统那道 Reduce Motion 闸")
        #expect(SkidTransition.properties.hasMotion, "`.skid` 关掉了系统那道 Reduce Motion 闸")
        #expect(PolarMoveTransition.properties.hasMotion, "`.move` 关掉了系统那道 Reduce Motion 闸")
    }

    /// **位图那一半**：真的从第 1 层的公开入口 `Transition.apply(content:phase:)` 走一遍。
    ///
    /// ⚠️ **它能证的只有恒等相位**，别把它当成上一条的替代：`TransitionPhase` 是
    /// 3 case frozen enum，而 `.willAppear` / `.didDisappear` 两个端点的
    /// `TransitionCurve.opacity` 恰为 0 ⇒ 那两帧对**任何**实现都渲成同一张空背景。
    /// 恒等相位这一帧仍然承重：它是转场停住之后用户**长期**看到的那一帧，
    /// 而这条路径把层 1 → 层 2 → 层 3 整条链真的求值了一遍
    ///（`identityFrameIsIndistinguishableFromPlainContent` 只走层 3）。
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

    /// 非背景像素的**重心**（画布像素坐标）。背景色取第一个像素，理由同 `contentFootprint`。
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

    /// ⚠️⚠️ **承重（`#267` 终审 I-1）：方向是**绝对**的，不只是对称的。**
    ///
    /// `directionSemanticsMatchTheDocumentedTable` 断的全是**相对**关系
    /// （`travel(-1) == -travel(1)`、同侧两端相等），而这些关系在
    /// `TransitionCurve.direction(of:)` 四个向量**整体变号**下**一条都不变**。
    /// 实测：把那四个向量逐个取反（`.swoosh(edge: .trailing)` 于是从**左**边进、
    /// 上下对调），全量测试只剩一条既有的 flake ⇒ 四个方向全反而全绿。
    /// 这与本仓「滑块左右画反、而标签把两半都标错」是同一族缺陷。
    ///
    /// ⇒ 本条钉**绝对**取值，并把从未被行使过的 `.top` / `.bottom`
    /// 与 `Skid.tilt` 的**纵向分支**（`SkidTransition.swift` 里那个 `-Double(unit.height)`）
    /// 一起拉进射程。
    @Test("四条边的方向是绝对的：单位向量、位移、甩尾角逐个钉死（含 .top / .bottom）")
    func absoluteDirectionsMatchTheDocumentedEdges() {
        // ① 单位向量**指向那条边的外侧**（SwiftUI 的 y 轴朝下 ⇒ `.top` 是 -1）。
        #expect(TransitionCurve.direction(of: .leading) == CGSize(width: -1, height: 0))
        #expect(TransitionCurve.direction(of: .trailing) == CGSize(width: 1, height: 0))
        #expect(TransitionCurve.direction(of: .top) == CGSize(width: 0, height: -1))
        #expect(TransitionCurve.direction(of: .bottom) == CGSize(width: 0, height: 1))

        // ② swoosh：`.willAppear`（-1）落在 `edge` **那一侧**（正 x = 右、正 y = 下）。
        #expect(Swoosh.travel(at: -1, along: .trailing, points: 80) == CGSize(width: 80, height: 0),
                "`.swoosh(edge: .trailing)` 不是从右边进 —— 文档那张表反了")
        #expect(Swoosh.travel(at: -1, along: .leading, points: 80) == CGSize(width: -80, height: 0))
        #expect(Swoosh.travel(at: -1, along: .top, points: 80) == CGSize(width: 0, height: -80))
        #expect(Swoosh.travel(at: -1, along: .bottom, points: 80) == CGSize(width: 0, height: 80))

        // ③ skid：两端整段行程落在 `edge` 那一侧（`elastic(±1)` 恰为 `amplitude`）。
        #expect(Skid.travel(at: -1, along: .leading, points: 80) == CGSize(width: -80, height: 0),
                "`.skid(edge: .leading)` 不是从左边滑进来")
        #expect(Skid.travel(at: -1, along: .trailing, points: 80) == CGSize(width: 80, height: 0))
        #expect(Skid.travel(at: -1, along: .top, points: 80) == CGSize(width: 0, height: -80))
        #expect(Skid.travel(at: -1, along: .bottom, points: 80) == CGSize(width: 0, height: 80))

        // ④ Skid.tilt 的**纵向分支**：`sign = -unit.height`，与横向分支符号相反。
        //    ⚠️ 断绝对值而不是"两者相反" —— 整体变号下"相反"这条关系不变。
        #expect(Skid.tilt(at: -1, along: .leading) == -Skid.maximumTilt,
                "从左边滑进来时车身没有往左甩")
        #expect(Skid.tilt(at: -1, along: .trailing) == Skid.maximumTilt)
        #expect(Skid.tilt(at: -1, along: .top) == Skid.maximumTilt,
                "纵向进出的甩尾方向（`SkidTransition` 里那条 `-Double(unit.height)`）反了")
        #expect(Skid.tilt(at: -1, along: .bottom) == -Skid.maximumTilt)

        // ⑤ move 的极角：0° 指向右、90° 指向下。
        let right = PolarMove.travel(at: -1, radians: 0, distance: 80)
        #expect(right == CGSize(width: 80, height: 0), "`.move(angle: .degrees(0))` 不是向右")
        let down = PolarMove.travel(at: -1, radians: .pi / 2, distance: 80)
        #expect(abs(down.width) < 1e-9 && abs(down.height - 80) < 1e-9,
                "`.move(angle: .degrees(90))` 不是向下（SwiftUI 的 y 轴朝下），实测 \(down)")

        // ⑥ 两条旋转类：`.willAppear` 取负角。
        #expect(Flip.angle(at: -1) == -FlipTransition.quarterTurn)
        #expect(Flip.angle(at: 1) == FlipTransition.quarterTurn)
        #expect(Rotate3D.angle(at: -1, degrees: 75) == -75)
    }

    /// 上一条的**位图那一半**：方向不只是算对了，还得真的画在那一侧。
    ///
    /// 量的是「非背景像素的重心相对裸内容偏了多少」——取样点全部避开 ±1
    /// （那里不透明度为 0，画布上一个非背景像素都没有，重心不存在）。
    @Test("绝对方向在像素上也成立：内容真的画在文档说的那一侧")
    func absoluteDirectionsReachThePixels() throws {
        let plain = try #require(Self.renderPlain(), "对照组渲染失败")
        let base = try #require(Self.contentCentroid(in: plain), "对照组重心求不出来")

        /// `(名字, 那一帧, 期望的 x 偏移方向, 期望的 y 偏移方向)`；`0` = 该轴不该动。
        var cases: [(String, Frame?, Int, Int)] = []
        for (edge, dx, dy) in [(Edge.trailing, 1, 0), (.leading, -1, 0), (.top, 0, -1), (.bottom, 0, 1)] {
            cases.append((
                "swoosh(edge: .\(edge)) @ -0.6",
                Self.render(SwooshMotion(phaseValue: -0.6, edge: edge, points: 80, isReduced: false)),
                dx, dy
            ))
        }
        // ⚠️ skid 取 -0.5 —— 那里阻尼余弦**已经翻负号**（过冲段）⇒ 内容冲过了恒等位、
        // 落在**对**侧。这一帧同时是"过冲真的发生了"的方向证据，而 ±1 附近虽然方向直观，
        // 不透明度却只剩 0.05~0.15，重心量不稳。
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

        // 位移量最小的那一格是 skid 的过冲（≈16 pt）⇒ 阈值取 6 px，留足余量又远大于抗锯齿噪声。
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

    /// ⚠️ **这条是编译期的存在性检查，不是渲染检查**（`#267` 终审 S-1）。
    ///
    /// 上一版叫 `entryPointsExistAndRender`、断言 `stablePixels(...) != nil`
    /// ——那条断言**不可能失败**：`.transition(_:)` 不在插入 / 移除语境里是**惰性**的，
    /// 12 个视图全部渲染得与裸 `Text("x")` 一模一样（实测）。
    /// 真正的价值在于「这 12 个静态成员写得出来、类型对得上」，那是编译期的事
    /// ⇒ 名字与断言都按事实改：只留一条"渲染没崩"的非空检查，不再声称"可用于真实视图"。
    /// 真正走完整条链的那一条是 `realTransitionEntryPointRendersTheWholeChain`。
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

    /// `.move` 与系统的 `.move(edge:)` 是重载，不是覆盖。
    ///
    /// ⚠️⚠️ **本条不是命名冲突的守卫，别再当它是**（`#267` 终审 C-4）。
    /// 上一版的文档（本文件、`PolarMoveTransition` 的类型文档、
    /// `docs/components/move-transition.md`）三处都写着「哪天有人把签名改成
    /// `move(edge:)` 就会判红」——**实测是假的**：把那条回归注进去
    ///（新增 `static func move(edge: Edge) -> PolarMoveTransition`），
    /// `swift build` 报 `Build complete!`、本 suite 18 条全过，
    /// 而**同一份源码在真实外部消费者 target 上**报 `error: ambiguous use of 'move(edge:)'`。
    /// 原因就在下面第一行：`let system: MoveTransition = .move(edge: .top)` 的
    /// **显式结果类型标注按返回类型消歧了**；真实调用方写的是无标注的
    /// `.transition(.move(edge: .top))`，那里才会歧义。
    /// ⇒ 真正的守卫搬去了 `scripts/downstream-probe`（跨模块，才复现得出下游的形态）：
    /// `systemMoveEdgeKeepsResolvingToSwiftUI` 与
    /// `systemMoveEdgeIsUnambiguousWithoutAnyAnnotation`。
    /// 本条留下的只是「我们没把系统那个截胡」这一句，射程仅限于此。
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

    /// `#267` 终审 S-4：`.tilted` 是 `(1, 1, 0)`，长度 √2，另外三个 case 都是单位向量。
    ///
    /// ⚠️ **这不是缺陷，本条就是那句话的证据**：`rotation3DEffect(_:axis:)` 的 `axis`
    /// 是一个**方向**，把它整体乘一个正标量不改变旋转。⇒ `(1, 1, 0)` 与归一化后的
    /// `(√2/2, √2/2, 0)` 渲出**逐字节相同**的一帧，写成可读的整数三元组是有意的。
    /// 若哪天这条不再成立（SwiftUI 换了实现），本条判红，那时才该去归一化。
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
        // ⚠️ **这里必须自己再暖一次**（#267 终审 C-3 的同一条）：本条用的
        // `rotation3DEffect` + `perspective` **不带 `scaleEffect`**，是 `warmUp`
        // 覆盖的六条管线之外的第七条 ⇒ 不暖的话首帧是异类，实测会随机判红。
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
