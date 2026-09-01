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

    /// `type` / `name` 的**白名单**：Swift 标识符，允许 `.` 分隔的嵌套路径
    /// （现有 3 条嵌套名 `AgentTodoItem.Status` / `OutlineNodeState.Kind` / `StoryTypography.Size`）。
    ///
    /// ⚠️ **为什么是白名单而不是再加一批黑名单字符**（`#216` 终审第 3 轮 I-1）：
    /// 上一版靠「拒绝首尾空白」挡绕过，但 `.whitespacesAndNewlines` 的域**只有空白** ——
    /// **Unicode Cf 类（ZWNJ `U+200C` / ZWJ `U+200D` / BOM `U+FEFF`）三连绕过**：
    /// `"ChapterCardState\u{200D}"` 既过得了空白检查，又与 `"ChapterCardState"` **算两个 key**
    /// ⇒ J1 唯一性、J2 两表相交、J3 参数名唯一性**三条同时失明**
    /// （⚠️ 且这次 J1 **不会**像空白场景那样替 J2 顶班判红 —— Cf 场景是**全绿**）。
    ///
    /// ⚠️ **这正是台账 N5/N6 段自己写下的那个问句没答完**：
    /// 「**什么字符**会让它看起来合规而实际不是」—— 我只答了空白那一半。
    /// 黑名单要穷举「所有看起来像空的字符」，白名单只需说清「什么是合法的」。**后者才收敛。**
    /// ⚠️ 实测对现有 **20 条 type + 43 条 name 零首跑红**（定规则前对着真实数据跑过，同 J1 的 notes 那条教训）。
    ///
    /// ⚠️ **已知误红边界**（`#216` 终审第 4 轮 S-1）：`Optional<Foo>` / `[String]` / 非 ASCII 标识符
    /// （如中文类型名）都会被本白名单**拒绝** —— 它们是合法的 Swift 写法。
    /// 失效方向 **loud**（会红、失败信息逐字打码点），可接受；
    /// **届时的动作是放宽 pattern 并在 `docs/component-contract-revisions.md` 记一条修订**，
    /// 不是直接删断言。写在这里，免得第一个撞上的人以为撞的是 bug。
    nonisolated static let identifierPattern = "^[A-Za-z_][A-Za-z0-9_]*(\\.[A-Za-z_][A-Za-z0-9_]*)*$"

    nonisolated static func isValidIdentifier(_ s: String) -> Bool {
        s.range(of: Self.identifierPattern, options: .regularExpression) != nil
    }

    // ⚠️ 下面三处 trim 用 `.whitespacesAndNewlines`，**不是 `.whitespaces`**（`#216` Copilot）：
    //    Swift 的 `.whitespaces` **不含换行** ⇒ notes 误写成 `"\n"` 或 `" \n"` 时，
    //    「非空」与「不在占位黑名单」两条**都会被绕过** —— 判据静默转绿。

    @Test("J1：schema 合法 —— type 唯一、repo 与 category 在允许域、notes 非占位")
    func schemaIsWellFormed() throws {
        let entries = try Self.load()
        try #require(!entries.isEmpty, "可达类型登记表读到 0 条 —— 加载失效，后面全是空集上的恒真")

        // ⚠️ **先拒绝首尾空白，再用规范化值去重**（`#216` Copilot 第 2 轮，两条 suppressed）：
        //    只查 `isEmpty` + 拿**原串**去重时，`"ChapterCardState "` 既过得了非空、
        //    又跟 `"ChapterCardState"` **算成两个不同的 key** ⇒ **重复检测被绕过**。
        //    ⚠️ 这里**拒绝**而不是**静默规范化** —— 登记表 key 上的首尾空白本身就是缺陷，
        //    规范化会把它藏起来（下次有人按原串查就找不到）。与 `notes` 那条换行假绿同族。
        let untrimmedTypes = entries.map(\.type)
            .filter { $0 != $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        #expect(untrimmedTypes.isEmpty,
                "type 带首尾空白：\(untrimmedTypes.map { "「\($0)」" }) —— 会绕过重复检测，且按原串 grep 找不到")

        // ⚠️ **白名单才收敛**：空白检查只挡空白，Cf 类（ZWNJ/ZWJ/BOM）会三连绕过。见 `identifierPattern`。
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
            // ⚠️ 同上：`"title"` 与 `"title "` 会被当成两个 ⇒ 重复检测绕过。
            let untrimmed = e.textParams.map(\.name)
                .filter { $0 != $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            #expect(untrimmed.isEmpty,
                    "\(e.type) 有参数名带首尾空白：\(untrimmed.map { "「\($0)」" }) —— 会绕过重复检测")

            let names = e.textParams.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
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
