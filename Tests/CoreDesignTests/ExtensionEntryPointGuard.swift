import Foundation
import SwiftParser
import SwiftSyntax
import Testing

// MARK: - 扩展成员扫描器 / Extension member scanner（Issue #246，AD-4《下游连锁二》）
//
// ## 它替换了任务书原来的「条件项：差集守卫」
//
// `246.md` 原写「条件项：差集守卫——若 AD-4 对 Effects / Shaders 选 a，本 task 必须交付
// 它……`transition` / `modifier` **手工维护**并在盲区台账留痕」。
// AD-4 第 6 轮收敛为「**AD-2 原样适用**」（三个 target 全走路线 b，选 a 撤回）
// ⇒ **没有轻公约、也就没有差集守卫**；同时它的《下游连锁二》**逐字推翻**了「手工维护」：
//
// > task 250 的 8 个 `public extension View` 方法 + task 251 的 16 个转场 =
// > **24 个公开入口点**，今天对**所有**守卫不可见……⇒ 新建扩展成员扫描器
// > （把既有 `PublicTypeCollector` 扩到 extension 成员），登记进
// > `component-registry.json` 的 `entryPoints` 数组。
// > ⚠️ 本条推翻 `251.md` / `246.md` / `foundation/epic.md` 三处已写下的
// > 「按 AD-4 的裁决**手工维护**并在盲区台账留痕」——24 条量级的手工表必漂，
// > 正是 G-7 记在案的失效形态。
//
// ⇒ 本文件交付的就是那个扫描器；三份文件的「手工维护」已随本 PR 回改。
//
// ## 为什么它们对既有守卫**结构上**不可见
//
// `PublicTypeCollector` 采的是 `public struct: View/ViewModifier`
// ——一个**类型**。而 `.transition(.iris)` 里的 `iris` 是 `extension Transition where
// Self == IrisTransition` 上的一个**静态成员**，`.confetti(...)` 是
// `public extension View` 上的一个**方法**。两者都不是类型声明 ⇒ 不进 `scanned`
// ⇒ 登记表的双向差集对它们**恒真**。这与「闸门在空数组上真空为真」是同一种病。
//
// ## 射程：**只有新 target**
//
// 与 `EffectsColorLiteralGuard` / `ChromeTextLiteralGuard` 同一条界线。
// `CoreDesign` 有 40+ 个 `public extension View` 方法（`.bordered` / `.surface` /
// `.spinning` / `.bannerStyle` / `.toast` …），**回溯登记它们不是 `#246` 的题目**
// ——那会是一次 40 条量级的登记表改动，且与 AD-4 点名的 24 个入口点无关。
// ⚠️ 但主 target 仍被当**靶场**用（`scannerFiresOnRealSource`）：新 target 今天
// 一个入口点都没有，双向差集在 `∅ vs ∅` 上必绿，「零差集」与「扫描器坏了」
// 在这种输入上不可分辨。
@Suite("扩展成员入口点登记")
struct ExtensionEntryPointGuard {

    /// 扫描一个根，返回**带 target 前缀**的入口点键集合。
    static func scan(target: String, root: URL) throws -> Set<String> {
        let scan = try ComponentRegistryGuard.scanTypes(root: root)
        return Set(scan.entryPoints.map { GuardScanRoots.qualifiedKey(target: target, base: $0) })
    }

    /// 登记表条目 ⇒ 同款键。
    static func key(of entry: ComponentRegistryGuard.EntryPoint) -> String {
        GuardScanRoots.qualifiedKey(target: entry.target, base: "\(entry.host).\(entry.member)")
    }

    // MARK: - schema

    /// 一条 `entryPoints` 条目的全部字段判据，**抽成纯函数**：返回它违反的每一条。
    ///
    /// ⚠️ **抽出来是因为原地写在循环里的版本今天结构性恒绿**（PR #265 终审 S-1）：
    /// `entryPoints` 现在是 `[]`（新 target 还没有任何入口点），于是那个 `for` 循环
    /// **一次都不执行**、六条 `#expect` 从未被求值——「守卫」与「空循环」不可分辨。
    /// 这正是本 task 要防的「0 输入恒绿」，只是下沉了一层。
    /// ⇒ 判据搬进纯函数，由 `schemaValidatorActuallyFires` 用合成条目逐条打红。
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
        // ⚠️ 主 target 的入口点**今天不登记**（射程只有新 target），登记了就说明
        // 有人把射程悄悄扩了一半——一半会被下面的双向差集判成幽灵条目。
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
        // ⚠️ **fail-closed**：`RegistryFile.entryPoints` 是非可选字段——文件里没有这个键
        // 时解码直接 throw，而不是退化成「零入口点 ⇒ 零差集 ⇒ 绿」。
        let entryPoints = try ComponentRegistryGuard.loadEntryPoints()
        // 同一份文件的组件数组必须仍然读得到——顶层改成对象之后，两个数组是一起沉浮的。
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

