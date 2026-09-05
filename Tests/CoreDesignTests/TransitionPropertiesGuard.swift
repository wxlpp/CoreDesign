import Foundation
import SwiftParser
import SwiftSyntax
import Testing

// MARK: - `Transition.properties` 显式声明守卫 / Explicit `properties` guard（Issue #292）
//
// ## 它堵的那条缝
//
// `Transition` 协议有 `static var properties: TransitionProperties`，**默认
// `hasMotion == true`**，而 `hasMotion` 的文档逐字是：
//
// > Whether the transition includes motion.
// > When this behavior is included in a transition, that transition will be
// > replaced by opacity when Reduce Motion is enabled.
// > Defaults to `true`.
//
// ⇒ **不声明 = 继承 `true` = Reduce Motion 下框架把整条转场换成 `.opacity`**，
// 而各转场自己写的降级形态**根本不会被求值**。`#292` 之前全仓 12 条 `Transition`
// 里有 1 条（`ParticleTransition`）就是这个形态：类型文档 / `docs/components/*.md` /
// `docs/component-registry.json` 的 `notes` 三处都在描述那条**不可达**的内层门控。
//
// ⇒ 本守卫钉的是「**新增的 `Transition` 实现必须显式声明 `properties`**」。
// 取值对不对不归它（那归 `TransitionPropertiesRoster`，运行时逐条读）。
//
// ## ⚠️ 为什么必须按**结构**判定，不能文本匹配
//
// 全仓今天有**三种**语义相同的写法：
//
// ```
// public static let properties = TransitionProperties(hasMotion: false)                       // 滤镜簇 #266
// public static var properties: TransitionProperties { .init(hasMotion: true) }               // 3D 与弹性簇 #267
// public static let properties: TransitionProperties = TransitionProperties(hasMotion: true)  // mask reveal #268 / particle #292
// ```
//
// 任何「`code.contains("static let properties: TransitionProperties")`」形态的判据都只认
// 其中一种——那正是本仓反复栽过的「守卫钉形状而非性质」。本守卫改用 SwiftSyntax
// 按**声明结构**判：①这个类型的继承子句里有没有 `Transition`；②它（或它的任一
// extension）有没有一个 `static`（或 `class`）的、名字是 `properties` 的变量声明。
// ⇒ 三种写法一视同仁，换一种新写法也照样认，而**注释里**写着同样的字不算数
//（`scannerIsStructuralNotTextual` 的 fixture ⑧ 逐字钉住这一条）。
//
// ## ⚠️ `#292` 有意**不统一**三种声明形态，理由照录
//
// issue 的验收只要求「显式声明本身就是把意图写下来」，没要求统一形态。统一的代价是
// 实打实的：`MaskRevealTransitionBodyTests.transitionDeclaresItHasMotion` 逐字钉了自己
// 那一种写法（`contains("static let properties: TransitionProperties")`），统一会让它判红、
// 得连期望串一起改；而收益在本守卫落地之后是**零**——本守卫已经把「显式声明」这件事
// 变成结构判定，形态一不一致对机器没有任何区别，对读者也只是三行长得不一样的等价代码。
// ⇒ 定案：**不统一**。上面那条判据的文档注释里「`#292` 统一声明形态的那次改动会让本条
// 判红」一句已随本 PR 更正为「`#292` 决定不统一，本条继续有效」。
//
// ## 射程与**已知绕过路径**（如实登记，本守卫不宣称完备）
//
// 1. **只扫 `Sources/`**（`GuardScanRoots.allRoots` 三根）。`Tests/` 里的探针类型
//    （`FilterTransitionTests.DefaultPropertiesProbe`、
//    `TransitionPropertiesRoster.DefaultPropertiesProbe`）**有意不声明** `properties`
//    ——它们的全部价值就是读协议默认值。放进射程会把它们判红。
// 2. **嵌套类型只取最内层的名字**（`struct Outer { struct Inner: Transition {} }` 记作
//    `Inner`）。同名嵌套类型会在花名册里塌成一条。今天全仓 12 条全是顶层类型。
// 3. **泛型 / 条件式 extension 里的 `properties` 照样算数**——本守卫不做语义检查，
//    `extension Foo where T: Bar { static var properties … }` 会被记成"声明了"，
//    而编译器可能认为它不满足协议。这个方向是 fail-open 的，但那种代码编译不过，
//    所以实际上由编译器兜住。
// 4. **`typealias` 别名**：`typealias T2 = Transition` 之后 `struct X: T2` 采不到。
//    没有语义解析就堵不住这条；本仓没有这种写法，登记在此。
// 5. **`everyTransitionHasARuntimeExpectation` 只查"有一条**断言**读了该类型的
//    `properties.hasMotion`"**，查不了那条断言断的是不是对的值、更查不了它有没有真的
//    跑到。取值的正确性归 `TransitionPropertiesRoster`（12 条运行时 `#expect`），
//    本守卫只保证**没有漏网的类型**。
//    ⚠️ 上一版这条是**纯文本** `corpus.contains(…)`，注释 / doc comment / 字符串一律算数
//    ——实证过：删掉整个 `TransitionPropertiesRosterTests.swift`（花名册功能整个不工作），
//    本条靠 `MaskRevealTests.swift` 与 `ReduceMotionGuard.swift` 里的**两行注释**保持绿。
//    终审 I-2 起改成 AST 判定（`#expect`/`#require` 宏展开 + `.properties.hasMotion`
//    成员访问链），`runtimeExpectationScannerIsStructuralNotTextual` 逐形态钉住。
// 6. **精化协议**（`protocol P: Transition {}` + `struct X: P {}`）：终审 I-3 之后**已堵**
//    ——协议也进射程，先在协议名上求「等价于 `Transition`」的传递闭包再判 conformer
//    （`refiningProtocolConformerIsCaught` 钉住）。⚠️ 但只对**本仓自己声明的**协议成立：
//    经一个**外部模块**（SwiftUI / 别的包）里精化 `Transition` 的协议 conform，仍然采不到
//    ——那需要语义解析。本仓没有这种写法，登记在此。
// 7. **`#if` 里的 `properties` 算"声明了"，不判条件真假**（终审 S-1）：`#if os(Android)`
//    里的声明也会被算数。这一侧是 fail-open 的；反方向（把 `#if` 里的真声明误判成漏声明）
//    是终审 S-1 实证过的**假红**，已修。
// 8. **`everyTransitionHasARuntimeExpectation` 的语料根写死在 `Tests/CoreDesignEffectsTests`**
//    （`scanAllRoots()` 却覆盖三个 `Sources` 根）。`swift package describe` 实测该 test target
//    只依赖 `CoreDesignEffects` ⇒ 将来 `CoreDesignCharts` / `CoreDesign` 里落一条 `Transition`，
//    本条会红而**在原地修不了**（那个 target import 不到 Charts），只能连判据一起重构成
//    "按 target 归属挑语料根"。方向是 fail-closed（红而不是绿），不紧急，登记在此。
@Suite("Transition 必须显式声明 properties（#292）")
struct TransitionPropertiesGuard {

