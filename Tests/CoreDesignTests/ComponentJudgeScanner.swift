import Foundation
import SwiftParser
import SwiftSyntax
import Testing

// MARK: - 文本型参数分类 / Text parameter classification

nonisolated enum TextParamKind: Sendable, Equatable {
    case bareText
    case localizedText
    case textCarrying
    case notText
}

nonisolated let bareTextTypeNames: Set<String> = [
    "String", "Swift.String", "Substring", "Swift.Substring",
]

nonisolated let localizedTextTypeNames: Set<String> = [
    "LocalizedStringKey", "SwiftUI.LocalizedStringKey",
    "LocalizedStringResource", "Foundation.LocalizedStringResource",
]

nonisolated let stringProtocolOpaqueOrExistentialTypeNames: Set<String> = [
    "StringProtocol", "Swift.StringProtocol",
]

nonisolated func stripSomeOrAnyPrefix(_ t: String) -> String? {
    for prefix in ["some ", "any "] where t.hasPrefix(prefix) {
        return String(t.dropFirst(prefix.count))
    }
    return nil
}

nonisolated func functionReturnTypeText(_ t: String) -> String? {
    let chars = Array(t)
    var depth = 0
    var lastArrow: Int?
    var i = 0
    while i < chars.count {
        if chars[i] == "-", i + 1 < chars.count, chars[i + 1] == ">" {
            if depth == 0 { lastArrow = i }
            i += 2
            continue
        }
        switch chars[i] {
        case "(", "<", "[": depth += 1
        case ")", ">", "]": depth -= 1
        default: break
        }
        i += 1
    }
    guard let arrow = lastArrow else { return nil }
    return String(chars[(arrow + 2)...]).trimmingCharacters(in: .whitespaces)
}

nonisolated func classifyTextParameterType(
    _ raw: String, stringProtocolGenerics: Set<String>
) -> TextParamKind {
    let stripped = stripTypeDecorations(raw)
    var t = stripped.text

    if stripped.sawInout {
        return textIdentifierPresent(t) ? .textCarrying : .notText
    }

    t = stripOptionalSugarAndRedundantParens(t)
    if bareTextTypeNames.contains(t) || stringProtocolGenerics.contains(t) { return .bareText }
    if localizedTextTypeNames.contains(t) { return .localizedText }
    if let afterPrefix = stripSomeOrAnyPrefix(t),
        stringProtocolOpaqueOrExistentialTypeNames.contains(afterPrefix) {
        return .bareText
    }

    if let genericArgument = optionalGenericArgument(t) {
        let inner = classifyTextParameterType(genericArgument, stringProtocolGenerics: stringProtocolGenerics)
        if inner == .bareText || inner == .localizedText { return inner }
    }
    if let returned = functionReturnTypeText(t) {
        let inner = classifyTextParameterType(returned, stringProtocolGenerics: stringProtocolGenerics)
        if inner == .bareText || inner == .localizedText { return inner }
    }
    return textIdentifierPresent(t) ? .textCarrying : .notText
}

nonisolated func textIdentifierPresent(_ t: String) -> Bool {
    t.range(
        of: #"\b(String|Substring|LocalizedStringKey|LocalizedStringResource)\b"#,
        options: .regularExpression
    ) != nil
}

// MARK: - 命中项 / Hit

struct TextParamHit: Hashable, Comparable, Sendable {
    let owner: String
    let decl: String
    let parameter: String
    let file: String
    let line: Int
    let kind: TextParamKind
    let isInitializer: Bool

    var key: String { "\(self.owner).\(self.decl)#\(self.parameter)" }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.key == rhs.key ? lhs.line < rhs.line : lhs.key < rhs.key
    }
}

// MARK: - 扫描结果 / Scan result

struct StyleProtocolDecl: Hashable, Sendable {
    let name: String
    let file: String
    let line: Int
    let isPublic: Bool
    let nameHasStyleSuffix: Bool
}

struct StyleSlotDecl: Hashable, Sendable {
    let typeName: String
    let paramName: String
    let file: String
    let line: Int
    var key: String { "\(self.typeName).\(self.paramName)" }
}

