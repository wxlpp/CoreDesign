import Foundation
import Testing

// MARK: - downstream-probe 那道 warnings-as-errors 闸的树内判据 / CI gate guard（PR #304 终审 F-4）

@Suite("#290 downstream-probe 的 warnings-as-errors 闸不得被静默拆掉")
struct DownstreamProbeGateGuard {
    nonisolated static let jobName = "downstream-probe"

    nonisolated static let requiredFlag = "-Xswiftc -warnings-as-errors"

    nonisolated static let probeBuildMarker = "cd scripts/downstream-probe && swift build"

    nonisolated static var expectedProbeBuildCommand: String {
        "\(Self.probeBuildMarker) \(Self.requiredFlag)"
    }

    nonisolated static let selftestMarker = "selftest-warnings-as-errors.sh"

    nonisolated static let selftestBuildCommands = [
        #"output="$(cd "$PROBE_DIR" && swift build -Xswiftc -warnings-as-errors 2>&1)""#,
        #"(cd "$PROBE_DIR" && swift build -Xswiftc -warnings-as-errors)"#,
    ]

    nonisolated static var selftestBuildCommandCount: Int { Self.selftestBuildCommands.count }

    nonisolated static let proseLeadingWords: Set<String> = ["echo", "printf", ":"]

    nonisolated static let exitCodeNeutralizers: [(pattern: String, label: String)] = [
        (#"\|\|\s*true(?![\w-])"#, "|| true"),
        (#"\|\|\s*:(?![\w-])"#, "|| :"),
        (#"\|\|\s*exit\s+0(?![\w-])"#, "|| exit 0"),
        (#";\s*true(?![\w-])"#, "; true"),
        (#";\s*:(?![\w-])"#, "; :"),
        (#"(?:^|[\s;&|])set\s+\+e"#, "set +e"),
    ]

    nonisolated static let blockedJobKeys: [(key: String, reason: String)] = [
        ("if:", "这个 job / step 可能在某些事件上压根不跑"),
        ("needs:", "上游 job 被跳过时这个 job 会跟着不跑（`bool-ratchet` 就带着 `if:`）"),
        ("continue-on-error:", "这道闸判红也不会让 job 判红"),
        ("shell:", "覆写掉默认的 `bash -e -o pipefail`，失败可能不再传导到 step 退出码"),
    ]

    nonisolated static var workflowURL: URL {
        GuardScanRoots.repoRoot.appendingPathComponent(".github/workflows/ci.yml")
    }

    nonisolated static var selftestURL: URL {
        GuardScanRoots.repoRoot
            .appendingPathComponent("scripts/downstream-probe/selftest-warnings-as-errors.sh")
    }

    // MARK: - 归一化（共用；理由见文件头「病根与通用对策」）

    nonisolated private static func indentation(of line: String) -> Int {
        line.prefix { $0 == " " }.count
    }

    nonisolated private static func isSkippable(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty || trimmed.hasPrefix("#")
    }

    nonisolated static func mergingLineContinuations(_ text: String) -> String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var merged: [String] = []
        var index = 0
        while index < lines.count {
            var current = lines[index]
            while current.hasSuffix("\\"), index + 1 < lines.count {
                let head = String(current.dropLast()).trimmingCharacters(in: .whitespaces)
                let tail = lines[index + 1].trimmingCharacters(in: .whitespaces)
                current = tail.isEmpty ? head : "\(head) \(tail)"
                index += 1
            }
            merged.append(current)
            index += 1
        }
        return merged.joined(separator: "\n")
    }

    nonisolated static func strippingQuotedSegments(_ line: String) -> String {
        var out = ""
        var open: Character?
        for character in line {
            if let quote = open {
                if character == quote { open = nil }
                continue
            }
            if character == "\"" || character == "'" {
                open = character
                continue
            }
            out.append(character)
        }
        return out
    }

    nonisolated static func isProseLine(_ line: String) -> Bool {
        guard let first = line.split(separator: " ").first else { return true }
        return Self.proseLeadingWords.contains(String(first))
    }

    nonisolated static func commandLines(inRunCommand command: String) -> [String] {
        Self.mergingLineContinuations(command)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { !Self.isSkippable($0) }
            .map { Self.strippingQuotedSegments($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !Self.isProseLine($0) }
    }

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
            if indent == 0 { break }
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

    nonisolated static func runCommands(inJobBlock block: String) -> [String] {
        let lines = block.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var commands: [String] = []
        var index = 0
        var withIndent: Int?
        while index < lines.count {
            let line = lines[index]
            if Self.isSkippable(line) { index += 1; continue }
            let indent = Self.indentation(of: line)
            if let open = withIndent {
                if indent > open { index += 1; continue }
                withIndent = nil
            }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "with:" || trimmed == "- with:" {
                withIndent = indent
                index += 1
                continue
            }
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
                let baseIndent = indent
                var collected: [String] = []
                var cursor = index + 1
                while cursor < lines.count {
                    let next = lines[cursor]
                    if !Self.isSkippable(next), Self.indentation(of: next) <= baseIndent { break }
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

    // MARK: - 脚本侧归一化

    nonisolated static func strippingHeredocBodies(_ script: String) -> [String] {
        let lines = script.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let opener = try? NSRegularExpression(pattern: #"<<-?\s*(['"]?)([A-Za-z_][A-Za-z0-9_]*)\1"#)
        var kept: [String] = []
        var index = 0
        while index < lines.count {
            let line = lines[index]
            kept.append(line)
            if let opener,
               let match = opener.firstMatch(
                   in: line,
                   range: NSRange(line.startIndex..<line.endIndex, in: line)
               ),
               let range = Range(match.range(at: 2), in: line) {
                let terminator = String(line[range])
                index += 1
                while index < lines.count,
                      lines[index].trimmingCharacters(in: .whitespaces) != terminator {
                    index += 1
                }
            }
            index += 1
        }
        return kept
    }

    nonisolated static func flaggedBuildLines(inScript script: String) -> [String] {
        Self.strippingHeredocBodies(script)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") && !Self.isProseLine($0) }
            .filter { $0.contains("$PROBE_DIR") }
            .filter { $0.contains("swift build \(Self.requiredFlag)") }
    }

    // MARK: - 判据本体

    nonisolated private static func matches(_ pattern: String, in text: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        return regex.firstMatch(
            in: text,
            range: NSRange(text.startIndex..<text.endIndex, in: text)
        ) != nil
    }

    nonisolated static func violations(inWorkflow yaml: String) -> [String] {
        guard let block = Self.jobBlock(inWorkflow: yaml, job: Self.jobName) else {
            return ["解析失效：workflow 里找不到 `jobs:` 下的 `\(Self.jobName):` 块"]
        }
        let commands = Self.runCommands(inJobBlock: block)
        let realLines = commands.flatMap { Self.commandLines(inRunCommand: $0) }
        var problems: [String] = []

        let buildLines = realLines.filter { $0.contains(Self.probeBuildMarker) }
        if buildLines.isEmpty {
            problems.append("`\(Self.jobName)` 里找不到含 `\(Self.probeBuildMarker)` 的 `run:`")
        }
        let missingFlag = buildLines.filter { !$0.contains(Self.requiredFlag) }
        for line in missingFlag {
            problems.append("probe 构建命令缺少 `\(Self.requiredFlag)`：\(line)")
        }
        if !buildLines.isEmpty, missingFlag.isEmpty,
           !buildLines.contains(Self.expectedProbeBuildCommand) {
            problems.append(
                """
                probe 构建那条 `run:` 不是逐字的 `\(Self.expectedProbeBuildCommand)`：\
                \(buildLines.joined(separator: " / "))

                这是一条**正面清单**：多出来的部分**不一定**中和退出码（`-c release` /
                `--verbose` 这类合法标志同样判红），但按拼法追尾巴追不完，所以整条锁死。
                · 确实想改这条命令 ⇒ 同步改 `\(Self.jobName)` 判据里的
                  `expectedProbeBuildCommand`（它由 `probeBuildMarker` + `requiredFlag` 拼出）。
                · 回显的串搜不到 ⇒ 多半是归一化第 3 步剥掉了引号，
                  见 `strippingQuotedSegments` 的文档注释。
                """
            )
        }
        if !realLines.contains(where: { $0.contains(Self.selftestMarker) }) {
            problems.append("`\(Self.jobName)` 里找不到跑 `\(Self.selftestMarker)` 的 `run:`")
        }

        let neutralizerText = realLines.joined(separator: "\n")
        for neutralizer in Self.exitCodeNeutralizers
        where Self.matches(neutralizer.pattern, in: neutralizerText) {
            problems.append(
                "`\(Self.jobName)` 的某条 `run:` 退出码被 `\(neutralizer.label)` 吞掉：\(neutralizerText)"
            )
        }
        let effectiveBlockLines = block
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { !Self.isSkippable($0) }
            .map { $0.trimmingCharacters(in: .whitespaces) }
        for blocked in Self.blockedJobKeys where effectiveBlockLines.contains(where: {
            $0.hasPrefix(blocked.key) || $0.hasPrefix("- \(blocked.key)")
        }) {
            problems.append(
                "`\(Self.jobName)` job 里出现 `\(blocked.key)` —— \(blocked.reason)"
            )
        }
        return problems
    }

    nonisolated static func violations(inScript script: String) -> [String] {
        let flagged = Self.flaggedBuildLines(inScript: script)
        var problems: [String] = []
        if flagged.count != Self.selftestBuildCommandCount {
            problems.append(
                """
                `\(Self.selftestMarker)` 里带 `\(Self.requiredFlag)` 的**真实**构建命令
                有 \(flagged.count) 条，而不是预期的 \(Self.selftestBuildCommandCount) 条：
                \(flagged.isEmpty ? "（一条都没有）" : flagged.joined(separator: "\n"))

                ⚠️ 「一条都没有」**不等于「标志被删了」**（PR #304 第 4 轮终审 R-5）：
                `flaggedBuildLines` 的第 4 层筛按 `$PROBE_DIR` **同行共现**，把脚本里那个
                变量改名（纯合法重构）会得到**逐字相同**的这句话，而标志一个没少。
                先确认标志是否真的还在，再看下面那条逐字集合比对给的指引。
                """
            )
        }
        if Set(flagged) != Set(Self.selftestBuildCommands) {
            problems.append(
                """
                `\(Self.selftestMarker)` 的两条构建命令与 `selftestBuildCommands` 逐字钉住的
                文本对不上：
                实际：\(flagged.joined(separator: "\n"))
                期望：\(Self.selftestBuildCommands.joined(separator: "\n"))

                逐字钉住是有意的（脚本侧不能剥引号，见文件头）。合法改写这两行请同时改常量。
                """
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
        let script = try String(contentsOf: Self.selftestURL, encoding: .utf8)
        let problems = Self.violations(inScript: script)
        #expect(
            problems.isEmpty,
            """
            \(problems.joined(separator: "\n\n"))

            这个脚本的价值是「用**带同一个标志**的构建命令证明这道闸会响」。
            ⚠️ 注意本判据**不比对两侧的命令文本**（PR #304 第 3 轮终审 S-i）：CI 那条是
            `cd scripts/downstream-probe && …`、脚本这两条是 `cd "$PROBE_DIR" && …`，
            本来就不逐字相同。两侧各自被钉住的是**同一个标志**，不是同一串命令
            ——CI 改成 `… -c release` 而脚本仍 debug，**这一条**不会红。
            ⚠️ 但**兄弟判据 `workflowKeepsWarningsAsErrors` 会红**（PR #304 第 4 轮终审 R-8）：
            第 3 轮新加的 `expectedProbeBuildCommand` 是**逐字正面清单**，`-c release` 属于
            「多出来的部分」⇒ 那边判红。⇒ 「CI 换 release、脚本不换」整体上仍会被拦住，
            只是拦它的不是这一条。
            """
        )
        for command in Self.selftestBuildCommands {
            #expect(command.contains("swift build \(Self.requiredFlag)"))
        }
    }

    @Test("合成输入：删掉标志会判红")
    func syntheticWorkflowWithoutFlagIsRejected() {
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

    @Test("合成输入：反斜杠续行接标志仍判绿（归一化第 1 步的回归保护）")
    func syntheticBackslashContinuationIsAccepted() {
        let yaml = """
        jobs:
          downstream-probe:
            steps:
              - name: Build downstream probe
                run: |
                  cd scripts/downstream-probe && swift build \\
                    -Xswiftc -warnings-as-errors
              - run: scripts/downstream-probe/selftest-warnings-as-errors.sh
        """
        #expect(Self.violations(inWorkflow: yaml).isEmpty)
    }

    @Test("合成输入：块标量里标志只剩在注释里也判红")
    func syntheticBlockScalarWithFlagOnlyInCommentIsRejected() {
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

    @Test("合成输入：注释里提到旧写法不该判红（`isSkippable` 跳 `#` 的正对照）")
    func syntheticBlockScalarCommentMentioningOldCommandStaysGreen() {
        let yaml = """
        jobs:
          downstream-probe:
            steps:
              - name: Build downstream probe
                run: |
                  # 旧写法（加标志之前）：cd scripts/downstream-probe && swift build
                  cd scripts/downstream-probe && swift build -Xswiftc -warnings-as-errors
              - run: scripts/downstream-probe/selftest-warnings-as-errors.sh
        """
        #expect(Self.violations(inWorkflow: yaml).isEmpty)
    }

    @Test("合成输入：块标量里用 echo 散文冒充命令也判红（I-A）")
    func syntheticBlockScalarWithEchoProseIsRejected() {
        let yaml = """
        jobs:
          downstream-probe:
            steps:
              - name: Build downstream probe
                run: |
                  echo "==> cd scripts/downstream-probe && swift build -Xswiftc -warnings-as-errors"
                  cd scripts/downstream-probe && swift build
              - run: scripts/downstream-probe/selftest-warnings-as-errors.sh
        """
        let problems = Self.violations(inWorkflow: yaml)
        #expect(problems.count == 1)
        #expect(problems.first?.contains(Self.requiredFlag) == true)
    }

    @Test("合成输入：整条命令只活在单引号 echo 里也判红（I-A 同族）")
    func syntheticEchoOnlyRunIsRejected() {
        let yaml = """
        jobs:
          downstream-probe:
            steps:
              - name: Build downstream probe
                run: echo 'cd scripts/downstream-probe && swift build -Xswiftc -warnings-as-errors'
              - run: scripts/downstream-probe/selftest-warnings-as-errors.sh
        """
        let problems = Self.violations(inWorkflow: yaml)
        #expect(problems.count == 1)
        #expect(problems.first?.contains(Self.probeBuildMarker) == true)
    }

    @Test("合成输入：selftest 路径被引号包成一个变量赋值也判红（归一化第 3 步的证人）")
    func syntheticQuotedSelftestAssignmentIsRejected() {
        let yaml = """
        jobs:
          downstream-probe:
            steps:
              - run: cd scripts/downstream-probe && swift build -Xswiftc -warnings-as-errors
              - run: SELFTEST="scripts/downstream-probe/selftest-warnings-as-errors.sh"
        """
        let problems = Self.violations(inWorkflow: yaml)
        #expect(problems.count == 1)
        #expect(problems.first?.contains(Self.selftestMarker) == true)
    }

    @Test("合成输入：`with:` 底下装饰性的 run: 不算命令（I-A 同族）")
    func syntheticRunUnderWithIsRejected() {
        let yaml = """
        jobs:
          downstream-probe:
            steps:
              - uses: some/action@v1
                with:
                  run: cd scripts/downstream-probe && swift build -Xswiftc -warnings-as-errors
              - uses: some/other@v1
                with:
                  run: scripts/downstream-probe/selftest-warnings-as-errors.sh
        """
        let problems = Self.violations(inWorkflow: yaml)
        #expect(problems.count == 2)
        #expect(problems.contains { $0.contains(Self.probeBuildMarker) })
        #expect(problems.contains { $0.contains(Self.selftestMarker) })
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
        #expect(swallowedProblems.count == 2)
        #expect(swallowedProblems.contains { $0.contains("|| true") })
        #expect(swallowedProblems.contains { $0.contains("不是逐字的") })

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

    @Test("合成输入：中和退出码的另外几种拼法也判红（I-C）")
    func syntheticNeutralizerSpellingsAreRejected() {
        func workflow(withBuildSuffix suffix: String) -> String {
            """
            jobs:
              downstream-probe:
                steps:
                  - run: |
                      cd scripts/downstream-probe && swift build -Xswiftc -warnings-as-errors\(suffix)
                  - run: scripts/downstream-probe/selftest-warnings-as-errors.sh
            """
        }
        for (suffix, label) in [
            (" ||true", "|| true"),
            (" || :", "|| :"),
            (" ||:", "|| :"),
            (" || exit 0", "|| exit 0"),
            (" ; true", "; true"),
            ("; :", "; :"),
        ] {
            let problems = Self.violations(inWorkflow: workflow(withBuildSuffix: suffix))
            #expect(problems.count == 2, "`\(suffix)` 未判红")
            #expect(problems.contains { $0.contains(label) }, "`\(suffix)` 的判红标签不对")
            #expect(problems.contains { $0.contains("不是逐字的") }, "`\(suffix)` 未被逐字比对拦下")
        }

        let softWrapped = """
        jobs:
          downstream-probe:
            steps:
              - run: |
                  cd scripts/downstream-probe && swift build -Xswiftc -warnings-as-errors ||
                  true
              - run: scripts/downstream-probe/selftest-warnings-as-errors.sh
        """
        let softProblems = Self.violations(inWorkflow: softWrapped)
        #expect(softProblems.count == 2)
        #expect(softProblems.contains { $0.contains("|| true") })

        let setPlusE = """
        jobs:
          downstream-probe:
            steps:
              - run: |
                  set +e
                  cd scripts/downstream-probe && swift build -Xswiftc -warnings-as-errors
              - run: scripts/downstream-probe/selftest-warnings-as-errors.sh
        """
        let setProblems = Self.violations(inWorkflow: setPlusE)
        #expect(setProblems.count == 1)
        #expect(setProblems.first?.contains("set +e") == true)
    }

    @Test("合成输入：`|| echo skipped` 这类「尾巴」也判红（本轮自查新拼法 1）")
    func syntheticTrailingSwallowIsRejected() {
        for tail in [" || echo skipped", " || printf 'skipped'", " || (exit 0)", " 2>/dev/null"] {
            let yaml = """
            jobs:
              downstream-probe:
                steps:
                  - run: cd scripts/downstream-probe && swift build -Xswiftc -warnings-as-errors\(tail)
                  - run: scripts/downstream-probe/selftest-warnings-as-errors.sh
            """
            let problems = Self.violations(inWorkflow: yaml)
            #expect(problems.contains { $0.contains("不是逐字的") }, "`\(tail)` 未判红")
        }
    }

    @Test("合成输入：`shell:` 覆写掉 bash 的 -e / pipefail 也判红（本轮自查新拼法 2）")
    func syntheticShellOverrideIsRejected() {
        let yaml = """
        jobs:
          downstream-probe:
            steps:
              - name: Build downstream probe
                shell: bash {0}
                run: |
                  cd scripts/downstream-probe && swift build -Xswiftc -warnings-as-errors
                  echo done
              - run: scripts/downstream-probe/selftest-warnings-as-errors.sh
        """
        let problems = Self.violations(inWorkflow: yaml)
        #expect(problems.count == 1)
        #expect(problems.first?.contains("`shell:`") == true)
    }

    @Test("合成输入：`if:` / `needs:` 让这个 job 可能压根不跑，也判红（C-2）")
    func syntheticSkipSwitchesAreRejected() {
        let gatedJob = """
        jobs:
          downstream-probe:
            if: github.event_name == 'pull_request'
            steps:
              - run: cd scripts/downstream-probe && swift build -Xswiftc -warnings-as-errors
              - run: scripts/downstream-probe/selftest-warnings-as-errors.sh
        """
        let gatedProblems = Self.violations(inWorkflow: gatedJob)
        #expect(gatedProblems.count == 1)
        #expect(gatedProblems.first?.contains("`if:`") == true)

        let gatedStep = """
        jobs:
          downstream-probe:
            steps:
              - name: Build downstream probe
                if: false
                run: cd scripts/downstream-probe && swift build -Xswiftc -warnings-as-errors
              - run: scripts/downstream-probe/selftest-warnings-as-errors.sh
        """
        let stepProblems = Self.violations(inWorkflow: gatedStep)
        #expect(stepProblems.count == 1)
        #expect(stepProblems.first?.contains("`if:`") == true)

        let needsSkippableJob = """
        jobs:
          downstream-probe:
            needs: bool-ratchet
            steps:
              - run: cd scripts/downstream-probe && swift build -Xswiftc -warnings-as-errors
              - run: scripts/downstream-probe/selftest-warnings-as-errors.sh
        """
        let needsProblems = Self.violations(inWorkflow: needsSkippableJob)
        #expect(needsProblems.count == 1)
        #expect(needsProblems.first?.contains("`needs:`") == true)
    }

    @Test("合成输入：selftest 里标志只剩在注释里也判红")
    func syntheticScriptWithFlagOnlyInCommentsIsRejected() {
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
        #expect(script.contains("swift build \(Self.requiredFlag)"))
        #expect(Self.flaggedBuildLines(inScript: script).isEmpty)
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

    @Test("合成输入：selftest 里用 echo 散文灌水顶替真命令也判红（I-B）")
    func syntheticScriptPaddedWithEchoIsRejected() {
        let oneRealOneEcho = """
        #!/usr/bin/env bash
        output="$(cd "$PROBE_DIR" && swift build -Xswiftc -warnings-as-errors 2>&1)"
        (cd "$PROBE_DIR" && swift build)
        echo "==> 干净树用 cd "$PROBE_DIR" && swift build -Xswiftc -warnings-as-errors 构建"
        """
        #expect(Self.flaggedBuildLines(inScript: oneRealOneEcho).count == 1)

        let twoEchoes = """
        #!/usr/bin/env bash
        output="$(cd "$PROBE_DIR" && swift build 2>&1)"
        (cd "$PROBE_DIR" && swift build)
        echo "cd "$PROBE_DIR" && swift build -Xswiftc -warnings-as-errors"
        echo "cd "$PROBE_DIR" && swift build -Xswiftc -warnings-as-errors"
        """
        #expect(Self.flaggedBuildLines(inScript: twoEchoes).isEmpty)

        let heredoc = """
        #!/usr/bin/env bash
        cat > /dev/null <<'NOTE'
        (cd "$PROBE_DIR" && swift build -Xswiftc -warnings-as-errors)
        (cd "$PROBE_DIR" && swift build -Xswiftc -warnings-as-errors)
        NOTE
        (cd "$PROBE_DIR" && swift build)
        """
        #expect(Self.flaggedBuildLines(inScript: heredoc).isEmpty)
    }

    @Test("合成输入：脚本两条命令数目对但文本对不上也判红（逐字集合比对的证人）")
    func syntheticScriptDivergingFromPinnedCommandsIsRejected() {
        let script = """
        #!/usr/bin/env bash
        output="$(cd "$PROBE_DIR" && swift build -Xswiftc -warnings-as-errors --verbose 2>&1)"
        (cd "$PROBE_DIR" && swift build -Xswiftc -warnings-as-errors)
        """
        #expect(Self.flaggedBuildLines(inScript: script).count == Self.selftestBuildCommandCount)
        let problems = Self.violations(inScript: script)
        #expect(problems.count == 1)
        #expect(problems.first?.contains("逐字钉住") == true)
    }

    @Test("合成输入：不含 $PROBE_DIR 的行不算真命令（第 4 层筛的证人）")
    func syntheticScriptWithFlagOutsideProbeDirIsAccepted() {
        let script = """
        #!/usr/bin/env bash
        output="$(cd "$PROBE_DIR" && swift build -Xswiftc -warnings-as-errors 2>&1)"
        (cd "$PROBE_DIR" && swift build -Xswiftc -warnings-as-errors)
        HINT="修法：swift build -Xswiftc -warnings-as-errors"
        """
        #expect(Self.violations(inScript: script).isEmpty)
    }

    @Test("合成输入：脚本里把标志藏进行尾注释，逐字比对仍抓得到（本轮自查新拼法 3）")
    func syntheticScriptWithTrailingCommentFlagIsRejected() {
        let script = """
        #!/usr/bin/env bash
        output="$(cd "$PROBE_DIR" && swift build -Xswiftc -warnings-as-errors 2>&1)"
        (cd "$PROBE_DIR" && swift build) # swift build -Xswiftc -warnings-as-errors
        """
        let flagged = Self.flaggedBuildLines(inScript: script)
        #expect(flagged.count == Self.selftestBuildCommandCount)
        #expect(Set(flagged) != Set(Self.selftestBuildCommands))
    }
}
