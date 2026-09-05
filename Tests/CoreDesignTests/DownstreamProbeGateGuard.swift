import Foundation
import Testing

// MARK: - downstream-probe 那道 warnings-as-errors 闸的树内判据 / CI gate guard（PR #304 终审 F-4）
//
// ## 它守什么
//
// `.github/workflows/ci.yml` 的 `downstream-probe` job 里，构建 probe 的那条 `run:`
// 必须**逐字**带 `-Xswiftc -warnings-as-errors`；同 job 里必须还有一步跑
// `selftest-warnings-as-errors.sh`；而那个脚本里的构建命令必须带同一个标志。
//
// ## 为什么还要一条判据（「已经有 selftest 了」不够）
//
// ⚠️ `scripts/downstream-probe/selftest-warnings-as-errors.sh` **自己硬编码**这个标志
// （脚本内两处）⇒ 它证的是「**这条命令**会响」，**不是「CI 跑的是这条命令」**。
// 谁把 `ci.yml` 那步改回裸 `swift build`：probe 恢复容忍 warning，而 selftest 照样绿，
// `swift build` / `swift test` / iOS 腿 / bool-ratchet 也全绿 ⇒ **整道闸静默消失**。
//
// ⚠️⚠️ 这正是 `#290` 自己立的那条 AD-E 命题（「加了标志 ≠ 它真的会响」）在**上一层**
// 的复现：selftest 把命题从「标志有用吗」推到「这条命令会响吗」，本判据再推一层到
// 「CI 跑的是不是这条命令」。少了这一层，`EffectsNonisolatedUsage.swift` 与
// `FilterTransitionSupport.swift` 里那句「今天谁把 `nonisolated` 拿掉，probe 会判红」
// 会**再次变成假话**——`#291` 第 2 轮发现过同款事故（一句「常驻判据」的散文，
// 底下并没有判据）。
//
// ⚠️ 本仓先例是 `AppProjectManifestGuard`：同样用 `String(contentsOf:)` 读 manifest
// 做纯文本判据。而 `.github/workflows/ci.yml` **在本判据之前从未被任何判据读过**
// （`grep -rn "ci.yml" Tests/` 只在 `AppProjectManifestGuard.swift` 的散文注释里
// 出现一次）⇒ CI 配置本身一直是无人看守的一面。
//
// ## 射程与已知缺口（不要读成比实际更强）
//
// ⚠️ 上一版这里把「job 被删 / workflow 文件被改名」写进了「它看不见」那一侧——
// **实测为假，照录更正**（PR #304 第 2 轮终审 I-2）：两者都判红，形态见下。
//
// **本轮在真实 `ci.yml`（与真实 selftest 脚本）上逐条变异实测过的 7 种改法，
// 它都守得到**（每条附判红形态，原始输出见 PR #304 第 2 轮的验证块）：
// · 标志被删 ⇒ `probe 构建命令缺少 -Xswiftc -warnings-as-errors：…`
// · 构建那条 `run:` 整个不见 ⇒ ``\`downstream-probe\` 里找不到含 …… 的 `run:` ``
// · selftest 那一步不见 ⇒ ``\`downstream-probe\` 里找不到跑 …… 的 `run:` ``
// · **job 被整块删掉** ⇒ `解析失效：workflow 里找不到 \`jobs:\` 下的 \`downstream-probe:\` 块`
//   （`jobBlock` 返回 `nil` 时**不**当作「零命中 ⇒ 零违规」）
// · **workflow 文件被改名 / 删除** ⇒ `String(contentsOf:)` 抛错，测试以
//   `Caught error: Error Domain=NSCocoaErrorDomain Code=260 …` 判红
// · 那条 `run:` 末尾被追加 ` || true` ⇒ `probe 构建命令的退出码被 \` || true\` 吞掉：…`
// · 该 step 被加上 `continue-on-error: true` ⇒ `job 里出现 \`continue-on-error\`…`
//
// ⚠️ 后两条不是理论洁癖：**标志在场 ≠ 失败会传导到 job 结论**。只查标志时，
// 这两种改法都让判据全绿而闸已死——与「改回裸 `swift build`」等效，只是更隐蔽。
//
// ⚠️ 它**不**保证：
// · **CI 真的跑了这个 job** —— `if:` 被加到 job 或某个 step 上，本判据看不见。
//   （这是「job 没跑」这一类里**唯一**仍然敞着的口；上面两条已经堵住。）
// · **别的中和退出码的写法** —— 本次只堵了 ` || true` 与 `continue-on-error` 两种；
//   `|| :`、`|| exit 0`、步骤里先 `set +e`、把命令包进一个自己吞错的脚本，
//   本判据都仍然看不见。**已知缺口**。
// · probe 里某个 `nonisolated func` 被整个删掉会判红 ——
//   `readTransitionPropertiesHasMotion()` / `useSettingsRowMetrics()` 删掉，
//   没有任何判据会红（`scripts/api-surface-diff.sh` 的头注释自己就写了
//   「它引用的符号是**手写清单**」）。**已知缺口**，不在本判据射程。
// · 新增的公开 `static` 成员会被 probe 引用 —— 完整性仍是 `#290` 的**一次性人工
//   枚举**：新加一个 `public static let` 到新类型上，它默认仍被 `defaultIsolation`
//   卷进 MainActor，而 probe 不引用它就没有任何东西判红。**已知缺口**，连同一个
//   可行的 symbol-graph 机器判据（含「扫描范围决定豁免表是 5 条还是 51 条」这个
//   必须先定案的分叉）登记在 **#307**。
//
// ⚠️ 判据**只解析文本、不跑 CI**——因此它和 `AppProjectManifestGuard` 一样，
// 是那类「CI 里唯一看得见自己」的判据：它随 `swift test` 在**每个事件**上跑。
@Suite("#290 downstream-probe 的 warnings-as-errors 闸不得被静默拆掉")
struct DownstreamProbeGateGuard {

