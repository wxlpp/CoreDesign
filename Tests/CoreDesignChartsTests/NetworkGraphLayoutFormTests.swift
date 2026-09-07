import CoreGraphics
import Testing
@testable import CoreDesignCharts

// MARK: - 布局形态扩展点（Issue #312 · 形态 D2）

@Suite("NetworkGraph 的布局形态（#312）")
struct NetworkGraphLayoutFormTests {
    private struct Node: GraphNode {
        let id: String
        let label: String
    }

    private static let size = CGSize(width: 400, height: 300)

    /// 一条链 a→b→c→d，外加一个孤立点 e。
    private static func chain() -> (nodes: [Node], edges: [GraphEdge<String>]) {
        let ids = ["a", "b", "c", "d", "e"]
        return (
            ids.map { Node(id: $0, label: $0) },
            [GraphEdge(from: "a", to: "b"), GraphEdge(from: "b", to: "c"), GraphEdge(from: "c", to: "d")]
        )
    }

    private static func seed(_ layout: NetworkGraphLayout) -> [String: CGPoint] {
        let g = Self.chain()
        return NetworkGraph<Node>.seed(
            layout: layout, nodes: g.nodes, edges: g.edges,
            center: CGPoint(x: 200, y: 150), radius: 120,
            width: Self.size.width, height: Self.size.height
        )
    }

    @Test("四个形态各自给出不同的播种，且都覆盖全部节点")
    func everyLayoutSeedsAllNodesDistinctly() {
        for layout in NetworkGraphLayout.allCases {
            let pos = Self.seed(layout)
            #expect(pos.count == 5, "\(layout)：只播种了 \(pos.count) 个节点，期望 5")
        }
        // ⚠️ `.force` 与 `.circular` 的**播种**本就相同（前者随后跑迭代、后者不跑），
        // 所以只要求这两个形态与 `.circular` 不同，不要求四者两两互异。
        let circular = Self.seed(.circular)
        for other in [NetworkGraphLayout.grid, .layered] {
            #expect(Self.seed(other) != circular, "\(other) 的播种与 .circular 相同 —— 形态没生效")
        }
    }

