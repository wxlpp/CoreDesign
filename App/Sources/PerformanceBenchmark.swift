@_spi(CoreDesignBenchmark) import CoreDesignCharts
@_spi(CoreDesignBenchmark) import CoreDesignEffects
import SwiftUI
import UIKit

// MARK: - NFR-1 帧率基准 / Frame-rate benchmark
//
// ⚠️⚠️⚠️ **本文件产出的数字在 Simulator 上不构成 NFR-1 的达标证据。**
//
// PRD 的 NFR-1 钉的是「iPhone 15 满帧」。Simulator 没有真实 GPU 调度：合成走宿主 Mac 的
// 显卡与 CoreSimulator 的窗口服务，与被测 App 在真机上的 GPU / CPU 竞争关系没有对应关系。
// ⇒ Simulator 上跑绿**不等于** NFR-1 过；跑红倒是有意义（真机只会更严）。
//
// ⚠️ **截至 `#256` 合入，真机那一次尚未执行**（实现者没有物理设备）。本文件与
// `scripts/run-perf-benchmark.sh` 交付的是「一台可重复跑的秤」，**不是**「NFR-1 已达标」
// 的结论。谁跑了真机，请把 `[perf]` 那几行贴进 issue 并更新这段。
//
// MARK: 为什么基准住在 **App target** 而不是 `App/Tests/`
//
// ⚠️⚠️ **这条是实测逼出来的，不是架构偏好**（`#256`）。
//
// 初版把基准写成 `XCTestCase`，在测试里 `UIHostingController` + `UIWindow` 托管被测视图、
// 用 `CADisplayLink` 采样。结果是：
//
//     [perf] jank(control): frames=119 mean=16.67ms p95=16.87ms max=16.99ms
//            dropped=0.0% bodyEvaluations=1
//
// —— 一个**每帧在主线程死等 40 ms** 的对照组被判成「零掉帧」，而 `bodyEvaluations=1`
// 暴露了真因：**在 unit test 宿主里，被托管视图的 SwiftUI 更新循环根本不转**，
// `TimelineView` 的 body 在整个 2 秒采样窗口里只求值了 **1 次**
// （`.animation` 与 `.periodic(by: 1/60)` 两种 schedule 都试过，都是 1）。
// `CADisplayLink` 照常每 16.67 ms 回调一次（它挂的是 runloop，不是 SwiftUI），
// 于是采样器采到一串完美的 16.67 ms —— **一把只会输出 16.67 的尺**。
//
// ⇒ 被测对象是 `TimelineView` 驱动的常驻渲染件（Confetti / NetworkGraph 的布局与绘制），
// 它们的开销**只在真实 App 的渲染循环里才存在**。基准必须跑在正常启动的 App 里。
// ⇒ 本文件走**启动参数**（`--perf-benchmark`），由 `scripts/run-perf-benchmark.sh`
// 经 `simctl launch --console-pty` / `devicectl ... --console` 拉起并解析 stdout。
//
// MARK: ⚠️⚠️ 第二次栽在同一件事上：**判据通过而被测对象什么都没画**（PR #294 终审 C-2）
//
// 上一版修好了「渲染循环转不转」，却**没有修好「被测对象在不在窗口里干活」**。
// 评审删掉宿主的 `.confetti(trigger:)`、把 `NetworkGraphBenchmarkHost.body` 换成
// `Color.clear`，跑**未改动的**脚本，得到：
//
//     [perf] PASS confetti(default particle count): frames=179 … dropped=0.0%
//     [perf] PASS networkGraph(150n/600e):          frames=191 … dropped=0.0%
//     [perf] PERF-VERDICT: PASS                     ← 退出码 0
//
// 与未变异基线（`dropped=0.5%` / `0.0%`）**不可分辨**。成因是结构性的，两条腿各不相同：
//
// · **Confetti**：`ConfettiBurst.duration = 2.0`，宿主只在 `onAppear` 触发一次；
//   采样窗口是 `[warmUp, warmUp+duration] = [1.0, 4.0]` ⇒ burst 的第一秒（最重的那段）
//   从没被采样，采样的三秒里两秒是**空屏**。
// · **NetworkGraph**：`grep -c TimelineView Sources/CoreDesignCharts/NetworkGraph.swift`
//   = **0**。布局是一次性 `.task(id:)` 派到 `Task.detached`（**主线程之外**），落定后
//   视图完全静止、逐帧零工作 ⇒ 三秒窗口量的是**空闲主线程**；而唯一可能掉帧的时刻
//   （初始求解 + 首帧绘制）落在 1 秒预热里。
//
// ⇒ 本版三处结构性改动，缺一不可：
//   1. **每条腿都有存活读数**（`liveness`），形态照搬对照组原有的 `bodyEvaluations`：
//      confetti 取 `ConfettiRenderProbe.drawnFrames`（画出粒子的帧数）、
//      networkGraph 取 `NetworkGraphRenderProbe.drawnFrames`（真的落笔画了边的帧数），
//      两者都是 `@_spi(CoreDesignBenchmark)` 的库内观测点。
//      `Verdict.passed` **要求窗口内的增量 > `minimumLiveness`**，与既有的
//      `intervals.count > 30` 前置同形 ⇒ 「什么都不画」再也不能判绿。
//   2. **每条腿有各自的窗口**：confetti 由宿主**定时重触发**，让 burst 铺满整个窗口；
//      networkGraph **先等解算落定**（等到第一帧真的画出边）再开采。
//   3. **被测对象在窗口内真的逐帧重绘**：networkGraph 宿主用 `TimelineView` 逐帧换
//      `tint`，强制 `NetworkGraph.body` 每帧重求值、600 条边 + 150 个节点每帧重绘。
//
// MARK: 量的是什么
//
// `CADisplayLink` 回调里取 `CACurrentMediaTime()` 求差 —— 即「主线程隔了多久才回到
// 渲染循环」。⚠️ **不用 `link.timestamp`**，理由是**灵敏度**（PR #294 终审 S-1 纠正）：
// `link.timestamp` 报的是该帧对应的**显示时间戳**（理想节拍），落在节拍格点上；
// 同一轮实测里，平滑腿在 `link.timestamp` 下会量化成恰好 `max=16.67ms`，
// 而 `CACurrentMediaTime()` 在同一次运行里抓到 `max=31.53ms` 的离群值。
// ⚠️ 上一版这里写的理由是「`link.timestamp` 把 40 ms 的对照组也报成 16.67」——
// **实测不成立**：评审把 `link.timestamp` 换回去跑原脚本，对照组仍被抓到
// `50ms / 100%`。那个 16.67 来自上面记的「渲染循环根本没转」（`bodyEvaluations=1`），
// 不是 `link.timestamp` 造成的。结论没变，理由改对。
//
// ⚠️ 它量的是**主线程节拍**，不是 GPU 提交完成时间。真机上 GPU 侧过载会通过反压体现为
// 帧间隔变长，Simulator 上不会 —— 这也是上面那条免责的一部分。

