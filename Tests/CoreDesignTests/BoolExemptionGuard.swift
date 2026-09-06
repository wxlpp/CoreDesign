import Foundation
import SwiftParser
import SwiftSyntax
import Testing

@Suite("Bool 豁免基线与棘轮")
struct BoolExemptionGuard {
    // MARK: - 路径

    static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    static var scanRoots: [(target: String, url: URL)] { GuardScanRoots.allRoots }
    static var exemptionsURL: URL { repoRoot.appendingPathComponent("docs/bool-exemptions.json") }
    static var baselineURL: URL { repoRoot.appendingPathComponent("docs/bool-exemptions-baseline.json") }

    // MARK: - 扫描缓存

    private static var cachedScan: BoolScanResult?

    static func boolScan() throws -> BoolScanResult {
        if let cached = Self.cachedScan { return cached }
        let result = try scanBoolParams(roots: Self.scanRoots)
        if !result.hits.isEmpty { Self.cachedScan = result }
        return result
    }

    // MARK: - 判据体系之外的参照物

    static let contractNamedKeys: Set<String> = [
        "Badge.init#outlined",
        "SidebarSection.init#showsChevron",
        "Tag.init#removable",
        "PinCode.init#isSecure",
        "Skeleton.init#isLoading",
        "Carousel.init#autoAdvance",
        "TagInput.init#allowDuplicates",
        "SegmentedControlStyleConfiguration.Segment.init#isSelected",
    ]

    static let pendingViolationKeys: Set<String> = []

    // MARK: - 与 #38 登记表的交叉核对（39.md 最后一条 AC 的收窄落地）

    enum OwnerExclusionKind: Sendable {
        case externalProtocolExtension
        case styleImplementation
        case nonViewPublicType
    }

    static let ownersWithoutRegistryEntry: [String: OwnerExclusionKind] = [
        "View": .externalProtocolExtension,
        "SolidButtonStyle": .styleImplementation,
        "LightButtonStyle": .styleImplementation,
        "StepItem": .nonViewPublicType,
        "ButtonRoleStyleRole": .nonViewPublicType,
        "EnergyState": .nonViewPublicType,
        "SegmentedControlStyleConfiguration.Segment": .nonViewPublicType,
    ]

    // MARK: - Important-2 (a)：`.externalProtocolExtension` 的正向核对

    private static var cachedDeclaredTypeNames: Set<String>?

    static func declaredTypeNames() throws -> Set<String> {
        if let cached = Self.cachedDeclaredTypeNames { return cached }
        GuardScanRoots.assertRootsExist(Self.scanRoots)
        var names: Set<String> = []
        for root in Self.scanRoots {
            for url in GuardScanRoots.swiftFiles(in: root.url) {
                let tree = SwiftParser.Parser.parse(source: try String(contentsOf: url, encoding: .utf8))
                if tree.hasError {
                    Issue.record("解析出错：\(GuardScanRoots.relativePath(url)) —— swift-syntax major 可能与工具链不配套")
                }
                let collector = DeclaredTypeNameCollector()
                collector.walk(tree)
                names.formUnion(collector.names)
            }
        }
        if !names.isEmpty { Self.cachedDeclaredTypeNames = names }
        return names
    }

