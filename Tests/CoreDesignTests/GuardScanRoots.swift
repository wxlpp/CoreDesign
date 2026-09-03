import Foundation
import Testing

// MARK: - 多 target 扫描根的单一来源 / Single source of truth for the multi-target scan roots
//
// 本仓从 `#244`/`#245` 起有三个 library target（`CoreDesign` / `CoreDesignEffects` /
// `CoreDesignCharts`），而在 `#246` 之前，**四条源码守卫的扫描根全部是硬编码的单根**
// `Sources/CoreDesign`（`BoolExemptionGuard.swift:43`、
// `AccessibilityStringLiteralGuard.swift:189`、`ComponentRegistryGuard.swift:366`）
// ⇒ 新 target 里写什么都不受纪律约束。本文件把「根列表」抽成**一份**数据，
// 由 Bool / a11y / 字面量 / 扩展成员四类守卫共用。
//
// ⚠️ **本文件不含 `ComponentRegistryGuard.coreDesignSources`**：登记表守卫的根
// 是否扩到新 target，是 AD-4《下游连锁一》的题目（Charts 走 b 会顶动
// `ComponentExtensionPointGuard` 的 `inspected.count == 11` 等一串断言），
// 归 Charts 落件时（`#255`）处置，不在 `#246` 的射程内。此处点名，免得后人以为漏了。
//
// ## 防假绿的两条纪律（`#246` AC「防假绿」节）
//
// 1. **根列表只含当下已存在的 target，且每个根必须真的存在**（fail-closed）——
//    `FileManager.enumerator(at:)` 对不存在的路径**静默产出空序列**，
//    「零文件 ⇒ 零违规 ⇒ 绿」是本仓反复栽过的坑。`Sources/CoreDesignShaders/`
//    今天**不存在**，故**不进**本表：对它做扫描/grep 无命中即绿，正是要防的 fail-open。
//    该根由 `shipswift-shaders` 的 B-1 在 target 真的落地时加入。
// 2. **根列表必须与 `Package.swift` 同步**——`libraryTargetsAreCoveredByScanRoots`
//    直接解析 manifest 里声明的 library target，与本表做**双向**差集。
//    ⇒ 将来任何人新增一个 library target 而忘了扩根，这条判据当场红；
//    「新 target 静默逃出全部守卫」这条通路被机器堵死，不靠人记得。
nonisolated enum GuardScanRoots {

    /// ⚠️ 用 `#filePath` 推导，worktree 与主仓两种布局下都稳（上三级到仓库根）。
    static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    /// 主 target。它同时是豁免台账键的**默认前缀**（见 `qualifiedKey(target:base:)`）。
    static let primaryTargetName = "CoreDesign"

    /// 当下**已存在**的全部 library target，顺序同 `Package.swift`。
    ///
    /// ⚠️ 加一个名字之前先确认 `Sources/<名字>/` 真的存在——`assertRootsExist()`
    /// 会当场判红，但那是第二道防线，不是第一道。
    static let targetNames: [String] = ["CoreDesign", "CoreDesignEffects", "CoreDesignCharts"]

    /// 新 target（除主 target 之外的全部）。
    ///
    /// 三条新守卫（`EffectsColorLiteralGuard` / `ChromeTextLiteralGuard` /
    /// `ExtensionEntryPointGuard`）的射程**只有这里**——公约 FR-7 与 `#246` 任务书
    /// 都明写「不回溯改造 CoreDesign 现状」。
    static var newTargetNames: [String] { Self.targetNames.filter { $0 != Self.primaryTargetName } }

    static func sourcesURL(of target: String) -> URL {
        Self.repoRoot.appendingPathComponent("Sources/\(target)")
    }

    /// 全部根（含主 target）——Bool 纪律与 a11y 字面量守卫用这一份。
    static var allRoots: [(target: String, url: URL)] {
        Self.targetNames.map { ($0, Self.sourcesURL(of: $0)) }
    }

    /// 新 target 的根——三条新守卫用这一份。
    static var newTargetRoots: [(target: String, url: URL)] {
        Self.newTargetNames.map { ($0, Self.sourcesURL(of: $0)) }
    }

    // MARK: - fail-closed：根必须真的存在

    /// 断言每个根目录都真的存在。**任何跨根扫描前都要先调它**。
    ///
    /// ⚠️ 单条守卫内部的 `scanXxx(root:)` 各自也有一条同款断言（那是**逐根**的），
    /// 这里是**列表级**的：列表非空 + 每项存在。两者都要，缺一个都留下一条
    /// 「扫描器在空输入上必绿」的缝。
    @discardableResult
    static func assertRootsExist(
        _ roots: [(target: String, url: URL)],
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> Bool {
        var ok = true
        if roots.isEmpty {
            Issue.record("扫描根列表为空 —— 后续扫描会在空输入上恒绿，这不是「零违规」", sourceLocation: sourceLocation)
            ok = false
        }
        for root in roots where !FileManager.default.fileExists(atPath: root.url.path) {
            Issue.record(
                "扫描根不存在：\(root.url.path)（target \(root.target)）—— 判据无法工作，这不是「零违规」",
                sourceLocation: sourceLocation
            )
            ok = false
        }
        return ok
    }

    /// 枚举一个根下的全部 `.swift` 文件。路径不存在 / 无法枚举都会 `Issue.record` 并返回空数组
    /// ——与本仓其余扫描器同一条纪律：**失败要变成可读的测试失败，不是静默的空集**。
    static func swiftFiles(
        in root: URL, sourceLocation: SourceLocation = #_sourceLocation
    ) -> [URL] {
        guard FileManager.default.fileExists(atPath: root.path) else {
            Issue.record("源码路径不存在：\(root.path) —— 判据无法工作，这不是「零违规」", sourceLocation: sourceLocation)
            return []
        }
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            Issue.record("无法枚举源码目录：\(root.path)（权限或 IO 异常）—— 判据无法工作", sourceLocation: sourceLocation)
            return []
        }
        var out: [URL] = []
        for case let url as URL in walker where url.pathExtension == "swift" { out.append(url) }
        return out
    }

    /// 仓库根相对路径，用于报错信息（`Sources/CoreDesignEffects/Foo.swift`）。
    static func relativePath(_ url: URL) -> String {
        url.path.replacingOccurrences(of: Self.repoRoot.path + "/", with: "")
    }

    // MARK: - 台账键的 target 前缀（`#246` AC「台账键加 target 前缀」）

    /// 台账键 = `<target 前缀>` + 扫描器产出的基键。
    ///
    /// ⚠️ **主 target 的前缀是空串，这是刻意的**：`docs/bool-exemptions.json` 现存 32 条
    /// 全部是 `Owner.decl#param` 裸形，而 `#246` 的 FR-10 要求「既有 CoreDesign 判据
    /// **字面**不变」。给 32 条既有条目集体加前缀既不增加任何判别力（它们本来就全是
    /// CoreDesign 的），又会同时改动 `contractNamedKeys` 这个**判据体系之外的参照物**
    /// ——那正是 FR-10 不许动的东西。
    /// ⇒ 前缀只对**新 target** 生效：`CoreDesignEffects/Owner.decl#param`。
    ///
    /// ⚠️ **它是承重的，不是装饰**：没有它，`CoreDesign` 与 `CoreDesignEffects` 里
    /// 两个同名类型的同名 Bool 参数会**塌成同一个键**，一条豁免静默覆盖两个 target
    /// ——`BoolScanResult.keys` 是 `Set`，塌掉的那一条在差集里看不见。
    /// 「裸形只属于主 target」这条规矩由 `exemptionKeysAreCanonicallyQualified` 钉死。
    static func qualifiedKey(target: String, base: String) -> String {
        target == Self.primaryTargetName ? base : "\(target)/\(base)"
    }

    /// 从台账键里取回 target 名（裸形 ⇒ 主 target）。
    static func target(ofKey key: String) -> String {
        guard let slash = key.firstIndex(of: "/") else { return Self.primaryTargetName }
        return String(key[key.startIndex..<slash])
    }

    /// 去掉 target 前缀后的基键。
    static func baseKey(_ key: String) -> String {
        guard let slash = key.firstIndex(of: "/") else { return key }
        return String(key[key.index(after: slash)...])
    }

    // MARK: - 每个 target 各自的 `.module`（`#246` AC「按 target 分辨各自的 .module」）

    /// 该 target 是否拥有**自己的** `Bundle.module`（即 `Package.swift` 给它声明了资源）。
    ///
    /// ⚠️ **这是 a11y 守卫多根化后最容易假绿的一处**：`bundle: .module` 在
    /// `Sources/CoreDesignEffects/` 里解析到的是 **CoreDesignEffects 自己的** bundle，
    /// 不是 CoreDesign 的 String Catalog。而 `CoreDesignEffects` / `CoreDesignCharts`
    /// **没有 `resources:` 声明** ⇒ SwiftPM 根本不给它们合成 `Bundle.module`。
    /// ⇒ 在这两个 target 里写 `bundle: .module` 既不能编译、也不会去到任何 catalog，
    /// 但**旧的文本判据只看 span 里有没有 `bundle: .module` 这串字符**，
    /// 于是它会被当成「已本地化」放行。本函数把「谁真的有 `.module`」变成可查的事实。
    static func ownsResourceBundle(_ target: String) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(
            atPath: Self.sourcesURL(of: target).appendingPathComponent("Resources").path,
            isDirectory: &isDirectory
        )
        return exists && isDirectory.boolValue
    }

    // MARK: - `Package.swift` 的 library target 清单

    static var packageManifestURL: URL { Self.repoRoot.appendingPathComponent("Package.swift") }

    /// 解析 `Package.swift` 里声明的 **library** target 名（不含 `.testTarget`）。
    ///
    /// ⚠️ 逐行状态机而非正则：manifest 里 `.target(` 与 `name:` 通常分行写。
    /// 注释行整行跳过——注释里提到 `.testTarget` 的地方不少，按子串匹配会误判。
    static func declaredLibraryTargets() throws -> [String] {
        let text = try String(contentsOf: Self.packageManifestURL, encoding: .utf8)
        var out: [String] = []
        var awaitingName = false
        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("//") { continue }
            if line.hasPrefix(".testTarget(") { awaitingName = false; continue }
            if line.hasPrefix(".target(") {
                awaitingName = true
                if let name = Self.firstQuoted(in: line) { out.append(name); awaitingName = false }
                continue
            }
            if awaitingName, line.hasPrefix("name:"), let name = Self.firstQuoted(in: line) {
                out.append(name)
                awaitingName = false
            }
        }
        return out
    }

    private static func firstQuoted(in line: String) -> String? {
        guard let open = line.firstIndex(of: "\"") else { return nil }
        let rest = line[line.index(after: open)...]
        guard let close = rest.firstIndex(of: "\"") else { return nil }
        return String(rest[rest.startIndex..<close])
    }
}

