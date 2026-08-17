import Foundation
import Testing

// 公约文档的**结构守卫**（J-4 的公约文档部分）。
//
// ⚠️ **这条判据原本无人认领**：#44 的验收写着「结构守卫（Task 001/004 的 J-4）」，
// 而 001 只要求文档「含 5 节」、004 只做 J-2/J-3/FR-4 —— **#44 引用了一条不存在的判据**。
// 开工 #37 时发现并归入本任务。
//
// ⚠️ 这正是本 epic 存在的理由（#30：组件文档模板一直在，5/27 份不符它，六轮评审无一核对）,
// 而漏掉的偏偏是**守护公约文档本身**的那条。
//
// ⚠️ J-4 的另外两半不在这里：分类登记表（`component-registry.json`）随 #38 落地、
// 豁免基线（`bool-exemptions.json`）随 #39 落地，**守卫应与被守卫物同批**。
@Suite("公约文档结构守卫")
struct ComponentContractStructureGuard {

    /// 5 个必需节。⚠️ 字面量必须与 `docs/component-contract.md` 一字不差。
    static let requiredSections = [
        "## 1. 判定法：语义组件 vs 规定性组件",
        "## 2. 样式扩展点：三选一",
        "## 3. 配置开关的四条替代路径",
        "## 4. 文案类型三分法",
        "## 5. 环境值清单",
    ]

    /// **12 个**承重 `###`/`####` 小节——tiebreaker、优先级固定、边界条款、终局条款、
    /// 头号反例、Style Configuration 状态 Bool 豁免，是四轮评审换来的增量；
    /// `by-type` 取值定义、三方同步通则、AD-2、AD-3 四条是 Issue #38 Task 2 本轮
    /// 新增的承重内容。#44 回写的「候选形态的作用域」是第 11 条。#44 回写的
    /// 「事后补写的效力边界」是第 12 条。
    /// ⚠️ **数字与下面数组的元素数必须一致**：第一版注释写「5 个」并逐一列举，
    /// 而数组在同一轮里已补到 6 个——**新增的那条不在列举里，最容易被后人当成多余而误删**
    /// （Copilot round 1 报出）。本轮终审 I1 发现同一种病复发：数组停在 6 个，而公约
    /// 本轮又新增了 4 段承重内容（`by-type` 取值定义、通则、AD-2、AD-3）一个都没进来
    /// ——**整段删掉 `swift test` 照绿**。改数组时**同步改这里的数字与列举**，这条警告
    /// 本身就是本条判据反复失守的证据，不是虚言。
    /// h2 保留、这些小节被掏空是这份文档最现实的烂法，
    /// 比删 h2 更隐蔽（`## 1.` 之类骨架完好，读者不会觉得"缺了什么"）。
    /// ⚠️ 字面量必须与 `docs/component-contract.md` 一字不差。
    static let requiredSubsections = [
        "### ⚠️ Tiebreaker：两可时怎么办",
        "### ⚠️ 优先级固定：A 永远优先于 B",
        "### 边界条款：样式不得携带行为",
        "### ⚠️ 终局条款：四条都不适用时怎么办",
        "### ⚠️ 头号反例：把 Bool 换成两 case enum **不是**替代路径",
        // 第四轮增量：没有它，`SegmentedControlStyleConfiguration.Segment.isSelected`
        // 就会成为 #39 的 J-1 在公约自己认可的先例上的误报。
        "### ⚠️ 例外：Style Configuration 上的状态描述 Bool 不受本节约束",
        // 终审 I1 补的四条（Issue #38 Task 2 本轮新增，此前未进本数组）：
        "### 登记表的第四个 `category` 取值：`by-type`",
        "#### 通则：判定法枚举的三方同步义务",
        "#### AD-2 裁决：「这不是组件」的范围——ViewModifier 是否进登记表",
        // ⚠️ 终审 M3：公约里这条标题原来跨两行写（Markdown 会把第二行渲染成独立段落，
        // 标题实际只是半句话），本数组的字面量因此也只抄了半句——**把公约标题排版
        // 修好会立刻把本判据打红**，所以两处必须同轮改。现已把公约标题合并成一行，
        // 这里同步改成完整字面量。
        "#### AD-3 裁决：AC #49 点名的三个 style（`CoreLabelStyle`/`CoreProgressViewStyle`/`CoreDisclosureGroupStyle`）在新登记单位下无对应物",
        // #44 SC-8 回写：判定法步骤 2 的作用域规则（不是第四出口）。没有它，
        // 6 条 step3 判例援引的那条规矩在公约里零提及。
        "### ⚠️ 候选形态的作用域：由兄弟组件承担的形态不计入候选",
        // #44 SC-8 回写：事后补写 notes 的效力边界。没有它，任何已发布判例都可由
        // 一次 notes 补写悄悄翻转（`SkeletonCircle` 是现成的可被翻转样本）。
        "### ⚠️ 事后补写的效力边界：只能补强记录，不得单方面翻转落点",
    ]

