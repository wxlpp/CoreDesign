import Foundation
import SwiftParser
import SwiftSyntax
import Testing

// MARK: - 新 target 禁 chrome 文案裸字面量 / No bare chrome text literals（Issue #246）
//
// 公约 **G-4**（`docs/component-contract.md:1017`）逐字：「**A 类**文案不经任何一路进入
// FR-4 的机器视野……评审（无机器判据）」。A 类 = 组件自己写死在 `body` 里的 chrome 文案
// （`Text("Loading…")` / `Label("Retry", systemImage:)`），与 B 类（public init 的裸文本
// **参数**）是两回事——后者由 `ComponentTextParamGuard` 以**登记表条目**为定义域守着，
// 结构上守不到 A 类。
//
// ⚠️ **`ComponentTextParamGuard` 不在本 task 处理**（`#246` 任务书 Technical Details）：
// 它的扩展与 FR-7 边界编码归 `shipswift-effects` 的 A-6（与 `47→51` 同一处）。
// 本守卫是**另建**的一条，专打 A 类，不碰它的 `== 31`。
//
// ## 射程：**只有新 target**，且**不回溯改造 CoreDesign 现状**
//
// `GuardScanRoots.newTargetRoots`。主 target 现有 198 处 `Text("…")`——公约自己写着
// 「连 CoreDesign 自己都没守住 A 类」，回溯治理不是本 task 的题目。
// ⚠️ 但主 target 仍被当**靶场**用（`detectorFiresOnRealSource`）：新 target 今天命中必然
// 为 0，「零违规」与「探测器坏了」在这种输入上不可分辨。
//
// ## 已知的两个口子（写在明处，不是漏了）
//
// 1. **`Text(verbatim:)` 不判违规**——它是「这串东西不是给人读的自然语言」的显式声明
//    （数字、用户数据、符号）。它可 grep、可评审，比逼人把 verbatim 改写成别的形状好。
//    本守卫**清点**它并打印，让滥用看得见。
// 2. **`#Preview` 整体跳过**——预览是视觉冒烟入口、不是产品路径（与 a11y 守卫跳过
//    `#if DEBUG` 同一条裁断）。
@Suite("新 target 禁 chrome 文案裸字面量")
struct ChromeTextLiteralGuard {

    /// 承载 chrome 文案的构造器。第一个**无标签**实参是字面量即违规。
    ///
    /// ⚠️ `Label` 只看第一个实参：`Label("Retry", systemImage: "arrow")` 里
    /// `systemImage:` 的值是 SF Symbol 名，不是给人读的文案，翻译它是错的。
    nonisolated static let textConstructors: Set<String> = ["Text", "Label"]

    nonisolated struct Violation: Hashable, Sendable {
        let file: String
        let line: Int
        let literal: String
        let snippet: String
        var description: String { "\(self.file):\(self.line) → 「\(self.literal)」| \(self.snippet)" }
    }

    nonisolated struct ScanResult: Sendable {
        var violations: [Violation] = []
        /// `Text(verbatim:)` 的清点（不判违规，见文件头口子 1）。
        var verbatimSites: [String] = []
    }

    /// 一个字面量是否算「文案」。
    ///
    /// ⚠️ **要求至少含一个字母**：`Text("")` / `Text(" ")` / `Text("•")` 不是可翻译的
    /// 自然语言，判它们违规只会制造噪音。这是一条**收窄**，写在明处——
    /// 「用全角符号拼一句话」能绕过去，但那已经不是本守卫要防的失效形态了。
    nonisolated static func isProse(_ literal: String) -> Bool {
        literal.contains(where: { $0.isLetter })
    }

    /// 合成输入入口——变红自证与边界形态都走它，不碰磁盘。
    static func scan(source: String, fileName: String = "Synthetic.swift") -> ScanResult {
        let tree = SwiftParser.Parser.parse(source: source)
        if tree.hasError {
            Issue.record("解析出错：\(fileName) —— swift-syntax major 可能与工具链不配套")
        }
        let converter = SourceLocationConverter(fileName: fileName, tree: tree)
        let collector = ChromeTextCollector(fileName: fileName, converter: converter)
        collector.walk(tree)
        return ScanResult(violations: collector.violations, verbatimSites: collector.verbatimSites)
    }

