//
//  NetworkGraph.swift
//  CoreDesignCharts
//

import Accessibility
import CoreDesign
import SwiftUI

/// 力导向网络图。
///
/// ⚠️ Swift Charts 画不出来：它没有图布局的概念——节点位置要由**斥力 + 弹簧**迭代解出，
/// 不是把数据映射到坐标轴。
public struct NetworkGraph<Node: GraphNode>: View {

    /// 本图表的边类型 —— 以调用方节点的 `ID` 相连。
    public typealias Edge = GraphEdge<Node.ID>

    /// 建议的节点上限。
    ///
    /// ⚠️ **力导向布局是每帧 O(n²)**。超过此数走"截断 + 静态环形布局"
    /// ——**不抛断言**：库代码对数据规模 `precondition` 就是让宿主 App crash（FR-20）。
    /// ⚠️ 泛型类型不支持 static **存储**属性。
    public static var recommendedNodeLimit: Int { 150 }

    private let nodes: [Node]
    private let edges: [Edge]
    private let tint: Color
    private let title: LocalizedStringResource

    public init(
        nodes: [Node],
        edges: [Edge],
        title: LocalizedStringResource? = nil,
        tint: Color = .accent
    ) {
        self.nodes = nodes
        self.edges = edges
        self.title = title ?? .chart("Relationship graph")
        self.tint = tint
    }

    public var body: some View {
        if self.nodes.isEmpty {
            ChartEmptyState(message: .chart("No data"))
        } else if self.isTruncated {
            // ⚠️ **截断必须对用户可见**（第 2 轮终审 I-4）：上一版 `isTruncated` 只用来
            // 把 `iterations` 置 0，界面与 a11y 都不提示 ⇒ 用户看到的是一张少了节点、
            // 且悄悄从力导向变成环形排布的图，无任何线索。而
            // `"Showing the first %lld nodes"` 这条 string 早就在 `Localizable.strings`
            // 里躺着、全仓零引用——说明原本计划过这个提示，落地时掉了。
            VStack(spacing: 4) {
                self.canvas
                // ⚠️ 写**实际渲染数**而非上限（第 3 轮终审 S-6）：去重后实际渲染数可能 < 150。
                Text(.chart("Showing the first \(self.effectiveNodes.count) nodes"))
                    .font(.caption2)
                    .foregroundStyle(Color.contentTertiary)
            }
        } else {
            self.canvas
        }
    }

    // MARK: - Private

    /// 迭代轮数随节点数收敛，让**单次布局的耗时有上界**。
    ///
    /// ⚠️⚠️ **第 2 轮终审 C-2：上一版写进这里的表格是假的，差 3.1 倍。**
    /// 成因是我的基准把结果用 `_ =` 丢弃 ⇒ 整个 `layout` 调用被**死代码消除**，
    /// 量到的是空气。加 `precondition(r.count == n)` 消费结果 + best-of-3 后复测
    /// （`swift test -c release`，Apple Silicon，390×390，边数 = 2n）：
    ///
    /// | n | 固定 90 轮 | 本函数收敛后 |
    /// |---|---|---|
    /// | 50 | 80 ms | 80 ms（iter 90）|
    /// | 100 | 311 ms | 187 ms（iter 54）|
    /// | 150 | 709 ms | **283 ms**（iter 36）|
    ///
    /// ⚠️ **283 ms ≈ 17 帧**。这就是为什么本组件的布局**不在主线程算**——
    /// 光靠收敛轮数救不了 NFR-1 的「上限内不掉帧」，只能把计算挪出去。
    /// 布局是纯函数（`nonisolated`、入参全值类型、无随机），可安全 detach。
    nonisolated static func iterations(for count: Int) -> Int {
        count <= 60 ? 90 : max(20, 90 * 60 / count)
    }
    /// 建议的**边数**上限。
    ///
    /// ⚠️ **第 3 轮终审 I-5**：上一版只有节点上限，而弹簧回路每轮遍历**全部** edges
    /// ⇒ O(E · iter)，`Path` 每帧画 E 条线段。性能表标注的是「边数 = 2n」即**稀疏图**；
    /// n=150 的稠密图 E 可达 11 175，与斥力回路的配对数同量级 ⇒ 实际耗时约为表中的两倍。
    /// 而 `pairwiseWorkIsBounded` 只算 `n²·iter`，对 E **完全无感**。
    public static var recommendedEdgeLimit: Int { 600 }

    private var effectiveEdges: [Edge] {
        Array(self.edges.prefix(Self.recommendedEdgeLimit))
    }

