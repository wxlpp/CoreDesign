import Accessibility
import CoreDesign
import SwiftUI
import Synchronization

/// 力导向网络图。
public struct NetworkGraph<Node: GraphNode>: View {
    /// 本图表的边类型 —— 以调用方节点的 `ID` 相连。
    public typealias Edge = GraphEdge<Node.ID>

    /// 建议的节点上限。
    /// ⚠️ 「建议」不是软约束：超限即**截断**多余节点并关掉力导向解算器。
    /// ⚠️ 「退化为静态环形」**只对 `.force` 成立**：其余三个 `NetworkGraphLayout` 本就不跑迭代，
    /// 截断后保持各自形态。
    public nonisolated static var recommendedNodeLimit: Int { 150 }

    private let layout: NetworkGraphLayout

    private let nodes: [Node]
    private let edges: [Edge]
    private let tint: Color
    private let title: LocalizedStringResource

    public init(
        nodes: [Node],
        edges: [Edge],
        title: LocalizedStringResource? = nil,
        tint: Color = .dataAccent,
        layout: NetworkGraphLayout = .force
    ) {
        self.layout = layout
        self.nodes = nodes
        self.edges = edges
        self.title = title ?? .chart("Relationship graph")
        self.tint = tint
    }

    public var body: some View {
        if self.nodes.isEmpty {
            ChartEmptyState(message: .chart("No data"))
        } else {
            let shownNodes = self.effectiveNodes
            let visible = Set(shownNodes.map(\.id))
            if self.nodesTruncated || self.edgesTruncated(visibleIn: visible) {
                VStack(spacing: 4) {
                    self.canvas
                    Text(self.nodesTruncated
                         ? .chart("Showing the first \(shownNodes.count) nodes")
                         : .chart("Showing the first \(self.effectiveEdges(visibleIn: visible).count) connections"))
                        .coreFont(.caption2)
                        .foregroundStyle(Color.contentTertiary)
                }
            } else {
                self.canvas
            }
        }
    }

    // MARK: - Private

    nonisolated static func iterations(for count: Int) -> Int {
        count <= 60 ? 90 : max(20, 90 * 60 / count)
    }

    nonisolated static var centeringStrength: Double { 0.10 }

    /// 建议的**边数**上限。
    /// ⚠️ 超限即**静默丢弃**多余的边，且**边超限会连带关掉力导向**——节点没超限时也关。
    /// （只影响 `.force`；其余形态本就不跑迭代，但**边照样被丢弃** ⇒ `.layered` 的分层会变。）
    public nonisolated static var recommendedEdgeLimit: Int { 600 }

    private func effectiveEdges(visibleIn visible: Set<Node.ID>) -> [Edge] {
        Self.firstUnique(
            self.edges, limit: Self.recommendedEdgeLimit, key: UndirectedKey.init,
            where: { visible.contains($0.from) && visible.contains($0.to) }
        )
    }

    private struct UndirectedKey: Hashable {
        private let a: Node.ID
        private let b: Node.ID
        init(_ e: Edge) {
            self.a = e.from
            self.b = e.to
        }
        static func == (lhs: Self, rhs: Self) -> Bool {
            (lhs.a == rhs.a && lhs.b == rhs.b) || (lhs.a == rhs.b && lhs.b == rhs.a)
        }
        func hash(into hasher: inout Hasher) {
            hasher.combine(self.a.hashValue &+ self.b.hashValue)
        }
    }

    private var effectiveNodes: [Node] {
        Self.firstUnique(self.nodes, limit: Self.recommendedNodeLimit, key: \.id)
    }

    private static func firstUnique<Element, Key: Hashable>(
        _ source: [Element], limit: Int, key: (Element) -> Key,
        where isIncluded: (Element) -> Bool = { _ in true }
    ) -> [Element] {
        guard limit > 0 else { return [] }
        var seen = Set<Key>()
        var kept: [Element] = []
        kept.reserveCapacity(min(source.count, limit))
        for element in source where isIncluded(element) && seen.insert(key(element)).inserted {
            kept.append(element)
            if kept.count >= limit { break }
        }
        return kept
    }

