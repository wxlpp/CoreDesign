import Foundation
import Testing

// MARK: - 多 target 扫描根的单一来源 / Single source of truth for the multi-target scan roots
//
// 本仓从 `#244`/`#245` 起有三个 library target（`CoreDesign` / `CoreDesignEffects` /
// `CoreDesignCharts`），而在 `#246` 之前，**四条源码守卫的扫描根全部是硬编码的单根**
// `Sources/CoreDesign`——各自在自己的文件里拼 `repoRoot + "Sources/CoreDesign"`
// （`BoolExemptionGuard.scanRoots` 与 `AccessibilityStringLiteralGuard` 的扫描循环
// 已在 `#246` 改指 `GuardScanRoots.allRoots`；`ComponentRegistryGuard` 的根
// **`#270` 才跟上**，见下）⇒ 新 target 里写什么都不受纪律约束。本文件把「根列表」抽成
// **一份**数据，由 Bool / a11y / 字面量 / 扩展成员 / **组件登记表**五类守卫共用。
//
// ⚠️ **此处刻意只引符号名、不引行号**（PR #265 第 5 轮终审 I-4）：上面括号里的三处
// 描述的是 `#246` **之前**的历史状态，行号注定随文件漂移——本文件头初版写下的
// `BoolExemptionGuard.swift:43` / `AccessibilityStringLiteralGuard.swift:189`
// **在写下的当天就已经指到空行和一个 `}`**，且没有任何判据会为此判红。
// 与下面 `relativePath(_:)` 文档里那条同样的纪律（活引用一律用符号名）。
//
// ⚠️ **上句原写「本文件不含 `ComponentRegistryGuard` 的 `coreDesignSources`」，`#270` 已作废**
//（⚠️ 该历史符号名在这里**拆开写**：它今天已不存在，连点写成限定名会被
//  `JudgementReferenceGuard` 判成悬空引用——那条判据不区分活引用与撤回痕迹）：
// 登记表守卫的根曾停在单根，理由是「扩根会顶动 AD-4《下游连锁一》那串断言，归 `#255` 处置」
// ——而 `#255` 落地时没做 ⇒ 两个新 target 的 public 类型对登记表**结构上不可见**，
// 少登记一条不会有任何判据红。`#270` 把它接过来收口：
// `ComponentRegistryGuard.componentScanRoots` 现在**直接返回 `Self.allRoots`**，
// 不另列一份根名（两套根必然漂，这是 `#270` AC 逐字写死的）。
// ⇒ 本文件现在是**全部五类守卫**的唯一根来源，`libraryTargetsAreCoveredByScanRoots`
// 与 `Package.swift` 的双向差集因此也同时守住了登记表的射程。
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

    /// ⚠️ **本函数按 target 名推根，这个假设本身是一条 fail-open 路径**（PR #297 终审 S-2）：
    /// `DeclaredTarget` 只记 `name` / `isLibrary` / `hasResources`，**不记 `path:`**。
    /// 若某天有 library target 写成 `.target(name: "Foo", path: "Sources/Bar")`，
    /// 而仓库里还留着一棵陈旧的 `Sources/Foo/`，则五族守卫会扫**错的树**，
    /// 而 `assertRootsExist`（目录存在）与 `libraryTargetsAreCoveredByScanRoots`
    /// （名字双向差集）**双双满足** ⇒ 静默 fail-open。
    /// ⇒ 处置不是「支持 `path:`」，而是把它**变成判红**：`declaredTargets` 一旦在
    /// library target 块里看到 `path:` 就 `Issue.record`（见该函数里的 `currentHasPath`）。
    /// 要真的支持 `path:`，得同时改 `DeclaredTarget` 的 schema 与本函数，那是独立一块工程。
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
    ///
    /// ⚠️ **多根扫描的诊断一律走这里，不得用 `url.lastPathComponent`**
    /// （PR #265 第 3 轮 Copilot A-1 / A-2）：`CoreDesign/Foo.swift` 与
    /// `CoreDesignEffects/Foo.swift` 的裸文件名一模一样，失败位置会指错文件。
    /// 传给 `SourceLocationConverter(fileName:)` 的也必须是它——那个名字会进
    /// `Violation.file` / `BoolParamHit.file`，最终出现在给人读的清单里。
    ///
    /// **本轮已逐条排查过的全部 `lastPathComponent` 用点**（免得后人重扫一遍）：
    /// · `BoolExemptionGuard.declaredTypeNames()`、`scanBoolParams(root:target:)`
    ///   ——**多根**，本轮已改；
    /// · `EffectsColorLiteralGuard.scan(root:)` / `ChromeTextLiteralGuard.scan(root:)` /
    ///   `AccessibilityStringLiteralGuard.noBareAccessibilityLiterals` /
    ///   `ExtensionEntryPointGuard` ——多根，本来就走 `relativePath`；
    /// · `ComponentRegistryGuard.scanTypes(root:)`、`scanComponentJudgeInputs(root:)`
    ///   （解析出错诊断 + `collectComponentJudgeInputs(tree:fileName:)` 的 `fileName` 实参）、
    ///   `StyleConsumptionGuard.swiftSources()`、
    ///   `ToastPublicEntryForwardingGuard.aliasEntriesForwardEveryParameter()`
    ///   ——⚠️ **这里逐条引的是符号名不是行号**（PR #265 第 5 轮终审 S-e）：本 PR 的
    ///   `4ce5366` / `0455e9f` 刚把行号引用统一改成符号名，本清单写回行号是反向漂移
    ///   ——行号今天全对，下一次任何人在这四个文件里插一行就全错，而没有任何判据会红。
    ///   ——⚠️ **上句原写「扫描根是这**一个**根，跨 target 同名不可能发生 ⇒ 有意保持原样。
    ///   它们哪天扩到多根，必须同轮改成 `relativePath`」——`#270` 就是那一天，已兑现**：
    ///   · `ComponentRegistryGuard.scanTypes(root:)` 的解析出错诊断 → 改走 `relativePath`；
    ///   · `StyleConsumptionGuard.swiftSources()` 的键 → 改走 `relativePath`；
    ///   · `ToastPublicEntryForwardingGuard.aliasEntriesForwardEveryParameter()` → 多根扫描，
    ///     命中以 `URL` 传递，不再经裸文件名；
    ///   · `scanComponentJudgeInputs(root:)` 的 `fileName` → 改成 **`<根目录名>/<根内相对路径>`**
    ///     而**不是** `relativePath`。那一处是唯一的例外，理由写在该函数的文档里：
    ///     它的 `file` 串被 `ComponentJudgeMutationTests` 拿来比对「临时副本 vs 真实源码」，
    ///     用仓库根相对路径的话副本侧会退化成绝对路径、等值断言不再成立。
    ///     ⚠️ `#311` 起那一处**也走本函数**，只是传的 `root` 是扫描根而不是仓库根
    ///     （见 `relativePath(_:from:)`）——同一条符号链接归一逻辑必须两处共用。
    static func relativePath(_ url: URL) -> String {
        Self.relativePath(url, from: Self.repoRoot)
    }

    /// 把 `url` 表达成相对 `root` 的路径；`url` 不在 `root` 之下时**原样返回绝对路径**。
    ///
    /// ⚠️ **不得退回裸字符串前缀替换**（`#311`）。原实现是
    /// `url.path.replacingOccurrences(of: root.path + "/", with: "")`，它有两处独立缺陷，
    /// 叠在一起就是 `#311` 的失效形态：
    ///
    /// 1. **两端对符号链接的解析不一致**。macOS 上 `/tmp` 是 `/private/tmp` 的符号链接。
    ///    `repoRoot` 由 `#filePath` 推出，而 `#filePath` 是**编译期**记下的那串路径；
    ///    扫描侧的路径则来自**运行期** `FileManager.enumerator(at:)`。
    ///    实测（Xcode 26.4，worktree 在 `/tmp/cd311-repro`）：
    ///    · `xcodebuild` 腿——`#filePath` = `/tmp/cd311-repro/…`，
    ///      而同一次运行里 `FileManager.enumerator(at: /tmp/cd311-repro/Sources/CoreDesign)`
    ///      吐出来的是 `/private/tmp/cd311-repro/Sources/CoreDesign/…`（枚举器**会**解析
    ///      符号链接，即使传进去的根没解析）⇒ 两端分叉；
    ///    · `swift test` 腿——SwiftPM 先把包根解析成 `/private/tmp/cd311-repro` 再传给
    ///      编译器，`#filePath` 与枚举结果**同为** `/private/…` ⇒ 不分叉。
    ///    ⇒ 这个坑**只在 `xcodebuild` 腿上现形**，macOS `swift test` 全绿是假绿。
    /// 2. **`replacingOccurrences` 不是前缀操作**。前缀对不上时它不会「原样返回」，而是
    ///    在**串中间**找到那段并挖掉：`/private` + `/tmp/repo/` + `Sources/…` 里的中段被
    ///    删掉 ⇒ 得到 `/privateSources/…`。实测被污染的键（`#311` 复现）：
    ///    `"/privateSources/CoreDesignEffects/AnimatedMeshGradient.swift#body"`、
    ///    `"CoreDesign//privateComponents/ProgressIndicator/ProgressIndicator.swift"`。
    ///    ⇒ 失效方向是**假红**（判据本身仍在工作），但诊断指向完全错误的方向：
    ///    `JudgementReferenceGuard` 报的是「各面候选引用数全 0、扫描面之外 4857」，
    ///    读到的人会去查扫描面配置，不会想到是 checkout 位置。
    ///
    /// ⇒ 现在按**路径分量**比较，且分两步：
    /// · 先拿 `standardizedFileURL` 的分量试一次（见 `standardizedComponents(_:)`）。
    ///   ⚠️ **这一趟不是零 IO**：`standardizedFileURL` **本身会读文件系统**，并对
    ///   **真实存在**的路径去掉 `/private` 前缀。实测（同一串，只改文件存不存在）：
    ///   文件存在 ⇒ `/private/tmp/X/S/A.swift` 归一成 `/tmp/X/S/A.swift`；
    ///   删掉文件后同一串 ⇒ 原样返回 `/private/tmp/X/S/A.swift`。
    ///   **本仓的真实输入全部在这一趟命中**；
    /// · 不中才归一后重试（见 `canonicalComponents(_:)`）。
    ///
    /// ⚠️ **两趟各守一味分叉，别以为哪一趟是冗余的**（`#313` 终审 F-1 起的这一段）：
    /// · **`/private` 味**（`#311` 实际踩到的那种，`/tmp` → `/private/tmp`）——
    ///   **快路径自己就归一掉了**，因为 `standardizedFileURL` 对**存在**的路径去 `/private`。
    ///   实测（`/tmp` 下真实 fixture 树、未解析的根 + 枚举出的文件）：串替换版给
    ///   `/privateSources/CoreDesign/Colors/A.swift`；本实现、「慢路径去掉 `private` 抹除」、
    ///   「**只留快路径**」三者**同为** `Sources/CoreDesign/Colors/A.swift`
    ///   ⇒ 只看这一味的话，慢路径确实不执行。
    /// · **普通符号链接味**（扫描根的**祖先分量**是符号链接，例如 checkout 落在
    ///   `~/work` → `/Volumes/Data/work` 之下）——**快路径给 `nil`**
    ///  （`standardizedFileURL` 不解析普通符号链接，实测），**只有慢路径能归正**。
    ///   `GuardScanRootsGuard.enumeratorResolvesSymlinksInScanRootAncestor` 拿真实 fixture
    ///   钉的正是这一格：把慢路径删掉 ⇒ 它当场红。
    ///   ⚠️ **⇒「慢路径是不执行的代码、删了只有合成判据会红」是错的**，别照那个结论动手。
    ///
    /// ⚠️ **慢路径里只靠 `resolvingSymlinksInPath()` 不够**，还要显式抹掉领头的
    /// `private` 分量：该 API 同样只在路径**真实存在**时才会去掉 `/private` 前缀。
    /// 实测（本机 Swift 6.3）：
    /// `/private/tmp/cd311-repro` 存在 ⇒ 归一成 `/tmp/cd311-repro`；
    /// 而 `/private/tmp/cd311-repro/Sources/CoreDesign/NOPE.swift`（不存在）**原样返回**，
    /// 对应的 `/tmp/…/NOPE.swift` 也原样返回 ⇒ 两端仍分叉。
    /// 判据要能用合成路径构造这个形态，就不能把正确性建在「文件恰好存在」上。
    ///
    /// ⚠️ **兜底那一支默认会 `Issue.record`**（`expectingContainment`，`#313` 终审 C-5）：
    /// 全部**真实**调用点的 `url` 都是枚举 `root` 得到的 ⇒ 结构上不可能不在 `root` 之下。
    /// 真落进兜底就意味着又冒出了一类新的路径分叉，后果与 `#311` 一样
    ///（台账键退化成绝对路径 ⇒ 假红 + 诊断指错方向），但**更安静**——不再有 `/private`
    /// 这种显眼特征可供 grep。⇒ 默认把它变成一条可读的失败，而不是静默 fail-open。
    /// 判据里那几种「本来就该落兜底」的形态传 `expectingContainment: false`。
    static func relativePath(
        _ url: URL,
        from root: URL,
        expectingContainment: Bool = true,
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> String {
        if let relative = Self.relative(
            Self.standardizedComponents(url), under: Self.standardizedComponents(root)
        ) {
            return relative
        }
        if let relative = Self.relative(
            Self.canonicalComponents(url), under: Self.canonicalComponents(root)
        ) {
            return relative
        }
        if expectingContainment {
            Issue.record(
                """
                路径推导落进兜底：\(url.path)
                不在扫描根 \(root.path) 之下 —— 真实调用点的 url 全部由枚举该根得到，
                结构上不该发生。出现它意味着又冒出了一类路径分叉（`#311` 那次是 `/private`），
                后果同样是台账键被污染（假红 + 诊断指向扫描面配置），但没有显眼特征可查。
                """,
                sourceLocation: sourceLocation
            )
        }
        return url.path
    }

    /// 路径分量的前缀比较——命中返回根内相对路径，不中返回 `nil`。
    ///
    /// ⚠️ 用 `>` 而不是 `>=`：`url == root` 时没有「根内相对路径」可言，
    /// 交给调用方走原样返回绝对路径那一支（与替换版的行为一致）。
    private static func relative(_ file: [String], under root: [String]) -> String? {
        guard file.count > root.count, Array(file.prefix(root.count)) == root else { return nil }
        return file.dropFirst(root.count).joined(separator: "/")
    }

    /// ⚠️ **本函数会做 IO**：`standardizedFileURL` 读文件系统，对**存在**的路径去掉
    /// `/private` 前缀（实测见 `relativePath(_:from:)` 的文档）。正因如此，`/private`
    /// 那一味分叉在这一趟就已经归一完毕。
    /// ⚠️ 但它**不解析普通符号链接**（实测：`<tmp>/link -> <tmp>/real` 之下的路径
    /// 原样返回）⇒ 那一味只能靠 `canonicalComponents(_:)`。
    private static func standardizedComponents(_ url: URL) -> [String] {
        url.standardizedFileURL.pathComponents
    }

    /// ⚠️ **`count >= 3` 不是随手写的下界**：`/private` 自己（分量 `["/", "private"]`）
    /// 不能被抹成 `["/"]`——那会让「根 = `/private`」匹配上**任何**绝对路径。
    private static func canonicalComponents(_ url: URL) -> [String] {
        var parts = url.standardizedFileURL.resolvingSymlinksInPath().pathComponents
        if parts.count >= 3, parts[0] == "/", parts[1] == "private" { parts.remove(at: 1) }
        return parts
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

    /// 该 target 是否拥有**自己的** `Bundle.module`（即 `Package.swift` 给它声明了 `resources:`）。
    ///
    /// ⚠️ **这是 a11y 守卫多根化后最容易假绿的一处**：`bundle: .module` 在
    /// `Sources/CoreDesignEffects/` 里解析到的是 **CoreDesignEffects 自己的** bundle，
    /// 不是 CoreDesign 的 String Catalog。而 `CoreDesignEffects` / `CoreDesignCharts`
    /// **没有 `resources:` 声明** ⇒ SwiftPM 根本不给它们合成 `Bundle.module`。
    /// ⇒ 在这两个 target 里写 `bundle: .module` 既不能编译、也不会去到任何 catalog，
    /// 但**旧的文本判据只看 span 里有没有 `bundle: .module` 这串字符**，
    /// 于是它会被当成「已本地化」放行。本函数把「谁真的有 `.module`」变成可查的事实。
    ///
    /// ⚠️ **判据是 `Package.swift` 的 `resources:`，不是 `Sources/<target>/Resources/` 目录**
    /// （PR #265 终审 I-4）：首版只 `fileExists` 查目录，与本行文档逐字不符——而
    /// **合成 `Bundle.module` 的是 manifest 的 `resources:` 声明，不是目录**。
    /// 光建目录不声明，SwiftPM 只会报 unhandled resource 警告、`.module` 依然不存在；
    /// 那时旧实现返回 `true`，等于把「假绿」从 a11y 守卫搬进了本函数。
    /// 目录与声明是否同步，由 `GuardScanRootsGuard.moduleBundleOwnership` 单独钉住。
    static func ownsResourceBundle(_ target: String) -> Bool {
        Self.resourceOwningTargets().contains(target)
    }

    /// `Package.swift` 里带 `resources:` 声明的 target 名集合。
    ///
    /// ⚠️ **有意不缓存**：`GuardScanRoots` 是 `nonisolated enum`（本 package 的
    /// `.defaultIsolation(MainActor.self)` 对它不生效），可变静态量在 Swift 6 严格并发下
    /// 直接判错；而 manifest 只有 ~90 行、解析一次以 µs 计，缓存不值得为它开一个
    /// 并发安全的口子。⚠️ 解析失败时返回空集并 `Issue.record`——**空集不能被当成
    /// 「没人有资源包」静默消费**，故失败必须以可读的测试失败现形。
    static func resourceOwningTargets(sourceLocation: SourceLocation = #_sourceLocation) -> Set<String> {
        guard let targets = try? Self.declaredTargets(sourceLocation: sourceLocation) else {
            Issue.record("读不到 / 解析不了 Package.swift —— `.module` 归属无法判定", sourceLocation: sourceLocation)
            return []
        }
        return Set(targets.filter(\.hasResources).map(\.name))
    }

    // MARK: - `Package.swift` 的 library target 清单

    static var packageManifestURL: URL { Self.repoRoot.appendingPathComponent("Package.swift") }

    /// `Package.swift` 里解析出来的一个 target 声明。
    nonisolated struct DeclaredTarget: Hashable, Sendable {
        let name: String
        /// 是否由 `.target(` 声明。`.testTarget` / `.executableTarget` / `.macro` /
        /// `.binaryTarget` / `.plugin` / `.systemLibrary` 都**不是** library target。
        let isLibrary: Bool
        /// 该 target 块里写了 `resources:` —— `Bundle.module` 只对它们存在。
        let hasResources: Bool
    }

    /// 解析 `Package.swift` 里声明的**全部** target（含 name / 种类 / 有无 `resources:`）。
    ///
    /// ⚠️ 逐行状态机而非正则：manifest 里 `.target(` 与 `name:` 通常分行写。
    /// 注释（行首 / 行尾 `//` 与跨行 `/* */`）与多行字符串体由 `code(of:state:)` 剥掉
    /// ——注释里提到 `.testTarget` 的地方不少，按子串匹配会误判。
    ///
    /// ⚠️ **解析不出 name 的块会 `Issue.record`，不静默丢弃**（PR #265 终审 S-4，
    /// PR #265 第 4 轮终审 I-4 把它真正接上）：`.target(name: shadersName,` 这类非字面量 name
    /// 会让 `quotedName` 返回 `nil`，据此把整个块丢掉并报一条可读的失败 ⇒ 该 target
    /// 不会悄悄不进 `targetNames` 的双向差集、也不会悄悄不进 `.module` 归属表，
    /// 而两者都是 fail-open 方向的漏。
    /// （更精确的做法是 `swift package describe --type json`，但那会给测试引入
    /// 子进程依赖——本仓的守卫至今没有先例，故不引。）
    static func declaredTargets(sourceLocation: SourceLocation = #_sourceLocation) throws -> [DeclaredTarget] {
        Self.declaredTargets(
            manifestText: try String(contentsOf: Self.packageManifestURL, encoding: .utf8),
            sourceLocation: sourceLocation
        )
    }

    /// 合成输入入口——`GuardScanRootsGuard.manifestParserHandlesAwkwardShapes` 用它证伪
    /// 三种畸形写法，不碰磁盘。
    ///
    /// ⚠️ **括号深度是承重的**（PR #265 第 3 轮终审 S-d）：首版靠「下一个 `.target(` 起始行」
    /// 隐式关块 + 行首前缀匹配，三种真实存在的写法会把 `resources:` 记到**错的 target** 上：
    /// ① `.target(name: "X", resources: [...])` 写成一行 ⇒ `resources:` 不在行首 ⇒ 漏记；
    /// ② `dependencies:` 数组里嵌套的 `.target(name: "CoreDesign")`（地道 SwiftPM 写法）
    ///    被当成一个**新块**：它提前 flush 外层块、偷走外层还没读到的 `resources:`，
    ///    并注入一个幽灵 library target；
    /// ③ `targets:` 数组闭合之后出现的 `resources:` 会被记到最后一个块上。
    /// 三种都是 fail-closed（判红，不会假绿），但诊断会把读者指向一个不存在的 target
    /// ——「守卫红了却指错地方」与守卫没红同样浪费一次排查。
    /// ⇒ 用括号深度界定块的起止：块内的 `.target(` 不再开新块，块外的 `resources:` 不再归属。
    static func declaredTargets(
        manifestText text: String, sourceLocation: SourceLocation = #_sourceLocation
    ) -> [DeclaredTarget] {
        /// 每种 target 构造器的前缀，与「它算不算 library target」。
        let starters: [(prefix: String, isLibrary: Bool)] = [
            (".target(", true),
            (".testTarget(", false), (".executableTarget(", false), (".macro(", false),
            (".binaryTarget(", false), (".plugin(", false), (".systemLibrary(", false),
        ]
        var out: [DeclaredTarget] = []
        var open = false
        var depth = 0
        var openedAtLine = 0
        var currentName: String?
        var currentIsLibrary = false
        var currentHasResources = false
        var currentHasPath = false
        var awaitingName = false

        func flush() {
            guard open else { return }
            if let name = currentName {
                // ⚠️ **`path:` 是 fail-open 的入口，必须当场判红**（PR #297 终审 S-2）：
                // `sourcesURL(of:)` 按 **target 名**推根（`Sources/<name>`），
                // `.target(name: "Foo", path: "Sources/Bar")` 会让五族守卫扫错树，
                // 而「目录存在」与「名字双向差集」两道现有判据**双双满足** ⇒ 无人接住。
                // ⇒ 在解析器里堵死：出现 `path:` 就报，不让它悄悄生效。
                if currentIsLibrary && currentHasPath {
                    Issue.record("""
                    Package.swift:\(openedAtLine) 的 library target `\(name)` 写了 `path:` ——
                    `GuardScanRoots.sourcesURL(of:)` 按 target **名**推根（`Sources/<name>`），
                    重定向之后守卫会扫**错的树**，而 `assertRootsExist` 与
                    `libraryTargetsAreCoveredByScanRoots` 都照样满足 ⇒ 静默 fail-open。
                    处置：把源码放回 `Sources/\(name)/`，或同时扩 `DeclaredTarget` 的 schema
                    与 `sourcesURL(of:)` 让根列表读得到 `path:`。**不要**直接删本断言。
                    """, sourceLocation: sourceLocation)
                }
                out.append(.init(name: name, isLibrary: currentIsLibrary, hasResources: currentHasResources))
            } else {
                Issue.record("""
                Package.swift:\(openedAtLine) 的 target 块解析不出 name（name 可能不是字符串字面量）
                —— 静默丢弃它意味着该 target 既不进 `GuardScanRoots.targetNames` 的双向差集、
                也不进 `.module` 归属表，两者都是 fail-open 方向的漏。
                处置：把 name 写成字面量，或扩展本解析器。
                """, sourceLocation: sourceLocation)
            }
            open = false
            depth = 0
            currentName = nil
            currentIsLibrary = false
            currentHasResources = false
            currentHasPath = false
            awaitingName = false
        }

        // ⚠️ **词法状态跨行保持**（PR #265 第 4 轮终审 I-3）：块注释 `/* */` 与多行字符串
        // `"""` 都能跨行，逐行独立地剥注释解不了它们（详见 `code(of:state:)`）。
        var lex = ManifestLexState()

        for (index, raw) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            // 行首整行注释、行尾 `//`、跨行 `/* */`、多行字符串体全部在 `code(of:state:)`
            // 里剥掉（**按引号状态剥**，否则 `"https://…"` 里的 `//` 会把半行代码连同
            // 它的右括号一起吃掉，括号深度就再也回不到 0）。
            let code = Self.code(of: line, state: &lex)
            // ⚠️ **块内不再开新块**：`dependencies: [.target(name: "CoreDesign")]` 是地道写法。
            if !open, let starter = starters.first(where: { code.hasPrefix($0.prefix) }) {
                open = true
                openedAtLine = index + 1
                currentIsLibrary = starter.isLibrary
                if let name = Self.quotedName(in: code) { currentName = name } else { awaitingName = true }
            } else if !open {
                continue
            } else if awaitingName, let name = Self.quotedName(in: code, atDepth: 0) {
                // ⚠️ **按深度 0 取**（PR #265 第 5 轮终审 S-b）：这一行是块内单独一行的 `name: "X",`，
                // `name:` 就在最外层。此前用 `code.hasPrefix("name:")` 前缀匹配，
                // `name : "X"`（合法 Swift）匹配不上 ⇒ 整块被丢弃并报「name 可能不是字面量」。
                currentName = name
                awaitingName = false
            }
            // ⚠️ 一行写完的 `.target(name: "X", resources: [...])` 也要认 ⇒ 不能要求行首。
            if code.contains("resources:") { currentHasResources = true }
            // ⚠️ 与上一行同一条口径（一行写完的 target 也要认 ⇒ 不要求行首）。
            if code.contains("path:") { currentHasPath = true }
            depth += Self.parenDelta(of: code)
            if depth <= 0 { flush() }
        }
        flush()
        return out
    }

    /// 逐行扫 manifest 时**跨行保持**的词法状态。
    ///
    /// ⚠️ 只有块注释与多行字符串需要跨行——单行字符串字面量在 Swift 里不能跨行，
    /// 行尾 `//` 注释到行尾自然结束。
    nonisolated struct ManifestLexState: Hashable, Sendable {
        /// ⚠️ **是深度不是布尔**（PR #265 第 5 轮终审 S-a）：**Swift 的块注释可嵌套**
        /// （`/* 老写法： /* 更老的写法 */ .target(name: "Ghost") */` 整段都是注释）。
        /// 布尔版遇**第一个** `*/` 就出注释 ⇒ 其后的内容重新被当成代码 ⇒
        /// `90da0b1` 声称堵掉的「注释掉的 target 变成幽灵 library target」换个入口原样复现，
        /// 且 `Issue.record` 一条都没有。
        var blockCommentDepth = 0
        var inMultilineString = false
    }

    /// 剥掉这一行里的**全部非代码文本**，返回剩下的代码。
    ///
    /// 处理四种：① 行尾 / 整行 `//` 注释；② 跨行块注释 `/* … */`；
    /// ③ 多行字符串 `"""…"""`；④ 单行字符串字面量（其内容**保留**，`firstQuoted` /
    /// `quotedName` 要从里面取 name；括号由 `parenDelta` 自己按引号状态排除）。
    ///
    /// ⚠️ **块注释与多行字符串是 PR #265 第 4 轮终审 I-3 补的**：首版只认 `//`
    /// （行首 `hasPrefix("//")` + `code(of:)` 里的行尾剥离），块注释与 `"""` 的内容
    /// 因此被当成代码，实测两种真实后果——
    /// · 块注释里含**未配对的括号**（`/* 见 Package.swift 的 .target( 用法 */` 只有左括号）
    ///   ⇒ `depth` 永远回不到 0 ⇒ 当前块吃掉其后**所有** target，后面的 target 整个丢失；
    /// · 块注释里含 `.target(`（注释掉的一段 manifest）⇒ 被当成一个真块解析
    ///   ⇒ **注释掉的 target 变成幽灵 library target**（还可能带上 `resources:`）。
    /// 第二条与首版靠「下一个 `.target(` 起始行隐式关块」时的 ② 号病同形，
    /// 只是换了个入口复现——本函数是那条入口的堵法。
    ///
    /// ⚠️ **块注释按深度计数，因为 Swift 的块注释可嵌套**（PR #265 第 5 轮终审 S-a）：
    /// 布尔版遇第一个 `*/` 就出注释，于是嵌套注释的**尾部**重新被当成代码
    /// ——上面第二条「幽灵 target」换个入口原样复现（实测
    /// `/* 老写法： /* 更老的写法 */ .target(name: "Ghost", …), */` 产出 `Ghost`，零 `Issue.record`）。
    /// 多行字符串同理：`"""` 是**奇数个**引号，逐行重置的 `inString` 会被它带偏，
    /// 字符串体里的 `.target(` / 括号会被当成代码。
    ///
    /// ⚠️ 失败方向仍是 fail-closed（丢块 ⇒ 双向差集判红），但诊断会把读者指向
    /// 一个不存在的 target——「守卫红了却指错地方」与守卫没红同样浪费一次排查。
    static func code(of line: String, state: inout ManifestLexState) -> String {
        var out = ""
        let chars = Array(line)
        var index = 0
        var inString = false
        while index < chars.count {
            let character = chars[index]
            if state.blockCommentDepth > 0 {
                // ⚠️ 嵌套：注释里再开一层 `/*` 要加深，`*/` 只关掉最内那一层。
                if character == "/", index + 1 < chars.count, chars[index + 1] == "*" {
                    state.blockCommentDepth += 1
                    index += 2
                } else if character == "*", index + 1 < chars.count, chars[index + 1] == "/" {
                    state.blockCommentDepth -= 1
                    index += 2
                } else {
                    index += 1
                }
                continue
            }
            if state.inMultilineString {
                if character == "\"", index + 2 < chars.count,
                   chars[index + 1] == "\"", chars[index + 2] == "\"" {
                    state.inMultilineString = false
                    index += 3
                } else {
                    index += 1
                }
                continue
            }
            if inString {
                // 转义：连同被转义的那个字符一起原样带走（`\"` 不能关闭字符串）。
                if character == "\\", index + 1 < chars.count {
                    out.append(character)
                    out.append(chars[index + 1])
                    index += 2
                    continue
                }
                out.append(character)
                if character == "\"" { inString = false }
                index += 1
                continue
            }
            if character == "\"" {
                if index + 2 < chars.count, chars[index + 1] == "\"", chars[index + 2] == "\"" {
                    state.inMultilineString = true
                    index += 3
                    continue
                }
                inString = true
                out.append(character)
                index += 1
                continue
            }
            if character == "/", index + 1 < chars.count, chars[index + 1] == "/" { break }
            if character == "/", index + 1 < chars.count, chars[index + 1] == "*" {
                state.blockCommentDepth += 1
                index += 2
                continue
            }
            out.append(character)
            index += 1
        }
        return out.trimmingCharacters(in: .whitespaces)
    }

    /// 无状态的便捷重载——单行输入（不跨行的注释 / 字符串）用它。
    static func code(of line: String) -> String {
        var state = ManifestLexState()
        return Self.code(of: line, state: &state)
    }

    /// 一行代码的括号净增量（字符串字面量里的括号不计）。
    static func parenDelta(of code: String) -> Int {
        var inString = false
        var escaped = false
        var delta = 0
        for character in code {
            if escaped { escaped = false; continue }
            if character == "\\", inString { escaped = true; continue }
            if character == "\"" { inString.toggle(); continue }
            guard !inString else { continue }
            if character == "(" { delta += 1 }
            if character == ")" { delta -= 1 }
        }
        return delta
    }

    /// 解析 `Package.swift` 里声明的 **library** target 名（不含 `.testTarget` 等）。
    static func declaredLibraryTargets() throws -> [String] {
        try Self.declaredTargets().filter(\.isLibrary).map(\.name)
    }

    /// 取 `name:` 标签**紧随其后**的字符串字面量。取不到（name 不是字面量 / 是插值）返回 `nil`。
    ///
    /// `wantedDepth` 是 `name:` 相对**本段代码起点**的括号深度：调用点若传的是
    /// `.target(name: "X", …)` 这一整行则为 `1`（`.target(` 之后），若传的是
    /// 单独一行的 `name: "X",` 则为 `0`。
    ///
    /// ⚠️ **不能取整行的第一个引号串**（PR #265 第 4 轮终审 I-4）：首版是
    /// `firstQuoted(in: code)`，于是 `.target(name: shadersName, path: "Sources/Shaders")`
    /// 会产出一个**名叫 `"Sources/Shaders"` 的幽灵 library target**，且
    /// `Issue.record` 一条都不发——本文件的文档却写着「非字面量 name 会让 `firstQuoted`
    /// 返回 `nil` ⇒ 走 `awaitingName` ⇒ 丢块并 `Issue.record`」，两者不符。
    /// 方向仍是 fail-closed（差集判红），但**静默改名比丢弃更难排查**：读者会拿着
    /// 一个从没在 manifest 里出现过的 target 名去找。
    /// ⇒ 只认紧跟 `name:` 的字面量；取不到就落回 `awaitingName` / `Issue.record`。
    ///
    /// ⚠️⚠️ **上一版仍留着三条静默路径**（PR #265 第 5 轮终审 S-b），本版一并堵掉：
    /// · **插值字面量**——`.target(name: "\(prefix)Alpha")` 产出一个名叫
    ///   `\(prefix)Alpha` 的 target 且零 `Issue.record`，与 I-4 要治的「静默改名」同类；
    /// · **`range(of: "name:")` 取整行第一个**——`.target(dependencies:
    ///   [.product(name: "Inner", package: "p")], name: "Alpha")` 产出一个名叫 **`Inner`**
    ///   的 target（多行写法不中招，只有单行 deps-在前会撞上）⇒ 改成按**括号深度**定位；
    /// · **`name :`（冒号前空格）是合法 Swift**——此前整块被丢弃并报「name 可能不是
    ///   字符串字面量」，**诊断误导**（那行的 name 明明就是字面量）⇒ 容忍标签与冒号之间的空白。
    ///
    /// ⚠️ 标签必须落在**标识符边界**上：`packageName:` / `names:` 不得被当成 `name:`。
    static func quotedName(in code: String, atDepth wantedDepth: Int = 1) -> String? {
        let chars = Array(code)
        var index = 0
        var depth = 0
        var inString = false
        while index < chars.count {
            let character = chars[index]
            if inString {
                if character == "\\", index + 1 < chars.count { index += 2; continue }
                if character == "\"" { inString = false }
                index += 1
                continue
            }
            if character == "\"" { inString = true; index += 1; continue }
            if character == "(" { depth += 1; index += 1; continue }
            if character == ")" { depth -= 1; index += 1; continue }
            guard depth == wantedDepth, let valueStart = Self.nameLabelEnd(chars, at: index) else {
                index += 1
                continue
            }
            // 标签命中但值不是字符串字面量（`name: shadersName`）⇒ 继续找同深度的下一个，
            // 找不到就返回 `nil` ⇒ 调用方落回 `awaitingName` / `Issue.record`。
            if let name = Self.stringLiteralBody(chars, at: valueStart) { return name }
            index += 1
        }
        return nil
    }

    /// `chars[index...]` 是否正是标签 `name`（允许 `name :` 的空白），是则返回值的起始下标。
    private static func nameLabelEnd(_ chars: [Character], at index: Int) -> Int? {
        let label = Array("name")
        guard index + label.count <= chars.count,
              Array(chars[index..<(index + label.count)]) == label
        else { return nil }
        // 标识符边界：前后都不能再接标识符字符（挡掉 `packageName:` / `names:`）。
        if index > 0, Self.isIdentifierCharacter(chars[index - 1]) { return nil }
        var cursor = index + label.count
        if cursor < chars.count, Self.isIdentifierCharacter(chars[cursor]) { return nil }
        while cursor < chars.count, chars[cursor] == " " || chars[cursor] == "\t" { cursor += 1 }
        guard cursor < chars.count, chars[cursor] == ":" else { return nil }
        cursor += 1
        while cursor < chars.count, chars[cursor] == " " || chars[cursor] == "\t" { cursor += 1 }
        return cursor
    }

    /// 从 `index` 读一个字符串字面量的内容；不是字面量、或**含插值**则返回 `nil`。
    private static func stringLiteralBody(_ chars: [Character], at index: Int) -> String? {
        guard index < chars.count, chars[index] == "\"" else { return nil }
        var body = ""
        var cursor = index + 1
        while cursor < chars.count {
            let character = chars[cursor]
            if character == "\\", cursor + 1 < chars.count {
                // ⚠️ 插值不是名字：`"\(prefix)Alpha"` 必须走 `Issue.record`，不得静默产出。
                if chars[cursor + 1] == "(" { return nil }
                body.append(character)
                body.append(chars[cursor + 1])
                cursor += 2
                continue
            }
            if character == "\"" { return body }
            body.append(character)
            cursor += 1
        }
        return nil
    }

    private static func isIdentifierCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_"
    }

    // MARK: - 测试根与文档根（`#287`：判据引用守卫的扫描面也要有单一来源）

    /// `Tests/` —— 全部 test target 源码的公共父目录。
    static var testsRoot: URL { Self.repoRoot.appendingPathComponent("Tests") }

    /// `Tests/` 下的每个子目录 = 一个 test target 的源码根。
    ///
    /// ⚠️ **不做任何白名单**：新增 test target 只要按 SwiftPM 约定落在 `Tests/<名字>/`
    /// 就自动进扫描范围；`BitmapExpectationGuard.scanRootsMatchTheManifest` 与
    /// `JudgementReferenceGuard.scanFaceMatchesTheManifest` 各自与 `Package.swift`
    /// 里的非 library target 做**双向**差集，堵住「新 target 静默逃出守卫」。
    ///
    /// ⚠️ `#287` 之前这份实现住在 `BitmapExpectationGuard` 里。第二条守卫要用同一份根时，
    /// 复制一份必然漂——本文件既然是「根列表的单一来源」，测试根就该在这里，
    /// 而不是在某一条守卫的私有实现里。
    static func testRootDirectories() throws -> [URL] {
        try FileManager.default
            .contentsOfDirectory(at: Self.testsRoot, includingPropertiesForKeys: [.isDirectoryKey])
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// `docs/` —— 组件文档与 `component-registry.json` 的根。
    static var docsRoot: URL { Self.repoRoot.appendingPathComponent("docs") }

    /// `docs/` 下指定扩展名的全部文件（递归）。
    ///
    /// ⚠️ 与 `swiftFiles(in:)` 同一条 fail-closed 纪律：路径不存在 / 枚举失败时
    /// `Issue.record` 并返回空，而不是静默产出空序列。
    static func docFiles(
        extensions: Set<String> = ["md", "json"],
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> [URL] {
        guard FileManager.default.fileExists(atPath: Self.docsRoot.path) else {
            Issue.record("文档根不存在：\(Self.docsRoot.path) —— 判据无法工作，这不是「零违规」",
                         sourceLocation: sourceLocation)
            return []
        }
        guard let walker = FileManager.default.enumerator(
            at: Self.docsRoot, includingPropertiesForKeys: nil
        ) else {
            Issue.record("无法枚举文档目录：\(Self.docsRoot.path)（权限或 IO 异常）—— 判据无法工作",
                         sourceLocation: sourceLocation)
            return []
        }
        var out: [URL] = []
        for case let url as URL in walker where extensions.contains(url.pathExtension) { out.append(url) }
        return out.sorted { $0.path < $1.path }
    }

    /// 仓库**根目录**下的 `.md`（不递归）—— `CLAUDE.md` / `AGENTS.md` / `README.md` /
    /// `ACKNOWLEDGEMENTS.md` 这一层。
    ///
    /// ⚠️ `#287` 第 1 轮终审：指引文件本身就住在这一层，而 `docFiles()` 只看 `docs/`
    /// ⇒ 「判据引用必须指得到真实符号」这条纪律**对写着这条纪律的那份文件本身不生效**。
    /// 实测代价不是零：那一层当时活着两条真悬空引用（`CLAUDE.md` 与 `AGENTS.md` 各一条
    /// 同文的 `ComponentRegistryGuard` 单根声称，`#270` 之后已失真）。
    ///
    /// ⚠️ **不递归**是刻意的：`.claude/`（epic / PRD 归档，173 个 `.md`）是历史文档，
    /// 按「撤回痕迹拆开写」的纪律回改它们等于篡改归档，理由写在
    /// `JudgementReferenceGuard` 文件头的「找到但堵不住的路径」一节。
    ///
    /// ⚠️ **扩展名写死成 `md`，与 `docFiles(extensions:)` 的可配置形态不对称——这是刻意的**
    /// （`#287` 第 2 轮终审 S-5）：`docs/` 那棵树里 `.json` 是**语料**
    /// （`component-registry.json` 的 `notes` 写着判据引用，`#287` 的验收逐字要求扫它），
    /// 而仓库根这一层的非 `.md` 今天恰好四份，要么是**构建配置**（`Package.swift` /
    /// `Package.resolved` / `.gitignore`）、要么是**法律文本**（`LICENSE`）——都不含
    /// 判据引用，扫进来只会平添噪声。（⚠️ 上一版把 `LICENSE` 一并归进「构建配置」，
    /// 归错了类：`#287` 第 3 轮终审 S-c。四份是**今天**的枚举，这一层随时可能多出别的
    /// 非 `.md` 文件，届时这句话要重新核。⚠️ 并且「四份」只在**普通 clone** 里成立：
    /// 在 git worktree 里 `.git` 是一个**文件**而不是目录 ⇒ 那里是五份
    ///（`#287` 第 4 轮终审 S2）。对本函数无影响——过滤条件是 `pathExtension != "md"`，
    /// 与是不是目录无关；登记在此以免下一个读者按「四份」去核而对不上。）
    /// ⇒ 两个同族函数口径不同是因为两片语料的性质不同，不是漏了一个参数。
    /// 真要扩到别的扩展名时，把这段理由一并改掉。
    ///
    /// ⚠️ 与 `docFiles()` / `swiftFiles(in:)` 一样**按文件系统枚举、不按 git 索引**：
    /// 未跟踪的散文件照样进面。仓库根是散文件最容易落地的一层 ⇒ 已登记在
    /// `JudgementReferenceGuard` 文件头的「找到但堵不住的路径」一节。
    ///
    /// 与 `swiftFiles(in:)` / `docFiles()` 同一条 fail-closed 纪律。
    ///
    /// ⚠️ **`in root:` 这个参数只为一件事存在：让上面那条「按文件系统枚举」的声称
    /// 本身可判据化**（`#287` 第 3 轮终审 I-E）。上一版把这条性质写成了承重注释，却
    /// 没有任何判据钉住它——`JudgementReferenceGuard` 的 `pinnedRootDocuments` 是
    /// **超集**检查，对「枚举退化成恰好那四份已知指引」的**白名单式收窄**天然无感
    ///（实测变异 `DRIFT-whitelist`：改成白名单 + 往根放一份含两条真悬空引用的未跟踪
    /// `.md` ⇒ 六个测试全绿）。⇒ `rootDocFilesEnumeratesTheWholeLayer` 在**临时目录**
    /// 里放文件来钉它：临时目录里的文件天然未跟踪，且不污染仓库根。
    /// 生产调用点一律走默认实参，不传 `root`。
    ///
    /// ⚠️ **但这条 fixture 的射程到本函数为止**（`#287` 第 4 轮终审 F1）：注入 `root`
    /// 只能证明**这个函数**枚举整层，证明不了「本函数的产出真的进了文档扫描面」。
    /// 实测变异 `CALLSITE-whitelist`——把同一张白名单从这里挪到**调用点**
    ///（`JudgementReferenceGuard` 的 `docScanFace`）——`rootDocFilesEnumeratesTheWholeLayer`
    /// 与 `pinnedRootDocuments` 那条超集检查**都照绿**（19/19），而往仓库根放的一份含两条
    /// 真悬空引用的未跟踪 `.md` 真的逃了出去。上面那句「生产调用点一律走默认实参」
    /// 在该变异下**照样成立** ⇒ 它桥不到「所以 fixture 覆盖了生产路径」。
    /// ⇒ 缺的那一半在 J2 里补（`escaped.isEmpty`：整层的每一份都在 `docScanFace()` 的
    /// 产出里），两条**组合**起来才等于「整层 ⊆ 扫描面」。
    static func rootDocFiles(
        in root: URL = GuardScanRoots.repoRoot,
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> [URL] {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: nil
        ) else {
            Issue.record("无法枚举仓库根：\(root.path)（权限或 IO 异常）—— 判据无法工作",
                         sourceLocation: sourceLocation)
            return []
        }
        return entries.filter { $0.pathExtension == "md" }.sorted { $0.path < $1.path }
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

    /// `#287` 第 3 轮终审 I-E：把「按文件系统枚举整层、未跟踪文件照样进面」从一句
    /// 承重注释变成一条判据。
    ///
    /// ⚠️ **要钉的是「整层」，不是「那四份已知指引」**：`JudgementReferenceGuard` 的
    /// `pinnedRootDocuments` 只做**超集**检查，把 `rootDocFiles(in:)` 换成一张
    /// 「只扫已知四份」的白名单时它照样满足，而随手落在仓库根的未跟踪 `.md`
    /// 就此静默逃出扫描面（实测变异 `DRIFT-whitelist` 下六个测试全绿）。
    /// ⇒ 这里刻意用一个**不在**那张表里的名字（`draft-notes.md`）当主探针。
    ///
    /// ⚠️ **本 fixture 钉的是这个函数的枚举行为，不是「扫描面的性质」**
    ///（`#287` 第 4 轮终审 F1）：把同一张白名单挪到**调用点**
    ///（`JudgementReferenceGuard` 的 `docScanFace`）时本 fixture **照绿**，未跟踪的根
    /// `.md` 照样逃出扫描面。缺的那一半由 J2 里的 `escaped.isEmpty` 补上
    ///（「整层的每一份都在 `docScanFace()` 的产出里」）⇒ 只跑本 fixture 断言不了扫描面完整，
    /// 两条要一起读。
    ///
    /// ⚠️ 在**临时目录**里做而不是往仓库根扔文件：既天然满足「未跟踪」，
    /// 又不会污染仓库根（根 `.md` 现在在扫描面内，残留文件会直接把 J1 判红）。
    @Test("`rootDocFiles(in:)` 枚举整层的 `.md`，包括未跟踪的、不在具名表里的（`#287` 第 3 轮终审 I-E）")
    func rootDocFilesEnumeratesTheWholeLayer() throws {
        let sandbox = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("GuardScanRoots-rootDocFiles-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: sandbox, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: sandbox) }

        for name in ["draft-notes.md", "README.md", "LICENSE", "Package.swift", "notes.txt"] {
            try "占位".write(to: sandbox.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }
        // ⚠️ **子目录里再放一份 `.md`，把「不递归」也钉住**（`#287` 第 4 轮终审 F6）：
        // 上一版把 `contentsOfDirectory` 换成递归的 `enumerator` 时本 fixture **照绿**
        //（全套件下是别处那条 `other` 桶下界把它抓住的——那是捡到的，不是这里设计的）。
        // 期望值不变 ⇒ 递归化会让 `nested.md` 多出来，当场判红。
        let nested = sandbox.appendingPathComponent("nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try "占位".write(to: nested.appendingPathComponent("nested.md"), atomically: true, encoding: .utf8)

        let found = GuardScanRoots.rootDocFiles(in: sandbox).map(\.lastPathComponent)
        #expect(found == ["README.md", "draft-notes.md"], """
        `rootDocFiles(in:)` 枚举到 \(found) —— 期望恰为整层的两份 `.md`（按路径排序）。
        · 少了 `draft-notes.md` ⇒ 枚举退化成了某种**白名单**：随手落在仓库根的未跟踪
          `.md` 就此静默逃出扫描面，而 J1 / J2 的具名表是超集检查、不会响。
        · 多出 `LICENSE` / `Package.swift` / `notes.txt` ⇒ 扩展名过滤失效，
          非散文文件会被当成语料扫。
        · 多出 `nested.md` ⇒ 枚举变成了**递归**：仓库根下的 `.claude/**`（173 个归档
          `.md`）会整片涌进扫描面，而那一片是**有意不扫**的，理由见
          `JudgementReferenceGuard` 文件头的《找到但堵不住的路径》一节。
        """)
    }

    @Test("manifest 解析器：三种畸形写法不再把 `resources:` 归给错的 target（终审 S-d）")
    func manifestParserHandlesAwkwardShapes() {
        // ① 一行写完的 target ⇒ `resources:` 不在行首，首版漏记。
        let inline = GuardScanRoots.declaredTargets(manifestText: """
        targets: [
            .target(name: "Alpha", resources: [.process("Resources")]),
            .target(name: "Beta"),
        ]
        """)
        #expect(inline.map(\.name) == ["Alpha", "Beta"])
        #expect(inline.first(where: { $0.name == "Alpha" })?.hasResources == true,
                "一行写完的 `resources:` 漏记 —— `.module` 归属表会说 Alpha 没有资源包")
        #expect(inline.first(where: { $0.name == "Beta" })?.hasResources == false)

        // ② `dependencies:` 里嵌套的 `.target(name:)`：首版把它当新块 ⇒ 提前 flush 外层、
        //    偷走外层的 `resources:`、并注入一个幽灵 library target `CoreDesign`。
        let nested = GuardScanRoots.declaredTargets(manifestText: """
        targets: [
            .target(
                name: "Effects",
                dependencies: [
                    .target(name: "CoreDesign"),
                ],
                resources: [.process("Resources")]
            ),
        ]
        """)
        #expect(nested.map(\.name) == ["Effects"],
                "嵌套的 `.target(name:)` 被当成了一个独立 target —— 幽灵条目会顶动根列表的双向差集")
        #expect(nested.first?.hasResources == true,
                "外层 target 的 `resources:` 被嵌套块偷走了")

        // ③ `targets:` 数组闭合之后的 `resources:` 不再归给最后一个块。
        let trailing = GuardScanRoots.declaredTargets(manifestText: """
        targets: [
            .target(name: "Gamma"),
        ]
        // 下面这行不属于任何 target 块
        resources: [.process("Resources")]
        """)
        #expect(trailing.map(\.name) == ["Gamma"])
        #expect(trailing.first?.hasResources == false,
                "块外的 `resources:` 被记到了最后一个 target 上")

        // ④ 字符串里的 `//` 不能被当成注释剥掉——剥掉会连右括号一起吃，块永远关不上。
        let url = GuardScanRoots.declaredTargets(manifestText: """
        targets: [
            .target(
                name: "Delta",
                dependencies: ["https://example.com/not-a-comment"]
            ),
            .target(name: "Epsilon"),
        ]
        """)
        #expect(url.map(\.name) == ["Delta", "Epsilon"])

        // ⑤ 种类判别不变：`.testTarget` 不是 library target。
        let kinds = GuardScanRoots.declaredTargets(manifestText: """
        targets: [
            .target(name: "Lib"),
            .testTarget(name: "LibTests", dependencies: ["Lib"]),
        ]
        """)
        #expect(kinds.filter(\.isLibrary).map(\.name) == ["Lib"])
    }

    /// PR #265 **第 4 轮**终审 I-3：块注释 / 多行字符串此前完全不被处理。
    ///
    /// ⚠️ 四条探针里前两条与 S-d 的形态②**同级别**（幽灵 target / 丢 target），
    /// 只是换了个入口复现——S-d 换实现时新开的盲区，此前没登记在任何口子里。
    @Test("manifest 解析器：块注释与多行字符串不再吃掉 / 伪造 target（PR #265 第 4 轮终审 I-3）")
    func manifestParserHandlesBlockCommentsAndMultilineStrings() {
        // ① 块注释里含**未配对**的括号 ⇒ 首版 `depth` 永远回不到 0 ⇒ 其后的 target 全丢。
        // ⚠️ 注释必须落在**块内**才复现：块外的行走 `else if !open { continue }`，
        // `parenDelta` 根本不参与——这一点实测过，别把 fixture 写在 `targets: [` 与
        // 第一个 `.target(` 之间然后以为它证伪了什么。
        let unbalanced = GuardScanRoots.declaredTargets(manifestText: """
        targets: [
            .target(
                name: "Alpha"
                /* 历史备注：早期这里写的是 .target( 形态，见 #244 */
            ),
            .target(name: "Beta"),
        ]
        """)
        #expect(unbalanced.map(\.name) == ["Alpha", "Beta"],
                "块注释里的未配对括号把后面的 target 吃掉了 —— 丢失的 target 完全不受守卫覆盖")

        // ② 块注释里含 `.target(` ⇒ 首版把**注释掉的** target 解析成幽灵 library target，
        //    还会连它的 `resources:` 一起记上（`.module` 归属表因此凭空多一条）。
        let commentedOut = GuardScanRoots.declaredTargets(manifestText: """
        targets: [
            /*
            .target(
                name: "Ghost",
                resources: [.process("Resources")]
            ),
            */
            .target(name: "Real"),
        ]
        """)
        #expect(commentedOut.map(\.name) == ["Real"],
                "注释掉的 target 变成了幽灵条目 —— 双向差集会红在一个 manifest 里根本不存在的名字上")
        #expect(commentedOut.first?.hasResources == false,
                "注释里的 `resources:` 被记到了真 target 上 —— `.module` 归属判据会说 Real 有资源包")

        // ③ 多行字符串体同样不能当代码读：`"""` 是**奇数个**引号，逐行重置的引号状态
        //    会被它带偏，字符串里的括号 / `.target(` 会吃掉后面的 target。
        let multiline = GuardScanRoots.declaredTargets(manifestText: #"""
        targets: [
            .target(
                name: "Doc",
                swiftSettings: [.define("""
                一段说明：这里故意写 .target( 和一个左括号 (
                """)]
            ),
            .target(name: "Next"),
        ]
        """#)
        #expect(multiline.map(\.name) == ["Doc", "Next"],
                "多行字符串体被当成代码 —— 后面的 target 丢失或多出幽灵条目")

        // ④ 非字面量 `name:` 同行还有别的字面量时**不得静默改名**（PR #265 第 4 轮终审 I-4）。
        //    期望：产出零个 target + 一条 `Issue.record`。
        //    ⚠️ `withKnownIssue` 在这里**是一颗牙不是消音器**：块内一条 issue 都没记录时
        //    它自己会判红 ⇒ 「解析不出 name 必须报出来」这条被机器钉住，而不是靠读文档。
        //    （代价：本次 `swift test` 的 known issue 计数 2 → 3，那一条就是它。）
        var renamed: [GuardScanRoots.DeclaredTarget] = []
        withKnownIssue("非字面量 name 必须 Issue.record，不得静默改名") {
            renamed = GuardScanRoots.declaredTargets(manifestText: """
            targets: [
                .target(name: shadersName, path: "Sources/Shaders"),
            ]
            """)
        }
        #expect(renamed.isEmpty, """
        `.target(name: shadersName, path: "Sources/Shaders")` 被解析成了 \(renamed.map(\.name))
        —— 首版取「整行第一个引号串」，于是产出一个名叫 "Sources/Shaders" 的幽灵 library target
        且零 `Issue.record`。方向仍 fail-closed，但**静默改名比丢弃更难排查**：
        读者会拿着一个从没在 manifest 里出现过的名字去找。
        """)
    }

    /// PR #265 **第 5 轮**终审 S-a / S-b：三条**静默**路径（不 `Issue.record`、方向却错）。
    ///
    /// ⚠️ 三条都与 I-3 / I-4 同级别——产出一个 manifest 里根本不存在的 target 名，
    /// 双向差集照样判红，但读者拿着那个名字无处可查。
    @Test("manifest 解析器：嵌套块注释 / 插值 name / 同行多个 `name:`（PR #265 第 5 轮终审 S-a / S-b）")
    func manifestParserHandlesNestedCommentsAndTrickyNames() {
        // ① **Swift 的块注释可嵌套**（`/* /* */ */` 合法）。首版遇**第一个** `*/` 就出注释
        //    ⇒ 注释尾部的内容重新被当成代码 ⇒ `90da0b1` 声称堵掉的那条「幽灵 target」
        //    换个入口原样复现，且 `Issue.record` 一条都没有。
        let nested = GuardScanRoots.declaredTargets(manifestText: """
        targets: [
            /* 老写法：
               /* 更老的写法 */
               .target(name: "Ghost", resources: [.process("R")]),
            */
            .target(name: "Alpha"),
            .target(name: "Beta"),
        ]
        """)
        #expect(nested.map(\.name) == ["Alpha", "Beta"],
                "嵌套块注释里被注释掉的 target 变成了幽灵条目 —— 双向差集会红在一个不存在的名字上")
        #expect(nested.allSatisfy { !$0.hasResources },
                "嵌套注释里的 `resources:` 被记到了真 target 上 —— `.module` 归属表凭空多一条")

        // ② **插值字面量的 name 不得静默产出**：`"\(prefix)Alpha"` 是一段代码不是一个名字。
        //    期望零 target + 一条 `Issue.record`（与 I-4 的非字面量 name 同一条纪律：
        //    丢弃 + 报出来，好过静默改名）。
        //    ⚠️ 本次 `swift test` 的 known issue 计数因此再 +1，那一条就是它。
        var interpolated: [GuardScanRoots.DeclaredTarget] = []
        withKnownIssue("插值 name 必须 Issue.record，不得静默产出一个含插值的 target 名") {
            interpolated = GuardScanRoots.declaredTargets(manifestText: ##"""
            targets: [
                .target(name: "\(prefix)Alpha"),
            ]
            """##)
        }
        #expect(interpolated.isEmpty, """
        插值 name 被静默产出成了 \(interpolated.map(\.name))
        —— 那个名字在 manifest 里根本不存在，读者查不到它。
        """)

        // ③ `name:` 必须取**本块自己的**那一个：单行写法里 `dependencies:` 在前时，
        //    「整行第一个 `name:`」会取到 `.product(name: "Inner", …)` 的那个
        //    ⇒ 产出一个名叫 `Inner` 的 target，且零 `Issue.record`。
        //    （多行写法不中招——那正是它此前没被发现的原因。）
        let depsFirst = GuardScanRoots.declaredTargets(manifestText: """
        targets: [
            .target(dependencies: [.product(name: "Inner", package: "p")], name: "Alpha"),
        ]
        """)
        #expect(depsFirst.map(\.name) == ["Alpha"],
                "同行的内层 `name:` 被当成了 target 名 —— 静默改名，双向差集会红在 `Inner` 上")

        // ④ `name :`（冒号前空格）是**合法 Swift**。此前整块被丢弃并报
        //    「name 可能不是字符串字面量」——诊断把读者指向一个根本不存在的问题。
        let spaced = GuardScanRoots.declaredTargets(manifestText: """
        targets: [
            .target(name : "Alpha"),
        ]
        """)
        #expect(spaced.map(\.name) == ["Alpha"],
                "`name :` 被判成非字面量 —— 诊断误导：那行的 name 明明就是字符串字面量")
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

    /// PR #297 终审 S-2：`Sources/<targetName>` 这条路径推断是一条**静默 fail-open**
    /// 路径 —— `.target(name: "Foo", path: "Sources/Bar")` + 陈旧的 `Sources/Foo/`
    /// 会让五族守卫扫错树，而「目录存在」与「名字双向差集」两道现有判据双双满足。
    /// ⇒ 解析器里已改成判红。本条是那条判红的**变红自证**（合成 manifest，不碰磁盘）。
    @Test("manifest 解析器：library target 写 `path:` ⇒ 当场判红（终审 S-2 的 fail-open 入口）")
    func manifestParserFlagsExplicitTargetPath() {
        // ① 正例：写了 `path:` 的 library target 必须报 issue。
        withKnownIssue("合成 manifest 故意写 path: —— 本块若不记录 issue 说明 fail-open 入口又开了") {
            _ = GuardScanRoots.declaredTargets(manifestText: """
            targets: [
                .target(name: "Foo", path: "Sources/Bar"),
            ]
            """)
        }

        // ② 反例（承重）：不写 `path:` 就不许报 —— 否则上面那条会被一条恒报的断言喂饱。
        //    ⚠️ 真实 `Package.swift` 侧由 `libraryTargetsAreCoveredByScanRoots` 覆盖
        //    （它每次都解析真 manifest，若解析器乱报 issue 那条会红）。
        let clean = GuardScanRoots.declaredTargets(manifestText: """
        targets: [
            .target(name: "Foo", resources: [.process("Resources")]),
            .testTarget(name: "FooTests", dependencies: ["Foo"]),
        ]
        """)
        #expect(clean.map(\.name) == ["Foo", "FooTests"], "无 path: 的合成 manifest 解析结果变了")
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

    /// `.module` 归属的**唯一**权威判据，a11y 守卫不再自己重复断言一遍
    /// （PR #265 终审 I-4 / P-1）。
    ///
    /// ⚠️ **本条不禁止新 target 拥有资源包**——首版在「新 target 有了 Resources」时
    /// `Issue.record`，那是**硬测试失败**，尽管消息自称「只是提醒，不是禁令」。
    /// 而 `ChromeTextLiteralGuard` 规定的补救措施逐字就是「给该 target 声明它自己的
    /// String Catalog（`Package.swift` 的 `resources:` + `Sources/<target>/Resources/`）」
    /// ⇒ 照守卫说的做 ⇒ 测试红。**守卫不许禁止自己开出的处方。**
    /// ⇒ 现状只 `print`，真正的断言换成一条**不自相矛盾**的一致性判据：
    /// manifest 的 `resources:` 与 `Sources/<target>/Resources/` 目录必须同进同退。
    /// 只建目录不声明 ⇒ SwiftPM 只报 unhandled resource 警告、`.module` 根本不存在，
    /// 而写 `bundle: .module` 的文本判据会把它当「已本地化」放行（正是要防的假绿）；
    /// 只声明不建目录 ⇒ SwiftPM 直接构建失败。
    @Test("`.module` 归属：manifest 的 `resources:` 与 `Resources/` 目录同进同退")
    func moduleBundleOwnership() {
        #expect(GuardScanRoots.ownsResourceBundle("CoreDesign"),
                "Package.swift 里 CoreDesign 的 `resources:` 声明不见了 —— a11y 守卫的 `bundle: .module` 放行条失去依据")

        for target in GuardScanRoots.targetNames {
            let declared = GuardScanRoots.ownsResourceBundle(target)
            var isDirectory: ObjCBool = false
            let dirExists = FileManager.default.fileExists(
                atPath: GuardScanRoots.sourcesURL(of: target).appendingPathComponent("Resources").path,
                isDirectory: &isDirectory
            ) && isDirectory.boolValue
            #expect(declared == dirExists, """
            \(target)：Package.swift 声明了 `resources:`=\(declared)，而
            `Sources/\(target)/Resources/` 目录存在=\(dirExists) —— 两者必须一致：
            · 有目录没声明 ⇒ SwiftPM 只报 unhandled resource 警告、**不合成 `Bundle.module`**，
              但写 `bundle: .module` 的文本判据会把它当「已本地化」放行（假绿）；
            · 有声明没目录 ⇒ SwiftPM 构建直接失败。
            处置：两样一起加，或两样一起删。
            """)
            if declared, target != GuardScanRoots.primaryTargetName {
                // ⚠️ 提醒，不是禁令（见本函数文档）：新 target 有了自己的 String Catalog 之后，
                // `bundle: .module` 在它里面才开始有意义，a11y 守卫的按 target 放行逻辑值得复核。
                print("【.module 归属】\(target) 现在拥有自己的资源包 —— 请复核 `AccessibilityStringLiteralGuard` 的按 target 放行逻辑。")
            }
        }
    }

    // MARK: - manifest 解析器自身的变红自证（PR #265 终审 S-4）

    @Test("manifest 解析器：现状快照 + 非字面量 name 不被静默丢弃")
    func manifestParserSnapshot() throws {
        let targets = try GuardScanRoots.declaredTargets()
        let libraries = Set(targets.filter(\.isLibrary).map(\.name))
        #expect(libraries == Set(GuardScanRoots.targetNames),
                "manifest 解析出的 library target \(libraries.sorted()) 与根列表不符")
        // 三个 test target 必须被认出来、且**不算** library。
        let nonLibraries = Set(targets.filter { !$0.isLibrary }.map(\.name))
        #expect(nonLibraries.contains("CoreDesignTests"), "`.testTarget(` 没被解析出来 —— 解析器可能失效")
        #expect(!libraries.contains("CoreDesignTests"), "test target 被误判成 library target")
        // `resources:` 归属：解析器**真的**从 manifest 里读出了 `resources:`。
        //
        // ⚠️ **不写成 `== ["CoreDesign"]`**：那会把「新 target 声明自己的 String Catalog」
        // 判红，而那正是 `ChromeTextLiteralGuard` 开出的处方——守卫不许禁止自己开出的处方
        // （终审 I-4 的同一条病，别在这里复发一次）。承重的只有「主 target 有」这半句：
        // a11y 守卫的 `.clean` 放行条依赖它。
        #expect(GuardScanRoots.resourceOwningTargets().contains("CoreDesign"),
                "解析器没从 Package.swift 读出 CoreDesign 的 `resources:` —— `.module` 归属判据失效")
        #expect(!targets.filter(\.hasResources).isEmpty,
                "解析器一条 `resources:` 都没读出来 —— 「谁有资源包」会退化成恒 false")
    }

    // MARK: - `relativePath` 对符号链接前缀的免疫（`#311`）

    /// ⚠️ **这条判据用的是合成路径，不是磁盘上的真实文件**，理由如下。
    ///
    /// ⚠️ **理由不是「真实路径必然恒绿」**（`#313` 终审 F-2 纠正了本段的原写法）：
    /// 恒绿的只有「拿**仓库自己的**路径写判据」这一种——仓库在 `/Users/…` 下时
    /// `#filePath` 与枚举结果不分叉，怎么断言都绿。
    /// **判据自己在临时目录里造一棵 fixture 树的写法并不恒绿**：它在任何 checkout 位置
    /// 都能复现分叉（实测：在 `/Users` checkout 里跑，串替换版照样吐 `/privateSources/…`）。
    /// 那条路已经走通并落地成两条**真实 fixture** 判据，与本条分工如下：
    /// · `GuardScanRootsGuard.enumeratorResolvesSymlinksInScanRootAncestor`（`#313` C-4）
    ///   ——钉住整套修法所依赖的那条 Foundation 行为：`FileManager.enumerator(at:)`
    ///   **会**解析根**祖先分量**里的符号链接（根自己的末段是符号链接时反而一条都不产出，
    ///   见 `SymlinkedScanRootFixture` 的文档）；
    /// · `ComponentJudgeScannerPathKeyTests.componentJudgeKeysAreImmuneToSymlinkDivergence`
    ///   （`#313` C-1）——钉住 `scanComponentJudgeInputs(root:)` 的台账键，
    ///   那一处此前**零判据覆盖**。
    ///
    /// ⇒ 本条留着，是因为它钉的是**真实文件造不出来的**那一格：
    /// `resolvingSymlinksInPath()` 对**不存在的路径**不去 `/private` 前缀
    ///（见 `GuardScanRoots.relativePath(_:from:)` 的文档）——文件一旦真的存在，
    /// 快路径的 `standardizedFileURL` 自己就把 `/private` 归一掉了，这一格永远走不到。
    ///
    /// **变异实证（双向；`#313` 终审后按八种形态重跑）**：把 `relativePath(_:from:)` 的
    /// 主体整体回退成 `url.path.replacingOccurrences(of: root.path + "/", with: "")`
    /// ⇒ 本条当场判红，**八种形态里红了四种**，红法各不相同（实测原文）：
    /// · 形态一 → `"/privateSources/CoreDesignEffects/Shine.swift"`（串中间被挖掉一段）；
    /// · 形态二 → `"/tmp/repo/Sources/CoreDesign/Components/Banner/Banner.swift"`
    ///   （串里没有可替换的段 ⇒ 整条绝对路径被原样当成相对路径）；
    /// · 形态四 → `"/elsewhereSources/CoreDesign/Foo.swift"`（同形态一的挖串）；
    /// · 形态八 → `Known issue was not recorded`（替换版根本没有兜底那一支，自然不记录）。
    /// 同一次变异下**两条真实 fixture 判据也一起红**（上面列的那两条），
    /// 且它们的红法与合成形态不同：给出的是一整条 `/private/var/folders/…/real/…` 绝对路径。
    /// ⚠️ **两种红法都会落进 `JudgementReferenceGuard` 的「扫描面之外」**（面的归属靠
    /// `Sources/` / `Tests/` / `docs/` 前缀判定，上面两种串都不以它们开头）
    /// ——`#309` 与 `#311` 复现里那条「各面候选引用数全 0、扫描面之外 4637 / 4857」
    /// 因此**指不出**是哪一种，别照着那行数字反推成因。
    /// 形态三 / 五 / 六 / 七在替换版下**本来就绿**，但四者的分量并不相同
    ///（`#313` 终审 C-8，逐条变异实测）：
    /// · **形态五承重**——唯一杀死「`relative(_:under:)` 的 `>` 写成 `>=`」那个变异的形态；
    /// · **形态六承重**——杀死「分量比较退化成串前缀比较」（`#313` C-2 补，补之前静默存活）；
    /// · **形态七承重**——杀死「`canonicalComponents` 的 `count >= 3` 放松成 `>= 2`」
    ///   （`#313` C-3 补，补之前静默存活）；
    /// · **形态三不承重**——实测整轮变异里它一个都没杀掉，是纯文档性的 happy path 示范，
    ///   价值在「读的人一眼看到正常 checkout 长什么样」，不在判别力。
    @Test("`relativePath` 对 /private 前缀不一致免疫，且不做串中间的替换（#311）")
    func relativePathIgnoresPrivatePrefixMismatch() {
        // 形态一：根未解析（`#filePath` 侧）、文件已解析（`FileManager` 枚举侧）
        // —— `#311` 在 xcodebuild 腿上实测到的那一种。
        #expect(
            GuardScanRoots.relativePath(
                URL(fileURLWithPath: "/private/tmp/repo/Sources/CoreDesignEffects/Shine.swift"),
                from: URL(fileURLWithPath: "/tmp/repo")
            ) == "Sources/CoreDesignEffects/Shine.swift"
        )

        // 形态二：反向（根已解析、文件未解析）。两端谁解析谁不解析取决于构建系统，
        // 判据不该只盯一个方向。
        #expect(
            GuardScanRoots.relativePath(
                URL(fileURLWithPath: "/tmp/repo/Sources/CoreDesign/Components/Banner/Banner.swift"),
                from: URL(fileURLWithPath: "/private/tmp/repo")
            ) == "Sources/CoreDesign/Components/Banner/Banner.swift"
        )

        // 形态三：两端本来就一致（`/Users/…` 下的正常 checkout）——不得被归一改坏。
        #expect(
            GuardScanRoots.relativePath(
                URL(fileURLWithPath: "/Users/somebody/CoreDesign/docs/DESIGN-FOUNDATION.md"),
                from: URL(fileURLWithPath: "/Users/somebody/CoreDesign")
            ) == "docs/DESIGN-FOUNDATION.md"
        )

        // 形态四：文件**真的**在根之外 ⇒ 原样返回绝对路径。
        // ⚠️ 这一条钉的是「不做串中间的替换」：根名整段出现在路径中间时，
        // 替换版会把它挖掉、拼出 `/elsewhereSources/CoreDesign/Foo.swift` 这种畸形串
        // 并当成相对路径继续用下去（`MaskSiteRegistryGuard` 的台账键就是这么被污染的）。
        #expect(
            GuardScanRoots.relativePath(
                URL(fileURLWithPath: "/elsewhere/tmp/repo/Sources/CoreDesign/Foo.swift"),
                from: URL(fileURLWithPath: "/tmp/repo"), expectingContainment: false
            ) == "/elsewhere/tmp/repo/Sources/CoreDesign/Foo.swift"
        )

        // 形态五：`url == root` ⇒ 没有「根内相对路径」，原样返回（与替换版行为一致）。
        #expect(
            GuardScanRoots.relativePath(
                URL(fileURLWithPath: "/tmp/repo"), from: URL(fileURLWithPath: "/tmp/repo"),
                expectingContainment: false
            ) == "/tmp/repo"
        )

        // 形态六：**分量比较 vs 串比较**（`#313` 终审 C-2）。根名是文件路径某一段的
        // **前缀**（`Repo` vs `RepoX`）⇒ 分量比较判「不在根内」、原样返回绝对路径；
        // 把 `relative(_:under:)` 退化成串前缀比较则会切在分量中间、吐出 `S/Foo.swift`。
        // ⚠️ 这一格正是 `relative(_:under:)` 存在的**全部理由**，此前无判据覆盖。
        #expect(
            GuardScanRoots.relativePath(
                URL(fileURLWithPath: "/Users/e/RepoX/S/Foo.swift"),
                from: URL(fileURLWithPath: "/Users/e/Repo"), expectingContainment: false
            ) == "/Users/e/RepoX/S/Foo.swift"
        )

        // 形态七：`canonicalComponents` 的 `count >= 3` 下界（`#313` 终审 C-3）。
        // 根就是 `/private` 本身：抹掉领头分量会把它变成 `["/"]`，于是**任何**绝对路径
        // 都成了「根内路径」。放松成 `count >= 2` ⇒ 这里会得到 `Users/somebody/y.swift`。
        #expect(
            GuardScanRoots.relativePath(
                URL(fileURLWithPath: "/Users/somebody/y.swift"),
                from: URL(fileURLWithPath: "/private"), expectingContainment: false
            ) == "/Users/somebody/y.swift"
        )

        // 形态八：兜底那一支**默认必须记一条 issue**（`#313` 终审 C-5）。
        // ⚠️ 与本文件里 `manifestParserRecordsNonLiteralTargetName` 那几块同一条纪律：
        // `withKnownIssue` 在这里**是一颗牙不是消音器**——块内一条 issue 都没记录时
        // 它会判「预期的已知问题没有发生」而红 ⇒ 这一条真的钉住了「记录发生了」。
        // 把 `Issue.record` 那一支删掉（退回静默 `return url.path`）⇒ 本块当场红。
        withKnownIssue("兜底会记录：这里故意传一个不在根下的 url，期望恰好记下一条") {
            _ = GuardScanRoots.relativePath(
                URL(fileURLWithPath: "/elsewhere/Foo.swift"),
                from: URL(fileURLWithPath: "/tmp/repo")
            )
        }
    }

    // MARK: - 枚举器会解析扫描根祖先里的符号链接（`#311` 修法的地基 / `#313` 终审 C-4）

    /// ⚠️ **整套 `#311` 修法建立在一条 Foundation 行为上，而此前没有任何判据钉住它**：
    /// `FileManager.enumerator(at:)` **会**解析根路径**祖先分量**里的符号链接——传进去一个
    /// 未解析的根，吐出来的却是解析后的路径。`#311` 的分叉就是这么来的。
    /// 哪天 Foundation 改掉这个行为，`relativePathIgnoresPrivatePrefixMismatch` 那八条
    /// **纯合成**形态会全绿（它们根本不碰枚举器），而真实扫描在符号链接 checkout 下会
    /// 重新静默失效 ⇒ 必须有一条**真实 fixture** 判据盯着这条前提本身。
    ///
    /// ⚠️ **本条同时是慢路径（`canonicalComponents`）的唯一真实用例**：
    /// `/private` 那一味分叉（`/tmp` → `/private/tmp`）快路径自己就归一掉了
    ///（`standardizedFileURL` 会做，见 `GuardScanRoots.relativePath(_:from:)` 的文档）；
    /// 而**祖先分量是普通符号链接**时快路径给 `nil`，只有慢路径能归正（实测）。
    /// ⇒ 「把慢路径删了也没人红」是**错的**，本条会红。
    @Test("`FileManager.enumerator` 会解析根祖先里的符号链接，`relativePath` 必须归一回去（#311）")
    func enumeratorResolvesSymlinksInScanRootAncestor() throws {
        let fixture = try SymlinkedScanRootFixture.make(
            rootName: "Root", files: ["Sub/A.swift": "// fixture\n"]
        )
        defer { fixture.destroy() }

        let walker = try #require(
            FileManager.default.enumerator(at: fixture.root, includingPropertiesForKeys: nil),
            "无法枚举 fixture 根 —— 判据无法工作，这不是「零违规」"
        )
        var swiftFiles: [URL] = []
        for case let url as URL in walker where url.pathExtension == "swift" { swiftFiles.append(url) }
        let file = try #require(swiftFiles.first, "fixture 里的 .swift 没被枚举出来")

        // ① 枚举器**确实**解析了根祖先里的符号链接——这正是 `#311` 分叉的来源。
        //    ⚠️ 这一条是**前提自证**：它绿了，下面那条才算真的在分叉上做的断言。
        #expect(
            !file.path.hasPrefix(fixture.root.path),
            """
            枚举器不再解析根祖先里的符号链接（根 \(fixture.root.path)，枚举得 \(file.path)）
            —— `#311` 修法据以成立的前提变了，`relativePath(_:from:)` 的归一逻辑需要重新评估。
            """
        )
        #expect(
            file.path.hasSuffix("/\(SymlinkedScanRootFixture.realDirectoryName)/Root/Sub/A.swift"),
            "枚举产出没走解析后的实体目录：\(file.path)"
        )

        // ② 分叉确实存在的前提下，根内相对路径仍必须干净。
        //    串替换版在这里把整条绝对路径原样当成相对路径。
        #expect(
            GuardScanRoots.relativePath(file, from: fixture.root) == "Sub/A.swift",
            "根内相对路径没被归一：\(GuardScanRoots.relativePath(file, from: fixture.root))"
        )
    }

}

