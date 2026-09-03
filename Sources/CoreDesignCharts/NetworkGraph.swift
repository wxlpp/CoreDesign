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
public struct NetworkGraph: View {

    /// 一个节点。⚠️ `nonisolated` 的理由见 `ChartValue` 的文档。
    public nonisolated struct Node: Identifiable, Sendable, Hashable {
        public let id: String
        public let label: String
        public init(id: String, label: String) {
            self.id = id
            self.label = label
        }
    }

    /// 一条边。
    public nonisolated struct Edge: Sendable, Hashable {
        public let from: String
        public let to: String
        public init(from: String, to: String) {
            self.from = from
            self.to = to
        }
    }

    /// 建议的节点上限。
    ///
    /// ⚠️ **力导向布局是每帧 O(n²)**。超过此数走"截断 + 静态环形布局"
    /// ——**不抛断言**：库代码对数据规模 `precondition` 就是让宿主 App crash（FR-20）。
    public static let recommendedNodeLimit = 150

    private let nodes: [Node]
    private let edges: [Edge]
    private let tint: Color
    private let title: LocalizedStringKey

    public init(
        nodes: [Node],
        edges: [Edge],
        title: LocalizedStringKey = "关系图",
        tint: Color = .accent
    ) {
        self.nodes = nodes
        self.edges = edges
        self.title = title
        self.tint = tint
    }

    public var body: some View {
        if self.nodes.isEmpty {
            ChartEmptyState(message: "暂无数据")
        } else {
            self.canvas
        }
    }

    // MARK: - Private

    /// 超限时截断。⚠️ 截断而不是拒绝——半张图仍有信息量，crash 没有。
    private var effectiveNodes: [Node] {
        Array(self.nodes.prefix(Self.recommendedNodeLimit))
    }

    private var isTruncated: Bool {
        self.nodes.count > Self.recommendedNodeLimit
    }

    private var canvas: some View {
        GeometryReader { proxy in
            let layout = Self.layout(
                nodes: self.effectiveNodes,
                edges: self.edges,
                size: proxy.size,
                // ⚠️ 超限时**跳过迭代**，直接用环形初始布局——这就是"降级为静态布局"。
                iterations: self.isTruncated ? 0 : 90
            )

            ZStack {
                // 边
                Path { path in
                    for edge in self.edges {
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
        }
        .accessibilityElement()
        .accessibilityLabel(self.title)
        .accessibilityChartDescriptor(self)
    }

    /// 力导向布局：环形初始位置 + N 轮「斥力 + 弹簧」迭代。
    ///
    /// ⚠️ **初始位置必须是环形而不是随机/同点**：所有节点重合时斥力方向未定义，
    /// 归一化零向量会产生 **NaN**，整张图消失（FR-19 点名的退化形态）。
    /// 环形初始保证任意两点初始就不重合。
    static func layout(
        nodes: [Node], edges: [Edge], size: CGSize, iterations: Int
    ) -> [String: CGPoint] {
        guard !nodes.isEmpty else { return [:] }
        let w = max(size.width, 1)
        let h = max(size.height, 1)
        let center = CGPoint(x: w / 2, y: h / 2)
        let radius = min(w, h) / 2 * 0.8

        var pos = [String: CGPoint]()
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
            var disp = [String: CGVector](minimumCapacity: ids.count)
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
            for id in ids {
                guard let d = disp[id], let p = pos[id] else { continue }
                let len = max(sqrt(d.dx * d.dx + d.dy * d.dy), 0.01)
                let limited = min(len, temperature)
                pos[id] = CGPoint(
                    x: min(max(p.x + d.dx / len * limited, 4), w - 4),
                    y: min(max(p.y + d.dy / len * limited, 4), h - 4)
                )
            }
        }
        return pos
    }
}

private extension CGVector {
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
        var degree = [String: Int]()
        for e in self.edges {
            degree[e.from, default: 0] += 1
            degree[e.to, default: 0] += 1
        }
        let peak = degree.values.max() ?? 1
        let category = AXCategoricalDataAxisDescriptor(
            title: "节点", categoryOrder: self.effectiveNodes.map(\.label)
        )
        let axis = AXNumericDataAxisDescriptor(
            title: "连接数", range: 0...Double(max(peak, 1)), gridlinePositions: []
        ) { "\(Int($0))" }
        let series = AXDataSeriesDescriptor(
            name: "", isContinuous: false,
            dataPoints: self.effectiveNodes.map {
                AXDataPoint(x: $0.label, y: Double(degree[$0.id] ?? 0))
            }
        )
        return AXChartDescriptor(
            title: nil, summary: nil,
            xAxis: category, yAxis: axis, additionalAxes: [], series: [series]
        )
    }
}

#Preview("NetworkGraph") {
    let nodes = (0..<14).map { NetworkGraph.Node(id: "n\($0)", label: "节点 \($0)") }
    let edges = (0..<20).map {
        NetworkGraph.Edge(from: "n\($0 % 14)", to: "n\(($0 * 5 + 3) % 14)")
    }
    return NetworkGraph(nodes: nodes, edges: edges)
        .frame(height: 300)
        .padding()
}
