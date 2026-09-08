import Foundation
import SwiftParser
import SwiftSyntax
import Testing

// MARK: - 类型分类 / Parameter type classification

nonisolated enum BoolParamKind: Sendable, Equatable {
    case plainBool
    case boolCarrying
    case notBool
}

nonisolated func isRedundantOuterParen(_ t: String) -> Bool {
    guard t.hasPrefix("("), t.hasSuffix(")") else { return false }
    let chars = Array(t)
    var depth = 0
    var topLevelComma = false
    for (index, char) in chars.enumerated() {
        if char == "(" {
            depth += 1
        } else if char == ")" {
            depth -= 1
            if depth == 0, index != chars.count - 1 { return false }
        } else if char == ",", depth == 1 {
            topLevelComma = true
        }
    }
    return !topLevelComma
}

nonisolated func stripComments(_ t: String) -> String {
    let chars = Array(t)
    var result = ""
    result.reserveCapacity(chars.count)
    var i = 0
    var depth = 0
    while i < chars.count {
        if depth > 0 {
            if chars[i] == "/", i + 1 < chars.count, chars[i + 1] == "*" {
                depth += 1
                i += 2
            } else if chars[i] == "*", i + 1 < chars.count, chars[i + 1] == "/" {
                depth -= 1
                i += 2
                if depth == 0 { result.append(" ") }
            } else {
                i += 1
            }
            continue
        }
        if chars[i] == "/", i + 1 < chars.count, chars[i + 1] == "*" {
            depth = 1
            i += 2
            continue
        }
        if chars[i] == "/", i + 1 < chars.count, chars[i + 1] == "/" {
            while i < chars.count, chars[i] != "\n", chars[i] != "\r" { i += 1 }
            result.append(" ")
            continue
        }
        result.append(chars[i])
        i += 1
    }
    return result
}

nonisolated func normalizeWhitespace(_ t: String) -> String {
    let collapsed = t.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    return collapsed.replacingOccurrences(
        of: #"\s*([.<>])\s*"#, with: "$1", options: .regularExpression
    )
}

// MARK: - 类型文本剥离层（Task 1 抽出，#40 复用）/ Type-text stripping layer

struct StrippedTypeText: Equatable, Sendable {
    let text: String
    let sawInout: Bool
    let sawAutoclosure: Bool
}

nonisolated func stripTypeDecorations(_ raw: String) -> StrippedTypeText {
    var t = normalizeWhitespace(stripComments(raw)).replacingOccurrences(of: "`", with: "")
    var sawInout = false
    var sawAutoclosure = false
    while true {
        var stripped = false
        for specifier in ["inout", "borrowing", "consuming", "sending", "__owned", "__shared", "_const"]
        where t.hasPrefix(specifier) {
            let rest = t.dropFirst(specifier.count)
            guard let next = rest.first, next == " " || next == "(" else { continue }
            if specifier == "inout" { sawInout = true }
            t = String(rest).trimmingCharacters(in: .whitespaces)
            stripped = true
            break
        }
        if !stripped, t.hasPrefix("@") {
            let attribute = String(t.prefix(while: { !$0.isWhitespace }))
            let attributeName: String
            if attribute.hasSuffix("()") {
                attributeName = String(attribute.dropLast(2))
            } else if attribute.hasPrefix("@autoclosure()") {
                attributeName = "@autoclosure"
            } else if attribute == "@autoclosure(",
                let closeParen = t.dropFirst(attribute.count).firstIndex(of: ")"),
                t.dropFirst(attribute.count)[..<closeParen].allSatisfy(\.isWhitespace) {
                attributeName = "@autoclosure"
            } else {
                attributeName = attribute
            }
            if attributeName == "@autoclosure" {
                sawAutoclosure = true
                t = String(t.dropFirst(attributeName.count)).trimmingCharacters(in: .whitespaces)
            } else {
                t = String(t.dropFirst(attribute.count)).trimmingCharacters(in: .whitespaces)
            }
            stripped = true
        }
        if !stripped { break }
    }
    return StrippedTypeText(text: t, sawInout: sawInout, sawAutoclosure: sawAutoclosure)
}