// MARK: - 统计量

/// 一段采样窗口内的帧间隔统计。
struct FrameStats {
    let intervals: [CFTimeInterval]

    /// 本次窗口内**实测**的帧预算（一帧的名义时长）。
    ///
    /// ⚠️⚠️ **不能写死 1/60**（PR #294 终审 I-1）：门槛是它的 1.5 倍，
    /// 而 25 ms 在 120 Hz 屏上是 **3 倍**预算 ⇒ 一台**每两帧掉一帧**的 ProMotion 设备
    /// 会报 `dropped = 0.0%`。而 NFR-1 唯一算数的那次跑在真机上，
    /// iPhone 15 **Pro** 是 PRD 那个「iPhone 15」的合理替代。
    /// ⇒ 运行时从 `CADisplayLink.duration` 取，并打印出来。
    let frameBudget: CFTimeInterval

    /// 判为「掉帧」的帧间隔门槛。
    ///
    /// ⚠️ **取 1.5 × 预算而不是 1.0 ×**：正常帧间隔恰好就是一个预算，
    /// 用 1.0 × 当门槛会让每一帧都算掉帧。1.5 × 让**正常**节拍在门槛内，
    /// 而真掉一帧（2 × 预算）会越线。
    var droppedThreshold: CFTimeInterval { self.frameBudget * 1.5 }