    @Test("#312：只有 .force 会继续跑力导向迭代，其余三个形态的位置就是播种结果")
    func onlyForceRunsIterations() {
        let g = Self.chain()
        for layout in [NetworkGraphLayout.circular, .grid, .layered] {
            let seeded = NetworkGraph<Node>.seed(
                layout: layout, nodes: g.nodes, edges: g.edges,
                center: CGPoint(x: 200, y: 150), radius: 120, width: 400, height: 300
            )
            let solved = NetworkGraph<Node>.layout(
                nodes: g.nodes, edges: g.edges, size: Self.size, iterations: 90, layout: layout
            )
            #expect(solved == seeded, """
            \(layout) 经 `layout(…, iterations: 90)` 之后位置变了 —— 说明它**也跑了迭代**。
            ⚠️ 迭代会把这些形态揉回力导向的样子，那正是选它们的人不要的。
            守这一条的是 `layout()` 里那句 `guard layout == .force, iterations > 0, …`。
            """)
        }
        let forced = NetworkGraph<Node>.layout(
            nodes: g.nodes, edges: g.edges, size: Self.size, iterations: 90, layout: .force
        )
        let forceSeed = Self.seed(.force)
        #expect(forced != forceSeed, ".force 没跑迭代 —— 它应当在环形播种之后继续解算")
    }

    @Test("#312：网格形态按行列铺开，行数列数取 ceil(sqrt(n))")
    func gridSpreadsInRowsAndColumns() {
        let pos = Self.seed(.grid)
        // 5 个节点 ⇒ 3 列 × 2 行
        let xs = Set(pos.values.map { ($0.x * 100).rounded() })
        let ys = Set(pos.values.map { ($0.y * 100).rounded() })
        #expect(xs.count == 3, "网格的不同 x 坐标有 \(xs.count) 个，期望 3（ceil(sqrt(5)) = 3 列）")
        #expect(ys.count == 2, "网格的不同 y 坐标有 \(ys.count) 个，期望 2（5 个节点分 2 行）")
    }

    @Test("#312：分层形态按边的方向分层——链 a→b→c→d 应得四层，孤立点在第 0 层")
    func layeredRanksFollowEdgeDirection() {
        let g = Self.chain()
        let ranks = NetworkGraph<Node>.layeredRanks(nodes: g.nodes, edges: g.edges)
        #expect(ranks["a"] == 0, "a 无入边，应在第 0 层，实为 \(ranks["a"].map(String.init) ?? "nil")")
        #expect(ranks["b"] == 1)
        #expect(ranks["c"] == 2)
        #expect(ranks["d"] == 3, "链尾应在第 3 层，实为 \(ranks["d"].map(String.init) ?? "nil")")
        #expect(ranks["e"] == 0, "孤立点无入边，应与源点同层")
    }

    @Test("#312：有环时环的**下游**必须分开——不是整片塌成一层")
    func layeredSeparatesCycleDownstream() {
        // a→b→c→a 是环，d 由 a 指出、**不在环里**
        let nodes = ["a", "b", "c", "d"].map { Node(id: $0, label: $0) }
        let edges = [
            GraphEdge(from: "a", to: "b"), GraphEdge(from: "b", to: "c"),
            GraphEdge(from: "c", to: "a"), GraphEdge(from: "a", to: "d"),
        ]
        let ranks = NetworkGraph<Node>.layeredRanks(nodes: nodes, edges: edges)
        #expect(ranks.count == 4, "有环时漏掉了节点（实得 \(ranks.count)，期望 4）")
        #expect(Set(ranks.values).count > 1, """
        所有节点都在同一层（实得 \(ranks.sorted { "\($0.key)" < "\($1.key)" })）——
        ⚠️ **`.layered` 退化成了一条水平线**。第一版就是这样：剥不动时把「剩下的整体压到最后一层」，
        于是**环的下游**也跟着卡住（它们的入度永远减不到 0）。⇒ 必须强制放一个再继续剥。
        """)
        let cycleMax = ["a", "b", "c"].compactMap { ranks[$0] }.max() ?? 0
        #expect((ranks["d"] ?? 0) > 0 || cycleMax > 0, "d 与整个环同层 —— 下游没有被分出来")
    }

    @Test("#312：根上就有环时也不能整张图 rank 全 0")
    func layeredHandlesRootCycle() {
        // a↔b 互指（没有任何入度为 0 的节点）+ 链 b→c→d
        let nodes = ["a", "b", "c", "d"].map { Node(id: $0, label: $0) }
        let edges = [
            GraphEdge(from: "a", to: "b"), GraphEdge(from: "b", to: "a"),
            GraphEdge(from: "b", to: "c"), GraphEdge(from: "c", to: "d"),
        ]
        let ranks = NetworkGraph<Node>.layeredRanks(nodes: nodes, edges: edges)
        #expect(ranks.count == 4)
        #expect(Set(ranks.values).count > 1, """
        根上有环时整张图 rank 全为 0（实得 \(ranks.sorted { "\($0.key)" < "\($1.key)" })）——
        ⚠️ 一个入度 0 的节点都没有时，第一版的 `while` **一次都不进**，`level` 停在 0。
        复算（组件自带那份 14 节点样例数据，逐字复刻的第一版算法、非产物）：
        直接喂未去重的 20 条边得 rank 全 0；走 view 的 `layoutKey(for:)`（去重后 13 条边）
        得 3 层、其中一层坐着 14 个点里的 12 个。现算法在两条路上都给 6 层。
        """)
        #expect((ranks["d"] ?? 0) > (ranks["a"] ?? 0), "链尾 d 应当排在 a 之后")
    }

    @Test("#312：四个形态的坐标一律落在画布内，且分层的位置逐点钉死")
    func seedsStayInsideCanvasAndLayeredIsPinned() {
        for layout in NetworkGraphLayout.allCases {
            for (id, p) in Self.seed(layout) {
                #expect(p.x.isFinite && p.y.isFinite, "\(layout) 的 \(id) 坐标非有限：\(p)")
                #expect(p.x >= 0 && p.x <= Self.size.width, """
                \(layout) 的 \(id) x = \(p.x) 落在画布外（宽 \(Self.size.width)）。
                ⚠️ 终审变异实证：`rowCount` 少一个 `+1` 就会产生 y = 390 > 300 的越界坐标，
                而第一版**没有任何判据看得见**。
                """)
                #expect(p.y >= 0 && p.y <= Self.size.height,
                        "\(layout) 的 \(id) y = \(p.y) 落在画布外（高 \(Self.size.height)）")
            }
        }
        // ⚠️ 逐点钉死：只比「与 circular 不同」挡不住「分层画成了网格 / x-y 互换」
        // ——终审三条变异（合并进 grid 分支、少 `+1`、x/y 互换）**全部存活**。
        let pos = Self.seed(.layered)
        let expected: [String: CGPoint] = [
            "a": CGPoint(x: 40, y: 30), "e": CGPoint(x: 360, y: 30),
            "b": CGPoint(x: 200, y: 110), "c": CGPoint(x: 200, y: 190),
            "d": CGPoint(x: 200, y: 270),
        ]
        for (id, want) in expected.sorted(by: { $0.key < $1.key }) {
            #expect(pos[id] == want, "分层布局的 \(id) 实为 \(pos[id].map(String.init(describing:)) ?? "nil")，期望 \(want)")
        }
    }

    // MARK: - 层号不是「跑到第几轮」（第 3 轮 C-1）

    /// ⚠️ 这两条抓的是**第 2 版**的病：层号用全局迭代计数 ⇒ 剥不动时每轮只放一个，
    /// **互不相连的分量被串成一列**。既有的 `layeredSeparatesCycleDownstream` /
    /// `layeredHandlesRootCycle` 对它**全绿** —— 它们的输入是单个连通分量，
    /// 「串行化」在单分量上恰好与正确答案重合。
    @Test("#312：互不相连的两个 3-环必须并排在同三层，不能被串成六层")
    func disjointCyclesShareLayers() {
        // ⚠️ 必须用 **3-环**：互指的一对（2-环）会被 `UndirectedKey` 去重成单向一条边，
        // 到 `layeredRanks` 手里根本不是环 —— 第一版判据用的就是 2-环，
        // 结果**变异下照样绿**（去重后两条独立的边，两种算法都给 2 层）。
        let ids = ["a", "b", "c", "d", "e", "f"]
        let nodes = ids.map { Node(id: $0, label: $0) }
        let edges = [
            GraphEdge(from: "a", to: "b"), GraphEdge(from: "b", to: "c"), GraphEdge(from: "c", to: "a"),
            GraphEdge(from: "d", to: "e"), GraphEdge(from: "e", to: "f"), GraphEdge(from: "f", to: "d"),
        ]
        let key = NetworkGraph(nodes: nodes, edges: edges).layoutKey(for: Self.size)
        #expect(key.edges.count == 6, "去重把环拆了，下面的断言就不再是在测环：\(key.edges.count) 条")

        let ranks = NetworkGraph<Node>.layeredRanks(nodes: nodes, edges: key.edges)
        #expect(Set(ranks.values).count == 3,
                """
                两个**互不相连**的 3-环排出了 \(Set(ranks.values).count) 层（应为 3）：\(ranks)。
                层号必须是「已放前驱的最大层号 + 1」，不能是「循环跑到第几轮」——
                后者会把每个分量各自往下串，150 个点的极端下排成 150 层、行距约 1.6px。
                """)
        #expect(ranks["a"] == ranks["d"] && ranks["b"] == ranks["e"] && ranks["c"] == ranks["f"],
                "两个同构分量没落在同三层：\(ranks)")
    }

    @Test("#312：孤立点旁边的环，环的起点仍在第 0 层")
    func cycleBesideIsolatedNodeStartsAtZero() {
        let nodes = ["a", "b", "c", "e"].map { Node(id: $0, label: $0) }
        let edges = [GraphEdge(from: "a", to: "b"), GraphEdge(from: "b", to: "c"), GraphEdge(from: "c", to: "a")]
        let key = NetworkGraph(nodes: nodes, edges: edges).layoutKey(for: Self.size)
        let ranks = NetworkGraph<Node>.layeredRanks(nodes: nodes, edges: key.edges)

        #expect(ranks["e"] == 0, "孤立点没在第 0 层：\(ranks)")
        #expect(ranks["a"] == 0,
                """
                环的起点被推到第 \(ranks["a"] ?? -1) 层（应为 0）：\(ranks)。
                第 2 版里孤立点先占掉第 0 轮，环因为全局计数从第 1 层起排。
                """)
        #expect(Set(ranks.values).count == 3, "层数应为 3（e/a 同层，b、c 各一层）：\(ranks)")
    }

    // MARK: - 层号规则的两个分支（第 4 轮 I-2）

    /// ⚠️ 上面那些输入里**没有一个节点有两个不同层的前驱**，也**没有一个被强制放行的节点
    /// 带着已放前驱** —— 于是 `max` 换成 `min`、以及「强制放行的节点恒取 0」两个变异
    /// 在它们身上**逐位相同**（第 4 轮终审实测）。这两条专打那两个分支。
    @Test("#312：一个节点有两个不同层的前驱时，取**最大**前驱层号 + 1")
    func rankTakesDeepestPredecessor() {
        let nodes = ["a", "b", "c"].map { Node(id: $0, label: $0) }
        // a→b、a→c、b→c：c 有两个前驱（a 在第 0 层、b 在第 1 层）
        let edges = [GraphEdge(from: "a", to: "b"), GraphEdge(from: "a", to: "c"), GraphEdge(from: "b", to: "c")]
        let key = NetworkGraph(nodes: nodes, edges: edges).layoutKey(for: Self.size)
        let ranks = NetworkGraph<Node>.layeredRanks(nodes: nodes, edges: key.edges)

        #expect(ranks["c"] == 2,
                """
                c 落在第 \(ranks["c"] ?? -1) 层（应为 2）：\(ranks)。
                层号必须取**最大**前驱层号 + 1；取 min 会让 b→c 画成同一行里的一条水平边。
                """)
        #expect(ranks["a"] == 0 && ranks["b"] == 1, "菱形的前两层不对：\(ranks)")
    }

    @Test("#312：被强制放行的节点也要认已放前驱，不能恒取第 0 层")
    func forcedNodeStillHonoursPlacedPredecessors() {
        let nodes = ["x", "a", "b", "c"].map { Node(id: $0, label: $0) }
        // x→a，外加环 a→b→c→a：x 先入第 0 层，a 是被**强制放行**的那个，但它有已放前驱 x
        let edges = [
            GraphEdge(from: "x", to: "a"),
            GraphEdge(from: "a", to: "b"), GraphEdge(from: "b", to: "c"), GraphEdge(from: "c", to: "a"),
        ]
        let key = NetworkGraph(nodes: nodes, edges: edges).layoutKey(for: Self.size)
        let ranks = NetworkGraph<Node>.layeredRanks(nodes: nodes, edges: key.edges)

        #expect(ranks["x"] == 0 && ranks["a"] == 1 && ranks["b"] == 2 && ranks["c"] == 3,
                """
                期望 x=0 a=1 b=2 c=3，实得 \(ranks)。
                强制放行的节点若恒取 0，a 会与 x 同层 ⇒ x→a 变成一条水平边。
                """)
    }

    @Test("#312：强制放行只在「还有未放后继」的节点里挑，不放纯汇点")
    func forcedPickReleasesSomeone() {
        // nodes 顺序 f,p,u,v,w；环 u→v→w→u，外加 w→p→f 两个汇向的点。
        // 不限候选时会先强制 f（纯汇点，释放不了任何人）⇒ p→f 被压成同层。
        let nodes = ["f", "p", "u", "v", "w"].map { Node(id: $0, label: $0) }
        let edges = [
            GraphEdge(from: "u", to: "v"), GraphEdge(from: "v", to: "w"), GraphEdge(from: "w", to: "u"),
            GraphEdge(from: "w", to: "p"), GraphEdge(from: "p", to: "f"),
        ]
        let key = NetworkGraph(nodes: nodes, edges: edges).layoutKey(for: Self.size)
        let ranks = NetworkGraph<Node>.layeredRanks(nodes: nodes, edges: key.edges)

        #expect(ranks["p"] != ranks["f"],
                """
                p 与 f 落在同一层（\(ranks["p"] ?? -1)）：\(ranks) —— p→f 会画成一条水平边。
                成因：强制放行挑了 f，而 f 没有未放后继、释放不了任何人。
                """)
        #expect((ranks["p"] ?? 0) < (ranks["f"] ?? 0), "p→f 方向反了：\(ranks)")
    }

    // MARK: - 组件自带样例数据的分层直方图（第 4 轮 S-2）

    /// ⚠️ 这份 14 节点数据是 `#Preview` 用的、**两次退化都发生在它身上**的唯一输入，
    /// 却一直没有任何判据钉着它。两条路各钉一次。
    @Test("#312：#Preview 那份 14 节点样例的分层直方图（去重前后都是 6 层）")
    func previewSampleLayering() {
        // ⚠️ 直接引用 `NetworkGraphPreviewSample`（生产代码里 `#Preview` 用的**同一份**），
        // 不在这里重抄一遍公式 —— 抄一份的话两边漂开时本判据照绿、而它的全部意义
        // 就是钉住「`#Preview` 画出来的那张图」。
        let nodes = NetworkGraphPreviewSample.nodes
        let raw = NetworkGraphPreviewSample.edges
        let key = NetworkGraph(nodes: nodes, edges: raw).layoutKey(for: Self.size)

        #expect(nodes.count == 14 && raw.count == 20 && key.edges.count == 13,
                """
                样例数据变了（节点 \(nodes.count) / 原始边 \(raw.count) / 去重后 \(key.edges.count)，
                期望 14 / 20 / 13），下面的直方图不再可比
                """)

        func histogram(_ edges: [GraphEdge<String>]) -> [Int] {
            let ranks = NetworkGraph<NetworkGraphPreviewNode>.layeredRanks(nodes: nodes, edges: edges)
            var counts = [Int: Int]()
            for value in ranks.values { counts[value, default: 0] += 1 }
            return counts.keys.sorted().map { counts[$0] ?? 0 }
        }
        let expected = [3, 3, 2, 2, 2, 2]
        let message = """
            ⚠️ 本条只钉这份数据的**形状**，它对「层号规则本身写错」并不敏感 ——
            规则 1 / 3 的三个变异在这份数据上直方图**逐位不变**（第 4 轮终审复算），
            那三条各有专门的判据。本条抓的是历史上真出过的两次退化：
            第 1 版 [14]（全 rank 0）、第 2 版 [1,1,1,…]（14 层各 1 个）。
            ⚠️ 期望值依赖 `layeredRanks` 的 tie-break（入度最小 + `nodes` 顺序）——
            **合法地改 tie-break 要重算期望，别直接把它改绿**。
            """
        #expect(histogram(raw) == expected, "原始边的直方图是 \(histogram(raw))，期望 \(expected)。\n\(message)")
        #expect(histogram(key.edges) == expected,
                "去重后（view 走的那条路）直方图是 \(histogram(key.edges))，期望 \(expected)。\n\(message)")
    }

    // MARK: - view 实际走的那条路（去重后的边）

    /// ⚠️ 上面的判据全都**直接**调 `seed` / `layout`，看到的是**未去重**的边；
    /// 而 view 走 `layoutKey(for:)`，看到的是 `effectiveEdges` **去重后**的边。
    /// 两者对 `.layered` 不等价 —— 互指的一对被去重后只剩一条，**层向由先列出者定**。
    /// 这两条判据走的是 view 那条路。
    @Test("#312：互指的一对边去重后只剩先列出的那条，.layered 的层向随之而定")
    func layeredDirectionFollowsFirstListedOfAMutualPair() {
        let nodes = ["a", "b"].map { Node(id: $0, label: $0) }

        func ranksThroughViewPath(_ edges: [GraphEdge<String>]) -> (kept: [GraphEdge<String>], a: Int, b: Int) {
            let key = NetworkGraph(nodes: nodes, edges: edges).layoutKey(for: Self.size)
            let ranks = NetworkGraph<Node>.layeredRanks(nodes: nodes, edges: key.edges)
            return (key.edges, ranks["a"] ?? -1, ranks["b"] ?? -1)
        }

        let ab = ranksThroughViewPath([GraphEdge(from: "a", to: "b"), GraphEdge(from: "b", to: "a")])
        let ba = ranksThroughViewPath([GraphEdge(from: "b", to: "a"), GraphEdge(from: "a", to: "b")])

        #expect(ab.kept.count == 1 && ba.kept.count == 1,
                """
                互指的一对没被 UndirectedKey 去重：\(ab.kept.count) / \(ba.kept.count) —— \
                去重若失效，下面那条『层向翻转』的断言就不再是在测本条要测的东西
                """)
        #expect(ab.kept.first?.from == "a" && ba.kept.first?.from == "b",
                "保留的不是**先列出**的那条：\(String(describing: ab.kept.first)) / \(String(describing: ba.kept.first))")
        #expect(ab.a < ab.b && ba.b < ba.a,
                """
                .layered 的层向没有跟着「先列出者」翻转：先列 a→b 得 a=\(ab.a) b=\(ab.b)，\
                先列 b→a 得 a=\(ba.a) b=\(ba.b)。这是**有意的**契约（边模型无向、分层要方向），\
                写在 NetworkGraphLayout.layered 的文档注释与 docs/components/network-graph.md 里；\
                改了实现就要同步改那两处文档，不要只把这条判据改绿。
                """)
    }

    @Test("#312：layoutKey 换形态就换 key —— 少了这个字段 .task(id:) 不会重算")
    func layoutKeyDistinguishesForms() {
        let g = Self.chain()
        let keys = NetworkGraphLayout.allCases.map {
            NetworkGraph(nodes: g.nodes, edges: g.edges, layout: $0).layoutKey(for: Self.size)
        }
        for (i, lhs) in keys.enumerated() {
            for rhs in keys[(i + 1)...] {
                #expect(lhs != rhs, "两个不同形态给出了相等的 LayoutKey：\(lhs.layout) / \(rhs.layout)")
            }
        }
    }

    @Test("#312：slot 在只有一格时给正中，不贴边")
    func singleSlotIsCentered() {
        #expect(NetworkGraph<Node>.slot(index: 0, count: 1, extent: 400) == 200)
        // 多格时首尾留 10% 边距
        #expect(NetworkGraph<Node>.slot(index: 0, count: 2, extent: 400) == 40)
        #expect(NetworkGraph<Node>.slot(index: 1, count: 2, extent: 400) == 360)
    }
}
