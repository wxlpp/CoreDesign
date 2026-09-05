import Foundation
import Testing

// MARK: - `#279`：`CoreDesignShaders` 进扫描根之后，守卫在它上面**真的在工作**
//
// 本文件回答的问题只有一个：**把 `"CoreDesignShaders"` 加进
// `GuardScanRoots.targetNames` 之后，那批守卫是「扫了、零违规」还是「压根没扫」？**
//
// ⚠️ **「零违规 ⇒ 绿」在本仓被反复证伪过**：`FileManager.enumerator(at:)` 对不存在的
// 路径静默产出空序列，`#246` 的文件头把它逐字记为「本仓反复栽过的坑」。`#279` 的 AC
// 因此逐字写着「须留一条『扫描文件数 > 0』的实证，**不接受**『零违规 ⇒ 绿』」。
//
// ⚠️ **只数文件还不够**：文件数 > 0 只证明 `swiftFiles(in:)` 看得见那棵树，
// 证明不了**每条守卫自己的 `scan(root:)` 真的把那些文件读了一遍**
// （守卫大可以枚举完就丢掉）。⇒ 下面第二条判据往 Shaders 树的**临时副本**里各埋一处
// 违规，跑每条守卫**真实的** `scan(root:)`，要求它当场开火。
// 这与 `ComponentJudgeMutationTests` 是同一条纪律：**判据在真实数据上零命中时，
// 必须另有 fixture 证明它还活着。**
//
// ⚠️ **本文件的射程只有 `CoreDesignShaders` 一个根**，不是全部四个根的通用判据 ——
// 别的根各自的非空断言在各自的守卫里。写成全根循环会让失败诊断指不出是哪个根出的事，
// 而 `#279` 要接的账恰恰就是这一个根。
@Suite("#279 CoreDesignShaders 扫描根实证")
struct ShadersScanRootGuard {

    static let shadersTarget = "CoreDesignShaders"
    static var shadersRoot: URL { GuardScanRoots.sourcesURL(of: Self.shadersTarget) }

    /// 埋进副本里的探针文件名前缀。⚠️ 以 `ZZ` 开头，排序时落在最后，扫描输出里一眼可辨。
    static let probePrefix = "ZZShadersScanProbe"

    // MARK: - ① 扫描文件数 > 0（AC 逐字要求的那条实证）

    @Test("Shaders 根真的被枚举到了文件（扫描文件数 > 0，且逐条打印出来）")
    func shadersRootYieldsFiles() {
        #expect(GuardScanRoots.targetNames.contains(Self.shadersTarget),
                "`\(Self.shadersTarget)` 不在根列表里 —— 本文件全部判据失去对象")
        #expect(GuardScanRoots.assertRootsExist([(Self.shadersTarget, Self.shadersRoot)]))

