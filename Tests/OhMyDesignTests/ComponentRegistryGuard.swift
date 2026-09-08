import Foundation
import SwiftParser
import SwiftSyntax
import Testing

func compareRegistryToScan(scanned: Set<String>, registered: Set<String>) -> (missing: Set<String>, ghosts: Set<String>) {
    (missing: scanned.subtracting(registered), ghosts: registered.subtracting(scanned))
}

@Suite("组件登记表")
struct ComponentRegistryGuard {
    struct Entry: Codable {
        let component: String
        let repo: String
        let kind: String
        let decidedBy: String
        let nativeProtocol: String?
        let customStyleProtocol: String?
        let styleSlot: String?
        let styleEnum: String?
        let needsExtensionPoint: Bool
        let textParams: [TextParam]
        let notes: String

        func withDecidedBy(_ value: String) -> Entry {
            Entry(
                component: self.component, repo: self.repo, kind: self.kind, decidedBy: value,
                nativeProtocol: self.nativeProtocol, customStyleProtocol: self.customStyleProtocol,
                styleSlot: self.styleSlot, styleEnum: self.styleEnum,
                needsExtensionPoint: self.needsExtensionPoint,
                textParams: self.textParams, notes: self.notes
            )
        }
    }
    struct TextParam: Codable { let name: String; let category: String }

    static let validKinds: Set<String> = ["semantic", "prescriptive", "excluded"]
    static let validDecidedBy: Set<String> = [
        "step1", "step2", "step3", "tiebreaker", "precedent",
        "exclusion",
        "pendingStep2",
    ]
    static let validCategories: Set<String> = ["A", "B", "C", "by-type"]
    static let validRepos: Set<String> = ["ohmydesign", "storyui"]

    static let expectedKindForDecidedBy: [String: String] = [
        "step1": "semantic",
        "step2": "semantic",
        "step3": "prescriptive",
        "tiebreaker": "prescriptive",
        "precedent": "semantic",
        "pendingStep2": "prescriptive",
    ]

    // MARK: - 缓办台账：步骤 2 枚举未完成的条目（PR #297 终审 I-2）

    static let pendingStep2FollowUpIssue: String? = nil

    static let knownPendingStep2Enumeration: Set<String> = []

    static func pendingStep2Components(in entries: [Entry]) -> Set<String> {
        Set(entries.filter { $0.decidedBy == "pendingStep2" }.map(\.component))
    }

    static let knownOffScannerComponents: Set<String> = ["Toast"]

    // MARK: - README 索引 ↔ 登记表对账（终审第 2 轮 I1）

    static let knownReadmeTombstones: Set<String> = ["Typography", "EmptyState"]

    static let knownExcludedReadmeRows: Set<String> = ["FlowLayout"]

    static let knownStyleAnnotationRows: [String: Set<String>] = [
        "Button": ["SolidButtonStyle", "LightButtonStyle", "CoreBorderlessButtonStyle"],
        "FloatButton": ["ExtendedFloatButtonStyle", "CircularGlassButtonStyle"],
        ".core Control Styles": [
            "CoreProgressViewStyle", "CoreLabelStyle", "CoreDisclosureGroupStyle", "CoreLabeledContentStyle",
        ],
    ]

    static let knownReadmeAuxiliaryNames: Set<String> = ["RadioOption"]

    static let knownReadmeAliases: [String: String] = ["spinning": "SpinningModifier"]

    static let knownReadmeEntryPointRows: [String: String] = [
        "Confetti": "confetti",
        "ParticleTransition": "particle",
    ]

    static let knownReadmeContainerPrefixes: [String: String] = ["Sidebar": "Sidebar"]

    // MARK: - README 行 → 登记条目的聚合映射（`#48` G-3）

    static let readmeCoverageStructuralExemptions: [String: Set<String>] = [
        "Button": ["AsyncButton"],
        "FloatButton": ["FloatingGlassModifier", "TelegramGlassButtonModifier"],
    ]

    static let readmeRowCoverage: [String: (entries: Set<String>, reason: String)] = [
        "Sidebar": (
            ["SidebarSection", "SidebarNavigationRow", "SidebarUtilityRow",
             "SidebarDocumentRow", "SidebarTagRow", "SidebarStatusFooter"],
            "Sidebar 行覆盖全部子行；子行不单列索引"
        ),
        "SettingsRow": (
            ["SettingsRow", "SettingsRowChevron"],
            "SettingsRow 行覆盖它的内部部件 SettingsRowChevron"
        ),
        "Button": (
            ["AsyncButton"],
            "Button 行覆盖 AsyncButton（同一按钮族的异步变体）"
        ),
        "spinning": (
            ["SpinningModifier"],
            "README 行名是 modifier 的调用名 spinning，与类型名 SpinningModifier 大小写/后缀均不同，必须显式映射"
        ),
        "shine": (
            ["Shine"],
            "shine.md 同时收录 View.shine 修饰符与容器形态 Shine，README 按入口点名列行，容器类型挂在同一行下"
        ),
        "Skeleton": (
            ["SkeletonLine", "SkeletonRect", "SkeletonCircle"],
            "三种骨架形状写在 Skeleton 行的括号里，而解析器在首个括号处截断、不递归解析括号内容"
        ),
        "FloatButton": (
            ["FloatingGlassModifier", "TelegramGlassButtonModifier"],
            "两个 modifier 服务于 FloatButton 行展示的浮动按钮外观，不单列索引"
        ),
    ]

