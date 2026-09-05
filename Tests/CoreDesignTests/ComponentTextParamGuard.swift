import Foundation
import Testing

@Suite("FR-4 文本参数分类覆盖")
struct ComponentTextParamGuard {

    /// 宿主类型 → 登记表条目名。
    ///
    /// ⚠️ **这不是白名单，是「登记单位 = 组件」与「声明单位 = 类型」之间的翻译表**
    /// （公约 AD-2：登记单位是组件，而一个组件的 public 表面可以由多个类型组成）。
    /// 每一条都由登记表自己的 `notes` 或 `textParams` 名字佐证：
    /// - `ToastItem` / `ToastHost` → `Toast`：`Toast` 条目的 notes 原文
    ///   「ToastItem.message / ToastHost.show(_:level:duration:) 的 message 均为裸 String」。
    /// - `RadioOption` → `RadioGroup`：`RadioGroup` 的 textParams 名字就是 `RadioOption.title`。
    /// - `StepItem` → `Steps`：同上，名字是 `StepItem.title` / `StepItem.description`。
    /// - `SegmentedControlStyleConfiguration.Segment` → `SegmentedControl`：该条目 notes 原文
    ///   「`SegmentedControlStyleConfiguration.Segment.title` 是同一份文本经组件内部转交给
    ///   style 实现者的镜像字段……不重复计入 textParams」。
    /// ⚠️ **表长本身是负债信号**：新条目落进来时，先问「登记表能不能直接以这个类型名登记」，
    /// 答不出来才加翻译条目。现状 5 条，由下面的 `ownerAliasesAreLoadBearing` 断言钉住
    /// ——每一条都必须真的被源码里的某个命中用到，否则就是过期条目。
    static let ownerAliases: [String: String] = [
        "ToastItem": "Toast",
        "ToastHost": "Toast",
        "RadioOption": "RadioGroup",
        "StepItem": "Steps",
        "SegmentedControlStyleConfiguration.Segment": "SegmentedControl",
    ]

    /// FR-4 的**已知违规**：裸文本参数没有分类条目，登记表 `notes` 也没点名它。
    ///
    /// ⚠️ **这四条是 #38 的登记缺口，不是 FR-4 的判据 bug**：`LabelIcon` 的 `notes` 已经
    /// 为同一类参数（SF Symbol 标识符）写过裁决——「systemName 是符号标识符不是展示文案，
    /// 不计入 textParams」——但四条 Sidebar row 的 `systemImage` / `trailingSystemImage`
    /// 在各自 `notes` 里**零提及**（实测：三条 notes 里 `systemImage` 子串命中数均为 0）。
    /// **正确修法是在这些 notes 里补一句**（成本一句话），承接
    /// **`wxlpp/oh-my-story#51`** —— 原写作「回 #38 补」，但 **#38 已 CLOSED**，往已关闭的
    /// issue 移交等于移交蒸发；#51 的标题就是「原『#38 本位』，但 #38 已关闭」。不是在判据里硬编码
    /// 特例、更不是把它们塞进 `textParams` 当成文案分类（那会把 SF Symbol 标识符错记成
    /// 界面文案）。缺陷报告见 Task 12。
    static let knownUnregisteredSymbolParams: Set<String> = [
        "SidebarDocumentRow.init#systemImage",
        "SidebarNavigationRow.init#systemImage",
        "SidebarUtilityRow.init#systemImage",
        "SidebarUtilityRow.init#trailingSystemImage",
    ]

    /// 宿主不对应任何登记表条目的**`init`** 裸文本参数（判据定义域之外），实测两条。
    ///
    /// - `Color.init#text`：`extension Color` 上的便利 init，`text` 是**取色种子**
    ///   （对字符串做哈希选一个预置色），不是界面文案；`Color` 是 SwiftUI 的类型，不是本仓组件。
    /// - `SettingsRowIcon.init#systemName`：`public struct SettingsRowIcon: Sendable`
    ///   ——不是 `View`/`ViewModifier`，按公约 AD-2 与 #38 的登记单位不进登记表。
    ///
    /// ⚠️ `View.bottomInputBar#placeholder` **不在本集合里**——它是 `func` 上的参数，
    /// 在规则里先被 `functionSideBareText` 那道分支接走（分桶发生在宿主解析之前）。
    /// 它同样有固定集合断言盯着，见 `publicInitTextParamsAreClassified` 里的 func 侧断言。
    static let knownUnmappedOwnerParams: Set<String> = [
        "Color.init#text",
        "SettingsRowIcon.init#systemName",
    ]

    /// `func`（非 `init`）上的裸文本参数：AC 只点名 `init`，本桶是**留痕**不是判据。
    ///
    /// - `ToastHost.show#message`：与 `ToastItem.init#message` 是同一份文案的两个入口，
    ///   登记表 `Toast.message` 已覆盖（notes 原文点名了两者）。
    /// - `View.bottomInputBar#placeholder`：`BottomInputBar` 被公约 AD-2 **显式排除**出
    ///   登记表（`struct BottomInputBar: View` 没有 `public` 修饰符，唯一暴露面是
    ///   `public extension View` 上的 modifier 函数）⇒ 没有可对账的条目。
    ///   ⚠️ **公约 §A.2 旧句称它「已移交 39.md（J-1/FR-4）」——那句对 FR-4 不成立**：
    ///   #39 只做了 J-1（Bool），FR-4 落地后它**仍然没有任何机器判据给它分类**。
    ///   Task 12 修正该句，处置移交 #41/#42。
    /// ⚠️ **`#270` 新增第三条 `View.spray#symbol`**：扫描根扩到 `Sources/CoreDesignEffects`
    /// 之后，`View.spray(trigger:symbol:strength:colors:)` 这个公开 modifier 第一次进入
    /// FR-4 的视野。它是 `func` 侧参数 ⇒ 与另外两条一样落本留痕桶，不进主判据。
    /// ⚠️ **它的内容是 SF Symbol 标识符，不是界面文案** —— 与 `LabelIcon.systemName`
    /// 同类（公约 §4「点名收编：编译期符号名」）。本桶只留痕、不裁决；真要裁决它算不算
    /// 文案，落点是把 FR-4 的定义域从 `init` 扩到 `func`，那是独立一块工程，不在 `#270` 射程内。
    static let knownFunctionSideBareText: Set<String> = [
        "ToastHost.show#message",
        "View.bottomInputBar#placeholder",
        "View.spray#symbol",
    ]

