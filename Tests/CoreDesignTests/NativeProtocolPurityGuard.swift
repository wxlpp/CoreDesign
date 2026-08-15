import Foundation
import Testing

// MARK: - J-3

@Suite("J-3 原生协议纯度")
struct NativeProtocolPurityGuard {

    /// **绿色正对照**的两个组件：它们的作用域里**必须**存在自有样式协议。
    ///
    /// ⚠️ **它挡的是「探针退化成恒空」，不是「主判据逻辑写坏」**：J-3 的真实输入只有
    /// `ProgressIndicator` 一条，主判据「作用域里没有自有协议 ⇒ 绿」在探针恒返回空集时
    /// **同样是绿**。把探针反向施加到这两个必然命中的组件上，探针一死，这里立刻红。
    /// ⚠️ **这条红能推到主判据身上，前提是 `judgeNativeProtocolPurity` 消费本探针**
    /// （Task 7 的结构约束，由规则层的 `j3JudgeConsumesTheProbe` 钉住）。判据若自带一份
    /// 内联副本，正对照红只证明副本之外那份死了——主判据可能照常工作，也可能早就写坏而无人
    /// 知晓。⇒ 改动 `customStyleProtocolsInScope` 或 `judgeNativeProtocolPurity` 的调用
    /// 关系前，先读 Task 8 的防线表。
    /// ⚠️ **两个正对照走的都是通道 (i)（作用域内声明）**：通道 (ii) 单独死掉时本条**不红**，
    /// 那一侧由规则层的 `j3MutationConformanceChannel` 与 Task 11 的端到端变异挡。
    static let positiveControls: [String: String] = [
        "Banner": "BannerStyle",
        "SegmentedControl": "SegmentedControlStyle",
    ]

    @Test("J-3：标注 nativeProtocol 的组件，作用域内不得出现自有样式协议")
    func nativeProtocolComponentsAreFreeOfCustomStyleProtocols() throws {
        let entries = try ComponentRegistryGuard.loadRegistry()
        let scan = try ComponentJudgeSources.scan()
        let result = judgeNativeProtocolPurity(entries: entries, scan: scan)

        // 防线 1：输入集合固定 —— AC 明令「对 nativeProtocol != null 的集合做了**实际
        // 源码扫描**且返回非零条数的检查记录」，不是「集合为空所以全绿」。
        #expect(result.inspected.count == 1,
                "J-3 定义域实测 1 条，实际 \(result.inspected.count) 条：\(result.inspected.keys.sorted())")
        #expect(result.inspected["ProgressIndicator"] != nil,
                "J-3 唯一的定义域成员应是 ProgressIndicator（本仓唯一 nativeProtocol 非空的条目）")

        // 防线 2：作用域真的解析出来了（扫到了非零个源码文件）。
        #expect(result.unresolvedScopes.isEmpty,
                "这些组件的声明文件定位不到 —— 判据没能运行，这不是『零违规』：\(result.unresolvedScopes)")
        #expect(result.inspected["ProgressIndicator"] == ["ProgressIndicator.swift"],
                "ProgressIndicator 的作用域文件实测为 ProgressIndicator.swift，实际 \(result.inspected["ProgressIndicator"] ?? [])")

        // 主判据（**无 withKnownIssue**：J-3 当前零违规，没有已知缺口要豁免）。
        #expect(result.violations.isEmpty,
                """
                这些标注了 nativeProtocol 的组件，作用域内出现了自有样式协议：
                \(result.violations.map { "\($0.component) ← \($0.symbol)（\($0.channel)，\($0.file)）" }.joined(separator: "\n"))
                """)

        // 防线 3：绿色正对照 —— 探针必须在必然命中的组件上命中。
        // ⚠️ 主判据消费的就是这个探针（Task 7 的结构约束）⇒ 这里红等于主判据的探测通路死了。
        for (component, expected) in Self.positiveControls.sorted(by: { $0.key < $1.key }) {
            let found = customStyleProtocolsInScope(of: component, scan: scan)
            #expect(found.contains { $0.symbol == expected },
                    """
                    正对照失效：\(component) 的作用域里应能探到 \(expected)，实际 \(found)。\
                    探针一旦恒返回空集，J-3 只有 1 条输入的主判据会静默全绿 —— 而主判据的违规逐字来自本探针，\
                    所以这条红同时意味着主判据已经失去发现违规的能力
                    """)
            #expect(found.contains { $0.symbol == expected && $0.channel == "作用域内声明" },
                    "正对照的两个组件都应走通道 (i)：\(component) 实际 \(found)")
        }
        // 反向对照：ProgressIndicator 上探到的必须是空集（与主判据同源，但换一个入口读，
        // 保证探针在「有命中」与「无命中」两侧都被使用过）。
        #expect(customStyleProtocolsInScope(of: "ProgressIndicator", scan: scan).isEmpty)

        // 跨仓裁决 (a)：显式报告 + 棘轮。
        #expect(result.skippedRepos == ["storyui": 25],
                "跨仓跳过计数变了：实际 \(result.skippedRepos)")
        #expect(entries.filter { $0.repo == "storyui" && $0.nativeProtocol != nil }.isEmpty,
                "StoryUI 侧出现了 nativeProtocol 非空的条目 —— 本仓读不到那边源码，必须移交 #43")

        print("J-3 定义域 \(result.inspected.count) 条：\(result.inspected.mapValues { $0.sorted() })")
        print("J-3 正对照：" + Self.positiveControls.keys.sorted().map {
            "\($0) → \(customStyleProtocolsInScope(of: $0, scan: scan).map { "\($0.symbol)(\($0.channel)@\($0.file))" })"
        }.joined(separator: "；"))
        print("⚠️ J-3 跳过 storyui \(result.skippedRepos["storyui"] ?? 0) 条：CI 只 checkout 本仓，跨仓核对移交 #43。")
    }
}