    /// 超限时截断。⚠️ 截断而不是拒绝——半张图仍有信息量，crash 没有。
    /// ⚠️⚠️ **去重必须在这一层，不能只在 `layout` 内部**（第 3 轮终审 C-2）。
    /// 上一版只在 `layout` 里去重 ⇒ 只保护了 `pos` 字典，而两个消费方拿的是
    /// **未去重的** `effectiveNodes`：`ForEach` 会拿到重复 ID（SwiftUI 未定义行为，
    /// 正是 `layout` 自己注释里点名的那个），descriptor 会多播报一个类目。
    /// ⚠️ 顺序与 `RingChart.effectiveValues` 对齐：**先去重、后截断**。
    /// ⚠️ 而 `NetworkGraphLayoutTests.duplicateIDs` 直接调 `layout` **绕过了本属性**
    /// ⇒ 这个 bug 存在时它是绿的——与第 2 轮判 `overLimitTruncates` 为假绿是同一句理由。
    private var effectiveNodes: [Node] {
        var seen = Set<Node.ID>()
        return Array(self.nodes.filter { seen.insert($0.id).inserted }
            .prefix(Self.recommendedNodeLimit))
    }

    private var isTruncated: Bool {
        self.nodes.count > Self.recommendedNodeLimit || self.edges.count > Self.recommendedEdgeLimit
    }

    /// 布局缓存的失效键。
    ///
    /// ⚠️ **缓存不是过早优化**（终审 I-2）：`layout` 是 90 轮 × O(n²)，初版直接写在
    /// `GeometryReader` 的 body 里 ⇒ **每次 body 求值全量重算**，而 SwiftUI 的 body
    /// 在每次布局/状态变化/旋转/父视图刷新时都会重跑，`GeometryReader` 一帧内被求值
    /// 多次也很常见。FR-20 只挡住了「>150 截断」，**没挡住「恰好 150 时每帧重算」**
    /// ——后者才是真正卡 UI 的那条。
    /// ⚠️ `internal` 是为了可测（第 3 轮终审 I-4）：C-4 修的「截断 ⇒ iterations 归零」
    /// 与「150 → 200 时 key 必须变」此前**零覆盖**——把 `:116` 改回去，516 条测试全绿。
    struct LayoutKey: Equatable, Sendable {
        let ids: [Node.ID]
        let edges: [Edge]
        let size: CGSize
        /// ⚠️ **必须进 key**（第 2 轮终审 C-4）：`iterations` 取决于 `isTruncated`，
        /// 而后者看的是**未截断的** `nodes.count` ——它不在 ids 里。
        /// 150 → 追加 50 个（边与尺寸不变）时 `effectiveNodes` 仍是同样的前 150 个 id
        /// ⇒ key 不变 ⇒ 命中缓存 ⇒ **继续用力导向布局**，而 FR-20 此时要求降级为静态环形。
        let iterations: Int
    }

    func layoutKey(for size: CGSize) -> LayoutKey {
        LayoutKey(
            ids: self.effectiveNodes.map(\.id),
            edges: self.effectiveEdges,
            size: size,
            iterations: self.isTruncated ? 0 : Self.iterations(for: self.effectiveNodes.count)
        )
    }

    /// 已解出的布局。⚠️ 空字典时渲染空 canvas（第一帧），`.task` 解完即填。
    @State private var solved: [Node.ID: CGPoint] = [:]