    // ⚠️ 统计量在**空样本**上必须有定义、且不得崩：采样失败时判据要走到
    // 「只拿到 0 帧」那条可读的失败信息上，而不是在 `summary` 里先越界崩掉进程。
    var mean: CFTimeInterval {
        guard !self.intervals.isEmpty else { return 0 }
        return self.intervals.reduce(0, +) / Double(self.intervals.count)
    }

    private func percentile(_ q: Double) -> CFTimeInterval {
        let sorted = self.intervals.sorted()
        guard !sorted.isEmpty else { return 0 }
        let index = min(sorted.count - 1, Swift.max(0, Int((Double(sorted.count) * q).rounded(.down))))
        return sorted[index]
    }

    var p95: CFTimeInterval { self.percentile(0.95) }

    /// ⚠️ 打印出来是给人做**理智检查**用的：若显示器真跑在 120 Hz 而
    /// `link.duration` 报了 16.67 ms，`p05` 会落在 8.3 ms 附近，一眼可见口径不对。
    var p05: CFTimeInterval { self.percentile(0.05) }

    var max: CFTimeInterval { self.intervals.max() ?? 0 }

    /// 超过 `droppedThreshold` 的帧占比。
    var droppedRatio: Double {
        guard !self.intervals.isEmpty else { return 0 }
        let threshold = self.droppedThreshold
        let dropped = self.intervals.filter { $0 > threshold }
        return Double(dropped.count) / Double(self.intervals.count)
    }

    func summary(liveness: Int, livenessLabel: String) -> String {
        String(
            format:
            "frames=%d budget=%.2fms threshold=%.2fms mean=%.2fms p05=%.2fms p95=%.2fms max=%.2fms dropped=%.1f%% %@=%d",
            self.intervals.count,
            self.frameBudget * 1000,
            self.droppedThreshold * 1000,
            self.mean * 1000,
            self.p05 * 1000,
            self.p95 * 1000,
            self.max * 1000,
            self.droppedRatio * 100,
            livenessLabel,
            liveness
        )
    }
}

// MARK: - 采样器

/// 在当前渲染循环上采样帧间隔。
///
/// ⚠️ 采样器**不托管视图**（那正是上面记的失败形态）：被测视图由
/// `PerformanceBenchmarkRunner` 放进 App 自己的 `WindowGroup` 根，
/// 采样器只负责在同一条渲染循环上数拍子。
@MainActor
final class FrameSampler: NSObject {

    private var link: CADisplayLink?
    private var last: CFTimeInterval = 0
    private var samples: [CFTimeInterval] = []
    private var isRecording = false
    /// 窗口内最后一次回调报的名义帧时长。⚠️ 见 `FrameStats.frameBudget`。
    private var nominalDuration: CFTimeInterval = 0

