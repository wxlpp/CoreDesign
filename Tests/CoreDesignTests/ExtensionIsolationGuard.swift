import Foundation
import SwiftParser
import SwiftSyntax
import Testing

// MARK: - public extension 成员的 nonisolated 显式性（Issue #271）
//
// ## 它守什么：**显式性**，不是下游契约
//
// ⚠️⚠️ **先把不成立的那句话钉死**（`#271` 第 2 轮终审 I-1，评审有合成包实证）：
// 「漏标 `nonisolated` ⇒ 下游在非主 actor 语境用不了」**为假**。`defaultIsolation` 推出来的
// 隔离**不进模块接口**——`swift package dump-symbol-graph` 里未标记成员的 declaration
// fragments 上**没有任何属性**，显式标记的才带 `nonisolated` ⇒ 跨模块看到的就是 nonisolated，
// `downstream-probe` 的 `readEffectsPolicyKnobs()`（本身就是个 nonisolated 下游读者）照绿。
//
// ⚠️ **注意区分**：类型级 `nonisolated` **进**接口（拿掉 `EnergyState` 的 `nonisolated`，
// 库绿而 probe 红）。不进接口的只有 `defaultIsolation` **推**出来的那一档。
//
// ⇒ 漏标今天唯一可观测的后果是「**同模块**新增 nonisolated 读者时当场编译红」，而那是
// 编译器已经在守的东西。本判据钉的是**显式性**本身，理由有二，都不是"下游会坏"：
// · 这个不一致（同模块严、跨模块松）是编译器的现状，**收紧它是兼容方向的改动**，
//   哪天收紧了，没显式标的成员会一次性变成下游破坏；
// · 显式 `nonisolated` 在 diff 与 symbol graph 里都看得见，是这条设计意图的唯一载体。
//
// ## 逐条变异实测（Swift 6.3，`#271` 第 1 / 2 轮）
//
// | 去掉谁的 `nonisolated` | 库 `swift build` | `downstream-probe` | `--build-tests`（含 `@testable`） |
// |---|---|---|---|
// | `RenderPolicy.particleScale`（extension 成员） | 红（同模块读者 `ConfettiBurst.particleCount(baseParticleCount:policy:)`） | 红（同一条） | 红（同一条） |
// | `RenderPolicy.usesGlow`（extension 成员） | **绿** | **绿** | **绿** |
// | `MotionPresentation.frozenIfPeriodIsDegenerate(_:)`（extension 成员） | **绿** | **绿** | **绿** |
// | `RenderPolicy` **类型级** | 红（`Equatable` 一致性被卷进 MainActor） | 红 | 红 |
// | `MotionPresentation` **类型级** | 红（同上） | 红 | 红 |
// | `EnergyState` **类型级** | **绿** | **红**（`policy` 取不到） | — |
//
// ⇒ extension 成员这一档，编译器只在**同模块有 nonisolated 读者**时才红；
// `usesGlow` 与 `frozenIfPeriodIsDegenerate(_:)` 今天一个这样的读者都没有。
//
// ## 射程（如实登记）
//
// ⚠️ 本判据**只看 `pinnedMembers` 点名的文件**，不是"全仓所有 public extension"。后者要区分
// 「有意留在 MainActor 的 View 扩展」与「必须 nonisolated 的值类型扩展」，而那个区分今天
// 没有机器可读的依据 ⇒ 扩大射程会变成一张巨大的人工豁免表。
//
// ⚠️ **更一般的替代方案已登记、本轮有意未做**：`scripts/api-surface-diff.sh` 比较
// `(usr, declAttributes)`，而 `nonisolated` 以 attribute 形式进 `declAttributes`
// ⇒ 把那个脚本接进 `ci.yml` 能覆盖**全部** public 成员的隔离变化。它今天**不在** CI 里
//（`ci.yml` 只挂了 `mainactor-static-ratchet.sh`），接进去是独立改动。
//
// ⚠️ 同一个类型在**别的文件**里再开一个 extension，本判据看不见 —— 这也在射程之外。
@Suite("public extension 成员的 nonisolated 显式性")
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
            // ⚠️ **读不出来要判红，不能静默跳过**（第 2 轮终审 S-7）：`else { continue }`
            // 会让"文件在、但读失败"落进绿色。
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
/// ⚠️ **"公开"= extension 自身带 `public` **或** 成员自己带 `public`**：只看前者会漏
/// `extension P { public var knob }` 这一形态（`#271` 第 2 轮终审 I-4，评审有变异实证：
/// 四种形态一次注入，判据当时全绿）。
///
/// ⚠️ **`#if` 块必须递归展开**：`IfConfigDeclSyntax` 的成员不是 `MemberBlockItemList`
/// 的直接子节点，不展开的话把成员包进 `#if os(iOS)` 就整个逃逸。
/// 展开取**所有**分支（含 `#else`）—— 判据要的是"源码里写了没有"，不是"这次编译进了哪支"。
///
/// ⚠️ **四种成员形态都要收**：`var` / `func` / `subscript` / `init`。
/// `init` 尤其不能漏 —— extension 可以加 init，而它的隔离正是下游构造时会撞上的。
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
