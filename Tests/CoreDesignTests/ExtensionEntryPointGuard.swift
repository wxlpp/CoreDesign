import Foundation
import SwiftParser
import SwiftSyntax
import Testing

// MARK: - 扩展成员扫描器 / Extension member scanner（Issue #246，AD-4《下游连锁二》）

@Suite("扩展成员入口点登记")
struct ExtensionEntryPointGuard {
    static func scan(target: String, root: URL) throws -> Set<String> {
        let scan = try ComponentRegistryGuard.scanTypes(root: root)
        return Set(scan.entryPoints.map { GuardScanRoots.qualifiedKey(target: target, base: $0) })
    }

    static func key(of entry: ComponentRegistryGuard.EntryPoint) -> String {
        GuardScanRoots.qualifiedKey(target: entry.target, base: "\(entry.host).\(entry.member)")
    }

    // MARK: - schema

    static func schemaProblems(of entry: ComponentRegistryGuard.EntryPoint, seen: inout Set<String>) -> [String] {
        let key = Self.key(of: entry)
        var problems: [String] = []
        if !seen.insert(key).inserted {
            problems.append("入口点「\(key)」重复登记 —— 双向差集看 Set，重名会被静默吞掉")
        }
        if !GuardScanRoots.targetNames.contains(entry.target) {
            problems.append("入口点「\(key)」的 target「\(entry.target)」不在 `GuardScanRoots.targetNames` 里")
        }
        if !PublicTypeCollector.entryPointHostTypes.contains(entry.host) {
            problems.append("""
            入口点「\(key)」的 host「\(entry.host)」不在扫描器认得的被扩展类型清单里
            （\(PublicTypeCollector.entryPointHostTypes.sorted())）
            —— 登记了一个扫描器永远采不到的 host，这条登记从落地那天起就是幽灵。
            """)
        }
        if entry.member.trimmingCharacters(in: .whitespaces).isEmpty {
            problems.append("入口点「\(key)」的 member 为空")
        }
        if entry.notes.count < 10 {
            problems.append("入口点「\(key)」的 notes 只有 \(entry.notes.count) 字符，像占位")
        }
        for banned in BoolExemptionGuard.bannedReasonPhrases where entry.notes.contains(banned) {
            problems.append("入口点「\(key)」的 notes 含空话占位词「\(banned)」")
        }
        if entry.target == GuardScanRoots.primaryTargetName {
            problems.append("""
            入口点「\(key)」登记在主 target 上，而本守卫的射程只有新 target
            —— 它会被下面的双向差集判成幽灵条目。若确要把 CoreDesign 的 40+ 个
            `public extension View` 方法纳入登记，那是一次独立的裁决与批量改动，
            不是往这个数组里塞一条。
            """)
        }
        return problems
    }

    @Test("`entryPoints` 数组存在、可解析，且每条字段合法")
    func entryPointSchemaIsValid() throws {
        let entryPoints = try ComponentRegistryGuard.loadEntryPoints()
        #expect(try ComponentRegistryGuard.loadRegistry().count > 30,
                "登记表的 components 数组读不到 —— 顶层结构可能又被改了")

