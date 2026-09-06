import Foundation
import SwiftParser
import SwiftSyntax
import Testing

// MARK: - public extension 成员的 nonisolated 显式性（Issue #271）

// ⚠️ **别把漏标 `nonisolated` 读成「下游会坏」**：`defaultIsolation` **推**出来的隔离
// 不进模块接口 ⇒ 跨模块（probe / 测试 target）看到的就是 nonisolated，不会红。
// 会红的只有**同模块**新增 nonisolated 读者的那一刻。（类型级 `nonisolated` 则**进**接口，
// 两者别混。逐条变异实测见 PR #271 正文。）
// ⇒ 本判据钉的是**显式性**：这个不一致收紧是兼容方向的改动，收紧那天没显式标的成员会
// 一次性变成下游破坏；且显式 `nonisolated` 是这条设计意图在 diff 与 symbol graph 里的唯一载体。

// 射程：只看 `pinnedMembers` 点名的文件。三种形态不覆盖，**失效方向不同** ——
// extension 级 `nonisolated`（`public nonisolated extension P { … }`）会**误报**，fail-closed；
// 嵌套类型的成员、元组模式存储属性是 **fail-open**：不进名单、也不查修饰符，漏标什么都不红。
// 更一般的替代方案：`scripts/api-surface-diff.sh` 比 `(usr, declAttributes)` 而 `nonisolated`
// 进 `declAttributes` ⇒ 接进 `ci.yml` 可覆盖全部 public 成员；它今天不在 CI 里，是独立改动。
@Suite("public extension 成员的 nonisolated 显式性")
struct ExtensionIsolationGuard {

    /// 受保护的文件 → 其 public extension 成员名。
    ///
    /// ⚠️ 本表是 `Set<String>` ⇒ **同名重载塌成一条**，删掉一对里的一个不会红。
    /// 只影响"数量"这一半，`nonisolated` 检查仍逐个成员跑。
    static let pinnedMembers: [String: Set<String>] = [
        "Sources/CoreDesignEffects/EffectsEnergy.swift": [
            "usesGlow", "particleScale", "frozenIfPeriodIsDegenerate",
        ],
    ]

    @Test("点名文件里 public extension 的成员必须逐个显式 nonisolated")
    func pinnedExtensionMembersAreExplicitlyNonisolated() throws {
        for (relative, expected) in Self.pinnedMembers {
            let url = GuardScanRoots.repoRoot.appendingPathComponent(relative)
            // ⚠️ **fail-closed**：文件不在就判红，不能"零成员 ⇒ 零违规 ⇒ 绿"。
            #expect(FileManager.default.fileExists(atPath: url.path),
                    "受保护的文件不存在：\(relative) —— 判据无法工作，这不是「零违规」")
            // 读失败也要判红：`else { continue }` 会让它落进绿色。
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
                ⚠️ 这**今天不会**让下游编译红（推出来的隔离不进模块接口，见本文件头那张变异表）\
                ⇒ 症状是：同模块哪天新增一个 nonisolated 读者才当场红，或编译器收紧这个不一致时\
                一次性变成下游破坏。显式标上，别让它悬着。
                """)
            }
        }
    }
}

/// 收集**公开的** extension 成员及其是否显式 `nonisolated`。
///
/// ⚠️ 四个收集条件各堵一种逃逸，改窄任一条都会开洞：
/// "公开"取 **extension 或成员任一带 `public`**；`#if` 的**所有**分支都要展开
///（要的是"源码里写了没有"，不是"这次编译进了哪支"）；
/// `var` / `func` / `subscript` / `init` 四种形态都收（`init` 的隔离正是下游构造时会撞上的）。
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
            // `#if` / `#else` 的每一支都要看进去。
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
