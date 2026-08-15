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

    // MARK: - FR-4

    /// 合成一份只含文本参数的扫描结果。
    private func textScan(_ rows: [(String, String, TextParamKind, Bool)]) -> ComponentJudgeScanResult {
        var result = ComponentJudgeScanResult()
        result.textParams = rows.map { owner, parameter, kind, isInit in
            TextParamHit(
                owner: owner, decl: isInit ? "init" : "show", parameter: parameter,
                file: "\(owner).swift", line: 1, kind: kind, isInitializer: isInit
            )
        }
        return result
    }

    @Test("FR-4：裸文本参数在 textParams 里有条目 ⇒ covered")
    func fr4Covered() {
        let entries = [
            makeTestEntry(component: "Tag", kind: "prescriptive", decidedBy: "step3",
                          needsExtensionPoint: false,
                          textParams: [ComponentRegistryGuard.TextParam(name: "text", category: "C")]),
        ]
        let result = judgeTextParamCoverage(
            entries: entries, scan: self.textScan([("Tag", "text", .bareText, true)]), ownerAliases: [:]
        )
        #expect(result.covered == ["Tag.init#text": "Tag.text"])
        #expect(result.violations.isEmpty)
        #expect(result.ghostRegistryParams.isEmpty)
    }

    @Test("FR-4 变异：新增未登记的裸文本参数 ⇒ 判红；补登记 ⇒ 转绿")
    func fr4MutationUnregisteredParameter() {
        let scan = self.textScan([("Tag", "text", .bareText, true), ("Tag", "hint", .bareText, true)])
        let before = [
            makeTestEntry(component: "Tag", kind: "prescriptive", decidedBy: "step3",
                          needsExtensionPoint: false,
                          textParams: [ComponentRegistryGuard.TextParam(name: "text", category: "C")]),
        ]
        let red = judgeTextParamCoverage(entries: before, scan: scan, ownerAliases: [:])
        #expect(red.violations == ["Tag.init#hint"], "未登记的裸文本参数必须判红")

        let after = [
            makeTestEntry(component: "Tag", kind: "prescriptive", decidedBy: "step3",
                          needsExtensionPoint: false,
                          textParams: [
                              ComponentRegistryGuard.TextParam(name: "text", category: "C"),
                              ComponentRegistryGuard.TextParam(name: "hint", category: "B"),
                          ]),
        ]
        let green = judgeTextParamCoverage(entries: after, scan: scan, ownerAliases: [:])
        #expect(green.violations.isEmpty, "补登记后应转绿 —— AC 原文的『补登记 → 判据变绿』")
    }

    @Test("FR-4：category 为空串的条目不算覆盖（AC 原文『且分类非空』）")
    func fr4EmptyCategoryIsNotCoverage() {
        let entries = [
            makeTestEntry(component: "Tag", kind: "prescriptive", decidedBy: "step3",
                          needsExtensionPoint: false,
                          textParams: [ComponentRegistryGuard.TextParam(name: "text", category: "")]),
        ]
        let result = judgeTextParamCoverage(
            entries: entries, scan: self.textScan([("Tag", "text", .bareText, true)]), ownerAliases: [:]
        )
        #expect(result.violations == ["Tag.init#text"])
    }

    @Test("FR-4：owner 别名 + 限定参数名两条解析路径")
    func fr4OwnerAliasAndQualifiedName() {
        let entries = [
            makeTestEntry(component: "Steps", kind: "prescriptive", decidedBy: "step3",
                          needsExtensionPoint: false,
                          textParams: [ComponentRegistryGuard.TextParam(name: "StepItem.title", category: "B")]),
            makeTestEntry(component: "Toast", kind: "semantic", decidedBy: "step2",
                          needsExtensionPoint: true,
                          textParams: [ComponentRegistryGuard.TextParam(name: "message", category: "B")]),
        ]
        let result = judgeTextParamCoverage(
            entries: entries,
            scan: self.textScan([("StepItem", "title", .bareText, true), ("ToastItem", "message", .bareText, true)]),
            ownerAliases: ["StepItem": "Steps", "ToastItem": "Toast"]
        )
        #expect(result.violations.isEmpty)
        #expect(result.covered["StepItem.init#title"] == "Steps.StepItem.title")
        #expect(result.covered["ToastItem.init#message"] == "Toast.message")
    }

    @Test("FR-4：kind == excluded 的组件整体豁免（弃用条款「不分类」）")
    func fr4ExcludedKindIsExempt() {
        let entries = [
            makeTestEntry(component: "ProgressBar", kind: "excluded", decidedBy: "exclusion",
                          needsExtensionPoint: false),
        ]
        let result = judgeTextParamCoverage(
            entries: entries, scan: self.textScan([("ProgressBar", "label", .bareText, true)]), ownerAliases: [:]
        )
        #expect(result.violations.isEmpty)
        #expect(result.exemptedByExcludedKind == ["ProgressBar.init#label"],
                "弃用组件必须落进**具名的豁免桶**并被固定集合断言钉住，不能悄悄不出现在任何桶里")
    }

    @Test("FR-4：登记表 notes 点名了参数名 ⇒ 豁免；没点名 ⇒ 判红")
    func fr4RegistryNotesAuthorization() {
        let authorized = [
            makeTestEntry(component: "LabelIcon", kind: "prescriptive", decidedBy: "step3",
                          needsExtensionPoint: false,
                          notes: "纯装饰图标。systemName 是符号标识符不是展示文案，不计入 textParams。"),
        ]
        let ok = judgeTextParamCoverage(
            entries: authorized, scan: self.textScan([("LabelIcon", "systemName", .bareText, true)]), ownerAliases: [:]
        )
        #expect(ok.violations.isEmpty)
        #expect(ok.exemptedByRegistryNotes == ["LabelIcon.init#systemName"])

        let unauthorized = [
            makeTestEntry(component: "SidebarUtilityRow", kind: "prescriptive", decidedBy: "step3",
                          needsExtensionPoint: false, notes: "单动作工具行，固定结构 ⇒ 步骤 3 规定性。"),
        ]
        let red = judgeTextParamCoverage(
            entries: unauthorized, scan: self.textScan([("SidebarUtilityRow", "systemImage", .bareText, true)]),
            ownerAliases: [:]
        )
        #expect(red.violations == ["SidebarUtilityRow.init#systemImage"],
                "登记表没点名 ⇒ 判据不得自行认定它『不是文案』—— 这类情形要退回 #38 补登记")
    }

    @Test("FR-4：宿主不对应登记表条目 ⇒ 进 unmappedOwners，不判红也不静默")
    func fr4UnmappedOwner() {
        let result = judgeTextParamCoverage(
            entries: [], scan: self.textScan([("Color", "text", .bareText, true)]), ownerAliases: [:]
        )
        #expect(result.violations.isEmpty)
        #expect(result.unmappedOwners == ["Color.init#text"])
    }

    @Test("FR-4 反向：登记表有条目、源码扫不到 ⇒ 幽灵条目")
    func fr4GhostRegistryParam() {
        let entries = [
            makeTestEntry(component: "Tag", kind: "prescriptive", decidedBy: "step3",
                          needsExtensionPoint: false,
                          textParams: [
                              ComponentRegistryGuard.TextParam(name: "text", category: "C"),
                              ComponentRegistryGuard.TextParam(name: "gone", category: "B"),
                          ]),
        ]
        let result = judgeTextParamCoverage(
            entries: entries, scan: self.textScan([("Tag", "text", .bareText, true)]), ownerAliases: [:]
        )
        #expect(result.ghostRegistryParams == ["Tag.gone"],
                "反向差集是第二道防线：把 `text: String` 改写成扫描器看不见的形态，正向漏判，反向会把它抓成幽灵")
    }

    @Test("FR-4：LSK/LSR 由类型判定，不要求登记表条目，但必须被识别")
    func fr4LocalizedByType() {
        let result = judgeTextParamCoverage(
            entries: [makeTestEntry(component: "Descriptions", kind: "prescriptive", decidedBy: "step3",
                                    needsExtensionPoint: false,
                                    textParams: [ComponentRegistryGuard.TextParam(name: "header", category: "by-type")])],
            scan: self.textScan([("Descriptions", "header", .localizedText, true)]), ownerAliases: [:]
        )
        #expect(result.violations.isEmpty)
        #expect(result.localizedByType == ["Descriptions.init#header"])
        #expect(result.ghostRegistryParams.isEmpty, "LSK/LSR 命中也要能消掉反向差集里的对应条目")
    }

    @Test("FR-4：同一个键被多个 init 重载命中时，各桶按键去重（计数单位是键不是命中）")
    func fr4BucketsAreDedupedByKey() {
        // 同一个 `SettingsRow.init#title` 被两个重载各命中一次 —— 真实源码里就是这个形态
        // （SettingsRow 有多个 init 重载都带 `title: LocalizedStringKey`）。
        let scan = self.textScan([
            ("SettingsRow", "title", .localizedText, true),
            ("SettingsRow", "title", .localizedText, true),
            ("SearchField", "text", .textCarrying, true),
            ("SearchField", "text", .textCarrying, true),
            ("Ghost", "a", .bareText, true),
            ("Ghost", "a", .bareText, true),
        ])
        let result = judgeTextParamCoverage(entries: [], scan: scan, ownerAliases: [:])
        #expect(result.localizedByType == ["SettingsRow.init#title"],
                "留痕桶的单位是**扫描键**不是命中数：两个重载命中同一个键只算一条，实际 \(result.localizedByType)")
        #expect(result.carrying == ["SearchField.init#text"])
        #expect(result.unmappedOwners == ["Ghost.init#a"])
        // ⚠️ 承重：不去重时上面三条会各得 2 —— 这正是 Task 10 首跑时 localizedByType
        // 打出 14（命中数）而 Task 3 冒烟打出 11（Set 键数）的原因。
        #expect(result.localizedByType.count == 1 && result.carrying.count == 1 && result.unmappedOwners.count == 1)
    }

    @Test("FR-4：func 侧裸文本参数进留痕桶，不进主判据")
    func fr4FunctionSideBucket() {
        let result = judgeTextParamCoverage(
            entries: [], scan: self.textScan([("View", "placeholder", .bareText, false)]), ownerAliases: [:]
        )
        #expect(result.violations.isEmpty)
        #expect(result.unmappedOwners.isEmpty)
        #expect(result.functionSideBareText == ["View.show#placeholder"])
    }
}
