import Foundation
import Testing

// MARK: - 公开 static 的 MainActor 隔离棘轮：树内看门人 / MainActor static ratchet gate (Issue #307)
//
// ## 被守的东西
//
// `scripts/mainactor-static-ratchet.sh` 从 `swift package dump-symbol-graph` 的产物里筛出
// 「公开 / open 的 static 型成员，且 `declarationFragments` 拼起来含 `@MainActor`」，
// 与 `docs/mainactor-static-exemptions.txt` 做**双向差集**。它替掉的是 `#290` 那份
// **一次性人工枚举**：`scripts/downstream-probe` 只钉住**它自己引用到的**符号，
// 新类型上新加的 `public static let` 它一个都看不见（`scripts/api-surface-diff.sh` 的
// 头注释自己就写了「它引用的符号是**手写清单**」）。
//
// ## 为什么判据不在 `swift test` 里，而本文件在
//
// `swift package dump-symbol-graph` 是一次完整的 SwiftPM 调用（本机热 `.build` 上实测
// 约 100s，写出约 265 MB JSON），从 `swift test` 里 spawn 它有嵌套构建锁的风险，
// 也会给**每一次**本地 `swift test` 加上这个开销。⇒ 判据落在脚本 + `ci.yml` 的
// `swiftpm` job 一步（复用 `swift test` 之后的热 `.build`），与 `downstream-probe` /
// `bool-ratchet` 同形。
//
// 而「判据在 CI」立刻带来 `#304` F-4 那个坑：**CI 配置无人看守**。本文件就是那道看守，
// 它**无条件**（没有任何 `.enabled(if:)`）随每次 `swift test` 跑，钉三样东西：
//
// 1. **豁免表逐条** —— `registeredExemptions` 与 `docs/mainactor-static-exemptions.txt`
//    做双向差集。往表里偷加一行、或把表清空，本文件当场红。
//    ⚠️ 这不是「重复一遍脚本做的事」：脚本比的是「symbol graph ↔ 表」，本文件比的是
//    「表 ↔ 树内常量」。两条链路串起来才是「新加的 MainActor static 一定会有人看见」。
// 2. **脚本的筛条件字面量** —— `requiredScriptLiterals` 逐条 `contains`。
//    把 `stale` 那一半差集删掉、把候选面归零的防空转网删掉、把 kind 名字打错，
//    这些改法都不会让脚本自己判红（它照样 exit 0），只有本文件会红。
// 3. **`ci.yml` 里那一步** —— 那条 `run:` 逐字，且它所在 step 与 job 上不许出现
//    `if:` / `continue-on-error:` / `needs:` 这类中和键。
//
// ## ⚠️ 射程与已知缺口（不要读成比实际更强）
//
// · **扩展块成员完全不在射程内**（这是脚本《范围定案与代价》那一节买单的那一侧，
//   照录到这里，别只在一处登记）：`dump-symbol-graph` 把「声明在外来类型上的成员」
//   （`extension Color` / `extension Transition` / `extension ButtonStyle` …）写进
//   `<Target>@<外来模块>.symbols.json`，而脚本**只读 `<Target>.symbols.json`**。
//   ⇒ 往 `public extension Color` 上新加一个 MainActor 隔离的 `public static let`，
//   **本棘轮不会红**。本轮实测：那三个 `@…` 文件里 `@MainActor` 命中共 46 条
//   （`CoreDesign@SwiftUI` 12 + `CoreDesignEffects@SwiftUICore` 34，
//   `CoreDesign@SwiftUICore` 的 285 个色彩 token 命中为 0），全部是转场 / style 工厂
//   ——它们的隔离来自 SwiftUI 协议本身，本来就该是 `@MainActor`。把它们收进射程
//   意味着每加一条转场就要改豁免表，棘轮会退化成橡皮图章。**这是有意的取舍，代价是
//   一块真实的盲区，且空间开放。**
//
// · **本文件不验证「脚本跑出来是对的」** —— 它只验证脚本的**筛条件字面量**在场。
//   把 python 段整段换成 `sys.exit(0)`、或在 `set -euo pipefail` 之后加
//   `trap "exit 0" ERR`，`requiredScriptLiterals` 那几条 `contains` 照样满足
//   （字面量还在文件里，只是不再被执行）。⇒ 与 `DownstreamProbeGateGuard` 头注释
//   「selftest 脚本自己的断言逻辑无人看守」是**同一条缺口**，同样**未修、只登记**。
//   兜住它的不是判据，是脚本在 CI 上每次真的跑一遍：它判红过（见 PR #307 的变异实证）。
//
// · **兄弟行不设防** —— 与 `DownstreamProbeGateGuard` 第 6 类同款：那条 `run:` 逐字保留、
//   在它上面加一行 `exit 0` / `trap 'exit 0' ERR`，本文件全绿而这一步什么也没做。
//   ⇒ 这一步的 `run:` 请**保持单行**（`ci.yml` 那段注释里也写了同一句）。
//   ⚠️ **有意只登记、不加正则**：给 `^exit 0` / `trap .*ERR` 各加一条正则，正是
//   `#304` 第 4 轮终审明确不建议的「按拼法打补丁」路线。
//
// · **`swiftpm` job 上的 `if:` 只堵 job 级与本 step 级** —— 该 job 的
//   「Upload test logs」step 带着 `if: always()`（合法且必要），所以不能像
//   `DownstreamProbeGateGuard` 那样对整个 job 块做 `contains("if:")`。本文件改成
//   **按缩进定位**：job 的直接子键、以及**含那条 `run:` 的那个 step** 两处各查一遍。
//   ⇒ **别的 step 上的 `if:` 不判红**（也不该判红）。而 workflow 级 `on:` 收窄 /
//   `paths-ignore:` / 假的 `runs-on:` 与 `DownstreamProbeGateGuard` 登记的一样**仍敞着**。

