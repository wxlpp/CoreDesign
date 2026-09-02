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
// 扫描范围：`Sources/CoreDesign/**/*.swift`，跳过 `#if DEBUG` 区块（预览宿主不是产品路径）。
// 豁免台账：`docs/a11y-exemptions.json`。

@Suite("a11y 字面量必须走 String Catalog")
struct AccessibilityStringLiteralGuard {

    private static let modifiers = ["accessibilityLabel", "accessibilityValue", "accessibilityHint"]

    private static func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

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

    @Test("Sources/ 下非 DEBUG 路径的 a11y 字面量全部走 bundle: .module")
    func noBareAccessibilityLiterals() throws {
        let root = Self.repoRoot()
        let sources = root.appendingPathComponent("Sources/CoreDesign")
        let exempt = try Self.exemptedSites()

        var offenders: [String] = []
        let e = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil)!
        for case let url as URL in e where url.pathExtension == "swift" {
            let rel = url.path.replacingOccurrences(of: root.path + "/", with: "")
            let text = try String(contentsOf: url, encoding: .utf8)

            for span in Self.accessibilityCallSpans(in: text) {
                // ⚠️ 豁免按 **文件 + 行**，不是整文件——整文件豁免会让该文件将来
                // 新增的任何裸 a11y 字面量全部不可见（登记了 ≠ 守住了）。
                if exempt.contains("\(rel):\(span.line)") { continue }
                if span.body.contains("bundle: .module") { continue }
                let literals = Self.stringLiterals(in: span.body)
                if !literals.isEmpty {
                    let oneLine = span.body
                        .split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
                        .joined(separator: " ")
                    offenders.append("\(rel):\(span.line) → \(literals) | \(oneLine)")
                }
            }
        }

        #expect(
            offenders.isEmpty,
            """
            以下 a11y 调用含未走 String Catalog 的字符串字面量（含插值内层、含折行形态）：
            \(offenders.joined(separator: "\n"))
            处置：改走 `String(localized:bundle: .module)`；若该串由调用方传入、
            本库不该翻译，加进 docs/a11y-exemptions.json 并写明理由（按文件+行）。
            """
        )
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