    /// 采样一个窗口，同时把**同一个窗口内**的存活增量一并算出来。
    ///
    /// ⚠️⚠️ **存活探针必须由采样器自己读，不能由调用方在 `record` 之前读**
    /// （PR #294 第 2 轮 S-3）。上一版是调用方写
    /// `let before = Probe.drawnFrames` 再 `await record(warmUp:duration:)` ——
    /// 而 `record` **先睡 `warmUp` 才开采** ⇒ 存活读数覆盖 `warmUp + duration`，
    /// 而 `intervals` 只覆盖 `duration`，**两把尺量的不是同一段时间**。
    /// 实测对得上：confetti 腿 `0.3 + 3.0 = 3.3 s × 60 ≈ 198`，日志里 `drawnFrames=195`。
    ///
    /// ⚠️ 今天没出事**只是余量凑巧**：`0.3 s × 60 = 18 < minimumLiveness(30)`，
    /// 所以「采样窗口全死、只有预热期在画」还过不了关。但谁把 confetti 的 `warmUp`
    /// 调回 **1.0 s**（正是上一版的值，也是对照组腿此刻仍在用的值），
    /// `1.0 × 60 = 60 > 30` ⇒ **一个完全死掉的采样窗口就能靠预热期的读数判绿**，
    /// 刚修好的 C-2 就悄悄回来一半。⇒ 这里取**严格的窗口差值**：
    /// `isRecording = true` 那一刻读一次，`isRecording = false` 那一刻再读一次。
    func record(
        warmUp: TimeInterval,
        duration: TimeInterval,
        liveness: () -> Int
    ) async -> (stats: FrameStats, liveness: Int) {
        let link = CADisplayLink(target: self, selector: #selector(self.tick))
        // ⚠️ 不设 `preferredFrameRateRange`：本基准要量的正是「系统愿意给多少、我们跟不跟得上」，
        // 钉死一个区间等于替被测对象把结论写好。
        link.add(to: .main, forMode: .common)
        self.link = link

        try? await Task.sleep(for: .seconds(warmUp))
        self.samples.removeAll()
        self.last = 0
        self.nominalDuration = 0
        self.isRecording = true
        let livenessBefore = liveness()
        try? await Task.sleep(for: .seconds(duration))
        self.isRecording = false
        let livenessAfter = liveness()

        link.invalidate()
        self.link = nil
        // ⚠️ 兜底 1/60：`duration` 在极少数早期回调上可能是 0。
        // 它是**兜底**，不是默认值 —— 正常路径下这里用的是实测值，且被打印出来。
        let budget = self.nominalDuration > 0 ? self.nominalDuration : 1.0 / 60.0
        return (
            FrameStats(intervals: self.samples, frameBudget: budget),
            livenessAfter - livenessBefore
        )
    }

    @objc
    private func tick(_ link: CADisplayLink) {
        guard self.isRecording else { return }
        if link.duration > 0 { self.nominalDuration = link.duration }
        let now = CACurrentMediaTime()
        defer { self.last = now }
        guard self.last != 0 else { return }
        self.samples.append(now - self.last)
    }
}

// MARK: - 被测宿主

/// Confetti 的基准宿主。
///
/// ⚠️ **除 `trigger` 外一个参数都不传**：AC 要的是「**默认**粒子数不掉帧」，
/// 传 `strength` / `colors` 都会把被测对象换成别的东西。
///
/// ⚠️⚠️ **必须定时重触发**（PR #294 终审 C-2）：一次 burst 只活
/// `ConfettiBurst.duration = 2.0` 秒，结束后 `burstStart` 被清空、整个 `TimelineView`
/// 分支被移除 ⇒ 上一版「`onAppear` 推一次」让采样窗口的后 2/3 在量**空屏**。
/// 这里每 `reburstInterval` 秒推一次，让 burst 在整个窗口内持续处在**粒子最多的前半段**。
private struct ConfettiBenchmarkHost: View {

    /// ⚠️ 必须 **< `ConfettiBurst.duration`（2.0）**，否则两轮之间会露出空屏。
    /// 该常量是库内 `internal`，这里按文档值取半 —— 而 `ConfettiRenderProbe` 的存活读数
    /// 正是「万一它变了」的兜底：真出现空窗，帧数会掉下来被判红，而不是静默变绿。
    static let reburstInterval: Double = 1.0

    @State private var trigger = 0

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .confetti(trigger: self.trigger)
            .task {
                while !Task.isCancelled {
                    self.trigger += 1
                    try? await Task.sleep(for: .seconds(Self.reburstInterval))
                }
            }
    }
}

private struct BenchmarkNode: GraphNode {
    let id: Int
    let label: String
}

/// NetworkGraph 的基准宿主：**恰好用声明的上限**（`recommendedNodeLimit` /
/// `recommendedEdgeLimit`），不多不少 —— AC 是「在声明的节点上限内不掉帧」。
///
/// ⚠️ 多一个节点就走进截断分支（那是另一条契约，不是本基准量的东西）。
private struct NetworkGraphBenchmarkHost: View {