nonisolated func stripOptionalSugarAndRedundantParens(_ raw: String) -> String {
    var t = raw
    while true {
        var stripped = false
        while t.hasSuffix("?") || t.hasSuffix("!") {
            t.removeLast()
            t = t.trimmingCharacters(in: .whitespaces)
            stripped = true
        }
        if isRedundantOuterParen(t) {
            t = String(t.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
            stripped = true
        }
        if !stripped { break }
    }
    return t
}

nonisolated func classifyBoolParameterType(_ raw: String) -> BoolParamKind {
    let stripped = stripTypeDecorations(raw)
    var t = stripped.text
    if stripped.sawInout {
        return t.range(of: #"\bBool\b"#, options: .regularExpression) != nil ? .boolCarrying : .notBool
    }
    if stripped.sawAutoclosure {
        let normalized = t.replacingOccurrences(of: " ", with: "")
        if normalized.hasPrefix("()->") {
            let returnType = String(normalized.dropFirst(4))
            if classifyBoolParameterType(returnType) == .plainBool { return .plainBool }
        }
    }

    t = stripOptionalSugarAndRedundantParens(t)
    if t == "Bool" || t == "Swift.Bool" || t == "CBool" || t == "Swift.CBool" { return .plainBool }
    if let genericArgument = optionalGenericArgument(t),
        classifyBoolParameterType(genericArgument) == .plainBool {
        return .plainBool
    }
    if t.range(of: #"\bBool\b"#, options: .regularExpression) != nil { return .boolCarrying }
    return .notBool
}

nonisolated func optionalGenericArgument(_ t: String) -> String? {
    for prefix in ["Optional<", "Swift.Optional<"] where t.hasPrefix(prefix) && t.hasSuffix(">") {
        let start = t.index(t.startIndex, offsetBy: prefix.count)
        let end = t.index(before: t.endIndex)
        guard start <= end else { continue }
        return String(t[start..<end])
    }
    return nil
}

// MARK: - 命中项 / Hit

struct BoolParamHit: Hashable, Comparable, Sendable {
    let owner: String
    let decl: String
    let parameter: String
    let file: String
    let line: Int
    var target: String = GuardScanRoots.primaryTargetName

    var baseKey: String { "\(self.owner).\(self.decl)#\(self.parameter)" }

    var key: String { GuardScanRoots.qualifiedKey(target: self.target, base: self.baseKey) }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.key == rhs.key ? lhs.line < rhs.line : lhs.key < rhs.key
    }
}

struct BoolScanResult: Sendable {
    var hits: [BoolParamHit] = []
    var carrying: [BoolParamHit] = []
    var publicBoolProperties: [String] = []
    var publicBoolTypeAliases: [String] = []

    var keys: Set<String> { Set(self.hits.map(\.key)) }
}

// MARK: - 双向差集 / Bidirectional diff

func compareBoolHitsToExemptions(
    hits: Set<String>, exempted: Set<String>
) -> (violations: Set<String>, stale: Set<String>) {
    (violations: hits.subtracting(exempted), stale: exempted.subtracting(hits))
}

// MARK: - 扫描入口 / Scan entry points

func scanBoolParams(root: URL, target: String = GuardScanRoots.primaryTargetName) throws -> BoolScanResult {
    guard FileManager.default.fileExists(atPath: root.path) else {
        Issue.record("源码路径不存在：\(root.path) —— 判据无法工作，这不是「零违规」")
        return BoolScanResult()
    }
    guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
        Issue.record("无法枚举源码目录：\(root.path)（权限或 IO 异常）—— 判据无法工作，这不是「零违规」")
        return BoolScanResult()
    }
    var result = BoolScanResult()
    for case let url as URL in walker where url.pathExtension == "swift" {
        let tree = SwiftParser.Parser.parse(source: try String(contentsOf: url, encoding: .utf8))
        let rel = GuardScanRoots.relativePath(url)
        if tree.hasError {
            Issue.record("解析出错：\(rel) —— swift-syntax major 可能与工具链不配套")
        }
        let partial = collectBoolParams(tree: tree, fileName: rel, target: target)
        result.hits += partial.hits
        result.carrying += partial.carrying
        result.publicBoolProperties += partial.publicBoolProperties
        result.publicBoolTypeAliases += partial.publicBoolTypeAliases
    }
    return result
}

func scanBoolParams(roots: [(target: String, url: URL)]) throws -> BoolScanResult {
    GuardScanRoots.assertRootsExist(roots)
    var result = BoolScanResult()
    for root in roots {
        let partial = try scanBoolParams(root: root.url, target: root.target)
        result.hits += partial.hits
        result.carrying += partial.carrying
        result.publicBoolProperties += partial.publicBoolProperties
        result.publicBoolTypeAliases += partial.publicBoolTypeAliases
    }
    return result
}

func scanBoolParams(
    source: String, fileName: String = "Synthetic.swift",
    target: String = GuardScanRoots.primaryTargetName
) -> BoolScanResult {
    collectBoolParams(tree: SwiftParser.Parser.parse(source: source), fileName: fileName, target: target)
}

private func collectBoolParams(tree: SourceFileSyntax, fileName: String, target: String) -> BoolScanResult {
    let converter = SourceLocationConverter(fileName: fileName, tree: tree)
    let collector = PublicBoolParamCollector(fileName: fileName, converter: converter, target: target)
    collector.walk(tree)
    var result = BoolScanResult()
    result.hits = collector.hits
    result.carrying = collector.carrying
    result.publicBoolProperties = collector.publicBoolProperties
    result.publicBoolTypeAliases = collector.publicBoolTypeAliases
    return result
}

// MARK: - 采集器 / Collector

private nonisolated final class PublicBoolParamCollector: SyntaxVisitor {
    var hits: [BoolParamHit] = []
    var carrying: [BoolParamHit] = []
    var publicBoolProperties: [String] = []
    var publicBoolTypeAliases: [String] = []

    private let fileName: String
    private let converter: SourceLocationConverter
    private let target: String

    private struct Frame {
        let name: String
        let isPublic: Bool
        let isPrivate: Bool
        let isInternal: Bool
        let isExtension: Bool
        var isProtocol: Bool = false
    }
    private var frames: [Frame] = []

    init(fileName: String, converter: SourceLocationConverter, target: String) {
        self.fileName = fileName
        self.converter = converter
        self.target = target
        super.init(viewMode: .sourceAccurate)
    }

    // MARK: 访问级别

    private static func access(_ modifiers: DeclModifierListSyntax) -> (pub: Bool, priv: Bool, int: Bool) {
        let names = Set(modifiers.map { $0.name.text })
        return (
            names.contains("public") || names.contains("open"),
            names.contains("private") || names.contains("fileprivate"),
            names.contains("internal")
        )
    }

    private func isEffectivelyPublic(_ modifiers: DeclModifierListSyntax) -> Bool {
        let a = Self.access(modifiers)
        if a.priv || a.int { return false }
        if self.frames.contains(where: { $0.isPrivate || $0.isInternal }) { return false }
        if self.frames.contains(where: { !$0.isExtension && !$0.isPublic }) { return false }
        guard let innermost = self.frames.last else { return a.pub }
        if innermost.isExtension { return innermost.isPublic || a.pub }
        if innermost.isProtocol { return innermost.isPublic }
        return a.pub
    }

    private func inheritsPublicFromContainer() -> Bool {
        if self.frames.contains(where: { $0.isPrivate || $0.isInternal }) { return false }
        if self.frames.contains(where: { !$0.isExtension && !$0.isPublic }) { return false }
        guard let innermost = self.frames.last else { return false }
        return innermost.isPublic
    }

    private var owner: String {
        self.frames.isEmpty ? "(top-level)" : self.frames.map(\.name).joined(separator: ".")
    }

    // MARK: 容器帧

    private func pushType(_ name: String, _ modifiers: DeclModifierListSyntax) {
        let a = Self.access(modifiers)
        let hasExplicitAccess = a.pub || a.priv || a.int
        let inheritsPublicFromExtension =
            !hasExplicitAccess
            && self.frames.last?.isExtension == true
            && self.frames.last?.isPublic == true
        self.frames.append(
            Frame(
                name: name,
                isPublic: a.pub || inheritsPublicFromExtension,
                isPrivate: a.priv, isInternal: a.int, isExtension: false
            )
        )
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        self.pushType(node.name.text, node.modifiers); return .visitChildren
    }
    override func visitPost(_ node: StructDeclSyntax) { self.frames.removeLast() }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        self.pushType(node.name.text, node.modifiers); return .visitChildren
    }
    override func visitPost(_ node: EnumDeclSyntax) { self.frames.removeLast() }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        self.pushType(node.name.text, node.modifiers); return .visitChildren
    }
    override func visitPost(_ node: ClassDeclSyntax) { self.frames.removeLast() }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        self.pushType(node.name.text, node.modifiers); return .visitChildren
    }
    override func visitPost(_ node: ActorDeclSyntax) { self.frames.removeLast() }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        let a = Self.access(node.modifiers)
        let hasExplicitAccess = a.pub || a.priv || a.int
        let inheritsPublicFromExtension =
            !hasExplicitAccess
            && self.frames.last?.isExtension == true
            && self.frames.last?.isPublic == true
        self.frames.append(
            Frame(
                name: node.name.text,
                isPublic: a.pub || inheritsPublicFromExtension,
                isPrivate: a.priv, isInternal: a.int,
                isExtension: false, isProtocol: true
            )
        )
        return .visitChildren
    }
    override func visitPost(_ node: ProtocolDeclSyntax) { self.frames.removeLast() }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        var extended = node.extendedType.trimmedDescription
        if let angle = extended.firstIndex(of: "<") { extended = String(extended[..<angle]) }
        let a = Self.access(node.modifiers)
        self.frames.append(
            Frame(
                name: extended.trimmingCharacters(in: .whitespaces),
                isPublic: a.pub, isPrivate: a.priv, isInternal: a.int, isExtension: true
            )
        )
        return .visitChildren
    }
    override func visitPost(_ node: ExtensionDeclSyntax) { self.frames.removeLast() }

    override func visit(_ node: IfConfigDeclSyntax) -> SyntaxVisitorContinueKind {
        for clause in node.clauses {
            if let elements = clause.elements { self.walk(elements) }
        }
        return .skipChildren
    }

    override func visit(_ node: MacroExpansionDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }

    override func visit(_ node: MacroExpansionExprSyntax) -> SyntaxVisitorContinueKind { .skipChildren }

    // MARK: 声明

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        self.collect(node.signature.parameterClause.parameters, decl: "init", modifiers: node.modifiers, at: node)
        return .skipChildren
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        self.collect(node.signature.parameterClause.parameters, decl: node.name.text, modifiers: node.modifiers, at: node)
        return .skipChildren
    }

    override func visit(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind {
        self.collect(node.parameterClause.parameters, decl: "subscript", modifiers: node.modifiers, at: node)
        return .skipChildren
    }

    override func visit(_ node: EnumCaseDeclSyntax) -> SyntaxVisitorContinueKind {
        guard self.inheritsPublicFromContainer() else { return .skipChildren }
        let line = self.converter.location(for: node.positionAfterSkippingLeadingTrivia).line
        for element in node.elements {
            guard let parameters = element.parameterClause?.parameters else { continue }
            for (index, parameter) in parameters.enumerated() {
                let name = (parameter.secondName ?? parameter.firstName)?.text ?? "_\(index)"
                let hit = BoolParamHit(
                    owner: self.owner, decl: element.name.text, parameter: name,
                    file: self.fileName, line: line, target: self.target
                )
                switch classifyBoolParameterType(parameter.type.trimmedDescription) {
                case .plainBool: self.hits.append(hit)
                case .boolCarrying: self.carrying.append(hit)
                case .notBool: break
                }
            }
        }
        return .skipChildren
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        guard self.isEffectivelyPublic(node.modifiers) else { return .skipChildren }
        for binding in node.bindings {
            guard let type = binding.typeAnnotation?.type,
                  classifyBoolParameterType(type.trimmedDescription) == .plainBool,
                  let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
            else { continue }
            self.publicBoolProperties.append("\(self.owner).\(name)")
        }
        return .skipChildren
    }

    override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        guard self.isEffectivelyPublic(node.modifiers) else { return .skipChildren }
        let underlying = node.initializer.value.trimmedDescription
        if classifyBoolParameterType(underlying) != .notBool {
            self.publicBoolTypeAliases.append("\(self.owner).\(node.name.text) = \(underlying)")
        }
        return .skipChildren
    }

    private func collect(
        _ parameters: FunctionParameterListSyntax,
        decl: String,
        modifiers: DeclModifierListSyntax,
        at node: some SyntaxProtocol
    ) {
        guard self.isEffectivelyPublic(modifiers) else { return }
        let line = self.converter.location(for: node.positionAfterSkippingLeadingTrivia).line
        for parameter in parameters {
            let name = (parameter.secondName ?? parameter.firstName).text
            let hit = BoolParamHit(
                owner: self.owner, decl: decl, parameter: name,
                file: self.fileName, line: line, target: self.target
            )
            switch classifyBoolParameterType(parameter.type.trimmedDescription) {
            case .plainBool: self.hits.append(hit)
            case .boolCarrying: self.carrying.append(hit)
            case .notBool: break
            }
        }
    }
}
