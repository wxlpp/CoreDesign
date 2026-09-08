import Foundation
import Testing

// MARK: - J-3

@Suite("J-3 原生协议纯度")
struct NativeProtocolPurityGuard {
    static let positiveControls: [String: String] = [
        "Banner": "BannerStyle",
        "SegmentedControl": "SegmentedControlStyle",
    ]

    @Test("J-3：标注 nativeProtocol 的组件，作用域内不得出现自有样式协议")
    func nativeProtocolComponentsAreFreeOfCustomStyleProtocols() throws {
        let entries = try ComponentRegistryGuard.loadRegistry()
        let scan = try ComponentJudgeSources.scan()
        let result = judgeNativeProtocolPurity(entries: entries, scan: scan)

        #expect(result.inspected.count == 1,
                "J-3 定义域实测 1 条，实际 \(result.inspected.count) 条：\(result.inspected.keys.sorted())")
        #expect(result.inspected["ProgressIndicator"] != nil,
                "J-3 唯一的定义域成员应是 ProgressIndicator（本仓唯一 nativeProtocol 非空的条目）")

        #expect(result.unresolvedScopes.isEmpty,
                "这些组件的声明文件定位不到 —— 判据没能运行，这不是『零违规』：\(result.unresolvedScopes)")
        #expect(result.inspected["ProgressIndicator"]
                == ["OhMyDesign/Components/ProgressIndicator/ProgressIndicator.swift"],
                "ProgressIndicator 的作用域文件实测为 OhMyDesign/Components/ProgressIndicator/ProgressIndicator.swift，实际 \(result.inspected["ProgressIndicator"] ?? [])")

        #expect(result.violations.isEmpty,
                """
                这些标注了 nativeProtocol 的组件，作用域内出现了自有样式协议：
                \(result.violations.map { "\($0.component) ← \($0.symbol)（\($0.channel)，\($0.file)）" }.joined(separator: "\n"))
                """)

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
        #expect(customStyleProtocolsInScope(of: "ProgressIndicator", scan: scan).isEmpty)

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