    static func assertOwnerClassification(
        owner: String,
        kind: OwnerExclusionKind,
        scan: ComponentRegistryGuard.ScanResult,
        declaredTypeNames: Set<String>,
        readmeNames: Set<String>
    ) {
        switch kind {
        case .externalProtocolExtension:
            #expect(!scan.components.contains(owner) && !scan.styleImpls.contains(owner),
                    "「\(owner)」被标为外部协议扩展，但本仓源码里就有这个类型 —— 分类过期，该重新裁决")
            #expect(!declaredTypeNames.contains(owner),
                    "「\(owner)」被标为外部协议扩展（本仓没有同名类型声明），但本仓源码里确实声明了一个同名类型 —— 分类过期，该重新裁决")
        case .styleImplementation:
            #expect(scan.styleImpls.contains(owner),
                    "「\(owner)」被标为 style 实现，但扫描器的 styleImpls 里没有它 —— 删光 Components/Button/styles/ 也会命中这条")
        case .nonViewPublicType:
            let root = owner.split(separator: ".").first.map(String.init) ?? owner
            #expect(!scan.components.contains(root),
                    "「\(root)」已被扫描器采集为组件类型 —— 它现在该进登记表了，从台账里移走")
            #expect(!readmeNames.contains(root),
                    "「\(root)」已出现在 docs/README.md 的组件索引里 —— 按 AD-2 终审 I4 的复合条件它该登记，重新裁决")
            #expect(declaredTypeNames.contains(root),
                    "「\(root)」被标为「非 View 的公开类型」，但本仓源码里根本没有这个类型的声明 —— 分类过期或名字写错了")
            #expect(!scan.styleImpls.contains(root),
                    "「\(root)」被标为「非 View 的公开类型」，但扫描器把它采集为**样式实现** —— 它该标 .styleImplementation，分类错了")
        }
    }

    static func owner(ofExemptionKey key: String) -> String {
        let head = GuardScanRoots.baseKey(key).split(separator: "#").first.map(String.init)
            ?? GuardScanRoots.baseKey(key)
        var parts = head.split(separator: ".").map(String.init)
        if parts.count > 1 { parts.removeLast() }
        return parts.joined(separator: ".")
    }

    static func exemptedKeys() throws -> Set<String> {
        Set(try Self.loadExemptions().compactMap(\.parameter))
    }

    // MARK: - 豁免清单 schema（J-4 的豁免基线部分）

    struct Exemption: Codable {
        let parameter: String?
        let reason: String?
        let decidedBy: String?
        let decidedOn: String?
    }

    static let bannedReasonPhrases: [String] = [
        "历史遗留", "TODO", "TBD", "FIXME", "fixme", "待定", "占位符", "暂无", "见上", "同上",
    ]

    static func loadExemptions() throws -> [Exemption] {
        try JSONDecoder().decode([Exemption].self, from: Data(contentsOf: Self.exemptionsURL))
    }

    // MARK: - 棘轮基线 schema（Task 5）

    struct Baseline: Codable {
        let maxEntries: Int?
        let raisedBy: String?
        let raisedOn: String?
        let rationale: String?
        let sourceSites: Int?

        let perTarget: [String: TargetCounts]?

        struct TargetCounts: Codable, Hashable, Sendable {
            let exemptions: Int
            let sourceSites: Int
        }
    }

    // MARK: - 棘轮判据的纯函数（终审 S-e：装牙 + 可合成证伪）

    static func rationaleTargetProblems(_ rationale: String?) -> [String] {
        guard let rationale, !rationale.trimmingCharacters(in: .whitespaces).isEmpty else {
            return ["棘轮基线缺 rationale —— 无从判断这次抬高属于哪个 target"]
        }
        guard GuardScanRoots.targetNames.contains(where: { rationale.contains($0) }) else {
            return ["""
            棘轮基线的 rationale 没有点名任何 target（\(GuardScanRoots.targetNames)）。
            `maxEntries` / `sourceSites` 自 `#246` 起是**全包**计数，一次抬高可能来自任一 target；
            rationale 不点名，读者只能按主 target 的老口径理解，而
            `scripts/bool-exemptions-ratchet.sh` 对此完全看不见（它只比较 rationale 是否逐字变了，
            随后 warning + exit 0）。⇒ 请在 rationale 里写明这次变化落在哪个 target 上。
            """]
        }
        return []
    }

    static func perTargetProblems(
        perTarget: [String: Baseline.TargetCounts]?,
        exemptionKeys: [String],
        hits: [BoolParamHit]
    ) -> [String] {
        guard let perTarget else {
            return ["棘轮基线缺 perTarget 字段 —— 跨 target 对冲（删一个 CoreDesign 的、加一个 Effects 的）对棘轮不可见"]
        }
        var problems: [String] = []
        let declared = Set(perTarget.keys)
        let expected = Set(GuardScanRoots.targetNames)
        if declared != expected {
            problems.append("""
            棘轮基线 perTarget 的键集合 \(declared.sorted()) 与 `GuardScanRoots.targetNames`
            \(expected.sorted()) 不吻合 —— 少一个 target 等于给它留一个不受棘轮约束的额度。
            """)
        }
        var actualExemptions: [String: Int] = [:]
        for key in exemptionKeys {
            actualExemptions[GuardScanRoots.target(ofKey: key), default: 0] += 1
        }
        var actualSites: [String: Int] = [:]
        for hit in hits { actualSites[hit.target, default: 0] += 1 }

        for target in GuardScanRoots.targetNames {
            let counts = perTarget[target] ?? .init(exemptions: 0, sourceSites: 0)
            let exemptions = actualExemptions[target] ?? 0
            let sites = actualSites[target] ?? 0
            if counts.exemptions != exemptions {
                let raised = exemptions > counts.exemptions
                problems.append("""
                逐 target 棘轮：\(target) 的豁免条目数 \(exemptions) ≠ 基线 \(counts.exemptions)。
                总数 `maxEntries` 不变**不代表**没变化——删一个 CoreDesign 的、加一个 Effects 的，
                总数纹丝不动而定义域已经漂了。
                \(raised
                    ? "本次是**抬高**（\(counts.exemptions) → \(exemptions)）⇒ 这是一次破例，请同轮更新 docs/bool-exemptions-baseline.json 的 perTarget，**连同 raisedBy / raisedOn / rationale**（rationale 必须点名 target）。"
                    : "本次是**下降**（\(counts.exemptions) → \(exemptions)）⇒ 治理掉了豁免，这是好方向，不是破例：只需把 docs/bool-exemptions-baseline.json 的 perTarget 跟着降下来，**不必**改 raisedBy / raisedOn / rationale（那三项记的是上一次抬高）。")
                """)
            }
            if counts.sourceSites != sites {
                let raised = sites > counts.sourceSites
                problems.append("""
                逐 target 棘轮：\(target) 的源码位置数 \(sites) ≠ 基线 \(counts.sourceSites)。
                同上——`sourceSites` 的全包合计挡不住跨 target 的一加一减。
                \(raised
                    ? "本次是**抬高**（\(counts.sourceSites) → \(sites)）⇒ 破例，署名同上。"
                    : "本次是**下降**（\(counts.sourceSites) → \(sites)）⇒ 好方向，把基线跟着降下来即可。")
                """)
            }
        }
        return problems
    }

    static func loadBaseline() throws -> Baseline {
        try JSONDecoder().decode(Baseline.self, from: Data(contentsOf: Self.baselineURL))
    }

    // MARK: - Task 2 的判据

    @Test("扫描器真的扫到了 public Bool 参数，且覆盖公约点名的每一条")
    func scannerFindsPublicBoolParameters() throws {
        let scan = try Self.boolScan()

        #expect(scan.hits.count > 20, "只扫到 \(scan.hits.count) 处 Bool 参数 —— 扫描器失效")
        #expect(scan.keys.count > 20, "只得到 \(scan.keys.count) 个豁免键 —— 扫描器失效")

        let missingNamed = Self.contractNamedKeys.subtracting(scan.keys)
        let namedMessage = """
        公约 / PRD 白纸黑字点名的这些 Bool 参数，扫描器没扫到：\(missingNamed.sorted())
        —— 这是判据体系**之外**的参照物，掉出来说明扫描器的匹配范围被改窄了，
        不是「这些参数不存在了」。若确实是源码删掉了它们（#41 的改造），
        请同轮把对应条目从 contractNamedKeys 里移走，并在 commit message 里说明。
        """
        #expect(missingNamed.isEmpty, "\(namedMessage)")

        let aliasMessage = """
        发现含 Bool 的 public typealias：\(scan.publicBoolTypeAliases.sorted())
        —— 它会让 `init(flag: Flag)` 这种签名在 J-1 的三层（命中 / 清点 / 留痕）里
        **同时消失**。判据不接受这种形状：要么改回写 `Bool`（照常进豁免清单并抬高
        maxEntries），要么同轮把扫描器扩成两遍扫描的完整档（建 alias 映射后代入分类），
        并在 commit message 里写明为何值得。**不要只把这条断言删掉。**
        """
        #expect(scan.publicBoolTypeAliases.isEmpty, "\(aliasMessage)")

        for root in Self.scanRoots {
            let n = scan.hits.filter { $0.target == root.target }.count
            print("【J-1 逐 target】\(root.target)：\(n) 处")
        }
        print("【J-1 命中】\(scan.keys.count) 个豁免键 / \(scan.hits.count) 处源码位置：")
        for hit in scan.hits.sorted() { print("  \(hit.key)  ←  \(hit.file):\(hit.line)") }
        print("【裁决 (b) 归类为 .boolCarrying，不判违规】\(scan.carrying.count) 处：")
        for hit in scan.carrying.sorted() { print("  \(hit.key)  ←  \(hit.file):\(hit.line)") }
        print("【裁决 (d) public Bool 属性，只清点不判据】\(scan.publicBoolProperties.count) 处：")
        for name in scan.publicBoolProperties.sorted() { print("  \(name)") }
        print("【裁决 (f) 含 Bool 的 public typealias，必须为 0】\(scan.publicBoolTypeAliases.count) 处：")
        for name in scan.publicBoolTypeAliases.sorted() { print("  \(name)") }
    }

    @Test("J-4：豁免基线存在、可解析、每条四字段齐全且理由不是空话")
    func exemptionBaselineIsWellFormed() throws {
        #expect(
            FileManager.default.fileExists(atPath: Self.exemptionsURL.path),
            "豁免基线不存在：\(Self.exemptionsURL.path) —— 判据无法工作，这不是「零豁免」"
        )
        let entries = try Self.loadExemptions()
        #expect(entries.count >= 12,
                "豁免清单只有 \(entries.count) 条 —— 下界取 PRD 点名的 10 条 + 两条实测补入（StepItem.init#isError / View.bottomInputBar#autoFocus），低于它疑似没读到或是空壳。⚠️ 原文案写的「10 条 + 两个 glass」已随 #41 裁决 3 过期：两个 glass 已按终局条款 (b) 删除、不再在清单里。")

        var seen: Set<String> = []
        for (index, entry) in entries.enumerated() {
            let label = "第 \(index + 1) 条（parameter=\(entry.parameter ?? "<缺失>")）"

            guard let parameter = entry.parameter, !parameter.trimmingCharacters(in: .whitespaces).isEmpty else {
                Issue.record("\(label)：缺 parameter 字段")
                continue
            }
            #expect(seen.insert(parameter).inserted, "\(label)：parameter 重复出现")

            guard let reason = entry.reason, !reason.trimmingCharacters(in: .whitespaces).isEmpty else {
                Issue.record("\(label)：缺 reason 字段"); continue
            }
            guard let decidedBy = entry.decidedBy, !decidedBy.trimmingCharacters(in: .whitespaces).isEmpty else {
                Issue.record("\(label)：缺 decidedBy（裁决人）字段"); continue
            }
            guard let decidedOn = entry.decidedOn, !decidedOn.trimmingCharacters(in: .whitespaces).isEmpty else {
                Issue.record("\(label)：缺 decidedOn（日期）字段"); continue
            }

            #expect(reason.count >= 40, "\(label)：理由只有 \(reason.count) 字符，像占位")
            for banned in Self.bannedReasonPhrases where reason.contains(banned) {
                Issue.record("\(label)：理由含空话占位词「\(banned)」")
            }
            #expect(reason.contains("删除"),
                    "\(label)：理由没提「删除」——公约终局条款是**有序**的，先试 (b) 删除、(b) 不成立才用 (a) 记入豁免，理由必须写清为什么删不掉")

            #expect(decidedOn.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil,
                    "\(label)：decidedOn=\(decidedOn) 不是 YYYY-MM-DD")
            for banned in Self.bannedReasonPhrases where decidedBy.contains(banned) {
                Issue.record("\(label)：裁决人字段里是占位词「\(banned)」，不是一个人")
            }
        }
    }

    @Test("豁免清单的每个键都是扫描器能产出的形状")
    func exemptionKeysAreScannerShaped() throws {
        let entries = try Self.loadExemptions()
        #expect(!entries.isEmpty, "豁免清单为空 —— 非空断言，见 exemptionBaselineIsWellFormed")
        for entry in entries {
            guard let parameter = entry.parameter else { continue }
            #expect(parameter.contains("#") && parameter.contains("."),
                    "豁免键「\(parameter)」不是 `Owner.decl#param` 形状")
        }
    }

    // MARK: - `#246`：台账键的 target 前缀

    static func qualificationProblems(ofKey parameter: String) -> [String] {
        guard parameter.contains("/") else { return [] }
        let target = GuardScanRoots.target(ofKey: parameter)
        var problems: [String] = []
        if !GuardScanRoots.targetNames.contains(target) {
            problems.append("""
            豁免键「\(parameter)」的 target 前缀「\(target)」不在 `GuardScanRoots.targetNames` 里
            —— 要么 target 名写错了，要么它还没落地。挂在不存在的 target 上的豁免永远匹配不到
            任何命中，只会以「过期条目」的面目红掉，诊断绕远路。
            """)
        }
        if target == GuardScanRoots.primaryTargetName {
            problems.append("""
            豁免键「\(parameter)」给主 target 写了显式前缀 —— 主 target 的规范形态是**裸形**
            `Owner.decl#param`（见 `GuardScanRoots.qualifiedKey(target:base:)` 的文档）。
            同一条豁免存在两种拼法时，扫描器只产出其中一种，另一种恒为过期条目。
            """)
        }
        return problems
    }

    @Test("台账键的 target 前缀合法且唯一形态：裸形只属于主 target，带前缀者必须指向已存在的 target")
    func exemptionKeysAreCanonicallyQualified() throws {
        let entries = try Self.loadExemptions()
        #expect(!entries.isEmpty, "豁免清单为空 —— 本判据会在空循环上恒真")

        for entry in entries {
            guard let parameter = entry.parameter else { continue }
            for problem in Self.qualificationProblems(ofKey: parameter) { Issue.record("\(problem)") }
        }
    }

    @Test("前缀判据真的会开火：合成键逐条变红自证（终审 S-1）")
    func qualificationValidatorActuallyFires() {
        #expect(!Self.qualificationProblems(ofKey: "CoreDesign/Foo.init#flag").isEmpty,
                "主 target 的显式前缀不会红 —— 上面那条判据在现存 32 个裸形键上从不执行")
        #expect(!Self.qualificationProblems(ofKey: "CoreDesignShaders/Foo.init#flag").isEmpty,
                "不存在的 target 前缀不会红")
        #expect(Self.qualificationProblems(ofKey: "CoreDesignEffects/Foo.init#flag").isEmpty,
                "合法的新 target 前缀被误报")
        #expect(Self.qualificationProblems(ofKey: "Badge.init#outlined").isEmpty,
                "主 target 的裸形键被误报")
    }

    // MARK: - Task 4 的判据：双向精确匹配

    @Test("J-1：public 声明不得含未豁免的 Bool 参数")
    func j1NoUnexemptedBoolParameters() throws {
        let scan = try Self.boolScan()
        #expect(scan.keys.count > 20, "只扫到 \(scan.keys.count) 个豁免键 —— 扫描器失效")

        let diff = compareBoolHitsToExemptions(hits: scan.keys, exempted: try Self.exemptedKeys())

        let staleMessage = """
        豁免清单里这些条目在源码里已经找不到了：\(diff.stale.sorted())
        —— 过期条目同样判红（AC 原文）。删掉它们，并**同轮下调**
        bool-exemptions-baseline.json 的 maxEntries（棘轮不留 slack，见 baselineRatchet 判据）。
        """
        #expect(diff.stale.isEmpty, "\(staleMessage)")

        let violationMessage = """
        这些 public Bool 参数不在 docs/bool-exemptions.json 里：\(diff.violations.sorted())

        ⚠️ **#41 之后这里预期为空**：`View.surface#bordered` 这条历史例外已随裁决 1 消失，
        `pendingViolationKeys` 也已清空 ⇒ 本断言不再有 `withKnownIssue` 包裹，是裸判据。
        新增的 Bool 参数要么改掉，要么按公约第 3 节终局条款**先试 (b) 删除**、
        (b) 不成立才走 (a) 记入豁免基线（并同轮抬高 bool-exemptions-baseline.json 的 maxEntries）。
        """

        #expect(diff.violations.isEmpty, "\(violationMessage)")
    }

    @Test("未豁免违规集合与 pendingViolationKeys（现为空集）恰好相等（这条是**绿**的，专抓新违规）")
    func j1ViolationSetIsExactlyTheContractPending() throws {
        let scan = try Self.boolScan()
        #expect(scan.keys.count > 20, "只扫到 \(scan.keys.count) 个豁免键 —— 扫描器失效")

        let diff = compareBoolHitsToExemptions(hits: scan.keys, exempted: try Self.exemptedKeys())
        let unexpected = diff.violations.subtracting(Self.pendingViolationKeys)
        #expect(unexpected.isEmpty,
                "出现了公约未预期的未豁免 Bool 参数：\(unexpected.sorted()) —— pendingViolationKeys 现为空集，没有任何预期的红，出现即是新增违规")

        let disappeared = Self.pendingViolationKeys.subtracting(diff.violations)
        let disappearedMessage = """
        这些条目已不再是未豁免违规：\(disappeared.sorted())
        —— 若 #41 已经删除/改造了它们，请**同轮**把它们从 pendingViolationKeys 移走
        （若改造成了别的形状而仍带 Bool，还要同轮进豁免清单 + 抬高 maxEntries）。
        本条断言的存在就是为了不让这个待办被忘掉：它不会自己保鲜，所以由判据保鲜。
        """
        #expect(disappeared.isEmpty, "\(disappearedMessage)")
    }

    @Test("棘轮：豁免清单条目数与基线 maxEntries 严格相等、源码位置数与 sourceSites 严格相等，且基线自身字段齐全")
    func baselineRatchetHoldsExactly() throws {
        #expect(
            FileManager.default.fileExists(atPath: Self.baselineURL.path),
            "棘轮基线不存在：\(Self.baselineURL.path) —— 判据无法工作，这不是「上限没被抬高」"
        )
        let baseline = try Self.loadBaseline()

        guard let maxEntries = baseline.maxEntries else {
            Issue.record("棘轮基线缺 maxEntries 字段"); return
        }
        #expect(maxEntries > 0, "maxEntries=\(maxEntries) —— 零上限不是「很严」，是判据没配置")
        for (name, value) in [("raisedBy", baseline.raisedBy), ("raisedOn", baseline.raisedOn),
                              ("rationale", baseline.rationale)] {
            guard let value, !value.trimmingCharacters(in: .whitespaces).isEmpty else {
                Issue.record("棘轮基线缺 \(name) 字段 —— 抬高上限是破例动作，必须留下署名、日期与理由")
                continue
            }
            for banned in Self.bannedReasonPhrases where value.contains(banned) {
                Issue.record("棘轮基线的 \(name) 里是占位词「\(banned)」")
            }
        }
        #expect(baseline.raisedOn?.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil,
                "棘轮基线 raisedOn=\(baseline.raisedOn ?? "<缺失>") 不是 YYYY-MM-DD")
        #expect((baseline.rationale?.count ?? 0) >= 40,
                "棘轮基线 rationale 只有 \(baseline.rationale?.count ?? 0) 字符，像占位")

        let count = try Self.loadExemptions().count
        #expect(count <= maxEntries, """
        棘轮：豁免清单 \(count) 条 > 上限 \(maxEntries)。
        扩张豁免面是**破例**——要新增豁免，必须**同轮**抬高 docs/bool-exemptions-baseline.json
        的 maxEntries，并更新 raisedBy / raisedOn / rationale（理由要写清这条新豁免
        为什么过不了公约第 3 节终局条款 (b)「论证它本不该存在、走删除」）。
        """)
        #expect(count >= maxEntries, """
        棘轮 slack：豁免清单 \(count) 条 < 上限 \(maxEntries)，中间空出了 \(maxEntries - count) 个额度。
        缩小清单后**必须同轮把 maxEntries 降到新值**——留着 slack 等于给未来的新增
        留了一个**免审白名单额度**（那正是 `<=` 版本判据的真实漏洞，本条等式专门堵它）。
        棘轮的「只许缩」靠的就是这条把已释放的额度立刻收回来。
        """)

        guard let sourceSites = baseline.sourceSites else {
            Issue.record("棘轮基线缺 sourceSites 字段 —— Task 8 终审补的键碰撞棘轮无法工作")
            return
        }
        #expect(sourceSites > 0, "sourceSites=\(sourceSites) —— 零不是「很严」，是判据没配置")
        let scan = try Self.boolScan()
        #expect(scan.hits.count == sourceSites, """
        豁免键碰撞棘轮：源码里的 Bool 参数位置数 \(scan.hits.count) ≠ 基线 sourceSites \(sourceSites)。
        `keys.count` 与 `maxEntries` 的等式拦不住「新增一个 public 声明但它的键已在清单里」这种键碰撞
        ——它不增加 `keys.count`，只增加 `hits.count`。若这个数变了，请核实是否出现了新的键碰撞
        （多处源码位置共用同一个豁免键），并**同轮**更新 docs/bool-exemptions-baseline.json 的
        sourceSites（连同 raisedBy / raisedOn / rationale，与 maxEntries 走同一套破例流程）。
        """)

        for problem in Self.rationaleTargetProblems(baseline.rationale) { Issue.record("\(problem)") }
        for problem in Self.perTargetProblems(
            perTarget: baseline.perTarget,
            exemptionKeys: try Self.loadExemptions().compactMap(\.parameter),
            hits: scan.hits
        ) { Issue.record("\(problem)") }
    }

    @Test("棘轮的两颗新牙真的会开火：合成基线逐条变红自证（终审 S-e）")
    func ratchetTeethActuallyFire() {
        #expect(!Self.rationaleTargetProblems("""
        这条理由写得又长又像模像样，凑够了四十个字符以上，也换了措辞因此过得了
        scripts/bool-exemptions-ratchet.sh 的逐字比较，但它一个 target 名都没写。
        """).isEmpty, "不点名 target 的 rationale 不会红 —— 那条「必须」就仍然只是约定")
        #expect(Self.rationaleTargetProblems(
            "本次抬高来自 CoreDesignEffects 的第一个动效组件，理由写足四十字符以上。"
        ).isEmpty)
        #expect(!Self.rationaleTargetProblems(nil).isEmpty, "缺 rationale 不会红")

        func hit(_ target: String, _ owner: String) -> BoolParamHit {
            BoolParamHit(owner: owner, decl: "init", parameter: "flag",
                         file: "X.swift", line: 1, target: target)
        }
        let baseline: [String: Baseline.TargetCounts] = [
            "CoreDesign": .init(exemptions: 2, sourceSites: 2),
            "CoreDesignEffects": .init(exemptions: 0, sourceSites: 0),
            "CoreDesignCharts": .init(exemptions: 0, sourceSites: 0),
        ]
        let hedged = Self.perTargetProblems(
            perTarget: baseline,
            exemptionKeys: ["A.init#flag", "CoreDesignEffects/B.init#flag"],
            hits: [hit("CoreDesign", "A"), hit("CoreDesignEffects", "B")]
        )
        #expect(!hedged.isEmpty, """
        跨 target 对冲不会红 —— 删一个 CoreDesign 的 Bool、加一个 Effects 的，
        `maxEntries` / `sourceSites` 两个合计都不变，定义域却已经漂了。
        """)
        #expect(Self.perTargetProblems(
            perTarget: baseline,
            exemptionKeys: ["A.init#flag", "C.init#flag"],
            hits: [hit("CoreDesign", "A"), hit("CoreDesign", "C")]
        ).isEmpty)
        #expect(!Self.perTargetProblems(perTarget: nil, exemptionKeys: [], hits: []).isEmpty,
                "缺 perTarget 字段不会红 —— 跨 target 对冲会重新变成盲区")
        #expect(!Self.perTargetProblems(
            perTarget: ["CoreDesign": .init(exemptions: 0, sourceSites: 0)],
            exemptionKeys: [], hits: []
        ).isEmpty, "perTarget 少列一个 target 不会红 —— 那个 target 就有了免审额度")

        let raised = Self.perTargetProblems(
            perTarget: baseline,
            exemptionKeys: ["A.init#flag", "C.init#flag", "D.init#flag"],
            hits: [hit("CoreDesign", "A"), hit("CoreDesign", "C")]
        )
        #expect(raised.contains(where: { $0.contains("抬高") && $0.contains("破例") }),
                "抬高方向的文案没说这是破例：\(raised)")
        let lowered = Self.perTargetProblems(
            perTarget: baseline,
            exemptionKeys: ["A.init#flag"],
            hits: [hit("CoreDesign", "A"), hit("CoreDesign", "C")]
        )
        #expect(lowered.contains(where: { $0.contains("下降") && $0.contains("好方向") }),
                "下降方向仍在用「破例」口吻：\(lowered)")
        #expect(!lowered.contains(where: { $0.contains("下降") && $0.contains("连同 raisedBy") }),
                "下降方向仍在要求补署名 —— 治理掉一个豁免不是破例")
    }

    @Test("豁免宿主要么在登记表里，要么在 AD 台账里且该分类真的成立")
    func exemptionOwnersReconcileWithRegistry() throws {
        let registered = Set(
            try ComponentRegistryGuard.loadRegistry()
                .filter { $0.repo == "coredesign" }.map(\.component)
        )
        #expect(registered.count > 30, "登记表只读到 \(registered.count) 条 coredesign 条目 —— 疑似没读到")

        let scan = try ComponentRegistryGuard.componentScan()
        #expect(scan.components.count > 15, "登记表扫描器只扫到 \(scan.components.count) 个组件类型 —— 失效")

        let readmeText = try String(
            contentsOf: ComponentRegistryGuard.repoRoot.appendingPathComponent("docs/README.md"),
            encoding: .utf8
        )
        let readmeRows = ComponentRegistryGuard.readmeIndexRows(readmeText)
        #expect(readmeRows.count > 20, "README 组件索引只解析到 \(readmeRows.count) 行 —— 解析器可能失效")
        var readmeNames: Set<String> = []
        for raw in readmeRows {
            readmeNames.formUnion(ComponentRegistryGuard.candidateNames(fromReadmeCell: raw).names)
        }
        #expect(readmeNames.count > 20, "README 候选名解析失效：\(readmeRows.count) 行只聚合出 \(readmeNames.count) 个名字")

        let declaredTypeNames = try Self.declaredTypeNames()
        #expect(scan.styleImpls.count > 3,
                "扫描器只采到 \(scan.styleImpls.count) 个样式实现 —— 疑似扫描失效；下面 .nonViewPublicType 的排他条会在空集上恒真放行")
        #expect(declaredTypeNames.count > 30,
                "只扫到 \(declaredTypeNames.count) 个类型声明 —— 扫描器失效")

        var unaccounted: [String] = []
        for key in try Self.exemptedKeys() {
            let owner = Self.owner(ofExemptionKey: key)
            if registered.contains(owner) { continue }
            guard let kind = Self.ownersWithoutRegistryEntry[owner] else {
                unaccounted.append("\(key) → 宿主「\(owner)」")
                continue
            }
            _ = kind
        }

        for (owner, kind) in Self.ownersWithoutRegistryEntry {
            Self.assertOwnerClassification(
                owner: owner, kind: kind, scan: scan,
                declaredTypeNames: declaredTypeNames, readmeNames: readmeNames
            )
        }
        let unaccountedMessage = """
        这些豁免的宿主既不在 component-registry.json 里，也不在 ownersWithoutRegistryEntry 台账里：
        \(unaccounted.sorted().joined(separator: "\n"))
        —— 39.md 最后一条 AC 的收窄版（见 39-plan.md）：宿主可以没有登记表条目，
        但必须写明是哪一条 AD 裁决让它没有，并让那条裁决在这里被真的核对一遍。
        """
        #expect(unaccounted.isEmpty, "\(unaccountedMessage)")

        let nowRegistered = Set(Self.ownersWithoutRegistryEntry.keys).intersection(registered)
        #expect(nowRegistered.isEmpty,
                "这些宿主已经进了登记表，该从 ownersWithoutRegistryEntry 移走：\(nowRegistered.sorted())")
    }
}

private nonisolated final class DeclaredTypeNameCollector: SyntaxVisitor {
    var names: Set<String> = []

    init() { super.init(viewMode: .sourceAccurate) }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        self.names.insert(node.name.text)
        return .visitChildren
    }
    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        self.names.insert(node.name.text)
        return .visitChildren
    }
    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        self.names.insert(node.name.text)
        return .visitChildren
    }
    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        self.names.insert(node.name.text)
        return .visitChildren
    }
    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        self.names.insert(node.name.text)
        return .visitChildren
    }
}