@Suite("#307 公开 static 的 MainActor 隔离棘轮不得被静默拆掉")
struct MainActorStaticRatchetGuard {

    // MARK: - 被钉住的常量

    /// 判据脚本（仓库相对路径）。
    nonisolated static let scriptRelativePath = "scripts/mainactor-static-ratchet.sh"

    /// 豁免表（仓库相对路径）。脚本与本文件的**唯一**共同数据源。
    nonisolated static let exemptionsRelativePath = "docs/mainactor-static-exemptions.txt"

    /// 承载那一步的 job 名。
    ///
    /// ⚠️ 有意搭 `swiftpm` 而不是另起一个 job：那一步要复用 `swift test` 跑完之后的
    /// **热 `.build`**（`dump-symbol-graph` 仍要重跑一遍符号提取，本机实测约 100s；
    /// 冷树上还要先整包构建一次）。另起 job 会多起一台 macOS runner，按 10× 计费。
    nonisolated static let jobName = "swiftpm"

    /// 那条 `run:` 的**整条**逐字文本。
    ///
    /// ⚠️ 与 `DownstreamProbeGateGuard.expectedProbeBuildCommand` 同一条纪律：这是**正面
    /// 清单**，不是「含某个关键词」。给它加**任何**尾巴都判红——` || true` / ` ; true` /
    /// ` | tee ratchet.log` / 甚至合法的 `--verbose`。理由：中和退出码的拼法按正则追不完
    /// （`#304` 第 3 轮 I-A 那一族的教训）。要改写这一行，同时改这里。
    nonisolated static let expectedRunCommand = "bash scripts/mainactor-static-ratchet.sh"

    /// 认出「这一行想跑那个脚本」的识别特征（不含 `bash ` 前缀）。
    ///
    /// 用它先把候选行捞出来，再拿 `expectedRunCommand` 逐字比——这样「标志还在但长了尾巴」
    /// 报的是「长出尾巴」而不是「找不到这一步」，两种失效形态的报错不会混。
    nonisolated static let scriptMarker = "scripts/mainactor-static-ratchet.sh"

    /// 已登记的豁免，**逐条**。
    ///
    /// ⚠️ 这不是「允许清单」而是「已知修不掉清单」：新加的公开 static 成员默认被
    /// `.defaultIsolation(MainActor.self)` 卷进 MainActor，处置是**给它加 `nonisolated`**，
    /// 不是往这里补一行。补一行之前先读 `docs/mainactor-static-exemptions.txt` 里
    /// 每条现有豁免下面写的「为什么修不掉」，并给新条目写一条同等分量的。
    nonisolated static let registeredExemptions: Set<String> = [
        "CoreDesign:SidebarTextStyle.primary",
        "CoreDesign:SidebarTextStyle.secondary",
        "CoreDesign:SidebarTextStyle.tertiary",
        "CoreDesign:BottomInputBarDefaults.placeholder",
        "CoreDesign:CoreElevation.spec(for:)",
    ]

