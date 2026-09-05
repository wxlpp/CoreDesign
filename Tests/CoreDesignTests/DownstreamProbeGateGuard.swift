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
// ⚠️ 它只钉「**这个标志出现在那一条 `run:` 里**」。它**不**保证：
// · probe 里某个 `nonisolated func` 被整个删掉会判红 ——
//   `readTransitionPropertiesHasMotion()` / `useSettingsRowMetrics()` 删掉，
//   没有任何判据会红（`scripts/api-surface-diff.sh` 的头注释自己就写了
//   「它引用的符号是**手写清单**」）。**已知缺口**，不在本判据射程。
// · 新增的公开 `static` 成员会被 probe 引用 —— 完整性仍是 `#290` 的**一次性人工
//   枚举**：新加一个 `public static let` 到新类型上，它默认仍被 `defaultIsolation`
//   卷进 MainActor，而 probe 不引用它就没有任何东西判红。**已知缺口**，连同一个
//   可行的 symbol-graph 机器判据（含「扫描范围决定豁免表是 5 条还是 51 条」这个
//   必须先定案的分叉）登记在 **#307**。
// · CI 真的跑了这个 job（`if:` 被加上、job 被删、workflow 文件被改名，本判据都看不见）。
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
    nonisolated static let probeBuildMarker = "cd scripts/downstream-probe && swift build"

    /// selftest 那一步的识别特征。
    nonisolated static let selftestMarker = "selftest-warnings-as-errors.sh"

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

    @Test("selftest 脚本与 CI 用的是同一个标志")
    func selftestUsesTheSameFlag() throws {
        let script = try String(contentsOf: Self.selftestURL, encoding: .utf8)
        #expect(
            script.contains("swift build \(Self.requiredFlag)"),
            "selftest 脚本里的构建命令与 CI 的不再是同一条——它证的东西会跟着跑偏"
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
}