    // MARK: - 扫描结果

    struct Scan: Equatable {
        /// 每个**名字**的继承子句里出现过的名字（跨声明 / 跨 extension / 跨文件聚合）。
        ///
        /// ⚠️ 存的是**原始继承关系**而不是「是不是 conformer」的结论：`Transition` 可以经
        /// 一层**精化协议**（`protocol P: Transition {}` + `struct X: P {}`）间接被 conform，
        /// 而那个协议完全可能声明在另一个文件里 ⇒ 结论只能在**全仓合并之后**算
        ///（`conformers` 是计算属性，`+` 只做并集）。
        var inherits: [String: Set<String>] = [:]
        /// 被 `protocol` 关键字声明的名字。它们**自己**不是 conformer，
        /// 但它们可以把 `Transition` 传递给别人。
        var protocolNames: Set<String> = []
        /// 声明了 `static`/`class` 的 `properties` 变量的名字（含 extension 里声明的）。
        var declaresProperties: Set<String> = []

        /// 直接或经**精化协议**间接 conform `Transition` 的**具体类型**名。
        ///
        /// ⚠️ 两步：①先在协议名上求「等价于 `Transition`」的**传递闭包**
        ///（`protocol A: Transition`、`protocol B: A`、… 全部算数）；
        /// ②继承子句里出现过闭包中任一名字的**非协议**名即 conformer。
        var conformers: Set<String> {
            var transitionLike: Set<String> = ["Transition"]
            var changed = true
            while changed {
                changed = false
                for name in self.protocolNames where !transitionLike.contains(name) {
                    if !(self.inherits[name] ?? []).isDisjoint(with: transitionLike) {
                        transitionLike.insert(name)
                        changed = true
                    }
                }
            }
            return Set(self.inherits.filter { name, parents in
                !self.protocolNames.contains(name) && !parents.isDisjoint(with: transitionLike)
            }.keys)
        }

        /// conform 了却没声明 ⇒ 继承 SDK 默认值 `hasMotion == true`。
        ///
        /// ⚠️ **协议扩展里的默认实现不算**：`extension P { static var properties … }` 记在
        /// `P` 名下，而 `P` 不在 `conformers` 里 ⇒ 用精化协议把取值藏进默认实现的
        /// `struct X: P {}` 仍然是 offender（`refiningProtocolConformerIsCaught` 钉住）。
        var offenders: Set<String> { self.conformers.subtracting(self.declaresProperties) }

        static func + (lhs: Scan, rhs: Scan) -> Scan {
            var inherits = lhs.inherits
            for (name, parents) in rhs.inherits { inherits[name, default: []].formUnion(parents) }
            return Scan(inherits: inherits,
                        protocolNames: lhs.protocolNames.union(rhs.protocolNames),
                        declaresProperties: lhs.declaresProperties.union(rhs.declaresProperties))
        }
    }