    static let nodes: [BenchmarkNode] = (0..<NetworkGraph<BenchmarkNode>.recommendedNodeLimit)
        .map { BenchmarkNode(id: $0, label: "n\($0)") }

    /// ⚠️⚠️ **步长必须让 600 条边**全不重复**（PR #294 终审 C-1）。上一版写的是
    /// `GraphEdge(from: i % 150, to: (i * 7 + 3) % 150)` —— 而 `7 × 150 ≡ 0 (mod 150)`
    /// ⇒ `edge(i)` 与 `edge(i + 150)` **完全相同**，600 条里只有 **150 条不同的有向边**、
    /// 按无向归一化后只剩 **147** 条：
    ///
    ///     $ python3 -c "n=150;e=600;E=[(i%n,(i*7+3)%n) for i in range(e)];
    ///       print(len(E), len(set(E)), len(set(frozenset(x) for x in E)))"
    ///     600 150 147
    ///
    /// 而 `NetworkGraph.effectiveEdges(visibleIn:)` **按无向去重、且在任何别的事之前做**
    /// ⇒ 那条腿实际跑的是 **150 节点 / 147 边**，标签与「恰好用声明的上限」的注释都是假的。
    /// 边上限 600 在 `NetworkGraph.swift` 里明写「**未实测**……待基准补齐」——
    /// **这份基准本该就是来补齐它的**。
    ///
    /// ⇒ 现在按**环形定距**生成：第 k 圈用步长 `k + 1`，即
    /// `(a, a + 1)`、`(a, a + 2)`、`(a, a + 3)`、`(a, a + 4)`（模 150）各 150 条。
    /// 同一步长内 150 条互不相同；不同步长之间圆周距离不同 ⇒ 也不相同
    /// （前提 `stride < nodes.count / 2`，由 `edgeIntegrity` 的断言守着）。
    static let edges: [GraphEdge<Int>] = (0..<NetworkGraph<BenchmarkNode>.recommendedEdgeLimit)
        .map { index in
            let count = Self.nodes.count
            let from = index % count
            let stride = 1 + index / count
            return GraphEdge(from: from, to: (from + stride) % count)
        }

    /// 输入自检：**让它不能再静默退化**。
    ///
    /// ⚠️ 与 `NetworkGraph` 内部同口径 —— 无向归一化（`a→b` 与 `b→a` 同一条）+ 禁自环
    /// （自环画不出来，`Path` 上是零长度 stroke）。
    static var edgeIntegrity: (unique: Int, selfLoops: Int) {
        var keys = Set<[Int]>()
        var loops = 0
        for edge in Self.edges {
            if edge.from == edge.to { loops += 1 }
            keys.insert([Swift.min(edge.from, edge.to), Swift.max(edge.from, edge.to)])
        }
        return (keys.count, loops)
    }

    var body: some View {
        // ⚠️⚠️ **逐帧换 `tint` 是有意的**（PR #294 终审 C-2）：本组件没有 `TimelineView`，
        // 解算落定后画面完全静止、逐帧零工作 ⇒ 静置采样量的是**空闲主线程**，
        // 与「宿主换成 `Color.clear`」不可分辨。换 `tint` 让 `NetworkGraph.body`
        // 每帧重求值、600 条边 + 150 个节点每帧重绘 —— 那才是 NFR-1 关心的开销。
        // ⚠️ **不动 `size` / 节点集**：那会改 `LayoutKey` ⇒ 每帧重启一次
        // `.task(id:)`，而解算被逐帧取消就永远落不定、`solved` 一直是空的
        // ⇒ 又变回「画不出东西的空 canvas」。`tint` 不进 `LayoutKey`，正好只重绘不重解。
        TimelineView(.animation) { context in
            let phase = context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 3.0) / 3.0
            NetworkGraph(
                nodes: Self.nodes,
                edges: Self.edges,
                tint: Color(hue: phase, saturation: 0.75, brightness: 0.9)
            )
            .padding()
        }
    }
}

