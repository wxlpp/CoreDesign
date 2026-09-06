import CoreGraphics
import Testing
@testable import CoreDesignCharts

/// `NetworkGraph` 力导向布局的**几何分布**判据（#295）。
///
/// ⚠️ 本套判据存在的理由：#295 那个缺陷下，`layout` 的每一条既有判据都是绿的
/// ——坐标有限、在界内、节点数正确、同输入同输出——而画出来的是一圈**贴着边框的
/// 矩形轮廓**，不是力导向结果。「不崩、不越界、参数被传对」抓不到「画得对不对」。
/// ⇒ 这里断言的是布局输出的**分布性质**，不是它有没有被调用。
@Suite("力导向布局的几何分布（#295）")
struct ForceLayoutGeometryGuard {

    private struct Node: GraphNode {
        let id: String
        let label: String
    }

    /// 画廊那张图：`App/Sources/ComponentData.swift` 的 `NetworkGraphDemo`。
    /// ⚠️ 边表必须与画廊逐字一致——#295 就是在这张图上肉眼发现的。
    private static func galleryGraph() -> (nodes: [Node], edges: [GraphEdge<String>]) {
        let nodes = (0..<14).map { Node(id: "n\($0)", label: "节点 \($0)") }
        let edges = (0..<20).map { GraphEdge(from: "n\($0 % 14)", to: "n\(($0 * 5 + 3) % 14)") }
        return (nodes, edges)
    }

    /// 贴在容器边框上的节点数。钳位边界与 `layout` 内部同式。
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

    /// 同一条水平/垂直线上最多有几个节点（坐标取整到 1pt）。
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
        // 实测：有向心力 0/14，无向心力 14/14。阈值留在 3 而不是 0，
        // 是给参数微调留余量——但 14/14 那种整体贴边一定判红。
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
        // 实测：有向心力 1，无向心力 6（六个节点共享同一 y）。
        #expect(collinear <= 3, "有 \(collinear) 个节点落在同一条水平或垂直线上")
    }

    /// ⚠️ **对照组**：把向心力系数置 0 —— 上面两条必须双双转红。
    ///
    /// ⚠️ 它兜的**不是**「有人把前两条改成恒真」——那种改法没有任何判据拦得住
    /// （实测把两条 `#expect` 换成 `>= 0` 后本条照样绿）。它真正锚住的是
    /// **共享 fixture 与度量函数**：`pinnedCount` 复制了一份 `layout` 的钳位 inset，
    /// 若有人把 `layout` 里的 4 改掉，`pinnedCount` 会静默恒返 0 ⇒ 前两条失效但仍绿，
    /// 而本条的 `>= 10` 会判红。
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

    /// 向心力不得把节点压成一堆：最近邻间距要比无向心力时**更大**，不是更小。
    /// 非退化 fixture：13 个节点、**23** 条互异无向边（`i,i+1` 12 条 + `i,i+2` 11 条）、
    /// 零重复、零自环、**单连通分量**（一条 path 加一条 skip 链，不是两簇）。
    /// ⚠️ 画廊那张图的 20 条边去重后只剩 13 条互异边（7 条重复），整套判据此前**只有**
    /// 那一张退化图。回归判据该钉住肉眼发现缺陷的那张，但不能只有它。
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

    /// ⚠️ **本条是宽容器面的正向判据，不是棘轮**：宿主画廊在 macOS / iPad 上宽度
    /// 轻易到 700–1400，而系数一度按**最窄的**容器（345×260）取最小值 ⇒ 1200×260 仍
    /// 6/14 贴边、还被登记成「固有代价」。系数改 0.10 后该范围实测全部 0/14。
    /// 阈值留 2 是给参数微调的余量，不是承认还有一半没修。
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
        // 同时钉住「没有向心力时更差」，否则这条阈值可能只是恒真。
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