    /// 被守的 job 名（`ci.yml` 的 `jobs:` 下那一条）。
    nonisolated static let jobName = "downstream-probe"

    /// 被守的标志——**逐字**，包含中间那个空格。
    nonisolated static let requiredFlag = "-Xswiftc -warnings-as-errors"

    /// probe 构建那条 `run:` 的识别特征（不含标志本身）。
    ///
    /// ⚠️ **它是整串逐字匹配，不是「`cd` 到那个目录并 `swift build`」的语义匹配**
    /// （PR #304 第 2 轮终审 S-2）。把那条 `run:` 改写成语义等价但**字面不同**的形态
    /// ——例如块标量里 `cd scripts/downstream-probe` 与 `swift build …` 分成两行、
    /// 或用折叠标量 `>-` 让这一串跨了折行——本判据会报
    /// 「找不到含 `\(probeBuildMarker)` 的 `run:`」而**判红**。
    /// 方向是 fail-closed（不会假绿），但重构的人会撞上一条**看起来像 bug 的红**：
    /// 那不是 bug，是本常量的已知代价。要改写那条 `run:`，同时改这里。
    nonisolated static let probeBuildMarker = "cd scripts/downstream-probe && swift build"

    /// selftest 那一步的识别特征。
    nonisolated static let selftestMarker = "selftest-warnings-as-errors.sh"

    /// `selftest-warnings-as-errors.sh` 里**真实**跑构建的命令条数（步骤 1 判红、步骤 3 判绿）。
    ///
    /// ⚠️ 这个数字是判据的关键：只断言「标志在脚本里出现过」会被脚本头部的**注释**
    /// 满足（该脚本第 9 行的用法说明里就逐字写着这条命令）⇒ 把两条真命令的标志
    /// 全删掉，断言照样绿。见 `selftestUsesTheSameFlag` 的注释。
    nonisolated static let selftestBuildCommandCount = 2

