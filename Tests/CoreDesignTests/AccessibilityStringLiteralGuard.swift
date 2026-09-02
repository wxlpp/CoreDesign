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
        let location: String
        let symbol: String
        let reason: String
    }

    private static func exemptedFiles() throws -> Set<String> {
        struct Ledger: Decodable { let exemptions: [Exemption] }
        let url = Self.repoRoot().appendingPathComponent("docs/a11y-exemptions.json")
        let ledger = try JSONDecoder().decode(Ledger.self, from: Data(contentsOf: url))
        return Set(ledger.exemptions.map(\.location))
    }

    /// 提取一行里所有字符串字面量的内容——**包括插值内层的**。
    ///
    /// 做法：逐字符扫描，遇到 `"` 进入字面量；字面量内遇到 `\(` 则**递归进入插值**，
    /// 插值里再遇到 `"` 就是内层字面量。这样 `"Clear \(x ? "search" : y)"`
    /// 会产出 `["Clear ", "search"]` 两个片段，而不是只看到最外层。
    static func stringLiterals(in line: String) -> [String] {
        var out: [String] = []
        var chars = Array(line)
        var i = 0
        var current = ""
        var inString = false
        var depth = 0  // 插值嵌套深度

        while i < chars.count {
            let c = chars[i]
            if c == "\\", i + 1 < chars.count {
                if inString, chars[i + 1] == "(" {
                    // 进入插值：当前片段收口，深度 +1，暂时离开字面量态
                    if !current.isEmpty { out.append(current); current = "" }
                    inString = false
                    depth += 1
                    i += 2
                    continue
                }
                // 转义字符，跳过下一个
                if inString { current.append(c); current.append(chars[i + 1]) }
                i += 2
                continue
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
            if !inString, c == ")", depth > 0 {
                depth -= 1
                // 插值结束 → 回到**外层字面量**内部（而不是回到「字面量外」）。
                // 漏掉这一步会把插值之后的普通代码当成字面量收集，
                // 产出 `"))"` 这类伪片段（实测踩过）。
                inString = true
                i += 1
                continue
            }
            if inString { current.append(c) }
            i += 1
        }
        // 行尾仍在字面量态说明括号/引号不配对（跨行表达式），此时 `current`
        // 不可信，丢弃而非上报——宁可漏报也不制造伪 offender。
        if !current.isEmpty, !inString { out.append(current) }
        return out
    }

    @Test("Sources/ 下非 DEBUG 路径的 a11y 字面量全部走 bundle: .module")
    func noBareAccessibilityLiterals() throws {
        let root = Self.repoRoot()
        let sources = root.appendingPathComponent("Sources/CoreDesign")
        let exempt = try Self.exemptedFiles()

        var offenders: [String] = []
        let e = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil)!
        for case let url as URL in e where url.pathExtension == "swift" {
            let rel = url.path.replacingOccurrences(of: root.path + "/", with: "")
            if exempt.contains(rel) { continue }
            let text = try String(contentsOf: url, encoding: .utf8)

            var inDebug = false
            for (idx, rawLine) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                let line = String(rawLine)
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("#if DEBUG") { inDebug = true; continue }
                if trimmed.hasPrefix("#endif") { inDebug = false; continue }
                if inDebug { continue }
                if trimmed.hasPrefix("//") || trimmed.hasPrefix("///") { continue }
                guard Self.modifiers.contains(where: { line.contains($0 + "(") }) else { continue }
                if line.contains("bundle: .module") { continue }

                let literals = Self.stringLiterals(in: line)
                if !literals.isEmpty {
                    offenders.append("\(rel):\(idx + 1) → \(literals) | \(trimmed)")
                }
            }
        }

        #expect(
            offenders.isEmpty,
            """
            以下 a11y 调用含未走 String Catalog 的字符串字面量（含插值内层）：
            \(offenders.joined(separator: "\n"))
            处置：改走 `String(localized:bundle: .module)`；若该串由调用方传入、
            本库不该翻译，加进 docs/a11y-exemptions.json 并写明理由。
            """
        )
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
    }
}
