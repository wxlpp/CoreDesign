import Foundation
import Testing

// MARK: - 多 target 扫描根的单一来源 / Single source of truth for the multi-target scan roots

nonisolated enum GuardScanRoots {
    static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    static let primaryTargetName = "CoreDesign"

    static let targetNames: [String] = ["CoreDesign", "CoreDesignEffects", "CoreDesignCharts"]

    static var newTargetNames: [String] { Self.targetNames.filter { $0 != Self.primaryTargetName } }

    static func sourcesURL(of target: String) -> URL {
        Self.repoRoot.appendingPathComponent("Sources/\(target)")
    }

    static var allRoots: [(target: String, url: URL)] {
        Self.targetNames.map { ($0, Self.sourcesURL(of: $0)) }
    }

    static var newTargetRoots: [(target: String, url: URL)] {
        Self.newTargetNames.map { ($0, Self.sourcesURL(of: $0)) }
    }

    // MARK: - fail-closed：根必须真的存在

    @discardableResult
    static func assertRootsExist(
        _ roots: [(target: String, url: URL)],
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> Bool {
        var ok = true
        if roots.isEmpty {
            Issue.record("扫描根列表为空 —— 后续扫描会在空输入上恒绿，这不是「零违规」", sourceLocation: sourceLocation)
            ok = false
        }
        for root in roots where !FileManager.default.fileExists(atPath: root.url.path) {
            Issue.record(
                "扫描根不存在：\(root.url.path)（target \(root.target)）—— 判据无法工作，这不是「零违规」",
                sourceLocation: sourceLocation
            )
            ok = false
        }
        return ok
    }

    static func swiftFiles(
        in root: URL, sourceLocation: SourceLocation = #_sourceLocation
    ) -> [URL] {
        guard FileManager.default.fileExists(atPath: root.path) else {
            Issue.record("源码路径不存在：\(root.path) —— 判据无法工作，这不是「零违规」", sourceLocation: sourceLocation)
            return []
        }
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            Issue.record("无法枚举源码目录：\(root.path)（权限或 IO 异常）—— 判据无法工作", sourceLocation: sourceLocation)
            return []
        }
        var out: [URL] = []
        for case let url as URL in walker where url.pathExtension == "swift" { out.append(url) }
        return out
    }

    static func relativePath(
        _ url: URL, sourceLocation: SourceLocation = #_sourceLocation
    ) -> String {
        Self.relativePath(url, from: Self.repoRoot, sourceLocation: sourceLocation)
    }

    static func relativePath(
        _ url: URL,
        from root: URL,
        expectingContainment: Bool = true,
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> String {
        if let relative = Self.relative(
            Self.standardizedComponents(url), under: Self.standardizedComponents(root)
        ) {
            return relative
        }
        if let relative = Self.relative(
            Self.canonicalComponents(url), under: Self.canonicalComponents(root)
        ) {
            return relative
        }
        if expectingContainment {
            Issue.record(
                """
                路径推导落进兜底：\(url.path)
                不在扫描根 \(root.path) 之下 —— 真实调用点的 url 全部由枚举该根得到，
                结构上不该发生。出现它意味着又冒出了一类路径分叉（`#311` 那次是 `/private`），
                后果同样是台账键被污染（假红 + 诊断指向扫描面配置），但没有显眼特征可查。
                """,
                sourceLocation: sourceLocation
            )
        }
        return url.path
    }

    private static func relative(_ file: [String], under root: [String]) -> String? {
        guard file.count > root.count, Array(file.prefix(root.count)) == root else { return nil }
        return file.dropFirst(root.count).joined(separator: "/")
    }

    private static func standardizedComponents(_ url: URL) -> [String] {
        url.standardizedFileURL.pathComponents
    }

    private static func canonicalComponents(_ url: URL) -> [String] {
        var parts = url.standardizedFileURL.resolvingSymlinksInPath().pathComponents
        if parts.count >= 3, parts[0] == "/", parts[1] == "private" { parts.remove(at: 1) }
        return parts
    }

    // MARK: - 台账键的 target 前缀（`#246` AC「台账键加 target 前缀」）

    static func qualifiedKey(target: String, base: String) -> String {
        target == Self.primaryTargetName ? base : "\(target)/\(base)"
    }

    static func target(ofKey key: String) -> String {
        guard let slash = key.firstIndex(of: "/") else { return Self.primaryTargetName }
        return String(key[key.startIndex..<slash])
    }

    static func baseKey(_ key: String) -> String {
        guard let slash = key.firstIndex(of: "/") else { return key }
        return String(key[key.index(after: slash)...])
    }

    // MARK: - 每个 target 各自的 `.module`（`#246` AC「按 target 分辨各自的 .module」）

    static func ownsResourceBundle(_ target: String) -> Bool {
        Self.resourceOwningTargets().contains(target)
    }

    static func resourceOwningTargets(sourceLocation: SourceLocation = #_sourceLocation) -> Set<String> {
        guard let targets = try? Self.declaredTargets(sourceLocation: sourceLocation) else {
            Issue.record("读不到 / 解析不了 Package.swift —— `.module` 归属无法判定", sourceLocation: sourceLocation)
            return []
        }
        return Set(targets.filter(\.hasResources).map(\.name))
    }

    // MARK: - `Package.swift` 的 library target 清单

    static var packageManifestURL: URL { Self.repoRoot.appendingPathComponent("Package.swift") }

    nonisolated struct DeclaredTarget: Hashable, Sendable {
        let name: String
        let isLibrary: Bool
        let hasResources: Bool
    }

    static func declaredTargets(sourceLocation: SourceLocation = #_sourceLocation) throws -> [DeclaredTarget] {
        Self.declaredTargets(
            manifestText: try String(contentsOf: Self.packageManifestURL, encoding: .utf8),
            sourceLocation: sourceLocation
        )
    }

    static func declaredTargets(
        manifestText text: String, sourceLocation: SourceLocation = #_sourceLocation
    ) -> [DeclaredTarget] {
        let starters: [(prefix: String, isLibrary: Bool)] = [
            (".target(", true),
            (".testTarget(", false), (".executableTarget(", false), (".macro(", false),
            (".binaryTarget(", false), (".plugin(", false), (".systemLibrary(", false),
        ]
        var out: [DeclaredTarget] = []
        var open = false
        var depth = 0
        var openedAtLine = 0
        var currentName: String?
        var currentIsLibrary = false
        var currentHasResources = false
        var currentHasPath = false
        var awaitingName = false

        func flush() {
            guard open else { return }
            if let name = currentName {
                if currentIsLibrary && currentHasPath {
                    Issue.record("""
                    Package.swift:\(openedAtLine) 的 library target `\(name)` 写了 `path:` ——
                    `GuardScanRoots.sourcesURL(of:)` 按 target **名**推根（`Sources/<name>`），
                    重定向之后守卫会扫**错的树**，而 `assertRootsExist` 与
                    `libraryTargetsAreCoveredByScanRoots` 都照样满足 ⇒ 静默 fail-open。
                    处置：把源码放回 `Sources/\(name)/`，或同时扩 `DeclaredTarget` 的 schema
                    与 `sourcesURL(of:)` 让根列表读得到 `path:`。**不要**直接删本断言。
                    """, sourceLocation: sourceLocation)
                }
                out.append(.init(name: name, isLibrary: currentIsLibrary, hasResources: currentHasResources))
            } else {
                Issue.record("""
                Package.swift:\(openedAtLine) 的 target 块解析不出 name（name 可能不是字符串字面量）
                —— 静默丢弃它意味着该 target 既不进 `GuardScanRoots.targetNames` 的双向差集、
                也不进 `.module` 归属表，两者都是 fail-open 方向的漏。
                处置：把 name 写成字面量，或扩展本解析器。
                """, sourceLocation: sourceLocation)
            }
            open = false
            depth = 0
            currentName = nil
            currentIsLibrary = false
            currentHasResources = false
            currentHasPath = false
            awaitingName = false
        }

        var lex = ManifestLexState()

        for (index, raw) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            let code = Self.code(of: line, state: &lex)
            if !open, let starter = starters.first(where: { code.hasPrefix($0.prefix) }) {
                open = true
                openedAtLine = index + 1
                currentIsLibrary = starter.isLibrary
                if let name = Self.quotedName(in: code) { currentName = name } else { awaitingName = true }
            } else if !open {
                continue
            } else if awaitingName, let name = Self.quotedName(in: code, atDepth: 0) {
                currentName = name
                awaitingName = false
            }
            if code.contains("resources:") { currentHasResources = true }
            if code.contains("path:") { currentHasPath = true }
            depth += Self.parenDelta(of: code)
            if depth <= 0 { flush() }
        }
        flush()
        return out
    }

    nonisolated struct ManifestLexState: Hashable, Sendable {
        var blockCommentDepth = 0
        var inMultilineString = false
    }

    static func code(of line: String, state: inout ManifestLexState) -> String {
        var out = ""
        let chars = Array(line)
        var index = 0
        var inString = false
        while index < chars.count {
            let character = chars[index]
            if state.blockCommentDepth > 0 {
                if character == "/", index + 1 < chars.count, chars[index + 1] == "*" {
                    state.blockCommentDepth += 1
                    index += 2
                } else if character == "*", index + 1 < chars.count, chars[index + 1] == "/" {
                    state.blockCommentDepth -= 1
                    index += 2
                } else {
                    index += 1
                }
                continue
            }
            if state.inMultilineString {
                if character == "\"", index + 2 < chars.count,
                   chars[index + 1] == "\"", chars[index + 2] == "\"" {
                    state.inMultilineString = false
                    index += 3
                } else {
                    index += 1
                }
                continue
            }
            if inString {
                if character == "\\", index + 1 < chars.count {
                    out.append(character)
                    out.append(chars[index + 1])
                    index += 2
                    continue
                }
                out.append(character)
                if character == "\"" { inString = false }
                index += 1
                continue
            }
            if character == "\"" {
                if index + 2 < chars.count, chars[index + 1] == "\"", chars[index + 2] == "\"" {
                    state.inMultilineString = true
                    index += 3
                    continue
                }
                inString = true
                out.append(character)
                index += 1
                continue
            }
            if character == "/", index + 1 < chars.count, chars[index + 1] == "/" { break }
            if character == "/", index + 1 < chars.count, chars[index + 1] == "*" {
                state.blockCommentDepth += 1
                index += 2
                continue
            }
            out.append(character)
            index += 1
        }
        return out.trimmingCharacters(in: .whitespaces)
    }

    static func code(of line: String) -> String {
        var state = ManifestLexState()
        return Self.code(of: line, state: &state)
    }

    static func parenDelta(of code: String) -> Int {
        var inString = false
        var escaped = false
        var delta = 0
        for character in code {
            if escaped { escaped = false; continue }
            if character == "\\", inString { escaped = true; continue }
            if character == "\"" { inString.toggle(); continue }
            guard !inString else { continue }
            if character == "(" { delta += 1 }
            if character == ")" { delta -= 1 }
        }
        return delta
    }

    static func declaredLibraryTargets() throws -> [String] {
        try Self.declaredTargets().filter(\.isLibrary).map(\.name)
    }

    static func quotedName(in code: String, atDepth wantedDepth: Int = 1) -> String? {
        let chars = Array(code)
        var index = 0
        var depth = 0
        var inString = false
        while index < chars.count {
            let character = chars[index]
            if inString {
                if character == "\\", index + 1 < chars.count { index += 2; continue }
                if character == "\"" { inString = false }
                index += 1
                continue
            }
            if character == "\"" { inString = true; index += 1; continue }
            if character == "(" { depth += 1; index += 1; continue }
            if character == ")" { depth -= 1; index += 1; continue }
            guard depth == wantedDepth, let valueStart = Self.nameLabelEnd(chars, at: index) else {
                index += 1
                continue
            }
            if let name = Self.stringLiteralBody(chars, at: valueStart) { return name }
            index += 1
        }
        return nil
    }

    private static func nameLabelEnd(_ chars: [Character], at index: Int) -> Int? {
        let label = Array("name")
        guard index + label.count <= chars.count,
              Array(chars[index..<(index + label.count)]) == label
        else { return nil }
        if index > 0, Self.isIdentifierCharacter(chars[index - 1]) { return nil }
        var cursor = index + label.count
        if cursor < chars.count, Self.isIdentifierCharacter(chars[cursor]) { return nil }
        while cursor < chars.count, chars[cursor] == " " || chars[cursor] == "\t" { cursor += 1 }
        guard cursor < chars.count, chars[cursor] == ":" else { return nil }
        cursor += 1
        while cursor < chars.count, chars[cursor] == " " || chars[cursor] == "\t" { cursor += 1 }
        return cursor
    }

    private static func stringLiteralBody(_ chars: [Character], at index: Int) -> String? {
        guard index < chars.count, chars[index] == "\"" else { return nil }
        var body = ""
        var cursor = index + 1
        while cursor < chars.count {
            let character = chars[cursor]
            if character == "\\", cursor + 1 < chars.count {
                if chars[cursor + 1] == "(" { return nil }
                body.append(character)
                body.append(chars[cursor + 1])
                cursor += 2
                continue
            }
            if character == "\"" { return body }
            body.append(character)
            cursor += 1
        }
        return nil
    }

    private static func isIdentifierCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_"
    }

    // MARK: - 测试根与文档根（`#287`：判据引用守卫的扫描面也要有单一来源）

    static var testsRoot: URL { Self.repoRoot.appendingPathComponent("Tests") }

    static func testRootDirectories() throws -> [URL] {
        try FileManager.default
            .contentsOfDirectory(at: Self.testsRoot, includingPropertiesForKeys: [.isDirectoryKey])
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    static var docsRoot: URL { Self.repoRoot.appendingPathComponent("docs") }

    static func docFiles(
        extensions: Set<String> = ["md", "json"],
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> [URL] {
        guard FileManager.default.fileExists(atPath: Self.docsRoot.path) else {
            Issue.record("文档根不存在：\(Self.docsRoot.path) —— 判据无法工作，这不是「零违规」",
                         sourceLocation: sourceLocation)
            return []
        }
        guard let walker = FileManager.default.enumerator(
            at: Self.docsRoot, includingPropertiesForKeys: nil
        ) else {
            Issue.record("无法枚举文档目录：\(Self.docsRoot.path)（权限或 IO 异常）—— 判据无法工作",
                         sourceLocation: sourceLocation)
            return []
        }
        var out: [URL] = []
        for case let url as URL in walker where extensions.contains(url.pathExtension) { out.append(url) }
        return out.sorted { $0.path < $1.path }
    }
}

// MARK: - 扫描根自身的守卫

@Suite("多 target 扫描根")
struct GuardScanRootsGuard {
    @Test("根列表非空，且每个根目录真的存在（fail-closed）")
    func rootsExist() {
        #expect(!GuardScanRoots.targetNames.isEmpty, "根列表为空 —— 全部跨根守卫会在空输入上恒绿")
        #expect(!GuardScanRoots.newTargetNames.isEmpty, "新 target 列表为空 —— 三条新守卫会在空输入上恒绿")
        #expect(GuardScanRoots.assertRootsExist(GuardScanRoots.allRoots))
        for root in GuardScanRoots.allRoots {
            #expect(!GuardScanRoots.swiftFiles(in: root.url).isEmpty,
                    "\(root.target) 的根 \(root.url.path) 下一个 .swift 都没有 —— 扫描器会在空输入上恒绿")
        }
    }

    @Test("manifest 解析器：三种畸形写法不再把 `resources:` 归给错的 target（终审 S-d）")
    func manifestParserHandlesAwkwardShapes() {
        let inline = GuardScanRoots.declaredTargets(manifestText: """
        targets: [
            .target(name: "Alpha", resources: [.process("Resources")]),
            .target(name: "Beta"),
        ]
        """)
        #expect(inline.map(\.name) == ["Alpha", "Beta"])
        #expect(inline.first(where: { $0.name == "Alpha" })?.hasResources == true,
                "一行写完的 `resources:` 漏记 —— `.module` 归属表会说 Alpha 没有资源包")
        #expect(inline.first(where: { $0.name == "Beta" })?.hasResources == false)

        let nested = GuardScanRoots.declaredTargets(manifestText: """
        targets: [
            .target(
                name: "Effects",
                dependencies: [
                    .target(name: "CoreDesign"),
                ],
                resources: [.process("Resources")]
            ),
        ]
        """)
        #expect(nested.map(\.name) == ["Effects"],
                "嵌套的 `.target(name:)` 被当成了一个独立 target —— 幽灵条目会顶动根列表的双向差集")
        #expect(nested.first?.hasResources == true,
                "外层 target 的 `resources:` 被嵌套块偷走了")

        let trailing = GuardScanRoots.declaredTargets(manifestText: """
        targets: [
            .target(name: "Gamma"),
        ]
        // 下面这行不属于任何 target 块
        resources: [.process("Resources")]
        """)
        #expect(trailing.map(\.name) == ["Gamma"])
        #expect(trailing.first?.hasResources == false,
                "块外的 `resources:` 被记到了最后一个 target 上")

        let url = GuardScanRoots.declaredTargets(manifestText: """
        targets: [
            .target(
                name: "Delta",
                dependencies: ["https://example.com/not-a-comment"]
            ),
            .target(name: "Epsilon"),
        ]
        """)
        #expect(url.map(\.name) == ["Delta", "Epsilon"])

        let kinds = GuardScanRoots.declaredTargets(manifestText: """
        targets: [
            .target(name: "Lib"),
            .testTarget(name: "LibTests", dependencies: ["Lib"]),
        ]
        """)
        #expect(kinds.filter(\.isLibrary).map(\.name) == ["Lib"])
    }

    @Test("manifest 解析器：块注释与多行字符串不再吃掉 / 伪造 target（PR #265 第 4 轮终审 I-3）")
    func manifestParserHandlesBlockCommentsAndMultilineStrings() {
        let unbalanced = GuardScanRoots.declaredTargets(manifestText: """
        targets: [
            .target(
                name: "Alpha"
                /* 历史备注：早期这里写的是 .target( 形态，见 #244 */
            ),
            .target(name: "Beta"),
        ]
        """)
        #expect(unbalanced.map(\.name) == ["Alpha", "Beta"],
                "块注释里的未配对括号把后面的 target 吃掉了 —— 丢失的 target 完全不受守卫覆盖")

        let commentedOut = GuardScanRoots.declaredTargets(manifestText: """
        targets: [
            /*
            .target(
                name: "Ghost",
                resources: [.process("Resources")]
            ),
            */
            .target(name: "Real"),
        ]
        """)
        #expect(commentedOut.map(\.name) == ["Real"],
                "注释掉的 target 变成了幽灵条目 —— 双向差集会红在一个 manifest 里根本不存在的名字上")
        #expect(commentedOut.first?.hasResources == false,
                "注释里的 `resources:` 被记到了真 target 上 —— `.module` 归属判据会说 Real 有资源包")

        let multiline = GuardScanRoots.declaredTargets(manifestText: #"""
        targets: [
            .target(
                name: "Doc",
                swiftSettings: [.define("""
                一段说明：这里故意写 .target( 和一个左括号 (
                """)]
            ),
            .target(name: "Next"),
        ]
        """#)
        #expect(multiline.map(\.name) == ["Doc", "Next"],
                "多行字符串体被当成代码 —— 后面的 target 丢失或多出幽灵条目")

        var renamed: [GuardScanRoots.DeclaredTarget] = []
        withKnownIssue("非字面量 name 必须 Issue.record，不得静默改名") {
            renamed = GuardScanRoots.declaredTargets(manifestText: """
            targets: [
                .target(name: shadersName, path: "Sources/Shaders"),
            ]
            """)
        }
        #expect(renamed.isEmpty, """
        `.target(name: shadersName, path: "Sources/Shaders")` 被解析成了 \(renamed.map(\.name))
        —— 首版取「整行第一个引号串」，于是产出一个名叫 "Sources/Shaders" 的幽灵 library target
        且零 `Issue.record`。方向仍 fail-closed，但**静默改名比丢弃更难排查**：
        读者会拿着一个从没在 manifest 里出现过的名字去找。
        """)
    }

    @Test("manifest 解析器：嵌套块注释 / 插值 name / 同行多个 `name:`（PR #265 第 5 轮终审 S-a / S-b）")
    func manifestParserHandlesNestedCommentsAndTrickyNames() {
        let nested = GuardScanRoots.declaredTargets(manifestText: """
        targets: [
            /* 老写法：
               /* 更老的写法 */
               .target(name: "Ghost", resources: [.process("R")]),
            */
            .target(name: "Alpha"),
            .target(name: "Beta"),
        ]
        """)
        #expect(nested.map(\.name) == ["Alpha", "Beta"],
                "嵌套块注释里被注释掉的 target 变成了幽灵条目 —— 双向差集会红在一个不存在的名字上")
        #expect(nested.allSatisfy { !$0.hasResources },
                "嵌套注释里的 `resources:` 被记到了真 target 上 —— `.module` 归属表凭空多一条")

        var interpolated: [GuardScanRoots.DeclaredTarget] = []
        withKnownIssue("插值 name 必须 Issue.record，不得静默产出一个含插值的 target 名") {
            interpolated = GuardScanRoots.declaredTargets(manifestText: ##"""
            targets: [
                .target(name: "\(prefix)Alpha"),
            ]
            """##)
        }
        #expect(interpolated.isEmpty, """
        插值 name 被静默产出成了 \(interpolated.map(\.name))
        —— 那个名字在 manifest 里根本不存在，读者查不到它。
        """)

        let depsFirst = GuardScanRoots.declaredTargets(manifestText: """
        targets: [
            .target(dependencies: [.product(name: "Inner", package: "p")], name: "Alpha"),
        ]
        """)
        #expect(depsFirst.map(\.name) == ["Alpha"],
                "同行的内层 `name:` 被当成了 target 名 —— 静默改名，双向差集会红在 `Inner` 上")

        let spaced = GuardScanRoots.declaredTargets(manifestText: """
        targets: [
            .target(name : "Alpha"),
        ]
        """)
        #expect(spaced.map(\.name) == ["Alpha"],
                "`name :` 被判成非字面量 —— 诊断误导：那行的 name 明明就是字符串字面量")
    }

    @Test("根列表与 Package.swift 的 library target 双向吻合 —— 新增 target 忘了扩根即红")
    func libraryTargetsAreCoveredByScanRoots() throws {
        let declared = try GuardScanRoots.declaredLibraryTargets()
        #expect(declared.count >= 3, "从 Package.swift 只解析到 \(declared.count) 个 library target —— 解析器可能失效，不是「target 变少了」")

        let declaredSet = Set(declared)
        let known = Set(GuardScanRoots.targetNames)
        let unguarded = declaredSet.subtracting(known).sorted()
        #expect(unguarded.isEmpty, """
        这些 library target 在 Package.swift 里声明了，却不在 `GuardScanRoots.targetNames` 里：\(unguarded)
        —— 它们的源码**不受** Bool 纪律 / a11y 字面量 / 色相字面量 / chrome 文案任何一条守卫覆盖。
        这正是 `#246` 要堵的「新 target 变成垃圾抽屉」。处置：把名字加进 `targetNames`，
        并确认三条新守卫在它上面真的跑得起来（`Sources/<名字>/` 必须已存在）。
        ⚠️ 不要反过来把 target 从 manifest 里藏起来。
        """)
        let ghosts = known.subtracting(declaredSet).sorted()
        #expect(ghosts.isEmpty, """
        `GuardScanRoots.targetNames` 里这些名字在 Package.swift 里已经没有对应的 library target：\(ghosts)
        —— 幽灵根会让「每个根断言目录存在」那条判据红在一个已经不该存在的路径上。
        """)
        #expect(known.contains(GuardScanRoots.primaryTargetName),
                "主 target `\(GuardScanRoots.primaryTargetName)` 不在根列表里 —— 台账键的默认前缀失去依据")
    }

    @Test("manifest 解析器：library target 写 `path:` ⇒ 当场判红（终审 S-2 的 fail-open 入口）")
    func manifestParserFlagsExplicitTargetPath() {
        withKnownIssue("合成 manifest 故意写 path: —— 本块若不记录 issue 说明 fail-open 入口又开了") {
            _ = GuardScanRoots.declaredTargets(manifestText: """
            targets: [
                .target(name: "Foo", path: "Sources/Bar"),
            ]
            """)
        }

        let clean = GuardScanRoots.declaredTargets(manifestText: """
        targets: [
            .target(name: "Foo", resources: [.process("Resources")]),
            .testTarget(name: "FooTests", dependencies: ["Foo"]),
        ]
        """)
        #expect(clean.map(\.name) == ["Foo", "FooTests"], "无 path: 的合成 manifest 解析结果变了")
    }

    @Test("`Sources/CoreDesignShaders/` 尚不存在，因此**不得**进根列表（防 fail-open）")
    func shadersRootIsDeliberatelyAbsent() {
        let shaders = GuardScanRoots.sourcesURL(of: "CoreDesignShaders")
        let exists = FileManager.default.fileExists(atPath: shaders.path)
        let listed = GuardScanRoots.targetNames.contains("CoreDesignShaders")
        #expect(exists == listed, """
        `Sources/CoreDesignShaders/` 存在=\(exists)，而根列表里有它=\(listed) —— 两者必须一致：
        · 目录不存在却进了列表 ⇒ 「每个根断言目录存在」会红（fail-closed，符合预期）；
        · 目录存在却没进列表 ⇒ 该 target 的源码**完全不受守卫覆盖**，且所有 grep 判据
          在它上面无命中即绿（fail-open）。处置：把 `CoreDesignShaders` 加进
          `GuardScanRoots.targetNames`（`shipswift-shaders` 的 B-1）。
        """)
    }

    // MARK: - NFR-4：零 `@unchecked Sendable`

    static func uncheckedSendableLines(in source: String) -> [Int] {
        source.split(separator: "\n", omittingEmptySubsequences: false).enumerated()
            .filter { $0.element.contains("@unchecked Sendable") }
            .map { $0.offset + 1 }
    }

    @Test("NFR-4：全部已存在 target 的源码里零 `@unchecked Sendable`")
    func noUncheckedSendable() {
        #expect(GuardScanRoots.assertRootsExist(GuardScanRoots.allRoots))

        var offenders: [String] = []
        var scannedFiles = 0
        for root in GuardScanRoots.allRoots {
            let files = GuardScanRoots.swiftFiles(in: root.url)
            #expect(!files.isEmpty, "\(root.target) 下没有任何 .swift 文件 —— NFR-4 的 grep 在它上面恒绿")
            scannedFiles += files.count
            for url in files {
                guard let text = try? String(contentsOf: url, encoding: .utf8) else {
                    Issue.record("读不到 \(GuardScanRoots.relativePath(url)) —— 判据无法工作")
                    continue
                }
                for line in Self.uncheckedSendableLines(in: text) {
                    offenders.append("\(GuardScanRoots.relativePath(url)):\(line)")
                }
            }
        }
        #expect(scannedFiles > 50, "只扫到 \(scannedFiles) 个源文件 —— 扫描失效，「零命中」不可信")
        #expect(offenders.isEmpty, """
        NFR-4：这些位置用了 `@unchecked Sendable`：
        \(offenders.joined(separator: "\n"))
        —— 它把并发正确性从编译器手里拿走、换成一句口头承诺。处置：改成真正的 `Sendable`
        （值语义 / `let` / actor 隔离），或把类型收成非 public 的实现细节。
        """)
    }

    @Test("NFR-4 的探测器真的会开火（合成输入变红自证）")
    func uncheckedSendableDetectorActuallyFires() {
        let violating = """
        import Foundation
        final class Box: @unchecked Sendable {
            var value = 0
        }
        """
        #expect(Self.uncheckedSendableLines(in: violating) == [2],
                "探测器对最直白的违规都不开火 —— 上面那条「零命中」毫无意义")
        let clean = """
        struct Box: Sendable { let value = 0 }
        """
        #expect(Self.uncheckedSendableLines(in: clean).isEmpty, "探测器误报：干净的 Sendable 也被标记")
    }

    // MARK: - 台账键的 target 前缀

    @Test("台账键前缀：主 target 走裸形，新 target 必须带前缀")
    func qualifiedKeyShape() {
        #expect(GuardScanRoots.qualifiedKey(target: "CoreDesign", base: "Badge.init#outlined")
                == "Badge.init#outlined")
        #expect(GuardScanRoots.qualifiedKey(target: "CoreDesignEffects", base: "Badge.init#outlined")
                == "CoreDesignEffects/Badge.init#outlined")
        for target in GuardScanRoots.targetNames {
            let key = GuardScanRoots.qualifiedKey(target: target, base: "Foo.init#flag")
            #expect(GuardScanRoots.target(ofKey: key) == target, "键「\(key)」取不回 target \(target)")
            #expect(GuardScanRoots.baseKey(key) == "Foo.init#flag")
        }
        #expect(GuardScanRoots.qualifiedKey(target: "CoreDesign", base: "Foo.init#flag")
                != GuardScanRoots.qualifiedKey(target: "CoreDesignCharts", base: "Foo.init#flag"))
    }

    @Test("`.module` 归属：manifest 的 `resources:` 与 `Resources/` 目录同进同退")
    func moduleBundleOwnership() {
        #expect(GuardScanRoots.ownsResourceBundle("CoreDesign"),
                "Package.swift 里 CoreDesign 的 `resources:` 声明不见了 —— a11y 守卫的 `bundle: .module` 放行条失去依据")

        for target in GuardScanRoots.targetNames {
            let declared = GuardScanRoots.ownsResourceBundle(target)
            var isDirectory: ObjCBool = false
            let dirExists = FileManager.default.fileExists(
                atPath: GuardScanRoots.sourcesURL(of: target).appendingPathComponent("Resources").path,
                isDirectory: &isDirectory
            ) && isDirectory.boolValue
            #expect(declared == dirExists, """
            \(target)：Package.swift 声明了 `resources:`=\(declared)，而
            `Sources/\(target)/Resources/` 目录存在=\(dirExists) —— 两者必须一致：
            · 有目录没声明 ⇒ SwiftPM 只报 unhandled resource 警告、**不合成 `Bundle.module`**，
              但写 `bundle: .module` 的文本判据会把它当「已本地化」放行（假绿）；
            · 有声明没目录 ⇒ SwiftPM 构建直接失败。
            处置：两样一起加，或两样一起删。
            """)
            if declared, target != GuardScanRoots.primaryTargetName {
                print("【.module 归属】\(target) 现在拥有自己的资源包 —— 请复核 `AccessibilityStringLiteralGuard` 的按 target 放行逻辑。")
            }
        }
    }

    // MARK: - manifest 解析器自身的变红自证（PR #265 终审 S-4）

    @Test("manifest 解析器：现状快照 + 非字面量 name 不被静默丢弃")
    func manifestParserSnapshot() throws {
        let targets = try GuardScanRoots.declaredTargets()
        let libraries = Set(targets.filter(\.isLibrary).map(\.name))
        #expect(libraries == Set(GuardScanRoots.targetNames),
                "manifest 解析出的 library target \(libraries.sorted()) 与根列表不符")
        let nonLibraries = Set(targets.filter { !$0.isLibrary }.map(\.name))
        #expect(nonLibraries.contains("CoreDesignTests"), "`.testTarget(` 没被解析出来 —— 解析器可能失效")
        #expect(!libraries.contains("CoreDesignTests"), "test target 被误判成 library target")
        #expect(GuardScanRoots.resourceOwningTargets().contains("CoreDesign"),
                "解析器没从 Package.swift 读出 CoreDesign 的 `resources:` —— `.module` 归属判据失效")
        #expect(!targets.filter(\.hasResources).isEmpty,
                "解析器一条 `resources:` 都没读出来 —— 「谁有资源包」会退化成恒 false")
    }

    // MARK: - `relativePath` 对符号链接前缀的免疫（`#311`）

    @Test("`relativePath` 对 /private 前缀不一致免疫，且不做串中间的替换（#311）")
    func relativePathIgnoresPrivatePrefixMismatch() {
        #expect(
            GuardScanRoots.relativePath(
                URL(fileURLWithPath: "/private/tmp/repo/Sources/CoreDesignEffects/Shine.swift"),
                from: URL(fileURLWithPath: "/tmp/repo")
            ) == "Sources/CoreDesignEffects/Shine.swift"
        )

        #expect(
            GuardScanRoots.relativePath(
                URL(fileURLWithPath: "/tmp/repo/Sources/CoreDesign/Components/Banner/Banner.swift"),
                from: URL(fileURLWithPath: "/private/tmp/repo")
            ) == "Sources/CoreDesign/Components/Banner/Banner.swift"
        )

        #expect(
            GuardScanRoots.relativePath(
                URL(fileURLWithPath: "/Users/somebody/CoreDesign/docs/DESIGN-FOUNDATION.md"),
                from: URL(fileURLWithPath: "/Users/somebody/CoreDesign")
            ) == "docs/DESIGN-FOUNDATION.md"
        )

        #expect(
            GuardScanRoots.relativePath(
                URL(fileURLWithPath: "/elsewhere/tmp/repo/Sources/CoreDesign/Foo.swift"),
                from: URL(fileURLWithPath: "/tmp/repo"), expectingContainment: false
            ) == "/elsewhere/tmp/repo/Sources/CoreDesign/Foo.swift"
        )

        #expect(
            GuardScanRoots.relativePath(
                URL(fileURLWithPath: "/tmp/repo"), from: URL(fileURLWithPath: "/tmp/repo"),
                expectingContainment: false
            ) == "/tmp/repo"
        )

        #expect(
            GuardScanRoots.relativePath(
                URL(fileURLWithPath: "/Users/e/RepoX/S/Foo.swift"),
                from: URL(fileURLWithPath: "/Users/e/Repo"), expectingContainment: false
            ) == "/Users/e/RepoX/S/Foo.swift"
        )

        #expect(
            GuardScanRoots.relativePath(
                URL(fileURLWithPath: "/Users/somebody/y.swift"),
                from: URL(fileURLWithPath: "/private"), expectingContainment: false
            ) == "/Users/somebody/y.swift"
        )

        withKnownIssue("兜底会记录：这里故意传一个不在根下的 url，期望恰好记下一条") {
            _ = GuardScanRoots.relativePath(
                URL(fileURLWithPath: "/elsewhere/Foo.swift"),
                from: URL(fileURLWithPath: "/tmp/repo")
            )
        }
    }

    // MARK: - `expectingContainment` 的 fail-open 旋钮必须被钉住（`#313` 第 2 轮终审 I-4）

    @Test("`expectingContainment` 的 fail-open 旋钮只许出现在 relativePath 自己的判据里（#311）")
    func containmentOptOutIsConfinedToItsOwnJudgement() throws {
        let optOut = "expectingContainment:" + " false"
        let allowedOwner = "relativePathIgnoresPrivatePrefixMismatch"

        let files = GuardScanRoots.swiftFiles(
            in: GuardScanRoots.repoRoot.appendingPathComponent("Tests")
        )
        #expect(files.count > 20, "只扫到 \(files.count) 个测试源文件 —— 扫描失效，「零命中」不可信")

        var hits = 0
        var offenders: [String] = []
        for url in files {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else {
                Issue.record("读不到 \(GuardScanRoots.relativePath(url)) —— 判据无法工作，这不是「零违规」")
                continue
            }
            var owner = "<文件顶层>"
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
            for (index, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("//") else { continue }
                if let name = Self.declaredFunctionName(on: trimmed) { owner = name }
                guard trimmed.contains(optOut) else { continue }
                hits += 1
                if owner != allowedOwner {
                    offenders.append("\(GuardScanRoots.relativePath(url)):\(index + 1)（在 `\(owner)` 内）")
                }
            }
        }

        #expect(hits >= 4, """
        只扫到 \(hits) 处 `\(optOut)` —— 现存应有 4 处，全在 `\(allowedOwner)` 的合成形态里。
        ⚠️ 本条在 `hits` 落到 0 / 1 / 2 / 3 时都会红，别照着「一处都没扫到」去查
        （`#313` 第 3 轮终审）：`hits == 0` 是本条已经退化成恒绿（形参改名？判据被删？）；
        `0 < hits < 4` 则是合成形态被删掉了一部分，判别力少了一格但本条还活着。
        处置：先看上面这个数，再确认 `GuardScanRoots.relativePath(_:from:)` 的兜底开关
        与 `\(allowedOwner)` 里那四种合成形态都还在，最后同步本条的串。
        """)
        #expect(offenders.isEmpty, """
        `\(optOut)` 出现在了 `\(allowedOwner)` 之外：
        \(offenders.joined(separator: "\n"))
        —— 它把 `relativePath(_:from:)` 的兜底 `Issue.record` 整条关掉、退回静默
        fail-open（`#311` 那类路径分叉会重新变成「台账键被污染但没人红」）。
        真实扫描路径上的 `url` 全部由枚举 `root` 得到，结构上不可能不在 `root` 之下
        ⇒ 那里不需要这个旋钮；需要它只说明那条路径的根用错了。
        """)
    }

    static func declaredFunctionName(on line: String) -> String? {
        guard let keyword = line.range(of: "func ") else { return nil }
        let rest = line[keyword.upperBound...]
        guard let stop = rest.firstIndex(where: { $0 == "(" || $0 == "<" }) else { return nil }
        let name = rest[rest.startIndex..<stop].trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? nil : name
    }

    // MARK: - 枚举器会解析扫描根祖先里的符号链接（`#311` 修法的地基 / `#313` 终审 C-4）

    @Test("`FileManager.enumerator` 会解析根祖先里的符号链接，`relativePath` 必须归一回去（#311）")
    func enumeratorResolvesSymlinksInScanRootAncestor() throws {
        let fixture = try SymlinkedScanRootFixture.make(
            rootName: "Root", files: ["Sub/A.swift": "// fixture\n"]
        )
        defer { fixture.destroy() }

        let walker = try #require(
            FileManager.default.enumerator(at: fixture.root, includingPropertiesForKeys: nil),
            "无法枚举 fixture 根 —— 判据无法工作，这不是「零违规」"
        )
        var swiftFiles: [URL] = []
        for case let url as URL in walker where url.pathExtension == "swift" { swiftFiles.append(url) }
        let file = try #require(swiftFiles.first, "fixture 里的 .swift 没被枚举出来")

        #expect(
            !file.path.hasPrefix(fixture.root.path),
            """
            枚举器不再解析根祖先里的符号链接（根 \(fixture.root.path)，枚举得 \(file.path)）
            —— `#311` 修法据以成立的前提变了，`relativePath(_:from:)` 的归一逻辑需要重新评估。
            """
        )
        #expect(
            file.path.hasSuffix("/\(SymlinkedScanRootFixture.realDirectoryName)/Root/Sub/A.swift"),
            "枚举产出没走解析后的实体目录：\(file.path)"
        )

        #expect(
            GuardScanRoots.relativePath(file, from: fixture.root) == "Sub/A.swift",
            "根内相对路径没被归一：\(GuardScanRoots.relativePath(file, from: fixture.root))"
        )
    }
}

// MARK: - `#311` 复现用的符号链接扫描根 fixture（`#313` 终审 C-1 / C-4 共用）

nonisolated struct SymlinkedScanRootFixture {
    static let realDirectoryName = "real"
    static let linkDirectoryName = "link"

    let base: URL
    let root: URL

    static func make(rootName: String, files: [String: String]) throws -> Self {
        let fileManager = FileManager.default
        let base = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("cd311-symlinked-root-\(UUID().uuidString)")
        do {
            let real = base.appendingPathComponent(Self.realDirectoryName)
                .appendingPathComponent(rootName)
            for (relativePath, contents) in files {
                let destination = real.appendingPathComponent(relativePath)
                try fileManager.createDirectory(
                    at: destination.deletingLastPathComponent(), withIntermediateDirectories: true
                )
                try Data(contents.utf8).write(to: destination)
            }
            try fileManager.createSymbolicLink(
                at: base.appendingPathComponent(Self.linkDirectoryName),
                withDestinationURL: base.appendingPathComponent(Self.realDirectoryName)
            )
        } catch {
            try? fileManager.removeItem(at: base)
            throw error
        }
        return Self(
            base: base,
            root: base.appendingPathComponent(Self.linkDirectoryName).appendingPathComponent(rootName)
        )
    }

    func destroy() {
        try? FileManager.default.removeItem(at: self.base)
    }
}