    nonisolated static var workflowURL: URL {
        GuardScanRoots.repoRoot.appendingPathComponent(".github/workflows/ci.yml")
    }

    nonisolated static var selftestURL: URL {
        GuardScanRoots.repoRoot
            .appendingPathComponent("scripts/downstream-probe/selftest-warnings-as-errors.sh")
    }

    // MARK: - 纯解析器（供合成输入的变红自证使用）

    nonisolated private static func indentation(of line: String) -> Int {
        line.prefix { $0 == " " }.count
    }

    nonisolated private static func isSkippable(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty || trimmed.hasPrefix("#")
    }

    /// 从 workflow 文本里切出 `jobs:` → `<job>:` 那一块（不含 job 行本身）。
    ///
    /// ⚠️ 返回 `nil` 表示**没找到那个 job**，调用方必须当解析失效处理，
    /// 而不是「零命中 ⇒ 零违规 ⇒ 绿」——那是 fail-open，正是本判据要防的形态。
    /// 块的终点是「第一条缩进 ≤ job 行缩进的非空非注释行」；空行与注释行并入块内。
    nonisolated static func jobBlock(inWorkflow yaml: String, job: String) -> String? {
        let lines = yaml.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let jobsIndex = lines.firstIndex(where: {
            $0.trimmingCharacters(in: .whitespaces) == "jobs:" && Self.indentation(of: $0) == 0
        }) else { return nil }

        var start: Int?
        var jobIndent = 0
        var cursor = jobsIndex + 1
        while cursor < lines.count {
            let line = lines[cursor]
            if Self.isSkippable(line) { cursor += 1; continue }
            let indent = Self.indentation(of: line)
            if indent == 0 { break } // 离开 `jobs:` 这一节
            if line.trimmingCharacters(in: .whitespaces) == "\(job):" {
                start = cursor + 1
                jobIndent = indent
                break
            }
            cursor += 1
        }
        guard let first = start else { return nil }

        var block: [String] = []
        var index = first
        while index < lines.count {
            let line = lines[index]
            if !Self.isSkippable(line), Self.indentation(of: line) <= jobIndent { break }
            block.append(line)
            index += 1
        }
        return block.joined(separator: "\n")
    }

    /// 取一个 job 块里的全部 `run:` 命令文本。
    ///
    /// 同时认两种写法：行内 `run: cmd`，与块标量 `run: |` +（更深缩进的）后续行。
    /// 块标量的多行会被拼成一条以 `\n` 相连的字符串——判据用 `contains` 匹配，
    /// 因此拆成多行写也仍然抓得到。
    ///
    /// ⚠️ 块标量里的**空行与 `#` 注释行不进结果**：它们只参与判块边界。理由见循环内注释。
    nonisolated static func runCommands(inJobBlock block: String) -> [String] {
        let lines = block.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var commands: [String] = []
        var index = 0
        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let body: String?
            if trimmed.hasPrefix("run:") {
                body = String(trimmed.dropFirst("run:".count)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("- run:") {
                body = String(trimmed.dropFirst("- run:".count)).trimmingCharacters(in: .whitespaces)
            } else {
                body = nil
            }
            guard let scalar = body else { index += 1; continue }

            if scalar == "|" || scalar == ">" || scalar == "|-" || scalar == ">-" {
                let baseIndent = Self.indentation(of: line)
                var collected: [String] = []
                var cursor = index + 1
                while cursor < lines.count {
                    let next = lines[cursor]
                    if !Self.isSkippable(next), Self.indentation(of: next) <= baseIndent { break }
                    // ⚠️ 空行与 `#` 注释行只用来**判块边界**，**不进 `collected`**
                    // （PR #304 第 2 轮终审 I-2/S-1）。上一版把它们一并拼进命令串 ⇒
                    // 下面的 `contains(requiredFlag)` 能被**注释里的标志**满足：把那条
                    // `run:` 改成块标量、标志只留在 `#` 注释里、实际命令裸 `swift build`，
                    // 判据全绿而闸已死。本仓 `ci.yml` 正是重注释风格（这个 job 自己就有
                    // 二十多行注释），不是理论风险。
                    if Self.isSkippable(next) { cursor += 1; continue }
                    collected.append(next.trimmingCharacters(in: .whitespaces))
                    cursor += 1
                }
                commands.append(collected.joined(separator: "\n"))
                index = cursor
            } else {
                commands.append(scalar)
                index += 1
            }
        }
        return commands
    }

    /// selftest 脚本里**真正会执行**的、带那个标志的构建命令行。
    ///
    /// ⚠️ 整行以 `#` 开头的行被丢掉。**不**做行内 `#` 处理——bash 里 `#` 只有在词首
    /// 才是注释，而本仓这个脚本没有行尾注释；真要处理得先做一遍 shell 词法分析，
    /// 那超出「纯文本判据」的定位。**已知缺口**：把标志藏进一条行尾注释仍能骗过它。
    nonisolated static func flaggedBuildLines(inScript script: String) -> [String] {
        script.split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("#") }
            .filter { $0.contains("swift build \(Self.requiredFlag)") }
    }

