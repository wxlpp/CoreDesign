import Foundation
import Testing

/// `#72`（G-8 续）的「可达类型登记表」判据。
///
/// ## 这张表为什么单独一个文件
///
/// `#67` 的参数级扫描器把 FR-4 的定义域扩到**结构可达性传递闭包**，深度 ≥ 1 有 43 条文本参数，
/// 但它们**没有登记落点** —— `component-registry.json` 的 `textParams` 挂在**组件条目**上，
/// 而 `ChapterCardState` / `CodexEntry` / `AgentTodoItem` 这些**不是登记表条目**。
///
/// 四种形态里选了「新开一份文件」（`#72` spec §2），主要因为另外三条各有硬伤：
/// 往 `component-registry.json` 加同构条目会**语义错配**（9 个固定字段里 `kind` /
/// `decidedBy` / `nativeProtocol` / `needsExtensionPoint` 对值类型无意义）**且两仓判据连环红**；
/// 顶层改对象会破坏两仓所有 loader；把参数用限定名挂到「可达到该类型的组件」上会**挂靠歧义**
/// （`StoryReadingTheme` 被三个 manuscript 组件的 public init **各自直接持有**）。
///
/// ⚠️ **代价要说出来**：从此「StoryUI 文本参数全集 = **两文件的并集**」，
/// 而**没有任何判据强制未来的读者做并集**。今天 43 条全是 C /「不迁移」所以漏读无实害；
/// 但**将来任何一条深度 ≥1 的 B 类落进本文件后**，只读 `component-registry.json` 的迁移工具
/// 会**静默漏掉它**。⇒ 这一面的**机器触发点是 `allEntriesAreCategoryC` 判红**（见该判据）。
///
/// ⚠️ **本表没有 `reachableFrom` 字段**（`#72` plan 裁决 A）。spec 前三稿设计过它
/// （可达到该类型的登记组件），推翻它的**主要理由不是成本，是数据性质**：
/// 「哪些组件可达该类型」是**扫描器按需可重算的派生数据**，登记进去只会漂移
/// （重构换了持有者 ⇒ 字段成假话，而「指针不悬空」的判据照样绿）；
/// 而 `notes` 是**不可重算的人判证据**，所以留。
/// **次要理由**才是成本：守住它要么逐种子跑 25 次扫描（一次 ≈ 2s ⇒ ≈ 50s），
/// 要么改 `wxlpp/oh-my-story#74` 点名「提交态零覆盖」的那台机器。
/// ⇒ **派生数据不登记**；「守不住」是佐证，不是理由本身。
/// 组件删除导致孤儿条目的方向由 story 侧 J5 的 `onlyInRegistry` 接住。
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

    /// `notes` 的占位黑名单。
    ///
    /// ⚠️ **不用长度阈值**（`#72` spec 评审 C1）：`component-registry.json` 那条是
    /// `notes.count >= 10`，而本表 43 条里**有 7 条短于 10 字符**
    /// （最短 6：`ChapterCardState.summary` 的「用户手稿内容」）⇒ 照抄会**首跑即红**，
    /// 逼人要么改 notes（击穿「纯搬运」前提）、要么当天降阈值
    /// （**判据落地当天就被现实削弱**）。**定阈值前必须对着真实数据跑一遍。**
    static let placeholderNotes: Set<String> = ["TODO", "todo", "-", "—", "待补", "?", "？", "N/A"]

    // ⚠️ 下面三处 trim 用 `.whitespacesAndNewlines`，**不是 `.whitespaces`**（`#216` Copilot）：
    //    Swift 的 `.whitespaces` **不含换行** ⇒ notes 误写成 `"\n"` 或 `" \n"` 时，
    //    「非空」与「不在占位黑名单」两条**都会被绕过** —— 判据静默转绿。

    @Test("J1：schema 合法 —— type 唯一、repo 与 category 在允许域、notes 非占位")
    func schemaIsWellFormed() throws {
        let entries = try Self.load()
        try #require(!entries.isEmpty, "可达类型登记表读到 0 条 —— 加载失效，后面全是空集上的恒真")

        let types = entries.map(\.type)
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
            let names = e.textParams.map(\.name)
            let dup = Dictionary(grouping: names, by: { $0 }).filter { $0.value.count > 1 }.keys.sorted()
            #expect(dup.isEmpty, "\(e.type) 内参数名重复：\(dup)")
        }
    }

    /// ⚠️ **定义域是「全部条目」，不是「深度 ≥ 1 的条目」**（`#72` spec 评审 I1）：
    /// 后者会诱导实现者拿扫描器算深度再过滤 —— **扫描器坏掉时过滤集为空、全称量词恒真**。
    /// ⚠️ **别写「J2 保证了全部条目天然深度 ≥ 1」**（`#216` 终审 I-2）：J2 只排除了
    /// **深度 0 的组件条目**，**不保证可达** —— 往本文件编造一条不可达的幽灵类型
    /// （配一条 C + 像样的 notes），J1/J2/J3/J8 **四条全绿**。
    /// **可达性由 story 侧的双向差集（`onlyInRegistry` 方向）承接，而它要到 PR-B 才存在**
    /// ⇒ PR-A → tag → PR-B 之间有一个窗口期无人守。
    /// 对 J8 本身无实害（在超集上做全称断言是保守方向），但那句话是**写在三处的假全称**。
    ///
    /// ⚠️ **它守的是哪一半**：挡「悄悄改成非 C」，**挡不了「非 C 被误登记成 C」**（A 同样挡不了）。
    ///
    /// ⚠️ **而激励梯度指向它守不住的那一半**（`#216` 终审 I-3）：真出现深度 ≥1 的 B 类参数时，
    /// 诚实写 B ⇒ 本判据红 + 下面 message 要求做三件重活；谎报写 C ⇒ **四条判据全绿、机器不可见**。
    /// **本判据抬高了诚实路径的成本。** 唯一的对冲在 J1：`notes` 必须非空非占位
    /// ⇒ 谎报 C 必须**编造一条 C 的证据**，那是**人审可核**的。
    /// ⇒ **误登记成 C 的唯一防线是 notes 证据 + 人审**，不是机器。别指望本判据。
    /// 这不是「category 被独立校验」——扫描器只产出**参数名**，category 是人判的、源码里不存在
    /// ⇒ 拿 registry 去比 registry 就是**同源恒真**。本判据是把**取值域**钉死。
    @Test("J8：全部条目的 category 都是 C（并集规则的机器触发点）")
    func allEntriesAreCategoryC() throws {
        let entries = try Self.load()
        // ⚠️ **非退化前置要到「参数」级，不能只到「条目」级**（`#216` 终审 Suggestion）：
        //    条目非空但每条 `textParams` 都是 `[]` 时，下面的全称断言仍是**空集上恒真**，
        //    只能靠 J1 的 `!textParams.isEmpty` 顶班 —— 与 spec 自己禁止的「靠别的判据兜空集」
        //    是同一形态、小一号。⇒ 直接对拍平后的参数总数 require。
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