    static func candidateNames(fromReadmeCell raw: String) -> (names: [String], isTombstone: Bool) {
        let isTombstone = raw.contains("~~")
        var s = raw.replacingOccurrences(of: "~~", with: "")
        s = s.replacingOccurrences(of: "`", with: "")
        let parenChars: Set<Character> = ["（", "("]
        if let idx = s.firstIndex(where: { parenChars.contains($0) }) {
            s = String(s[s.startIndex..<idx])
        }
        let names = s.split(separator: "/")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return (names, isTombstone)
    }

    static func resolveReadmeCandidate(
        _ name: String, isTombstone: Bool, registered: Set<String>, styleImpls: Set<String>,
        entryPointMembers: Set<String>
    ) -> Bool {
        if registered.contains(name) { return true }
        if isTombstone { return Self.knownReadmeTombstones.contains(name) }
        if entryPointMembers.contains(name) { return true }
        if let member = Self.knownReadmeEntryPointRows[name] { return entryPointMembers.contains(member) }
        if Self.knownExcludedReadmeRows.contains(name) { return true }
        if let required = Self.knownStyleAnnotationRows[name] {
            return required.isSubset(of: styleImpls)
        }
        if let coverage = Self.readmeRowCoverage[name] {
            return coverage.entries.allSatisfy { registered.contains($0) }
        }
        if Self.knownReadmeAuxiliaryNames.contains(name) { return true }
        if let alias = Self.knownReadmeAliases[name] { return registered.contains(alias) }
        if let prefix = Self.knownReadmeContainerPrefixes[name] {
            return registered.contains(where: { $0.hasPrefix(prefix) })
        }
        return false
    }

    static let readmeIndexSections: [(start: String, end: String)] = [
        (start: "## 组件索引", end: "## 生成预览图"),
        (start: "## 动效与图表索引", end: "## NFR-1 帧率基准"),
    ]

    static func readmeIndexRows(_ text: String) -> [String] {
        var out: [String] = []
        for section in Self.readmeIndexSections {
            guard let range = Self.readmeSectionRange(in: text, section) else { continue }
            out += Self.tableFirstCells(in: text[range])
        }
        return out
    }

    static func readmeSectionRange(
        in text: String, _ section: (start: String, end: String)
    ) -> Range<String.Index>? {
        guard let start = text.range(of: "\n" + section.start) else { return nil }
        let end = text.range(
            of: "\n" + section.end, range: start.upperBound..<text.endIndex
        )?.lowerBound ?? text.endIndex
        return start.upperBound..<end
    }

    static func tableFirstCells(in section: Substring) -> [String] {
        func firstCell(_ line: Substring) -> String? {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("|") else { return nil }
            let cells = trimmed.split(separator: "|", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard cells.count > 1 else { return nil }
            let first = cells[1]
            return first.isEmpty ? nil : first
        }
        func isSeparator(_ cell: String) -> Bool {
            !cell.isEmpty && cell.allSatisfy { $0 == "-" || $0 == ":" }
        }

        let cells = section.split(separator: "\n", omittingEmptySubsequences: true).map(firstCell)
        var out: [String] = []
        for (index, cell) in cells.enumerated() {
            guard let cell else { continue }
            if isSeparator(cell) { continue }
            let next = index + 1 < cells.count ? cells[index + 1] : nil
            if let next, isSeparator(next) { continue }
            out.append(cell)
        }
        return out
    }

    static var repoRoot: URL { GuardScanRoots.repoRoot }

    static var componentScanRoots: [(target: String, url: URL)] { GuardScanRoots.allRoots }
    static var registryURL: URL { repoRoot.appendingPathComponent("docs/component-registry.json") }

    struct EntryPoint: Codable {
        let target: String
        let host: String
        let member: String
        let notes: String
    }

    struct RegistryFile: Codable {
        let components: [Entry]
        let entryPoints: [EntryPoint]
    }

    static func loadRegistryFile() throws -> RegistryFile {
        try JSONDecoder().decode(RegistryFile.self, from: Data(contentsOf: registryURL))
    }

    static func loadRegistry() throws -> [Entry] {
        try Self.loadRegistryFile().components
    }

    static func loadEntryPoints() throws -> [EntryPoint] {
        try Self.loadRegistryFile().entryPoints
    }

    struct ScanResult {
        var components: Set<String> = []
        var styleImpls: Set<String> = []
        var entryPoints: Set<String> = []
    }

    private static var cachedComponentScan: ScanResult?

    static func componentScan() throws -> ScanResult {
        if let cached = Self.cachedComponentScan { return cached }
        let result = try Self.scanTypes(roots: Self.componentScanRoots)
        if !result.components.isEmpty { Self.cachedComponentScan = result }
        return result
    }

    static func scanTypes(roots: [(target: String, url: URL)]) throws -> ScanResult {
        var result = ScanResult()
        for (_, one) in try Self.scanTypesByTarget(roots: roots) {
            result.components.formUnion(one.components)
            result.styleImpls.formUnion(one.styleImpls)
            result.entryPoints.formUnion(one.entryPoints)
        }
        return result
    }

    static func scanTypesByTarget(
        roots: [(target: String, url: URL)],
        sourceLocation: Testing.SourceLocation = #_sourceLocation
    ) throws -> [(target: String, scan: ScanResult)] {
        GuardScanRoots.assertRootsExist(roots)
        let out = try roots.map { ($0.target, try Self.scanTypes(root: $0.url)) }
        for (target, scan) in out where scan.components.isEmpty {
            Issue.record(
                "扫描根 \(target) 一个 public 组件类型都没采到 —— 多根扫描最常见的假绿就是新根静默产出空集，这不是「零违规」",
                sourceLocation: sourceLocation
            )
        }
        return out
    }

    static func scanTypes(root: URL) throws -> ScanResult {
        guard FileManager.default.fileExists(atPath: root.path) else {
            Issue.record("源码路径不存在：\(root.path) —— 判据无法工作，这不是「零违规」")
            return ScanResult()
        }
        var result = ScanResult()
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            Issue.record("无法枚举源码目录：\(root.path)（权限或 IO 异常）—— 判据无法工作，这不是「零违规」")
            return ScanResult()
        }
        for case let url as URL in walker
        where url.pathExtension == "swift" {
            let tree = SwiftParser.Parser.parse(source: try String(contentsOf: url, encoding: .utf8))
            if tree.hasError {
                let site = root.lastPathComponent + "/" + GuardScanRoots.relativePath(url, from: root)
                Issue.record("解析出错：\(site) —— swift-syntax major 可能与工具链不配套")
            }
            let c = PublicTypeCollector()
            c.walk(tree)
            result.components.formUnion(c.components)
            result.styleImpls.formUnion(c.styleImpls)
            result.entryPoints.formUnion(c.entryPoints)
        }
        return result
    }