    /// 判据本体：对一份 workflow 文本给出违规清单（空 = 通过）。
    ///
    /// ⚠️ 抽成纯函数，是为了让「删掉标志会判红」这件事本身**有一条常驻测试**
    /// （下面 `合成输入：删掉标志会判红`），而不必去改真实的 `ci.yml`。
    nonisolated static func violations(inWorkflow yaml: String) -> [String] {
        guard let block = Self.jobBlock(inWorkflow: yaml, job: Self.jobName) else {
            return ["解析失效：workflow 里找不到 `jobs:` 下的 `\(Self.jobName):` 块"]
        }
        let commands = Self.runCommands(inJobBlock: block)
        var problems: [String] = []

        let buildCommands = commands.filter { $0.contains(Self.probeBuildMarker) }
        if buildCommands.isEmpty {
            problems.append("`\(Self.jobName)` 里找不到含 `\(Self.probeBuildMarker)` 的 `run:`")
        }
        for command in buildCommands where !command.contains(Self.requiredFlag) {
            problems.append("probe 构建命令缺少 `\(Self.requiredFlag)`：\(command)")
        }
        if !commands.contains(where: { $0.contains(Self.selftestMarker) }) {
            problems.append("`\(Self.jobName)` 里找不到跑 `\(Self.selftestMarker)` 的 `run:`")
        }

        // ⚠️ **标志在场 ≠ 失败会传导**（PR #304 第 2 轮终审 I-2）。下面两条各堵一种
        // 「闸还在、但红点到不了 job 结论」的改法；它们比「改回裸 `swift build`」更隐蔽，
        // 因为标志仍然逐字躺在那条 `run:` 里。**只堵这两种**，别的中和写法见判据头。
        for command in commands where command.contains("|| true") {
            problems.append("`\(Self.jobName)` 的某条 `run:` 退出码被 `|| true` 吞掉：\(command)")
        }
        let effectiveBlockLines = block
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { !Self.isSkippable($0) } // 注释里提一嘴 `continue-on-error` 不该判红
        if effectiveBlockLines.contains(where: { $0.contains("continue-on-error") }) {
            problems.append(
                "`\(Self.jobName)` job 里出现 `continue-on-error` —— 这道闸判红也不会让 job 判红"
            )
        }
        return problems
    }

    // MARK: - 判据

