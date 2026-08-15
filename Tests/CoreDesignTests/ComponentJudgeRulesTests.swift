import Foundation
import Testing

@Suite("组件判据规则层")
struct ComponentJudgeRulesTests {

    /// 合成一份扫描结果：只填 J-2/J-3 关心的三个桶。
    private func scan(
        styleProtocols: [String] = [],
        protocolFiles: [String: String] = [:],
        conformances: [(String, [String], String)] = [],
        typeFiles: [String: Set<String>] = [:]
    ) -> ComponentJudgeScanResult {
        var result = ComponentJudgeScanResult()
        result.styleProtocols = styleProtocols.map {
            StyleProtocolDecl(
                name: $0, file: protocolFiles[$0] ?? "\($0).swift", line: 1,
                isPublic: true, nameHasStyleSuffix: $0.hasSuffix("Style")
            )
        }
        result.conformances = conformances.map {
            ConformanceRecord(typeName: $0.0, inheritedNames: $0.1, file: $0.2, line: 1)
        }
        result.typeDeclFiles = typeFiles
        return result
    }

    // MARK: - J-2

    @Test("J-2：自有协议已声明且有实现 ⇒ 满足")
    func j2CustomProtocolSatisfied() {
        let entries = [
            makeTestEntry(component: "Banner", kind: "semantic", decidedBy: "precedent",
                          customStyleProtocol: "BannerStyle", needsExtensionPoint: true),
        ]
        let result = judgeExtensionPoints(
            entries: entries,
            scan: self.scan(
                styleProtocols: ["BannerStyle"],
                conformances: [("PlainBannerStyle", ["BannerStyle"], "Banner.swift")]
            )
        )
        #expect(result.missing.isEmpty)
        #expect(result.inspected == ["Banner"])
        #expect(result.satisfied["Banner"]?.contains("PlainBannerStyle") == true)
    }

    @Test("J-2 变异：协议声明被移走 ⇒ 判红（且违规集合精确）")
    func j2MissingProtocolDeclaration() {
        let entries = [
            makeTestEntry(component: "Banner", kind: "semantic", decidedBy: "precedent",
                          customStyleProtocol: "BannerStyle", needsExtensionPoint: true),
        ]
        let result = judgeExtensionPoints(
            entries: entries,
            scan: self.scan(conformances: [("PlainBannerStyle", ["BannerStyle"], "Banner.swift")])
        )
        #expect(result.missing == ["Banner"])
        #expect(result.diagnostics.contains { $0.contains("无该协议声明") })
    }

    @Test("J-2 变异：协议已声明但零实现 ⇒ 判红（AC 原文『定义 + 使用』）")
    func j2ProtocolWithoutImplementation() {
        let entries = [
            makeTestEntry(component: "Banner", kind: "semantic", decidedBy: "precedent",
                          customStyleProtocol: "BannerStyle", needsExtensionPoint: true),
        ]
        let result = judgeExtensionPoints(entries: entries, scan: self.scan(styleProtocols: ["BannerStyle"]))
        #expect(result.missing == ["Banner"])
        #expect(result.diagnostics.contains { $0.contains("无实现类型") })
    }

    @Test("J-2：nativeProtocol 走 conformance 通路，不要求本仓声明该协议")
    func j2NativeProtocolSatisfied() {
        let entries = [
            makeTestEntry(component: "ProgressIndicator", kind: "semantic", decidedBy: "step1",
                          nativeProtocol: "ProgressViewStyle", needsExtensionPoint: true),
        ]
        let ok = judgeExtensionPoints(
            entries: entries,
            scan: self.scan(conformances: [("CoreProgressViewStyle", ["ProgressViewStyle"], "S.swift")])
        )
        #expect(ok.missing.isEmpty)
        // 变异：本仓没有任何类型实现该原生协议 ⇒ 扩展点不存在。
        let bad = judgeExtensionPoints(entries: entries, scan: self.scan())
        #expect(bad.missing == ["ProgressIndicator"])
    }

    @Test("J-2：两个协议字段都为 null ⇒ 判红（Rating / Toast 的形态）")
    func j2NoExtensionPointAtAll() {
        let entries = [
            makeTestEntry(component: "Rating", kind: "semantic", decidedBy: "step2", needsExtensionPoint: true),
        ]
        let result = judgeExtensionPoints(entries: entries, scan: self.scan())
        #expect(result.missing == ["Rating"])
        #expect(result.diagnostics.contains { $0.contains("既无 nativeProtocol 也无 customStyleProtocol") })
    }