        var seen: Set<String> = []
        for entry in entryPoints {
            for problem in Self.schemaProblems(of: entry, seen: &seen) { Issue.record("\(problem)") }
        }
    }

    @Test("schema 判据真的会开火：合成条目逐条变红自证（终审 S-1）")
    func schemaValidatorActuallyFires() {
        func problems(_ entry: ComponentRegistryGuard.EntryPoint) -> [String] {
            var seen: Set<String> = []
            return Self.schemaProblems(of: entry, seen: &seen)
        }
        let good = ComponentRegistryGuard.EntryPoint(
            target: "CoreDesignEffects", host: "View", member: "confetti",
            notes: "这是一条长度足够、说明了用途的登记理由。"
        )
        #expect(problems(good).isEmpty, "合法条目被误判：\(problems(good))")

        #expect(!problems(.init(target: "CoreDesignEffects", host: "NotAHost", member: "confetti",
                                notes: good.notes)).isEmpty, "非法 host 不会红")
        #expect(!problems(.init(target: "CoreDesignShaders", host: "View", member: "confetti",
                                notes: good.notes)).isEmpty, "不存在的 target 不会红")
        #expect(!problems(.init(target: "CoreDesign", host: "View", member: "bordered",
                                notes: good.notes)).isEmpty, "登记在主 target 上不会红")
        #expect(!problems(.init(target: "CoreDesignEffects", host: "View", member: "  ",
                                notes: good.notes)).isEmpty, "空 member 不会红")
        #expect(!problems(.init(target: "CoreDesignEffects", host: "View", member: "confetti",
                                notes: "TODO")).isEmpty, "过短 notes 不会红")
        let banned = BoolExemptionGuard.bannedReasonPhrases.first ?? "TODO"
        #expect(!problems(.init(target: "CoreDesignEffects", host: "View", member: "confetti",
                                notes: "这条理由\(banned)，凑够十个字符以上。")).isEmpty,
                "空话占位词「\(banned)」不会红")
        var seen: Set<String> = []
        #expect(Self.schemaProblems(of: good, seen: &seen).isEmpty)
        #expect(!Self.schemaProblems(of: good, seen: &seen).isEmpty, "重复登记不会红")
    }

    // MARK: - 双向差集

    @Test("新 target 的扩展成员入口点：登记表全覆盖，且无幽灵条目")
    func registryCoversNewTargetEntryPoints() throws {
        #expect(GuardScanRoots.assertRootsExist(GuardScanRoots.newTargetRoots))

        var scanned: Set<String> = []
        for root in GuardScanRoots.newTargetRoots {
            let files = GuardScanRoots.swiftFiles(in: root.url)
            #expect(!files.isEmpty, "\(root.target) 下没有任何 .swift 文件 —— 本守卫在它上面恒绿")
            scanned.formUnion(try Self.scan(target: root.target, root: root.url))
        }
        let registered = Set(try ComponentRegistryGuard.loadEntryPoints().map(Self.key(of:)))

        let diff = compareRegistryToScan(scanned: scanned, registered: registered)
        #expect(diff.missing.isEmpty, """
        新 target 里这些公开入口点没有登记：\(diff.missing.sorted())
        —— `public extension View` 的方法与 `Transition` 的静态成员是调用方真正写下的
        API 表面（`.transition(.iris)` / `.confetti(...)`），它们不是类型，登记表的
        组件条目结构上覆盖不到。处置：往 `docs/component-registry.json` 的 `entryPoints`
        数组补条目（`target` / `host` / `member` / `notes`）。
        ⚠️ **不要**改回手工表——AD-4《下游连锁二》逐字否决了那条路。
        """)
        #expect(diff.ghosts.isEmpty, """
        登记表的 `entryPoints` 里有幽灵条目（新 target 源码里找不到）：\(diff.ghosts.sorted())
        —— 要么成员被删/改名了（同轮删登记），要么 host / member 写错了。
        """)

        print("【入口点】新 target 共 \(scanned.count) 个：\(scanned.sorted())")
    }

    // MARK: - 防假绿

    @Test("扫描器真的看得见 extension 成员（合成输入变红自证）")
    func scannerSeesExtensionMembers() {
        func entryPoints(_ source: String) -> Set<String> {
            let tree = SwiftParser.Parser.parse(source: source)
            let collector = PublicTypeCollector()
            collector.walk(tree)
            return collector.entryPoints
        }

        #expect(entryPoints("""
        import SwiftUI
        public extension View {
            func confetti(_ trigger: Bool) -> some View { self }
            func glassOrb() -> some View { self }
        }
        """) == ["View.confetti", "View.glassOrb"])

        #expect(entryPoints("""
        import SwiftUI
        extension View {
            public func shimmer() -> some View { self }
            func internalHelper() -> some View { self }
        }
        """) == ["View.shimmer"])

        #expect(entryPoints("""
        import SwiftUI
        public extension Transition where Self == IrisTransition {
            static var iris: Self { .init() }
            static func wipe(angle: Double) -> WipeTransition { .init(angle: angle) }
        }
        """) == ["Transition.iris", "Transition.wipe"])

        #expect(entryPoints("""
        import SwiftUI
        public extension Transition {
            static func wipe(angle: Double) -> Self { .init() }
            static func wipe(angle: Double, distance: Double) -> Self { .init() }
        }
        """) == ["Transition.wipe"])

        #expect(entryPoints("""
        import SwiftUI
        extension View {
            open func openModifier() -> some View { self }
        }
        """) == ["View.openModifier"])

        #expect(entryPoints("""
        import SwiftUI
        private extension View { func hidden1() -> some View { self } }
        extension Tag { public func notAnEntryPoint() {} }
        """).isEmpty)

        let scanned: Set<String> = ["CoreDesignEffects/View.confetti"]
        let missing = compareRegistryToScan(scanned: scanned, registered: []).missing
        #expect(missing == scanned, "漏登记方向不会红")
        let ghosts = compareRegistryToScan(scanned: [], registered: scanned).ghosts
        #expect(ghosts == scanned, "幽灵条目方向不会红")

        #expect(GuardScanRoots.qualifiedKey(target: "CoreDesignEffects", base: "View.confetti")
                != GuardScanRoots.qualifiedKey(target: "CoreDesignCharts", base: "View.confetti"))
    }

    @Test("扫描器在真实源码上非真空：拿主 target 当靶场必须采到入口点")
    func scannerFiresOnRealSource() throws {
        let scan = try ComponentRegistryGuard.componentScan()
        #expect(scan.entryPoints.count > 10, """
        扩展成员扫描器在三个扫描根上只采到 \(scan.entryPoints.count) 个入口点 —— 疑似失效。
        本条**不是**要求主 target 登记它们，而是「新 target 的零入口点来自真的没有、
        不是来自坏掉的扫描器」这句话的活证据。
        """)
        for expected in ["View.bordered", "View.surface", "View.spinning"] {
            #expect(scan.entryPoints.contains(expected),
                    "主 target 的公开 modifier `\(expected)` 没被采到 —— 扫描器的 public 判别可能又窄了")
        }
        #expect(scan.components.isDisjoint(with: scan.entryPoints),
                "入口点混进了 components —— 会被 `registryCoversCoreDesignTypes` 判成幽灵条目")
    }
}
