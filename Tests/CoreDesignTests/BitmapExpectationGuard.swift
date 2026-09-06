import Foundation
import SwiftParser
import SwiftSyntax
import Testing

// MARK: - 位图断言纪律 / Bitmap expectation discipline（Issue #293）

@Suite("#293 位图断言纪律")
struct BitmapExpectationGuard {
    // MARK: - 违规记录

    nonisolated struct Violation: Hashable, Sendable, CustomStringConvertible {
        let file: String
        let line: Int
        let snippet: String
        let reason: String

        var description: String { "\(self.file):\(self.line)  \(self.reason)\n    \(self.snippet)" }
    }

    // MARK: - 大类型的拼法

    nonisolated static let baseBigTypeSpellings: Set<String> = [
        "Data", "Foundation.Data",
        "[UInt8]", "Array<UInt8>", "[Swift.UInt8]", "Array<Swift.UInt8>",
        "ContiguousArray<UInt8>", "ContiguousArray<Swift.UInt8>",
        "[UInt8]?", "Slice<Data>", "ArraySlice<UInt8>",
    ]

    nonisolated static let bitmapNameFragments: [String] = ["pixel", "bitmap", "rgba"]

    nonisolated static let scalarReducingMembers: Set<String> = [
        "count", "isEmpty", "first", "last", "hashValue", "description", "debugDescription",
        "size", "width", "height", "startIndex", "endIndex", "indices", "underestimatedCount",
        "base64EncodedString", "hexString", "hexEncodedString", "sha256", "fingerprint",
    ]

    nonisolated static func mentionsBigElementType(_ text: String) -> Bool {
        let tokens = text.split { !$0.isLetter && !$0.isNumber && $0 != "_" }
        return tokens.contains("Data") || tokens.contains("UInt8")
    }

    nonisolated static func normalizedTypeText(_ text: String) -> String {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while t.hasSuffix("?") || t.hasSuffix("!") { t.removeLast() }
        return t.replacingOccurrences(of: " ", with: "")
    }

    nonisolated static func looksLikeBitmapName(_ name: String) -> Bool {
        let lowered = name.lowercased()
        return Self.bitmapNameFragments.contains { lowered.contains($0) }
    }

    // MARK: - 扫描根（fail-closed）

    nonisolated static var testsRoot: URL { GuardScanRoots.testsRoot }

    nonisolated static func testRootDirectories() throws -> [URL] {
        try GuardScanRoots.testRootDirectories()
    }

    nonisolated static func testSourceFiles() throws -> [URL] {
        var out: [URL] = []
        for root in try Self.testRootDirectories() {
            out.append(contentsOf: GuardScanRoots.swiftFiles(in: root))
        }
        return out.sorted { $0.path < $1.path }
    }

    // MARK: - 判据本体（纯函数：合成输入即可自证，不碰磁盘）

    nonisolated static func violations(in files: [(name: String, source: String)]) -> [Violation] {
        let trees = files.map { (name: $0.name, tree: SwiftParser.Parser.parse(source: $0.source)) }

        var bigTypes = Self.baseBigTypeSpellings
        var declaredTypeNames: Set<String> = []
        for _ in 0..<3 {
            for entry in trees {
                let collector = BigTypeCollector(known: bigTypes, viewMode: .sourceAccurate)
                collector.walk(entry.tree)
                bigTypes.formUnion(collector.discovered)
                declaredTypeNames.formUnion(collector.declaredTypeNames)
            }
        }

        var bigFunctionNames: Set<String> = []
        var knownNonBitmapNames: Set<String> = []
        for entry in trees {
            let collector = BigFunctionCollector(
                bigTypes: bigTypes, declaredTypeNames: declaredTypeNames, viewMode: .sourceAccurate
            )
            collector.walk(entry.tree)
            bigFunctionNames.formUnion(collector.names)
            knownNonBitmapNames.formUnion(collector.knownNonBitmapNames)
        }

        var out: [Violation] = []
        for entry in trees {
            let converter = SourceLocationConverter(fileName: entry.name, tree: entry.tree)
            let finder = ComparisonFinder(
                bigTypes: bigTypes,
                bigFunctionNames: bigFunctionNames,
                knownNonBitmapNames: knownNonBitmapNames,
                fileName: entry.name,
                converter: converter,
                viewMode: .sourceAccurate
            )
            finder.walk(entry.tree)
            out.append(contentsOf: finder.violations)
        }
        return out.sorted { ($0.file, $0.line) < ($1.file, $1.line) }
    }

