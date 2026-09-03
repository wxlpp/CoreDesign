import Foundation
import SwiftParser
import SwiftSyntax
import Testing

// MARK: - 新 target 禁色相字面量 / No hue literals in the new targets（Issue #246）
//
// 本仓的四层色彩系统（`CLAUDE.md`《分层色彩系统》）明写「不要在组件中直接使用底层原子色」，
// 而 `0.3.0` 把地基换成 Apple HIG 之后，第 3 层多数 token 直接指系统语义色、随系统外观
// 与对比度设置自动更新。**一个写死 `.cyan` 的动效在暗色模式 / 高对比度下就是坏的**，
// 而且它不会报错、只会难看——没有机器判据的话，表达性视觉层正是最容易堆积这类硬编码的地方。
//
// ## 射程：**只有新 target**
//
// `GuardScanRoots.newTargetRoots`（`CoreDesignEffects` / `CoreDesignCharts`）。
// **不回溯改造 `CoreDesign` 现状**（`#246` 任务书逐字）：主 target 现有 120 处色相字面量，
// 其中相当一部分是 `ColorExtension` 的调色板实现本身与 glass 描边的既有裁决，
// 回溯改造不是本 task 的题目。
//
// ⚠️ **但 `CoreDesign` 在本文件里仍有用处**——见 `detectorFiresOnRealSource`：
// 它是**探测器非真空的活证据**。两个新 target 今天是骨架文件、命中必然为 0，
// 「零违规」与「探测器坏了」在这种输入上**不可分辨**；拿主 target 当靶场跑一遍，
// 零命中就说明探测器失效，而不是「新 target 很干净」。
//
// ## 判据形态：语法树，不是 grep
//
// 逐字符 grep 会把注释与字符串里的 `.white` 一起抓进来（主 target 的 120 处命中里
// 就有一大半在文档注释里）。这里走 SwiftSyntax：
// · **隐式成员访问** `.cyan` / `.white.opacity(0.2)`（`.white` 自身是一个成员访问）；
// · **显式限定** `Color.cyan` / `UIColor.systemPink` 里的色相名；
// · **数值构造** `Color(red:green:blue:)` / `Color(white:)` / `Color(hue:…)` /
//   `UIColor(red:…)` / `NSColor(…)`。
//
// ⚠️ **`#Preview` 整体跳过**：预览是视觉冒烟入口、不是产品路径（与 a11y 守卫跳过
// `#if DEBUG` 同一条裁断）。这是一个**已知的口子**：把违规写进 `#Preview` 里它看不见。
// 之所以接受：预览块不进消费者的二进制，而禁止预览里用 `.red` 会把「拿原色标出布局边界」
// 这种正当用法也一起禁掉。
@Suite("新 target 禁色相字面量")
struct EffectsColorLiteralGuard {

    /// SwiftUI / UIKit / AppKit 的具名色相。
    ///
    /// ⚠️ **`.clear` 不在表里**：它不是色相，是「不画」。
    /// ⚠️ **`.primary` / `.secondary` / `.accentColor` 也不在表里**：它们本身就是语义色。
    nonisolated static let hueNames: Set<String> = [
        "black", "blue", "brown", "cyan", "gray", "green", "indigo", "mint",
        "orange", "pink", "purple", "red", "teal", "white", "yellow",
    ]

    /// 允许作为色相名前缀的限定符（`Color.cyan` 合法地被抓，`rgba.red` 不被抓）。
    nonisolated static let colorTypeNames: Set<String> = ["Color", "UIColor", "NSColor", "CGColor", "SwiftUI"]

    /// 数值构造的实参标签——命中其一即判「用数字调色」。
    nonisolated static let numericColorLabels: Set<String> = ["red", "white", "hue"]

    nonisolated struct Violation: Hashable, Sendable {
        let file: String
        let line: Int
        let snippet: String
        var description: String { "\(self.file):\(self.line) → \(self.snippet)" }
    }

