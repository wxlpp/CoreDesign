import Foundation
import SwiftParser
import SwiftSyntax
import Testing

// MARK: - 跨模块 extension 成员的 nonisolated 契约（Issue #271）
//
// ## 为什么需要一条**源码**判据，而不是一个编译期读者
//
// 三个 target 都开了 `.defaultIsolation(MainActor.self)`，它**确实**作用于同包内类型的
// 扩展 ⇒ `extension RenderPolicy { var usesGlow }` 写在 `CoreDesignEffects` 里、不标
// `nonisolated`，就会被卷进 MainActor，下游在非主 actor 语境用不了。
//
// ⚠️⚠️ **这条契约没有任何编译期读者能跨模块守住**（`#271` 终审逐条变异实测，Swift 6.3）：
//
// | 去掉谁的 `nonisolated` | 库 `swift build` | `downstream-probe` | `--build-tests`（含 `@testable`） |
// |---|---|---|---|
// | `particleScale` | **红**（`Confetti.swift:443` 是同模块 nonisolated 读者） | 红（同一条） | 红（同一条） |
// | `usesGlow` | 绿 | **绿** | **绿** |
// | `frozenIfPeriodIsDegenerate(_:)` | 绿 | **绿** | **绿** |
//
// ⇒ 只有**同模块**的 nonisolated 读者会红；跨模块（probe / 测试 target）一律看不见。
// `particleScale` 恰好有一个同模块读者所以安全，另外两个**一个读者都没有**
// ——拿掉 `nonisolated` 全程静默，`api-surface-diff.sh` 也不在 `ci.yml` 里。
//
// ⚠️ **别拿"给它们各造一个读者"当解**：为守判据而在库里养一个没人用的 nonisolated 函数，
// 下一个人会当死代码删掉，且它守的是"今天这个读者还在"而不是"契约还在"。
//
// ## 射程（如实登记）
//
// 本判据**只看点名的这一个文件**，不是"全仓所有 public extension"。后者要区分
// 「有意留在 MainActor 的 View 扩展」与「必须 nonisolated 的值类型扩展」，
// 而那个区分今天没有机器可读的依据 ⇒ 扩大射程会变成一张巨大的人工豁免表。
@Suite("跨模块 extension 成员的 nonisolated 契约")
struct ExtensionIsolationGuard {

    /// 受本判据保护的文件，及其 `public extension` 里**必须**逐个显式 `nonisolated`
    /// 的成员名。⚠️ 数量与名字都钉死：删掉一个成员而不来改这里会判红。
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
            guard let source = try? String(contentsOf: url, encoding: .utf8) else { continue }

            let collector = PublicExtensionMemberCollector()
            collector.walk(Parser.parse(source: source))

            #expect(Set(collector.members.map(\.name)) == expected, """
            \(relative) 的 public extension 成员名单与实际不一致 —— \
            实际 \(collector.members.map(\.name).sorted())、登记 \(expected.sorted())。\
            新增成员必须来这里登记（否则它漏标 nonisolated 时没有任何东西会红）。
            """)

            for member in collector.members where !member.isNonisolated {
                Issue.record("""
                \(relative) 的 `\(member.name)` 没有显式 `nonisolated` —— \
                本 target 的 `.defaultIsolation(MainActor.self)` 会把它卷进 MainActor，\
                而这件事**跨模块看不见**（probe 与测试 target 都不会红），下游在非主 actor \
                语境取用时才发现。
                """)
            }
        }
    }
}

/// 收集 `public extension` 块里的 `var` / `func` 成员及其是否显式 `nonisolated`。
private nonisolated final class PublicExtensionMemberCollector: SyntaxVisitor {

    struct Member { let name: String; let isNonisolated: Bool }

    private(set) var members: [Member] = []

    init() { super.init(viewMode: .sourceAccurate) }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard node.modifiers.contains(where: { $0.name.text == "public" }) else { return .skipChildren }
        for item in node.memberBlock.members {
            if let v = item.decl.as(VariableDeclSyntax.self) {
                let isNonisolated = v.modifiers.contains { $0.name.text == "nonisolated" }
                for binding in v.bindings {
                    guard let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
                    else { continue }
                    self.members.append(Member(name: name, isNonisolated: isNonisolated))
                }
            } else if let f = item.decl.as(FunctionDeclSyntax.self) {
                self.members.append(Member(name: f.name.text,
                                           isNonisolated: f.modifiers.contains { $0.name.text == "nonisolated" }))
            }
        }
        return .skipChildren
    }
}
