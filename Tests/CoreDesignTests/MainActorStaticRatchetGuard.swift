import Foundation
import Testing

// MARK: - 公开 static 的 MainActor 隔离棘轮：树内看门人 / MainActor static ratchet gate (Issue #307)

@Suite("#307 公开 static 的 MainActor 隔离棘轮不得被静默拆掉")
struct MainActorStaticRatchetGuard {
    // MARK: - 被钉住的常量

    nonisolated static let scriptRelativePath = "scripts/mainactor-static-ratchet.sh"

    nonisolated static let exemptionsRelativePath = "docs/mainactor-static-exemptions.txt"

    nonisolated static let judgementCount = 19

    nonisolated static var ownSourceURL: URL {
        GuardScanRoots.repoRoot
            .appendingPathComponent("Tests/CoreDesignTests/MainActorStaticRatchetGuard.swift")
    }

    nonisolated static let jobName = "swiftpm"

    nonisolated static let expectedRunCommand = "bash scripts/mainactor-static-ratchet.sh"

    nonisolated static let scriptMarker = "scripts/mainactor-static-ratchet.sh"

    nonisolated static let registeredExemptions: Set<String> = [
        "CoreDesign:SidebarTextStyle.primary",
        "CoreDesign:SidebarTextStyle.secondary",
        "CoreDesign:SidebarTextStyle.tertiary",
        "CoreDesign:BottomInputBarDefaults.placeholder",
        "CoreDesign:CoreElevation.spec(for:)",
    ]