    private static func uniqueCountExceeds<Element, Key: Hashable>(
        _ limit: Int, in source: [Element], key: (Element) -> Key,
        where isIncluded: (Element) -> Bool = { _ in true }
    ) -> Bool {
        var seen = Set<Key>()
        for element in source where isIncluded(element) && seen.insert(key(element)).inserted {
            if seen.count > limit { return true }
        }
        return false
    }

    private func isTruncated(visibleIn visible: Set<Node.ID>) -> Bool {
        self.nodesTruncated || self.edgesTruncated(visibleIn: visible)
    }

    private var nodesTruncated: Bool {
        Self.uniqueCountExceeds(Self.recommendedNodeLimit, in: self.nodes, key: \.id)
    }

    private func edgesTruncated(visibleIn visible: Set<Node.ID>) -> Bool {
        Self.uniqueCountExceeds(
            Self.recommendedEdgeLimit, in: self.edges, key: UndirectedKey.init,
            where: { visible.contains($0.from) && visible.contains($0.to) }
        )
    }

    struct LayoutKey: Equatable, Sendable {
        let ids: [Node.ID]
        let edges: [Edge]
        let size: CGSize
        let iterations: Int
        // ⚠️ 必须进 key：`.task(id: key)` 靠它重算，漏了换形态不会重新布局。
        let layout: NetworkGraphLayout
    }

    func layoutKey(for size: CGSize) -> LayoutKey {
        let shownNodes = self.effectiveNodes
        let visible = Set(shownNodes.map(\.id))
        return LayoutKey(
            ids: shownNodes.map(\.id),
            edges: self.effectiveEdges(visibleIn: visible),
            size: size,
            iterations: self.isTruncated(visibleIn: visible) ? 0 : Self.iterations(for: shownNodes.count),
            layout: self.layout
        )
    }

    @State private var solved: [Node.ID: CGPoint] = [:]

