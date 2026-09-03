import Foundation
import Testing

@testable import CoreDesignCharts

/// ⚠️ Preview / 测试专用。**必须 `nonisolated`**——本 target 设了
/// `defaultIsolation(MainActor)`，不标就拿不到满足 `Sendable` 的 `Identifiable`
/// conformance。见 `ChartValue` 的文档。
private nonisolated struct Point: ChartValue {
    let id = UUID()
    let label: String
    let value: Double
}

// ⚠️ **退化输入是一等契约，不是边角**（FR-19）：力导向布局节点重合会 NaN、
// 雷达图轴值全等会除零——这是图表类组件最常见的 crash 源。
//
// ⚠️ 本 suite 断言的是「**不 crash、不产生 NaN**」与「走到正确的降级分支」，
// **不是**具体像素。像素级验证靠 `#Preview`（本仓组件的主要视觉冒烟方式）。

@Suite("ChartDegeneracy 判定")
struct ChartDegeneracyTests {

    @Test("空数组 → .empty")
    func empty() {
        #expect(ChartDegeneracy.of([]) == .empty)
    }

    @Test("单点 + 需要 3 个 → .singlePoint")
    func singlePoint() {
        #expect(ChartDegeneracy.of([1], minimumCount: 3) == .singlePoint)
        #expect(ChartDegeneracy.of([1, 2], minimumCount: 3) == .singlePoint)
    }

    @Test("总和为 0 → .zeroTotal")
    func zeroTotal() {
        #expect(ChartDegeneracy.of([0, 0, 0]) == .zeroTotal)
    }

    @Test("全等非零 → .flat")
    func flat() {
        #expect(ChartDegeneracy.of([5, 5, 5]) == .flat)
    }

    /// ⚠️ `[0]` 同时是"单点"与"零总和"——判定顺序是**有意的**：报单点更有信息量
    /// （调用方更可能是漏了数据，而不是真的全零）。
    @Test("[0] 报单点而非零总和 —— 判定顺序有意为之")
    func orderingIsIntentional() {
        #expect(ChartDegeneracy.of([0], minimumCount: 3) == .singlePoint)
    }

    @Test("正常数据 → .usable")
    func usable() {
        #expect(ChartDegeneracy.of([1, 2, 3]) == .usable)
    }
}

@Suite("安全归一化 —— 不产生 NaN")
struct NormalizationTests {

    @Test("全等值返回 0.5 而不是 NaN —— 所有维度同分是常见输入，不是错误")
    func flatIsNotNaN() {
        let out = [7.0, 7.0, 7.0].normalizedSafely()
        #expect(out == [0.5, 0.5, 0.5])
        #expect(out.allSatisfy { !$0.isNaN })
    }

    @Test("空数组返回空，不崩")
    func emptyIsEmpty() {
        #expect([Double]().normalizedSafely().isEmpty)
    }

    @Test("正常区间映射到 [0, 1] 端点")
    func spansFullRange() {
        let out = [10.0, 20.0, 30.0].normalizedSafely()
        #expect(out.first == 0)
        #expect(out.last == 1)
        #expect(out.allSatisfy { (0...1).contains($0) })
    }

    @Test("含负值也不越界")
    func handlesNegatives() {
        let out = [-5.0, 0.0, 5.0].normalizedSafely()
        #expect(out.allSatisfy { (0...1).contains($0) && !$0.isNaN })
    }
}

@Suite("NetworkGraph 力导向布局 —— 退化输入")
struct NetworkGraphLayoutTests {

    private func nodes(_ n: Int) -> [NetworkGraph.Node] {
        (0..<n).map { .init(id: "n\($0)", label: "L\($0)") }
    }

    @Test("空节点 → 空布局，不崩")
    func emptyNodes() {
        let layout = NetworkGraph.layout(
            nodes: [], edges: [], size: .init(width: 100, height: 100), iterations: 30
        )
        #expect(layout.isEmpty)
    }

