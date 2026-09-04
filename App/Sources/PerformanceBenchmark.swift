import CoreDesignCharts
import CoreDesignEffects
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
// 经 `simctl launch --console` / `devicectl ... --console` 拉起并解析 stdout。
//
// MARK: 量的是什么
//
// `CADisplayLink` 回调里取 `CACurrentMediaTime()` 求差 —— 即「主线程隔了多久才回到
// 渲染循环」。⚠️ **不能用 `link.timestamp`**：它报的是该帧对应的**显示时间戳**（理想节拍），
// 主线程迟到多久它都按 16.67 ms 递增（同一轮实测里它把 40 ms 的对照组也报成 16.67）。
//
// ⚠️ 它量的是**主线程节拍**，不是 GPU 提交完成时间。真机上 GPU 侧过载会通过反压体现为
// 帧间隔变长，Simulator 上不会 —— 这也是上面那条免责的一部分。

// MARK: - 统计量

/// 一段采样窗口内的帧间隔统计。
struct FrameStats {
    let intervals: [CFTimeInterval]

    // ⚠️ 三个统计量在**空样本**上必须有定义、且不得崩：采样失败时判据要走到
    // 「只拿到 0 帧」那条可读的失败信息上，而不是在 `summary` 里先越界崩掉进程。
    var mean: CFTimeInterval {
        guard !self.intervals.isEmpty else { return 0 }
        return self.intervals.reduce(0, +) / Double(self.intervals.count)
    }

    var p95: CFTimeInterval {
        let sorted = self.intervals.sorted()
        guard !sorted.isEmpty else { return 0 }
        let index = min(sorted.count - 1, Int((Double(sorted.count) * 0.95).rounded(.down)))
        return sorted[index]
    }

    var max: CFTimeInterval { self.intervals.max() ?? 0 }

    /// 超过 `PerformanceBenchmark.droppedFrameThreshold` 的帧占比。
    var droppedRatio: Double {
        guard !self.intervals.isEmpty else { return 0 }
        let dropped = self.intervals.filter { $0 > PerformanceBenchmark.droppedFrameThreshold }
        return Double(dropped.count) / Double(self.intervals.count)
    }