    nonisolated static func violations(inSource source: String, fileName: String = "fixture.swift") -> [Violation] {
        Self.violations(in: [(name: fileName, source: source)])
    }

    // MARK: - J1：全仓扫描

    @Test("J1：test target 里不得对大 Collection 直接 #expect(==) / #expect(!=)")
    func noDirectBitmapComparisons() throws {
        let files = try Self.testSourceFiles()
        try #require(files.count > 80, """
        只枚举到 \(files.count) 个测试源文件 —— 扫描失效，这不是「零违规」。
        """)

        var violations: [Violation] = []
        for root in try Self.testRootDirectories() {
            let loaded: [(name: String, source: String)] = try GuardScanRoots.swiftFiles(in: root).map {
                (GuardScanRoots.relativePath($0), try String(contentsOf: $0, encoding: .utf8))
            }
            violations.append(contentsOf: Self.violations(in: loaded))
        }
        violations.sort { ($0.file, $0.line) < ($1.file, $1.line) }
        #expect(violations.isEmpty, """
        以下断言把**大 Collection**（`Data` / `[UInt8]` / 像素缓冲）直接交给了
        `#expect` / `#require` 的 `==` / `!=`（共 \(violations.count) 处）：

        \(violations.map(\.description).joined(separator: "\n"))

        ⚠️ 这类断言**判红时不判红，而是挂住**：swift-testing 会去求
        `CollectionDifference`，两幅 160 000 字节的无关位图实测 90 秒不收敛
        （SIGALRM，一行汇总都没打印）。而失效的恰好是最该判红的那一类变异
        ——整层被绕过 ⇒ 整幅图都变 ⇒ 差分规模爆炸。

        处置（任选，两种本判据都放行）：
        · `expectBitmapsEqual(a, b, "…")` / `expectBitmapsDiffer(a, b, "…")`
          —— 见 `BitmapExpectations.swift`，失败信息自带指纹与首个相异下标；
        · `let matches = a == b; #expect(matches, "…")` —— #291 / #294 的成法。
        """)
    }

    // MARK: - J2：扫描根与 manifest 双向一致

    @Test("J2：扫描根与 Package.swift 里声明的 test target 双向一致")
    func scanRootsMatchTheManifest() throws {
        let directories = Set(try Self.testRootDirectories().map(\.lastPathComponent))
        try #require(directories.count >= 3, """
        `Tests/` 下只找到 \(directories.count) 个子目录 —— 扫描根解析失效，这不是「零违规」。
        """)

        let declared = Set(try GuardScanRoots.declaredTargets().filter { !$0.isLibrary }.map(\.name))
        #expect(declared == directories, """
        `Tests/` 的子目录 \(directories.sorted()) 与 `Package.swift` 里声明的
        非 library target \(declared.sorted()) 不一致。

        · 目录多出来 ⇒ 那份源码不属于任何 target，`swift test` 根本不编它；
        · manifest 多出来 ⇒ 该 target 的源码不在 `Tests/<名字>/`，本判据扫不到它
          （fail-open：它里面写什么位图断言都不受约束）。
        """)
    }

    // MARK: - J3：判据自证会开火（AD-E：能触发红的 fixture）

    nonisolated static let firingFixtures: [(name: String, source: String)] = [
        ("裸写法：局部绑定 + `==`", """
        struct T {
            static func pixels(_ v: Int) -> Data? { nil }
            func t() {
                let a = T.pixels(0)
                let b = T.pixels(1)
                #expect(a == b, "…")
            }
        }
        """),
        ("`!=` 与 `==` 同罚", """
        struct T {
            static func shot(_ v: Int) -> Data? { nil }
            func t() {
                let a = T.shot(0), b = T.shot(1)
                #expect(a != b)
            }
        }
        """),
        ("`#require` 与 `#expect` 同罚", """
        struct T {
            static func shot(_ v: Int) -> Data? { nil }
            func t() throws {
                let a = T.shot(0), b = T.shot(1)
                try #require(a == b)
            }
        }
        """),
        ("typealias 别名藏住 Data", """
        typealias Bitmap = Data
        struct T {
            static func shot(_ v: Int) -> Bitmap? { nil }
            func t() {
                let a = T.shot(0), b = T.shot(1)
                #expect(a == b)
            }
        }
        """),
        ("typealias 别名藏住 [UInt8]", """
        typealias Buffer = [UInt8]
        struct T {
            static func grab(_ v: Int) -> Buffer { [] }
            func t() { #expect(T.grab(0) == T.grab(1)) }
        }
        """),
        ("显式类型前缀（跨类型限定名）", """
        struct Other {
            static func shot(_ v: Int) -> Data? { nil }
        }
        struct T {
            func t() { #expect(Other.shot(0) == Other.shot(1)) }
        }
        """),
        ("函数参数位承载位图", """
        struct T {
            func check(_ a: Data, _ b: Data) { #expect(a == b, "…") }
        }
        """),
        ("显式类型标注的局部量（没有任何 helper 调用）", """
        struct T {
            func t() {
                let a: Data = Data()
                let b: Data = Data()
                #expect(a == b)
            }
        }
        """),
        ("藏在 `&&` 里的那一半", """
        struct T {
            static func shot(_ v: Int) -> Data? { nil }
            func t() {
                let a = T.shot(0), b = T.shot(1)
                #expect(a != nil && a == b)
            }
        }
        """),
        ("名字启发式兜底：返回类型解析不出，但名字是位图", """
        struct T {
            static func framePixels(_ v: Int) -> SomeOpaqueThing { .init() }
            func t() { #expect(T.framePixels(0) == T.framePixels(1)) }
        }
        """),
        ("字典/数组容器里的位图", """
        struct T {
            func t() {
                let shots: [String: Data] = [:]
                #expect(shots["a"] == shots["b"])
            }
        }
        """),
        ("跨文件：helper 声明在另一个文件里", """
        struct Consumer {
            func t() { #expect(Producer.pixels(0) == Producer.pixels(1)) }
        }
        """),
        ("`guard let` 解包后的非可选位图", """
        struct T {
            static func shot(_ v: Int) -> Data? { nil }
            func t() {
                guard let a = T.shot(0), let b = T.shot(1) else { return }
                #expect(a == b, "…")
            }
        }
        """),
        ("`if let` 解包后的非可选位图（绑定写在条件里）", """
        struct T {
            static func shot(_ v: Int) -> Data? { nil }
            func t() {
                if let a = T.shot(0), let b = T.shot(1) {
                    #expect(a == b)
                }
            }
        }
        """),
        ("标量成员只出现在实参里（`.size` 不是这条比较的头）", """
        struct T {
            static func pixels(_ v: Int, size: CGSize) -> Data? { nil }
            func t() {
                let canvas = CGRect.zero
                #expect(T.pixels(0, size: canvas.size) == T.pixels(1, size: canvas.size))
            }
        }
        """),
    ]

    nonisolated static let crossFileProducer = """
    struct Producer {
        static func pixels(_ v: Int) -> Data? { nil }
    }
    """

    nonisolated static let silentFixtures: [(name: String, source: String)] = [
        ("`!= nil` 是可选性检查，不是位图比较", """
        struct T {
            static func pixels(_ v: Int) -> Data? { nil }
            func t() {
                let a = T.pixels(0), b = T.pixels(1)
                #expect(a != nil && b != nil)
            }
        }
        """),
        ("归约成标量之后比较", """
        struct T {
            static func pixels(_ v: Int) -> Data? { nil }
            func t() {
                let a = T.pixels(0), b = T.pixels(1)
                #expect(a?.count == b?.count)
            }
        }
        """),
        ("成法一：`let matches = a == b`", """
        struct T {
            static func pixels(_ v: Int) -> Data? { nil }
            func t() {
                let a = T.pixels(0), b = T.pixels(1)
                let matches = a == b
                #expect(matches, "…")
            }
        }
        """),
        ("成法二：走 expectBitmapsEqual", """
        struct T {
            static func pixels(_ v: Int) -> Data? { nil }
            func t() {
                let a = T.pixels(0), b = T.pixels(1)
                expectBitmapsEqual(a, b, "…")
            }
        }
        """),
        ("包装进非 Collection 值类型（实测 0.037 s 判红 —— 第三种被认可的形态）", """
        struct Frame: Equatable { let bytes: Data }
        struct T {
            static func grab(_ v: Int) -> Frame { Frame(bytes: Data()) }
            func t() {
                let a = T.grab(0), b = T.grab(1)
                #expect(a == b)
            }
        }
        """),
        ("最外层是取色函数，只是操作数里出现了同名的位图绑定", """
        struct T {
            static func pixels(_ v: Int) -> Data? { nil }
            func t() {
                let red = T.pixels(0)
                expectBitmapsEqual(red, T.pixels(1))
                #expect([Color.red, .blue].particleColor(at: 2) == .red)
            }
        }
        """),
        ("`elementsEqual` 已经是 Bool（实测 0.038 s 判红，不是逃逸口子）", """
        struct T {
            static func pixels(_ v: Int) -> Data { Data() }
            func t() { #expect(T.pixels(0).elementsEqual(T.pixels(1))) }
        }
        """),
        ("同名局部量在另一个函数里是 CGSize —— 作用域必须分得开", """
        struct T {
            static func pixels(_ v: Int) -> Data? { nil }
            static func size(_ v: Int) -> CGSize { .zero }
            func a() {
                let one = T.pixels(0), all = T.pixels(1)
                expectBitmapsEqual(one, all)
            }
            func b() {
                let one = T.size(0)
                let all = T.size(1)
                #expect(one == all, "布局尺寸")
            }
        }
        """),
        ("非位图的普通相等断言", """
        struct T {
            func t() {
                let name = "x"
                #expect(name == "x")
                #expect(3 == 3)
            }
        }
        """),
        ("名字里含 Data 的具名类型不是位图", """
        struct Metadata: Equatable { let tag: Int }
        struct T {
            func t() {
                let a: Metadata = .init(tag: 0)
                let b: Metadata = .init(tag: 1)
                #expect(a == b)
            }
        }
        """),
    ]

    @Test("J3：判据自证会开火 —— 15 种等价改写逐个打红")
    func judgeFiresOnEveryEquivalentRewrite() {
        for fixture in Self.firingFixtures {
            let files: [(name: String, source: String)] =
                fixture.name.hasPrefix("跨文件")
                ? [("producer.swift", Self.crossFileProducer), ("fixture.swift", fixture.source)]
                : [("fixture.swift", fixture.source)]
            let hits = Self.violations(in: files)
            #expect(!hits.isEmpty, """
            fixture「\(fixture.name)」**没有**被判红 —— 这条等价改写可以从判据下走过去。

            \(fixture.source)
            """)
        }
    }

    @Test("J3b：判据不是恒真 —— 10 种合规写法逐个放行")
    func judgeStaysSilentOnSanctionedForms() {
        for fixture in Self.silentFixtures {
            let hits = Self.violations(inSource: fixture.source)
            #expect(hits.isEmpty, """
            fixture「\(fixture.name)」被误判红了 —— 判据过宽会把合规写法一起挡掉：

            \(hits.map(\.description).joined(separator: "\n"))

            \(fixture.source)
            """)
        }
    }

    // MARK: - J4：两份 `BitmapExpectations.swift` 拷贝必须同步

    @Test("J4：每个带 BitmapExpectations.swift 的 test target 里，拷贝逐字节相同")
    func copiesAreInSync() throws {
        let candidates = try Self.testRootDirectories()
            .map { $0.appendingPathComponent("BitmapExpectations.swift") }
        let present = candidates.filter { FileManager.default.fileExists(atPath: $0.path) }

        try #require(present.count >= 2, """
        `Tests/` 的 \(candidates.count) 个 target 根里只找到 \(present.count) 份
        `BitmapExpectations.swift` —— 归约入口缺失，
        J1 会因为「没人用它」而在一批已经改回裸 `==` 的断言上继续绿。
        找过的位置：
        \(candidates.map { GuardScanRoots.relativePath($0) }.joined(separator: "\n"))
        """)

        let texts = try present.map { try String(contentsOf: $0, encoding: .utf8) }
        let drifted = zip(present, texts).filter { $0.1 != texts[0] }.map { GuardScanRoots.relativePath($0.0) }
        #expect(drifted.isEmpty, """
        以下 `BitmapExpectations.swift` 与 \(GuardScanRoots.relativePath(present[0])) 不同：
        \(drifted.joined(separator: "\n"))
        改动其中一份时必须同步所有拷贝（共 \(present.count) 份）。
        """)
    }

    // MARK: - J5：不得用 XCTest 断言绕过

    @Test("J5：测试代码里不得出现 XCTAssert* 系列断言")
    func noXCTestAssertions() throws {
        let files = try Self.testSourceFiles()
        try #require(files.count > 80, "只枚举到 \(files.count) 个测试源文件 —— 扫描失效")

        var offenders: [String] = []
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            guard file.lastPathComponent != "BitmapExpectationGuard.swift" else { continue }
            let tree = SwiftParser.Parser.parse(source: text)
            let finder = XCTAssertFinder(viewMode: .sourceAccurate)
            finder.walk(tree)
            if !finder.hits.isEmpty {
                offenders.append("\(GuardScanRoots.relativePath(file)): \(finder.hits.sorted().joined(separator: ", "))")
            }
        }
        #expect(offenders.isEmpty, """
        以下文件用了 XCTest 断言：
        \(offenders.joined(separator: "\n"))

        本仓统一用 Swift Testing（`CLAUDE.md`）。就 #293 而言它还是一条**绕过通路**：
        `XCTAssertEqual(a, b)` 同样会为失败信息去展开两个大 `Collection`，
        而 `BitmapExpectationGuard` 只看 `#expect` / `#require`。
        """)
    }
}

// MARK: - 语法遍历器

private nonisolated final class BigTypeCollector: SyntaxVisitor {
    private let known: Set<String>
    private(set) var discovered: Set<String> = []
    private(set) var declaredTypeNames: Set<String> = []

    init(known: Set<String>, viewMode: SyntaxTreeViewMode) {
        self.known = known
        super.init(viewMode: viewMode)
    }

    private func isBig(_ type: TypeSyntax?) -> Bool {
        guard let type else { return false }
        let text = BitmapExpectationGuard.normalizedTypeText(type.trimmedDescription)
        if self.known.contains(text) || self.discovered.contains(text) { return true }
        return BitmapExpectationGuard.baseBigTypeSpellings.contains { spelling in
            spelling.count > 4 && text.contains(spelling)
        } || BitmapExpectationGuard.mentionsBigElementType(text)
    }

    override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        if self.isBig(node.initializer.value) { self.discovered.insert(node.name.text) }
        return .visitChildren
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        self.declaredTypeNames.insert(node.name.text)
        return .visitChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        self.declaredTypeNames.insert(node.name.text)
        return .visitChildren
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        self.declaredTypeNames.insert(node.name.text)
        return .visitChildren
    }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        self.declaredTypeNames.insert(node.name.text)
        return .visitChildren
    }
}

private nonisolated final class BigFunctionCollector: SyntaxVisitor {
    private let bigTypes: Set<String>
    private let declaredTypeNames: Set<String>
    private(set) var names: Set<String> = []
    private(set) var knownNonBitmapNames: Set<String> = []

    init(bigTypes: Set<String>, declaredTypeNames: Set<String>, viewMode: SyntaxTreeViewMode) {
        self.bigTypes = bigTypes
        self.declaredTypeNames = declaredTypeNames
        super.init(viewMode: viewMode)
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard !Self.isNested(node) else { return .visitChildren }
        let name = node.name.text
        guard let returnType = node.signature.returnClause?.type else {
            if BitmapExpectationGuard.looksLikeBitmapName(name) { self.names.insert(name) }
            return .visitChildren
        }
        let text = BitmapExpectationGuard.normalizedTypeText(returnType.trimmedDescription)
        if self.bigTypes.contains(text) {
            self.names.insert(name)
        } else if self.declaredTypeNames.contains(text) {
            self.knownNonBitmapNames.insert(name)
        } else if BitmapExpectationGuard.looksLikeBitmapName(name) {
            self.names.insert(name)
        }
        return .visitChildren
    }

    private static func isNested(_ node: FunctionDeclSyntax) -> Bool {
        var cursor = node.parent
        while let current = cursor {
            if current.is(FunctionDeclSyntax.self) || current.is(ClosureExprSyntax.self)
                || current.is(AccessorDeclSyntax.self) {
                return true
            }
            cursor = current.parent
        }
        return false
    }
}

private nonisolated final class ComparisonFinder: SyntaxVisitor {
    private let bigTypes: Set<String>
    private let bigFunctionNames: Set<String>
    private let knownNonBitmapNames: Set<String>
    private let fileName: String
    private let converter: SourceLocationConverter
    private(set) var violations: [BitmapExpectationGuard.Violation] = []

    init(
        bigTypes: Set<String>,
        bigFunctionNames: Set<String>,
        knownNonBitmapNames: Set<String>,
        fileName: String,
        converter: SourceLocationConverter,
        viewMode: SyntaxTreeViewMode
    ) {
        self.bigTypes = bigTypes
        self.bigFunctionNames = bigFunctionNames
        self.knownNonBitmapNames = knownNonBitmapNames
        self.fileName = fileName
        self.converter = converter
        super.init(viewMode: viewMode)
    }

    override func visit(_ node: MacroExpansionExprSyntax) -> SyntaxVisitorContinueKind {
        guard ["expect", "require"].contains(node.macroName.text),
              let first = node.arguments.first
        else { return .visitChildren }

        for (op, lhs, rhs, whole) in Self.equalityComparisons(in: Syntax(first.expression)) {
            if Self.isLiteral(lhs) || Self.isLiteral(rhs) { continue }
            let lhsBig = self.isBitmapOperand(lhs, at: Syntax(node))
            let rhsBig = self.isBitmapOperand(rhs, at: Syntax(node))
            guard lhsBig || rhsBig else { continue }

            let line = self.converter.location(for: node.positionAfterSkippingLeadingTrivia).line
            self.violations.append(.init(
                file: self.fileName,
                line: line,
                snippet: Self.oneLine(whole),
                reason: "`#\(node.macroName.text)` 的第一个实参里有位图 `\(op)` 比较"
            ))
        }
        return .visitChildren
    }

    private static func equalityComparisons(
        in node: Syntax
    ) -> [(op: String, lhs: ExprSyntax, rhs: ExprSyntax, text: String)] {
        var out: [(op: String, lhs: ExprSyntax, rhs: ExprSyntax, text: String)] = []

        if let sequence = node.as(SequenceExprSyntax.self) {
            let elements = Array(sequence.elements)
            for (index, element) in elements.enumerated() {
                guard let op = element.as(BinaryOperatorExprSyntax.self)?.operator.text,
                      op == "==" || op == "!=",
                      index > 0, index + 1 < elements.count
                else { continue }
                let lhs = elements[index - 1]
                let rhs = elements[index + 1]
                out.append((op, lhs, rhs, "\(lhs.trimmedDescription) \(op) \(rhs.trimmedDescription)"))
            }
        }
        if let infix = node.as(InfixOperatorExprSyntax.self),
           let op = infix.operator.as(BinaryOperatorExprSyntax.self)?.operator.text,
           op == "==" || op == "!=" {
            out.append((op, infix.leftOperand, infix.rightOperand, infix.trimmedDescription))
        }
        for child in node.children(viewMode: .sourceAccurate) {
            out.append(contentsOf: Self.equalityComparisons(in: child))
        }
        return out
    }

    private static func oneLine(_ text: String) -> String {
        let squashed = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
        let joined = squashed.joined(separator: " ")
        return joined.count > 140 ? String(joined.prefix(140)) + "…" : joined
    }

    // MARK: - 操作数分类

    private static func isLiteral(_ expr: ExprSyntax) -> Bool {
        expr.is(NilLiteralExprSyntax.self) || expr.is(BooleanLiteralExprSyntax.self)
            || expr.is(IntegerLiteralExprSyntax.self) || expr.is(FloatLiteralExprSyntax.self)
            || expr.is(StringLiteralExprSyntax.self)
    }

    private func isBitmapOperand(_ expr: ExprSyntax, at site: Syntax) -> Bool {
        if Self.isLiteral(expr) { return false }

        if let head = Self.headName(of: expr) {
            if BitmapExpectationGuard.scalarReducingMembers.contains(head) { return false }
            return self.isBitmapName(head, at: site)
        }

        if Self.mentionsScalarReducer(Syntax(expr)) { return false }
        let names = Self.referencedBaseNames(in: Syntax(expr))
        return names.contains { self.isBitmapName($0, at: site) }
    }

    private func isBitmapName(_ name: String, at site: Syntax) -> Bool {
        if self.bigFunctionNames.contains(name) { return true }
        if self.knownNonBitmapNames.contains(name) { return false }
        if BitmapExpectationGuard.looksLikeBitmapName(name) { return true }
        return self.bitmapBindingsInScope(of: site).contains(name)
    }

    private static func headName(of expr: ExprSyntax) -> String? {
        if let tryExpr = expr.as(TryExprSyntax.self) { return Self.headName(of: tryExpr.expression) }
        if let awaitExpr = expr.as(AwaitExprSyntax.self) { return Self.headName(of: awaitExpr.expression) }
        if let forced = expr.as(ForceUnwrapExprSyntax.self) { return Self.headName(of: forced.expression) }
        if let chained = expr.as(OptionalChainingExprSyntax.self) {
            return Self.headName(of: chained.expression)
        }
        if let call = expr.as(FunctionCallExprSyntax.self) {
            return Self.headName(of: call.calledExpression)
        }
        if let subscriptCall = expr.as(SubscriptCallExprSyntax.self) {
            return Self.headName(of: subscriptCall.calledExpression)
        }
        if let member = expr.as(MemberAccessExprSyntax.self) {
            guard member.base != nil else { return nil }
            return member.declName.baseName.text
        }
        if let ref = expr.as(DeclReferenceExprSyntax.self) { return ref.baseName.text }
        if let macro = expr.as(MacroExpansionExprSyntax.self),
           ["require", "expect"].contains(macro.macroName.text),
           let first = macro.arguments.first {
            return Self.headName(of: first.expression)
        }
        return nil
    }

    private static func mentionsScalarReducer(_ node: Syntax) -> Bool {
        if let member = node.as(MemberAccessExprSyntax.self),
           BitmapExpectationGuard.scalarReducingMembers.contains(member.declName.baseName.text) {
            return true
        }
        for child in node.children(viewMode: .sourceAccurate) where Self.mentionsScalarReducer(child) {
            return true
        }
        return false
    }

    private static func referencedBaseNames(in node: Syntax) -> Set<String> {
        var out: Set<String> = []
        if let member = node.as(MemberAccessExprSyntax.self) {
            guard let base = member.base else { return [] }
            out.insert(member.declName.baseName.text)
            out.formUnion(Self.referencedBaseNames(in: Syntax(base)))
            return out
        }
        if let ref = node.as(DeclReferenceExprSyntax.self) { out.insert(ref.baseName.text) }
        for child in node.children(viewMode: .sourceAccurate) {
            out.formUnion(Self.referencedBaseNames(in: child))
        }
        return out
    }

    private func bitmapBindingsInScope(of site: Syntax) -> Set<String> {
        var out: Set<String> = []
        var cursor: Syntax? = site
        var childPosition = site.position

        while let node = cursor {
            if let block = node.as(CodeBlockItemListSyntax.self) {
                for item in block {
                    if let function = item.item.as(FunctionDeclSyntax.self) {
                        if self.isBigType(function.signature.returnClause?.type)
                            || BitmapExpectationGuard.looksLikeBitmapName(function.name.text) {
                            out.insert(function.name.text)
                        }
                        continue
                    }
                    guard item.position < childPosition else { continue }
                    self.collectBindings(from: Syntax(item.item), into: &out)
                }
            }
            if let members = node.as(MemberBlockItemListSyntax.self) {
                for member in members {
                    self.collectBindings(from: Syntax(member.decl), into: &out)
                }
            }
            if let function = node.as(FunctionDeclSyntax.self) {
                for parameter in function.signature.parameterClause.parameters
                where self.isBigType(parameter.type) {
                    out.insert(parameter.secondName?.text ?? parameter.firstName.text)
                }
            }
            if let ifExpr = node.as(IfExprSyntax.self) {
                self.collectOptionalBindings(from: ifExpr.conditions, into: &out)
            }
            if let whileStmt = node.as(WhileStmtSyntax.self) {
                self.collectOptionalBindings(from: whileStmt.conditions, into: &out)
            }
            childPosition = node.position
            cursor = node.parent
        }
        return out
    }

    private func collectBindings(from item: Syntax, into out: inout Set<String>) {
        if let guardStmt = item.as(GuardStmtSyntax.self) {
            self.collectOptionalBindings(from: guardStmt.conditions, into: &out)
            return
        }
        guard let variable = item.as(VariableDeclSyntax.self) else { return }
        for binding in variable.bindings {
            guard let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
            else { continue }
            if self.isBigType(binding.typeAnnotation?.type) {
                out.insert(name)
                continue
            }
            if BitmapExpectationGuard.looksLikeBitmapName(name) {
                out.insert(name)
                continue
            }
            guard let value = binding.initializer?.value else { continue }
            if self.initializerLooksLikeBitmap(value) { out.insert(name) }
        }
    }

    private func collectOptionalBindings(
        from conditions: ConditionElementListSyntax, into out: inout Set<String>
    ) {
        for condition in conditions {
            guard let binding = condition.condition.as(OptionalBindingConditionSyntax.self),
                  let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
            else { continue }
            if self.isBigType(binding.typeAnnotation?.type) {
                out.insert(name)
                continue
            }
            if BitmapExpectationGuard.looksLikeBitmapName(name) {
                out.insert(name)
                continue
            }
            guard let value = binding.initializer?.value else { continue }
            if self.initializerLooksLikeBitmap(value) { out.insert(name) }
        }
    }

    private func initializerLooksLikeBitmap(_ value: ExprSyntax) -> Bool {
        if let head = Self.headName(of: value) {
            return self.bigFunctionNames.contains(head)
                || (!self.knownNonBitmapNames.contains(head)
                    && BitmapExpectationGuard.looksLikeBitmapName(head))
        }
        let names = Self.referencedBaseNames(in: Syntax(value))
        return names.contains(where: { self.bigFunctionNames.contains($0) })
            || names.contains(where: BitmapExpectationGuard.looksLikeBitmapName)
    }

    private func isBigType(_ type: TypeSyntax?) -> Bool {
        guard let type else { return false }
        let text = BitmapExpectationGuard.normalizedTypeText(type.trimmedDescription)
        if self.bigTypes.contains(text) { return true }
        return BitmapExpectationGuard.mentionsBigElementType(text)
    }
}

private nonisolated final class XCTAssertFinder: SyntaxVisitor {
    private(set) var hits: Set<String> = []

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard let callee = Self.calleeBaseName(of: node.calledExpression) else { return .visitChildren }
        if callee.hasPrefix("XCTAssert") || callee == "XCTFail" || callee == "XCTUnwrap" {
            self.hits.insert(callee)
        }
        return .visitChildren
    }

    private static func calleeBaseName(of expr: ExprSyntax) -> String? {
        if let ref = expr.as(DeclReferenceExprSyntax.self) { return ref.baseName.text }
        if let member = expr.as(MemberAccessExprSyntax.self) { return member.declName.baseName.text }
        return nil
    }
}
