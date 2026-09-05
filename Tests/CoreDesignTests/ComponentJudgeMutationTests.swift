import Foundation
import Testing

/// 端到端变异证伪：在 `Sources/CoreDesign` 的**临时副本**上改源码，跑真实扫描 + 真实规则。
///
/// ⚠️ **三条纪律，缺一条这个测试就会变成自己制造的绿**：
/// 1. **先证基线**：未变异的副本上，判据结果必须与真实源码上的结果一致——否则拷贝本身
///    出了问题（漏文件 / 编码问题），后面的「变异后判红」毫无意义。
/// 2. **变异自证**：`applyMutation` 断言替换命中次数 > 0；`replacingOccurrences` 找不到
///    目标时**静默返回原串**，不自证就会得到「变异了个寂寞 ⇒ 判据当然还是绿」。
/// 3. **违规集合精确**：断言 `== [期望的那一条]` 而不是 `!isEmpty`。这是「红要证明是
///    **这条**断言造成的」在纯函数世界里的等价落法。
@Suite("组件判据端到端变异")
struct ComponentJudgeMutationTests {

    /// 把**三个 target** 的源码树拷到同一个临时目录，返回该目录（不是某一个根）。
    /// 调用方负责在 `defer` 里删掉它。
    ///
    /// ⚠️ `#270` 之前这里只拷 `Sources/CoreDesign` 一棵树并直接返回那棵树的根。
    /// 登记表扩到三根之后，`copiedTreeReproducesBaseline` 拿「一棵树的扫描结果」
    /// 去比「三棵树的扫描结果」必然不等 —— 而那条断言的语义是「拷贝没出问题」，
    /// 不是「射程变了」。⇒ 副本布局与仓库一致：`<tmp>/CoreDesign`、
    /// `<tmp>/CoreDesignEffects`、`<tmp>/CoreDesignCharts`。
    ///
    /// ⚠️ **子目录名必须与真实根同名**：`scanComponentJudgeInputs(root:)` 的 `fileName`
    /// 前缀取的是根目录名（见该函数文档），同名才能让副本与真实源码产出**逐字相同**的
    /// `file` 串，`copiedTreeReproducesBaseline` 的等值断言才成立。
    private func copySources() throws -> URL {
        let destination = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("component-judge-mutation-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        for root in ComponentRegistryGuard.componentScanRoots {
            try FileManager.default.copyItem(
                at: root.url, to: destination.appendingPathComponent(root.target)
            )
        }
        return destination
    }

    /// 副本目录里与 `ComponentRegistryGuard.componentScanRoots` 一一对应的根列表。
    private func copiedRoots(in destination: URL) -> [(target: String, url: URL)] {
        ComponentRegistryGuard.componentScanRoots.map {
            ($0.target, destination.appendingPathComponent($0.target))
        }
    }

