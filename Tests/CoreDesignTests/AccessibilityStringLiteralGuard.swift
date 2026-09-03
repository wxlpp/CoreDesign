import Foundation
import Testing

// MARK: - a11y 字面量守卫（Issue #222）
//
// 库内组件读给 VoiceOver 的每一句都必须走 String Catalog（`bundle: .module`），
// 否则下游 App 换语言时组件会突然说英文。
//
// **本守卫必须能看见插值内层的字面量**——`Text("Clear \(x.isEmpty ? "search" : x)")`
// 这种形态里，外层字面量显眼、**内层的 "search" 藏在插值里**，按 token 粗扫会漏。
// #222 修的四个字面量里就有一个是这种形态，故变异自证的靶点专打它。
//
// 扫描范围：`GuardScanRoots.allRoots` 下的全部 `**/*.swift`（`#246` 起**多根**：
// `CoreDesign` / `CoreDesignEffects` / `CoreDesignCharts`），跳过 `#if DEBUG` 区块
// （预览宿主不是产品路径）。豁免台账：`docs/a11y-exemptions.json`。
//
// ⚠️ **多根化后必须按 target 分辨各自的 `.module`**（`#246` AC）：
// `bundle: .module` 是**每个 target 各自的** bundle，不是「CoreDesign 的 String Catalog」
// 的同义词。`CoreDesignEffects` / `CoreDesignCharts` 在 `Package.swift` 里**没有
// `resources:` 声明** ⇒ SwiftPM 不给它们合成 `Bundle.module` ⇒ 在这两个 target 里
// 写 `bundle: .module` 既编译不过、也到不了任何 catalog。而旧的放行条只看 span 文本里
// 有没有 `bundle: .module` 这串字符 ⇒ 一旦多根化，它会把这种写法**当成已本地化放行**。
// ⇒ 放行条改为「该 target 真的拥有自己的资源包」才成立，由
// `GuardScanRoots.ownsResourceBundle(_:)` 提供事实。

@Suite("a11y 字面量必须走 String Catalog")
struct AccessibilityStringLiteralGuard {

    private static let modifiers = ["accessibilityLabel", "accessibilityValue", "accessibilityHint"]

    private static func repoRoot() -> URL { GuardScanRoots.repoRoot }

    private struct Exemption: Decodable {
        let location: String   // "相对路径:行号" —— ⚠️ 精确到行，不是整文件
        let symbol: String
        let reason: String
    }

    /// 豁免站点集合，元素形如 `Sources/.../TagInput.swift:105`。
    ///
    /// ⚠️ **按文件+行而非整文件**：首版按文件路径整文件跳过，射程比台账声称的
    /// （`symbol: TagInput.body` 这个单一调用点）宽得多——该文件将来新增的任何
    /// 裸 a11y 字面量都会不可见。这是「登记了 ≠ 守住了」的形态。
    private static func exemptedSites() throws -> Set<String> {
        struct Ledger: Decodable { let exemptions: [Exemption] }
        let url = Self.repoRoot().appendingPathComponent("docs/a11y-exemptions.json")
        let ledger = try JSONDecoder().decode(Ledger.self, from: Data(contentsOf: url))
        return Set(ledger.exemptions.map(\.location))
    }

    /// 提取一段源码里所有字符串字面量的内容——**包括插值内层的**。
    ///
    /// 做法：逐字符状态机。遇 `"` 进入字面量；字面量内遇 `\(` 递归进入插值，
    /// 插值里再遇 `"` 就是内层字面量；插值收尾 `)` 回到**外层字面量内部**。
    /// 于是 `"Clear \(x ? "search" : y)"` 产出 `["Clear ", "search"]`。
    ///
    /// ⚠️ 处理三引号字符串：`"""` 开头的多行字面量整体收集为一段。
    static func stringLiterals(in source: String) -> [String] {
        var out: [String] = []
        let chars = Array(source)
        var i = 0
        var current = ""
        var inString = false
        var parenDepth = 0      // 插值内的括号深度，用于精确定位插值收尾
        var interpolating = false

        while i < chars.count {
            let c = chars[i]

            // 三引号：整段收集，内部不解析插值（保守——宁可多收不漏收）
            if !inString, !interpolating, c == "\"", i + 2 < chars.count,
               chars[i + 1] == "\"", chars[i + 2] == "\"" {
                var j = i + 3
                var body = ""
                while j + 2 < chars.count,
                      !(chars[j] == "\"" && chars[j + 1] == "\"" && chars[j + 2] == "\"") {
                    body.append(chars[j]); j += 1
                }
                if !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { out.append(body) }
                i = min(j + 3, chars.count)
                continue
            }

            if c == "\\", i + 1 < chars.count {
                if inString, chars[i + 1] == "(" {
                    if !current.isEmpty { out.append(current); current = "" }
                    inString = false
                    interpolating = true
                    parenDepth = 1
                    i += 2
                    continue
                }
                if inString { current.append(c); current.append(chars[i + 1]) }
                i += 2
                continue
            }

            if interpolating, !inString {
                if c == "(" { parenDepth += 1; i += 1; continue }
                if c == ")" {
                    parenDepth -= 1
                    if parenDepth == 0 {
                        // 插值结束 → 回到**外层字面量内部**。漏掉这步会把插值之后的
                        // 普通代码当字面量收集，产出 `"))"` 这类伪片段（实测踩过）。
                        interpolating = false
                        inString = true
                    }
                    i += 1
                    continue
                }
            }

            if c == "\"" {
                if inString {
                    if !current.isEmpty { out.append(current) }
                    current = ""
                    inString = false
                } else {
                    inString = true
                }
                i += 1
                continue
            }

            if inString { current.append(c) }
            i += 1
        }
        // 收尾仍在字面量态说明引号不配对，`current` 不可信 —— 丢弃而非上报。
        if !current.isEmpty, !inString { out.append(current) }
        return out
    }