nonisolated func componentJudgeBaseTypeName(_ raw: String) -> String {
    var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    while text.hasSuffix("?") || text.hasSuffix("!") { text.removeLast() }
    if let angle = text.firstIndex(of: "<") { text = String(text[text.startIndex..<angle]) }
    guard !text.contains("["), !text.contains("("), !text.contains(" ") else { return "" }
    return text.split(separator: ".").last.map(String.init) ?? ""
}

struct StyleEnumUse: Hashable, Sendable {
    let enumName: String
    let hostType: String
    let paramName: String
    let file: String
    let line: Int
    var key: String { "\(self.hostType).\(self.enumName)" }
}

struct StyleEnumDecl: Hashable, Sendable {
    let name: String
    let file: String
    let line: Int
    let caseNames: Set<String>
}

struct ConformanceRecord: Hashable, Sendable {
    let typeName: String
    let inheritedNames: [String]
    let file: String
    let line: Int
}

struct ComponentJudgeScanResult: Sendable {
    var textParams: [TextParamHit] = []
    var styleProtocols: [StyleProtocolDecl] = []
    var conformances: [ConformanceRecord] = []
    var styleSlots: [StyleSlotDecl] = []
    var styleEnums: [StyleEnumDecl] = []
    var styleEnumUses: [StyleEnumUse] = []
    var typeDeclFiles: [String: Set<String>] = [:]

    var isEmpty: Bool {
        self.textParams.isEmpty && self.styleProtocols.isEmpty
            && self.conformances.isEmpty && self.typeDeclFiles.isEmpty
    }

    var bareTextKeys: Set<String> { Set(self.textParams.filter { $0.kind == .bareText }.map(\.key)) }
    var localizedTextKeys: Set<String> { Set(self.textParams.filter { $0.kind == .localizedText }.map(\.key)) }
    var carryingKeys: Set<String> { Set(self.textParams.filter { $0.kind == .textCarrying }.map(\.key)) }

    var styleProtocolNames: Set<String> { Set(self.styleProtocols.map(\.name)) }

    var styleSlotKeys: Set<String> { Set(self.styleSlots.map(\.key)) }
    var styleEnumNames: Set<String> { Set(self.styleEnums.map(\.name)) }
    var styleEnumHosts: [String: Set<String>] {
        self.styleEnumUses.reduce(into: [:]) { $0[$1.enumName, default: []].insert($1.hostType) }
    }

    func conformers(of protocolName: String) -> Set<String> {
        Set(self.conformances.filter { $0.inheritedNames.contains(protocolName) }.map(\.typeName))
    }
}

// MARK: - 扫描入口 / Scan entry points

func scanComponentJudgeInputs(
    roots: [(target: String, url: URL)],
    sourceLocation: Testing.SourceLocation = #_sourceLocation
) throws -> ComponentJudgeScanResult {
    GuardScanRoots.assertRootsExist(roots)
    var result = ComponentJudgeScanResult()
    for root in roots {
        let one = try scanComponentJudgeInputs(root: root.url)
        if one.isEmpty {
            Issue.record("""
            扫描根 \(root.target)（\(root.url.path)）四个桶全空 —— 判据无法工作，这不是「零违规」。
            多根扫描最容易的假绿就是新根静默产出空集：合并之后主 target 的量把合计下界撑满，
            而这一根的源码**完全不受 J-2 / J-3 / FR-4 覆盖**。
            """, sourceLocation: sourceLocation)
        }
        result.merge(one)
    }
    return result
}

func scanComponentJudgeInputs(root: URL) throws -> ComponentJudgeScanResult {
    guard FileManager.default.fileExists(atPath: root.path) else {
        Issue.record("源码路径不存在：\(root.path) —— 判据无法工作，这不是「零违规」")
        return ComponentJudgeScanResult()
    }
    guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
        Issue.record("无法枚举源码目录：\(root.path)（权限或 IO 异常）—— 判据无法工作，这不是「零违规」")
        return ComponentJudgeScanResult()
    }
    var result = ComponentJudgeScanResult()
    let rootPrefix = root.lastPathComponent
    for case let url as URL in walker where url.pathExtension == "swift" {
        let name = rootPrefix + "/" + GuardScanRoots.relativePath(url, from: root)
        let tree = SwiftParser.Parser.parse(source: try String(contentsOf: url, encoding: .utf8))
        if tree.hasError {
            Issue.record("解析出错：\(name) —— swift-syntax major 可能与工具链不配套")
        }
        result.merge(collectComponentJudgeInputs(tree: tree, fileName: name))
    }
    return result
}