    /// 单条条目的「散文 ⟂ 数据」判定。返回 `nil` 表示无矛盾。
    ///
    /// ⚠️ **抽成纯函数是为了让 fixture 能进 CI** —— 见 `proseDataJudgeCatchesRealIncidents`：
    /// 判据在**提交态的真实条目上活体命中 0**（数据是自洽的，判据自然沉默），
    /// 于是「把措辞表整个删掉」在**本判据刚落地时**测不出来（变异 A6g 当时实测全绿）。
    /// ⚠️ **那是过去式** —— 现已由下面的 `proseDataJudgeCatchesRealIncidents` 与
    /// `claimTablesMatchPinnedSets` 接住，同一变异现在判红。
    /// 这与 `wxlpp/oh-my-story#74` 是同一种「机器在提交态零覆盖」。⇒ 用 fixture 钉住。
    nonisolated static func contradiction(notes: String, hasParams: Bool) -> String? {
        let live = strippingRetractions(notes)
        if hasParams, let c = absenceClaims.first(where: { live.contains($0) }) {
            return "登记了 textParams，notes 却写着「\(c)」——散文与数据自相矛盾"
        }
        if !hasParams, let c = presenceClaims.first(where: { live.contains($0) }) {
            return "textParams 是空的，notes 却写着「\(c)」——散文与数据自相矛盾"
        }
        return nil
    }

    /// 剥掉 notes 里的**撤回句**再判 —— 台账是 add-only，改写一条结论要**复述被推翻的旧话**
    /// （⚠️ 两种形态，终审 S-2：`上句原写「X」` = **逐字引原串**；`上句原判**X**` = **转述那条裁定**。
    ///  本表两个标记都收，因为**两种都会把旧命题带回文本里**、都需要被剥。
    ///  ⚠️ 别把下面例子里的 `该参数不进本表` 当逐字原文 —— 真正被撤回的原串是
    ///  `不落入 textParams 的 A/B/C 三分法`，那句才是逐字的。）
    /// （「上句原判**该参数不进本表**，已由 #67 推翻」），而纯子串判据**分不清引述与断言**：
    /// 初版就把这三条留痕全判成了违规。
    ///
    /// 规则：按句号切分，**丢掉含撤回标记的整句**，只在剩下的话里找矛盾。
    /// ⚠️ **已知盲区之二**（终审 I-2）：`ManuscriptReader` / `StoryTextView` 的「登记为 C」
    /// **只出现在撤回句里** ⇒ 被剥掉 ⇒ 把它们的 `textParams` 改回 `[]`，本判据**静默**
    /// （只有 `ManuscriptEditor` 会响，它的 notes 已改成直述）。那个方向由
    /// `expectedStoryuiTextParams` 的集合相等接住，**不是无人守**，但要知道**不是这条守的**。
    ///
    /// ⚠️ **已知盲区**：真正的假断言若与撤回标记**同处一句**则逃逸。接受它——
    /// 反方向（把留痕判成违规）会逼人删掉留痕，那是**用篡改记录换绿**，代价大得多。
    nonisolated static func strippingRetractions(_ notes: String) -> String {
        notes.split(separator: "。").filter { sentence in
            !retractionMarkers.contains { sentence.contains($0) }
        }.joined(separator: "。")
    }

    /// 撤回句的标记词。
    nonisolated static let retractionMarkers = ["原判", "上句原写", "推翻", "已作废"]
    /// notes 里「本条目**没有** textParams」这一意思的措辞枚举。
    /// ⚠️ 枚举而非语义识别 —— 同义换词会逃，这是已知边界，不是没想到。
    ///
    /// ⚠️ **措辞之间不得有子串包含关系** —— 初版把「无 textParams」放进本表，而
    /// 「不**等于**无 textParams」（一句**肯定**有条目的话）含它作子串 ⇒ 判据当场自造一条误报。
    /// 加判据前先跑 `absenceClaims` 两两互查与 `presenceClaims` 交叉互查。
    nonisolated static let absenceClaims = [
        "不落入 textParams", "不进本表", "没有 textParams 条目", "无 textParams 条目",
        // ⚠️ **补于终审 C-1**：这一句才是本 PR 真实事故的措辞（`ManuscriptEditor` 的 notes
        //    **以它收尾、后面什么都没有**）
        //    ⚠️ 初版这里写「用它开头、靠下一句转折兜住」—— 那是 **`SuggestionStream`** 的形态
        //    （「…无裸 String 展示参数。⚠️ 但**不等于无 textParams**：…」）。**把两个组件搞混了**，
        //    而这正是本 PR 第 1 条事故（改 notes 改到别的组件上）本身。。初版表里**没有它** ⇒ 判据在自己写来防的那棵事故树上是绿的。
        "无裸 String 展示参数",
    ]

    /// notes 里「本条目**登记了** textParams」这一意思的措辞枚举。
    /// ⚠️ **收敛到最短形**（终审 C-1）：初版写「已登记为 C 类」，而真实事故的措辞是
    /// 「…的 C 行**登记为 C**（用户手稿正文）」——**不含「已」「类」** ⇒ 不命中。
    nonisolated static let presenceClaims = ["登记为 C", "登记为 B"]

