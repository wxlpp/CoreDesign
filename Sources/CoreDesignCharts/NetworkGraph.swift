import Accessibility
import CoreDesign
import SwiftUI
import Synchronization

/// 力导向网络图。
public struct NetworkGraph<Node: GraphNode>: View {
    /// 本图表的边类型 —— 以调用方节点的 `ID` 相连。
    public typealias Edge = GraphEdge<Node.ID>

    /// 建议的节点上限。
    public nonisolated static var recommendedNodeLimit: Int { 150 }

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
    }

    func layoutKey(for size: CGSize) -> LayoutKey {
        let shownNodes = self.effectiveNodes
        let visible = Set(shownNodes.map(\.id))
        return LayoutKey(
            ids: shownNodes.map(\.id),
            edges: self.effectiveEdges(visibleIn: visible),
            size: size,
            iterations: self.isTruncated(visibleIn: visible) ? 0 : Self.iterations(for: shownNodes.count)
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

    nonisolated static func layout(
        nodes: [Node], edges: [Edge], size: CGSize, iterations: Int,
        centeringStrength: Double = Self.centeringStrength
    ) -> [Node.ID: CGPoint] {
        guard !nodes.isEmpty else { return [:] }
        let w = size.width.isFinite ? max(size.width, 1) : 1
        let h = size.height.isFinite ? max(size.height, 1) : 1
        let center = CGPoint(x: w / 2, y: h / 2)
        let radius = min(w, h) / 2 * 0.8

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