    nonisolated static let requiredScriptLiterals: [(literal: String, reason: String)] = [
        (
            #"STATIC_KINDS = {"swift.type.property", "swift.type.method", "swift.type.subscript"}"#,
            "筛的三种 static 型成员 kind。少一种（或名字打错一个字母）⇒ 那一类成员静默漏筛，脚本照样 exit 0"
        ),
        (
            #"PUBLIC_LEVELS = {"public", "open"}"#,
            #"""
            可见性筛。⚠️ **整条今天都是空跑**，不只是 `open` 那一半：`dump-symbol-graph` 的
            `--minimum-access-level` 默认就是 `public`，本轮实测整张图 50432 个符号的
            `accessLevel` 全是 `public`。写在这里是为了将来加 open class、或有人把门槛
            调低时不静默漏掉
            """#
        ),
        (
            #"swift package dump-symbol-graph --minimum-access-level public > "$DUMP_LOG""#,
            #"""
            dump 那条命令**整条**，含**显式**写死的可见性门槛。删掉门槛 ⇒ 退回 SwiftPM
            的默认值，而 `PUBLIC_LEVELS` 那条筛的非空性完全建立在那个默认值上（今天默认
            恰好是 `public`，脚本照样 exit 0）——那正是「一条判据的前提没被钉住」的形态。
            ⚠️ **钉整条而不是只钉 `--minimum-access-level public` 那个 flag**：那个 flag
            在 `7c8c07e` 上出现**两次**（真 flag + 脚本头注释里的一份逐字副本），
            `contains` 会被注释那份满足 ⇒ 删掉真 flag 两侧全绿（PR #314 第 2 轮终审 C-1 实测）。
            ⚠️ **`98f551b` 已把注释那份改写成不再逐字重复**，所以今天全文计数已是 1 次
            （实测：`7c8c07e` full=2 / `98f551b` 起 full=1）——**别把这条理由读成现在时**。
            钉整条的理由不受影响，因为整条只在真命令那一行出现
            """#
        ),
        (
            #"SYNTHESIZED_MARK = "::SYNTHESIZED::""#,
            #"""
            **范围定案的另一半**（不是「顺手剔噪音」）：symbol graph 把写在协议扩展上的成员
            **复制**一份到每个具体遵从类型上、挂 `::SYNTHESIZED::`。不剔的话 `CoreDesign`
            从 42 涨到 56、`CoreDesignEffects` 从 32 涨到 78，多出的 58 条里有 **46 条正是
            被文件筛选挡在门外的那 46 条转场 / style 工厂**（本轮逐条同名核对），
            另 12 条是 `Transition.properties` 默认实现。⚠️ 这条理由曾写「多出的 14 条不是
            本包写的声明」——**那是错的**：`CoreDesign` 那 14 条里 12 条恰恰是本包写的声明
            （`CircularGlassButtonStyle.circularGlass` / `CoreProgressViewStyle.core` / …），
            只是换了个键，且其中 12 条带 `@MainActor`
            """#
        ),
        (
            #"ISOLATION_MARK = "@MainActor""#,
            #"""
            隔离判定本身。⚠️ 两个方向都会红，**没有静默失效的方向**：改成匹配不上的串
            ⇒ 命中恒为空集，空集与豁免表不等 ⇒ 红；改成恒真的空串 ⇒ 本轮实测
            **exit 1，把 74 条 unregistered 全报出来**——恒真是最吵的失效形态，不是最危险的
            （这句原来写反了）。钉它是为了钉住「判的是 `@MainActor` 这件事」本身
            """#
        ),
        (
            "unregistered = sorted(actual - expected)",
            "差集的**一半**：新增的 MainActor static。删掉它 ⇒ 棘轮只剩「表里的条目还在不在」，对新增完全失明，而脚本照样 exit 0"
        ),
        (
            "stale = sorted(expected - actual)",
            "差集的**另一半**：表里已过期的条目。删掉它 ⇒ 表会慢慢变成一张没人核对过的旧账"
        ),
        (
            "empty = [t for t, n in population.items() if n == 0]",
            "防空转网：任一 target 候选面为 0 就判红。删掉它 ⇒ 一个把 kind 名字打错的 typo 会让整条判据永远绿"
        ),
        (
            "if not os.path.isfile(path):",
            "fail-closed：某个 target 的主 symbols 文件缺席时判红而不是「零命中 ⇒ 零违规」"
        ),
        (
            #"cross = os.path.join(symbolgraph_dir, "%s@%s.symbols.json" % (target, other))"#,
            #"""
            **包内跨 target** 的扩展块文件也要扫。删掉它 ⇒ `CoreDesignEffects` /
            `CoreDesignCharts` 往 `CoreDesign` 的公开类型（109 个里 62 个带 `@MainActor`）
            上加公开 static 时，成员落进 `<Target>@CoreDesign.symbols.json` 而无人看见。
            ⚠️ 这一族**今天零个文件** ⇒ 删掉它脚本照样 exit 0，正是本文件要接住的形态
            """#
        ),
        (
            #"EXEMPTIONS="$REPO_ROOT/docs/mainactor-static-exemptions.txt""#,
            #"""
            脚本读的豁免表路径，钉**整条赋值**。改指别处 ⇒ 本文件钉的表与脚本比的表分了家。
            ⚠️ **钉整条而不是只钉 `docs/mainactor-static-exemptions.txt` 那个路径**：那个路径
            在脚本里出现**三次**（真赋值 + 头注释 + stderr 文案；实测 `7c8c07e` 与 `98f551b`
            都是 full=3、非注释行 2 次）⇒「把赋值改指别处、并在那里放一份同名副本」
            这条**完整失效链**当时两侧全绿（PR #314 第 2 轮终审 C-1 实测）。
            ⚠️ 这一条与上面那条 dump 命令不同，**它的计数今天仍是现在时**
            """#
        ),
    ]

    nonisolated static let blockedJobKeys: [(key: String, reason: String, topLevelReason: String)] = [
        (
            "if",
            "这个 job 可能在某些事件上压根不跑",
            "workflow 顶层没有 `if:` 这个合法键 —— 出现它说明这份 workflow 的形态不是判据假定的那样，fail-closed 判红"
        ),
        (
            "needs",
            "上游 job 被跳过时这个 job 会跟着不跑（`bool-ratchet` 就带着 `if:`）",
            "workflow 顶层没有 `needs:` 这个合法键 —— 同上，fail-closed 判红"
        ),
        (
            "continue-on-error",
            "这道闸判红也不会让 job 判红",
            "workflow 顶层没有 `continue-on-error:` 这个合法键 —— 同上，fail-closed 判红"
        ),
        (
            "defaults",
            #"""
            `run.shell` 可被改写成 `bash -c "exit 0" {0}`，这一步会以退出码 0 空转
            ——GitHub 的自定义 shell 模板是 `<command> […options] {0}`，于是整步变成
            `bash -c "exit 0" <脚本路径>`，脚本一行都不跑（PR #314 第 2 轮终审 C-2 实测：
            job 级与 workflow 级两种写法当时都判绿，而**同一个 `shell:` 写在 step 上就判红**）。
            这个 job 今天不需要 `defaults:` ⇒ 拦掉它零假红成本
            """#,
            #"""
            写在顶层的 `defaults:` 会被**每个 job 继承** ⇒ `swiftpm` job 同样吃到
            `run.shell`，这一步以退出码 0 空转（GitHub 的自定义 shell 模板是
            `<command> […options] {0}`）。这份 workflow 今天顶层不需要 `defaults:`
            ⇒ 拦掉它零假红成本
            """#
        ),
    ]

    nonisolated static let allowedStepKeys: Set<String> = [
        "name", "run", "env", "working-directory", "uses", "with",
    ]

    nonisolated static let stepKeyDangerNotes: [String: String] = [
        "if": "这一步可能压根不跑",
        "continue-on-error": "这一步判红也不会让 job 判红",
        "shell": "覆写掉默认的 `bash -e -o pipefail`，失败可能不再传导到 step 退出码",
    ]

    // MARK: - 路径

    nonisolated static var workflowURL: URL {
        GuardScanRoots.repoRoot.appendingPathComponent(".github/workflows/ci.yml")
    }

    nonisolated static var scriptURL: URL {
        GuardScanRoots.repoRoot.appendingPathComponent(Self.scriptRelativePath)
    }

    nonisolated static var exemptionsURL: URL {
        GuardScanRoots.repoRoot.appendingPathComponent(Self.exemptionsRelativePath)
    }

    // MARK: - 纯函数（合成输入可直接喂，AD-E 要求每条断言都有能触发红的 fixture）

    nonisolated static func indentation(of line: String) -> Int {
        line.prefix { $0 == " " }.count
    }

    nonisolated static func occurrences(of literal: String, in text: String) -> Int {
        guard !literal.isEmpty else { return 0 }
        var count = 0
        var cursor = text.startIndex
        while let found = text.range(of: literal, range: cursor..<text.endIndex) {
            count += 1
            cursor = found.upperBound
        }
        return count
    }

    nonisolated static func isSkippable(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty || trimmed.hasPrefix("#")
    }

    nonisolated static func exemptionEntries(inTable text: String) -> [String] {
        text.split(omittingEmptySubsequences: false, whereSeparator: { $0.isNewline })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
    }

    nonisolated static func keyName(ofLine line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let colon = trimmed.firstIndex(of: ":") else { return nil }
        var key = String(trimmed[trimmed.startIndex..<colon])
            .trimmingCharacters(in: .whitespaces)
        for quote in ["\"", "'"]
        where key.count >= 2 && key.hasPrefix(quote) && key.hasSuffix(quote) {
            key = String(key.dropFirst().dropLast())
        }
        return key.trimmingCharacters(in: .whitespaces)
    }

    nonisolated static func valuePart(ofLine line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let colon = trimmed.firstIndex(of: ":") else { return nil }
        return String(trimmed[trimmed.index(after: colon)...])
            .trimmingCharacters(in: .whitespaces)
    }

    nonisolated static func isBlockScalarIndicator(_ value: String) -> Bool {
        guard let first = value.first, first == "|" || first == ">" else { return false }
        return value.dropFirst().allSatisfy { $0.isNumber || $0 == "-" || $0 == "+" }
    }

    nonisolated static func stepBlocks(inJobBlock block: String) -> [String] {
        let lines = block.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let stepsIndex = lines.firstIndex(where: {
            $0.trimmingCharacters(in: .whitespaces) == "steps:"
        }) else { return [] }
        let stepsIndent = Self.indentation(of: lines[stepsIndex])

        var items: [[String]] = []
        var itemIndent: Int?
        var cursor = stepsIndex + 1
        while cursor < lines.count {
            let line = lines[cursor]
            if !Self.isSkippable(line) {
                let indent = Self.indentation(of: line)
                if indent <= stepsIndent { break }
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("- "), itemIndent == nil || indent == itemIndent {
                    itemIndent = indent
                    items.append([line])
                    cursor += 1
                    continue
                }
            }
            if !items.isEmpty { items[items.count - 1].append(line) }
            cursor += 1
        }
        return items.map { $0.joined(separator: "\n") }
    }

    nonisolated static func directChildKeys(inStep step: String) -> [(key: String?, line: String)] {
        let lines = step.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let firstIndex = lines.firstIndex(where: { !Self.isSkippable($0) }) else { return [] }
        let first = lines[firstIndex]
        let dashIndent = Self.indentation(of: first)
        let afterIndent = first.dropFirst(dashIndent)
        guard afterIndent.hasPrefix("-") else { return [] }
        let gap = afterIndent.dropFirst().prefix { $0 == " " }.count
        let childIndent = dashIndent + 1 + gap

        let head = String(afterIndent.dropFirst(1 + gap))
        var out: [(key: String?, line: String)] = [(Self.keyName(ofLine: head), head)]
        for line in lines[(firstIndex + 1)...] where !Self.isSkippable(line) {
            guard Self.indentation(of: line) == childIndent else { continue }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            out.append((Self.keyName(ofLine: trimmed), trimmed))
        }
        return out
    }

    nonisolated static func disallowedStepKeys(inStep step: String) -> [String] {
        var hits: [String] = []
        for entry in Self.directChildKeys(inStep: step) {
            guard let key = entry.key else {
                hits.append(
                    """
                    直接子键那一层出现了一行不含 `:` 的内容：`\(entry.line)`
                    ——解析规则之外的形态，判红而不是当作零违规。
                    """
                )
                continue
            }
            if Self.allowedStepKeys.contains(key) { continue }
            let note = Self.stepKeyDangerNotes[key].map { "（\($0)）" } ?? ""
            hits.append(
                """
                不在允许清单里的直接子键 `\(key):`\(note)
                ⚠️ 这里是**正面清单**（`allowedStepKeys`），与 `expectedRunCommand` 同一条纪律：
                `if:` / `continue-on-error:` / `shell:` 的同义拼法（`"if": false` /
                `'if': false` / `if : false` …）按负面清单追不完。
                这一步确实需要一个新键时，把它加进 `allowedStepKeys` 并说明理由。
                """
            )
        }
        return hits
    }

    nonisolated static func runLineIsInlineScalar(inStep step: String) -> [String] {
        let runValues = Self.directChildKeys(inStep: step)
            .filter { $0.key == "run" }
            .compactMap { Self.valuePart(ofLine: $0.line) }
        if runValues.isEmpty {
            return ["跑棘轮的那个 step 上找不到 `run:` 这个直接子键 —— 解析失效，判红而不是当作零违规"]
        }
        return runValues.filter { $0 != Self.expectedRunCommand }.map {
            """
            跑棘轮的那个 step 的 `run:` **不是行内标量**，或值不逐字等于期望命令：
            实际值：\($0)
            期望值：\(Self.expectedRunCommand)
            ⚠️ 值是 `|` / `>` 之类 ⇒ 那条 `run:` 被改成了**块标量**。块标量能在命令旁边
            塞兄弟行（`exit 0` / `trap 'exit 0' ERR`），而按行比对的那条判据抓不到。
            这一步的 `run:` 请保持单行；确实要改，先改 `expectedRunCommand` 并说明理由。
            """
        }
    }

    nonisolated static func runScalarContinuationLines(inStep step: String) -> [String] {
        let lines = step.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let firstIndex = lines.firstIndex(where: { !Self.isSkippable($0) }) else { return [] }
        let first = lines[firstIndex]
        let dashIndent = Self.indentation(of: first)
        let afterIndent = first.dropFirst(dashIndent)
        guard afterIndent.hasPrefix("-") else { return [] }
        let gap = afterIndent.dropFirst().prefix { $0 == " " }.count
        let childIndent = dashIndent + 1 + gap

        let head = String(afterIndent.dropFirst(1 + gap))
        var currentKey = Self.keyName(ofLine: head)
        var currentValue = Self.valuePart(ofLine: head)
        var hits: [String] = []
        for line in lines[(firstIndex + 1)...] where !Self.isSkippable(line) {
            let indent = Self.indentation(of: line)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if indent == childIndent {
                currentKey = Self.keyName(ofLine: trimmed)
                currentValue = Self.valuePart(ofLine: trimmed)
                continue
            }
            if indent < childIndent {
                currentKey = nil
                currentValue = nil
                continue
            }
            guard currentKey == "run",
                  let value = currentValue,
                  !Self.isBlockScalarIndicator(value)
            else { continue }
            hits.append(
                """
                跑棘轮的那个 step 的 `run:` 底下还有更深缩进的续行：`\(trimmed)`
                ⚠️ YAML 的**普通标量可以跨行**：`run: <命令>` 底下加一行 `|| true`，
                解析器折叠之后就是 `<命令> || true`，退出码当场被中和，而按「`run:` 的值
                逐字」与「命令行逐字」比对的两条判据都看不见它。
                这一步的 `run:` 请保持**单行单标量**；确实要改，先改 `expectedRunCommand`。
                """
            )
        }
        return hits
    }

    nonisolated static func blockedTopLevelKeys(inWorkflow yaml: String) -> [String] {
        var hits: [String] = []
        let lines = yaml.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        for line in lines where !Self.isSkippable(line) && Self.indentation(of: line) == 0 {
            guard let key = Self.keyName(ofLine: line) else { continue }
            for entry in Self.blockedJobKeys where key == entry.key {
                hits.append("`\(entry.key):`：\(entry.topLevelReason)")
            }
        }
        return hits
    }

    nonisolated static func blockedJobLevelKeys(inJobBlock block: String) -> [String] {
        let lines = block.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let first = lines.first(where: { !Self.isSkippable($0) }) else { return [] }
        let keyIndent = Self.indentation(of: first)
        var hits: [String] = []
        for line in lines where !Self.isSkippable(line) {
            guard Self.indentation(of: line) == keyIndent else { continue }
            guard let key = Self.keyName(ofLine: line) else { continue }
            for entry in Self.blockedJobKeys where key == entry.key {
                hits.append("`\(entry.key):`：\(entry.reason)")
            }
        }
        return hits
    }

    nonisolated static func violations(inWorkflow yaml: String) -> [String] {
        var problems: [String] = Self.blockedTopLevelKeys(inWorkflow: yaml).map {
            "workflow **顶层**的直接子键里出现 \($0)"
        }
        guard let block = DownstreamProbeGateGuard.jobBlock(inWorkflow: yaml, job: Self.jobName)
        else {
            problems.append("解析失效：workflow 里找不到 `jobs:` 下的 `\(Self.jobName):` 块")
            return problems
        }

        let commands = DownstreamProbeGateGuard.runCommands(inJobBlock: block)
        let realLines = commands.flatMap { DownstreamProbeGateGuard.commandLines(inRunCommand: $0) }
        let candidates = realLines.filter { $0.contains(Self.scriptMarker) }

        if candidates.isEmpty {
            problems.append(
                """
                `\(Self.jobName)` job 里找不到跑 `\(Self.scriptMarker)` 的 `run:`。
                这一步是 `#307` 棘轮唯一真正执行判据的地方——没有它，
                `docs/mainactor-static-exemptions.txt` 只是一张没人核对的表。
                """
            )
        }
        for line in candidates where line != Self.expectedRunCommand {
            problems.append(
                """
                跑 `\(Self.scriptMarker)` 的那一行不是逐字的期望命令：
                实际：\(line)
                期望：\(Self.expectedRunCommand)
                ⚠️ 尾巴（` || true` / ` ; true` / ` | tee …`）会把脚本的非零退出码中和掉；
                合法后缀（`--verbose` 之类）同样判红——这是**正面清单**，按拼法追不完。
                要改写这一行，同时改 `expectedRunCommand`。
                """
            )
        }

        problems.append(contentsOf: Self.blockedJobLevelKeys(inJobBlock: block).map {
            "`\(Self.jobName)` job 的直接子键里出现 \($0)"
        })

        let steps = Self.stepBlocks(inJobBlock: block)
        let owning = steps.filter { $0.contains(Self.scriptMarker) }
        if candidates.isEmpty == false, owning.isEmpty {
            problems.append(
                """
                解析失效：命令行里找得到 `\(Self.scriptMarker)`，却切不出含它的 step 块
                ——`steps:` 的缩进形态变了。判据失去依据，判红而不是当作零违规。
                """
            )
        }
        for step in owning {
            problems.append(contentsOf: Self.disallowedStepKeys(inStep: step).map {
                "跑棘轮的那个 step 上出现 \($0)"
            })
            problems.append(contentsOf: Self.runLineIsInlineScalar(inStep: step))
            problems.append(contentsOf: Self.runScalarContinuationLines(inStep: step))
        }
        return problems
    }

    nonisolated static func violations(inScript script: String) -> [String] {
        let executable = Self.nonCommentText(ofScript: script)
        return Self.requiredScriptLiterals.compactMap { entry in
            let hits = Self.occurrences(of: entry.literal, in: executable)
            guard hits != 1 else { return nil }
            return """
                脚本的**非注释行**里，这条逐字片段出现了 \(hits) 次，必须**恰好 1 次**：
                \(entry.literal)
                这一条为什么必须在：\(entry.reason)
                ⚠️ 0 次 = 判据被删（**含**「删掉真的那一份、只在注释里留一份逐字副本」这种搬家）；
                ≥2 次 = 真代码里出现了第二份，两份里删掉哪一份都不会有人看见。
                ⚠️ 注释行不计数 ⇒ 在注释里逐字提这条片段是**允许**的。
                ⚠️ 但只剥**整行**注释：行尾注释（`cmd  # <副本>`）、`echo` 字符串、
                heredoc 正文、python 多行字符串里的副本都照样计数 ⇒ 这四种搬家实测仍全绿
                （各 11/11）。门槛抬高了，门没关死。
                ⚠️ ≥2 的补救（这是真实的假红成本：保留真的那份、另加一条**合法**的
                `echo` 提及，实测 11 条 pin 全部判红）：把那句措辞改写成不逐字重复，
                或把这条 pin 换成更长的、只可能出现在真代码里的唯一片段。
                """
        }
    }

    nonisolated static func nonCommentText(ofScript script: String) -> String {
        script
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { !Self.isSkippable($0) }
            .joined(separator: "\n")
    }

    // MARK: - 判据（全部**无条件**，没有任何 `.enabled(if:)`）

    @Test("豁免表与树内登记逐条相符（双向差集）")
    func exemptionTableMatchesRegisteredTable() throws {
        #expect(
            Self.registeredExemptions.count == 5,
            """
            `registeredExemptions` 的条数变了（期望 5，实际 \(Self.registeredExemptions.count)）。
            往豁免表里加一行是破例动作：默认处置是给那个成员加 `nonisolated`。
            确实修不掉才登记，并同轮改这个数。
            """
        )
        let text = try String(contentsOf: Self.exemptionsURL, encoding: .utf8)
        let entries = Self.exemptionEntries(inTable: text)

        #expect(
            entries.count == Set(entries).count,
            "豁免表里有重复行：\(entries.filter { entry in entries.filter { $0 == entry }.count > 1 })"
        )
        #expect(
            !entries.isEmpty,
            "豁免表一条都没有——那不是「本包没有 MainActor 隔离的公开 static」，是表被清空了"
        )

        let actual = Set(entries)
        let extra = actual.subtracting(Self.registeredExemptions).sorted()
        let missing = Self.registeredExemptions.subtracting(actual).sorted()
        #expect(
            extra.isEmpty,
            """
            豁免表里多出这些条目，而 `registeredExemptions` 没登记：\(extra)
            ⚠️ 往表里加一行是**破例动作**：默认处置是给那个成员（或它的 enclosing type）
            加 `nonisolated`。确实修不掉才登记，且必须同轮更新本文件的 `registeredExemptions`
            与表里那条「为什么修不掉」的说明。
            """
        )
        #expect(
            missing.isEmpty,
            """
            `registeredExemptions` 登记了这些条目，而豁免表里没有：\(missing)
            要么是修好了（那就把它从本文件也删掉），要么是表被人改瘦了。
            """
        )

        let known = Set(GuardScanRoots.targetNames)
        let strays = entries.filter { entry in
            guard let target = entry.split(separator: ":").first else { return true }
            return !known.contains(String(target))
        }
        #expect(
            strays.isEmpty,
            """
            这些豁免条目的 target 前缀不在 `GuardScanRoots.targetNames` 里：\(strays)
            脚本按 `<Target>.symbols.json` 逐 target 筛，前缀写错的条目**永远**匹配不上，
            会以「表里已过期」的形态一直红——那是假红，先修前缀。
            """
        )
    }

    @Test("脚本的筛条件与两半差集逐字在场")
    func scriptPinsTheFilterPredicate() throws {
        #expect(
            Self.requiredScriptLiterals.count == 11,
            """
            `requiredScriptLiterals` 的条数变了（期望 11，实际 \(Self.requiredScriptLiterals.count)）。
            少一条 ⇒ 那条筛条件从此可以被静默删掉；清空 ⇒ 整条 pin 空转（循环零次即空真）。
            确实要增删时，改这个数并在 PR 里说明增删的是哪一条、为什么。
            """
        )
        let script = try String(contentsOf: Self.scriptURL, encoding: .utf8)
        let problems = Self.violations(inScript: script)
        #expect(
            problems.isEmpty,
            "\(Self.scriptRelativePath) 的判据被改动了：\n\(problems.joined(separator: "\n\n"))"
        )
    }

    @Test("脚本存在且可执行")
    func scriptIsExecutable() {
        let path = Self.scriptURL.path
        #expect(
            FileManager.default.isExecutableFile(atPath: path),
            """
            \(Self.scriptRelativePath) 不存在或没有可执行位。
            ⚠️ `ci.yml` 那一步用 `bash <path>` 调它，缺可执行位在 CI 上**不会**红
            ——所以这条要在树内查。
            """
        )
    }

    @Test("ci.yml 的 swiftpm job 逐字跑棘轮，且这一步没被中和")
    func workflowRunsTheRatchet() throws {
        #expect(
            Self.blockedJobKeys.count == 4,
            "`blockedJobKeys` 的条数变了（期望 4，实际 \(Self.blockedJobKeys.count)）——减一条 ⇒ 那个中和键从此在 job / workflow 两级都放行"
        )
        #expect(
            Self.allowedStepKeys.count == 6,
            "`allowedStepKeys` 的条数变了（期望 6，实际 \(Self.allowedStepKeys.count)）——往里加键是放松判据，要有人看见"
        )
        let yaml = try String(contentsOf: Self.workflowURL, encoding: .utf8)
        let problems = Self.violations(inWorkflow: yaml)
        #expect(problems.isEmpty, "ci.yml 的棘轮闸出了问题：\n\(problems.joined(separator: "\n\n"))")
    }

    // MARK: - 合成输入（AD-E：每条断言都要有能触发红的 fixture）

    nonisolated static func syntheticWorkflow(runLine: String, stepKeys: [String] = []) -> String {
        var lines = [
            "name: CI",
            "on:",
            "  push:",
            "jobs:",
            "  swiftpm:",
            "    name: SwiftPM",
            "    runs-on: macos-26",
            "    steps:",
            "      - uses: actions/checkout@v4",
            "      - name: Test",
            "        run: swift test",
            "      - name: MainActor static ratchet",
        ]
        lines.append(contentsOf: stepKeys.map { "        \($0)" })
        lines.append("        run: \(runLine)")
        lines.append(contentsOf: [
            "      - name: Upload test logs",
            "        if: always()",
            "        uses: actions/upload-artifact@v4",
        ])
        return lines.joined(separator: "\n")
    }

    @Test("合成输入：一步都没有 ⇒ 判红")
    func syntheticWorkflowWithoutTheStepIsRejected() {
        let yaml = Self.syntheticWorkflow(runLine: "swift build")
        #expect(!Self.violations(inWorkflow: yaml).isEmpty)
    }

    @Test("合成输入：命令长出 `|| true` 尾巴 ⇒ 判红")
    func syntheticWorkflowWithNeutralizedExitCodeIsRejected() {
        let yaml = Self.syntheticWorkflow(runLine: "\(Self.expectedRunCommand) || true")
        #expect(!Self.violations(inWorkflow: yaml).isEmpty)
    }

    @Test("合成输入：加个合法后缀也判红（正面清单，不是关键词匹配）")
    func syntheticWorkflowWithBenignSuffixIsRejected() {
        let yaml = Self.syntheticWorkflow(runLine: "\(Self.expectedRunCommand) --verbose")
        #expect(!Self.violations(inWorkflow: yaml).isEmpty)
    }

    @Test("合成输入：`echo` 冒充命令 ⇒ 判红")
    func syntheticWorkflowWithProseIsRejected() {
        let yaml = Self.syntheticWorkflow(runLine: "echo \"\(Self.expectedRunCommand)\"")
        #expect(!Self.violations(inWorkflow: yaml).isEmpty)
    }

    @Test("合成输入：这一步被加上 `if:` ⇒ 判红（同 job 别的 step 的 `if:` 不算）")
    func syntheticWorkflowWithStepConditionIsRejected() {
        let clean = Self.syntheticWorkflow(runLine: Self.expectedRunCommand)
        #expect(Self.violations(inWorkflow: clean).isEmpty, "正对照：干净的合成输入必须判绿")
        let dirty = Self.syntheticWorkflow(
            runLine: Self.expectedRunCommand,
            stepKeys: ["if: github.event_name == 'pull_request'"]
        )
        #expect(!Self.violations(inWorkflow: dirty).isEmpty)
    }

    @Test("合成输入：job 被加上 `if:` / `needs:` ⇒ 判红")
    func syntheticWorkflowWithJobLevelConditionIsRejected() {
        for key in ["if: false", "needs: bool-ratchet", "continue-on-error: true"] {
            let yaml = Self.syntheticWorkflow(runLine: Self.expectedRunCommand)
                .replacingOccurrences(of: "    runs-on: macos-26", with: "    \(key)\n    runs-on: macos-26")
            #expect(!Self.violations(inWorkflow: yaml).isEmpty, "job 级 `\(key)` 应判红")
        }
    }

    @Test("合成输入：`if:` / `needs:` / `continue-on-error:` 的同义 YAML 拼法一样判红")
    func syntheticWorkflowWithEquivalentKeySpellingsAreRejected() {
        let clean = Self.syntheticWorkflow(runLine: Self.expectedRunCommand)
        #expect(Self.violations(inWorkflow: clean).isEmpty, "正对照：干净的合成输入必须判绿")

        for key in [#""if": false"#, "'if': false", "if : false", "continue-on-error : true"] {
            let yaml = Self.syntheticWorkflow(runLine: Self.expectedRunCommand, stepKeys: [key])
            #expect(!Self.violations(inWorkflow: yaml).isEmpty, "step 级 `\(key)` 应判红")
        }
        for key in [#""if": false"#, "needs : simulator"] {
            let yaml = clean.replacingOccurrences(
                of: "    runs-on: macos-26",
                with: "    \(key)\n    runs-on: macos-26"
            )
            #expect(!Self.violations(inWorkflow: yaml).isEmpty, "job 级 `\(key)` 应判红")
        }
    }

    @Test("合成输入：`run:` 改成块标量并加兄弟行 ⇒ 判红")
    func syntheticWorkflowWithBlockScalarRunIsRejected() {
        let yaml = [
            "name: CI",
            "on:",
            "  push:",
            "jobs:",
            "  swiftpm:",
            "    name: SwiftPM",
            "    runs-on: macos-26",
            "    steps:",
            "      - name: MainActor static ratchet",
            "        run: |",
            "          exit 0",
            "          \(Self.expectedRunCommand)",
        ].joined(separator: "\n")
        #expect(!Self.violations(inWorkflow: yaml).isEmpty)
    }

    @Test("合成输入：job 整个不见了 ⇒ 判红（不是 fail-open）")
    func syntheticWorkflowWithoutJobIsRejected() {
        let yaml = """
        name: CI
        jobs:
          simulator:
            runs-on: macos-26
        """
        #expect(!Self.violations(inWorkflow: yaml).isEmpty)
    }

    @Test("合成输入：脚本少了任意一条筛条件字面量 ⇒ 判红")
    func syntheticScriptMissingAnyLiteralIsRejected() throws {
        let script = try String(contentsOf: Self.scriptURL, encoding: .utf8)
        #expect(Self.violations(inScript: script).isEmpty, "正对照：真脚本必须判绿")
        for entry in Self.requiredScriptLiterals {
            let mutated = script.replacingOccurrences(of: entry.literal, with: "")
            #expect(
                !Self.violations(inScript: mutated).isEmpty,
                "删掉 `\(entry.literal)` 之后判据仍绿——这一条是空转的"
            )
        }
    }

    @Test("合成输入：某条筛条件字面量被「搬进注释」⇒ 判红")
    func syntheticScriptWithRelocatedLiteralIsRejected() throws {
        let script = try String(contentsOf: Self.scriptURL, encoding: .utf8)
        for entry in Self.requiredScriptLiterals {
            let relocated = script.replacingOccurrences(of: entry.literal, with: "")
                + "\n# 搬进注释的那一份：" + entry.literal + "\n"
            #expect(
                !Self.violations(inScript: relocated).isEmpty,
                """
                把 `\(entry.literal)` 从真代码里删掉、只在注释里留一份逐字副本之后判据仍绿
                ——这条 pin 挡不住「搬家」：脚本侧的判据已经没了，两侧却都不会红。
                """
            )
        }
    }

    @Test("合成输入：job 级 / workflow 级 `defaults: run: shell:` ⇒ 判红")
    func syntheticWorkflowWithInheritedShellDefaultsAreRejected() {
        let clean = Self.syntheticWorkflow(runLine: Self.expectedRunCommand)
        #expect(Self.violations(inWorkflow: clean).isEmpty, "正对照：干净的合成输入必须判绿")

        let jobLevel = clean.replacingOccurrences(
            of: "    runs-on: macos-26",
            with: [
                "    defaults:",
                "      run:",
                #"        shell: bash -c "exit 0" {0}"#,
                "    runs-on: macos-26",
            ].joined(separator: "\n")
        )
        #expect(!Self.violations(inWorkflow: jobLevel).isEmpty, "job 级 `defaults:` 应判红")

        let workflowLevel = clean.replacingOccurrences(
            of: "jobs:",
            with: [
                "defaults:",
                "  run:",
                #"    shell: bash -c "exit 0" {0}"#,
                "jobs:",
            ].joined(separator: "\n")
        )
        let workflowLevelProblems = Self.violations(inWorkflow: workflowLevel)
        #expect(
            !workflowLevelProblems.isEmpty,
            "workflow 级 `defaults:` 应判红（它会被每个 job 继承，`jobBlock` 看不见它）"
        )
        #expect(
            workflowLevelProblems.contains(where: { $0.contains("每个 job 继承") }),
            """
            顶层命中必须打印**顶层那一份**措辞（`topLevelReason`），不是 job 级那份
            ——后者的主语是「这个 job」，指错了一层。
            实际报出来的是：\(workflowLevelProblems)
            """
        )
    }

    @Test("合成输入：`run:` 折成跨行普通标量、续行挂 `|| true` ⇒ 判红")
    func syntheticWorkflowWithFoldedPlainScalarRunIsRejected() {
        let base = [
            "name: CI",
            "on:",
            "  push:",
            "jobs:",
            "  swiftpm:",
            "    name: SwiftPM",
            "    runs-on: macos-26",
            "    steps:",
            "      - name: MainActor static ratchet",
            "        run: \(Self.expectedRunCommand)",
        ]
        #expect(
            Self.violations(inWorkflow: base.joined(separator: "\n")).isEmpty,
            "正对照：只差那一行续行的干净输入必须判绿"
        )
        let yaml = (base + ["          || true"]).joined(separator: "\n")
        #expect(!Self.violations(inWorkflow: yaml).isEmpty)
    }

    @Test("合成输入：裸 `-` 单独一行的 step —— 唯一 step 时判红（解析失效），前面有正常 step 时判绿")
    func syntheticWorkflowWithBareDashStepIsRejected() {
        let bareDashOnly = [
            "name: CI",
            "on:",
            "  push:",
            "jobs:",
            "  swiftpm:",
            "    name: SwiftPM",
            "    runs-on: macos-26",
            "    steps:",
            "      -",
            "        name: MainActor static ratchet",
            "        run: \(Self.expectedRunCommand)",
        ].joined(separator: "\n")
        let bareDashProblems = Self.violations(inWorkflow: bareDashOnly)
        #expect(!bareDashProblems.isEmpty)
        #expect(
            bareDashProblems.contains(where: { $0.contains("切不出含它的 step 块") }),
            """
            期望走的是「解析失效：切不出含它的 step 块」那条分支
            （不是 `directChildKeys` 推错列——那是已登记假红 ⑤ 原来写错的机制）。
            实际报出来的是：\(bareDashProblems)
            """
        )

        let bareDashAfterNormalStep = [
            "name: CI",
            "on:",
            "  push:",
            "jobs:",
            "  swiftpm:",
            "    name: SwiftPM",
            "    runs-on: macos-26",
            "    steps:",
            "      - uses: actions/checkout@v4",
            "      -",
            "        name: MainActor static ratchet",
            "        run: \(Self.expectedRunCommand)",
        ].joined(separator: "\n")
        #expect(
            Self.violations(inWorkflow: bareDashAfterNormalStep).isEmpty,
            """
            登记的现状变了：裸 `-` 前面还有一个正常 step 时，今天它被吞进上一个 step ⇒ 判绿。
            如果这是因为 `stepBlocks` 被加强成也认裸 `-`，请改这条断言，不要改 `stepBlocks`。
            实际报出来的是：\(Self.violations(inWorkflow: bareDashAfterNormalStep))
            """
        )

        let prefix = [
            "name: CI",
            "on:",
            "  push:",
            "jobs:",
            "  swiftpm:",
            "    name: SwiftPM",
            "    runs-on: macos-26",
            "    steps:",
            "      - uses: actions/checkout@v4",
            "      -",
            "        name: MainActor static ratchet",
        ]
        let neutralizations: [(label: String, tail: [String], branch: String)] = [
            (
                "命令长出 `|| true` 尾巴",
                ["        run: \(Self.expectedRunCommand) || true"],
                "那一行不是逐字的期望命令"
            ),
            (
                "偷塞 `if:`",
                ["        if: false", "        run: \(Self.expectedRunCommand)"],
                "不在允许清单里的直接子键 `if:`"
            ),
            (
                "折行续行挂 `|| true`",
                ["        run: \(Self.expectedRunCommand)", "          || true"],
                "底下还有更深缩进的续行"
            ),
        ]
        for (label, tail, branch) in neutralizations {
            let yaml = (prefix + tail).joined(separator: "\n")
            let problems = Self.violations(inWorkflow: yaml)
            #expect(!problems.isEmpty, "被吞进上一个 step 之后，中和写法「\(label)」仍必须判红")
            #expect(
                problems.contains(where: { $0.contains(branch) }),
                """
                中和写法「\(label)」判红了，但走的不是期望那条分支（期望的特征子串：\(branch)）。
                实际报出来的是：\(problems)
                """
            )
        }
    }

    @Test("本 suite 的判据条数 = 钉住的那个数")
    func judgementCountIsPinned() throws {
        let source = try String(contentsOf: Self.ownSourceURL, encoding: .utf8)
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let declared = lines.filter { $0.hasPrefix("    @Test") }.count
        #expect(
            declared == Self.judgementCount,
            "本文件里 `@Test` 有 \(declared) 条，`judgementCount` 钉的是 \(Self.judgementCount) 条"
        )
    }
}
