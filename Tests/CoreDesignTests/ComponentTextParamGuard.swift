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
    static let knownFunctionSideBareText: Set<String> = [
        "ToastHost.show#message",
        "View.bottomInputBar#placeholder",
    ]

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
        #expect(registryTextParams == 30,
                "CoreDesign 侧 textParams 实测 30 条，实际 \(registryTextParams) —— 若为预期变化请同步改这个数字")
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
        #expect(result.covered.count == 29,
                "覆盖数实测 29，实际 \(result.covered.count)：\(result.covered.keys.sorted())")
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
        #expect(result.localizedByType.count == 11,
                """
                LSK/LSR 由类型判定的键实测 11 条，实际 \(result.localizedByType.count)：\(result.localizedByType)。\
                变化意味着有参数在 LSK/LSR 与裸串之间换了类型 —— 要人过目，不能静默
                """)
        #expect(result.carrying.count == 8,
                """
                text-carrying 键实测 8 条，实际 \(result.carrying.count)：\(result.carrying)。\
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
        //（`:239` 逐字「CI 只 checkout 本仓」——CoreDesign 的 CI 读不到 StoryUI 源码）。
        // **源码侧的参数级判据在 `oh-my-story` 的 `TextParamGuard`**（深度 0 三桶差集 +
        // registry 侧派生差集 + 深度 ≥1 的 canary）。
        //
        // ⚠️ **代价（跨仓协调棘轮）**：StoryUI 侧任何 `textParams` 变更从此**需要配套的
        // CoreDesign commit** 来更新本常量。这是有意的——两边各自演化正是要防的事。
        let storyuiTextParamEntries = Set(
            entries.filter { $0.repo == "storyui" }
                .flatMap { e in e.textParams.map { "\(e.component).\($0.name)=\($0.category)" } })
        let expectedStoryuiTextParams: Set<String> = [
            "DynamicForm.header=B", "DynamicForm.footer=B", "ChapterStatusBadge.label=B",
            // ⚠️ `#67` 新登记：三条 `AttributedString`，承载**用户手稿正文** ⇒ 判 **C**。
            //    CoreDesign 排除 `AttributedString` 的成文理由是「本仓零使用，先留痕」
            //    （`ComponentJudgeScanner.swift:135-136`）——**那个理由在 StoryUI 被证伪**。
            "ManuscriptEditor.text=C", "ManuscriptReader.text=C", "StoryTextView.initialText=C",
        ]
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
        #expect(byTypeCount == 2,
                "by-type 条目实测 2 条（Descriptions.header / SpinningModifier.text），实际 \(byTypeCount)")
        #expect(localizedBCount == 0)
        print("FR-4 by-type 核对：\(byTypeCount) 条 by-type 均无裸串孪生重载；28 条 B/C 均有裸串入口")
    }
}