// MARK: - `#311` 复现用的符号链接扫描根 fixture（`#313` 终审 C-1 / C-4 共用）

/// 造一棵**根的祖先分量是符号链接**的源码树，用来复现 `#311` 的路径分叉。
///
/// ⚠️ **不直接依赖 `/private`**（`#313` 终审后改的）：`/tmp` → `/private/tmp`、
/// `/var` → `/private/var` 这两条只在 macOS 上成立。iOS Simulator 的
/// `NSTemporaryDirectory()` 落在 `…/CoreSimulator/Devices/<id>/data/tmp/`，
/// **不带 `/private`**（实测：`xcodebuild` iOS 腿上原版判据当场红在
/// `file.path.hasPrefix("/private/")` 那一句）⇒ 拿 `/private` 写的 fixture 在 iOS 腿上
/// 会静默退化成「两端一致、构造不出分叉 ⇒ 恒绿」。自己造一条符号链接，两条腿都成立。
///
/// ⚠️ **符号链接必须落在根的祖先分量上，不能是根自己的末段**（实测）：
/// 给 `FileManager.enumerator(at:)` 传一个**末段就是符号链接**的目录时它**一条都不产出**
///（同一路径上 `contentsOfDirectory(atPath:)` 照常返回内容）——那是「零命中 ⇒ 零违规 ⇒ 绿」
/// 的经典假绿形态。祖先分量是符号链接时才会照常枚举，并把路径按**解析后**的形态吐出来。
///
/// 布局：
///
///     <tmp>/<uuid>/real/<rootName>/<相对路径…>
///     <tmp>/<uuid>/link -> <tmp>/<uuid>/real
///     根 = <tmp>/<uuid>/link/<rootName>          （末段是真目录）
///     枚举产出 = <tmp>/<uuid>/real/<rootName>/…  （macOS 上还会多带 `/private` 前缀）
nonisolated struct SymlinkedScanRootFixture {

    /// 实体目录名——判据要断言「枚举产出走的是解析后的那一支」，需要这个名字。
    static let realDirectoryName = "real"
    /// 符号链接名。
    static let linkDirectoryName = "link"

    /// 整棵 fixture 的容器，`destroy()` 删的就是它。
    let base: URL
    /// 交给扫描器的**未解析**根（祖先里带符号链接）。
    let root: URL

    /// - Parameters:
    ///   - rootName: 扫描根的目录名。`scanComponentJudgeInputs(root:)` 的台账键前缀取的
    ///     就是它（`root.lastPathComponent`），判据要能控制它才能写出期望值。
    ///   - files: 根内相对路径 → 文件内容。
    static func make(rootName: String, files: [String: String]) throws -> Self {
        let fileManager = FileManager.default
        let base = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("cd311-symlinked-root-\(UUID().uuidString)")
        let real = base.appendingPathComponent(Self.realDirectoryName).appendingPathComponent(rootName)
        for (relativePath, contents) in files {
            let destination = real.appendingPathComponent(relativePath)
            try fileManager.createDirectory(
                at: destination.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try Data(contents.utf8).write(to: destination)
        }
        try fileManager.createSymbolicLink(
            at: base.appendingPathComponent(Self.linkDirectoryName),
            withDestinationURL: base.appendingPathComponent(Self.realDirectoryName)
        )
        return Self(
            base: base,
            root: base.appendingPathComponent(Self.linkDirectoryName).appendingPathComponent(rootName)
        )
    }

    func destroy() {
        try? FileManager.default.removeItem(at: self.base)
    }
}