        let files = GuardScanRoots.swiftFiles(in: Self.shadersRoot)
        // ⚠️ 下界写 `>= 6` 而不是精确数：精确数由下面的 print 给出，写进断言会让每加一个
        // shader 都要来改这里，而它挡的是「整根空掉」不是「少一个」。
        // 6 的出处：本轮实测 **9** 个 `.swift`（CoreDesignShaders / ShaderSupport / RefractiveGlass
        // + 6 个 shader 件），留三个的余量给后续删件（`Starfield` 已随 `#281` 删过一个）。
        #expect(files.count >= 6, """
        `Sources/\(Self.shadersTarget)/` 只枚举到 \(files.count) 个 .swift 文件 ——
        四族守卫在它上面的「零违规」不可信。⚠️ 这不是「文件变少了」的提示，是「扫描失效」的提示。
        """)
        print("【#279 扫描文件数】\(Self.shadersTarget) 共 \(files.count) 个 .swift："
              + files.map { GuardScanRoots.relativePath($0) }.sorted().joined(separator: ", "))

        // ⚠️ `.metal` 侧另计：`EffectsColorLiteralGuard` 是 SwiftSyntax 解析器，**看不见 `.metal`**
        // （AD-F 已把这一层登记为「已知无机器判据、由评审覆盖」）。这里把它数出来，
        // 免得「Swift 侧零违规」被读成「整个 target 零硬编码色」。
        let metalFiles = ((try? FileManager.default.contentsOfDirectory(atPath: Self.shadersRoot.path)) ?? [])
            .filter { $0.hasSuffix(".metal") }
        #expect(!metalFiles.isEmpty, """
        `Sources/\(Self.shadersTarget)/` 下一个 `.metal` 都没有 —— 若 shader 源真的搬走了，
        `Package.swift` 的 `resources:` 声明与 `GuardScanRootsGuard.moduleBundleOwnership` 会先红；
        本条只是让「`.metal` 那一层没有机器判据」这句话始终有对象可指。
        """)
        print("【#279 AD-F 留痕】\(Self.shadersTarget) 的 `.metal` 共 \(metalFiles.count) 个：\(metalFiles.sorted())"
              + " —— 色相字面量守卫是 SwiftSyntax 解析器，**看不见它们**；那一层由评审覆盖。")
    }

    // MARK: - ② 三条新 target 守卫在 Shaders 树上真的会开火

    /// 把 Shaders 树拷进临时目录。调用方负责删。
    private func copyShaders() throws -> URL {
        let destination = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("shaders-scan-probe-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let tree = destination.appendingPathComponent(Self.shadersTarget)
        try FileManager.default.copyItem(at: Self.shadersRoot, to: tree)
        return destination
    }

    private func plant(_ source: String, named name: String, in tree: URL) throws {
        try source.write(
            to: tree.appendingPathComponent("\(Self.probePrefix)\(name).swift"),
            atomically: true, encoding: .utf8
        )
    }

    @Test("三条新 target 守卫的 `scan(root:)` 真的读了 Shaders 树：埋一处违规就当场开火")
    func newTargetGuardsActuallyReadTheShadersTree() throws {
        let destination = try self.copyShaders()
        defer { try? FileManager.default.removeItem(at: destination) }
        let tree = destination.appendingPathComponent(Self.shadersTarget)

        // ---- 基线：未变异的副本上三条守卫全部零违规 ----
        // ⚠️ 没有这一半，下面的「变异后开火」证明不了火是变异点的
        //（也顺带兑现 AC 的「`EffectsColorLiteralGuard` 对 `Sources/CoreDesignShaders/` 零违规」，
        // 只是这里跑在副本上；真实树上那一条由 `EffectsColorLiteralGuard.noColorLiteralsInNewTargets`
        // 与本文件的 `effectsColorLiteralGuardIsCleanOnTheRealShadersTree` 各跑一遍）。
        #expect(try EffectsColorLiteralGuard.scan(root: tree).isEmpty, "副本基线就有色相字面量 —— 下面的变异证明不了任何事")
        #expect(try ChromeTextLiteralGuard.scan(root: tree).violations.isEmpty, "副本基线就有裸 chrome 文案")
        let baselineEntryPoints = try ComponentRegistryGuard.scanTypes(root: tree).entryPoints
        #expect(baselineEntryPoints == ["View.refractiveGlass"], """
        副本基线的入口点集合是 \(baselineEntryPoints.sorted())，而真实树上是 `["View.refractiveGlass"]` ——
        拷贝出了问题（漏文件 / 编码），下面的变异证明不了任何事。
        """)

        // ---- ① EffectsColorLiteralGuard：埋一处色相字面量 ----
        try self.plant("""
        import SwiftUI

        public struct \(Self.probePrefix)Color: View {
            public init() {}
            public var body: some View { Color.clear.foregroundStyle(.cyan) }
        }
        """, named: "Color", in: tree)
        let colorHits = try EffectsColorLiteralGuard.scan(root: tree)
        #expect(!colorHits.isEmpty, """
        往 Shaders 树的副本里埋了一处 `.cyan`，`EffectsColorLiteralGuard.scan(root:)` 竟然零命中
        —— 说明它**根本没读**这棵树，真实树上的「零违规」是假绿。
        """)

        // ---- ② ChromeTextLiteralGuard：埋一处裸 chrome 文案 ----
        try self.plant("""
        import SwiftUI

