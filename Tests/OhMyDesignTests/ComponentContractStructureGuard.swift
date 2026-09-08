import Foundation
import Testing

@Suite("公约文档结构守卫")
struct ComponentContractStructureGuard {
    static let requiredSections = [
        "## 1. 判定法：语义组件 vs 规定性组件",
        "## 2. 样式扩展点：四选一",
        "## 3. 配置开关的四条替代路径",
        "## 4. 文案类型三分法",
        "## 5. 环境值清单",
    ]

    static let requiredSubsections = [
        "### ⚠️ Tiebreaker：两可时怎么办",
        "### ⚠️ 优先级固定：A 永远优先于 B",
        "### 边界条款：样式不得携带行为",
        "### ⚠️ 终局条款：四条都不适用时怎么办",
        "### ⚠️ 头号反例：把 Bool 换成两 case enum **不是**替代路径",
        "### ⚠️ 例外：Style Configuration 上的状态描述 Bool 不受本节约束",
        "### 登记表的第四个 `category` 取值：`by-type`",
        "#### 通则：判定法枚举的三方同步义务",
        "#### AD-2 裁决：「这不是组件」的范围——ViewModifier 是否进登记表",
        "#### AD-3 裁决：AC #49 点名的三个 style（`CoreLabelStyle`/`CoreProgressViewStyle`/`CoreDisclosureGroupStyle`）在新登记单位下无对应物",
        "### ⚠️ 候选形态的作用域：由兄弟组件承担的形态不计入候选",
        "### ⚠️ 事后补写的效力边界：只能补强记录，不得单方面翻转落点",
        "### ⚠️ 取值域的命名规矩：「角色 + 修饰词」允许，禁的是**裸**修饰词",
        "### ⚠️ 已知判据缺口：本公约有规定、机器判据够不到的地方",
        "#### AD-4 裁决：三个新 target 的登记表作用域 —— **裁定：AD-2 原样适用**",
        "##### 为什么裁「AD-2 原样适用」而不是「什么都不裁」",
        "##### 撤回记录：五版各错在哪（照录，不删）",
        "##### 下游连锁一 · Charts 走 b 会触发整条 J-2 链",
        "##### 下游连锁二 · `transition` / `modifier` 走扩展成员扫描器（**与路线无关**）",
        "##### 下游连锁三 · README 索引落点：**三个 target 全部进主索引**",
        "##### 下游连锁四 · 扫描根的实施形态（工程事实，**不是禁令**）",
    ]

    static var contractURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("docs/component-contract.md")
    }

    @Test("公约文档含全部 5 个必需节")
    func contractHasAllRequiredSections() throws {
        let text = try String(contentsOf: Self.contractURL, encoding: .utf8)

        #expect(text.count > 1000, "公约文档只有 \(text.count) 字符 —— 疑似没读到或是个空壳")

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

        let missingSubsections = Self.requiredSubsections.filter { !headings.contains($0) }
        #expect(missingSubsections.isEmpty, "公约文档缺这些承重小节：\n\(missingSubsections.joined(separator: "\n"))")

        if missing.isEmpty {
            let appendixHeading = "## 附录 A：判定法的实测走查"
            let orderedHeadings = Self.requiredSections + [appendixHeading]
            let lineNumbers = orderedHeadings.compactMap { trimmedLines.firstIndex(of: $0) }
            #expect(lineNumbers.count == orderedHeadings.count, "找不到附录 A 标题：\(appendixHeading)")
            #expect(lineNumbers == lineNumbers.sorted(), "节顺序被打乱，应为：\n\(orderedHeadings.joined(separator: "\n"))")
        }
    }

    @Test("公约的 markdown 表格没有被裸换行劈开的行")
    func contractTablesHaveNoSplitRows() throws {
        let text = try String(contentsOf: Self.contractURL, encoding: .utf8)
        let lines = text.components(separatedBy: "\n")

        var offenders: [String] = []
        var block: [(line: Int, pipes: Int)] = []
        func flush() {
            defer { block = [] }
            if block.count == 1 {
                offenders.append("表块只有 1 行（:\(block[0].line)）—— 多半是表头被劈开，或表格只剩一行")
                return
            }
            let counts = Set(block.map(\.pipes))
            guard counts.count > 1 else { return }
            let majority = block.map(\.pipes).sorted().middleValue
            let odd = block.filter { $0.pipes != majority }.map { ":\($0.line)(\($0.pipes) 个管道符)" }
            offenders.append("表块起于 :\(block[0].line)，异常行 \(odd.joined(separator: "、"))")
        }
        for (idx, line) in lines.enumerated() {
            let line = line.hasPrefix("    ") ? line : String(line.drop(while: { $0 == " " }))
            if line.hasPrefix("|") {
                block.append((idx + 1, line.filter { $0 == "|" }.count))
            } else {
                flush()
            }
        }
        flush()

        #expect(offenders.isEmpty, """
        公约里有表格行被裸换行劈开：
        \(offenders.joined(separator: "\n"))

        ⚠️ 被劈开的行在渲染器里**掉出表格**变成普通段落，而**测试全绿、grep 也命中** ——
        只有本判据看得见。⇒ 把续行折回同一个单元格（表格单元格内不能有裸换行），
        或把那段内容移到表格外面。
        """)
    }

    @Test("公约文本提及守卫允许域里的每一个取值（终审 I1(b)：给通则装上牙）")
    func contractMentionsEveryGuardAllowedValue() throws {
        let text = try String(contentsOf: Self.contractURL, encoding: .utf8)
        #expect(text.count > 1000, "公约文档只有 \(text.count) 字符 —— 疑似没读到或是个空壳")

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

private extension Array where Element == Int {
    var middleValue: Int { self[self.count / 2] }
}