// MARK: - 扫描根自身的守卫

@Suite("多 target 扫描根")
struct GuardScanRootsGuard {

    @Test("根列表非空，且每个根目录真的存在（fail-closed）")
    func rootsExist() {
        #expect(!GuardScanRoots.targetNames.isEmpty, "根列表为空 —— 全部跨根守卫会在空输入上恒绿")
        #expect(!GuardScanRoots.newTargetNames.isEmpty, "新 target 列表为空 —— 三条新守卫会在空输入上恒绿")
        #expect(GuardScanRoots.assertRootsExist(GuardScanRoots.allRoots))
        // ⚠️ 每个根都必须真的有 `.swift` 文件——「目录存在但空」同样让扫描器恒绿。
        for root in GuardScanRoots.allRoots {
            #expect(!GuardScanRoots.swiftFiles(in: root.url).isEmpty,
                    "\(root.target) 的根 \(root.url.path) 下一个 .swift 都没有 —— 扫描器会在空输入上恒绿")
        }
    }

    @Test("根列表与 Package.swift 的 library target 双向吻合 —— 新增 target 忘了扩根即红")
    func libraryTargetsAreCoveredByScanRoots() throws {
        let declared = try GuardScanRoots.declaredLibraryTargets()
        // ⚠️ 非空前置：manifest 解析失效 ⇒ 空集 ⇒ 下面两条差集全空 ⇒ 静默变绿。
        #expect(declared.count >= 3, "从 Package.swift 只解析到 \(declared.count) 个 library target —— 解析器可能失效，不是「target 变少了」")

        let declaredSet = Set(declared)
        let known = Set(GuardScanRoots.targetNames)
        let unguarded = declaredSet.subtracting(known).sorted()
        #expect(unguarded.isEmpty, """
        这些 library target 在 Package.swift 里声明了，却不在 `GuardScanRoots.targetNames` 里：\(unguarded)
        —— 它们的源码**不受** Bool 纪律 / a11y 字面量 / 色相字面量 / chrome 文案任何一条守卫覆盖。
        这正是 `#246` 要堵的「新 target 变成垃圾抽屉」。处置：把名字加进 `targetNames`，
        并确认三条新守卫在它上面真的跑得起来（`Sources/<名字>/` 必须已存在）。
        ⚠️ 不要反过来把 target 从 manifest 里藏起来。
        """)
        let ghosts = known.subtracting(declaredSet).sorted()
        #expect(ghosts.isEmpty, """
        `GuardScanRoots.targetNames` 里这些名字在 Package.swift 里已经没有对应的 library target：\(ghosts)
        —— 幽灵根会让「每个根断言目录存在」那条判据红在一个已经不该存在的路径上。
        """)
        #expect(known.contains(GuardScanRoots.primaryTargetName),
                "主 target `\(GuardScanRoots.primaryTargetName)` 不在根列表里 —— 台账键的默认前缀失去依据")
    }

    @Test("`Sources/CoreDesignShaders/` 尚不存在，因此**不得**进根列表（防 fail-open）")
    func shadersRootIsDeliberatelyAbsent() {
        // ⚠️ 本条不是「禁止将来加 Shaders」，而是钉住 `#246` AC 里那句话的现状：
        // 对一个**不存在**的目录做扫描 / grep，无命中即绿——那是 fail-open，不是「零违规」。
        // Shaders target 落地那天，`libraryTargetsAreCoveredByScanRoots` 会当场判红，
        // 逼 `shipswift-shaders` 的 B-1 把根加进来；本条随之改为断言它**在**列表里。
        let shaders = GuardScanRoots.sourcesURL(of: "CoreDesignShaders")
        let exists = FileManager.default.fileExists(atPath: shaders.path)
        let listed = GuardScanRoots.targetNames.contains("CoreDesignShaders")
        #expect(exists == listed, """
        `Sources/CoreDesignShaders/` 存在=\(exists)，而根列表里有它=\(listed) —— 两者必须一致：
        · 目录不存在却进了列表 ⇒ 「每个根断言目录存在」会红（fail-closed，符合预期）；
        · 目录存在却没进列表 ⇒ 该 target 的源码**完全不受守卫覆盖**，且所有 grep 判据
          在它上面无命中即绿（fail-open）。处置：把 `CoreDesignShaders` 加进
          `GuardScanRoots.targetNames`（`shipswift-shaders` 的 B-1）。
        """)
    }

    // MARK: - NFR-4：零 `@unchecked Sendable`

    /// 纯函数入口，供合成输入的变红自证使用（见 `uncheckedSendableDetectorActuallyFires`）。
    static func uncheckedSendableLines(in source: String) -> [Int] {
        source.split(separator: "\n", omittingEmptySubsequences: false).enumerated()
            .filter { $0.element.contains("@unchecked Sendable") }
            .map { $0.offset + 1 }
    }

    @Test("NFR-4：全部已存在 target 的源码里零 `@unchecked Sendable`")
    func noUncheckedSendable() {
        // ⚠️ **根列表与其余四条守卫同源**（`GuardScanRoots.allRoots`），
        // 只含已存在的 target。对不存在的 `Sources/CoreDesignShaders/` 做 grep
        // **无命中即绿**，正是 `#246` 点名要防的 fail-open。
        #expect(GuardScanRoots.assertRootsExist(GuardScanRoots.allRoots))

        var offenders: [String] = []
        var scannedFiles = 0
        for root in GuardScanRoots.allRoots {
            let files = GuardScanRoots.swiftFiles(in: root.url)
            // ⚠️ 逐根非空：某个 target 下一个文件都没有时，「零命中」是假绿。
            #expect(!files.isEmpty, "\(root.target) 下没有任何 .swift 文件 —— NFR-4 的 grep 在它上面恒绿")
            scannedFiles += files.count
            for url in files {
                guard let text = try? String(contentsOf: url, encoding: .utf8) else {
                    Issue.record("读不到 \(GuardScanRoots.relativePath(url)) —— 判据无法工作")
                    continue
                }
                for line in Self.uncheckedSendableLines(in: text) {
                    offenders.append("\(GuardScanRoots.relativePath(url)):\(line)")
                }
            }
        }
        #expect(scannedFiles > 50, "只扫到 \(scannedFiles) 个源文件 —— 扫描失效，「零命中」不可信")
        #expect(offenders.isEmpty, """
        NFR-4：这些位置用了 `@unchecked Sendable`：
        \(offenders.joined(separator: "\n"))
        —— 它把并发正确性从编译器手里拿走、换成一句口头承诺。处置：改成真正的 `Sendable`
        （值语义 / `let` / actor 隔离），或把类型收成非 public 的实现细节。
        """)
    }

    @Test("NFR-4 的探测器真的会开火（合成输入变红自证）")
    func uncheckedSendableDetectorActuallyFires() {
        // ⚠️ **没有这条，上面那条在 0 个命中上必绿，而「必绿」与「守住了」不可分辨**。
        // 三个新 target 今天各只有一个骨架文件，正是 `#246` AC 点名的
        // 「新守卫在 0 个文件上必绿」形态。
        let violating = """
        import Foundation
        final class Box: @unchecked Sendable {
            var value = 0
        }
        """
        #expect(Self.uncheckedSendableLines(in: violating) == [2],
                "探测器对最直白的违规都不开火 —— 上面那条「零命中」毫无意义")
        let clean = """
        struct Box: Sendable { let value = 0 }
        """
        #expect(Self.uncheckedSendableLines(in: clean).isEmpty, "探测器误报：干净的 Sendable 也被标记")
    }

    // MARK: - 台账键的 target 前缀

    @Test("台账键前缀：主 target 走裸形，新 target 必须带前缀")
    func qualifiedKeyShape() {
        #expect(GuardScanRoots.qualifiedKey(target: "CoreDesign", base: "Badge.init#outlined")
                == "Badge.init#outlined")
        #expect(GuardScanRoots.qualifiedKey(target: "CoreDesignEffects", base: "Badge.init#outlined")
                == "CoreDesignEffects/Badge.init#outlined")
        // 往返：前缀能被完整取回。
        for target in GuardScanRoots.targetNames {
            let key = GuardScanRoots.qualifiedKey(target: target, base: "Foo.init#flag")
            #expect(GuardScanRoots.target(ofKey: key) == target, "键「\(key)」取不回 target \(target)")
            #expect(GuardScanRoots.baseKey(key) == "Foo.init#flag")
        }
        // ⚠️ 承重性：同名类型在两个 target 里**不塌成同一个键**。
        #expect(GuardScanRoots.qualifiedKey(target: "CoreDesign", base: "Foo.init#flag")
                != GuardScanRoots.qualifiedKey(target: "CoreDesignCharts", base: "Foo.init#flag"))
    }

    @Test("`.module` 归属：只有 CoreDesign 拥有自己的资源包")
    func moduleBundleOwnership() {
        #expect(GuardScanRoots.ownsResourceBundle("CoreDesign"),
                "CoreDesign 的 Sources/CoreDesign/Resources 不见了 —— a11y 守卫的 `bundle: .module` 放行条失去依据")
        for target in GuardScanRoots.newTargetNames where GuardScanRoots.ownsResourceBundle(target) {
            // 不是「不许有」，是「有了就必须同轮告诉 a11y 守卫」：该 target 一旦有了自己的
            // String Catalog，`bundle: .module` 在它里面才开始有意义。
            Issue.record("""
            \(target) 现在有了 Sources/\(target)/Resources —— 若它真的带 String Catalog，
            请确认 `Package.swift` 也给它声明了 `resources:`，并复核
            `AccessibilityStringLiteralGuard` 的按 target 放行逻辑（本条只是提醒，不是禁令）。
            """)
        }
    }
}
