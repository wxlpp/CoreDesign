import Foundation
import Testing

@Suite("#72 G-8 续 —— 可达类型登记表")
struct ReachableTypeRegistryGuard {
    struct Entry: Codable {
        let type: String
        let repo: String
        let textParams: [TextParam]
    }

    struct TextParam: Codable {
        let name: String
        let category: String
        let notes: String
    }

    static var registryURL: URL {
        ComponentRegistryGuard.repoRoot.appendingPathComponent("docs/reachable-type-registry.json")
    }

    static func load() throws -> [Entry] {
        try JSONDecoder().decode([Entry].self, from: Data(contentsOf: registryURL))
    }

    static let placeholderNotes: Set<String> = ["TODO", "todo", "-", "—", "待补", "?", "？", "N/A"]

    nonisolated static let identifierPattern = "^[A-Za-z_][A-Za-z0-9_]*(\\.[A-Za-z_][A-Za-z0-9_]*)*$"

    nonisolated static func isValidIdentifier(_ s: String) -> Bool {
        s.range(of: Self.identifierPattern, options: .regularExpression) != nil
    }

    @Test("J1：schema 合法 —— type 唯一、repo 与 category 在允许域、notes 非占位")
    func schemaIsWellFormed() throws {
        let entries = try Self.load()
        try #require(!entries.isEmpty, "可达类型登记表读到 0 条 —— 加载失效，后面全是空集上的恒真")

        let untrimmedTypes = entries.map(\.type)
            .filter { $0 != $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        #expect(untrimmedTypes.isEmpty,
                "type 带首尾空白：\(untrimmedTypes.map { "「\($0)」" }) —— 会绕过重复检测，且按原串 grep 找不到")

        let badTypes = entries.map(\.type).filter { !Self.isValidIdentifier($0) }
        #expect(badTypes.isEmpty,
                "type 不是合法标识符：\(badTypes.map { "「\($0)」(\($0.unicodeScalars.map { "U+\(String(format: "%04X", $0.value))" }.joined(separator: " ")))" })")

        let types = entries.map { $0.type.trimmingCharacters(in: .whitespacesAndNewlines) }
        let dupTypes = Dictionary(grouping: types, by: { $0 }).filter { $0.value.count > 1 }.keys.sorted()
        #expect(dupTypes.isEmpty, "type 重复登记：\(dupTypes) —— 读者不知该信哪一条")

        for e in entries {
            #expect(!e.type.isEmpty, "有条目的 type 为空")
            #expect(ComponentRegistryGuard.validRepos.contains(e.repo),
                    "\(e.type) repo=\(e.repo) 不在允许域")
            #expect(!e.textParams.isEmpty,
                    "\(e.type) 的 textParams 为空 —— 空条目没有登记意义，应删掉整条")
            for p in e.textParams {
                #expect(ComponentRegistryGuard.validCategories.contains(p.category),
                        "\(e.type).\(p.name) category=\(p.category) 不在允许域")
                #expect(!p.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                        "\(e.type) 有参数的 name 为空 —— 空 name 在 PR-B 落地前四条判据全绿")
                #expect(Self.isValidIdentifier(p.name),
                        "\(e.type).\(p.name) 的 name 不是合法标识符：\(p.name.unicodeScalars.map { "U+\(String(format: "%04X", $0.value))" }.joined(separator: " "))")
                #expect(!p.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                        "\(e.type).\(p.name) 的 notes 为空 —— 逐条证据是本表的存在理由")
                #expect(!Self.placeholderNotes.contains(p.notes.trimmingCharacters(in: .whitespacesAndNewlines)),
                        "\(e.type).\(p.name) 的 notes 是占位符「\(p.notes)」")
            }
        }
    }

    @Test("J2：本表的 type 与组件登记表的 component 不相交")
    func typesDoNotCollideWithComponents() throws {
        let entries = try Self.load()
        try #require(!entries.isEmpty, "可达类型登记表读到 0 条 —— 加载失效")
        let components = Set(try ComponentRegistryGuard.loadRegistry().map(\.component))
        try #require(!components.isEmpty, "组件登记表读到 0 条 —— 加载失效")

        let collisions = Set(entries.map(\.type)).intersection(components).sorted()
        #expect(collisions.isEmpty, """
        同一个名字在两张表里都登记了：\(collisions)
        —— 读者不知该信哪一张，且「全集 = 两表并集」会重复计数。
        """)
    }

    @Test("J3：同一 type 内的参数名唯一")
    func paramNamesAreUniqueWithinType() throws {
        let entries = try Self.load()
        try #require(!entries.isEmpty, "可达类型登记表读到 0 条 —— 加载失效")

        for e in entries {
            let untrimmed = e.textParams.map(\.name)
                .filter { $0 != $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            #expect(untrimmed.isEmpty,
                    "\(e.type) 有参数名带首尾空白：\(untrimmed.map { "「\($0)」" }) —— 会绕过重复检测")

            let names = e.textParams.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
            let dup = Dictionary(grouping: names, by: { $0 }).filter { $0.value.count > 1 }.keys.sorted()
            #expect(dup.isEmpty, "\(e.type) 内参数名重复：\(dup)")
        }
    }

    @Test("J8：全部条目的 category 都是 C（并集规则的机器触发点）")
    func allEntriesAreCategoryC() throws {
        let entries = try Self.load()
        let allParams = entries.flatMap(\.textParams)
        try #require(!allParams.isEmpty,
                     "可达类型登记表拍平后 0 个参数（条目 \(entries.count) 条）—— 空集上全称量词恒真")

        let nonC = entries.flatMap { e in
            e.textParams.filter { $0.category != "C" }.map { "\(e.type).\($0.name)=\($0.category)" }
        }.sorted()

        #expect(nonC.isEmpty, """
        本表出现了非 C 条目：\(nonC)

        ⚠️ **这不只是一条断言失败，是一个动作指令。**
        本表落地时 43 条全是 C（「不迁移」），所以「只读 component-registry.json 的人
        会漏掉本表」在当时无实害。**出现第一条非 C 条目，那个前提就没了。**

        ⇒ 现在必须做的：
        1. 公约 G-8 行的**并集规则**从「今天无实害」升级为**强制**：
           凡是要枚举「StoryUI 文本参数全集」的工具（迁移器、审计脚本、判据），
           必须读 `component-registry.json` **与** `docs/reachable-type-registry.json` 的**并集**；
        2. 给本表补一条判据，核对上述并集读者确实读了两份；
        3. 若这条非 C 条目是有意的，把本判据从「全体为 C」放宽成新的取值域，
           并在 `docs/component-contract-revisions.md` 记一条修订 —— **不要直接删掉本判据**。
        """)
    }
}