    /// ⚠️ **本 PR 真实事故的回放 fixture** —— 不是构造的假设。
    ///
    /// `#67` 在改 registry 的过程中**连犯三条**「散文与数据矛盾」，两轮外部评审各抓一次。
    /// 上面那条判据是为它们写的，但**在提交态永远沉默**（真实数据自洽）⇒ 删掉措辞表也测不出。
    /// 这里把三条事故的**逐字措辞**钉成 fixture（⚠️ 逐字 = 从事故树 `git show` 出来的原串；
    /// 终审 C-2 查出初版三条里**只有一条**真逐字：r1 把 `文本以` 写成了 `text 以`（那是**另一棵树**
    /// 的开头，尾巴又是第一棵的）、r2b 漏掉中段括号 —— 回放 fixture 的全部权威就在**逐字**，
    /// 拼接出来的串会造出新的假绿通道）。
    ///
    /// ⚠️ **别写成「措辞表退化，本测试立刻红」** —— 那是个假的全称（终审 I-1）：
    /// 上面三条只钉住 `absenceClaims` / `presenceClaims` 里的**三条**串，
    /// 其余四条（`不进本表` / `没有 textParams 条目` / `无 textParams 条目` / `登记为 B`）
    /// **逐条删掉都全绿**（⚠️ **那是本测试落地前的实测**；现在逐条删都判红）。⇒ 下面 `claimTablesMatchPinnedSets` 把它们**逐条**钉住。
    ///
    /// 逐字出处：`422055b`（第 1 轮）与 `e9f42ee`（第 2 轮）的 `docs/component-registry.json`。
    @Test("散文 ⟂ 数据判据必须抓得住 #67 真实发生过的三条矛盾")
    func proseDataJudgeCatchesRealIncidents() {
        // 第 1 轮（`422055b`）：登记了 C 类条目，notes 仍说「不落入三分法」。
        #expect(Self.contradiction(
            notes: "文本以 AttributedString 承载，不落入 textParams 的 A/B/C 三分法（该判据面向 String/LocalizedStringKey/Resource 类型的展示文案参数）。",
            hasParams: true) != nil, "第 1 轮事故（ManuscriptReader / StoryTextView 形态）逃逸")

        // 第 2 轮（`e9f42ee`）之一：改错了组件 —— 空 textParams 却被安上「登记为 C」。
        #expect(Self.contradiction(
            notes: "组件自身 init 无裸 String 展示参数。⚠️ 但**不等于无 textParams**：text 是 AttributedString，由 #67 起按公约 §4 的 C 行登记为 C（用户手稿正文）。",
            hasParams: false) != nil, "第 2 轮事故（SuggestionStream 形态）逃逸")

        // 第 2 轮之二：真正的目标一字未动 —— 登记了条目，notes 仍以缺席措辞开头。
        #expect(Self.contradiction(
            notes: "理由同 ManuscriptReader：步骤 1 无，步骤 3 视觉即含义（外观完全由 typography/theme 值参数化，组件自身无独立可换皮表面）。无裸 String 展示参数。",
            hasParams: true) != nil, "第 2 轮事故（ManuscriptEditor 形态）逃逸")

        // ⚠️ **反向**：撤回句里复述旧话**不得**判红，否则会逼人删掉 add-only 留痕换绿。
        #expect(Self.contradiction(
            notes: "text 以 AttributedString 承载。⚠️ 上句原判**该参数不进本表**，已由 #67 推翻。",
            hasParams: true) == nil, "撤回留痕被误判为活体断言")
    }

    /// ⚠️ **措辞表的每一条都要被独立钉住**（终审 I-1）：整表清空（变异 A6g）会红，
    /// 但**逐条删除**在提交态是**静默**的 —— 而逐条退化才是现实中的回归形态。
    ///
    /// ⚠️ **初版这条测试是同义反复**：写的是 `for claim in Self.absenceClaims { … }` ——
    /// **遍历表本身**，删掉一条它就不被遍历，三条变异实测**全绿**。
    /// 「每一条表项都能被这张表认出来」是恒真命题，**它一个字都没守住**。
    /// ⇒ 改成对一份**独立写死**的期望表做**集合相等**（同 `expectedStoryuiTextParams` 的成法）：
    /// 增删任一条都红，逼人当场想清楚「这条措辞是不是真的不要了」。
    ///
    /// ⚠️ `retractionMarkers` 同理，但**别写成「活体条目每条都带两个标记」** —— 那是假全称
    /// （第 5 轮终审 S3：71 条里 `ListRow` / `Tag` / `Timeline` 等**各只带一个**）。
    /// 准确说法：**真正依赖剥离的那三条**（`ManuscriptReader` / `StoryTextView` / `ManuscriptEditor`）
    /// 各带两个标记 ⇒ 删任一条标记，**0 条判红**；`已作废` 当时更是零活体、零 fixture 使用。
    @Test("措辞表与撤回标记表不得静默增删")
    func claimTablesMatchPinnedSets() {
        let pinnedAbsence: Set<String> = [
            "不落入 textParams", "不进本表", "没有 textParams 条目", "无 textParams 条目",
            "无裸 String 展示参数",
        ]
        let pinnedPresence: Set<String> = ["登记为 C", "登记为 B"]
        let pinnedMarkers: Set<String> = ["原判", "上句原写", "推翻", "已作废"]

        #expect(Set(Self.absenceClaims) == pinnedAbsence,
                "absenceClaims 变了：多出 \(Set(Self.absenceClaims).subtracting(pinnedAbsence).sorted())、少了 \(pinnedAbsence.subtracting(Set(Self.absenceClaims)).sorted())")
        #expect(Set(Self.presenceClaims) == pinnedPresence,
                "presenceClaims 变了：多出 \(Set(Self.presenceClaims).subtracting(pinnedPresence).sorted())、少了 \(pinnedPresence.subtracting(Set(Self.presenceClaims)).sorted())")
        #expect(Set(Self.retractionMarkers) == pinnedMarkers,
                "retractionMarkers 变了：多出 \(Set(Self.retractionMarkers).subtracting(pinnedMarkers).sorted())、少了 \(pinnedMarkers.subtracting(Set(Self.retractionMarkers)).sorted())")

        // ⚠️ **光钉字符串还不够** —— 还要钉住「每条措辞真的能触发判定」，
        //    否则表还在、`contradiction` 的比对方式已废。
        // ⚠️ **措辞必须嵌在句子中段**（第 5 轮终审 I1）：初版写的是 `"占位。\(claim)。"`，
        //    **把措辞摆成了一整句** —— 于是「把 `contains` 换成整句相等」这个变异照样命中，
        //    本循环**全绿**（实测挡住它的是 `proseDataJudgeCatchesRealIncidents`，不是这里）。
        //    而真实 notes 里措辞一律**嵌在长句中段**。⇒ fixture 要长得像真的。
        for claim in pinnedAbsence {
            #expect(Self.contradiction(notes: "占位。前段文字\(claim)后段文字。", hasParams: true) != nil, "缺席措辞「\(claim)」触发不了判定")
        }
        for claim in pinnedPresence {
            #expect(Self.contradiction(notes: "占位。前段文字\(claim)后段文字。", hasParams: false) != nil, "在场措辞「\(claim)」触发不了判定")
        }
        for marker in pinnedMarkers {
            #expect(Self.contradiction(notes: "正文。上一版\(marker)：不进本表。", hasParams: true) == nil, "撤回标记「\(marker)」失效，留痕会被误判为活体断言")
        }
    }

    @Test("FR-4：public init 的裸文本参数必须在登记表 textParams 里有分类条目")
    func publicInitTextParamsAreClassified() throws {
        let entries = try ComponentRegistryGuard.loadRegistry()
        let scan = try ComponentJudgeSources.scan()
        let result = judgeTextParamCoverage(
            entries: entries, scan: scan, ownerAliases: Self.ownerAliases
        )

        // ⚠️ **非空断言先行**（AC 原文：「实际扫到的 public init 文本型参数数量 > 0 且与
        // 登记表 textParams 覆盖的裸 String 数量级吻合」）。
        let registryTextParams = entries.filter { $0.repo == "coredesign" }.flatMap(\.textParams).count
        #expect(scan.bareTextKeys.count > 20,
                "只扫到 \(scan.bareTextKeys.count) 个裸文本参数 —— 扫描器失效，这不是『零违规』")
        #expect(scan.localizedTextKeys.count > 5,
                "只扫到 \(scan.localizedTextKeys.count) 个 LSK/LSR 参数 —— 扫描器失效")
        // ⚠️ **31 → 36 的出处（`#270`）**：扩扫描根后新登记的 15 条里有 5 条带 textParams
        // —— `TypewriterText.text`（C；`init(verbatim:String)` 是运行期内容通道）
        // + 四个图表的 `title`（by-type；`LocalizedStringResource?` 且无裸串孪生重载，
        // 该「无孪生」由本文件 `byTypeCategoryHasNoBareStringTwin` 逐条核过）。
        // 其余 10 条的 public init 没有文本型参数。
        #expect(registryTextParams == 36,
                "CoreDesign 侧 textParams 实测 36 条（#270 扩扫描根后新增 TypewriterText.text 与四个图表的 title，由 31 变为 36），实际 \(registryTextParams) —— 若为预期变化请同步改这个数字")
        // ⚠️ 覆盖数 29 与登记表 30 条**不相等是预期的**，两者的计数单位不同：
        // 前者数的是**扫描键**（`Owner.init#param`），后者数的是**登记表条目**。
        // ⚠️ **29 的完整记账（Task 10 实测，非推演）**：
        //   30 条登记条目 = 产生 covered 键的 28 条 + 零 covered 键的 2 条
        //   零 covered 键的 2 条：`Descriptions.header` / `SpinningModifier.text`
        //     —— 两条 by-type，走 `.localizedText` 分支，按设计不产生 covered 键。
        //   双命中 1 条：`SegmentedControl.title` ← `SegmentedControl.init#title`
        //     与 `SegmentedControlStyleConfiguration.Segment.init#title`（后者是同一份文本
        //     转交给 style 实现者的镜像字段，该条目 notes 原文说明了不重复计入）。
        //   ⇒ 27 条各出 1 键 + 1 条出 2 键 = **29**。算平。
        // ⚠️ 两处曾经写错的因果，留在这里当反面样本（本 epic 的「绿得理由不对」）：
        //   (a) 旧旁注称「差 1 来自 Toast.message 的两个入口」——**不成立**：
        //       `ToastHost.show#message` 是 `func` 侧参数，先被 `functionSideBareText`
        //       分支接走，根本不产生 covered 键，`Toast.message` 只被 1 个键命中。
        //   (b) plan 评审推的「必须还存在**至少两处**双命中」也偏了一位：28 条产键条目
        //       只需 **1 条**双命中即可从 28 到 29。
        //   ⇒ 数字对不等于理由对；理由由下方的映射打印定案，不由推演定案。
        // ⚠️ **30 → 31 的出处（`#270`）**：新登记的 5 条 textParams 里，只有
        // `TypewriterText.text` 产出 covered 键（`TypewriterText.init#text`，来自
        // `init(verbatim text: String)` 那个裸串重载）。四个图表的 `title` 是 by-type、
        // 走 `.localizedText` 分支 ⇒ **按设计不产生 covered 键**（与既有的
        // `Descriptions.header` / `SpinningModifier.text` 同一形态）。⇒ 30 + 1 = 31。
        #expect(result.covered.count == 31,
                "覆盖数实测 31（#270 新增 TypewriterText.init#text，由 30 变为 31），实际 \(result.covered.count)：\(result.covered.keys.sorted())")
        // 数量级吻合（AC 原文）：覆盖数与登记条数同一量级（相差不超过登记条数的一半）。
        #expect(abs(result.covered.count - registryTextParams) * 2 <= registryTextParams,
                "扫到的覆盖数 \(result.covered.count) 与登记表 \(registryTextParams) 条不在同一量级 —— 两侧口径可能已经脱节")

        // ⚠️ **主判据 —— `withKnownIssue` 只包住这一句**（#39 Task 8 变异实测：块里多包
        // 一句，新违规会被静默吞掉）。到期由机器强制：`wxlpp/oh-my-story#51` 补上 notes 之后块内不再记录
        // issue，Swift Testing 主动判红，逼人回来删掉这段。
        withKnownIssue(
            """
            FR-4 已知缺口：四条 Sidebar row 的 systemImage / trailingSystemImage 是 SF Symbol 标识符，\
            与 LabelIcon.systemName 同类，但 #38 只在 LabelIcon 的 notes 里写了裁决、Sidebar 侧没写。\
            处置：补 notes（见 40 的缺陷报告），不是改判据、不是塞进 textParams。\
            ⚠️ 承接 **wxlpp/oh-my-story#51** —— 原写作「回 #38 补」，但 **#38 已 CLOSED**，\
            指向已关闭的 issue 等于移交蒸发（#51 正是为此新开的，其标题即「原『#38 本位』，但 #38 已关闭」）。
            """
        ) {
            #expect(result.violations.isEmpty, "这些裸文本参数没有分类条目：\n\(result.diagnostics.joined(separator: "\n"))")
        }

        // ⚠️ **块外 canary**：新违规不能被上面的 knownIssue 吞掉。
        #expect(Set(result.violations) == Self.knownUnregisteredSymbolParams,
                """
                FR-4 违规集合变了：实际 \(result.violations)，已知 \(Self.knownUnregisteredSymbolParams.sorted())。\
                变大 ⇒ 新增了未登记的裸文本参数（上面的 withKnownIssue 会把它静默吞掉，靠本条抓）；\
                变小 ⇒ 已补登记（承接 wxlpp/oh-my-story#51），同步删除 knownUnregisteredSymbolParams 与上面的 withKnownIssue 块
                """)

        // ⚠️ **反向差集**：登记表有条目、源码扫不到 ⇒ 幽灵条目。这是把参数改写成扫描器
        // 看不见的形态时的第二道防线。
        #expect(result.ghostRegistryParams.isEmpty,
                "登记表里这些 textParams 在源码里找不到对应参数（改名？改类型？删了？）：\(result.ghostRegistryParams)")

        // ⚠️ **三个豁免/域外桶都要固定集合断言 —— 不许有静默桶**。
        #expect(Set(result.exemptedByRegistryNotes) == ["LabelIcon.init#systemName"],
                """
                notes 授权豁免集合变了：实际 \(result.exemptedByRegistryNotes)。这条通道是 FR-4 唯一的语义豁免入口，\
                授权者是登记表 notes 而不是判据作者，集合变化必须有人过目
                """)
        #expect(Set(result.exemptedByExcludedKind) == ["ProgressBar.init#label"],
                """
                弃用豁免集合变了：实际 \(result.exemptedByExcludedKind)。ProgressBar 已 kind=excluded、\
                textParams 留空是刻意的（公约弃用条款「不分类」）；#42 删掉该组件后本条会因集合变空而红，届时同步删除
                """)
        #expect(Set(result.unmappedOwners) == Self.knownUnmappedOwnerParams,
                """
                定义域外集合变了：实际 \(result.unmappedOwners)，已知 \(Self.knownUnmappedOwnerParams.sorted())。\
                新条目意味着出现了『有裸文本参数、但宿主不对应任何登记表条目』的类型 —— 要么补 ownerAliases，\
                要么退回登记表判断它该不该登记（#38 已 CLOSED，判定归属见 wxlpp/oh-my-story#51），**不能**默默跳过
                """)

        // ⚠️ **承重核对**：弃用豁免的对象必须真的还在源码里、真的还是 excluded。
        #expect(scan.bareTextKeys.contains("ProgressBar.init#label"),
                "ProgressBar.init#label 已不在源码里 —— 弃用豁免失去豁免对象，请删除对应断言")
        #expect(entries.first { $0.component == "ProgressBar" }?.kind == "excluded",
                "ProgressBar 不再是 kind=excluded —— 它的 textParams 留空就不再受弃用条款保护了")

        // ⚠️ **`func` 侧留痕桶**：AC 只点名 `init`，但 func 侧确实存在真实的 public 文案入口。
        #expect(Set(result.functionSideBareText) == Self.knownFunctionSideBareText,
                """
                func 侧裸文本参数集合变了：实际 \(result.functionSideBareText)，已知 \(Self.knownFunctionSideBareText.sorted())。\
                本桶是留痕不是判据（AC 只点名 init）；集合变化说明新增了不受 FR-4 主判据覆盖的文案入口，\
                需要人来决定是扩 FR-4 定义域还是移交
                """)

        // ⚠️ **`localizedByType` 与 `carrying` 两个桶同样要固定计数 —— 「不许有静默桶」是
        // 分桶模型自己写下的全称量词，两个只打印不断言的桶会让它当场变成假话。**
        // 本 epic 的教训就是全称量词是反例制造机 ⇒ 要么让断言配得上那句话，要么改掉那句话；
        // 这里选前者。计数取自 Task 3 Step 5 的真实源码冒烟（裸文本 39 / LSK/LSR 11 / carrying 8）。
        // ⚠️ 这两个桶用**计数**而不是固定集合：它们是留痕桶不是判据桶，集合逐条钉住会把
        // 「改了个参数名」也变成红，成本与收益不匹配；计数变化已足以逼人过目。
        // ⚠️ **11 → 17 的出处（`#270`）**：扩扫描根后新增 6 个 LSK/LSR 键 ——
        // 四个图表的 `title`（`LocalizedStringResource?`）+ `TypewriterText.init#text`
        // （它的另一个重载 `init(_:LocalizedStringResource)`；同一个键同时出现在本桶与
        // covered 里，因为两个 public init 共用参数名 `text`）+ `View.rise#text`
        // （`CoreDesignEffects` 的公开 modifier，`func` 侧的 LSK/LSR 参数）。
        #expect(result.localizedByType.count == 17,
                """
                LSK/LSR 由类型判定的键实测 17 条（`#270` 扩扫描根后由 11 变为 17），实际 \(result.localizedByType.count)：\(result.localizedByType)。\
                变化意味着有参数在 LSK/LSR 与裸串之间换了类型 —— 要人过目，不能静默
                """)
        // ⚠️ **9 → 10 的出处（`#270`）**：新增 `CharSphere.init#characters`（`[String]`）。
        // 按 FR-7 它是**调用方的数据内容**而不是本件的界面文案（`docs/components/char-sphere.md`
        // 逐字：「调用方传入的数据文案是内容不是 UI 文案，不强制本地化类型」），
        // 扫描器把它归入 text-carrying 桶 ⇒ 不进 FR-4 主判据，与该文档的裁决同向。
        #expect(result.carrying.count == 10,
                """
                text-carrying 键实测 10 条（`#270` 扩扫描根后新增 CharSphere.init#characters，由 9 变为 10），\
                实际 \(result.carrying.count)：\(result.carrying)。\
                本桶（Binding<String> / 回调等）不进主判据，但它是**文案经此进入组件**的通道，\
                静默增长等于 FR-4 的定义域在无人过目的情况下缩小
                """)

        // ⚠️ **跨仓裁决 (a)：显式报告 + 棘轮**。
        #expect(result.skippedRepos == ["storyui": 25], "跨仓跳过计数变了：实际 \(result.skippedRepos)")
        // ⚠️ **从纯计数收紧为条目级集合相等**（`wxlpp/oh-my-story#67`，G-8）。
        //
        // 旧版是 `storyuiTextParams == 3`——它抓不到**改名 / 改 category / 换组件挂靠**
        // 三类漂移（计数不变）。集合相等三类都抓。
        //
        // ⚠️ **但要写明它守的是哪一半**：本条**只核登记表内容、核不了源码**
        //（依据见 **FR-4 主测试结尾**那条 print 的逐字「CI 只 checkout 本仓」——⚠️ 初稿写
        //  「本文件末尾」，而文件真正最后一条 print 是另一条同样以 FR-4 开头的 by-type 核对；
        //  ⚠️ 而那句短语在本文件出现 **3 次**（本注释自引 + FR-4 主测试结尾的注释与 print）——
        //  初版写「全文件唯一」被一条 `grep -c` 证伪，且第 3 处正是本 PR 自己加的。——CoreDesign 的
        //  CI 读不到 StoryUI 源码。⚠️ **此处不写行号**：本 PR 自己在上方插入 23 行，就把
        //  原来写的 `:239` 顶成了别的语句 —— 自引用行号会被引用它的那次编辑弄失效。）
        // **源码侧的参数级判据在 `oh-my-story` 的 `TextParamGuard`**（深度 0 三桶差集 +
        // registry 侧派生差集 + 深度 ≥1 的 canary）。
        //
        // ⚠️ **代价（跨仓协调棘轮）**：StoryUI 侧任何 `textParams` 变更从此**需要配套的
        // CoreDesign commit** 来更新本常量。这是有意的——两边各自演化正是要防的事。
        let storyuiTextParamFlat = entries.filter { $0.repo == "storyui" }
            .flatMap { e in e.textParams.map { "\(e.component).\($0.name)=\($0.category)" } }
        let storyuiTextParamEntries = Set(storyuiTextParamFlat)
        let expectedStoryuiTextParams: Set<String> = [
            "DynamicForm.header=B", "DynamicForm.footer=B", "ChapterStatusBadge.label=B",
            // ⚠️ `#67` 新登记：三条 `AttributedString`，承载**用户手稿正文** ⇒ 判 **C**。
            //    CoreDesign 排除 `AttributedString` 的成文理由是「本仓零使用，先留痕」
            //    （`ComponentJudgeScanner.swift:135-136`）——**那个理由在 StoryUI 被证伪**。
            "ManuscriptEditor.text=C", "ManuscriptReader.text=C", "StoryTextView.initialText=C",
        ]
        // ⚠️ **`Set` 相等把「重复登记」静默折叠掉了 —— 这是相对旧判据的一处净退化**：
        //  旧的 `count == 3` 抓得住同一条 textParam 被写两遍（7 ≠ 6 ⇒ 红），
        //  换成集合后重复项被折叠 ⇒ 全绿。核过 `ComponentRegistryGuard`：它对 textParams
        //  **只验 category 允许域、无唯一性断言** ⇒ 无人顶位。故这里显式补一条。
        // ⚠️ **notes 的散文不得与 textParams 数据自相矛盾**（`#67` 第 1/2 轮评审各抓一次，
        //  合计**三条**活体假断言）。⚠️ 第 1 轮由 Copilot 独家抓到、superpowers 终审漏了；
        //  第 2 轮 Copilot 与 superpowers 终审**各自独立报出**（此处初版写「两轮全漏、都是
        //  Copilot 抓的」——**假**，被本分支自己的 commit 正文推翻）：
        //  改了 `textParams` 数组，而**近旁描述它的那句散文**没跟着改 ⇒ 数据说有、散文说无。
        //  ⚠️ 第 2 轮那次更糟：我按字符串替换去改 `ManuscriptEditor`，而
        //  「无裸 String 展示参数。」在本表里**有三处**（`SuggestionStream` / `ManuscriptEditor`
        //  / `StoryScaffold`），替换命中的是**第一处** ⇒ 改错了条目，还在 PR 里回帖说改好了。
        //  ⇒ 这条判据把「散文 ⟂ 数据」这一面**部分**机械化。
        //  ⚠️ **别读成「守住了」** —— 初版**只机械化了第 1 轮那一种措辞**：把第 2 轮的事故树
        //  （`e9f42ee` 的 registry）放回来跑，判据**全绿**，因为两条真实假断言的措辞
        //  （「无裸 String 展示参数」/「…登记为 C（…）」）**都不在措辞表里**；
        //  且 `absenceClaims` 在当时的 71 条条目上**活体命中 0**，整表清空照样全绿。
        //  终审 C-1 用一条命令证的：`git checkout e9f42ee -- docs/component-registry.json && swift test`。
        //  ⇒ 措辞表已补真实事故的两种说法。
        //  ⚠️ **变异编号在仓内无定义，此处写明内容**（第 5 轮终审 S4 —— 编号只在 commit
        //  正文里出现过，读者 grep 不到，等于没留）：
        //    · **A6d** = `git show e9f42ee:docs/component-registry.json > 该文件` 后跑本套（第 2 轮事故树回放）
        //    · **A6e** = 同上，换 `422055b`（第 1 轮事故树回放）
        //    · **A6f** = 往 `presenceClaims` 塞一条含既有项作子串的措辞（如 `本条目登记为 C 类`）
        //    · **A6g** = 把 `absenceClaims` 整表清空
        //    · **A6i** = 从任一表里删掉**一条**（`不进本表` / `登记为 B` / `已作废`）
        //    · **A6j** = 把 `contradiction` 的 `live.contains(claim)` 换成**按句切分后整句相等**
        //  六条现在**逐条判红**；A6g 在 fixture 落地前、A6i 在期望表落地前、A6j 在措辞嵌入句中前，**都是绿的**。
        //  ⚠️ **它守不住的**：措辞是**枚举**的，同义换词照样逃（同 `#48` G-7 的名单式判据）；
        //  它只核**有无**，核不了 category 是否说对。
        // ⚠️ **把「两两无子串包含」从纪律变成断言**（终审 C-1）：这是本判据**唯一有过实际
        //  误报记录**的失效方向（初版「无 textParams」被「不**等于**无 textParams」含作子串）。
        //  ⚠️ **口径要说准**（终审 S-3）：本断言测的是 **claim ⊂ claim**，而那次事故是
        //  **claim ⊂ notes 散文**。它之所以能挡住那次回归，是因为把「无 textParams」加回表里
        //  会与既有的「无 textParams 条目」相撞（变异 A6f 实测红）—— **间接命中，不是直接测**。
        //  写成注释靠人记会失效，写成断言不会。
        let allClaims = Self.absenceClaims + Self.presenceClaims
        let overlaps = allClaims.flatMap { x in allClaims.filter { $0 != x && $0.contains(x) }.map { (x, $0) } }
        #expect(overlaps.isEmpty,
                "措辞表存在子串包含，判据会自造误报：\(overlaps.map { "「\($0.0)」⊂「\($0.1)」" }.joined(separator: "、"))")

        for e in entries {
            let c = Self.contradiction(notes: e.notes, hasParams: !e.textParams.isEmpty)
            #expect(c == nil, "\(e.component)：\(c ?? "")")
        }

        #expect(storyuiTextParamFlat.count == storyuiTextParamEntries.count,
                """
                storyui 的 textParams 有重复登记：展开 \(storyuiTextParamFlat.count) 条、去重后 \(storyuiTextParamEntries.count) 条。
                重复项：\(Dictionary(grouping: storyuiTextParamFlat, by: { $0 }).filter { $0.value.count > 1 }.keys.sorted())
                """)

        #expect(storyuiTextParamEntries == expectedStoryuiTextParams,
                """
                StoryUI 侧 textParams 条目集与期望不一致：
                  登记表有、期望没有：\(storyuiTextParamEntries.subtracting(expectedStoryuiTextParams).sorted())
                  期望有、登记表没有：\(expectedStoryuiTextParams.subtracting(storyuiTextParamEntries).sorted())
                —— 本条只核**登记表内容**；源码侧判据在 oh-my-story 的 `TextParamGuard`（#67）。
                """)

        // ⚠️ **covered 的完整记账（扫描键 → 登记条目），不写因果故事只打映射**。
        // 29（covered 键）与 30（登记条目）的差额到底由什么构成，只有这张映射说了算：
        // 一条登记条目可以被 0 个、1 个或多个扫描键命中，三种情形都要能在输出里数出来。
        var scanKeysByRegistryEntry: [String: [String]] = [:]
        for (scanKey, registryEntry) in result.covered {
            scanKeysByRegistryEntry[registryEntry, default: []].append(scanKey)
        }
        let allRegistryNames = Set(
            entries.filter { $0.repo == "coredesign" }
                .flatMap { entry in entry.textParams.map { "\(entry.component).\($0.name)" } }
        )
        let uncoveredRegistryNames = allRegistryNames.subtracting(scanKeysByRegistryEntry.keys).sorted()
        let multiHitRegistryNames = scanKeysByRegistryEntry.filter { $0.value.count > 1 }
        print("FR-4 covered 映射（登记条目 ← 扫描键）：")
        for (registryEntry, scanKeys) in scanKeysByRegistryEntry.sorted(by: { $0.key < $1.key }) {
            print("  \(registryEntry)  ←  \(scanKeys.sorted().joined(separator: " , "))")
        }
        print("FR-4 记账：登记条目 \(allRegistryNames.count) 条 = 产生 covered 键的 \(scanKeysByRegistryEntry.count) 条 + 零 covered 键的 \(uncoveredRegistryNames.count) 条")
        print("FR-4 零 covered 键的登记条目：\(uncoveredRegistryNames)")
        print("FR-4 双命中登记条目 \(multiHitRegistryNames.count) 条：\(multiHitRegistryNames.mapValues { $0.sorted() })")
        // ⚠️ **记账恒等式**：covered 键数 = Σ 每条登记条目命中的键数。这条本身是同义反复，
        // 但它逼出下面这条**不是**同义反复的：把三个数摆在一起，差额就没有藏身处。
        #expect(scanKeysByRegistryEntry.values.map(\.count).reduce(0, +) == result.covered.count)
        #expect(scanKeysByRegistryEntry.count + uncoveredRegistryNames.count == allRegistryNames.count,
                """
                记账不闭合：产生 covered 键的 \(scanKeysByRegistryEntry.count) 条 + 零 covered 键的 \
                \(uncoveredRegistryNames.count) 条 ≠ 登记条目 \(allRegistryNames.count) 条 —— \
                多半是某个 covered 值指向了一条并不存在于登记表的条目名
                """)

        print("FR-4 覆盖 \(result.covered.count) 条；LSK/LSR 由类型判定 \(result.localizedByType.count) 条；carrying \(result.carrying.count) 条")
        print("FR-4 已知违规 \(result.violations)（回 #38 补 notes）")
        print("FR-4 notes 授权豁免 \(result.exemptedByRegistryNotes)；弃用豁免 \(result.exemptedByExcludedKind)")
        print("FR-4 定义域外 \(result.unmappedOwners)；func 侧留痕 \(result.functionSideBareText)")
        // ⚠️ 旧文写「移交 #43」且说这 3 条「两个方向都无法核对」——**两处都已过期**：
        //    条数是 6 不是 3；而源码侧的参数级判据已由 `wxlpp/oh-my-story#67` 落地
        //    （`TextParamGuard`）。本仓仍核不了源码（CI 只 checkout 本仓），但**对面能核**。
        print("FR-4 跳过 storyui \(result.skippedRepos["storyui"] ?? 0) 条 / \(storyuiTextParamEntries.count) 个 textParams：本仓只核登记表内容（CI 只 checkout 本仓）；源码侧判据见 oh-my-story 的 TextParamGuard（#67）。")
    }

    @Test("FR-4 附条：owner 翻译表每一条都必须真的被用到（不许有过期条目）")
    func ownerAliasesAreLoadBearing() throws {
        let scan = try ComponentJudgeSources.scan()
        let owners = Set(scan.textParams.map(\.owner))
        let unused = Set(Self.ownerAliases.keys).subtracting(owners)
        #expect(unused.isEmpty,
                "ownerAliases 里这些宿主在源码里已经没有文本参数了，翻译条目已过期：\(unused.sorted())")
    }

    @Test("FR-4 附条：by-type 分类必须真的没有孪生裸串重载（公约 §4 的实际筛子）")
    func byTypeCategoryHasNoBareStringTwin() throws {
        let entries = try ComponentRegistryGuard.loadRegistry()
        let scan = try ComponentJudgeSources.scan()

        // 建「组件 → 该组件的裸文本参数候选名集合」的索引。
        var bareNamesByComponent: [String: Set<String>] = [:]
        for hit in scan.textParams where hit.kind == .bareText {
            let component = Self.ownerAliases[hit.owner] ?? hit.owner
            bareNamesByComponent[component, default: []]
                .formUnion(textParamCandidateNames(owner: hit.owner, parameter: hit.parameter))
        }

        var byTypeCount = 0
        var localizedBCount = 0
        for entry in entries where entry.repo == "coredesign" {
            for textParam in entry.textParams {
                let hasBareTwin = bareNamesByComponent[entry.component]?.contains(textParam.name) ?? false
                if textParam.category == "by-type" {
                    byTypeCount += 1
                    // 公约 §4：`by-type` 的前提是「无接受裸字符串的孪生重载
                    // （`String` **或** `StringProtocol`）」。有孪生 ⇒ 该判 B 类。
                    #expect(!hasBareTwin,
                            """
                            \(entry.component).\(textParam.name) 登记为 by-type，但源码里存在裸串孪生重载 —— \
                            按公约 §4 应判 B 类，请退回 #38 重新分类
                            """)
                } else if !hasBareTwin {
                    // 反向：分类为 B/C 却只有 LSK/LSR 入口 ⇒ 按公约 §4 应判 by-type。
                    localizedBCount += 1
                    #expect(Bool(false),
                            """
                            \(entry.component).\(textParam.name) 登记为 \(textParam.category)，但源码里只有 LSK/LSR 入口、\
                            没有裸串孪生重载 —— 按公约 §4「无孪生重载 ⇒ by-type」应重新分类，请退回 #38
                            """)
                }
            }
        }
        // ⚠️ **2 → 6 的出处（`#270`）**：四个图表的 `title` 是 `LocalizedStringResource?`
        // 且**没有**裸串孪生重载（本测试上面的循环刚逐条核过），按公约 §4 落 by-type。
        // ⚠️ `TypewriterText.text` **不在**这 6 条里：它有 `init(verbatim text: String)`
        // 这个裸串孪生重载 ⇒ 公约 §4 的筛子把它挡在 by-type 之外，登记为 C。
        #expect(byTypeCount == 6,
                "by-type 条目实测 6 条（Descriptions.header / SpinningModifier.text + 四个图表的 title），实际 \(byTypeCount)")
        #expect(localizedBCount == 0)
        // ⚠️ 分母**从数据里算**，不写死：上一版写死「28 条 B/C」，而 `#270` 一改登记表它就过期了，
        // 且它是 print 不是断言 ⇒ 过期了也没有任何判据会红。
        let bcCount = entries.filter { $0.repo == "coredesign" }
            .flatMap(\.textParams).count - byTypeCount
        print("FR-4 by-type 核对：\(byTypeCount) 条 by-type 均无裸串孪生重载；\(bcCount) 条 B/C 均有裸串入口")
    }
}