    @Test("登记表每条含全部必需字段，且取值在允许域内")
    func registrySchemaIsValid() throws {
        let entries = try Self.loadRegistry()
        #expect(entries.count >= 4, "登记表只有 \(entries.count) 条 —— 疑似没读到或是空壳")

        #expect(Set(entries.map(\.component)).count == entries.count,
                "登记表存在重名 component 条目——差集判据会把重名静默吞掉")

        #expect(entries.filter { $0.repo == "ohmydesign" }.count == 62,
                "OhMyDesign 侧条目数不是 62（#270 扩扫描根到三个 target，Effects 11 + Charts 4 共 15 条按判定法补录后由 47 变为 62）——若为新增属预期变化请同步改这个数字；若无源码变更条目却变了，是静默删条目/改 repo 的信号")
        #expect(entries.filter { $0.repo == "storyui" }.count == 25,
                "StoryUI 侧条目数不是 25——CI 无法跨仓核对源码，这条固定计数断言是 #43 落地前唯一挡「静默删条目」的机器判据，不得放宽为 print")

        for e in entries where e.decidedBy != "exclusion" {
            if let expected = Self.expectedKindForDecidedBy[e.decidedBy] {
                #expect(e.kind == expected,
                        "\(e.component)：decidedBy=\(e.decidedBy) 按公约必须 kind=\(expected)，实际是 \(e.kind)")
            }
        }

        let m1SyncMessage = """
        validDecidedBy 与 expectedKindForDecidedBy 不同步——新增 decidedBy 取值必须同步\
        加进 expectedKindForDecidedBy（除非它和 exclusion 一样另有专门断言），否则 M1\
        判据对新取值静默无声
        """
        #expect(Set(Self.expectedKindForDecidedBy.keys).union(["exclusion"]) == Self.validDecidedBy,
                "\(m1SyncMessage)")

        let pendingStep2 = Self.pendingStep2Components(in: entries)
        #expect(pendingStep2 == Self.knownPendingStep2Enumeration, """
        `decidedBy: pendingStep2` 的条目集合变了：实际 \(pendingStep2.sorted())，        已知 \(Self.knownPendingStep2Enumeration.sorted())。
        `pendingStep2` 的含义是「公约步骤 2 的候选枚举与来源核验尚未完成，本条不声称任何出口，        按可逆的一侧（prescriptive / 不给扩展点）缓办登记」——它是**台账**，不是判定结论。
        · 变小：若某条真的补完了枚举，落点应改成 step1/step2/step3/tiebreaker 之一，        并同步从本表移除；若只是把标记删掉，那是把缓办伪装成已判。
        · 变大：又出现了一条跳过枚举的条目 —— 须在 notes 里写明成因，并挂进一个**尚未关闭**的承接 issue        （`pendingStep2FollowUpIssue`，`#315` 终审 I-6 后为 nil，须当轮显式指定；`#299` 将随 PR #315 关闭，不得复用）。
        """)

        for e in entries where e.decidedBy == "pendingStep2" {
            guard let followUp = Self.pendingStep2FollowUpIssue else {
                Issue.record("""
                出现了 pendingStep2 条目 \(e.component)，但 pendingStep2FollowUpIssue 仍是 nil。                缓办必须挂在一个**尚未关闭**的承接 issue 上 —— 请先把该常量改成本轮的 issue 号                （⚠️ `#299` 将随 PR #315 关闭，不得复用），再挂条目。
                """)
                continue
            }
            #expect(e.notes.contains(followUp), """
            \(e.component) 是 pendingStep2 条目，但 notes 里没有承接 issue 号 \(followUp)             —— 缓办没有落点等于永久缓办
            """)
        }

        for e in entries {
            #expect(Self.validKinds.contains(e.kind), "\(e.component) kind=\(e.kind) 不在允许域")
            #expect(Self.validDecidedBy.contains(e.decidedBy), "\(e.component) decidedBy=\(e.decidedBy) 不在允许域")
            #expect(Self.validRepos.contains(e.repo), "\(e.component) repo=\(e.repo) 不在允许域")
            for tp in e.textParams {
                #expect(Self.validCategories.contains(tp.category),
                        "\(e.component).\(tp.name) category=\(tp.category) 不在允许域")
            }
            #expect(e.notes.count >= 10, "\(e.component) 的 notes 只有 \(e.notes.count) 字符，像占位")
            if e.kind == "prescriptive" {
                #expect(!e.needsExtensionPoint, "\(e.component) 判为 prescriptive 却要扩展点 —— 自相矛盾")
            }
            if e.kind == "excluded" {
                #expect(!e.needsExtensionPoint, "\(e.component) 已弃用却要扩展点 —— 自相矛盾")
            }
            #expect((e.kind == "excluded") == (e.decidedBy == "exclusion"),
                    "\(e.component)：kind=excluded 与 decidedBy=exclusion 必须同时成立")
            #expect(!(e.nativeProtocol != nil && e.customStyleProtocol != nil),
                    "\(e.component) 同时标了原生协议与自有协议 —— 正是 J-3 要禁的形态")
            let extensionPointFields = [
                e.nativeProtocol, e.customStyleProtocol, e.styleSlot, e.styleEnum,
            ].compactMap { $0 }
            #expect(
                extensionPointFields.count <= 1,
                """
                \(e.component) 同时标了 \(extensionPointFields.count) 个扩展点字段\
                （nativeProtocol / customStyleProtocol / styleSlot / styleEnum 至多填一个）\
                 —— J-2 只会按判定链的第一个裁决，其余通路静默略过
                """
            )
            if e.kind == "semantic" {
                #expect(e.needsExtensionPoint, "\(e.component) 判为 semantic 却不给扩展点 —— 自相矛盾")
            }
            if e.decidedBy == "step1" {
                #expect(e.nativeProtocol != nil, "\(e.component) decidedBy=step1 却没填 nativeProtocol")
            }
            if e.decidedBy == "precedent" {
                #expect(e.customStyleProtocol != nil, "\(e.component) decidedBy=precedent 却没填 customStyleProtocol")
            }
        }
    }

    @Test("`pendingStep2` 台账承重：删一条标记判红、加一条未登记的标记也判红")
    func pendingStep2LedgerIsLoadBearing() throws {
        let entries = try Self.loadRegistry()
        let known = Self.knownPendingStep2Enumeration

        #expect(Self.pendingStep2Components(in: entries) == known, "基线不成立，下面的变异证明不了任何事")

        let fixtureKnown: Set<String> = ["FixturePendingA", "FixturePendingB"]
        let fixtureEntries = [
            Self.pendingStep2Fixture(component: "FixturePendingA", decidedBy: "pendingStep2"),
            Self.pendingStep2Fixture(component: "FixturePendingB", decidedBy: "pendingStep2"),
            Self.pendingStep2Fixture(component: "FixtureSettledC", decidedBy: "tiebreaker"),
        ]
        #expect(Self.pendingStep2Components(in: fixtureEntries) == fixtureKnown,
                "合成夹具自身的基线就不成立 —— 纯函数 pendingStep2Components 已失效")

        let markerRemoved = fixtureEntries.map { e -> Entry in
            e.component == "FixturePendingA" ? e.withDecidedBy("tiebreaker") : e
        }
        #expect(Self.pendingStep2Components(in: markerRemoved) != fixtureKnown, """
        把 FixturePendingA 的 pendingStep2 标记改回 tiebreaker 之后集合竟然没变 —— \
        双侧等式的「缩小」方向失效，缓办可以被静默说成已判
        """)

        let intruder = try #require(entries.first { $0.decidedBy == "tiebreaker" && !known.contains($0.component) })
        let markerAdded = entries.map { e -> Entry in
            e.component == intruder.component ? e.withDecidedBy("pendingStep2") : e
        }
        #expect(Self.pendingStep2Components(in: markerAdded) != known, """
        把 \(intruder.component) 改成 pendingStep2 之后集合竟然没变 —— \
        双侧等式的「增大」方向失效，新的跳过枚举条目可以不过评审就落盘
        """)
    }

    static func pendingStep2Fixture(component: String, decidedBy: String) -> Entry {
        Entry(
            component: component, repo: "ohmydesign", kind: "prescriptive", decidedBy: decidedBy,
            nativeProtocol: nil, customStyleProtocol: nil, styleSlot: nil, styleEnum: nil,
            needsExtensionPoint: false, textParams: [],
            notes: "合成夹具，不是真实条目"
        )
    }

    @Test("扫描器真的扫到了三个 target 的类型，且类型名跨 target 不重名")
    func scannerFindsComponentTypes() throws {
        let r = try Self.componentScan()
        #expect(r.components.count > 15, "只扫到 \(r.components.count) 个组件类型 —— 扫描器失效")
        #expect(r.styleImpls.count > 5, "只扫到 \(r.styleImpls.count) 个 Style 实现 —— 协议清单可能又漏了")
        print("组件 \(r.components.count) 个：\(r.components.sorted())")
        print("Style 实现 \(r.styleImpls.count) 个：\(r.styleImpls.sorted())")

        let byTarget = try Self.scanTypesByTarget(roots: Self.componentScanRoots)
        #expect(byTarget.count == GuardScanRoots.targetNames.count,
                "逐 target 扫描只回来 \(byTarget.count) 组，根列表有 \(GuardScanRoots.targetNames.count) 个")
        for (target, scan) in byTarget {
            print("· \(target)：组件 \(scan.components.count) 个 \(scan.components.sorted())"
                  + "；Style 实现 \(scan.styleImpls.count) 个；入口点 \(scan.entryPoints.count) 个")
            #expect(!scan.components.isEmpty,
                    "扫描根 \(target) 一个组件类型都没采到 —— 多根扫描最常见的假绿就是新根静默产出空集")
        }

        func collisions(in bucket: (ScanResult) -> Set<String>) -> [String] {
            var seenIn: [String: String] = [:]
            var out: [String] = []
            for (target, scan) in byTarget {
                for name in bucket(scan).sorted() {
                    if let previous = seenIn[name] {
                        out.append("\(name)（\(previous) 与 \(target)）")
                    } else {
                        seenIn[name] = target
                    }
                }
            }
            return out
        }
        let buckets: [(name: String, get: (ScanResult) -> Set<String>, why: String)] = [
            ("components", { $0.components },
             "登记表按**名字**对账（`Entry` 无 target 字段）⇒ 一条登记就能同时满足双向差集的两个方向，「少登记一条」不会红"),
            ("styleImpls", { $0.styleImpls },
             "`knownStyleAnnotationRows` 用它判 README 行的归宿 ⇒ 一个 target 里的 style 实现能替另一个 target 的同名行放行"),
            ("entryPoints", { $0.entryPoints },
             "README 的入口点桶与 `knownReadmeEntryPointRows` 都按 `Host.member` 比对 ⇒ 一个 target 的入口点能替另一个 target 的同名行放行"),
        ]
        for bucket in buckets {
            let found = collisions(in: bucket.get)
            #expect(found.isEmpty, """
            `ScanResult.\(bucket.name)` 里这些名字在两个 target 里同时出现：\(found)。
            合并成一个 Set 之后它们会**塌成一条**，而 \(bucket.why)。
            处置：给其中一个改名，或把对应的索引改成按 (target, name) 建 ——
            **不要**为了让本条变绿把它删掉。
            """)
        }
    }

    @Test("OhMyDesign 侧：登记表覆盖全部组件类型，且无幽灵条目")
    func registryCoversOhMyDesignTypes() throws {
        let entries = try Self.loadRegistry()
        let scanned = try Self.componentScan().components
        #expect(scanned.count > 15, "只扫到 \(scanned.count) 个类型 —— 扫描器失效")

        let registered = Set(entries.filter { $0.repo == "ohmydesign" }.map(\.component))
            .subtracting(Self.knownOffScannerComponents)

        let diff = compareRegistryToScan(scanned: scanned, registered: registered)
        #expect(diff.missing.isEmpty,
                "这些 OhMyDesign 类型在源码里但登记表没有：\(diff.missing.sorted())")
        #expect(diff.ghosts.isEmpty,
                "登记表有幽灵条目（OhMyDesign 源码里找不到）：\(diff.ghosts.sorted())")

        let n = entries.filter { $0.repo == "storyui" }.count
        print("⚠️ StoryUI 侧 \(n) 条未做源码比对——CI 只 checkout 本仓；「源码新增组件而没登记」在 #43 落地前无机器拦截。")

        let registeredOhMyDesign = Set(entries.filter { $0.repo == "ohmydesign" }.map(\.component))
        #expect(Self.knownOffScannerComponents.isSubset(of: registeredOhMyDesign),
                "knownOffScannerComponents 里有条目不在登记表里，白名单本身失去了豁免对象")
        let m2ExpiredMessage = """
        白名单条目已经能被扫描器看到 ⇒ 该移出 knownOffScannerComponents，\
        否则将来扫描器能力扩展、真扫到它时，判据不会提醒你这条豁免已经过期
        """
        #expect(scanned.isDisjoint(with: Self.knownOffScannerComponents), "\(m2ExpiredMessage)")
    }

    @Test("README 组件索引每个候选名都有归宿：登记表 / styleImpls（须真的扫到）/ 墓碑 / 排除 / **聚合映射** / 辅助类型 / 别名与容器前缀（守卫绿态下不可达）")
    func readmeIndexReconcilesWithRegistry() throws {
        let entries = try Self.loadRegistry()
        let registered = Set(entries.filter { $0.repo == "ohmydesign" }.map(\.component))
        let scan = try Self.componentScan()
        let scanned = scan.components

        let readmeText = try String(
            contentsOf: Self.repoRoot.appendingPathComponent("docs/README.md"), encoding: .utf8
        )
        let rows = Self.readmeIndexRows(readmeText)
        let parseFailureMessage = """
        README 组件索引只解析到 \(rows.count) 行 —— 解析器可能失效，不是真的「组件索引缩水了」
        """
        #expect(rows.count > 20, "\(parseFailureMessage)")

        let entryPointMembers = Set(try Self.loadEntryPoints().map(\.member))
        #expect(entryPointMembers.count > 20,
                "登记表只读到 \(entryPointMembers.count) 个入口点成员 —— 疑似解析失效，入口点桶会在空集上把整节判红")

        var unresolved: [String] = []
        for raw in rows {
            let (names, isTombstone) = Self.candidateNames(fromReadmeCell: raw)
            for name in names
            where !Self.resolveReadmeCandidate(
                name, isTombstone: isTombstone, registered: registered,
                styleImpls: scan.styleImpls, entryPointMembers: entryPointMembers
            ) {
                unresolved.append("「\(raw)」→ 「\(name)」")
            }
        }
        let unresolvedMessage = """
        README 组件索引里这些候选名，既不在登记表也不在任何已知豁免清单（墓碑 / 排除 / \
        style 注记 / 辅助类型 / 别名 / 容器前缀）里，是本判据存在的理由——正是这类「新增 \
        README 行但没登记」曾经放过 Toast / BottomInputBar：\n\(unresolved.joined(separator: "\n"))
        """
        #expect(unresolved.isEmpty, "\(unresolvedMessage)")

        let resurrectedTombstones = Self.knownReadmeTombstones.intersection(scanned)
        let tombstoneMessage = """
        这些墓碑组件在源码里又出现了，需要回填登记表并把名字从 knownReadmeTombstones \
        移走：\(resurrectedTombstones.sorted())
        """
        #expect(resurrectedTombstones.isEmpty, "\(tombstoneMessage)")
        let resurrectedExclusions = Self.knownExcludedReadmeRows.intersection(scanned)
        #expect(resurrectedExclusions.isEmpty,
                "这些排除项在源码里被扫描器采集到了，需要重新裁决是否登记：\(resurrectedExclusions.sorted())")
    }

    // MARK: - `#48` G-3：反向对账 + 快照存在性 + 映射表自洽

    @Test("反向：每个非 excluded 的 ohmydesign 条目都被 README 索引覆盖")
    func registryEntriesAreCoveredByReadme() throws {
        let entries = try Self.loadRegistry()
        let targets = entries.filter { $0.repo == "ohmydesign" && $0.kind != "excluded" }
        #expect(targets.count > 30, "只读到 \(targets.count) 条非 excluded 的 ohmydesign 条目 —— 疑似解析失效")

        let readmeText = try String(
            contentsOf: Self.repoRoot.appendingPathComponent("docs/README.md"), encoding: .utf8
        )
        let rows = Self.readmeIndexRows(readmeText)
        #expect(rows.count > 20, "README 组件索引只解析到 \(rows.count) 行 —— 解析器可能失效")

        var covered: Set<String> = []
        for raw in rows {
            let (names, _) = Self.candidateNames(fromReadmeCell: raw)
            covered.formUnion(names)
            for name in names {
                if let coverage = Self.readmeRowCoverage[name] { covered.formUnion(coverage.entries) }
            }
        }

        let missing = targets.map(\.component).filter { !covered.contains($0) }.sorted()
        #expect(missing.isEmpty, """
        这些登记条目在 README 组件索引里**没有任何行覆盖**：\(missing)
        —— 索引缺行此前不会红（G-3 的单向缺口）。要么给它补索引行，要么在
        `readmeRowCoverage` 里挂到某条已有行下并写明理由。
        """)
    }

    @Test("README 索引引用的快照 PNG 必须真的存在")
    func readmeSnapshotsExist() throws {
        let readmeText = try String(
            contentsOf: Self.repoRoot.appendingPathComponent("docs/README.md"), encoding: .utf8
        )
        var refs: [String] = []
        var rest = Substring(readmeText)
        while let open = rest.range(of: "src=\"snapshots/") {
            let after = rest[open.upperBound...]
            guard let close = after.range(of: "\"") else { break }
            refs.append(String(after[..<close.lowerBound]))
            rest = after[close.upperBound...]
        }
        #expect(refs.count > 20, "README 里只解析到 \(refs.count) 个快照引用 —— 解析器可能失效")

        let dir = Self.repoRoot.appendingPathComponent("docs/snapshots")
        let actual = Set(
            (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        )
        #expect(actual.count > 20, "docs/snapshots 只枚举到 \(actual.count) 个文件 —— 疑似路径错，本断言会在空集上把所有引用判红")
        let missing = refs.filter { !actual.contains($0) }.sorted()
        #expect(missing.isEmpty, "README 索引引用了不存在的快照（**区分大小写**）：\(missing)")
    }

    @Test("覆盖事实的单一来源：prefix / alias 表能推出的覆盖，coverage 表必须已经包含")
    func coverageTableIsTheSingleSourceOfTruth() throws {
        let entries = try Self.loadRegistry()
        let targets = entries.filter { $0.repo == "ohmydesign" && $0.kind != "excluded" }.map(\.component)
        #expect(!targets.isEmpty, "registry 解析为空 —— 本守卫会在空集上恒真")

        for (rowName, prefix) in Self.knownReadmeContainerPrefixes {
            let derived = Set(targets.filter { $0.hasPrefix(prefix) })
            let declared = Self.readmeRowCoverage[rowName]?.entries ?? []
            let missing = derived.subtracting(declared).sorted()
            #expect(missing.isEmpty, """
            `knownReadmeContainerPrefixes["\(rowName)"]` 能推出 \(missing) 被覆盖，            但 `readmeRowCoverage["\(rowName)"]` 里没有它们 —— 两张表已漂移。            覆盖事实必须以 coverage 表为准；prefix 表只是正向的 fallback。
            """)
        }
        for (rowName, alias) in Self.knownReadmeAliases {
            let declared = Self.readmeRowCoverage[rowName]?.entries ?? []
            #expect(declared.contains(alias), """
            `knownReadmeAliases["\(rowName)"] = "\(alias)"`，但             `readmeRowCoverage["\(rowName)"]` 里没有它 —— 两张表已漂移。
            """)
        }
    }

    @Test("两个 README 索引小节都真的解析出了行（`#270`：定义域扩了要有活证据）")
    func readmeIndexSectionsAllParse() throws {
        let readmeText = try String(
            contentsOf: Self.repoRoot.appendingPathComponent("docs/README.md"), encoding: .utf8
        )
        for section in Self.readmeIndexSections {
            guard let range = Self.readmeSectionRange(in: readmeText, section) else {
                Issue.record("README 里找不到行首小节标题「\(section.start)」—— 该节的行整段掉出定义域，判据对它恒真")
                continue
            }
            #expect(readmeText.range(
                        of: "\n" + section.end, range: range.lowerBound..<readmeText.endIndex
                    ) != nil,
                    "README 里「\(section.start)」之后找不到行首终止标题「\(section.end)」—— 解析范围会一路吃到文末")
            let rows = Self.tableFirstCells(in: readmeText[range])
            #expect(rows.count > 10,
                    "README 小节「\(section.start)」只解析到 \(rows.count) 行 —— 解析器或标题文案可能失效")
            #expect(!rows.contains("组件") && !rows.contains("单位"),
                    "小节「\(section.start)」的表头行没被剔除：\(rows.filter { $0 == "组件" || $0 == "单位" })")
        }
    }

    @Test("`knownReadmeEntryPointRows` 承重：两条映射都真的被用到，且都不是多余的")
    func readmeEntryPointRowsAreLoadBearing() throws {
        let entries = try Self.loadRegistry()
        let registered = Set(entries.filter { $0.repo == "ohmydesign" }.map(\.component))
        let entryPointMembers = Set(try Self.loadEntryPoints().map(\.member))
        let readmeText = try String(
            contentsOf: Self.repoRoot.appendingPathComponent("docs/README.md"), encoding: .utf8
        )
        let rowNames = Set(Self.readmeIndexRows(readmeText).flatMap { Self.candidateNames(fromReadmeCell: $0).names })

        #expect(!Self.knownReadmeEntryPointRows.isEmpty, "映射表为空 —— 本守卫会在空循环上恒真")
        #expect(!rowNames.isEmpty, "README 行名解析为空 —— 第 ① 条会恒假、其余恒真")
        #expect(entryPointMembers.count > 20, "登记表只读到 \(entryPointMembers.count) 个入口点成员 —— 疑似解析失效")

        for (rowName, member) in Self.knownReadmeEntryPointRows.sorted(by: { $0.key < $1.key }) {
            #expect(rowNames.contains(rowName),
                    "`knownReadmeEntryPointRows` 的 key「\(rowName)」不是 README 索引里的行名 —— 悬空键")
            #expect(entryPointMembers.contains(member),
                    "`knownReadmeEntryPointRows[\(rowName)]` 指向的入口点成员「\(member)」不在登记表的 entryPoints 里")
            #expect(!registered.contains(rowName) && !entryPointMembers.contains(rowName),
                    "`knownReadmeEntryPointRows` 的 key「\(rowName)」不用映射也能解析（它本身就是登记条目名或入口点成员名）—— 这条是死代码，删掉")
        }
    }

    @Test("`readmeRowCoverage` 自洽：key 真在 README、value 真是条目、理由不是空话")
    func readmeRowCoverageIsSelfConsistent() throws {
        let entries = try Self.loadRegistry()
        let known = Set(entries.map(\.component))
        let readmeText = try String(
            contentsOf: Self.repoRoot.appendingPathComponent("docs/README.md"), encoding: .utf8
        )
        let rowNames = Set(Self.readmeIndexRows(readmeText).flatMap { Self.candidateNames(fromReadmeCell: $0).names })

        #expect(!Self.readmeRowCoverage.isEmpty, "readmeRowCoverage 为空 —— 本守卫会在空循环上恒真")
        #expect(!rowNames.isEmpty, "README 行名解析为空 —— 第 ① 条会恒假、其余恒真")

        for (key, coverage) in Self.readmeRowCoverage.sorted(by: { $0.key < $1.key }) {
            #expect(rowNames.contains(key),
                    "`readmeRowCoverage` 的 key「\(key)」不是 README 组件索引里的行名 —— 悬空键")
            for entry in coverage.entries.sorted() {
                #expect(known.contains(entry),
                        "`readmeRowCoverage[\(key)]` 里的「\(entry)」不是 component-registry.json 的条目 —— 挂了个不存在的名字")
            }
            #expect(!coverage.entries.isEmpty, "`readmeRowCoverage[\(key)]` 的覆盖集合为空 —— 删掉它")
            let lowered = coverage.reason.lowercased()
            let banned = BoolExemptionGuard.bannedReasonPhrases.filter { lowered.contains($0.lowercased()) }
            #expect(banned.isEmpty,
                    "`readmeRowCoverage[\(key)]` 的理由命中空话词 \(banned)：「\(coverage.reason)」—— 「显式理由」这条通道不接空话拦截的话，映射表就还剩一条『写句空话就挂进去』的窄缝")
            #expect(coverage.reason.count >= 8, "`readmeRowCoverage[\(key)]` 的理由太短：「\(coverage.reason)」")
            for entry in coverage.entries.sorted() {
                let lowerKey = key.lowercased()
                let lowerEntry = entry.lowercased()
                let stripped = ["modifier", "style", "view"].reduce(lowerEntry) { acc, suffix in
                    acc.hasSuffix(suffix) ? String(acc.dropLast(suffix.count)) : acc
                }
                let related = lowerEntry.hasPrefix(lowerKey)
                    || lowerKey.hasPrefix(lowerEntry)
                    || stripped == lowerKey
                    || Self.readmeCoverageStructuralExemptions[key]?.contains(entry) == true
                #expect(related, """
                `readmeRowCoverage[\(key)]` 挂了「\(entry)」，但两者**没有结构关系**                 （既非前缀、去掉常见后缀后也不相等）—— 一条真实行名 + 一句不含空话词的理由，                就能把任意条目「洗白」、让反向断言对它消音，那正是 G-3 要堵的口子。                若确有正当理由，加进 `readmeCoverageStructuralExemptions` 并写清依据。
                """)
            }
        }
    }
}

nonisolated final class PublicTypeCollector: SyntaxVisitor {
    var components: Set<String> = []
    var styleImpls: Set<String> = []
    var entryPoints: Set<String> = []

    static let entryPointHostTypes: Set<String> = ["View", "Transition", "AnyTransition"]

    private static let styleProtocols: Set<String> = [
        "ButtonStyle", "PrimitiveButtonStyle", "ToggleStyle", "LabelStyle",
        "ProgressViewStyle", "DisclosureGroupStyle", "LabeledContentStyle",
    ]
    private static let excluded: Set<String> = ["Layout", "Shape", "InsettableShape"]

    init() { super.init(viewMode: .sourceAccurate) }

    override func visit(_ node: IfConfigDeclSyntax) -> SyntaxVisitorContinueKind {
        for clause in node.clauses where clause.elements != nil { walk(clause.elements!) }
        return .skipChildren
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        let host = node.extendedType.trimmedDescription
            .split(separator: ".").last.map(String.init) ?? ""
        guard Self.entryPointHostTypes.contains(host) else { return .visitChildren }
        let extensionIsPublic = node.modifiers.contains(where: { $0.name.text == "public" || $0.name.text == "open" })

        for member in node.memberBlock.members {
            let decl = member.decl
            if let fn = decl.as(FunctionDeclSyntax.self) {
                guard Self.isEffectivelyPublic(fn.modifiers, extensionIsPublic: extensionIsPublic)
                else { continue }
                self.entryPoints.insert("\(host).\(fn.name.text)")
            } else if let variable = decl.as(VariableDeclSyntax.self) {
                guard Self.isEffectivelyPublic(variable.modifiers, extensionIsPublic: extensionIsPublic)
                else { continue }
                for binding in variable.bindings {
                    guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else { continue }
                    self.entryPoints.insert("\(host).\(pattern.identifier.text)")
                }
            }
        }
        return .visitChildren
    }

    private static func isEffectivelyPublic(
        _ modifiers: DeclModifierListSyntax, extensionIsPublic: Bool
    ) -> Bool {
        let names = Set(modifiers.map(\.name.text))
        if names.contains("private") || names.contains("fileprivate") || names.contains("internal") {
            return false
        }
        return names.contains("public") || names.contains("open") || extensionIsPublic
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        let name = node.name.text
        guard node.modifiers.contains(where: { $0.name.text == "public" }) else { return .visitChildren }
        guard !name.hasSuffix("Demo"), !name.hasSuffix("Preview"), !name.hasSuffix("PreviewHost")
        else { return .visitChildren }

        let inherited = (node.inheritanceClause?.inheritedTypes ?? [])
            .map { $0.type.trimmedDescription.split(separator: ".").last.map(String.init) ?? "" }

        if inherited.contains(where: { Self.excluded.contains($0) }) { return .visitChildren }
        if inherited.contains(where: { Self.styleProtocols.contains($0) }) {
            styleImpls.insert(name)
        } else if inherited.contains("View") || inherited.contains("ViewModifier") {
            components.insert(name)
        }
        return .visitChildren
    }
}