    @Test("ci.yml 的 downstream-probe 构建命令逐字带 -Xswiftc -warnings-as-errors")
    func workflowKeepsWarningsAsErrors() throws {
        let yaml = try String(contentsOf: Self.workflowURL, encoding: .utf8)
        let problems = Self.violations(inWorkflow: yaml)
        #expect(
            problems.isEmpty,
            """
            `.github/workflows/ci.yml` 的 `\(Self.jobName)` job 不再守着那道零警告闸：
            \(problems.joined(separator: "\n"))

            这不是风格问题——不带 `\(Self.requiredFlag)`，隔离契约里**整整一类**回归
            （长在 View / Transition 上的公开常量，诊断被降级成 warning）在这个 job 里
            是看不见的。恢复标志，或先说明为什么这道闸可以拆。
            """
        )
    }

    @Test("selftest 脚本的两条真实构建命令与 CI 用的是同一个标志")
    func selftestUsesTheSameFlag() throws {
        // ⚠️ **上一版这里写 `script.contains("swift build \(requiredFlag)")`，实测为假，
        // 照录更正**（PR #304 第 2 轮终审 I-1）：把脚本里**两条真实构建命令**（`:56`
        // 与 `:76`）的标志全部删掉，这条断言**照样绿**——满足它的是脚本第 9 行那条
        // **用法说明注释**里逐字写着的同一条命令。⇒ 它当时证的其实是「这个字符串在
        // 这个文件里出现过（含注释）」。
        //
        // ⚠️⚠️ 这正是本判据自己在别处修的同款失效，也是判据头那段「selftest 自己硬编码
        // 这个标志 ⇒ 它证的是**这条命令**会响」的**镜像**：那段话成立的前提是脚本里真的
        // 有那条命令，而不是有那行注释。⇒ 改为**按行判定、只看非注释行**，并要求至少
        // 两行命中（对应脚本内两条真命令）。
        let script = try String(contentsOf: Self.selftestURL, encoding: .utf8)
        let flagged = Self.flaggedBuildLines(inScript: script)
        #expect(
            flagged.count >= Self.selftestBuildCommandCount,
            """
            `\(Self.selftestMarker)` 里带 `\(Self.requiredFlag)` 的**非注释**构建命令
            只剩 \(flagged.count) 条，少于预期的 \(Self.selftestBuildCommandCount) 条：
            \(flagged.isEmpty ? "（一条都没有）" : flagged.joined(separator: "\n"))

            这个脚本的全部价值是「用与 CI **逐字相同**的命令证明这道闸会响」。它自己的
            构建命令一旦与 CI 的分叉，它证的东西就跟着跑偏——而判据头那段推理
            （selftest 证「这条命令会响」、本判据证「CI 跑的是这条命令」）会缺掉前一半。
            """
        )
    }

    @Test("合成输入：删掉标志会判红")
    func syntheticWorkflowWithoutFlagIsRejected() {
        // ⚠️ 这就是本判据自己的「能触发红的 fixture」（AD-E）：真实 `ci.yml` 上做同样的
        // 删除也判红，见 PR #304 正文贴的原始输出；这里把它固化成常驻测试。
        let yaml = """
        jobs:
          downstream-probe:
            name: Downstream API probe
            runs-on: macos-26
            steps:
              - uses: actions/checkout@v4
              - name: Build downstream probe
                run: cd scripts/downstream-probe && swift build
              - name: Self-test the warnings-as-errors gate
                run: scripts/downstream-probe/selftest-warnings-as-errors.sh
        """
        let problems = Self.violations(inWorkflow: yaml)
        #expect(problems.count == 1)
        #expect(problems.first?.contains(Self.requiredFlag) == true)
    }

    @Test("合成输入：job 整个不见了也判红（不是 fail-open）")
    func syntheticWorkflowWithoutJobIsRejected() {
        let yaml = """
        jobs:
          build:
            runs-on: macos-26
            steps:
              - run: swift build
        """
        let problems = Self.violations(inWorkflow: yaml)
        #expect(problems.count == 1)
        #expect(problems.first?.contains("解析失效") == true)
    }

    @Test("合成输入：块标量写法也抓得到")
    func syntheticBlockScalarIsAccepted() {
        let yaml = """
        jobs:
          downstream-probe:
            steps:
              - name: Build downstream probe
                run: |
                  cd scripts/downstream-probe && swift build -Xswiftc -warnings-as-errors
              - run: scripts/downstream-probe/selftest-warnings-as-errors.sh
        """
        #expect(Self.violations(inWorkflow: yaml).isEmpty)
    }

    @Test("合成输入：块标量里标志只剩在注释里也判红")
    func syntheticBlockScalarWithFlagOnlyInCommentIsRejected() {
        // ⚠️ 这条 fixture 钉住 `runCommands` 那个解析缺陷的修复（S-1）：注释行曾被拼进
        // 命令串，于是 `contains(requiredFlag)` 被**注释**满足 ⇒ 全绿而闸已死。
        let yaml = """
        jobs:
          downstream-probe:
            steps:
              - name: Build downstream probe
                run: |
                  # 这一步等价于 swift build -Xswiftc -warnings-as-errors
                  cd scripts/downstream-probe && swift build
              - run: scripts/downstream-probe/selftest-warnings-as-errors.sh
        """
        let problems = Self.violations(inWorkflow: yaml)
        #expect(problems.count == 1)
        #expect(problems.first?.contains(Self.requiredFlag) == true)
    }

    @Test("合成输入：`|| true` 与 continue-on-error 把闸变成装饰也判红")
    func syntheticNeutralizedGateIsRejected() {
        let swallowed = """
        jobs:
          downstream-probe:
            steps:
              - run: cd scripts/downstream-probe && swift build -Xswiftc -warnings-as-errors || true
              - run: scripts/downstream-probe/selftest-warnings-as-errors.sh
        """
        let swallowedProblems = Self.violations(inWorkflow: swallowed)
        #expect(swallowedProblems.count == 1)
        #expect(swallowedProblems.first?.contains("|| true") == true)

        let continued = """
        jobs:
          downstream-probe:
            steps:
              - name: Build downstream probe
                continue-on-error: true
                run: cd scripts/downstream-probe && swift build -Xswiftc -warnings-as-errors
              - run: scripts/downstream-probe/selftest-warnings-as-errors.sh
        """
        let continuedProblems = Self.violations(inWorkflow: continued)
        #expect(continuedProblems.count == 1)
        #expect(continuedProblems.first?.contains("continue-on-error") == true)
    }

    @Test("合成输入：selftest 里标志只剩在注释里也判红")
    func syntheticScriptWithFlagOnlyInCommentsIsRejected() {
        // 上一版断言（整文件 `contains`）对**这份**输入是绿的——它就是 I-1 那条实测的
        // 最小化形态：两条真命令裸 `swift build`，标志只活在头部用法说明里。
        let script = """
        #!/usr/bin/env bash
        #
        # CI 的 downstream-probe 步骤跑的是
        #
        #     cd scripts/downstream-probe && swift build -Xswiftc -warnings-as-errors
        #
        output="$(cd "$PROBE_DIR" && swift build 2>&1)"
        (cd "$PROBE_DIR" && swift build)
        """
        #expect(script.contains("swift build \(Self.requiredFlag)")) // 旧断言：绿
        #expect(Self.flaggedBuildLines(inScript: script).isEmpty) // 新判据：零命中 ⇒ 红
    }

    @Test("合成输入：两条真命令都带标志才算数")
    func syntheticScriptWithTwoRealCommandsIsAccepted() {
        let script = """
        #!/usr/bin/env bash
        # 说明里也提一次 swift build -Xswiftc -warnings-as-errors
        output="$(cd "$PROBE_DIR" && swift build -Xswiftc -warnings-as-errors 2>&1)"
        (cd "$PROBE_DIR" && swift build -Xswiftc -warnings-as-errors)
        """
        #expect(Self.flaggedBuildLines(inScript: script).count == Self.selftestBuildCommandCount)
    }
}