    /// **花名册**：`#292` 扫出的全仓 `Transition` 实现清单（12 条，全部在 `CoreDesignEffects`）。
    ///
    /// ⚠️ 它与实扫结果做**双向差集**（`rosterMatchesReality`）：
    /// · 少一条 ⇒ 有人删了转场却没更新清单；
    /// · 多一条 ⇒ 有人新加了转场 ⇒ 必须同轮在这里登记、在
    ///   `TransitionPropertiesRoster` 里写下运行时取值判据、并在类型文档里裁定取值。
    /// 这是 AC 第一条「全仓扫出所有 `Transition` 实现，列出完整清单」的**机器版本**
    /// ——一次性的 grep 会过期，双向差集不会。
    static let roster: Set<String> = [
        // 3D 与弹性簇（#267 / PR #286）——有真实几何运动 ⇒ hasMotion true
        "FlipTransition", "Rotate3DTransition", "SwooshTransition",
        "BoingTransition", "SkidTransition", "PolarMoveTransition",
        // mask reveal 簇（#268 / PR #291）——遮罩边扫过内容 ⇒ hasMotion true
        "MaskRevealTransition",
        // 粒子（#253，本 issue 的标的）——粒子飞散 + 内容缩放 ⇒ hasMotion true
        "ParticleTransition",
        // 滤镜簇（#266 / PR #289）——纯成像滤镜、无几何运动 ⇒ hasMotion false
        "BlurTransition", "FilmExposureTransition", "SnapshotTransition", "FlickerTransition",
    ]

    // MARK: - 扫描器（纯函数，fixture 直接喂字符串）

    static func scan(source: String) -> Scan {
        let tree = SwiftParser.Parser.parse(source: source)
        let collector = TransitionConformanceCollector()
        collector.walk(tree)
        return collector.scan
    }

    static func scan(root: URL) throws -> Scan {
        var out = Scan()
        for url in GuardScanRoots.swiftFiles(in: root) {
            let source = try String(contentsOf: url, encoding: .utf8)
            let tree = SwiftParser.Parser.parse(source: source)
            // ⚠️ **解析保真检查**：parser major 与工具链不配套时会静默产出 error node
            // ⇒ 类型被漏采，而扫描器照样「成功」返回一个偏小的集合（与
            // `ComponentRegistryGuard.scanTypes(root:)` 同一条纪律）。
            if tree.hasError {
                Issue.record("解析出错：\(GuardScanRoots.relativePath(url)) —— swift-syntax major 可能与工具链不配套")
            }
            let collector = TransitionConformanceCollector()
            collector.walk(tree)
            out = out + collector.scan
        }
        return out
    }

    /// 全部扫描根合起来的一次扫描。
    static func scanAllRoots() throws -> Scan {
        #expect(GuardScanRoots.assertRootsExist(GuardScanRoots.allRoots))
        var out = Scan()
        for root in GuardScanRoots.allRoots {
            let files = GuardScanRoots.swiftFiles(in: root.url)
            #expect(!files.isEmpty, "\(root.target) 下没有任何 .swift 文件 —— 本守卫在它上面恒绿")
            out = out + (try Self.scan(root: root.url))
        }
        return out
    }

    // MARK: - 运行时判据扫描器（同样是结构判定，不是文本匹配）

    /// 语料里**写在 `#expect` / `#require` 里**的 `<类型>.properties.hasMotion` 读取，
    /// 返回那些 `<类型>` 的名字。
    ///
    /// ## ⚠️⚠️ 为什么这里也必须按结构判（终审 I-2）
    ///
    /// 上一版是 `corpus.contains("\(name).properties.hasMotion")` ——**纯文本**：
    /// 注释、doc comment、字符串字面量一律算数。实证过的失效形态：
    /// 把整个 `TransitionPropertiesRosterTests.swift` 删掉（= 花名册功能整个不工作），
    /// 本条判据**照样绿**——因为 `MaskRevealTests.swift` 与 `ReduceMotionGuard.swift`
    /// 各有一行**注释**恰好写着 `ParticleTransition.properties.hasMotion == true`。
    /// 那正是本文件头声讨、并用 fixture ⑧ 给**声明扫描器**钉住的同一种失效形态，
    /// 而它当时在自己这条判据上没做。
    ///
    /// ⇒ 现在两步都按 AST：①祖先里必须有一个 `#expect` / `#require` 宏展开；
    /// ②里面必须有一条 `<something>.properties.hasMotion` 的成员访问链。
    /// 注释与字符串字面量在 AST 里分别是 trivia 与 `StringLiteralExprSyntax` 的片段，
    /// 两者都到不了 `MemberAccessExprSyntax` ⇒ 天然不算数
    ///（`runtimeExpectationScannerIsStructuralNotTextual` 逐形态钉住）。
    ///
    /// ⚠️ 射程：**只认宏里的读取**。写在普通语句里的 `let x = Foo.properties.hasMotion`
    /// 不算——那不是断言，把值改掉它也不会红。
    static func assertedTypes(tree: SourceFileSyntax) -> Set<String> {
        let collector = RuntimeExpectationCollector()
        collector.walk(tree)
        return collector.asserted
    }

    /// fixture 入口：直接喂字符串。
    static func assertedTypes(source: String) -> Set<String> {
        Self.assertedTypes(tree: SwiftParser.Parser.parse(source: source))
    }

    // MARK: - 判据