    func summary(bodyEvaluations: Int?) -> String {
        var text = String(
            format: "frames=%d mean=%.2fms p95=%.2fms max=%.2fms dropped=%.1f%%",
            self.intervals.count,
            self.mean * 1000,
            self.p95 * 1000,
            self.max * 1000,
            self.droppedRatio * 100
        )
        if let bodyEvaluations { text += " bodyEvaluations=\(bodyEvaluations)" }
        return text
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

    func record(warmUp: TimeInterval, duration: TimeInterval) async -> FrameStats {
        let link = CADisplayLink(target: self, selector: #selector(self.tick))
        // ⚠️ 不设 `preferredFrameRateRange`：本基准要量的正是「系统愿意给多少、我们跟不跟得上」，
        // 钉死一个区间等于替被测对象把结论写好。
        link.add(to: .main, forMode: .common)
        self.link = link

        try? await Task.sleep(for: .seconds(warmUp))
        self.samples.removeAll()
        self.last = 0
        self.isRecording = true
        try? await Task.sleep(for: .seconds(duration))
        self.isRecording = false

        link.invalidate()
        self.link = nil
        return FrameStats(intervals: self.samples)
    }

    @objc
    private func tick(_ link: CADisplayLink) {
        _ = link
        guard self.isRecording else { return }
        let now = CACurrentMediaTime()
        defer { self.last = now }
        guard self.last != 0 else { return }
        self.samples.append(now - self.last)
    }
}

// MARK: - 被测宿主

/// Confetti 的基准宿主：`onAppear` 推一次 trigger，让 burst 在采样窗口内真的在跑。
///
/// ⚠️ **除 `trigger` 外一个参数都不传**：AC 要的是「**默认**粒子数不掉帧」，
/// 传 `strength` / `colors` 都会把被测对象换成别的东西。
private struct ConfettiBenchmarkHost: View {
    @State private var trigger = 0

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .confetti(trigger: self.trigger)
            .onAppear { self.trigger += 1 }
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

    static let edges: [GraphEdge<Int>] = (0..<NetworkGraph<BenchmarkNode>.recommendedEdgeLimit)
        .map { index in
            GraphEdge(from: index % Self.nodes.count, to: (index * 7 + 3) % Self.nodes.count)
        }

    var body: some View {
        NetworkGraph(nodes: Self.nodes, edges: Self.edges).padding()
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

    /// NFR-1 的目标帧预算：PRD 钉的「iPhone 15 满帧」= 60 fps ⇒ 16.67 ms/帧。
    static let targetFrameBudget: CFTimeInterval = 1.0 / 60.0

    /// 判为「掉帧」的帧间隔门槛。
    ///
    /// ⚠️ **取 1.5 × 预算（25 ms）而不是 1.0 ×**，理由是**设备刷新率不是常数**：
    /// 60 Hz 屏上正常帧间隔恰好就是 16.67 ms，用 1.0 × 当门槛会让每一帧都算掉帧；
    /// 120 Hz 屏（ProMotion）在内容平稳时系统会主动降到 60 Hz，同样打在 16.67 ms 上。
    /// 25 ms ≈ 40 fps —— 两种屏的**正常**节拍都在门槛内，而真掉一帧（33 ms）会越线。
    static let droppedFrameThreshold: CFTimeInterval = targetFrameBudget * 1.5

    /// 允许的掉帧比例。
    ///
    /// ⚠️ **不是 0**：进程本身会在采样窗口里做 I/O 与日志，偶发单帧越线与
    /// 「被测对象扛不住」不是一回事。5% 在 2 s / 120 帧的窗口上约等于「最多 6 帧」。
    static let allowedDroppedRatio: Double = 0.05

    static let warmUp: TimeInterval = 1.0
    static let duration: TimeInterval = 3.0

    /// 一条基准的判定结果。
    struct Verdict {
        let label: String
        let stats: FrameStats
        let bodyEvaluations: Int?
        /// 期望方向：`true` = 期望不掉帧；`false` = 对照组，期望**被判为**掉帧。
        let expectsSmooth: Bool

        var passed: Bool {
            // ⚠️ 先要求「真的采到了帧」——空数组上后面的比较是恒真的，
            // 那是本仓点名的「零输入 ⇒ 零违规 ⇒ 绿」病型。
            guard self.stats.intervals.count > 30 else { return false }
            return self.expectsSmooth
                ? self.stats.droppedRatio <= PerformanceBenchmark.allowedDroppedRatio
                : self.stats.droppedRatio > PerformanceBenchmark.allowedDroppedRatio
        }

        var line: String {
            "[perf] \(self.passed ? "PASS" : "FAIL") \(self.label): \(self.stats.summary(bodyEvaluations: self.bodyEvaluations))"
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

    @MainActor
    private static func run(advance: @escaping (Int) -> Void) async {
        print("[perf] --- CoreDesign NFR-1 frame-rate benchmark ---")
        print("[perf] budget=\(String(format: "%.2f", PerformanceBenchmark.targetFrameBudget * 1000))ms "
            + "droppedThreshold=\(String(format: "%.2f", PerformanceBenchmark.droppedFrameThreshold * 1000))ms "
            + "allowedDroppedRatio=\(PerformanceBenchmark.allowedDroppedRatio)")
        #if targetEnvironment(simulator)
        print("[perf] environment=SIMULATOR ⚠️ 趋势参考，不构成 NFR-1 达标证据")
        #else
        print("[perf] environment=DEVICE model=\(UIDevice.current.model) os=\(UIDevice.current.systemVersion)")
        #endif

        var verdicts: [PerformanceBenchmark.Verdict] = []

        // ⚠️ 对照组排**第一个**跑：它红就说明这把秤是坏的，后面两条的「绿」不构成证据。
        advance(0)
        let jank = await FrameSampler().record(
            warmUp: PerformanceBenchmark.warmUp,
            duration: PerformanceBenchmark.duration
        )
        verdicts.append(.init(
            label: "jank(control · 每帧主线程死等 40ms)",
            stats: jank,
            bodyEvaluations: JankBenchmarkHost.evaluations,
            expectsSmooth: false
        ))

        advance(1)
        let confetti = await FrameSampler().record(
            warmUp: PerformanceBenchmark.warmUp,
            duration: PerformanceBenchmark.duration
        )
        verdicts.append(.init(
            label: "confetti(default particle count)",
            stats: confetti,
            bodyEvaluations: nil,
            expectsSmooth: true
        ))

        advance(2)
        let graph = await FrameSampler().record(
            warmUp: PerformanceBenchmark.warmUp,
            duration: PerformanceBenchmark.duration
        )
        verdicts.append(.init(
            label: "networkGraph(\(NetworkGraph<BenchmarkNode>.recommendedNodeLimit)n/\(NetworkGraph<BenchmarkNode>.recommendedEdgeLimit)e)",
            stats: graph,
            bodyEvaluations: nil,
            expectsSmooth: true
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