/// 秤本身的自检对象：每帧在主线程上死等 40 ms。
///
/// ⚠️ **它存在的唯一理由是证明判据会变红**。没有它，「两条基准都绿」与
/// 「渲染循环根本没转 / 阈值形同虚设」在输出上不可分辨 —— 那正是本仓反复记在案的
/// 「测量工具制造自己的绿」，也正是本文件头记的那次实测事故。
private struct JankBenchmarkHost: View {
    var body: some View {
        TimelineView(.animation) { context in
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay {
                    Text(verbatim: Self.burn(context.date)).opacity(0.001)
                }
        }
    }

    /// ⚠️ `nonisolated(unsafe)`：只在主线程的 body 求值里自增，用来在输出里回答
    /// 「渲染循环到底转了没有」——这正是初版栽的那一跤，留一个常驻读数。
    nonisolated(unsafe) static var evaluations = 0

    nonisolated static func burn(_ date: Date) -> String {
        Self.evaluations += 1
        Thread.sleep(forTimeInterval: 0.04)
        return "\(date.timeIntervalSince1970)"
    }
}

// MARK: - 判据与跑法

enum PerformanceBenchmark {

    /// 启动参数：带上它，App 不进画廊，改跑基准并把结果打到 stdout。
    static let launchArgument = "--perf-benchmark"

    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains(Self.launchArgument)
    }

    /// 允许的掉帧比例。
    ///
    /// ⚠️ **不是 0**：进程本身会在采样窗口里做 I/O 与日志，偶发单帧越线与
    /// 「被测对象扛不住」不是一回事。5% 在 3 s / 180 帧的窗口上约等于「最多 9 帧」。
    static let allowedDroppedRatio: Double = 0.05

    /// 窗口内**必须**观测到的存活读数下限。
    ///
    /// ⚠️ 与既有的 `intervals.count > 30` 同形、同数量级：3 秒窗口在 60 Hz 下
    /// 该有 ~180 个读数，30 是「基本没在动」与「在动」之间一条很宽松的界。
    static let minimumLiveness = 30

    static let warmUp: TimeInterval = 1.0
    static let duration: TimeInterval = 3.0

    /// 一条基准的判定结果。
    struct Verdict {
        let label: String
        let stats: FrameStats
        /// 存活读数：窗口内被测对象**真的干了活**的次数。⚠️ 见文件头 C-2。
        let liveness: Int
        let livenessLabel: String
        /// 期望方向：`true` = 期望不掉帧；`false` = 对照组，期望**被判为**掉帧。
        let expectsSmooth: Bool
        /// 附加读数，原样拼在判词行尾（PR #294 第 2 轮 S-4）。
        ///
        /// ⚠️ 它装的是**输出侧**的量：`liveness` 只回答「在不在画」，
        /// 回答不了「画的是不是该画的那么多」——`graph-input: uniqueUndirected=600`
        /// 与「屏幕上真画了 600 条」之间原本隔着一个在 App 侧平行实现的去重口径。
        var detail: String = ""

        var passed: Bool {
            // ⚠️ 先要求「真的采到了帧」——空数组上后面的比较是恒真的，
            // 那是本仓点名的「零输入 ⇒ 零违规 ⇒ 绿」病型。
            guard self.stats.intervals.count > 30 else { return false }
            // ⚠️⚠️ 再要求「被测对象真的在画」——上一版缺的正是这一条：
            // 什么都不渲染的窗口同样采得到一串完美的 16.67 ms（PR #294 终审 C-2）。
            guard self.liveness > PerformanceBenchmark.minimumLiveness else { return false }
            return self.expectsSmooth
                ? self.stats.droppedRatio <= PerformanceBenchmark.allowedDroppedRatio
                : self.stats.droppedRatio > PerformanceBenchmark.allowedDroppedRatio
        }

        var line: String {
            "[perf] \(self.passed ? "PASS" : "FAIL") \(self.label): "
                + self.stats.summary(liveness: self.liveness, livenessLabel: self.livenessLabel)
                + (self.detail.isEmpty ? "" : " " + self.detail)
        }
    }
}

