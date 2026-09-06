import Foundation
import SwiftParser
import SwiftSyntax
import Testing

// MARK: - `Transition.properties` 显式声明守卫 / Explicit `properties` guard（Issue #292）

@Suite("Transition 必须显式声明 properties（#292）")
struct TransitionPropertiesGuard {
    // MARK: - 扫描结果

    struct Scan: Equatable {
        var inherits: [String: Set<String>] = [:]
        var protocolNames: Set<String> = []
        var declaresProperties: Set<String> = []

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

        var offenders: Set<String> { self.conformers.subtracting(self.declaresProperties) }

        static func + (lhs: Scan, rhs: Scan) -> Scan {
            var inherits = lhs.inherits
            for (name, parents) in rhs.inherits { inherits[name, default: []].formUnion(parents) }
            return Scan(inherits: inherits,
                        protocolNames: lhs.protocolNames.union(rhs.protocolNames),
                        declaresProperties: lhs.declaresProperties.union(rhs.declaresProperties))
        }
    }

    static let roster: Set<String> = [
        "FlipTransition", "Rotate3DTransition", "SwooshTransition",
        "BoingTransition", "SkidTransition", "PolarMoveTransition",
        "MaskRevealTransition",
        "ParticleTransition",
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
            if tree.hasError {
                Issue.record("解析出错：\(GuardScanRoots.relativePath(url)) —— swift-syntax major 可能与工具链不配套")
            }
            let collector = TransitionConformanceCollector()
            collector.walk(tree)
            out = out + collector.scan
        }
        return out
    }

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

    static func assertedTypes(tree: SourceFileSyntax) -> Set<String> {
        let collector = RuntimeExpectationCollector()
        collector.walk(tree)
        return collector.asserted
    }

    static func assertedTypes(source: String) -> Set<String> {
        Self.assertedTypes(tree: SwiftParser.Parser.parse(source: source))
    }

    // MARK: - 判据

    @Test("每个 Transition 实现都显式声明 properties，不继承 SDK 默认值")
    func everyTransitionDeclaresProperties() throws {
        let scan = try Self.scanAllRoots()
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
        let filterForm = Self.scan(source: """
        public struct BlurLike: Transition {
            public static let properties = TransitionProperties(hasMotion: false)
            public func body(content: Content, phase: TransitionPhase) -> some View { content }
        }
        """)
        #expect(filterForm.conformers == ["BlurLike"])
        #expect(filterForm.offenders.isEmpty, "滤镜簇写法没被认出来")

        let computedForm = Self.scan(source: """
        public struct FlipLike: Transition {
            public static var properties: TransitionProperties { .init(hasMotion: true) }
        }
        """)
        #expect(computedForm.offenders.isEmpty, "计算属性写法没被认出来")

        let annotatedForm = Self.scan(source: """
        public struct IrisLike: Transition {
            public static let properties: TransitionProperties = TransitionProperties(hasMotion: true)
        }
        """)
        #expect(annotatedForm.offenders.isEmpty, "带类型标注的 `let` 写法没被认出来")

        let offender = Self.scan(source: """
        public struct SilentTransition: Transition {
            public func body(content: Content, phase: TransitionPhase) -> some View { content }
        }
        """)
        #expect(offender.offenders == ["SilentTransition"], """
        漏声明 `properties` 的类型没有被判为违规 —— 本守卫在它要防的那个形态上是瞎的。
        """)

        #expect(Self.scan(source: """
        struct Multi: Sendable, Equatable, Transition {}
        """).conformers == ["Multi"])

        #expect(Self.scan(source: """
        struct Qualified: SwiftUI.Transition {}
        """).conformers == ["Qualified"])

        let split = Self.scan(source: """
        struct Split: Transition {}
        extension Split {
            public static let properties = TransitionProperties(hasMotion: true)
        }
        """)
        #expect(split.conformers == ["Split"])
        #expect(split.offenders.isEmpty, "写在 extension 里的声明没被聚合到类型上")

        let commentOnly = Self.scan(source: """
        struct CommentOnly: Transition {
            // public static let properties: TransitionProperties = TransitionProperties(hasMotion: true)
            /// static var properties: TransitionProperties { .init(hasMotion: true) }
        }
        """)
        #expect(commentOnly.offenders == ["CommentOnly"], """
        注释里的 `properties` 被当成了真声明 —— 这正是文本匹配的失效形态。
        """)

        #expect(Self.scan(source: """
        struct InstanceOnly: Transition {
            let properties = TransitionProperties(hasMotion: true)
        }
        """).offenders == ["InstanceOnly"], "实例属性被当成了协议见证")

        let decoys = Self.scan(source: """
        struct NotOne: Equatable {}
        struct AlsoNot: AnyTransition {}
        enum TransitionCurve { static let properties = 1 }
        extension Transition where Self == BlurLike { static var blurLike: Self { .init() } }
        """)
        #expect(decoys.conformers.isEmpty, "误采到了非 `Transition` 类型：\(decoys.conformers.sorted())")

        let retro = Self.scan(source: """
        struct Retro {}
        extension Retro: Transition {}
        """)
        #expect(retro.conformers == ["Retro"])
        #expect(retro.offenders == ["Retro"], "retroactive conformance 漏声明时不会红")

        #expect(Self.scan(source: """
        final class ClassHost: Transition {
            class var properties: TransitionProperties { .init(hasMotion: true) }
        }
        """).offenders.isEmpty, "`class var` 见证没被认出来")
    }

    @Test("精化协议不是逃逸位：经 `protocol P: Transition` 间接 conform 的类型照样采得到")
    func refiningProtocolConformerIsCaught() {
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

        let twoHops = Self.scan(source: """
        protocol A: Transition {}
        protocol B: A {}
        struct Deep: B {}
        """)
        #expect(twoHops.conformers == ["Deep"], "两跳精化没走到：\(twoHops.conformers.sorted())")

        let split = Self.scan(source: "protocol Refining: Transition {}")
            + Self.scan(source: "struct Elsewhere: Refining {}")
        #expect(split.conformers == ["Elsewhere"], "跨文件的精化协议没被聚合")

        #expect(Self.scan(source: """
        protocol Unrelated: Equatable {}
        struct Innocent: Unrelated {}
        """).conformers.isEmpty, "无关协议把类型误采进来了")
    }

    @Test("`#if` 包住的 properties 算数（终审 S-1：条件编译不是「没声明」）")
    func conditionallyCompiledDeclarationCounts() {
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

        #expect(Self.scan(source: """
        struct EitherWay: Transition {
            #if canImport(UIKit)
            static let properties = TransitionProperties(hasMotion: true)
            #else
            static let properties = TransitionProperties(hasMotion: false)
            #endif
        }
        """).offenders.isEmpty, "`#else` 分支里的声明没被认出来")

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
        #expect(Self.assertedTypes(source: """
        #expect(FlipTransition.properties.hasMotion, "note")
        #expect(BlurTransition.properties.hasMotion == false, "note")
        """) == ["FlipTransition", "BlurTransition"])

        #expect(Self.assertedTypes(source: "_ = try #require(FooTransition.properties.hasMotion)")
                == ["FooTransition"])

        #expect(Self.assertedTypes(source: "#expect(Self.DefaultPropertiesProbe.properties.hasMotion)")
                == ["DefaultPropertiesProbe"])

        #expect(Self.assertedTypes(source: """
        // ParticleTransition.properties.hasMotion   == true
        """).isEmpty, "行注释被当成了断言")

        #expect(Self.assertedTypes(source: """
        /// ParticleTransition.properties.hasMotion   == true
        func f() {}
        """).isEmpty, "doc comment 被当成了断言")

        #expect(Self.assertedTypes(source: """
        #expect(somethingElse, "ParticleTransition.properties.hasMotion 变了")
        """).isEmpty, "字符串字面量里的类型名被当成了断言")

        #expect(Self.assertedTypes(source: "let x = ParticleTransition.properties.hasMotion").isEmpty,
                "普通语句里的读取被当成了断言")

        #expect(Self.assertedTypes(source: "#expect(ParticleTransition.properties.hasMotion)")
                == ["ParticleTransition"], "真断言都采不到 —— 上面 5 条否定判据不作数")

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

private nonisolated final class TransitionConformanceCollector: SyntaxVisitor {
    var scan = TransitionPropertiesGuard.Scan()

    init() { super.init(viewMode: .sourceAccurate) }

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

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let name = Self.trailingName(of: node.extendedType) else { return .visitChildren }
        self.record(name: name, inheritance: node.inheritanceClause, members: node.memberBlock)
        return .visitChildren
    }

    private func record(name: String,
                        inheritance: InheritanceClauseSyntax?,
                        members: MemberBlockSyntax,
                        isProtocol: Bool = false) {
        var parents = self.scan.inherits[name] ?? []
        if let inheritance {
            for item in inheritance.inheritedTypes {
                if let parent = Self.trailingName(of: item.type) { parents.insert(parent) }
            }
        }
        self.scan.inherits[name] = parents
        if isProtocol { self.scan.protocolNames.insert(name) }
        if Self.declaresStaticProperties(members) { self.scan.declaresProperties.insert(name) }
    }

    // MARK: - 结构判别

    static func trailingName(of type: TypeSyntax) -> String? {
        if let ident = type.as(IdentifierTypeSyntax.self) { return ident.name.text }
        if let member = type.as(MemberTypeSyntax.self) { return member.name.text }
        return nil
    }

    static func declaresStaticProperties(_ members: MemberBlockSyntax) -> Bool {
        Self.declaresStaticProperties(members.members)
    }

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

    static func trailingName(of expr: ExprSyntax) -> String? {
        if let reference = expr.as(DeclReferenceExprSyntax.self) { return reference.baseName.text }
        if let member = expr.as(MemberAccessExprSyntax.self) { return member.declName.baseName.text }
        return nil
    }
}