        public struct \(Self.probePrefix)Text: View {
            public init() {}
            public var body: some View { Text("Cancel") }
        }
        """, named: "Text", in: tree)
        let textHits = try ChromeTextLiteralGuard.scan(root: tree).violations
        #expect(!textHits.isEmpty, """
        往 Shaders 树的副本里埋了一处 `Text("Cancel")`，`ChromeTextLiteralGuard.scan(root:)` 竟然零命中
        —— 同上，真实树上的「零违规」是假绿。
        """)

        // ---- ③ ExtensionEntryPointGuard：埋一个未登记的 `public extension View` 成员 ----
        try self.plant("""
        import SwiftUI

        public extension View {
            func \(Self.probePrefix)Entry() -> some View { self }
        }
        """, named: "Entry", in: tree)
        let scanned = try ExtensionEntryPointGuard.scan(target: Self.shadersTarget, root: tree)
        let probeKey = GuardScanRoots.qualifiedKey(
            target: Self.shadersTarget, base: "View.\(Self.probePrefix)Entry"
        )
        #expect(scanned.contains(probeKey), """
        往 Shaders 树的副本里埋了一个 `public extension View` 成员，扫描结果里没有它（实际 \(scanned.sorted())）
        —— `ExtensionEntryPointGuard` 没读这棵树，`registryCoversNewTargetEntryPoints` 对 Shaders 是假绿。
        """)
        // 双向差集在这个探针上必须判红（登记表里没有它）。
        let registered = Set(try ComponentRegistryGuard.loadEntryPoints().map(ExtensionEntryPointGuard.key(of:)))
        #expect(compareRegistryToScan(scanned: scanned, registered: registered).missing == [probeKey], """
        埋进去的入口点探针没有被判成缺失 —— 双向差集在 Shaders 根上没有射程。
        """)
    }

    // MARK: - ③ AC 逐字：色相字面量守卫在**真实** Shaders 树上零违规

    @Test("`EffectsColorLiteralGuard` 对真实的 `Sources/CoreDesignShaders/` 零违规（且这不是空扫）")
    func effectsColorLiteralGuardIsCleanOnTheRealShadersTree() throws {
        // ⚠️ **非空前置写在同一条判据里**：上面 `shadersRootYieldsFiles` 已经数过一次，
        // 但那是**另一条**判据 —— 本条自己的「零违规」若要可信，得在本条里就有文件数。
        // （与 `assertRootsExist` 的「列表级 + 逐根级两者都要」同一条纪律。）
        let files = GuardScanRoots.swiftFiles(in: Self.shadersRoot)
        #expect(files.count >= 6, "只扫到 \(files.count) 个文件 —— 下面的「零违规」不可信")

        let hits = try EffectsColorLiteralGuard.scan(root: Self.shadersRoot)
        #expect(hits.isEmpty, """
        `Sources/\(Self.shadersTarget)/` 里出现了色相字面量：\(hits.map(\.description))
        —— 本 target 的色一律经 `ShaderRamp`（由调用方 `tint` 推导）后用 `.color(...)` 传进 shader，
        FR-8 逐字写着「`.metal` 侧一律零硬编码色」。
        """)
        print("【#279】EffectsColorLiteralGuard 在 \(files.count) 个 Swift 文件上零违规。"
              + "⚠️ AD-F：`.metal` 侧本守卫看不见，那一层**登记为已知无机器判据**、由评审覆盖。")
    }

    // MARK: - ④ 变异实证 + 对照：未登记的 public 类型，加根后判红、加根前完全不红

    /// ⚠️ **这条是 `#279` 的承重实证，形态照搬 `#270` 的
    /// `ComponentJudgeMutationTests.multiRootCatchesUnregisteredTypeInNewTarget`**：
    /// AC 要求的不只是「新增未登记类型 ⇒ 判红」，还要求证明**加 Shaders 根之前同一枚变异
    /// 不判红** —— 只做单向验证会漏掉「红是别的原因造成的 / 修的不是那个洞」。
    /// 两侧跑在**同一棵被污染的树**上，差别只可能来自根列表本身。
    @Test("`#279` 扩根实证：Shaders 里未登记的 public 类型，加根后判红、加根前完全不红，补登记转绿")
    func shadersRootCatchesUnregisteredType() throws {
        let destination = try self.copyShaders()
        defer { try? FileManager.default.removeItem(at: destination) }
        // 另外三个根直接用真实树（本条只需要它们的类型集合，不改动它们）。
        let otherRoots = ComponentRegistryGuard.componentScanRoots
            .filter { $0.target != Self.shadersTarget }
        let shadersCopy = (target: Self.shadersTarget, url: destination.appendingPathComponent(Self.shadersTarget))

        let probe = "ZZUnregisteredShaderProbeView"
        try self.plant("""
        import SwiftUI