    private var canvas: some View {
        GeometryReader { proxy in
            let key = self.layoutKey(for: proxy.size)
            let layout = self.solved

            ZStack {
                // 边
                Path { path in
                    for edge in self.effectiveEdges {
                        guard let a = layout[edge.from], let b = layout[edge.to] else { continue }
                        path.move(to: a)
                        path.addLine(to: b)
                    }
                }
                .stroke(Color.dividerDefault, lineWidth: CoreBorderWidth.hairline)

                // 节点
                ForEach(self.effectiveNodes) { node in
                    if let p = layout[node.id] {
                        Circle()
                            .fill(self.tint)
                            .frame(width: 8, height: 8)
                            .position(p)
                    }
                }
            }
            // ⚠️⚠️ **布局不在主线程算**（第 2 轮终审 C-2 / C-3）。两处理由：
            // ① 实测上限处 283 ms ≈ 17 帧，同步跑必然掉帧（NFR-1）；
            // ② 上一版用 `@State` 缓存 + `onChange` 里重算，**每次 key 变化算两遍**
            //    （body 走未命中分支算一次、`onChange` 又算一次）⇒ 比不加缓存更慢。
            // `.task(id:)` 让 key 变才重算、且算在主线程之外。
            //
            // ⚠️⚠️ **取消必须显式传导**（第 3 轮终审 I-1）：上一版注释写「旧任务自动取消」
            // ——**对 detached 子任务不成立**。`Task.detached` 按定义不继承父任务的
            // 优先级、task-local 与**取消**，一旦启动就会跑完整整 `iterations` 轮。
            // 而 `key` 含 `size`，`GeometryReader` 在 resize / 旋转时**逐帧**报新尺寸
            // ⇒ 每帧启动一个不可打断的 solve、旧的继续烧到底 ⇒ 把上一版**有界的卡顿**
            // 换成**无界的 CPU 堆积**。
            .task(id: key) {
                let nodes = self.effectiveNodes
                let edges = self.effectiveEdges
                let handle = Task.detached(priority: .userInitiated) {
                    Self.layout(nodes: nodes, edges: edges,
                                size: key.size, iterations: key.iterations)
                }
                let result = await withTaskCancellationHandler {
                    await handle.value
                } onCancel: {
                    handle.cancel()
                }
                guard !Task.isCancelled else { return }
                self.solved = result
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text(self.title))
        .accessibilityChartDescriptor(self)
    }

    /// 力导向布局：环形初始位置 + N 轮「斥力 + 弹簧」迭代。
    ///
    /// ⚠️ **初始位置必须是环形而不是随机/同点**：所有节点重合时斥力方向未定义，
    /// 归一化零向量会产生 **NaN**，整张图消失（FR-19 点名的退化形态）。
    /// 环形初始保证任意两点初始就不重合。
    nonisolated static func layout(
        nodes: [Node], edges: [Edge], size: CGSize, iterations: Int
    ) -> [Node.ID: CGPoint] {
        guard !nodes.isEmpty else { return [:] }
        // ⚠️ `max(x, 1)` 挡得住 0 与负数，**挡不住 `NaN`**（`max(NaN, 1) == NaN`）
        // 也挡不住 `.infinity`（`cos(θ) * ∞ == NaN`）——终审 I-5 实测
        // `size = CGSize(width: .infinity, height: .infinity)` 让全体节点变 `(nan, nan)`。
        let w = size.width.isFinite ? max(size.width, 1) : 1
        let h = size.height.isFinite ? max(size.height, 1) : 1
        let center = CGPoint(x: w / 2, y: h / 2)
        let radius = min(w, h) / 2 * 0.8

        // ⚠️ **重复 id 必须先去重**（终审 I-4）：`pos` 是以 id 为键的字典，
        // 重复 id 会让后写的覆盖先写的 ⇒ 返回的节点数少于输入，且渲染侧
        // `ForEach` 拿到重复 ID 是 SwiftUI 未定义行为。**保留首次出现**。
        var seen = Set<Node.ID>()
        let nodes = nodes.filter { seen.insert($0.id).inserted }

        var pos = [Node.ID: CGPoint]()
        for (i, node) in nodes.enumerated() {
            let angle = 2 * Double.pi * Double(i) / Double(nodes.count)
            pos[node.id] = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
        }
        guard iterations > 0, nodes.count > 1 else { return pos }

        let ids = nodes.map(\.id)
        let k = sqrt(w * h / Double(nodes.count))

        for step in 0..<iterations {
            var disp = [Node.ID: CGVector](minimumCapacity: ids.count)
            for id in ids { disp[id] = .zero }

            // 斥力：每对节点互推。
            for i in 0..<ids.count {
                for j in (i + 1)..<ids.count {
                    guard let a = pos[ids[i]], let b = pos[ids[j]] else { continue }
                    var dx = a.x - b.x
                    var dy = a.y - b.y
                    var dist = sqrt(dx * dx + dy * dy)
                    // ⚠️ 两点重合 ⇒ 用**确定性**的微小偏移拆开，不是 `random`
                    //（随机会让同一份数据每次布局不同，且测试不可复现）。
                    if dist < 0.01 {
                        dx = Double((i % 7) + 1) * 0.01
                        dy = Double((j % 5) + 1) * 0.01
                        dist = sqrt(dx * dx + dy * dy)
                    }
                    let force = k * k / dist
                    let vx = dx / dist * force
                    let vy = dy / dist * force
                    disp[ids[i]]? += CGVector(dx: vx, dy: vy)
                    disp[ids[j]]? -= CGVector(dx: vx, dy: vy)
                }
            }

            // 弹簧：相连节点互拉。
            for edge in edges {
                guard let a = pos[edge.from], let b = pos[edge.to] else { continue }
                let dx = a.x - b.x
                let dy = a.y - b.y
                let dist = max(sqrt(dx * dx + dy * dy), 0.01)
                let force = dist * dist / k
                let vx = dx / dist * force
                let vy = dy / dist * force
                disp[edge.from]? -= CGVector(dx: vx, dy: vy)
                disp[edge.to]? += CGVector(dx: vx, dy: vy)
            }

            // 退火：步长随迭代衰减，让布局收敛而不是永远抖动。
            let temperature = (1 - Double(step) / Double(iterations)) * min(w, h) * 0.1
            // ⚠️ **钳位边界要先算好，不能写死 `4` 与 `w - 4`**（终审 I-3 实测）：
            // 容器宽 < 8pt 时 `w - 4 < 4`，`min(max(x, 4), w - 4)` 的 min 无条件取到
            // `w - 4` ⇒ 所有节点**坍缩到同一点、且落在容器外**（`size = .zero` 时实测
            // 四个节点全是 `(-3, -3)`）。这同时把 `staysInBounds` 宣称的不变量证伪了。
            let loX = min(4, w / 2), hiX = max(w - 4, loX)
            let loY = min(4, h / 2), hiY = max(h - 4, loY)
            for id in ids {
                guard let d = disp[id], let p = pos[id] else { continue }
                let len = max(sqrt(d.dx * d.dx + d.dy * d.dy), 0.01)
                let limited = min(len, temperature)
                pos[id] = CGPoint(
                    x: min(max(p.x + d.dx / len * limited, loX), hiX),
                    y: min(max(p.y + d.dy / len * limited, loY), hiY)
                )
            }
        }
        return pos
    }
}

/// ⚠️ **必须 `nonisolated`**：本 target 设了 `defaultIsolation(MainActor)`，
/// 它作用于**整个 target**，运算符也不例外。`layout` 是 `nonisolated` 纯函数，
/// 里面调 MainActor 隔离的 `+=` 会报 `#ActorIsolatedCall`。
/// 这是 `ChartValue` 文档里记的同一道摩擦的第四次现身。
private nonisolated extension CGVector {
    static func += (lhs: inout CGVector, rhs: CGVector) {
        lhs = CGVector(dx: lhs.dx + rhs.dx, dy: lhs.dy + rhs.dy)
    }
    static func -= (lhs: inout CGVector, rhs: CGVector) {
        lhs = CGVector(dx: lhs.dx - rhs.dx, dy: lhs.dy - rhs.dy)
    }
}

extension NetworkGraph: AXChartDescriptorRepresentable {
    public func makeChartDescriptor() -> AXChartDescriptor {
        // 网络图没有数值轴——用「每个节点的度数」作为可播报的量。
        var degree = [Node.ID: Int]()
        for e in self.edges {
            degree[e.from, default: 0] += 1
            degree[e.to, default: 0] += 1
        }
        let peak = degree.values.max() ?? 1
        let category = AXCategoricalDataAxisDescriptor(
            title: chartAXString("Node"), categoryOrder: self.effectiveNodes.map(\.label)
        )
        // ⚠️⚠️ **不要写成 `"\(Int($0))"`**——`Accessibility` 框架在构造描述符时会拿
        // **非有限的探针值**调用这个闭包，`Int(非有限)` 直接 trap。
        // 这不是理论：本 target 的空数据 descriptor 测试**当场崩给我看**
        // （`Fatal error: Double value cannot be converted to Int because it is
        // either infinite or NaN`），而在补这批 a11y 断言之前它一直是绿的。
        // ⇒ 走 `formatted`，既不 trap 也不会在大数上溢出。
        let axis = AXNumericDataAxisDescriptor(
            title: chartAXString("Connections"), range: 0...Double(max(peak, 1)), gridlinePositions: []
        ) { $0.formatted(.number.precision(.fractionLength(0))) }
        let series = AXDataSeriesDescriptor(
            name: "", isContinuous: false,
            dataPoints: self.effectiveNodes.map {
                AXDataPoint(x: $0.label, y: Double(degree[$0.id] ?? 0))
            }
        )
        return AXChartDescriptor(
            title: String(localized: self.title), summary: nil,
            xAxis: category, yAxis: axis, additionalAxes: [], series: [series]
        )
    }
}

#Preview("NetworkGraph") {
    nonisolated struct Node: GraphNode {
        let id: String
        let label: String
    }
    let nodes = (0..<14).map { Node(id: "n\($0)", label: "节点 \($0)") }
    let edges = (0..<20).map {
        GraphEdge(from: "n\($0 % 14)", to: "n\(($0 * 5 + 3) % 14)")
    }
    return NetworkGraph(nodes: nodes, edges: edges)
        .frame(height: 300)
        .padding()
}