    /// 在副本的某个文件上做文本替换，并**断言真的替换到了**。
    /// ⚠️ `relativePath` 是**相对 `Sources/CoreDesign` 那棵树**的路径（全部现存变异都落在
    /// 主 target 里），`root` 是 `copySources()` 返回的**临时目录**。`#270` 之前两者
    /// 恰好同一个 URL，改多根后必须在这里补上 target 段，否则替换会找不到文件、
    /// 上面那条「变异没命中」的自证断言会红 —— 那是好的失败形态（不会静默变绿）。
    private func applyMutation(
        root: URL, relativePath: String, find: String, replace: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let url = root
            .appendingPathComponent(GuardScanRoots.primaryTargetName)
            .appendingPathComponent(relativePath)
        let original = try String(contentsOf: url, encoding: .utf8)
        let mutated = original.replacingOccurrences(of: find, with: replace)
        #expect(mutated != original,
                "变异没命中：\(relativePath) 里找不到「\(find)」—— 不自证的话后面「判据仍绿」会被误读成判据失效",
                sourceLocation: sourceLocation)
        try mutated.write(to: url, atomically: true, encoding: .utf8)
    }

    /// ⚠️ **本条是 `#270` 的承重实证，不是锦上添花**：AC 要求的不只是「新增未登记类型 ⇒ 判红」，
    /// 还要求证明**扩根前后有差别** —— 只做单向验证会漏掉「红是别的原因造成的 / 修的不是那个洞」。
    /// 这里把两侧放进**同一棵被污染的树**上跑：多根判红、单根**完全不红**，
    /// 差别只可能来自扫描根本身。
    ///
    /// ⚠️ 用副本而不是真实源码：真实源码里写一个 probe 类型会污染工作区，
    /// 而 CI 上「跑完忘了删」就是一条永久的假条目。
    @Test("`#270` 扩根实证：新 target 里未登记的 public 类型，多根下判红、单根下完全不红")
    func multiRootCatchesUnregisteredTypeInNewTarget() throws {
        let root = try self.copySources()
        defer { try? FileManager.default.removeItem(at: root) }

        let probe = "ZZUnregisteredProbeView"
        let probeSource = """
        import SwiftUI

        /// 变异用的合成类型：形态与 `Shine` / `GlowSweep` 等同款（`public struct: View`），
        /// 唯一的区别是**登记表里没有它**。
        public struct \(probe): View {
            public init() {}
            public var body: some View { Color.clear }
        }
        """
        try probeSource.write(
            to: root.appendingPathComponent("CoreDesignEffects/ZZUnregisteredProbe.swift"),
            atomically: true, encoding: .utf8
        )

        let entries = try ComponentRegistryGuard.loadRegistry()
        let registered = Set(entries.filter { $0.repo == "coredesign" }.map(\.component))
            .subtracting(ComponentRegistryGuard.knownOffScannerComponents)

        // ---- 多根（`#270` 之后）：判红，且违规集合**恰好**是那一条 ----
        let multiRoot = try ComponentRegistryGuard.scanTypes(roots: self.copiedRoots(in: root))
        let multi = compareRegistryToScan(scanned: multiRoot.components, registered: registered)
        #expect(multi.missing == [probe],
                "多根扫描下未登记类型没有被判成缺失，实际缺失集合：\(multi.missing.sorted())")
        #expect(multi.ghosts.isEmpty, "多根扫描下出现了幽灵条目：\(multi.ghosts.sorted())")

        // ---- 单根（`#270` 之前的形态）：**同一棵被污染的树上完全不红** ----
        // ⚠️ 这一半才是本条存在的理由。缺了它，上面那条只证明「判据会红」，
        // 证明不了「红是因为扩了根」——本仓的教训是只做单向验证会漏掉「修的不是那个洞」。
        let singleRoot = try ComponentRegistryGuard.scanTypes(
            root: root.appendingPathComponent(GuardScanRoots.primaryTargetName)
        )
        let single = compareRegistryToScan(scanned: singleRoot.components, registered: registered)
        #expect(!single.missing.contains(probe),
                "单根扫描竟然看到了 CoreDesignEffects 里的类型 —— 前后对照失效，本条证明不了任何事")
        #expect(single.missing.isEmpty, """
        单根扫描下的缺失集合本应为空（旧判据看不见 Sources/CoreDesignEffects），实际 \(single.missing.sorted())。
        """)

        // ---- 补登记 ⇒ 转绿 ----
        let afterRegistering = compareRegistryToScan(
            scanned: multiRoot.components, registered: registered.union([probe])
        )
        #expect(afterRegistering.missing.isEmpty,
                "补登记后仍判缺失：\(afterRegistering.missing.sorted())")
        #expect(afterRegistering.ghosts.isEmpty,
                "补登记后出现幽灵条目：\(afterRegistering.ghosts.sorted())")
    }

    @Test("端到端：副本未变异时，三条判据的结果与真实源码一致（基线）")
    func copiedTreeReproducesBaseline() throws {
        let root = try self.copySources()
        defer { try? FileManager.default.removeItem(at: root) }
        let entries = try ComponentRegistryGuard.loadRegistry()
        let copied = try scanComponentJudgeInputs(roots: self.copiedRoots(in: root))
        let real = try ComponentJudgeSources.scan()

        #expect(copied.bareTextKeys == real.bareTextKeys, "副本与真实源码的裸文本参数集合不一致 —— 拷贝有问题")
        #expect(copied.styleProtocolNames == real.styleProtocolNames)
        // ⚠️ 期望是**空集**：`Toast` 由 `wxlpp/oh-my-story#65` 以形态 D2 补齐后，
        // J-2 的扩展点缺口全部收口。基线为空集使下面的变异断言**语义更强**——
        // 变异引入的违规不再需要从「已有缺口」里择出来。
        // ⚠️ **上句是 `#65` 当时的记录，不改写。现状（`#299`）：基线不再是空集**——
        // 5 条重判落出口 1、扩展点实现移交 `#312`，登记在
        // `ComponentExtensionPointGuard.knownMissingExtensionPoints` 里。
        // ⇒ 基线改为**与那张红名单逐字相等**，而不是写死 `isEmpty`：
        // 写死空集会让本条在红名单非空期间**永远红**，写死 5 个名字则会在 `#312` 补齐后
        // 忘记同步。取红名单本身作期望，两个方向都由 J-2 自己的棘轮断言守着。
        #expect(Set(judgeExtensionPoints(entries: entries, scan: copied).missing)
                == ComponentExtensionPointGuard.knownMissingExtensionPoints,
                "副本的 J-2 缺口与真实红名单不一致 —— 拷贝有问题，或红名单没同步")
        #expect(judgeNativeProtocolPurity(entries: entries, scan: copied).violations.isEmpty)
        #expect(Set(judgeTextParamCoverage(
            entries: entries, scan: copied, ownerAliases: ComponentTextParamGuard.ownerAliases
        ).violations) == ComponentTextParamGuard.knownUnregisteredSymbolParams)
    }

    @Test("端到端 J-2 变异：把 BannerStyle 协议声明改名 ⇒ Banner 判缺扩展点")
    func j2EndToEndMutation() throws {
        let root = try self.copySources()
        defer { try? FileManager.default.removeItem(at: root) }
        try self.applyMutation(
            root: root, relativePath: "Components/Banner/Banner.swift",
            find: "public protocol BannerStyle {", replace: "public protocol BannerAppearanceContract {"
        )
        let entries = try ComponentRegistryGuard.loadRegistry()
        let result = judgeExtensionPoints(entries: entries, scan: try scanComponentJudgeInputs(roots: self.copiedRoots(in: root)))
        // ⚠️ **期望 = 已知红名单 ∪ {Banner}**（`#299` 由 `== ["Banner"]` 改）：本条要证的是
        // 「变异**新引入**了 Banner 这一条」，不是「全库恰好只有 Banner 一条缺口」。
        // 写死 `["Banner"]` 会把判据与红名单的长度耦合起来，`#312` 补齐后又得改回去。
        //
        // ⚠️ **`#315` 终审 S-6 登记的代价（明知而取）**：期望值与被测对象现在**同源** ——
        // 都取 `ComponentExtensionPointGuard.knownMissingExtensionPoints`。⇒ 若那张红名单本身
        // 写错了（多写 / 少写一个名字），**本条变异判据不会红**，它只证「变异新引入了 Banner」。
        // 挡红名单本身写错的是**另外两条**：J-2 自己的块外 canary
        // （`Set(result.missing) == knownMissingExtensionPoints`，拿真实扫描结果对账）与
        // 「已知缺口条目必须仍是 semantic + 要扩展点 + 协议字段皆 null + notes 写着承接 issue」
        // 那个承重核对循环。⇒ 分工是清楚的，此处只登记这条耦合，不改写法：
        // 换成写死名字会在 `#312` 补齐后静默过期，那是更糟的一侧。
        #expect(Set(result.missing) == ComponentExtensionPointGuard.knownMissingExtensionPoints.union(["Banner"]),
                "登记表说 Banner 的扩展点是 BannerStyle，源码里没有这个协议声明了 ⇒ 必须判红")
        #expect(result.diagnostics.contains { $0.contains("Banner：") && $0.contains("无该协议声明") })
    }

    @Test("端到端 J-2 变异：删掉 BannerStyle 的全部实现 ⇒ Banner 判缺扩展点（『定义 + 使用』的使用侧）")
    func j2EndToEndMutationImplementationsRemoved() throws {
        let root = try self.copySources()
        defer { try? FileManager.default.removeItem(at: root) }
        try self.applyMutation(
            root: root, relativePath: "Components/Banner/Banner.swift",
            find: "public struct PlainBannerStyle: BannerStyle {", replace: "public struct PlainBannerStyle {"
        )
        try self.applyMutation(
            root: root, relativePath: "Components/Banner/Banner.swift",
            find: "public struct BorderedBannerStyle: BannerStyle {", replace: "public struct BorderedBannerStyle {"
        )
        let entries = try ComponentRegistryGuard.loadRegistry()
        let result = judgeExtensionPoints(entries: entries, scan: try scanComponentJudgeInputs(roots: self.copiedRoots(in: root)))
        // ⚠️ 同上（`#299`）：期望 = 已知红名单 ∪ {Banner}。
        #expect(Set(result.missing) == ComponentExtensionPointGuard.knownMissingExtensionPoints.union(["Banner"]))
        #expect(result.diagnostics.contains { $0.contains("Banner：") && $0.contains("无实现类型") },
                "只查协议声明、不查实现的话，把两个 style 实现删光判据照绿 —— AC 原文是『定义 + 使用』")
    }

    @Test("端到端 J-3 变异（通道 i）：往 ProgressIndicator.swift 塞一个自有样式协议 ⇒ 判红")
    func j3EndToEndMutationDeclarationChannel() throws {
        let root = try self.copySources()
        defer { try? FileManager.default.removeItem(at: root) }
        try self.applyMutation(
            root: root, relativePath: "Components/ProgressIndicator/ProgressIndicator.swift",
            find: "public struct ProgressIndicator: View {",
            replace: """
            public protocol ProgressIndicatorStyle {
                associatedtype Body: View
                func makeBody(configuration: Self.Configuration) -> Body
                typealias Configuration = Int
            }

            public struct ProgressIndicator: View {
            """
        )
        let entries = try ComponentRegistryGuard.loadRegistry()
        let result = judgeNativeProtocolPurity(entries: entries, scan: try scanComponentJudgeInputs(roots: self.copiedRoots(in: root)))
        #expect(result.violations.map(\.symbol) == ["ProgressIndicatorStyle"])
        #expect(result.violations.map(\.channel) == ["作用域内声明"])
        #expect(result.violations.map(\.component) == ["ProgressIndicator"])
    }

    @Test("端到端 J-3 变异（通道 ii）：让 ProgressIndicator 采纳 BannerStyle ⇒ 判红")
    func j3EndToEndMutationConformanceChannel() throws {
        let root = try self.copySources()
        defer { try? FileManager.default.removeItem(at: root) }
        try self.applyMutation(
            root: root, relativePath: "Components/ProgressIndicator/ProgressIndicator.swift",
            find: "public struct ProgressIndicator: View {",
            replace: "extension ProgressIndicator: BannerStyle {}\n\npublic struct ProgressIndicator: View {"
        )
        let entries = try ComponentRegistryGuard.loadRegistry()
        let result = judgeNativeProtocolPurity(entries: entries, scan: try scanComponentJudgeInputs(roots: self.copiedRoots(in: root)))
        #expect(result.violations.map(\.symbol) == ["BannerStyle"])
        #expect(result.violations.map(\.channel) == ["组件采纳"])
    }

    @Test("端到端 FR-4 变异：给 Avatar 加一个未登记的裸 String 参数 ⇒ 判红；补登记 ⇒ 转绿")
    func fr4EndToEndMutation() throws {
        let root = try self.copySources()
        defer { try? FileManager.default.removeItem(at: root) }
        try self.applyMutation(
            root: root, relativePath: "Components/Avatar/Avatar.swift",
            find: "public init(name: String) {", replace: "public init(name: String, caption: String) {"
        )
        let entries = try ComponentRegistryGuard.loadRegistry()
        let scan = try scanComponentJudgeInputs(roots: self.copiedRoots(in: root))

        let red = judgeTextParamCoverage(
            entries: entries, scan: scan, ownerAliases: ComponentTextParamGuard.ownerAliases
        )
        #expect(Set(red.violations) ==
                ComponentTextParamGuard.knownUnregisteredSymbolParams.union(["Avatar.init#caption"]),
                "新增未登记的裸 String 参数必须判红，且违规集合精确")

        // 「补登记 ⇒ 转绿」：登记表只读，因此在**内存里**补一条条目，不碰 JSON。
        let patched = entries.map { entry -> ComponentRegistryGuard.Entry in
            guard entry.component == "Avatar" else { return entry }
            return makeTestEntry(
                component: entry.component, repo: entry.repo, kind: entry.kind, decidedBy: entry.decidedBy,
                nativeProtocol: entry.nativeProtocol, customStyleProtocol: entry.customStyleProtocol,
                needsExtensionPoint: entry.needsExtensionPoint,
                textParams: entry.textParams + [ComponentRegistryGuard.TextParam(name: "caption", category: "B")],
                notes: entry.notes
            )
        }
        let green = judgeTextParamCoverage(
            entries: patched, scan: scan, ownerAliases: ComponentTextParamGuard.ownerAliases
        )
        #expect(Set(green.violations) == ComponentTextParamGuard.knownUnregisteredSymbolParams,
                "补登记后新增的那条应消失，已知的四条不受影响 —— AC 原文的『补登记 → 判据变绿』")
    }

    @Test("端到端 FR-4 反向变异：把已登记参数改名 ⇒ 登记表条目变成幽灵")
    func fr4EndToEndGhostMutation() throws {
        let root = try self.copySources()
        defer { try? FileManager.default.removeItem(at: root) }
        try self.applyMutation(
            root: root, relativePath: "Components/Avatar/Avatar.swift",
            find: "public init(name: String) {", replace: "public init(displayName: String) {"
        )
        let entries = try ComponentRegistryGuard.loadRegistry()
        let result = judgeTextParamCoverage(
            entries: entries, scan: try scanComponentJudgeInputs(roots: self.copiedRoots(in: root)),
            ownerAliases: ComponentTextParamGuard.ownerAliases
        )
        #expect(result.ghostRegistryParams == ["Avatar.name"],
                "反向差集必须抓到『登记表有、源码没有』—— 这是参数被改写成扫描器看不见的形态时的第二道防线")
        #expect(result.violations.contains("Avatar.init#displayName"))
    }
}