    @Test("J-2 定义域：非 semantic / 不要扩展点 / 非本仓的条目都不进 inspected")
    func j2DomainFilters() {
        let entries = [
            makeTestEntry(component: "Card", kind: "prescriptive", decidedBy: "step3", needsExtensionPoint: false),
            makeTestEntry(component: "ProgressBar", kind: "excluded", decidedBy: "exclusion", needsExtensionPoint: false),
            makeTestEntry(component: "DynamicForm", repo: "storyui", kind: "semantic", decidedBy: "step2",
                          needsExtensionPoint: true),
        ]
        let result = judgeExtensionPoints(entries: entries, scan: self.scan())
        #expect(result.inspected.isEmpty)
        #expect(result.missing.isEmpty)
        #expect(result.skippedRepos == ["storyui": 1],
                "跨仓裁决 (a)：storyui 条目必须被**显式报告**跳过条数，不能静默略过")
    }

    // MARK: - J-3

    @Test("J-3 探针：作用域文件里声明的自有样式协议算命中（通道 i）")
    func j3ScopeDetectsDeclarationChannel() {
        let scan = self.scan(
            styleProtocols: ["BannerStyle"],
            protocolFiles: ["BannerStyle": "Banner.swift"],
            typeFiles: ["Banner": ["Banner.swift"], "ProgressIndicator": ["ProgressIndicator.swift"]]
        )
        let hits = customStyleProtocolsInScope(of: "Banner", scan: scan)
        #expect(hits.map(\.symbol) == ["BannerStyle"])
        #expect(hits.map(\.channel) == ["作用域内声明"])
        #expect(hits.map(\.file) == ["Banner.swift"])
        #expect(customStyleProtocolsInScope(of: "ProgressIndicator", scan: scan).isEmpty)
    }

    @Test("J-3 探针：组件（或其 extension）采纳自有样式协议算命中（通道 ii）")
    func j3ScopeDetectsConformanceChannel() {
        let scan = self.scan(
            styleProtocols: ["BannerStyle"],
            protocolFiles: ["BannerStyle": "Banner.swift"],
            conformances: [("ProgressIndicator", ["View", "BannerStyle"], "Elsewhere.swift")],
            typeFiles: ["ProgressIndicator": ["ProgressIndicator.swift"]]
        )
        let hits = customStyleProtocolsInScope(of: "ProgressIndicator", scan: scan)
        #expect(hits.map(\.symbol) == ["BannerStyle"])
        #expect(hits.map(\.channel) == ["组件采纳"])
        #expect(hits.map(\.file) == ["Elsewhere.swift"],
                "通道 ii 的出处是 conformance 所在文件，不是组件声明文件 —— 报告里要能指到人")
    }

    @Test("J-3 探针：采纳 Apple 原生协议不算命中（自有协议集合里没有它）")
    func j3ScopeIgnoresNativeProtocols() {
        let scan = self.scan(
            conformances: [("ProgressIndicator", ["View", "ProgressViewStyle"], "P.swift")],
            typeFiles: ["ProgressIndicator": ["ProgressIndicator.swift"]]
        )
        #expect(customStyleProtocolsInScope(of: "ProgressIndicator", scan: scan).isEmpty,
                "`styleProtocols` 只收本仓声明的协议，Apple 原生协议不在其中 —— 这是构造保证，不是名字白名单")
    }

    @Test("J-3：只在 nativeProtocol != nil 时触发（SegmentedControl 不得被自己的协议判红）")
    func j3OnlyTriggersOnNativeProtocol() {
        let entries = [
            makeTestEntry(component: "SegmentedControl", kind: "semantic", decidedBy: "precedent",
                          customStyleProtocol: "SegmentedControlStyle", needsExtensionPoint: true),
            makeTestEntry(component: "ProgressIndicator", kind: "semantic", decidedBy: "step1",
                          nativeProtocol: "ProgressViewStyle", needsExtensionPoint: true),
        ]
        let scan = self.scan(
            styleProtocols: ["SegmentedControlStyle"],
            protocolFiles: ["SegmentedControlStyle": "SegmentedControl.swift"],
            typeFiles: [
                "SegmentedControl": ["SegmentedControl.swift"],
                "ProgressIndicator": ["ProgressIndicator.swift"],
            ]
        )
        let result = judgeNativeProtocolPurity(entries: entries, scan: scan)
        #expect(Array(result.inspected.keys) == ["ProgressIndicator"],
                "裁决 D3：合并 nativeProtocol / customStyleProtocol 会让 SegmentedControl 被自己发布的协议判红")
        #expect(result.violations.isEmpty)
    }

    @Test("J-3 变异：给 nativeProtocol 组件的作用域塞进自有样式协议 ⇒ 判红（违规集合精确）")
    func j3MutationDeclarationChannel() {
        let entries = [
            makeTestEntry(component: "ProgressIndicator", kind: "semantic", decidedBy: "step1",
                          nativeProtocol: "ProgressViewStyle", needsExtensionPoint: true),
        ]
        let scan = self.scan(
            styleProtocols: ["ProgressIndicatorStyle"],
            protocolFiles: ["ProgressIndicatorStyle": "ProgressIndicator.swift"],
            typeFiles: ["ProgressIndicator": ["ProgressIndicator.swift"]]
        )
        let result = judgeNativeProtocolPurity(entries: entries, scan: scan)
        #expect(result.violations.map(\.symbol) == ["ProgressIndicatorStyle"])
        #expect(result.violations.map(\.channel) == ["作用域内声明"])
    }

    @Test("J-3 变异：conformance 通道同样判红")
    func j3MutationConformanceChannel() {
        let entries = [
            makeTestEntry(component: "ProgressIndicator", kind: "semantic", decidedBy: "step1",
                          nativeProtocol: "ProgressViewStyle", needsExtensionPoint: true),
        ]
        let scan = self.scan(
            styleProtocols: ["BannerStyle"],
            protocolFiles: ["BannerStyle": "Banner.swift"],
            conformances: [("ProgressIndicator", ["BannerStyle"], "ProgressIndicator.swift")],
            typeFiles: ["ProgressIndicator": ["ProgressIndicator.swift"]]
        )
        let result = judgeNativeProtocolPurity(entries: entries, scan: scan)
        #expect(result.violations.map(\.symbol) == ["BannerStyle"])
    }

    @Test("J-3：作用域解析不出来必须报告，不能算绿（零输出不是绿）")
    func j3UnresolvedScopeIsReported() {
        let entries = [
            makeTestEntry(component: "ProgressIndicator", kind: "semantic", decidedBy: "step1",
                          nativeProtocol: "ProgressViewStyle", needsExtensionPoint: true),
        ]
        let result = judgeNativeProtocolPurity(entries: entries, scan: self.scan())
        #expect(result.unresolvedScopes == ["ProgressIndicator"],
                "扫描器找不到组件的声明文件时，『作用域内没有自有协议』是假绿 —— 必须单独报出来")
    }

    @Test("J-3 结构约束：主判据的违规集合就是探针的命中集合（判据不得内联重写探针）")
    func j3JudgeConsumesTheProbe() {
        let entries = [
            makeTestEntry(component: "ProgressIndicator", kind: "semantic", decidedBy: "step1",
                          nativeProtocol: "ProgressViewStyle", needsExtensionPoint: true),
        ]
        // 两条通道同时命中，且 file 各不相同 —— 内联重写版本很容易在这里把 file 填错。
        let scan = self.scan(
            styleProtocols: ["ProgressIndicatorStyle", "BannerStyle"],
            protocolFiles: [
                "ProgressIndicatorStyle": "ProgressIndicator.swift",
                "BannerStyle": "Banner.swift",
            ],
            conformances: [("ProgressIndicator", ["BannerStyle"], "Elsewhere.swift")],
            typeFiles: ["ProgressIndicator": ["ProgressIndicator.swift"]]
        )
        let probeHits = customStyleProtocolsInScope(of: "ProgressIndicator", scan: scan)
        let result = judgeNativeProtocolPurity(entries: entries, scan: scan)

        // ⚠️ **这条断言是 Task 8「绿色正对照」的结构前提**：正对照红只能证明**探针**死了；
        // 只有当主判据的违规逐字来自探针命中时，「探针死 ⇒ 主判据也瞎」才是可推的，
        // 而不是两段各写各的代码恰好都还活着。
        #expect(result.violations.map(\.symbol) == probeHits.map(\.symbol))
        #expect(result.violations.map(\.channel) == probeHits.map(\.channel))
        #expect(result.violations.map(\.file) == probeHits.map(\.file))
        #expect(result.violations.map(\.component) == ["ProgressIndicator", "ProgressIndicator"])
        // 非空断言先行：两个空集合也能让上面三条相等 —— 那是「都没跑」不是「一致」。
        #expect(probeHits.count == 2, "两条通道各应命中一次，实际 \(probeHits)")
    }
}