    /// 脚本里必须**逐字**在场的片段，每条附「删掉它会怎样」。
    ///
    /// ⚠️ 选的都是**删掉之后脚本仍然 exit 0** 的东西——那才是本文件存在的理由。
    /// 语法错误、路径写错之类，脚本自己在 CI 上就会红，不需要在这里重复一遍。
    nonisolated static let requiredScriptLiterals: [(literal: String, reason: String)] = [
        (
            #"STATIC_KINDS = {"swift.type.property", "swift.type.method", "swift.type.subscript"}"#,
            "筛的三种 static 型成员 kind。少一种（或名字打错一个字母）⇒ 那一类成员静默漏筛，脚本照样 exit 0"
        ),
        (
            #"PUBLIC_LEVELS = {"public", "open"}"#,
            "可见性筛。`open` 目前是空跑（本包没有 open class），写在这里是为了将来加 open class 时不静默漏掉"
        ),
        (
            #"SYNTHESIZED_MARK = "::SYNTHESIZED::""#,
            "剔掉协议默认实现合成出来的成员——不剔的话 `CoreDesign` 侧会从 42 涨到 56，多出的 14 条不是本包写的声明"
        ),
        (
            #"ISOLATION_MARK = "@MainActor""#,
            "隔离判定本身。改成别的串 ⇒ 命中恒为空集，而空集与豁免表不等 ⇒ 这一条其实会红；真正危险的是把它改成一个恒真的串"
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
            "docs/mainactor-static-exemptions.txt",
            "脚本读的豁免表路径。改指别处 ⇒ 本文件钉的表与脚本比的表分了家"
        ),
    ]

    /// job 的**直接子键**上不许出现的键。
    nonisolated static let blockedJobKeys: [(key: String, reason: String)] = [
        ("if:", "这个 job 可能在某些事件上压根不跑"),
        ("needs:", "上游 job 被跳过时这个 job 会跟着不跑（`bool-ratchet` 就带着 `if:`）"),
        ("continue-on-error:", "这道闸判红也不会让 job 判红"),
    ]

    /// **含那条 `run:` 的那个 step** 上不许出现的键。
    ///
    /// ⚠️ 与 `blockedJobKeys` 分开，且**只查这一个 step**：同 job 的「Upload test logs」
    /// step 带着 `if: always()`，那是合法且必要的。
    nonisolated static let blockedStepKeys: [(key: String, reason: String)] = [
        ("if:", "这一步可能压根不跑"),
        ("continue-on-error:", "这一步判红也不会让 job 判红"),
        ("shell:", "覆写掉默认的 `bash -e -o pipefail`，失败可能不再传导到 step 退出码"),
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

    nonisolated static func isSkippable(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty || trimmed.hasPrefix("#")
    }

    /// 豁免表文本 → 条目集合（`#` 注释与空行忽略），与脚本侧的解析规则一致。
    nonisolated static func exemptionEntries(inTable text: String) -> [String] {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
    }

    /// 把一个 job 块切成一串 step 块（每块含 `- ` 那一行与它底下更深缩进的行）。
    ///
    /// ⚠️ 注释行**并入所属 step**（与 `jobBlock` 的边界规则一致），因此 step 里的
    /// 键查找必须自己跳过注释——本文件那段 `ci.yml` 注释里就逐字写着 `if:` 和
    /// `continue-on-error:`，不跳会假红。
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
                if indent <= stepsIndent { break } // 离开 `steps:` 这一节
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

    /// 一个 step 块里出现的、被禁的键（跳过注释行；`- ` 前缀先剥掉）。
    nonisolated static func blockedKeys(
        _ blocked: [(key: String, reason: String)],
        inStep step: String
    ) -> [String] {
        var hits: [String] = []
        for raw in step.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(raw)
            if Self.isSkippable(line) { continue }
            var trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- ") { trimmed = String(trimmed.dropFirst(2)) }
            for entry in blocked where trimmed.hasPrefix(entry.key) {
                hits.append("`\(entry.key)`：\(entry.reason)")
            }
        }
        return hits
    }