    @Test("单节点 → 有位置且不是 NaN")
    func singleNode() {
        let layout = NetworkGraph.layout(
            nodes: self.nodes(1), edges: [], size: .init(width: 100, height: 100), iterations: 30
        )
        #expect(layout.count == 1)
        let p = layout["n0"]
        #expect(p != nil)
        #expect(!(p?.x.isNaN ?? true) && !(p?.y.isNaN ?? true))
    }

    /// ⚠️ **这是本 suite 最重要的一条**：所有节点重合时斥力方向未定义，
    /// 归一化零向量会产生 NaN，整张图消失。环形初始位置就是为了防它。
    @Test("零边 + 多节点 —— 所有坐标有限，无 NaN / 无穷")
    func zeroEdgesNoNaN() {
        let layout = NetworkGraph.layout(
            nodes: self.nodes(12), edges: [], size: .init(width: 300, height: 300), iterations: 60
        )
        #expect(layout.count == 12)
        #expect(layout.values.allSatisfy { $0.x.isFinite && $0.y.isFinite })
    }

    @Test("自环边不产生 NaN")
    func selfLoop() {
        let layout = NetworkGraph.layout(
            nodes: self.nodes(3),
            edges: [.init(from: "n0", to: "n0")],
            size: .init(width: 200, height: 200), iterations: 40
        )
        #expect(layout.values.allSatisfy { $0.x.isFinite && $0.y.isFinite })
    }

    @Test("指向不存在节点的边被忽略，不崩")
    func danglingEdge() {
        let layout = NetworkGraph.layout(
            nodes: self.nodes(3),
            edges: [.init(from: "n0", to: "missing")],
            size: .init(width: 200, height: 200), iterations: 20
        )
        #expect(layout.count == 3)
        #expect(layout.values.allSatisfy { $0.x.isFinite && $0.y.isFinite })
    }

    @Test("零尺寸容器不产生除零")
    func zeroSize() {
        let layout = NetworkGraph.layout(
            nodes: self.nodes(4), edges: [], size: .zero, iterations: 20
        )
        #expect(layout.values.allSatisfy { $0.x.isFinite && $0.y.isFinite })
    }

    @Test("坐标始终留在容器内 —— 节点不会飘出可视区")
    func staysInBounds() {
        let size = CGSize(width: 200, height: 140)
        let layout = NetworkGraph.layout(
            nodes: self.nodes(20),
            edges: (0..<25).map { .init(from: "n\($0 % 20)", to: "n\(($0 * 7 + 1) % 20)") },
            size: size, iterations: 80
        )
        #expect(layout.values.allSatisfy {
            (0...size.width).contains($0.x) && (0...size.height).contains($0.y)
        })
    }

    /// ⚠️ 超限走**截断 + 静态布局**，**不抛断言**（FR-20）——
    /// 库代码对数据规模 `precondition` 就是让宿主 App crash。
    @Test("iterations = 0（超限降级路径）仍产出有限坐标")
    func staticFallback() {
        let layout = NetworkGraph.layout(
            nodes: self.nodes(200), edges: [], size: .init(width: 300, height: 300), iterations: 0
        )
        #expect(layout.count == 200)
        #expect(layout.values.allSatisfy { $0.x.isFinite && $0.y.isFinite })
    }

    @Test("布局是确定性的 —— 同输入两次结果相同")
    func deterministic() {
        let n = self.nodes(8)
        let e = (0..<10).map { NetworkGraph.Edge(from: "n\($0 % 8)", to: "n\(($0 * 3) % 8)") }
        let size = CGSize(width: 250, height: 250)
        let a = NetworkGraph.layout(nodes: n, edges: e, size: size, iterations: 40)
        let b = NetworkGraph.layout(nodes: n, edges: e, size: size, iterations: 40)
        #expect(a.keys.sorted() == b.keys.sorted())
        #expect(a.keys.allSatisfy { a[$0] == b[$0] })
    }

    @Test("节点上限是正数 —— 0 会让所有图都走降级路径")
    func limitIsPositive() {
        #expect(NetworkGraph.recommendedNodeLimit > 0)
    }
}