func scanComponentJudgeInputs(source: String, fileName: String = "Synthetic.swift") -> ComponentJudgeScanResult {
    collectComponentJudgeInputs(tree: SwiftParser.Parser.parse(source: source), fileName: fileName)
}

private func collectComponentJudgeInputs(tree: SourceFileSyntax, fileName: String) -> ComponentJudgeScanResult {
    let converter = SourceLocationConverter(fileName: fileName, tree: tree)
    let collector = ComponentJudgeCollector(fileName: fileName, converter: converter)
    collector.walk(tree)
    var result = ComponentJudgeScanResult()
    result.textParams = collector.textParams
    result.styleProtocols = collector.styleProtocols
    result.conformances = collector.conformances
    result.styleSlots = collector.styleSlots
    result.styleEnumUses = collector.styleEnumUses
    result.styleEnums = collector.styleEnums
    result.typeDeclFiles = collector.typeDeclFiles
    return result
}

extension ComponentJudgeScanResult {
    mutating func merge(_ other: ComponentJudgeScanResult) {
        self.textParams += other.textParams
        self.styleProtocols += other.styleProtocols
        self.conformances += other.conformances
        self.styleSlots += other.styleSlots
        self.styleEnumUses += other.styleEnumUses
        self.styleEnums += other.styleEnums
        for (name, files) in other.typeDeclFiles {
            self.typeDeclFiles[name, default: []].formUnion(files)
        }
    }
}

// MARK: - 采集器 / Collector

