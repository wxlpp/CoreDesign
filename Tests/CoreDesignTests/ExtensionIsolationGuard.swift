import Foundation
import SwiftParser
import SwiftSyntax
import Testing

// MARK: - public extension 成员的 nonisolated 显式性（Issue #271）

@Suite("public extension 成员的 nonisolated 显式性")
struct ExtensionIsolationGuard {
    static let pinnedMembers: [String: Set<String>] = [
        "Sources/CoreDesignEffects/EffectsEnergy.swift": [
            "usesGlow", "particleScale", "frozenIfPeriodIsDegenerate",
        ],
    ]

    @Test("点名文件里 public extension 的成员必须逐个显式 nonisolated")
    func pinnedExtensionMembersAreExplicitlyNonisolated() throws {
        for (relative, expected) in Self.pinnedMembers {
            let url = GuardScanRoots.repoRoot.appendingPathComponent(relative)
            #expect(FileManager.default.fileExists(atPath: url.path),
                    "受保护的文件不存在：\(relative) —— 判据无法工作，这不是「零违规」")
            let source: String
            do { source = try String(contentsOf: url, encoding: .utf8) } catch {
                Issue.record("受保护的文件读取失败：\(relative)（\(error)）—— 判据无法工作")
                continue
            }

            let collector = PublicExtensionMemberCollector()
            collector.walk(Parser.parse(source: source))

            #expect(Set(collector.members.map(\.name)) == expected, """
            \(relative) 的 public extension 成员名单与实际不一致 —— \
            实际 \(collector.members.map(\.name).sorted())、登记 \(expected.sorted())。\
            新增成员必须来这里登记 —— 否则它漏标 `nonisolated` 时没有任何东西会红。
            """)

            for member in collector.members where !member.isNonisolated {
                Issue.record("""
                \(relative) 的 `\(member.name)` 没有显式 `nonisolated` —— \
                本 target 的 `.defaultIsolation(MainActor.self)` 会把它卷进 MainActor。\
                ⚠️ 这**今天不会**让下游编译红（`defaultIsolation` 推出来的隔离不进模块接口）\
                ⇒ 症状是：同模块哪天新增一个 nonisolated 读者才当场红，或编译器收紧这个不一致时\
                一次性变成下游破坏。显式标上，别让它悬着。
                """)
            }
        }
    }
}

private nonisolated final class PublicExtensionMemberCollector: SyntaxVisitor {
    struct Member { let name: String; let isNonisolated: Bool }

    private(set) var members: [Member] = []

    init() { super.init(viewMode: .sourceAccurate) }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        let extensionIsPublic = node.modifiers.contains { $0.name.text == "public" }
        self.collect(node.memberBlock.members, extensionIsPublic: extensionIsPublic)
        return .skipChildren
    }

    private func collect(_ items: MemberBlockItemListSyntax, extensionIsPublic: Bool) {
        for item in items {
            if let ifConfig = item.decl.as(IfConfigDeclSyntax.self) {
                for clause in ifConfig.clauses {
                    if let nested = clause.elements?.as(MemberBlockItemListSyntax.self) {
                        self.collect(nested, extensionIsPublic: extensionIsPublic)
                    }
                }
                continue
            }
            guard let decl = item.decl.asProtocol(WithModifiersSyntax.self) else { continue }
            let isPublic = extensionIsPublic || decl.modifiers.contains { $0.name.text == "public" }
            guard isPublic else { continue }
            let isNonisolated = decl.modifiers.contains { $0.name.text == "nonisolated" }

            if let v = item.decl.as(VariableDeclSyntax.self) {
                for binding in v.bindings {
                    guard let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
                    else { continue }
                    self.members.append(Member(name: name, isNonisolated: isNonisolated))
                }
            } else if let f = item.decl.as(FunctionDeclSyntax.self) {
                self.members.append(Member(name: f.name.text, isNonisolated: isNonisolated))
            } else if item.decl.is(SubscriptDeclSyntax.self) {
                self.members.append(Member(name: "subscript", isNonisolated: isNonisolated))
            } else if item.decl.is(InitializerDeclSyntax.self) {
                self.members.append(Member(name: "init", isNonisolated: isNonisolated))
            }
        }
    }
}