    private var canvas: some View {
        GeometryReader { proxy in
            let key = self.layoutKey(for: proxy.size)
            let layout = self.solved

            ZStack {
                Path { path in
                    var drawn = 0
                    for edge in key.edges {
                        guard let a = layout[edge.from], let b = layout[edge.to] else { continue }
                        path.move(to: a)
                        path.addLine(to: b)
                        drawn += 1
                    }
                    if drawn > 0 { NetworkGraphRenderProbe.recordDrawnFrame(edges: drawn) }
                }
                .stroke(Color.dividerDefault, lineWidth: CoreBorderWidth.hairline)

                ForEach(self.effectiveNodes) { node in
                    if let p = layout[node.id] {
                        Circle()
                            .fill(self.tint)
                            .frame(width: 8, height: 8)
                            .position(p)
                    }
                }
            }
            .task(id: key) {
                let nodes = self.effectiveNodes
                let edges = key.edges
                let handle = Task.detached(priority: .userInitiated) {
                    Self.layout(nodes: nodes, edges: edges,
                                size: key.size, iterations: key.iterations,
                                layout: key.layout)
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

    nonisolated static func layout(
        nodes: [Node], edges: [Edge], size: CGSize, iterations: Int,
        layout: NetworkGraphLayout = .force,
        centeringStrength: Double = Self.centeringStrength
    ) -> [Node.ID: CGPoint] {
        guard !nodes.isEmpty else { return [:] }
        let w = size.width.isFinite ? max(size.width, 1) : 1
        let h = size.height.isFinite ? max(size.height, 1) : 1
        let center = CGPoint(x: w / 2, y: h / 2)
        let radius = min(w, h) / 2 * 0.8

        var seen = Set<Node.ID>()
        let nodes = nodes.filter { seen.insert($0.id).inserted }

        var pos = Self.seed(
            layout: layout, nodes: nodes, edges: edges,
            center: center, radius: radius, width: w, height: h
        )
        // ⚠️ **只有 `.force` 会继续跑力导向迭代**：其余三个形态的位置就是播种结果，
        // 迭代会把它们揉回力导向的样子 —— 那正是选那些形态的人不要的。
        guard layout == .force, iterations > 0, nodes.count > 1 else { return pos }

        let ids = nodes.map(\.id)
        let k = sqrt(w * h / Double(nodes.count))
        let centering = centeringStrength.isFinite ? max(centeringStrength, 0) : 0

        for step in 0..<iterations {
            if Task.isCancelled { return pos }
            var disp = [Node.ID: CGVector](minimumCapacity: ids.count)
            for id in ids { disp[id] = .zero }

            for i in 0..<ids.count {
                for j in (i + 1)..<ids.count {
                    guard let a = pos[ids[i]], let b = pos[ids[j]] else { continue }
                    var dx = a.x - b.x
                    var dy = a.y - b.y
                    var dist = sqrt(dx * dx + dy * dy)
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

            for id in ids {
                guard let p = pos[id] else { continue }
                disp[id]? += CGVector(
                    dx: (center.x - p.x) * centering * k,
                    dy: (center.y - p.y) * centering * k
                )
            }

            let temperature = (1 - Double(step) / Double(iterations)) * min(w, h) * 0.1
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
        var degree = [Node.ID: Int]()
        let shownNodes = self.effectiveNodes
        let visible = Set(shownNodes.map(\.id))
        for e in self.effectiveEdges(visibleIn: visible) {
            degree[e.from, default: 0] += 1
            degree[e.to, default: 0] += 1
        }
        let peak = degree.values.max() ?? 1
        let category = AXCategoricalDataAxisDescriptor(
            title: chartAXString("Node"), categoryOrder: shownNodes.map(\.label)
        )
        let axis = AXNumericDataAxisDescriptor(
            title: chartAXString("Connections"), range: 0...Double(max(peak, 1)), gridlinePositions: []
        ) { $0.formatted(.number.precision(.fractionLength(0))) }
        let series = AXDataSeriesDescriptor(
            name: "", isContinuous: false,
            dataPoints: shownNodes.map {
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

// MARK: - 四个布局形态各一个 Preview（Issue #312）
//
// ⚠️ 分开画不是形式主义：`.layered` 的两次退化（12 个点挤一行、14 个点串成一列）
// 在**这份样例数据**上画一次就看见，而当时的值判据全绿。

nonisolated struct NetworkGraphPreviewNode: GraphNode {
    let id: String
    let label: String
}

nonisolated enum NetworkGraphPreviewSample {
    static let nodes = (0..<14).map { NetworkGraphPreviewNode(id: "n\($0)", label: "节点 \($0)") }
    static let edges = (0..<20).map {
        GraphEdge(from: "n\($0 % 14)", to: "n\(($0 * 5 + 3) % 14)")
    }
}

#Preview("NetworkGraph — .force") {
    NetworkGraph(
        nodes: NetworkGraphPreviewSample.nodes, edges: NetworkGraphPreviewSample.edges,
        title: ".force", layout: .force
    )
    .padding()
}

#Preview("NetworkGraph — .circular") {
    NetworkGraph(
        nodes: NetworkGraphPreviewSample.nodes, edges: NetworkGraphPreviewSample.edges,
        title: ".circular", layout: .circular
    )
    .padding()
}

#Preview("NetworkGraph — .grid") {
    NetworkGraph(
        nodes: NetworkGraphPreviewSample.nodes, edges: NetworkGraphPreviewSample.edges,
        title: ".grid", layout: .grid
    )
    .padding()
}

#Preview("NetworkGraph — .layered") {
    NetworkGraph(
        nodes: NetworkGraphPreviewSample.nodes, edges: NetworkGraphPreviewSample.edges,
        title: ".layered", layout: .layered
    )
    .padding()
}

// MARK: - 渲染存活读数（基准专用观测点）

/// `NetworkGraph` **真的把边画出来了**的帧数。
@_spi(CoreDesignBenchmark)
public nonisolated enum NetworkGraphRenderProbe {
    private static let counter = Atomic<Int>(0)
    private static let lastDrawn = Atomic<Int>(0)

    /// 至今画出过边的帧数。基准取**窗口前后的差值**。
    public static var drawnFrames: Int { Self.counter.load(ordering: .relaxed) }

    /// 最近一次「画了边」的那一帧**落笔画了多少条**。
    public static var lastDrawnEdges: Int { Self.lastDrawn.load(ordering: .relaxed) }

    static func recordDrawnFrame(edges: Int) {
        Self.counter.wrappingAdd(1, ordering: .relaxed)
        Self.lastDrawn.store(edges, ordering: .relaxed)
    }
}

// MARK: - 布局形态（Issue #312 · 形态 D2）

/// `NetworkGraph` 的布局形态。
///
/// ⚠️ **本枚举是 `#312` 给 `NetworkGraph` 补的样式扩展点**（形态 D2 配置枚举）——
/// `#299` 步骤 2 枚举出的三个业界替代形态各对应一个 case，来源逐条记在各 case 的文档注释里。
///
/// ⚠️ **「配置枚举可演进」不是零代价**：本枚举**非 `@frozen`**，加 case 对下游任何
/// 穷举 `switch` 都是 source-breaking（下游要写 `@unknown default` 才免疫）。
/// 它仍比形态 B（public 协议）可撤，但加 case 要走一次 BREAKING-CHANGES 登记。
public nonisolated enum NetworkGraphLayout: Sendable, Equatable, CaseIterable {
    /// 默认：力导向解算（现状形态）—— 环形播种后跑排斥 / 吸引迭代。
    case force
    /// 环形：节点等角分布在一个圆上，**不跑迭代**。
    /// ⚠️ 这**不是新画法**：超 `recommendedNodeLimit` 时 `.force` 的降级形态本来就是它，
    /// 本 case 只是把它提成可选项。
    case circular
    /// 网格：按行列均匀铺开，忽略边的拉力。
    /// 业界来源：AntV G6 的 `grid` 布局。
    case grid
    /// 分层：按边的方向做拓扑分层，同层横向铺开、层间竖向排列。
    /// 业界来源：AntV G6 的 `dagre` 布局。
    ///
    /// ⚠️ **本组件的边模型是无向的**（`effectiveEdges` 会把互指的一对去重、只留**先列出**的那条），
    /// 而本形态**要读方向** ⇒ **层向由 `Edge.from → Edge.to` 定，互指对按先列出者算**。
    /// 换句话说：同一份数据里 a→b 与 b→a 谁写在前面，会改变分层方向。
    /// ⚠️ **同层的列序 = `nodes` 数组顺序**，不是 ID 排序 —— 换节点顺序列位置就变（与 `.circular` 一致）。
    /// ⚠️ 有环时**不会死循环**，但**不是**「剩余节点整体压到最后一层」——
    /// 那样会把环的**下游**一起卡住。剥不动时强制放一个再继续，见 `layeredRanks`。
    case layered
}

extension NetworkGraph {
    /// 按形态给出初始位置。⚠️ **纯函数，生产代码与判据共用同一份**（本仓既有约定）。
    nonisolated static func seed(
        layout: NetworkGraphLayout, nodes: [Node], edges: [Edge],
        center: CGPoint, radius: Double, width: Double, height: Double
    ) -> [Node.ID: CGPoint] {
        switch layout {
        case .force, .circular:
            var pos = [Node.ID: CGPoint]()
            for (i, node) in nodes.enumerated() {
                let angle = 2 * Double.pi * Double(i) / Double(nodes.count)
                pos[node.id] = CGPoint(
                    x: center.x + cos(angle) * radius,
                    y: center.y + sin(angle) * radius
                )
            }
            return pos
        case .grid:
            let columns = max(1, Int(ceil(sqrt(Double(nodes.count)))))
            let rows = max(1, Int(ceil(Double(nodes.count) / Double(columns))))
            var pos = [Node.ID: CGPoint]()
            for (i, node) in nodes.enumerated() {
                let col = i % columns
                let row = i / columns
                pos[node.id] = CGPoint(
                    x: Self.slot(index: col, count: columns, extent: width),
                    y: Self.slot(index: row, count: rows, extent: height)
                )
            }
            return pos
        case .layered:
            let ranks = Self.layeredRanks(nodes: nodes, edges: edges)
            let rowCount = max(1, (ranks.values.max() ?? 0) + 1)
            var byRow = [Int: [Node.ID]]()
            for node in nodes { byRow[ranks[node.id] ?? 0, default: []].append(node.id) }
            var pos = [Node.ID: CGPoint]()
            for (row, ids) in byRow {
                for (col, id) in ids.enumerated() {
                    pos[id] = CGPoint(
                        x: Self.slot(index: col, count: ids.count, extent: width),
                        y: Self.slot(index: row, count: rowCount, extent: height)
                    )
                }
            }
            return pos
        }
    }

    /// 把第 `index` 格（共 `count` 格）映射到 `extent` 上的中心点。
    /// ⚠️ `count == 1` 时给正中，不是贴边。
    nonisolated static func slot(index: Int, count: Int, extent: Double) -> Double {
        guard count > 1 else { return extent / 2 }
        let margin = extent * 0.1
        let usable = extent - margin * 2
        return margin + usable * Double(index) / Double(count - 1)
    }

    /// 拓扑分层：层号 = **已放前驱的最大层号 + 1**，没有已放前驱则为第 0 层。
    ///
    /// ⚠️ **别改成「循环跑到第几轮」当层号**：剥不动时每轮只强制放行一个节点，
    /// 互不相连的分量会被串成一列 —— 50 个互不相连的 3-环（150 点）排成 **150 层**而不是 3 层。
    /// ⚠️ **别改成「剥不动就把剩下的整体压到最后一层」**：那会让环的**下游**也跟着卡住。
    /// ⚠️ **强制放行只在「还有未放后继」的节点里挑**：放一个纯汇点释放不了任何人，
    /// 只会把指向它的边压成同层。
    /// ⚠️ **有环时消不掉全部向上边**：环至少留一条回边（形态本身的代价）；
    /// 另外「入度最小 + `nodes` 顺序」这个 tie-break 会先挑到环外的节点，还会多出向上边。
    nonisolated static func layeredRanks(nodes: [Node], edges: [Edge]) -> [Node.ID: Int] {
        let order = nodes.map(\.id)
        let ids = Set(order)
        var pending = [Node.ID: Int]()
        var outgoing = [Node.ID: [Node.ID]]()
        var predecessors = [Node.ID: [Node.ID]]()
        for id in ids { pending[id] = 0; outgoing[id] = []; predecessors[id] = [] }
        for edge in edges where ids.contains(edge.from) && ids.contains(edge.to) && edge.from != edge.to {
            pending[edge.to]? += 1
            outgoing[edge.from]?.append(edge.to)
            predecessors[edge.to]?.append(edge.from)
        }
        var rank = [Node.ID: Int]()
        var placed = Set<Node.ID>()
        while placed.count < order.count {
            var frontier = order.filter { !placed.contains($0) && (pending[$0] ?? 0) <= 0 }
            if frontier.isEmpty {
                let remaining = order.filter { !placed.contains($0) }
                let releasing = remaining.filter { id in
                    (outgoing[id] ?? []).contains { !placed.contains($0) }
                }
                // ⚠️ `releasing` 按论证恒非空（剩余子图每点入度 ≥1 ⇒ 必有一条内部边），
                // 这个兜底只防 pending 表缺项。
                let candidates = releasing.isEmpty ? remaining : releasing
                guard let fewest = candidates.map({ pending[$0] ?? 0 }).min(),
                      let forced = candidates.first(where: { (pending[$0] ?? 0) == fewest })
                else { break }
                frontier = [forced]
            }
            for id in frontier {
                let above = (predecessors[id] ?? []).compactMap { rank[$0] }.max()
                rank[id] = above.map { $0 + 1 } ?? 0
            }
            placed.formUnion(frontier)
            for id in frontier {
                for target in outgoing[id] ?? [] where !placed.contains(target) {
                    pending[target]? -= 1
                }
            }
        }
        return rank
    }
}