        // ① host 不在扫描器认得的清单里 ⇒ 幽灵登记。
        #expect(!problems(.init(target: "CoreDesignEffects", host: "NotAHost", member: "confetti",
                                notes: good.notes)).isEmpty, "非法 host 不会红")
        // ② target 不存在。
        #expect(!problems(.init(target: "CoreDesignShaders", host: "View", member: "confetti",
                                notes: good.notes)).isEmpty, "不存在的 target 不会红")
        // ③ 主 target（射程之外）。
        #expect(!problems(.init(target: "CoreDesign", host: "View", member: "bordered",
                                notes: good.notes)).isEmpty, "登记在主 target 上不会红")
        // ④ member 为空。
        #expect(!problems(.init(target: "CoreDesignEffects", host: "View", member: "  ",
                                notes: good.notes)).isEmpty, "空 member 不会红")
        // ⑤ notes 像占位。
        #expect(!problems(.init(target: "CoreDesignEffects", host: "View", member: "confetti",
                                notes: "TODO")).isEmpty, "过短 notes 不会红")
        // ⑥ notes 含空话占位词。
        let banned = BoolExemptionGuard.bannedReasonPhrases.first ?? "TODO"
        #expect(!problems(.init(target: "CoreDesignEffects", host: "View", member: "confetti",
                                notes: "这条理由\(banned)，凑够十个字符以上。")).isEmpty,
                "空话占位词「\(banned)」不会红")
        // ⑦ 重复登记（`seen` 是承重的，两次调用共用同一个 `seen`）。
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

        // ⚠️ 复用 `#38` 抽出的纯函数，两个方向共用同一份实现。
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
        // ⚠️ **`#246` AC「每条新守卫必须附一个会让它变红的 fixture」的落点**：
        // 两个新 target 今天一个入口点都没有，上面的双向差集在 `∅ vs ∅` 上**必绿**。
        func entryPoints(_ source: String) -> Set<String> {
            let tree = SwiftParser.Parser.parse(source: source)
            let collector = PublicTypeCollector()
            collector.walk(tree)
            return collector.entryPoints
        }

        // ① `public extension View` 上的方法（task 250 的 8 个 modifier 形态）。
        #expect(entryPoints("""
        import SwiftUI
        public extension View {
            func confetti(_ trigger: Bool) -> some View { self }
            func glassOrb() -> some View { self }
        }
        """) == ["View.confetti", "View.glassOrb"])

        // ② `extension View { public func … }`（另一种等价写法，只认一种会漏掉半数）。
        #expect(entryPoints("""
        import SwiftUI
        extension View {
            public func shimmer() -> some View { self }
            func internalHelper() -> some View { self }
        }
        """) == ["View.shimmer"])

        // ③ `Transition` 的静态成员（task 251 的 16 个转场形态）。
        #expect(entryPoints("""
        import SwiftUI
        public extension Transition where Self == IrisTransition {
            static var iris: Self { .init() }
            static func wipe(angle: Double) -> WipeTransition { .init(angle: angle) }
        }
        """) == ["Transition.iris", "Transition.wipe"])

        // ④ 含参重载合并成一条（`251.md`：计数单位是「一种 transition」）。
        #expect(entryPoints("""
        import SwiftUI
        public extension Transition {
            static func wipe(angle: Double) -> Self { .init() }
            static func wipe(angle: Double, distance: Double) -> Self { .init() }
        }
        """) == ["Transition.wipe"])

        // ④b `open` 成员同样是入口点（Copilot A-2：只认 `public` 会让 `open` 绕过登记）。
        #expect(entryPoints("""
        import SwiftUI
        extension View {
            open func openModifier() -> some View { self }
        }
        """) == ["View.openModifier"])

        // ⑤ 反向：非 public 成员与无关 host 不算入口点。
        #expect(entryPoints("""
        import SwiftUI
        private extension View { func hidden1() -> some View { self } }
        extension Tag { public func notAnEntryPoint() {} }
        """).isEmpty)

        // ⑥ 双向差集两个方向都能红（漏登记 / 幽灵条目）。
        let scanned: Set<String> = ["CoreDesignEffects/View.confetti"]
        let missing = compareRegistryToScan(scanned: scanned, registered: []).missing
        #expect(missing == scanned, "漏登记方向不会红")
        let ghosts = compareRegistryToScan(scanned: [], registered: scanned).ghosts
        #expect(ghosts == scanned, "幽灵条目方向不会红")

        // ⑦ target 前缀真的进了键（两个 target 的同名成员不塌成一条）。
        #expect(GuardScanRoots.qualifiedKey(target: "CoreDesignEffects", base: "View.confetti")
                != GuardScanRoots.qualifiedKey(target: "CoreDesignCharts", base: "View.confetti"))
    }

    @Test("扫描器在真实源码上非真空：拿主 target 当靶场必须采到入口点")
    func scannerFiresOnRealSource() throws {
        // ⚠️ 与另外两条新守卫同款。`CoreDesign` **不在射程内**（见文件头），
        // 这里只把它当靶场：它有 15 个 `extension View` 块、40+ 个公开 modifier 方法。
        // ⚠️ **必须走 `coreDesignScan()`，不能直接调 `scanTypes(root:)`**
        // （PR #265 终审 S-3）：`ComponentRegistryGuard.coreDesignScan()` 的文档逐字写着
        // 「三条判据统一走这个入口」，绕过它既丢缓存、也绕过「空结果不入缓存」那条纪律。
        let scan = try ComponentRegistryGuard.coreDesignScan()
        #expect(scan.entryPoints.count > 10, """
        扩展成员扫描器在 Sources/CoreDesign 上只采到 \(scan.entryPoints.count) 个入口点 —— 疑似失效。
        本条**不是**要求主 target 登记它们，而是「新 target 的零入口点来自真的没有、
        不是来自坏掉的扫描器」这句话的活证据。
        """)
        // 抽查几个真实存在的入口点，证明采到的不是噪音。
        for expected in ["View.bordered", "View.surface", "View.spinning"] {
            #expect(scan.entryPoints.contains(expected),
                    "主 target 的公开 modifier `\(expected)` 没被采到 —— 扫描器的 public 判别可能又窄了")
        }
        // ⚠️ 入口点**不得**混进 `components`：混进去会被登记表的双向差集判成幽灵条目。
        #expect(scan.components.isDisjoint(with: scan.entryPoints),
                "入口点混进了 components —— 会被 `registryCoversCoreDesignTypes` 判成幽灵条目")
    }
}