    /// job 的**直接子键**里出现的、被禁的键。
    ///
    /// 直接子键 = 缩进等于 job 块内第一条非空非注释行的缩进。
    nonisolated static func blockedJobLevelKeys(inJobBlock block: String) -> [String] {
        let lines = block.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let first = lines.first(where: { !Self.isSkippable($0) }) else { return [] }
        let keyIndent = Self.indentation(of: first)
        var hits: [String] = []
        for line in lines where !Self.isSkippable(line) {
            guard Self.indentation(of: line) == keyIndent else { continue }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            for entry in Self.blockedJobKeys where trimmed.hasPrefix(entry.key) {
                hits.append("`\(entry.key)`：\(entry.reason)")
            }
        }
        return hits
    }

    /// workflow 文本 → 违规清单（空 = 通过）。
    ///
    /// ⚠️ 归一化（反斜杠续行合并 / 剥引号 / 丢散文行 / 跳过 `with:` 子树）**复用**
    /// `DownstreamProbeGateGuard` 的那几个纯函数：那是**辅助**不是断言，没有
    /// 「两条判据实现独立」的价值可言（对照 `ColorGradeResolutionGuard` 头注释里
    /// 那份**有意保留**的 canary 重复——那边重复的是断言，这边复用的是解析器）。
    /// ⚠️ 代价一并登记：那几个函数将来因 `#290` 那条闸的理由被改时，本判据会跟着变。
    nonisolated static func violations(inWorkflow yaml: String) -> [String] {
        guard let block = DownstreamProbeGateGuard.jobBlock(inWorkflow: yaml, job: Self.jobName)
        else {
            return ["解析失效：workflow 里找不到 `jobs:` 下的 `\(Self.jobName):` 块"]
        }
        var problems: [String] = []

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
            problems.append(contentsOf: Self.blockedKeys(Self.blockedStepKeys, inStep: step).map {
                "跑棘轮的那个 step 上出现 \($0)"
            })
        }
        return problems
    }

    /// 脚本文本 → 违规清单（空 = 通过）。
    nonisolated static func violations(inScript script: String) -> [String] {
        Self.requiredScriptLiterals
            .filter { !script.contains($0.literal) }
            .map {
                """
                脚本里找不到逐字片段：
                \($0.literal)
                这一条为什么必须在：\($0.reason)
                """
            }
    }

    // MARK: - 判据（全部**无条件**，没有任何 `.enabled(if:)`）

    @Test("豁免表与树内登记逐条相符（双向差集）")
    func exemptionTableMatchesRegisteredTable() throws {
        let text = try String(contentsOf: Self.exemptionsURL, encoding: .utf8)
        let entries = Self.exemptionEntries(inTable: text)

        // 一、防「拿重复行凑数」。
        #expect(
            entries.count == Set(entries).count,
            "豁免表里有重复行：\(entries.filter { entry in entries.filter { $0 == entry }.count > 1 })"
        )
        // 二、防「表被清空 ⇒ 脚本零命中零违规 ⇒ 绿」。
        #expect(
            !entries.isEmpty,
            "豁免表一条都没有——那不是「本包没有 MainActor 隔离的公开 static」，是表被清空了"
        )

        // 三、双向差集。
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

        // 四、条目的 target 前缀必须是真的 library target。
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
        let yaml = try String(contentsOf: Self.workflowURL, encoding: .utf8)
        let problems = Self.violations(inWorkflow: yaml)
        #expect(problems.isEmpty, "ci.yml 的棘轮闸出了问题：\n\(problems.joined(separator: "\n\n"))")
    }

    // MARK: - 合成输入（AD-E：每条断言都要有能触发红的 fixture）

    /// 一份最小 workflow，`run:` 那一行由参数给。
    ///
    /// ⚠️ 缩进逐行显式拼（不用多行字符串字面量）：本函数产出的东西要喂给一个**按缩进**
    /// 判 step 边界的解析器，缩进就是被测输入本身，不能交给字面量的缩进剥离规则去猜。
    /// 形态与真 `ci.yml` 一致：`jobs:` 0 / job 名 2 / job 子键 4 / step 的 `- ` 6 / step 子键 8。
    /// 末尾那个带 `if: always()` 的 upload step 是**正对照**：它证明「别的 step 上的 `if:`
    /// 不判红」这条有意的取舍确实成立（真 `ci.yml` 的 `swiftpm` job 就长这样）。
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
}