    /// 合成输入入口——变红自证与边界形态都走它，不碰磁盘。
    static func scan(source: String, fileName: String = "Synthetic.swift") -> [Violation] {
        let tree = SwiftParser.Parser.parse(source: source)
        if tree.hasError {
            Issue.record("解析出错：\(fileName) —— swift-syntax major 可能与工具链不配套")
        }
        let converter = SourceLocationConverter(fileName: fileName, tree: tree)
        let collector = ColorLiteralCollector(fileName: fileName, converter: converter)
        collector.walk(tree)
        return collector.violations
    }

    /// 扫一个根，返回全部命中。
    static func scan(root: URL) throws -> [Violation] {
        var out: [Violation] = []
        for url in GuardScanRoots.swiftFiles(in: root) {
            out += Self.scan(
                source: try String(contentsOf: url, encoding: .utf8),
                fileName: GuardScanRoots.relativePath(url)
            )
        }
        return out
    }

    @Test("新 target 里零色相字面量")
    func noColorLiteralsInNewTargets() throws {
        #expect(GuardScanRoots.assertRootsExist(GuardScanRoots.newTargetRoots))

        var offenders: [Violation] = []
        var scannedFiles = 0
        for root in GuardScanRoots.newTargetRoots {
            let files = GuardScanRoots.swiftFiles(in: root.url)
            // ⚠️ 逐根非空：目录在、文件没有 ⇒ 扫描器恒绿。
            #expect(!files.isEmpty, "\(root.target) 下没有任何 .swift 文件 —— 本守卫在它上面恒绿")
            scannedFiles += files.count
            offenders += try Self.scan(root: root.url)
        }
        #expect(scannedFiles > 0, "新 target 一个源文件都没扫到 —— 「零违规」不可信")

        #expect(offenders.isEmpty, """
        新 target 里出现了色相字面量：
        \(offenders.map(\.description).joined(separator: "\n"))
        —— 本仓的色彩系统分四层，组件层只许用第 3/4 层的语义 token
        （`Color.accent` / `Color.contentPrimary` / `Color.statusDangerForeground` …）。
        写死的色相在暗色模式 / 高对比度下不会报错，只会难看。
        处置：换成已有语义 token；缺 token 就去 `Sources/CoreDesign/Colors/` 补一个**名字**，
        不要把色相硬编码进新 target。
        """)
    }

    @Test("探测器真的会开火：合成输入逐形态变红自证")
    func detectorFiresOnSyntheticSource() {
        // ⚠️ **本条是 `#246` AC「每条新守卫必须附一个会让它变红的 fixture」的落点**：
        // 两个新 target 今天是骨架文件，上面那条判据在 0 个命中上**必绿**，
        // 「零违规」与「探测器坏了」不可分辨。逐形态钉死。
        let cases: [(name: String, source: String)] = [
            ("隐式成员访问 `.cyan`", """
            import SwiftUI
            public struct A: View {
                public var body: some View { Color.clear.foregroundStyle(.cyan) }
            }
            """),
            ("`.white.opacity(…)`（AC 点名形态）", """
            import SwiftUI
            public struct B: View {
                public var body: some View { Color.clear.overlay(.white.opacity(0.2)) }
            }
            """),
            ("显式限定 `Color.red`", """
            import SwiftUI
            let c = Color.red
            """),
            ("数值构造 `Color(red:green:blue:)`（AC 点名形态）", """
            import SwiftUI
            let c = Color(red: 0.1, green: 0.2, blue: 0.3)
            """),
            ("数值构造 `Color(white:)`", """
            import SwiftUI
            let c = Color(white: 0.5)
            """),
            ("数值构造 `UIColor(hue:…)`", """
            import UIKit
            let c = UIColor(hue: 0.5, saturation: 1, brightness: 1, alpha: 1)
            """),
        ]
        for c in cases {
            #expect(!Self.scan(source: c.source).isEmpty, "\(c.name)：探测器漏报 —— 上面那条「零违规」毫无意义")
        }

        // 反向：不该误报的形态。
        let clean: [(name: String, source: String)] = [
            ("语义 token", "let c = Color.accent"),
            ("`.clear` 不是色相", "let c = Color.clear"),
            ("`.primary` / `.secondary` 是语义色", "let a = Color.primary; let b = Color.secondary"),
            ("同名成员但宿主不是颜色类型", "let v = pixel.red + pixel.green"),
            ("注释与字符串里的色相名", """
            // 这里说的是 .white 与 Color(red: 1, green: 0, blue: 0)
            let s = "白色 .white"
            """),
            ("`#Preview` 里的原色（有意跳过，见文件头）", """
            import SwiftUI
            #Preview { Color.red }
            """),
        ]
        for c in clean {
            let hits = Self.scan(source: c.source)
            #expect(hits.isEmpty, "\(c.name)：误报 \(hits.map(\.description))")
        }
    }

    @Test("探测器在真实源码上非真空：拿主 target 当靶场必须打出命中")
    func detectorFiresOnRealSource() throws {
        // ⚠️ **`CoreDesign` 不在本守卫射程内**（`#246` 明写不回溯改造），
        // 这里只把它当**靶场**：真实源码里必然有色相字面量（`ColorExtension` 的调色板、
        // glass 描边的 `.white.opacity(…)`）。零命中 ⇒ 探测器失效，
        // 那么新 target 上的「零违规」同样不可信。
        let hits = try Self.scan(root: GuardScanRoots.sourcesURL(of: GuardScanRoots.primaryTargetName))
        #expect(hits.count > 10, """
        在 Sources/CoreDesign 上只打出 \(hits.count) 处色相字面量 —— 探测器疑似失效。
        本条**不是**要求主 target 保持违规，而是「新 target 的零命中必须来自干净、
        不是来自坏掉的探测器」这句话的活证据。若主 target 真的被治理干净了，
        请把本条改成扫一份常驻 fixture，而不是直接删掉它。
        """)
    }
}

// MARK: - 采集器 / Collector

/// 采集色相字面量。
///
/// ⚠️ **`base` 判别是刻意的**：只认「隐式成员访问」（`.cyan`）与「颜色类型限定」
/// （`Color.cyan`）两种。`pixel.red` 这类同名成员不算——否则任何叫 `red` 的属性
/// 都会变成违规，判据会淹在假阳性里、最后被人整条关掉。
private nonisolated final class ColorLiteralCollector: SyntaxVisitor {
    var violations: [EffectsColorLiteralGuard.Violation] = []

    private let fileName: String
    private let converter: SourceLocationConverter

    init(fileName: String, converter: SourceLocationConverter) {
        self.fileName = fileName
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    /// `#Preview { … }` 整体跳过——预览不是产品路径（见文件头的裁断与它的已知口子）。
    override func visit(_ node: MacroExpansionDeclSyntax) -> SyntaxVisitorContinueKind {
        node.macroName.text == "Preview" ? .skipChildren : .visitChildren
    }
    override func visit(_ node: MacroExpansionExprSyntax) -> SyntaxVisitorContinueKind {
        node.macroName.text == "Preview" ? .skipChildren : .visitChildren
    }

    override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
        let name = node.declName.baseName.text
        guard EffectsColorLiteralGuard.hueNames.contains(name) else { return .visitChildren }
        // base 为 nil ⇒ 隐式成员访问 `.cyan`；否则必须是颜色类型名。
        if let base = node.base {
            let root = base.trimmedDescription.split(separator: ".").map(String.init)
            guard let first = root.first,
                  EffectsColorLiteralGuard.colorTypeNames.contains(first) else { return .visitChildren }
        }
        self.record(node, snippet: node.trimmedDescription)
        return .visitChildren
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        let callee = node.calledExpression.trimmedDescription.split(separator: ".").map(String.init)
        guard let typeName = callee.last,
              EffectsColorLiteralGuard.colorTypeNames.contains(typeName) else { return .visitChildren }
        let labels = node.arguments.compactMap { $0.label?.text }
        guard labels.contains(where: { EffectsColorLiteralGuard.numericColorLabels.contains($0) })
        else { return .visitChildren }
        self.record(node, snippet: node.trimmedDescription)
        return .visitChildren
    }

    private func record(_ node: some SyntaxProtocol, snippet: String) {
        let line = self.converter.location(for: node.positionAfterSkippingLeadingTrivia).line
        // 长表达式截断，报错信息才读得下去。
        let oneLine = snippet.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: " ")
        self.violations.append(
            .init(file: self.fileName, line: line, snippet: String(oneLine.prefix(120)))
        )
    }
}