    static func scan(root: URL) throws -> ScanResult {
        var out = ScanResult()
        for url in GuardScanRoots.swiftFiles(in: root) {
            let partial = Self.scan(
                source: try String(contentsOf: url, encoding: .utf8),
                fileName: GuardScanRoots.relativePath(url)
            )
            out.violations += partial.violations
            out.verbatimSites += partial.verbatimSites
        }
        return out
    }

    @Test("新 target 里零 chrome 文案裸字面量（公约 A 类）")
    func noBareChromeTextInNewTargets() throws {
        #expect(GuardScanRoots.assertRootsExist(GuardScanRoots.newTargetRoots))

        var result = ScanResult()
        var scannedFiles = 0
        for root in GuardScanRoots.newTargetRoots {
            let files = GuardScanRoots.swiftFiles(in: root.url)
            #expect(!files.isEmpty, "\(root.target) 下没有任何 .swift 文件 —— 本守卫在它上面恒绿")
            scannedFiles += files.count
            let partial = try Self.scan(root: root.url)
            result.violations += partial.violations
            result.verbatimSites += partial.verbatimSites
        }
        #expect(scannedFiles > 0, "新 target 一个源文件都没扫到 —— 「零违规」不可信")

        // ⚠️ 口子 1 的可见化：`verbatim:` 不判违规，但要打印出来，滥用才看得见。
        print("【chrome 文案】新 target 的 `Text(verbatim:)` 共 \(result.verbatimSites.count) 处：\(result.verbatimSites)")

        #expect(result.violations.isEmpty, """
        新 target 里出现了写死的 chrome 文案（公约 A 类）：
        \(result.violations.map(\.description).joined(separator: "\n"))
        —— 下游 App 换语言时这些字会突然说英文，而组件自己不带 String Catalog。
        处置（按优先级）：
        1. 把文案**交给调用方**（做成 init 参数，那样它落 B 类、由登记表的 textParams 管）；
        2. 确实该由库提供时，走 `String(localized:bundle:)` 指向**该 target 自己的**
           String Catalog（`Package.swift` 的 `resources:` + `Sources/<target>/Resources/`；
           ⚠️ 新 target 今天**没有**资源包，写 `bundle: .module` 编译不过）；
        3. 那串东西根本不是自然语言（数字 / 符号 / 用户数据）时用 `Text(verbatim:)`，
           它会被清点并打印出来。
        """)
    }

    @Test("探测器真的会开火：合成输入逐形态变红自证")
    func detectorFiresOnSyntheticSource() {
        // ⚠️ `#246` AC「每条新守卫必须附一个会让它变红的 fixture」的落点。
        let cases: [(name: String, source: String, literal: String)] = [
            ("`Text(\"…\")`", """
            import SwiftUI
            public struct A: View {
                public var body: some View { Text("Loading") }
            }
            """, "Loading"),
            ("`Label(\"…\", systemImage:)`", """
            import SwiftUI
            public struct B: View {
                public var body: some View { Label("Retry", systemImage: "arrow.clockwise") }
            }
            """, "Retry"),
            ("折行写法", """
            import SwiftUI
            let t = Text(
                "Something went wrong"
            )
            """, "Something went wrong"),
        ]
        for c in cases {
            let hits = Self.scan(source: c.source).violations
            #expect(hits.contains(where: { $0.literal == c.literal }),
                    "\(c.name)：探测器漏报（期望「\(c.literal)」，实得 \(hits.map(\.literal))）—— 上面那条「零违规」毫无意义")
        }

        // 反向：不该误报的形态。
        let clean: [(name: String, source: String)] = [
            ("文案来自参数", """
            import SwiftUI
            public struct C: View {
                let title: String
                public var body: some View { Text(self.title) }
            }
            """),
            ("走 String Catalog", #"let t = Text(String(localized: "Loading", bundle: .module))"#),
            ("`Text(verbatim:)`（口子 1，只清点）", #"let t = Text(verbatim: "42")"#),
            ("`Label` 的 systemImage 不是文案", """
            import SwiftUI
            let l = Label(self.title, systemImage: "star")
            """),
            ("非文案字面量（无字母）", #"let t = Text("•")"#),
            ("`#Preview` 里的写死文案（有意跳过，见文件头）", """
            import SwiftUI
            #Preview { Text("Preview only") }
            """),
            ("同名但不是 SwiftUI 构造（注释与字符串）", """
            // Text("in a comment")
            let s = "Label(\\"in a string\\")"
            """),
        ]
        for c in clean {
            let hits = Self.scan(source: c.source).violations
            #expect(hits.isEmpty, "\(c.name)：误报 \(hits.map(\.description))")
        }

        // 口子 1 真的被清点了（不判违规 ≠ 看不见）。
        #expect(Self.scan(source: #"let t = Text(verbatim: "42")"#).verbatimSites.count == 1,
                "`Text(verbatim:)` 没有被清点 —— 那个口子就真成了盲区")
    }

    @Test("探测器在真实源码上非真空：拿主 target 当靶场必须打出命中")
    func detectorFiresOnRealSource() throws {
        // ⚠️ 与 `EffectsColorLiteralGuard` 同款：`CoreDesign` **不在射程内**
        // （公约 G-4 明载连它自己都没守住 A 类），这里只把它当靶场用。
        let hits = try Self.scan(root: GuardScanRoots.sourcesURL(of: GuardScanRoots.primaryTargetName)).violations
        #expect(hits.count > 10, """
        在 Sources/CoreDesign 上只打出 \(hits.count) 处裸 chrome 文案 —— 探测器疑似失效。
        本条**不是**要求主 target 保持违规，而是「新 target 的零命中来自干净、不是来自
        坏掉的探测器」这句话的活证据。主 target 真被治理干净时，请改成扫常驻 fixture，
        不要直接删掉它。
        """)
    }
}

// MARK: - 采集器 / Collector

private nonisolated final class ChromeTextCollector: SyntaxVisitor {
    var violations: [ChromeTextLiteralGuard.Violation] = []
    var verbatimSites: [String] = []

    private let fileName: String
    private let converter: SourceLocationConverter

    init(fileName: String, converter: SourceLocationConverter) {
        self.fileName = fileName
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: MacroExpansionDeclSyntax) -> SyntaxVisitorContinueKind {
        node.macroName.text == "Preview" ? .skipChildren : .visitChildren
    }
    override func visit(_ node: MacroExpansionExprSyntax) -> SyntaxVisitorContinueKind {
        node.macroName.text == "Preview" ? .skipChildren : .visitChildren
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard let callee = node.calledExpression.as(DeclReferenceExprSyntax.self),
              ChromeTextLiteralGuard.textConstructors.contains(callee.baseName.text),
              let first = node.arguments.first
        else { return .visitChildren }

        let line = self.converter.location(for: node.positionAfterSkippingLeadingTrivia).line
        let snippet = node.trimmedDescription
            .split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: " ")

        // 口子 1：`Text(verbatim:)` 只清点。
        if first.label?.text == "verbatim" {
            self.verbatimSites.append("\(self.fileName):\(line)")
            return .visitChildren
        }
        // 只看**第一个无标签实参**——`systemImage:` 之类的值不是给人读的文案。
        guard first.label == nil,
              let literal = first.expression.as(StringLiteralExprSyntax.self)
        else { return .visitChildren }

        let text = literal.segments.compactMap { segment -> String? in
            segment.as(StringSegmentSyntax.self)?.content.text
        }.joined()
        guard ChromeTextLiteralGuard.isProse(text) else { return .visitChildren }

        self.violations.append(
            .init(file: self.fileName, line: line, literal: text, snippet: String(snippet.prefix(120)))
        )
        return .visitChildren
    }
}