    @Test("每个 Transition 实现都显式声明 properties，不继承 SDK 默认值")
    func everyTransitionDeclaresProperties() throws {
        let scan = try Self.scanAllRoots()
        // ⚠️ 非真空：0 个 conformer 会让下面的差集恒绿。
        #expect(scan.conformers.count >= 12, """
        扫描器只采到 \(scan.conformers.count) 个 `Transition` 实现（应 ≥ 12）—— 疑似失效。
        采到的是：\(scan.conformers.sorted())
        """)
        #expect(scan.offenders.isEmpty, """
        这些 `Transition` 实现没有显式声明 `static var/let properties`：\(scan.offenders.sorted())
        ⇒ 它们继承 `Transition.properties` 的 SDK 默认值 `hasMotion == true`，其语义是
        「Reduce Motion 开启时框架把整条转场换成 `.opacity`」——**该转场自己写的降级形态
        在生产中根本不会被求值**，而本仓的降级判据仍然全绿（它们量的是内层门控）。
        处置：在类型里写下 `properties`，并**据实**取值
        （有真实几何运动 ⇒ `true`；纯成像滤镜、无几何运动 ⇒ `false`），
        同时在 `TransitionPropertiesRoster` 里补一条运行时判据、在类型文档里写清
        「框架那道闸先触发 / 内层门控是否可达 / 为什么仍然保留」。
        """)
    }

    @Test("花名册与实扫双向差集：新增 / 删除 Transition 必须同轮更新清单")
    func rosterMatchesReality() throws {
        let scanned = try Self.scanAllRoots().conformers
        #expect(scanned.subtracting(Self.roster).isEmpty, """
        源码里有 `Transition` 实现不在 `TransitionPropertiesGuard.roster` 上：
        \(scanned.subtracting(Self.roster).sorted())
        ⇒ 同轮要做三件事：①登记进 `roster`；②在
        `Tests/CoreDesignEffectsTests/TransitionPropertiesRosterTests.swift` 里写下
        `<类型名>.properties.hasMotion` 的运行时判据；③在类型文档里裁定 `hasMotion`
        取值并写清它与内层 RM 门控的先后关系。
        """)
        #expect(Self.roster.subtracting(scanned).isEmpty, """
        `roster` 上有幽灵条目（源码里找不到）：\(Self.roster.subtracting(scanned).sorted())
        —— 转场被删 / 改名了却没同轮改这份清单。
        """)
    }

    @Test("每个 Transition 都在效果测试 target 里有一条运行时 hasMotion 判据")
    func everyTransitionHasARuntimeExpectation() throws {
        let scanned = try Self.scanAllRoots().conformers
        let testsRoot = GuardScanRoots.repoRoot.appendingPathComponent("Tests/CoreDesignEffectsTests")
        let files = GuardScanRoots.swiftFiles(in: testsRoot)
        // ⚠️ **fail-closed**：目录读不到 / 没有文件时必须判红，不能"零文件 ⇒ 零违规 ⇒ 绿"。
        #expect(!files.isEmpty, "\(testsRoot.path) 下没有任何 .swift 文件 —— 本条判据无法工作")
        var asserted: Set<String> = []
        for url in files {
            let source = try String(contentsOf: url, encoding: .utf8)
            let tree = SwiftParser.Parser.parse(source: source)
            if tree.hasError {
                Issue.record("解析出错：\(GuardScanRoots.relativePath(url)) —— swift-syntax major 可能与工具链不配套")
            }
            asserted.formUnion(Self.assertedTypes(tree: tree))
        }

        // ⚠️ 非真空：采到 0 个会让下面的差集在"花名册整份消失"那枚变异下恒绿。
        #expect(asserted.count >= 12, """
        只在 `Tests/CoreDesignEffectsTests/` 里采到 \(asserted.count) 个
        `#expect`/`#require` 里的 `<类型>.properties.hasMotion` 读取（应 ≥ 12）—— 疑似失效。
        采到的是：\(asserted.sorted())
        """)

        let missing = scanned.subtracting(asserted)
        #expect(missing.isEmpty, """
        这些 `Transition` 在 `Tests/CoreDesignEffectsTests/` 里找不到任何
        **写在 `#expect` / `#require` 里**的 `<类型名>.properties.hasMotion` 读取：\(missing.sorted())
        ⇒ 它们的 `hasMotion` 取值今天没有任何东西钉着，把值改掉不会有判据红。
        处置：在 `TransitionPropertiesRosterTests.swift` 的花名册里补一条。
        ⚠️ 本条查的是「有一条**断言**读了这个类型的 `properties.hasMotion`」，
        查不了那条断言断的是不是对的值，也查不了它有没有真的跑到。
        """)
    }

    @Test("登记表里每条 Transition 入口点的 notes 都记了框架那道闸")
    func registryNotesAccountForTheFrameworkGate() throws {
        let entries = try ComponentRegistryGuard.loadEntryPoints().filter { $0.host == "Transition" }
        // ⚠️ 非真空：零条目会让下面的循环一次都不执行（本仓 `#265` 终审 S-1 记过这个形态）。
        #expect(entries.count >= 17, "登记表里只有 \(entries.count) 条 `Transition` 入口点 —— 疑似没读到")
        let offenders = entries.filter { !$0.notes.contains("hasMotion") }.map(\.member)
        #expect(offenders.isEmpty, """
        这些转场入口点的 `notes` 里没有 `hasMotion` 一词：\(offenders.sorted())
        ⇒ `notes` 是有 schema 校验的承重契约，而它今天在描述 Reduce Motion 降级时
        没有交代**框架那道闸**（`hasMotion` 为 `true` 时 SwiftUI 先把整条转场换成
        `.opacity`，内层门控不可达）。这正是 `#292` 点名的「判据全绿、文档详尽、
        而运行时行为与文档所写不同」。
        ⚠️ 本条只查这个词出现过，查不了那段话说得对不对——它挡的是"整段忘了写"。
        """)
    }

    // MARK: - 防假绿：能触发红的 fixture（AD-E）

    @Test("扫描器逐形态自证：三种真实写法都认，漏声明必红")
    func scannerAcceptsEveryDeclarationForm() {
        // ① 滤镜簇写法（`static let`，无类型标注）。
        let filterForm = Self.scan(source: """
        public struct BlurLike: Transition {
            public static let properties = TransitionProperties(hasMotion: false)
            public func body(content: Content, phase: TransitionPhase) -> some View { content }
        }
        """)
        #expect(filterForm.conformers == ["BlurLike"])
        #expect(filterForm.offenders.isEmpty, "滤镜簇写法没被认出来")

        // ② 3D 与弹性簇写法（`static var` + 计算属性）。
        let computedForm = Self.scan(source: """
        public struct FlipLike: Transition {
            public static var properties: TransitionProperties { .init(hasMotion: true) }
        }
        """)
        #expect(computedForm.offenders.isEmpty, "计算属性写法没被认出来")

        // ③ mask reveal / particle 写法（`static let` + 类型标注）。
        let annotatedForm = Self.scan(source: """
        public struct IrisLike: Transition {
            public static let properties: TransitionProperties = TransitionProperties(hasMotion: true)
        }
        """)
        #expect(annotatedForm.offenders.isEmpty, "带类型标注的 `let` 写法没被认出来")

        // ④ ⚠️ **会触发红的 fixture**：conform 了却没声明 ⇒ 继承默认值。
        let offender = Self.scan(source: """
        public struct SilentTransition: Transition {
            public func body(content: Content, phase: TransitionPhase) -> some View { content }
        }
        """)
        #expect(offender.offenders == ["SilentTransition"], """
        漏声明 `properties` 的类型没有被判为违规 —— 本守卫在它要防的那个形态上是瞎的。
        """)

        // ⑤ 多协议继承子句里的 `Transition` 也算（顺序 / 数量都不该影响判别）。
        #expect(Self.scan(source: """
        struct Multi: Sendable, Equatable, Transition {}
        """).conformers == ["Multi"])

        // ⑥ 模块限定名 `SwiftUI.Transition` 也算。
        #expect(Self.scan(source: """
        struct Qualified: SwiftUI.Transition {}
        """).conformers == ["Qualified"])

        // ⑦ 声明写在**另一个 extension** 里也算数（跨 extension 聚合）。
        let split = Self.scan(source: """
        struct Split: Transition {}
        extension Split {
            public static let properties = TransitionProperties(hasMotion: true)
        }
        """)
        #expect(split.conformers == ["Split"])
        #expect(split.offenders.isEmpty, "写在 extension 里的声明没被聚合到类型上")

        // ⑧ ⚠️⚠️ **结构 vs 文本**：只在**注释**里写着同样的字，不算声明。
        // 逐字文本匹配（`code.contains("static let properties: TransitionProperties")`）
        // 会在这条输入上放行——这是本守卫必须按结构判定的直接理由。
        let commentOnly = Self.scan(source: """
        struct CommentOnly: Transition {
            // public static let properties: TransitionProperties = TransitionProperties(hasMotion: true)
            /// static var properties: TransitionProperties { .init(hasMotion: true) }
        }
        """)
        #expect(commentOnly.offenders == ["CommentOnly"], """
        注释里的 `properties` 被当成了真声明 —— 这正是文本匹配的失效形态。
        """)

        // ⑨ **实例属性不算**：协议要求是 `static`，一个实例 `properties` 满足不了它。
        #expect(Self.scan(source: """
        struct InstanceOnly: Transition {
            let properties = TransitionProperties(hasMotion: true)
        }
        """).offenders == ["InstanceOnly"], "实例属性被当成了协议见证")

        // ⑩ **反向**：不 conform `Transition` 的类型不进射程（`AnyTransition` /
        // `TransitionPhase` 这些名字里带 `Transition` 的不该被误采）。
        let decoys = Self.scan(source: """
        struct NotOne: Equatable {}
        struct AlsoNot: AnyTransition {}
        enum TransitionCurve { static let properties = 1 }
        extension Transition where Self == BlurLike { static var blurLike: Self { .init() } }
        """)
        #expect(decoys.conformers.isEmpty, "误采到了非 `Transition` 类型：\(decoys.conformers.sorted())")

        // ⑪ **retroactive conformance**：`extension Foo: Transition` 也是一次 conform。
        let retro = Self.scan(source: """
        struct Retro {}
        extension Retro: Transition {}
        """)
        #expect(retro.conformers == ["Retro"])
        #expect(retro.offenders == ["Retro"], "retroactive conformance 漏声明时不会红")

        // ⑫ `class` 宿主用 `class var` 也算见证（`static` 之外的那一种）。
        #expect(Self.scan(source: """
        final class ClassHost: Transition {
            class var properties: TransitionProperties { .init(hasMotion: true) }
        }
        """).offenders.isEmpty, "`class var` 见证没被认出来")
    }

    @Test("精化协议不是逃逸位：经 `protocol P: Transition` 间接 conform 的类型照样采得到")
    func refiningProtocolConformerIsCaught() {
        // ⚠️ 终审 I-3 实证过的探针：能编译、`public`、`hasMotion` 被协议扩展默认实现
        // 悄悄设成 `false`，而上一版扫描器（只比继承子句尾名是否恰为 `Transition`，
        // 且 `ProtocolDeclSyntax` 根本不在 visitor 的重载里）**六条判据全绿**。
        let indirect = Self.scan(source: """
        public protocol RefiningTransition: Transition {}
        public extension RefiningTransition {
            static var properties: TransitionProperties { .init(hasMotion: false) }
        }
        public struct ReviewProbeTransition: RefiningTransition {
            public func body(content: Content, phase: TransitionPhase) -> some View { content }
        }
        """)
        #expect(indirect.conformers == ["ReviewProbeTransition"], """
        经精化协议间接 conform 的类型没被采到（或协议自己被误采成了 conformer）：
        \(indirect.conformers.sorted())
        """)
        #expect(indirect.offenders == ["ReviewProbeTransition"], """
        协议扩展里的默认实现被当成了该类型自己的显式声明 —— 那正是这条路径最危险的地方：
        取值被藏进协议扩展，**没有任何地方写下它**。
        """)

        // 多跳传递闭包（`protocol B: A`，`A: Transition`）同样算数。
        let twoHops = Self.scan(source: """
        protocol A: Transition {}
        protocol B: A {}
        struct Deep: B {}
        """)
        #expect(twoHops.conformers == ["Deep"], "两跳精化没走到：\(twoHops.conformers.sorted())")

        // ⚠️ 跨文件：协议与实现分居两个文件时，结论只能在合并之后算。
        let split = Self.scan(source: "protocol Refining: Transition {}")
            + Self.scan(source: "struct Elsewhere: Refining {}")
        #expect(split.conformers == ["Elsewhere"], "跨文件的精化协议没被聚合")

        // 反向：不沾 `Transition` 的协议不传染。
        #expect(Self.scan(source: """
        protocol Unrelated: Equatable {}
        struct Innocent: Unrelated {}
        """).conformers.isEmpty, "无关协议把类型误采进来了")
    }

    @Test("`#if` 包住的 properties 算数（终审 S-1：条件编译不是「没声明」）")
    func conditionallyCompiledDeclarationCounts() {
        // ⚠️ `#if` 在 AST 里是 `IfConfigDeclSyntax`，平铺遍历 `members.members` 会跳过它
        // ⇒ 上一版把这份输入判成 offender（假红）。本仓 `#if canImport(UIKit)/AppKit`
        // 用得很多，迟早撞上。
        let gated = Self.scan(source: """
        public struct GatedTransition: Transition {
            #if canImport(SwiftUI)
            public static let properties: TransitionProperties = TransitionProperties(hasMotion: true)
            #endif
            public func body(content: Content, phase: TransitionPhase) -> some View { content }
        }
        """)
        #expect(gated.conformers == ["GatedTransition"])
        #expect(gated.offenders.isEmpty, "`#if` 里的声明没被认出来 —— 条件编译被误判成漏声明")

        // `#else` 分支里的声明同样算数。
        #expect(Self.scan(source: """
        struct EitherWay: Transition {
            #if canImport(UIKit)
            static let properties = TransitionProperties(hasMotion: true)
            #else
            static let properties = TransitionProperties(hasMotion: false)
            #endif
        }
        """).offenders.isEmpty, "`#else` 分支里的声明没被认出来")

        // 反向：`#if` 里**只有注释**照样是漏声明（结构判定不因嵌套而退化成文本匹配）。
        #expect(Self.scan(source: """
        struct StillSilent: Transition {
            #if canImport(SwiftUI)
            // static let properties = TransitionProperties(hasMotion: true)
            #endif
        }
        """).offenders == ["StillSilent"], "`#if` 里的注释被当成了真声明")
    }

    @Test("运行时判据扫描器同样按结构判：注释 / 字符串 / 非断言读取一律不算数")
    func runtimeExpectationScannerIsStructuralNotTextual() {
        // ① 真断言（两种真实写法：裸 Bool 与 `== false`）。
        #expect(Self.assertedTypes(source: """
        #expect(FlipTransition.properties.hasMotion, "note")
        #expect(BlurTransition.properties.hasMotion == false, "note")
        """) == ["FlipTransition", "BlurTransition"])

        // ② `#require` 也算。
        #expect(Self.assertedTypes(source: "_ = try #require(FooTransition.properties.hasMotion)")
                == ["FooTransition"])

        // ③ `Self.Probe.properties.hasMotion` 这种链取**最后一段**作类型名。
        #expect(Self.assertedTypes(source: "#expect(Self.DefaultPropertiesProbe.properties.hasMotion)")
                == ["DefaultPropertiesProbe"])

        // ④ ⚠️⚠️ **行注释**不算数 —— 终审 I-2 逐字实证的那两行就是这个形态。
        #expect(Self.assertedTypes(source: """
        // ParticleTransition.properties.hasMotion   == true
        """).isEmpty, "行注释被当成了断言")

        // ⑤ ⚠️⚠️ **doc comment** 不算数（另一行实证形态）。
        #expect(Self.assertedTypes(source: """
        /// ParticleTransition.properties.hasMotion   == true
        func f() {}
        """).isEmpty, "doc comment 被当成了断言")

        // ⑥ **字符串字面量**不算数（失败消息里照抄一遍不该顶一条判据）。
        #expect(Self.assertedTypes(source: """
        #expect(somethingElse, "ParticleTransition.properties.hasMotion 变了")
        """).isEmpty, "字符串字面量里的类型名被当成了断言")

        // ⑦ **不在宏里**的读取不算数：它不会因为取值变了而红。
        #expect(Self.assertedTypes(source: "let x = ParticleTransition.properties.hasMotion").isEmpty,
                "普通语句里的读取被当成了断言")

        // ⑧ 反向非真空：上面几条"不算数"必须不是因为扫描器整个是瞎的。
        #expect(Self.assertedTypes(source: "#expect(ParticleTransition.properties.hasMotion)")
                == ["ParticleTransition"], "真断言都采不到 —— 上面 5 条否定判据不作数")

        // ⑨ 只读到 `properties`、没读 `hasMotion` 不算数。
        #expect(Self.assertedTypes(source: "#expect(ParticleTransition.properties.isSomethingElse)").isEmpty)
    }

    @Test("扫描器在真实源码上非真空：花名册里的类型必须逐个被采到")
    func scannerFiresOnRealSource() throws {
        let scan = try Self.scanAllRoots()
        for name in Self.roster {
            #expect(scan.conformers.contains(name),
                    "真实源码里的 `\(name)` 没被采到 —— 扫描器的 conformance 判别可能坏了")
            #expect(scan.declaresProperties.contains(name),
                    "真实源码里的 `\(name)` 没被认出声明了 `properties` —— 见证判别可能坏了")
        }
        print("【#292】全仓 Transition 实现共 \(scan.conformers.count) 个：\(scan.conformers.sorted())")
    }
}

// MARK: - 采集器 / Collector

/// 采集「继承子句里有 `Transition` 的类型」与「声明了 `static`/`class` `properties` 的类型」。
///
/// ⚠️ **两件事分开采、最后做差集**：声明可以写在类型体里，也可以写在任意一个
/// extension 里（Swift 允许协议见证住在同模块的 extension 上）。若在同一个节点里
/// 一并判定，`struct X: Transition {}` + `extension X { static let properties … }`
/// 这种拆开写法会被误判成违规。
private nonisolated final class TransitionConformanceCollector: SyntaxVisitor {

    var scan = TransitionPropertiesGuard.Scan()

    init() { super.init(viewMode: .sourceAccurate) }

    /// ⚠️ **协议也要采**（终审 I-3）：`protocol P: Transition {}` + `struct X: P {}` 是一条
    /// 能编译、`public`、且可以把 `properties` 的取值藏进 `extension P` 默认实现的
    /// **完全隐形**的绕过路径。只比继承子句尾名是否恰为 `Transition` 就采不到 `X`。
    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        self.record(name: node.name.text,
                    inheritance: node.inheritanceClause,
                    members: node.memberBlock,
                    isProtocol: true)
        return .visitChildren
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        self.record(name: node.name.text, inheritance: node.inheritanceClause, members: node.memberBlock)
        return .visitChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        self.record(name: node.name.text, inheritance: node.inheritanceClause, members: node.memberBlock)
        return .visitChildren
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        self.record(name: node.name.text, inheritance: node.inheritanceClause, members: node.memberBlock)
        return .visitChildren
    }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        self.record(name: node.name.text, inheritance: node.inheritanceClause, members: node.memberBlock)
        return .visitChildren
    }

    /// ⚠️ extension 的「被扩展类型」取的是**最后一个标识符**：`extension Foo.Bar` 记作 `Bar`，
    /// 与嵌套类型声明侧取最内层名字的口径一致（见 `TransitionPropertiesGuard` 文件头「已知绕过路径」②）。
    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let name = Self.trailingName(of: node.extendedType) else { return .visitChildren }
        self.record(name: name, inheritance: node.inheritanceClause, members: node.memberBlock)
        return .visitChildren
    }

    private func record(name: String,
                        inheritance: InheritanceClauseSyntax?,
                        members: MemberBlockSyntax,
                        isProtocol: Bool = false) {
        // ⚠️ 无论有没有继承子句都要**建一个条目**：`inherits` 的键集就是"我见过的名字"，
        // 空集合的条目在 `conformers` 里天然落选（`isDisjoint(with:)` 恒真）。
        var parents = self.scan.inherits[name] ?? []
        if let inheritance {
            // ⚠️ 比的是**标识符**而不是子串：`AnyTransition` / `TransitionPhase` 不会被误采
            //（fixture ⑩ 钉住）。`SwiftUI.Transition` 这种模块限定形态取最后一段（fixture ⑥）。
            for item in inheritance.inheritedTypes {
                if let parent = Self.trailingName(of: item.type) { parents.insert(parent) }
            }
        }
        self.scan.inherits[name] = parents
        if isProtocol { self.scan.protocolNames.insert(name) }
        if Self.declaresStaticProperties(members) { self.scan.declaresProperties.insert(name) }
    }

    // MARK: - 结构判别

    /// `Foo` ⇒ `Foo`；`SwiftUI.Transition` ⇒ `Transition`；其余形态（元组 / 函数类型…）⇒ `nil`。
    static func trailingName(of type: TypeSyntax) -> String? {
        if let ident = type.as(IdentifierTypeSyntax.self) { return ident.name.text }
        if let member = type.as(MemberTypeSyntax.self) { return member.name.text }
        return nil
    }

    /// 成员块里有没有一个 `static`（或 `class`）的、绑定名恰为 `properties` 的变量声明。
    ///
    /// ⚠️ `let` 与 `var` 都算（三种真实写法里两种是 `let`），计算属性与存储属性也都算
    /// ——协议要求写的是 `static var properties { get }`，`static let` 是合法见证。
    static func declaresStaticProperties(_ members: MemberBlockSyntax) -> Bool {
        Self.declaresStaticProperties(members.members)
    }

    /// ⚠️ **必须递归进 `#if`**（终审 S-1）：`#if canImport(SwiftUI) … #endif` 在 AST 里是
    /// `IfConfigDeclSyntax`，它的成员**不是** `members.members` 的元素 ⇒ 平铺遍历会
    /// 直接跳过，把一个包在条件编译里的 `properties` 误判成"没声明"。方向虽然是
    /// fail-closed（假红不是假绿），但本仓 `#if canImport(UIKit)/AppKit` 用得很多
    ///（见 `CLAUDE.md`「系统色桥接」一节），迟早会撞上。
    /// ⚠️ **任意一个分支里有就算数**（不判条件真假）：这一侧是 fail-open 的
    ///——`#if os(Android)` 里的声明也会被算成"声明了"。登记在文件头射程一节。
    static func declaresStaticProperties(_ items: MemberBlockItemListSyntax) -> Bool {
        for member in items {
            if let ifConfig = member.decl.as(IfConfigDeclSyntax.self) {
                for clause in ifConfig.clauses {
                    if case .decls(let nested)? = clause.elements,
                       Self.declaresStaticProperties(nested) { return true }
                }
                continue
            }
            guard let variable = member.decl.as(VariableDeclSyntax.self) else { continue }
            let isTypeLevel = variable.modifiers.contains {
                $0.name.tokenKind == .keyword(.static) || $0.name.tokenKind == .keyword(.class)
            }
            guard isTypeLevel else { continue }
            for binding in variable.bindings {
                if binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text == "properties" {
                    return true
                }
            }
        }
        return false
    }
}

// MARK: - 运行时判据采集器 / Runtime-expectation collector

/// 采集「写在 `#expect` / `#require` 里的 `<类型>.properties.hasMotion` 读取」。
///
/// ⚠️ 两层都必须是**语法节点**（终审 I-2）：
/// · 外层 `MacroExpansionExprSyntax` 且宏名是 `expect` / `require` ⇒ 这是一条**断言**；
/// · 内层 `MemberAccessExprSyntax` 链 `<base>.properties.hasMotion` ⇒ 真的读到了那个值。
/// 注释是 trivia、失败消息是 `StringLiteralExprSyntax` 的片段，两者都产生不了
/// `MemberAccessExprSyntax` ⇒ 上一版靠两行注释保持绿的那枚变异现在必红。
private nonisolated final class RuntimeExpectationCollector: SyntaxVisitor {

    var asserted: Set<String> = []

    init() { super.init(viewMode: .sourceAccurate) }

    override func visit(_ node: MacroExpansionExprSyntax) -> SyntaxVisitorContinueKind {
        let macro = node.macroName.text
        guard macro == "expect" || macro == "require" else { return .visitChildren }
        let inner = HasMotionReadCollector()
        inner.walk(node)
        self.asserted.formUnion(inner.names)
        return .visitChildren
    }
}

/// 在一棵子树里找 `<base>.properties.hasMotion`，返回 `<base>` 的尾名。
private nonisolated final class HasMotionReadCollector: SyntaxVisitor {

    var names: Set<String> = []

    init() { super.init(viewMode: .sourceAccurate) }

    override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
        guard node.declName.baseName.text == "hasMotion",
              let properties = node.base?.as(MemberAccessExprSyntax.self),
              properties.declName.baseName.text == "properties",
              let owner = properties.base,
              let name = Self.trailingName(of: owner)
        else { return .visitChildren }
        self.names.insert(name)
        return .visitChildren
    }

    /// `Foo` ⇒ `Foo`；`Self.Probe` ⇒ `Probe`；其余形态（下标 / 调用 / 字面量…）⇒ `nil`。
    static func trailingName(of expr: ExprSyntax) -> String? {
        if let reference = expr.as(DeclReferenceExprSyntax.self) { return reference.baseName.text }
        if let member = expr.as(MemberAccessExprSyntax.self) { return member.declName.baseName.text }
        return nil
    }
}