    static var contractURL: URL {
        URL(fileURLWithPath: #filePath)          // Tests/CoreDesignTests/xxx.swift
            .deletingLastPathComponent()          // Tests/CoreDesignTests
            .deletingLastPathComponent()          // Tests
            .deletingLastPathComponent()          // 仓库根
            .appendingPathComponent("docs/component-contract.md")
    }

    @Test("公约文档含全部 5 个必需节")
    func contractHasAllRequiredSections() throws {
        let text = try String(contentsOf: Self.contractURL, encoding: .utf8)

        // ⚠️ **非空断言**：文件读不到或为空时，下面的「零个节缺失」会静默变绿。
        #expect(text.count > 1000, "公约文档只有 \(text.count) 字符 —— 疑似没读到或是个空壳")

        // ⚠️ **行锚定精确相等，不能用 `contains`**（plan 评审 C1）。
        // `contains` 被三种变异骗过，实测：
        //   追加后缀 `## 5. 环境值清单（改坏）` → 仍含原字面量 ⇒ 绿
        //   h2→h3 降级 `### 5. 环境值清单`       → 仍含原字面量 ⇒ 绿
        //   行内引用「见上文的 ## 5. 环境值清单」  → 仍含原字面量 ⇒ 绿
        // 而计划第一版的变异**正是「追加后缀」** —— 照跑会得到「存活」，
        // 然后执行者被迫临场改变异去迁就守卫，洞就永远不会被问。
        // ⚠️ **只剪行尾空白与 CR，不剪前导空白**（plan 评审第 2 轮 F4a）。
        // 剪两端（`.trimmingCharacters(in: .whitespaces)`）会自己开一个洞：
        // CommonMark 里**行首 ≥4 空格 = 缩进代码块**，标题已经不再渲染为标题，
        // 而剪掉前导空白后它与字面量精确相等 ⇒ **守卫照绿**。
        // 这是**单次编辑**就能触发的真实事故（把内容粘进嵌套列表项，整段被缩进），
        // 比被挡掉的三种 `contains` 形态都廉价。
        // ⚠️ 讽刺的是：不剪前导它本来就挡得住——**trim 是为「行尾空格」加的健壮性，
        // 副作用正好开了这个洞**。
        // 1–3 空格前导在本仓文风里本就不该出现 ⇒ 误红是 fail-safe 方向，可接受。
        let trimmedLines = text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> String in
                var t = String(line)
                while let last = t.last, last == " " || last == "\t" || last == "\r" {
                    t.removeLast()
                }
                return t
            }
        let headings = Set(trimmedLines)
        let missing = Self.requiredSections.filter { !headings.contains($0) }
        #expect(missing.isEmpty, "公约文档缺这些必需节：\n\(missing.joined(separator: "\n"))")

        // ⚠️ 终审 S3：h2 保留、承重 `###` 小节被掏空是比删 h2 更现实的烂法——
        // 同款行锚定机制（复用上面已算出的 `headings`），零新机器。
        let missingSubsections = Self.requiredSubsections.filter { !headings.contains($0) }
        #expect(missingSubsections.isEmpty, "公约文档缺这些承重小节：\n\(missingSubsections.joined(separator: "\n"))")

        // ⚠️ 只查存在性不查顺序，没有安全网（简报 Step 1）——补顺序断言：
        // 5 个必需节 + 附录 A 的行号必须严格递增（即节顺序未被打乱，且都在附录 A 之前）。
        // 只在上面「存在性」已全绿时才查，否则 firstIndex(of:) 会缺项，误报顺序错。
        if missing.isEmpty {
            let appendixHeading = "## 附录 A：判定法的实测走查"
            let orderedHeadings = Self.requiredSections + [appendixHeading]
            let lineNumbers = orderedHeadings.compactMap { trimmedLines.firstIndex(of: $0) }
            #expect(lineNumbers.count == orderedHeadings.count, "找不到附录 A 标题：\(appendixHeading)")
            #expect(lineNumbers == lineNumbers.sorted(), "节顺序被打乱，应为：\n\(orderedHeadings.joined(separator: "\n"))")
        }
    }

    @Test("公约文本提及守卫允许域里的每一个取值（终审 I1(b)：给通则装上牙）")
    func contractMentionsEveryGuardAllowedValue() throws {
        let text = try String(contentsOf: Self.contractURL, encoding: .utf8)
        #expect(text.count > 1000, "公约文档只有 \(text.count) 字符 —— 疑似没读到或是个空壳")

        // ⚠️ **终审 I1(b)——规矩存放在受害者处，不在致病者处**：公约第 4 节末尾的
        // 「通则：判定法枚举的三方同步义务」只是一段散文，约束的是人（读了才会遵守）；
        // 三个真正的致病者——`ComponentRegistryGuard.validKinds` /
        // `validDecidedBy` / `validCategories`、以及 oh-my-story 的任务书 schema
        // ——一次都不是公约本身，没有任何机器判据把改 `validXxx` 的人指向公约。
        // 这里把通则落成判据：三个允许域集合里的**每个取值**都必须能在公约文本里
        // 找到——backtick 包裹的字面量（`kind`/`decidedBy`/`by-type` 在公约里都是
        // 这么写的），或 A/B/C 用文案三分法表格的加粗写法（`**A. ...**` 这类）。
        // ⚠️ 范围限于「取值必须被公约提及」这个方向——不反向断言公约提到的每个词都在
        // `validXxx` 里（那会把公约里的普通中文字符也算进去，无意义）。
        func isMentioned(_ value: String) -> Bool {
            text.contains("`\(value)`") || text.contains("**\(value).")
        }

        for value in ComponentRegistryGuard.validKinds.sorted() {
            #expect(isMentioned(value), "公约文本里找不到 kind 取值 `\(value)`——validKinds 与公约脱节")
        }
        for value in ComponentRegistryGuard.validDecidedBy.sorted() {
            #expect(isMentioned(value), "公约文本里找不到 decidedBy 取值 `\(value)`——validDecidedBy 与公约脱节")
        }
        for value in ComponentRegistryGuard.validCategories.sorted() {
            #expect(isMentioned(value), "公约文本里找不到 textParams category 取值 `\(value)`——validCategories 与公约脱节")
        }
    }
}