/// 基准模式下的 App 根视图：逐条把被测视图放进**真实的**渲染循环，采样，打印，退出。
struct PerformanceBenchmarkRunner: View {
    @State private var stage = 0

    var body: some View {
        ZStack {
            switch self.stage {
            case 0: JankBenchmarkHost()
            case 1: ConfettiBenchmarkHost()
            case 2: NetworkGraphBenchmarkHost()
            default: Color.clear
            }
        }
        .task { await Self.run(advance: { self.stage = $0 }) }
    }

    /// 轮询等待某个条件成立，返回等到它用了多久；超时返回 `nil`。
    ///
    /// ⚠️ **超时不是失败路径的终点**：等不到时照样往下采样，让存活读数把这条腿判红
    /// 并把数字打出来 —— 静默 `return` 会让脚本连 `PERF-VERDICT:` 都收不到。
    @MainActor
    private static func waitUntil(
        timeout: TimeInterval, _ condition: @MainActor () -> Bool
    ) async -> TimeInterval? {
        let start = CACurrentMediaTime()
        while CACurrentMediaTime() - start < timeout {
            if condition() { return CACurrentMediaTime() - start }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return nil
    }

    @MainActor
    private static func run(advance: @escaping (Int) -> Void) async {
        print("[perf] --- CoreDesign NFR-1 frame-rate benchmark ---")
        print("[perf] allowedDroppedRatio=\(PerformanceBenchmark.allowedDroppedRatio) "
            + "minimumLiveness=\(PerformanceBenchmark.minimumLiveness)")
        // ⚠️ 帧预算**逐条腿实测**（见 `FrameStats.frameBudget`）；这里额外把屏幕报的
        // 上限打出来，是为了让日志能回答「判词是按哪个节奏算的」。
        let maxFPS = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.screen.maximumFramesPerSecond }
            .max() ?? 0
        // ⚠️ 括注**只在 `maxFPS > 60` 时打**（PR #294 第 2 轮 S-5）：上一版无条件打印，
        // 于是在一台 60 Hz 的设备上也会看到一句关于 ProMotion 的告诫 —— 那句话在那里
        // 既不成立也不可行动；而 iPad Pro 的 ProMotion 本来就不需要那个 Info.plist 键。
        if maxFPS > 60 {
            print("[perf] display: maximumFramesPerSecond=\(maxFPS) "
                + "(⚠️ iPhone 上若未设 CADisableMinimumFrameDurationOnPhone，"
                + "CADisplayLink 仍按 60 Hz 调度；iPad 不需要该键)")
        } else {
            print("[perf] display: maximumFramesPerSecond=\(maxFPS)")
        }
        #if targetEnvironment(simulator)
        print("[perf] environment=SIMULATOR ⚠️ 趋势参考，不构成 NFR-1 达标证据")
        #else
        print("[perf] environment=DEVICE model=\(UIDevice.current.model) os=\(UIDevice.current.systemVersion)")
        #endif

        // ⚠️⚠️ **输入自检先于一切**（PR #294 终审 C-1）：喂进去的边若在
        // `NetworkGraph` 内部被去重成 147 条，那条腿的标签与结论就都是假的。
        // 判红而不是静默继续 —— 而且仍然打 `PERF-VERDICT:`，脚本才不会误诊成「App 没跑起来」。
        let integrity = NetworkGraphBenchmarkHost.edgeIntegrity
        let expectedEdges = NetworkGraph<BenchmarkNode>.recommendedEdgeLimit
        print("[perf] graph-input: nodes=\(NetworkGraphBenchmarkHost.nodes.count) "
            + "edges=\(NetworkGraphBenchmarkHost.edges.count) "
            + "uniqueUndirected=\(integrity.unique) selfLoops=\(integrity.selfLoops) "
            + "(expected unique=\(expectedEdges), selfLoops=0)")
        guard integrity.unique == expectedEdges, integrity.selfLoops == 0 else {
            print("[perf] PERF-VERDICT: FAIL (graph input degenerate: "
                + "unique=\(integrity.unique) selfLoops=\(integrity.selfLoops))")
            print("[perf] --- end ---")
            exit(1)
        }

        var verdicts: [PerformanceBenchmark.Verdict] = []

        // ⚠️ 对照组排**第一个**跑：它红就说明这把秤是坏的，后面两条的「绿」不构成证据。
        advance(0)
        let jank = await FrameSampler().record(
            warmUp: PerformanceBenchmark.warmUp,
            duration: PerformanceBenchmark.duration,
            liveness: { JankBenchmarkHost.evaluations }
        )
        verdicts.append(.init(
            label: "jank(control · 每帧主线程死等 40ms)",
            stats: jank.stats,
            liveness: jank.liveness,
            livenessLabel: "bodyEvaluations",
            expectsSmooth: false
        ))

        // Confetti：宿主定时重触发 ⇒ 整个窗口都有粒子在飞。
        // ⚠️ 预热只留 0.3 s（够第一次 burst 起来），不再是 1.0 s ——
        // 上一版的 1.0 s 正好把最重的第一秒排除在窗口之外。
        advance(1)
        let confetti = await FrameSampler().record(
            warmUp: 0.3,
            duration: PerformanceBenchmark.duration,
            liveness: { ConfettiRenderProbe.drawnFrames }
        )
        verdicts.append(.init(
            label: "confetti(default particle count · 每 \(ConfettiBenchmarkHost.reburstInterval)s 重触发)",
            stats: confetti.stats,
            liveness: confetti.liveness,
            livenessLabel: "drawnFrames",
            expectsSmooth: true,
            detail: "lastFilledParticles=\(ConfettiRenderProbe.lastFilledParticles)"
        ))

        // NetworkGraph：**先等解算落定**再开采。
        // ⚠️ 力导向布局跑在 `Task.detached` 上（主线程之外），Debug 构建下 n=150
        // 要好几秒；在它落定之前 `solved` 是空字典、`Path` 一条边都画不出来
        // ⇒ 直接采样等于量空 canvas（PR #294 终审 C-2 的另一半）。
        advance(2)
        let graphStartProbe = NetworkGraphRenderProbe.drawnFrames
        let solveWait = await Self.waitUntil(timeout: 30) {
            NetworkGraphRenderProbe.drawnFrames > graphStartProbe
        }
        print("[perf] graph-layout: firstDrawnFrameAfter="
            + (solveWait.map { String(format: "%.2fs", $0) } ?? "TIMEOUT(30s)"))
        let graph = await FrameSampler().record(
            warmUp: 0.2,
            duration: PerformanceBenchmark.duration,
            liveness: { NetworkGraphRenderProbe.drawnFrames }
        )
        verdicts.append(.init(
            label: "networkGraph(\(NetworkGraph<BenchmarkNode>.recommendedNodeLimit)n/"
                + "\(integrity.unique)e · 逐帧重绘)",
            stats: graph.stats,
            liveness: graph.liveness,
            livenessLabel: "drawnFrames",
            expectsSmooth: true,
            // ⚠️ 输入侧（`graph-input: uniqueUndirected=`）与输出侧在这里对上：
            // 前者是宿主用 `Set<[Int]>` 算的「喂进去多少条」，后者是库内在
            // `Path` 构造闭包里数的「那一帧真的落笔画了多少条」。
            detail: "lastDrawnEdges=\(NetworkGraphRenderProbe.lastDrawnEdges)"
        ))

        for verdict in verdicts { print(verdict.line) }
        let failed = verdicts.filter { !$0.passed }
        if failed.isEmpty {
            print("[perf] PERF-VERDICT: PASS")
        } else {
            print("[perf] PERF-VERDICT: FAIL (\(failed.map(\.label).joined(separator: ", ")))")
        }
        print("[perf] --- end ---")
        // ⚠️ 自行退出，脚本才能在 `--console` 流上收尾。
        exit(failed.isEmpty ? 0 : 1)
    }
}
