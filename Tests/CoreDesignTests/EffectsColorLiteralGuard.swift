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
// · **显式限定** `Color.cyan` / `UIColor.red` / `SwiftUI.Color.white` 里的色相名；
// · **数值构造** `Color(red:green:blue:)` / `Color(white:)` / `Color(hue:…)` /
//   `UIColor(red:…)` / `NSColor(…)`，**含 `.init` 形态**
//   `Color.init(red:…)` / `SwiftUI.Color.init(white:)` / `let c: Color = .init(red:…)`；
// · **`#colorLiteral(red:green:blue:alpha:)`** —— Xcode 取色器自动插入的那一种。
//
// ## 三个**已知的口子**（写在明处，不是漏了）
//
// 1. **`#Preview` 整体跳过**：预览是视觉冒烟入口、不是产品路径（与 a11y 守卫跳过
//    `#if DEBUG` 同一条裁断）。把违规写进 `#Preview` 里它看不见。之所以接受：
//    预览块不进消费者的二进制，而禁止预览里用 `.red` 会把「拿原色标出布局边界」
//    这种正当用法也一起禁掉。
// 2. **`system*` 族有意不算色相**（PR #265 终审 I-1 的裁定，见 `hueNames` 的文档）。
// 3. **本守卫暂无例外台账**——本仓其余守卫（`bool-exemptions.json` /
//    `a11y-exemptions.json` / `knownMissingExtensionPoints`）都有带署名理由的逐站点
//    逃生门，本条与 `ChromeTextLiteralGuard` 都还没有。⚠️ **出现第一个正当例外时，
//    应新增台账（形态照 `bool-exemptions.json`：键 + 署名 reason + 双向差集），
//    不得放宽判据、更不得删掉本守卫**——「用削弱判据来消化一个正当例外」正是 G-7
//    记在案的失效形态。follow-up 见 `246.md` 的《后续》。
@Suite("新 target 禁色相字面量")
struct EffectsColorLiteralGuard {

    /// SwiftUI / UIKit / AppKit 的具名色相。
    ///
    /// ⚠️ **`.clear` 不在表里**：它不是色相，是「不画」。
    /// ⚠️ **`.primary` / `.secondary` / `.accentColor` 也不在表里**：它们本身就是语义色。
    /// ⚠️ **`system*` 族（`UIColor.systemPink` / `NSColor.systemRed` / `Color(.systemBlue)`）
    /// 同样不在表里，这是一条裁定而不是遗漏**（PR #265 终审 I-1）：
    /// 本守卫要防的失效形态是「**写死的颜色在暗色模式 / 高对比度下不会跟着变**」，
    /// 而 `system*` 是 Apple 的 **dynamic color**——它按外观模式与对比度设置自动取值，
    /// 恰恰**具备**本守卫要保护的那个性质，与 `.primary` / `.secondary` 同类。
    /// 且 `CLAUDE.md`《分层色彩系统》把系统语义色列为第 3 层 token 的**推荐来源**
    /// （`0.3.0` 换地基的方向本身），禁掉它会与仓库自己的地基方向相反。
    /// ⚠️ **代价照录**：`systemPink` 毕竟仍是「粉」，拿它当装饰色堆在新 target 里
    /// 本守卫看不见——这是上面口子 2 的确切含义，不是「它一定没问题」。
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
            // ⚠️ 以下四条是 PR #265 双评审补的**绕过形态**（Copilot A-3 / 终审 I-2、S-2）。
            ("`.init` 形态 `Color.init(red:green:blue:)`", """
            import SwiftUI
            let c = Color.init(red: 1, green: 0, blue: 0)
            """),
            ("限定 `.init` 形态 `SwiftUI.Color.init(white:)`", """
            import SwiftUI
            let c = SwiftUI.Color.init(white: 0.5)
            """),
            ("隐式成员 `.init` 形态 `let c: Color = .init(red:…)`", """
            import SwiftUI
            let c: Color = .init(red: 1, green: 0, blue: 0)
            """),
            ("`#colorLiteral(…)`（Xcode 取色器插入的形态）", """
            import SwiftUI
            let c = Color(#colorLiteral(red: 1, green: 0, blue: 0, alpha: 1))
            """),
            ("限定色相 `SwiftUI.Color.white`", """
            import SwiftUI
            let c = SwiftUI.Color.white
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
            // ⚠️ **裁定的落点**（终审 I-1）：`system*` 是 dynamic color、按外观自动取值，
            // 与 `.primary` / `.secondary` 同类，**有意不算色相**。这两条钉住裁定，
            // 免得后人把它当漏报「顺手补上」而与文件头的口子 2 打架。
            ("`system*` 是语义色，不是色相（裁定，见 `hueNames` 文档）", """
            import UIKit
            let a = UIColor.systemPink
            let b = NSColor.systemRed
            """),
            ("`Color(.systemBlue)` 是系统色桥接惯用法", """
            import SwiftUI
            let c = Color(.systemBlue)
            """),
            ("非颜色类型的 `.init` 数值构造", """
            struct Pixel { init(red: Int) {} }
            let p = Pixel.init(red: 1)
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

    /// ⚠️ **`#colorLiteral(red:green:blue:alpha:)` 必须在这里拦**（PR #265 终审 I-2）：
    /// 它解析成 `MacroExpansionExprSyntax`，子节点是一串**裸浮点字面量**的
    /// `LabeledExprListSyntax`——既没有 member access、也没有 function call，
    /// 下面两个 override 一个都碰不到它。而它正是 **Xcode 取色器自动插入的形态**，
    /// 是硬编码颜色最可能的入口：首版对非 `Preview` 宏一律 `.visitChildren`，
    /// 于是这条路径整个逃逸，且没有登记在「已知口子」里。
    override func visit(_ node: MacroExpansionExprSyntax) -> SyntaxVisitorContinueKind {
        if node.macroName.text == "Preview" { return .skipChildren }
        if node.macroName.text == "colorLiteral" {
            self.record(node, snippet: node.trimmedDescription)
            return .skipChildren
        }
        return .visitChildren
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

    /// ⚠️ **`.init` 形态必须单独剥一层**（PR #265 Copilot A-3 / 终审 S-2）：
    /// 首版取点号链的**最后一段**判宿主类型，于是 `Color.init(red:green:blue:)` /
    /// `SwiftUI.Color.init(white:)` / `let c: Color = .init(red:…)` 的最后一段都是
    /// `"init"`、不在 `colorTypeNames` 里 ⇒ 「禁数值色字面量」有一条一行就能写出来的绕过。
    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        // ⚠️ `omittingEmptySubsequences: false`：隐式成员 `.init(red:…)` 的 callee 文本是
        // `.init`，丢掉空段后只剩 `["init"]`，与 `Foo.init` 不可分辨。
        var callee = node.calledExpression.trimmedDescription
            .split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        let isInitForm = callee.last == "init"
        if isInitForm { callee.removeLast() }
        let host = callee.last ?? ""
        // 隐式成员 `.init(red:…)` 的宿主类型来自上下文标注（`let c: Color = …`），
        // 语法树里没有 ⇒ 放行给下面的**数值标签**判据裁。标签集合是 `red`/`white`/`hue`，
        // 误报面接近零，而漏掉它等于留一条一行绕过。
        guard EffectsColorLiteralGuard.colorTypeNames.contains(host) || (isInitForm && host.isEmpty)
        else { return .visitChildren }
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