private nonisolated final class ComponentJudgeCollector: SyntaxVisitor {
    var textParams: [TextParamHit] = []
    var styleProtocols: [StyleProtocolDecl] = []
    var conformances: [ConformanceRecord] = []
    var styleSlots: [StyleSlotDecl] = []
    var styleEnumUses: [StyleEnumUse] = []
    var styleEnums: [StyleEnumDecl] = []
    var typeDeclFiles: [String: Set<String>] = [:]

    private let fileName: String
    private let converter: SourceLocationConverter

    private struct Frame {
        let name: String
        let isPublic: Bool
        let isPrivate: Bool
        let isInternal: Bool
        let isExtension: Bool
        var isProtocol: Bool = false
    }
    private var frames: [Frame] = []

    init(fileName: String, converter: SourceLocationConverter) {
        self.fileName = fileName
        self.converter = converter
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

    private var owner: String {
        self.frames.isEmpty ? "(top-level)" : self.frames.map(\.name).joined(separator: ".")
    }

    // MARK: 声明索引 / Declaration index

    private func inheritedNames(_ clause: InheritanceClauseSyntax?) -> [String] {
        (clause?.inheritedTypes ?? []).map {
            $0.type.trimmedDescription.split(separator: ".").last.map(String.init) ?? ""
        }
    }

    private func indexDecl(
        name: String, inheritance: InheritanceClauseSyntax?, at node: some SyntaxProtocol
    ) {
        self.typeDeclFiles[name, default: []].insert(self.fileName)
        let names = self.inheritedNames(inheritance)
        guard !names.isEmpty else { return }
        self.conformances.append(
            ConformanceRecord(
                typeName: name, inheritedNames: names, file: self.fileName,
                line: self.converter.location(for: node.positionAfterSkippingLeadingTrivia).line
            )
        )
    }

    // MARK: 容器帧

    private func pushType(_ name: String, _ modifiers: DeclModifierListSyntax, isProtocol: Bool = false) {
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
                isPrivate: a.priv, isInternal: a.int, isExtension: false, isProtocol: isProtocol
            )
        )
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        self.indexDecl(name: node.name.text, inheritance: node.inheritanceClause, at: node)
        self.pushType(node.name.text, node.modifiers); return .visitChildren
    }
    override func visitPost(_ node: StructDeclSyntax) { self.frames.removeLast() }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        self.indexDecl(name: node.name.text, inheritance: node.inheritanceClause, at: node)
        if self.isEffectivelyPublic(node.modifiers) {
            var cases: Set<String> = []
            for member in node.memberBlock.members {
                guard let decl = member.decl.as(EnumCaseDeclSyntax.self) else { continue }
                for element in decl.elements { cases.insert(element.name.text) }
            }
            self.styleEnums.append(
                StyleEnumDecl(
                    name: node.name.text, file: self.fileName,
                    line: node.startLocation(converter: self.converter).line, caseNames: cases
                )
            )
        }
        self.pushType(node.name.text, node.modifiers); return .visitChildren
    }
    override func visitPost(_ node: EnumDeclSyntax) { self.frames.removeLast() }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        self.indexDecl(name: node.name.text, inheritance: node.inheritanceClause, at: node)
        self.pushType(node.name.text, node.modifiers); return .visitChildren
    }
    override func visitPost(_ node: ClassDeclSyntax) { self.frames.removeLast() }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        self.indexDecl(name: node.name.text, inheritance: node.inheritanceClause, at: node)
        self.pushType(node.name.text, node.modifiers); return .visitChildren
    }
    override func visitPost(_ node: ActorDeclSyntax) { self.frames.removeLast() }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        self.indexDecl(name: node.name.text, inheritance: node.inheritanceClause, at: node)
        let hasMakeBodyRequirement = node.memberBlock.members.contains { member in
            guard let function = member.decl.as(FunctionDeclSyntax.self),
                  function.name.text == "makeBody" else { return false }
            let parameters = function.signature.parameterClause.parameters
            return parameters.count == 1 && parameters.first?.firstName.text == "configuration"
        }
        if hasMakeBodyRequirement {
            self.styleProtocols.append(
                StyleProtocolDecl(
                    name: node.name.text, file: self.fileName,
                    line: self.converter.location(for: node.positionAfterSkippingLeadingTrivia).line,
                    isPublic: Self.access(node.modifiers).pub,
                    nameHasStyleSuffix: node.name.text.hasSuffix("Style")
                )
            )
        }
        self.pushType(node.name.text, node.modifiers, isProtocol: true); return .visitChildren
    }
    override func visitPost(_ node: ProtocolDeclSyntax) { self.frames.removeLast() }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        var extended = node.extendedType.trimmedDescription
        if let angle = extended.firstIndex(of: "<") { extended = String(extended[..<angle]) }
        extended = extended.trimmingCharacters(in: .whitespaces)
        self.indexDecl(name: extended, inheritance: node.inheritanceClause, at: node)
        let a = Self.access(node.modifiers)
        self.frames.append(
            Frame(
                name: extended,
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
        self.collect(
            node.signature.parameterClause.parameters, decl: "init", modifiers: node.modifiers,
            generics: Self.stringProtocolGenericNames(node.genericParameterClause, node.genericWhereClause),
            isInitializer: true, at: node
        )
        self.collectStyleSlots(node)
        self.collectStyleEnumUses(node)
        return .skipChildren
    }

    private func collectStyleSlots(_ node: InitializerDeclSyntax) {
        guard let typeName = self.frames.last?.name else { return }
        guard self.isEffectivelyPublic(node.modifiers) else { return }
        for parameter in node.signature.parameterClause.parameters {
            let hasViewBuilder = parameter.attributes.contains { attribute in
                guard case let .attribute(attr) = attribute else { return false }
                return attr.attributeName.trimmedDescription == "ViewBuilder"
            }
            guard hasViewBuilder else { continue }
            let name = (parameter.firstName.text == "_"
                ? parameter.secondName?.text : parameter.firstName.text) ?? parameter.firstName.text
            let line = node.startLocation(converter: self.converter).line
            self.styleSlots.append(
                StyleSlotDecl(typeName: typeName, paramName: name, file: self.fileName, line: line)
            )
        }
    }

    private func collectStyleEnumUses(_ node: InitializerDeclSyntax) {
        guard let hostType = self.frames.last?.name else { return }
        guard self.isEffectivelyPublic(node.modifiers) else { return }
        let line = node.startLocation(converter: self.converter).line
        for parameter in node.signature.parameterClause.parameters {
            let base = componentJudgeBaseTypeName(parameter.type.trimmedDescription)
            guard !base.isEmpty else { continue }
            let name = (parameter.firstName.text == "_"
                ? parameter.secondName?.text : parameter.firstName.text) ?? parameter.firstName.text
            self.styleEnumUses.append(
                StyleEnumUse(
                    enumName: base, hostType: hostType, paramName: name,
                    file: self.fileName, line: line
                )
            )
        }
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        self.collect(
            node.signature.parameterClause.parameters, decl: node.name.text, modifiers: node.modifiers,
            generics: Self.stringProtocolGenericNames(node.genericParameterClause, node.genericWhereClause),
            isInitializer: false, at: node
        )
        self.collectStyleEnumUsesFromViewModifier(node)
        return .skipChildren
    }

    private func collectStyleEnumUsesFromViewModifier(_ node: FunctionDeclSyntax) {
        guard let frame = self.frames.last, frame.isExtension, frame.name == "View" else { return }
        guard self.isEffectivelyPublic(node.modifiers) else { return }
        guard let returnType = node.signature.returnClause?.type.trimmedDescription,
              returnType == "some View" else { return }

        let hostType = node.name.text
        let line = node.startLocation(converter: self.converter).line
        for parameter in node.signature.parameterClause.parameters {
            let base = componentJudgeBaseTypeName(parameter.type.trimmedDescription)
            guard !base.isEmpty else { continue }
            let name = (parameter.firstName.text == "_"
                ? parameter.secondName?.text : parameter.firstName.text) ?? parameter.firstName.text
            self.styleEnumUses.append(
                StyleEnumUse(
                    enumName: base, hostType: hostType, paramName: name,
                    file: self.fileName, line: line
                )
            )
        }
    }

    private static func stringProtocolGenericNames(
        _ clause: GenericParameterClauseSyntax?, _ whereClause: GenericWhereClauseSyntax?
    ) -> Set<String> {
        var names: Set<String> = []
        for parameter in clause?.parameters ?? [] {
            guard let inherited = parameter.inheritedType?.trimmedDescription else { continue }
            if Self.mentionsStringProtocol(inherited) { names.insert(parameter.name.text) }
        }
        for requirement in whereClause?.requirements ?? [] {
            guard let conformance = requirement.requirement.as(ConformanceRequirementSyntax.self) else { continue }
            if Self.mentionsStringProtocol(conformance.rightType.trimmedDescription) {
                names.insert(conformance.leftType.trimmedDescription)
            }
        }
        return names
    }

    private static func mentionsStringProtocol(_ text: String) -> Bool {
        text.split(separator: "&")
            .map { $0.trimmingCharacters(in: .whitespaces).split(separator: ".").last.map(String.init) ?? "" }
            .contains("StringProtocol")
    }

    private func collect(
        _ parameters: FunctionParameterListSyntax,
        decl: String,
        modifiers: DeclModifierListSyntax,
        generics: Set<String>,
        isInitializer: Bool,
        at node: some SyntaxProtocol
    ) {
        guard self.isEffectivelyPublic(modifiers) else { return }
        let line = self.converter.location(for: node.positionAfterSkippingLeadingTrivia).line
        for parameter in parameters {
            let name = (parameter.secondName ?? parameter.firstName).text
            let kind = classifyTextParameterType(
                parameter.type.trimmedDescription, stringProtocolGenerics: generics
            )
            guard kind != .notText else { continue }
            self.textParams.append(
                TextParamHit(
                    owner: self.owner, decl: decl, parameter: name, file: self.fileName,
                    line: line, kind: kind, isInitializer: isInitializer
                )
            )
        }
    }
}
