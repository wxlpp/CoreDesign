import CoreGraphics
import Testing
@testable import CoreDesignCharts

@Suite("力导向布局的几何分布（#295）")
struct ForceLayoutGeometryGuard {
    private struct Node: GraphNode {
        let id: String
        let label: String
    }

    private static func galleryGraph() -> (nodes: [Node], edges: [GraphEdge<String>]) {
        let nodes = (0..<14).map { Node(id: "n\($0)", label: "节点 \($0)") }
        let edges = (0..<20).map { GraphEdge(from: "n\($0 % 14)", to: "n\(($0 * 5 + 3) % 14)") }
        return (nodes, edges)
    }

    private static func pinnedCount(
        _ positions: [String: CGPoint], in size: CGSize
    ) -> Int {
        let loX = min(4, size.width / 2), hiX = max(size.width - 4, loX)
        let loY = min(4, size.height / 2), hiY = max(size.height - 4, loY)
        return positions.values.count { p in
            abs(p.x - loX) < 0.5 || abs(p.x - hiX) < 0.5
                || abs(p.y - loY) < 0.5 || abs(p.y - hiY) < 0.5
        }
    }

    private static func maxCollinear(_ positions: [String: CGPoint]) -> Int {
        let rows = Dictionary(grouping: positions.values.map { Int($0.y.rounded()) }, by: { $0 })
        let cols = Dictionary(grouping: positions.values.map { Int($0.x.rounded()) }, by: { $0 })
        return max(rows.values.map(\.count).max() ?? 0, cols.values.map(\.count).max() ?? 0)
    }

    @Test("画廊那张图不得把节点钉在边框上")
    func galleryGraphIsNotPinnedToTheFrame() {
        let graph = Self.galleryGraph()
        let size = CGSize(width: 345, height: 260)
        let positions = NetworkGraph<Node>.layout(
            nodes: graph.nodes, edges: graph.edges, size: size,
            iterations: NetworkGraph<Node>.iterations(for: graph.nodes.count)
        )
        let pinned = Self.pinnedCount(positions, in: size)
        #expect(pinned <= 3, "14 个节点里有 \(pinned) 个贴在边框上")
    }

    @Test("画廊那张图不得呈共线排布")
    func galleryGraphIsNotCollinear() {
        let graph = Self.galleryGraph()
        let positions = NetworkGraph<Node>.layout(
            nodes: graph.nodes, edges: graph.edges,
            size: CGSize(width: 345, height: 260),
            iterations: NetworkGraph<Node>.iterations(for: graph.nodes.count)
        )
        let collinear = Self.maxCollinear(positions)
        #expect(collinear <= 3, "有 \(collinear) 个节点落在同一条水平或垂直线上")
    }

    @Test("对照：向心力归零时，贴边与共线双双复发")
    func removingTheCenteringForceReproducesTheDefect() {
        let graph = Self.galleryGraph()
        let size = CGSize(width: 345, height: 260)
        let positions = NetworkGraph<Node>.layout(
            nodes: graph.nodes, edges: graph.edges, size: size,
            iterations: NetworkGraph<Node>.iterations(for: graph.nodes.count),
            centeringStrength: 0
        )
        #expect(Self.pinnedCount(positions, in: size) >= 10)
        #expect(Self.maxCollinear(positions) >= 4)
    }

    private static func denseGraph() -> (nodes: [Node], edges: [GraphEdge<String>]) {
        let nodes = (0..<13).map { Node(id: "d\($0)", label: "d\($0)") }
        var edges: [GraphEdge<String>] = []
        for i in 0..<13 where i + 1 < 13 {
            edges.append(GraphEdge(from: "d\(i)", to: "d\(i + 1)"))
        }
        for i in 0..<12 where i + 2 < 13 {
            edges.append(GraphEdge(from: "d\(i)", to: "d\(i + 2)"))
        }
        return (nodes, edges)
    }

    @Test("非退化图同样不得整体贴边")
    func denseGraphIsNotPinnedToTheFrame() {
        let graph = Self.denseGraph()
        let size = CGSize(width: 345, height: 260)
        let positions = NetworkGraph<Node>.layout(
            nodes: graph.nodes, edges: graph.edges, size: size,
            iterations: NetworkGraph<Node>.iterations(for: graph.nodes.count)
        )
        #expect(Self.pinnedCount(positions, in: size) <= 4)
    }

    @Test("宽容器上同样不得把节点钉在边框上")
    func wideContainerIsNotPinnedToTheFrame() {
        let graph = Self.galleryGraph()
        let size = CGSize(width: 1200, height: 260)
        let positions = NetworkGraph<Node>.layout(
            nodes: graph.nodes, edges: graph.edges, size: size,
            iterations: NetworkGraph<Node>.iterations(for: graph.nodes.count)
        )
        let pinned = Self.pinnedCount(positions, in: size)
        #expect(pinned <= 2, "1200×260 上 \(pinned)/14 贴边")
        let without = NetworkGraph<Node>.layout(
            nodes: graph.nodes, edges: graph.edges, size: size,
            iterations: NetworkGraph<Node>.iterations(for: graph.nodes.count),
            centeringStrength: 0
        )
        #expect(Self.pinnedCount(without, in: size) > pinned)
    }

    @Test("向心力提高而非降低节点间距")
    func centeringForceIncreasesNearestNeighbourDistance() {
        let graph = Self.galleryGraph()
        let size = CGSize(width: 345, height: 260)
        let iterations = NetworkGraph<Node>.iterations(for: graph.nodes.count)
        func nearest(_ p: [String: CGPoint]) -> Double {
            let pts = Array(p.values)
            var best = Double.infinity
            for i in 0..<pts.count {
                for j in (i + 1)..<pts.count {
                    best = min(best, hypot(pts[i].x - pts[j].x, pts[i].y - pts[j].y))
                }
            }
            return best
        }
        let withForce = NetworkGraph<Node>.layout(
            nodes: graph.nodes, edges: graph.edges, size: size, iterations: iterations)
        let without = NetworkGraph<Node>.layout(
            nodes: graph.nodes, edges: graph.edges, size: size,
            iterations: iterations, centeringStrength: 0)
        #expect(nearest(withForce) > nearest(without))
    }
}
