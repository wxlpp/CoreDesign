import Foundation
import Testing

// MARK: - a11y 字面量守卫（Issue #222）

@Suite("a11y 字面量必须走 String Catalog")
struct AccessibilityStringLiteralGuard {
    private static let modifiers = ["accessibilityLabel", "accessibilityValue", "accessibilityHint"]

    private static func repoRoot() -> URL { GuardScanRoots.repoRoot }

    private struct Exemption: Decodable {
        let location: String
        let symbol: String
        let reason: String
    }

    private static func exemptedSites() throws -> Set<String> {
        struct Ledger: Decodable { let exemptions: [Exemption] }
        let url = Self.repoRoot().appendingPathComponent("docs/a11y-exemptions.json")
        let ledger = try JSONDecoder().decode(Ledger.self, from: Data(contentsOf: url))
        return Set(ledger.exemptions.map(\.location))
    }

    static func stringLiterals(in source: String) -> [String] {
        var out: [String] = []
        let chars = Array(source)
        var i = 0
        var current = ""
        var inString = false
        var parenDepth = 0
        var interpolating = false

        while i < chars.count {
            let c = chars[i]

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
        if !current.isEmpty, !inString { out.append(current) }
        return out
    }

    static func accessibilityCallSpans(in text: String) -> [(line: Int, body: String)] {
        var spans: [(Int, String)] = []
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var inDebug = false
        var i = 0
        while i < lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#if DEBUG") { inDebug = true; i += 1; continue }
            if trimmed.hasPrefix("#else") { inDebug = false; i += 1; continue }
            if trimmed.hasPrefix("#endif") { inDebug = false; i += 1; continue }
            if inDebug || trimmed.hasPrefix("//") { i += 1; continue }
            guard Self.modifiers.contains(where: { lines[i].contains($0 + "(") }) else { i += 1; continue }

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

    static func target(ofRelativePath rel: String) -> String {
        let parts = rel.split(separator: "/").map(String.init)
        guard parts.count >= 2, parts[0] == "Sources" else { return GuardScanRoots.primaryTargetName }
        return parts[1]
    }

    // MARK: - 调用段的裁定 / Verdict for one call span

    enum SpanVerdict: Equatable {
        case clean
        case bareLiteral([String])
        case moduleWithoutBundle
    }

    static func classify(span body: String, ownsBundle: Bool) -> SpanVerdict {
        if body.contains("bundle: .module") {
            return ownsBundle ? .clean : .moduleWithoutBundle
        }
        let literals = Self.stringLiterals(in: body)
        return literals.isEmpty ? .clean : .bareLiteral(literals)
    }

    @Test("全部已存在 target 下非 DEBUG 路径的 a11y 字面量全部走各自 target 的 bundle: .module")
    func noBareAccessibilityLiterals() throws {
        #expect(GuardScanRoots.assertRootsExist(GuardScanRoots.allRoots))
        let exempt = try Self.exemptedSites()

        var offenders: [String] = []
        var scannedFiles = 0
        for root in GuardScanRoots.allRoots {
            let ownsBundle = GuardScanRoots.ownsResourceBundle(root.target)
            let files = GuardScanRoots.swiftFiles(in: root.url)
            #expect(!files.isEmpty, "\(root.target) 下没有任何 .swift 文件 —— 本守卫在它上面恒绿")
            scannedFiles += files.count

            for url in files {
                let rel = GuardScanRoots.relativePath(url)
                let text = try String(contentsOf: url, encoding: .utf8)

                for span in Self.accessibilityCallSpans(in: text) {
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
        let span = #"    .accessibilityLabel(String(localized: "Play", bundle: .module))"#
        #expect(Self.classify(span: span, ownsBundle: true) == .clean,
                "CoreDesign（有资源包）里的规范写法被误判为违规")
        #expect(Self.classify(span: span, ownsBundle: false) == .moduleWithoutBundle,
                "没有资源包的 target 里写 `bundle: .module` 被静默放行 —— 这正是多根化引入的假绿")

        let bare = #"    .accessibilityLabel("Play")"#
        #expect(Self.classify(span: bare, ownsBundle: true) == .bareLiteral(["Play"]))
        #expect(Self.classify(span: bare, ownsBundle: false) == .bareLiteral(["Play"]))

        #expect(Self.classify(span: "    .accessibilityLabel(self.title)", ownsBundle: false) == .clean)

        #expect(GuardScanRoots.ownsResourceBundle("CoreDesign"))
        for target in GuardScanRoots.newTargetNames where GuardScanRoots.ownsResourceBundle(target) {
            print("【a11y】\(target) 现在拥有自己的资源包 —— `bundle: .module` 在它里面开始有意义了。")
        }
    }

    @Test("扫描器能看见跨行调用——评审实测的失明形态")
    func scannerSeesCrossLineCalls() {
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
        let line = #"    .accessibilityLabel(Text("Clear \(x.isEmpty ? "search" : x)"))"#
        let found = Self.stringLiterals(in: line)
        #expect(found.contains("Clear "), "外层字面量未被提取：\(found)")
        #expect(found.contains("search"), "**插值内层**字面量未被提取：\(found)")
        #expect(
            found.allSatisfy { $0 == "Clear " || $0 == "search" },
            "提取出伪片段——插值收尾处的状态机有误：\(found)"
        )
        let nested = #"    .accessibilityLabel(Text("A \(f(g("B"))) C"))"#
        let n = Self.stringLiterals(in: nested)
        #expect(
            n.allSatisfy { $0 == "A " || $0 == "B" || $0 == " C" },
            "嵌套括号插值产出伪片段：\(n)"
        )
    }
}