    /// 把源码切成**逻辑调用段**：从含 a11y modifier 的行起，按括号配平累积到闭合为止。
    ///
    /// ⚠️ **这是本守卫最关键的一环**。首版按**物理行**扫描，对折行调用结构性失明——
    /// `.accessibilityLabel(cond\n  ? String(localized: "X", bundle: .module)\n  : y)`
    /// 里，第一行有 modifier 名但无字面量、第二行有字面量但无 modifier 名，**两边都不命中**。
    /// `SearchField.swift` 本轮的修复恰好就是这个形态 —— 有人把它 revert 成裸字面量，
    /// 首版守卫会**恒绿**。同 MEMORY 的「跨行折断击穿单行 grep」。
    static func accessibilityCallSpans(in text: String) -> [(line: Int, body: String)] {
        var spans: [(Int, String)] = []
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var inDebug = false
        var i = 0
        while i < lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            // ⚠️ `#else` 也要处理：`#if DEBUG … #else … #endif` 的 else 分支是**产品路径**，
            // 首版把它一起跳过了（漏报方向）。
            if trimmed.hasPrefix("#if DEBUG") { inDebug = true; i += 1; continue }
            if trimmed.hasPrefix("#else") { inDebug = false; i += 1; continue }
            if trimmed.hasPrefix("#endif") { inDebug = false; i += 1; continue }
            if inDebug || trimmed.hasPrefix("//") { i += 1; continue }
            guard Self.modifiers.contains(where: { lines[i].contains($0 + "(") }) else { i += 1; continue }

            // 从本行起按括号配平累积。注释行跳过，行尾 `//` 之后截断。
            var body = ""
            var depth = 0
            var started = false
            var j = i
            while j < lines.count {
                let raw = lines[j]
                let code = Self.strippingTrailingComment(raw)
                body += code + "\n"
                for ch in code {
                    if ch == "(" { depth += 1; started = true }
                    if ch == ")" { depth -= 1 }
                }
                j += 1
                if started, depth <= 0 { break }
            }
            spans.append((i + 1, body))
            i = max(j, i + 1)
        }
        return spans
    }

    /// 去掉行尾 `//` 注释——但不能砍掉字符串里的 `//`（如 URL）。
    static func strippingTrailingComment(_ line: String) -> String {
        var inString = false
        let chars = Array(line)
        var i = 0
        while i < chars.count {
            if chars[i] == "\\", i + 1 < chars.count { i += 2; continue }
            if chars[i] == "\"" { inString.toggle(); i += 1; continue }
            if !inString, chars[i] == "/", i + 1 < chars.count, chars[i + 1] == "/" {
                return String(chars[0..<i])
            }
            i += 1
        }
        return line
    }

    /// 从仓库根相对路径（`Sources/CoreDesignEffects/Foo.swift`）里取回 target 名。
    /// 取不出来时回落主 target——豁免台账的路径形态由 `exemptionsAreNotDead` 的
    /// 格式检查兜底，这里不重复报错。
    static func target(ofRelativePath rel: String) -> String {
        let parts = rel.split(separator: "/").map(String.init)
        guard parts.count >= 2, parts[0] == "Sources" else { return GuardScanRoots.primaryTargetName }
        return parts[1]
    }

    // MARK: - 调用段的裁定 / Verdict for one call span

    /// 一个 a11y 调用段的裁定结果。
    ///
    /// ⚠️ **抽成一个函数、两处共用**（`#246`）：`noBareAccessibilityLiterals` 与
    /// `exemptionsAreNotDead` 此前各写一遍「有没有 `bundle: .module` + 有没有字面量」，
    /// 多根化又要在其中一处加「该 target 有没有资源包」这条 ⇒ 两处必漂，
    /// 而漂移的方向恰好是「死豁免自检看不见新形态的违规」。
    enum SpanVerdict: Equatable {
        case clean
        /// 裸字面量（含插值内层、含折行形态）。
        case bareLiteral([String])
        /// 写了 `bundle: .module`，但该 target 根本没有自己的资源包。
        case moduleWithoutBundle
    }

    /// - Parameter ownsBundle: 该 target 是否拥有自己的 `Bundle.module`
    ///   （见 `GuardScanRoots.ownsResourceBundle(_:)`）。
    static func classify(span body: String, ownsBundle: Bool) -> SpanVerdict {
        if body.contains("bundle: .module") {
            return ownsBundle ? .clean : .moduleWithoutBundle
        }
        let literals = Self.stringLiterals(in: body)
        return literals.isEmpty ? .clean : .bareLiteral(literals)
    }

    @Test("全部已存在 target 下非 DEBUG 路径的 a11y 字面量全部走各自 target 的 bundle: .module")
    func noBareAccessibilityLiterals() throws {
        // ⚠️ **fail-closed 先行**：根不存在时 `enumerator` 静默产出空序列，
        // 「零文件 ⇒ 零违规 ⇒ 绿」。`#246` 之前这里还是个 `!` 强制解包的单根。
        #expect(GuardScanRoots.assertRootsExist(GuardScanRoots.allRoots))
        let exempt = try Self.exemptedSites()

        var offenders: [String] = []
        var scannedFiles = 0
        for root in GuardScanRoots.allRoots {
            // 该 target 是否拥有自己的 `Bundle.module` —— 决定 `bundle: .module` 算不算放行。
            let ownsBundle = GuardScanRoots.ownsResourceBundle(root.target)
            let files = GuardScanRoots.swiftFiles(in: root.url)
            #expect(!files.isEmpty, "\(root.target) 下没有任何 .swift 文件 —— 本守卫在它上面恒绿")
            scannedFiles += files.count

            for url in files {
                let rel = GuardScanRoots.relativePath(url)
                let text = try String(contentsOf: url, encoding: .utf8)

                for span in Self.accessibilityCallSpans(in: text) {
                    // ⚠️ 豁免按 **文件 + 行**，不是整文件——整文件豁免会让该文件将来
                    // 新增的任何裸 a11y 字面量全部不可见（登记了 ≠ 守住了）。
                    if exempt.contains("\(rel):\(span.line)") { continue }
                    let oneLine = span.body
                        .split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
                        .joined(separator: " ")
                    switch Self.classify(span: span.body, ownsBundle: ownsBundle) {
                    case .clean:
                        continue
                    case .bareLiteral(let literals):
                        offenders.append("\(rel):\(span.line) → \(literals) | \(oneLine)")
                    case .moduleWithoutBundle:
                        // ⚠️ **按 target 分辨 `.module`**：该 target 没有自己的资源包时，
                        // 这串字符不是「已本地化」的证据，判红并明说原因。
                        offenders.append(
                            "\(rel):\(span.line) → 写了 `bundle: .module`，但 target `\(root.target)` "
                            + "**没有自己的资源包**（`Sources/\(root.target)/Resources/` 不存在，"
                            + "`Package.swift` 也没给它 `resources:`）⇒ 这里的 `.module` 到不了任何 "
                            + "String Catalog | \(oneLine)"
                        )
                    }
                }
            }
        }
        #expect(scannedFiles > 50, "只扫到 \(scannedFiles) 个源文件 —— 扫描失效，「零违规」不可信")

        #expect(
            offenders.isEmpty,
            """
            以下 a11y 调用含未走 String Catalog 的字符串字面量（含插值内层、含折行形态）：
            \(offenders.joined(separator: "\n"))
            处置：改走 `String(localized:bundle: .module)`；若该串由调用方传入、
            本库不该翻译，加进 docs/a11y-exemptions.json 并写明理由（按文件+行）。
            ⚠️ 若违规落在**新 target** 里：`bundle: .module` 在没有资源包的 target 里不成立，
            正确做法是把文案交给调用方，或先给该 target 声明它自己的 String Catalog
            （`Package.swift` 的 `resources:` + `Sources/<target>/Resources/`）。
            """
        )
    }

    @Test("每条豁免都必须对应一处真实命中——不许有死豁免")
    func exemptionsAreNotDead() throws {
        // ⚠️ **本条来自本地 Copilot CLI 评审**。#222 初版登记 `TagInput.swift:105`
        // 作「锚定首例」，而那一行是 `.accessibilityLabel(Text(self.placeholder))`
        // ——**不含任何字符串字面量**，守卫本就不会标记它。于是那条豁免：
        //
        //   1. 当前**什么都没守住**（登记了一个空靶）；
        //   2. 更糟：若将来有人把该行改成裸字面量（`Text("Add tag")` 这个键历史上
        //      真实存在过），豁免会**继续生效、静默放行**这个真实回归。
        //
        // 这正是 #222 自己反复强调要防的「登记了 ≠ 守住了」——我给它配的锚定首例
        // 本身就是这个病。故加本条自检：**把豁免摘掉后必须真的判红**，否则它是死的。
        let root = Self.repoRoot()
        let exempt = try Self.exemptedSites()

        var deadSites: [String] = []
        for site in exempt {
            let parts = site.split(separator: ":")
            guard parts.count == 2, let lineNo = Int(parts[1]) else {
                deadSites.append("\(site)（格式非法，应为「相对路径:行号」）"); continue
            }
            let url = root.appendingPathComponent(String(parts[0]))
            guard let text = try? String(contentsOf: url, encoding: .utf8) else {
                deadSites.append("\(site)（文件不存在）"); continue
            }
            // 无视豁免地扫一遍：该站点必须**确实**被判为违规，否则这条豁免是空靶。
            // ⚠️ `ownsBundle` 按该站点**所属 target** 取（`#246`）：写死 `true` 会让
            // 「新 target 里写 `bundle: .module`」这类新形态的豁免被当成死豁免误删。
            let ownsBundle = GuardScanRoots.ownsResourceBundle(Self.target(ofRelativePath: String(parts[0])))
            let hit = Self.accessibilityCallSpans(in: text).contains { span in
                span.line == lineNo
                    && Self.classify(span: span.body, ownsBundle: ownsBundle) != .clean
            }
            if !hit { deadSites.append(site) }
        }

        #expect(
            deadSites.isEmpty,
            """
            以下豁免条目**不对应任何真实违规**（死豁免）：
            \(deadSites.joined(separator: "\n"))
            死豁免有两重害处：现在什么都没守住；将来该行真的回归成裸字面量时会被静默放行。
            处置：删掉该条；确有需要豁免时，等它真的被守卫标记出来再登记。
            """
        )
    }

    @Test("按 target 分辨 `.module`：没有资源包的 target 里 `bundle: .module` 不算放行（合成输入变红自证）")
    func moduleIsResolvedPerTarget() {
        // ⚠️ **这条是 `#246` 多根化最容易假绿的一处的变红自证**：多根化之前，
        // 判据只看 span 文本里有没有 `bundle: .module`。多根化之后，同一串字符在
        // 一个**没有资源包**的 target 里既编译不过、也到不了任何 catalog——
        // 但文本判据看不出区别，会把它当成「已本地化」放行。
        let span = #"    .accessibilityLabel(String(localized: "Play", bundle: .module))"#
        #expect(Self.classify(span: span, ownsBundle: true) == .clean,
                "CoreDesign（有资源包）里的规范写法被误判为违规")
        #expect(Self.classify(span: span, ownsBundle: false) == .moduleWithoutBundle,
                "没有资源包的 target 里写 `bundle: .module` 被静默放行 —— 这正是多根化引入的假绿")

        // 裸字面量两种 target 下都违规。
        let bare = #"    .accessibilityLabel("Play")"#
        #expect(Self.classify(span: bare, ownsBundle: true) == .bareLiteral(["Play"]))
        #expect(Self.classify(span: bare, ownsBundle: false) == .bareLiteral(["Play"]))

        // 无字面量的调用两种情形都干净。
        #expect(Self.classify(span: "    .accessibilityLabel(self.title)", ownsBundle: false) == .clean)

        // 现状核对：主 target 拥有资源包（本守卫的 `.clean` 放行条依赖它）。
        //
        // ⚠️ **不再断言「新 target 没有资源包」**（PR #265 终审 I-4）：那条 `#expect(!…)`
        // 与 `ChromeTextLiteralGuard` 开出的处方（「给该 target 声明它自己的 String Catalog」）
        // 直接矛盾——照守卫说的做，这里就红。`.module` 归属的权威判据只有一处：
        // `GuardScanRootsGuard.moduleBundleOwnership`（manifest 的 `resources:` 与
        // `Resources/` 目录同进同退）。本守卫只消费 `ownsResourceBundle` 的返回值，
        // **两种取值下的分类行为都已在上面钉死**，故新 target 何时拿到资源包与本条无关。
        #expect(GuardScanRoots.ownsResourceBundle("CoreDesign"))
        for target in GuardScanRoots.newTargetNames where GuardScanRoots.ownsResourceBundle(target) {
            print("【a11y】\(target) 现在拥有自己的资源包 —— `bundle: .module` 在它里面开始有意义了。")
        }
    }

    @Test("扫描器能看见跨行调用——评审实测的失明形态")
    func scannerSeesCrossLineCalls() {
        // ⚠️ 首版按物理行扫描，下列形态**全部漏报**（评审实测）。逐个钉死。
        // Case I 最要害：它正是 SearchField 本轮修复的形态——若守卫对它失明，
        // 有人把修复 revert 成裸字面量时守卫会恒绿。
        let cases: [(name: String, src: String, expectLiteral: String)] = [
            ("折行三元（SearchField 修复处的形态）", """
                    .accessibilityLabel(cond
                        ? "Search"
                        : other)
            """, "Search"),
            ("modifier 与实参分行", """
                    .accessibilityLabel(
                        Text("Hardcoded")
                    )
            """, "Hardcoded"),
            ("三引号多行字面量", """
                    .accessibilityValue(\"\"\"
                    multi line
                    \"\"\")
            """, "multi line"),
        ]
        for c in cases {
            let spans = Self.accessibilityCallSpans(in: c.src)
            #expect(!spans.isEmpty, "\(c.name)：没识别出调用段")
            let found = spans.flatMap { Self.stringLiterals(in: $0.body) }
            #expect(
                found.contains(where: { $0.contains(c.expectLiteral) }),
                "\(c.name)：漏报——期望含 \(c.expectLiteral)，实得 \(found)"
            )
        }
    }

    @Test("#if DEBUG 的 #else 分支是产品路径，不得被跳过")
    func scannerDoesNotSkipDebugElseBranch() {
        // 首版把 `#else` 一并当 DEBUG 跳过 —— 漏报方向。
        let src = """
        #if DEBUG
                .accessibilityLabel("only in debug")
        #else
                .accessibilityLabel("SHIPPED")
        #endif
        """
        let found = Self.accessibilityCallSpans(in: src).flatMap { Self.stringLiterals(in: $0.body) }
        #expect(found.contains("SHIPPED"), "#else 分支被当成 DEBUG 跳过了：\(found)")
        #expect(!found.contains("only in debug"), "DEBUG 分支不该被扫：\(found)")
    }

    @Test("行尾注释不产生误报")
    func trailingCommentDoesNotFalsePositive() {
        let src = #"        .accessibilityLabel(x)  // 这里写个 "引号" 不该被当字面量"#
        let found = Self.accessibilityCallSpans(in: src).flatMap { Self.stringLiterals(in: $0.body) }
        #expect(found.isEmpty, "行尾注释里的引号被误当字面量：\(found)")
    }

    @Test("扫描器能看见插值内层的字面量")
    func scannerSeesNestedLiterals() {
        // 守卫自身的能力自证：若这条红了，说明扫描器对本组最易漏的形态失明，
        // 上面那条测试的「零命中」就不可信。
        let line = #"    .accessibilityLabel(Text("Clear \(x.isEmpty ? "search" : x)"))"#
        let found = Self.stringLiterals(in: line)
        #expect(found.contains("Clear "), "外层字面量未被提取：\(found)")
        #expect(found.contains("search"), "**插值内层**字面量未被提取：\(found)")
        // 插值收尾若处理错，会把插值之后的代码当字面量收进来（实测出现过 `"))"`）。
        // 伪片段不影响判红，但会污染报错信息、并可能在别处造成误报。
        #expect(
            found.allSatisfy { $0 == "Clear " || $0 == "search" },
            "提取出伪片段——插值收尾处的状态机有误：\(found)"
        )
        // 插值内含嵌套调用括号时，收尾定位若只认第一个 `)` 会产伪片段（评审 Case F）。
        let nested = #"    .accessibilityLabel(Text("A \(f(g("B"))) C"))"#
        let n = Self.stringLiterals(in: nested)
        #expect(
            n.allSatisfy { $0 == "A " || $0 == "B" || $0 == " C" },
            "嵌套括号插值产出伪片段：\(n)"
        )
    }
}