        /// 变异用的合成类型：形态与 `Plasma` / `DotGrid` 等同款（`public struct: View`），
        /// 唯一的区别是**登记表里没有它**。
        public struct \(probe): View {
            public init() {}
            public var body: some View { Color.clear }
        }
        """, named: "Unregistered", in: shadersCopy.url)

        let entries = try ComponentRegistryGuard.loadRegistry()
        let registered = Set(entries.filter { $0.repo == "coredesign" }.map(\.component))
            .subtracting(ComponentRegistryGuard.knownOffScannerComponents)

        // ---- 含 Shaders 根（`#279` 之后）：判红，且违规集合**恰好**是那一条 ----
        let withShaders = try ComponentRegistryGuard.scanTypes(roots: otherRoots + [shadersCopy])
        let after = compareRegistryToScan(scanned: withShaders.components, registered: registered)
        #expect(after.missing == [probe],
                "含 Shaders 根时未登记类型没有被判成缺失，实际缺失集合：\(after.missing.sorted())")
        #expect(after.ghosts.isEmpty, "含 Shaders 根时出现了幽灵条目：\(after.ghosts.sorted())")

        // ---- 不含 Shaders 根（`#279` 之前的形态）：**同一棵被污染的树上完全不红** ----
        // ⚠️ 这一半才是本条存在的理由。缺了它，上面那条只证明「判据会红」，
        // 证明不了「红是因为加了 Shaders 根」。
        let withoutShaders = try ComponentRegistryGuard.scanTypes(roots: otherRoots)
        let before = compareRegistryToScan(scanned: withoutShaders.components, registered: registered)
        #expect(!before.missing.contains(probe),
                "不含 Shaders 根时竟然看到了 Shaders 里的类型 —— 前后对照失效，本条证明不了任何事")
        #expect(before.missing.isEmpty, """
        不含 Shaders 根时的缺失集合本应为空（`#279` 之前的判据看不见 Sources/CoreDesignShaders），实际 \(before.missing.sorted())。
        """)
        // ⚠️ 反过来也要成立：`#279` 之后登记的 6 条 Shaders 条目，在**不含**该根时会变成幽灵。
        // 这是同一件事的另一面 —— 它证明那 6 条条目的射程确实来自新加的根，而不是别处。
        let shadersEntries: Set<String> = [
            "DotGrid", "FractalClouds", "GlassSymbol", "InkSmoke", "LiquidChrome", "Plasma",
        ]
        #expect(shadersEntries.isSubset(of: before.ghosts), """
        不含 Shaders 根时，`#279` 登记的 6 条 Shaders 条目本应全部变成幽灵条目，实际幽灵集合 \(before.ghosts.sorted())
        —— 若它们不在里面，说明它们是被**别的根**扫到的，那 6 条登记的归属就写错了。
        """)

        // ---- 补登记 ⇒ 转绿 ----
        let afterRegistering = compareRegistryToScan(
            scanned: withShaders.components, registered: registered.union([probe])
        )
        #expect(afterRegistering.missing.isEmpty, "补登记后仍判缺失：\(afterRegistering.missing.sorted())")
        #expect(afterRegistering.ghosts.isEmpty, "补登记后出现幽灵条目：\(afterRegistering.ghosts.sorted())")
    }
}
