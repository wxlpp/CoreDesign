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
// 5. **`everyTransitionHasARuntimeExpectation` 只查"存在一条提到该类型的断言"**，
//    查不了那条断言断的是不是对的值、更查不了它有没有真的跑到。取值的正确性归
//    `TransitionPropertiesRoster`（12 条运行时 `#expect`），本守卫只保证**没有漏网的类型**。
@Suite("Transition 必须显式声明 properties（#292）")
struct TransitionPropertiesGuard {

    // MARK: - 扫描结果

    struct Scan: Equatable {
        /// 继承子句里出现 `Transition` 的类型名。
        var conformers: Set<String> = []
        /// 声明了 `static`/`class` 的 `properties` 变量的类型名（含 extension 里声明的）。
        var declaresProperties: Set<String> = []

        /// conform 了却没声明 ⇒ 继承 SDK 默认值 `hasMotion == true`。
        var offenders: Set<String> { self.conformers.subtracting(self.declaresProperties) }

        static func + (lhs: Scan, rhs: Scan) -> Scan {
            Scan(conformers: lhs.conformers.union(rhs.conformers),
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
        return Scan(conformers: collector.conformers, declaresProperties: collector.declaresProperties)
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
            out = out + Scan(conformers: collector.conformers,
                             declaresProperties: collector.declaresProperties)
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
        var corpus = ""
        for url in files { corpus += try String(contentsOf: url, encoding: .utf8) }

        let missing = scanned.filter { !corpus.contains("\($0).properties.hasMotion") }
        #expect(missing.isEmpty, """
        这些 `Transition` 在 `Tests/CoreDesignEffectsTests/` 里找不到任何
        `<类型名>.properties.hasMotion` 形态的运行时判据：\(missing.sorted())
        ⇒ 它们的 `hasMotion` 取值今天没有任何东西钉着，把值改掉不会有判据红。
        处置：在 `TransitionPropertiesRosterTests.swift` 的花名册里补一条。
        ⚠️ 本条只查「存在一条提到该类型的断言」，查不了那条断言断的是不是对的值。
        """)
        // 互锁：这条判据必须真的能红——一个不存在的类型名必须落进 `missing` 那一侧。
        #expect(!corpus.contains("NoSuchTransitionXYZ.properties.hasMotion"),
                "语料里居然有占位类型名 —— 上面的 `contains` 判别不作数")
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

    var conformers: Set<String> = []
    var declaresProperties: Set<String> = []

    init() { super.init(viewMode: .sourceAccurate) }

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

    private func record(name: String, inheritance: InheritanceClauseSyntax?, members: MemberBlockSyntax) {
        if Self.inherits(from: "Transition", inheritance) { self.conformers.insert(name) }
        if Self.declaresStaticProperties(members) { self.declaresProperties.insert(name) }
    }

    // MARK: - 结构判别

    /// 继承子句里有没有**名字恰为** `protocolName` 的条目。
    ///
    /// ⚠️ 比的是**标识符**而不是子串：`AnyTransition` / `TransitionPhase` 不会被误采
    ///（fixture ⑩ 钉住）。`SwiftUI.Transition` 这种模块限定形态取最后一段（fixture ⑥）。
    static func inherits(from protocolName: String, _ clause: InheritanceClauseSyntax?) -> Bool {
        guard let clause else { return false }
        return clause.inheritedTypes.contains { Self.trailingName(of: $0.type) == protocolName }
    }

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
        for member in members.members {
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
