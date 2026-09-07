import Foundation
import Testing

// MARK: - 设计系统摘要的同步看门人 / design-digest sync gate

@Suite("design-digest 的同步判据不得被静默拆掉")
struct DesignDigestSyncGuard {
    // MARK: - 被钉住的常量

    nonisolated static let generatorRelativePath = "scripts/design-digest.py"

    nonisolated static let headerRelativePath = "docs/design-digest.header.md"

    nonisolated static let digestRelativePath = "docs/design-digest.md"

    nonisolated static let jobName = "swiftpm"

    nonisolated static let expectedRunCommand =
        "python3 scripts/design-digest.py && git diff --exit-code -- docs/design-digest.md"

    /// 生成器里每一节的基数键。少一节即少一道判据，而缺的那一节在退出码上等同于通过。
    nonisolated static let expectedFloorKeys: Set<String> = [
        "spacing", "radius", "border", "typography", "elevation", "controlsize",
        "colors", "components", "enums", "viewext", "styleext", "others",
    ]

    nonisolated static func url(_ relativePath: String) -> URL {
        GuardScanRoots.repoRoot.appendingPathComponent(relativePath)
    }

    // MARK: - 纯函数

    nonisolated static func violations(inWorkflow yaml: String) -> [String] {
        guard let block = DownstreamProbeGateGuard.jobBlock(inWorkflow: yaml, job: Self.jobName) else {
            return ["解析失效：workflow 里找不到 `jobs:` 下的 `\(Self.jobName):` 块"]
        }
        // 整行精确比对，不是子串包含：`run: <cmd> || true` 这类尾巴含着原命令，
        // 用 `contains` 会放行（本判据的合成 fixture 当场抓到过）。
        let wanted = "run: \(Self.expectedRunCommand)"
        let hasExactLine = block
            .split(separator: "\n", omittingEmptySubsequences: false)
            .contains { $0.trimmingCharacters(in: .whitespaces) == wanted }
        guard hasExactLine else {
            return ["`\(Self.jobName)` job 里找不到逐字独占一行的 `\(wanted)`"]
        }
        return []
    }

    nonisolated static func floorKeys(inGenerator source: String) -> Set<String> {
        guard let start = source.range(of: "FLOORS = {"),
              let end = source.range(of: "}", range: start.upperBound ..< source.endIndex)
        else { return [] }
        let body = String(source[start.upperBound ..< end.lowerBound])
        let pattern = try? NSRegularExpression(pattern: "\"([a-z]+)\"\\s*:")
        let range = NSRange(body.startIndex ..< body.endIndex, in: body)
        var keys: Set<String> = []
        pattern?.enumerateMatches(in: body, range: range) { match, _, _ in
            guard let match, let r = Range(match.range(at: 1), in: body) else { return }
            keys.insert(String(body[r]))
        }
        return keys
    }

    // MARK: - 判据

    @Test("生成器、header、产物三件都在")
    func artifactsExist() {
        for path in [Self.generatorRelativePath, Self.headerRelativePath, Self.digestRelativePath] {
            #expect(
                FileManager.default.fileExists(atPath: Self.url(path).path),
                "\(path) 不在——摘要链条断了一环"
            )
        }
    }

    @Test("ci.yml 的 swiftpm job 逐字跑同步比对")
    func workflowRunsTheSyncCheck() throws {
        let yaml = try String(contentsOf: Self.url(".github/workflows/ci.yml"), encoding: .utf8)
        let problems = Self.violations(inWorkflow: yaml)
        #expect(problems.isEmpty, "\(problems.joined(separator: "；"))")
    }

    @Test("合成输入：这一步被删掉 ⇒ 判红")
    func syntheticWorkflowWithoutTheStepIsRejected() {
        let yaml = """
        jobs:
          swiftpm:
            steps:
              - name: Test
                run: swift test
        """
        #expect(!Self.violations(inWorkflow: yaml).isEmpty)
    }

    @Test("合成输入：命令被中和成恒零 ⇒ 判红")
    func syntheticWorkflowWithNeutralizedExitCodeIsRejected() {
        let yaml = """
        jobs:
          swiftpm:
            steps:
              - name: design-digest 未过期
                run: \(Self.expectedRunCommand) || true
        """
        #expect(!Self.violations(inWorkflow: yaml).isEmpty)
    }

    @Test("生成器的基数键与树内登记逐条相符（双向差集）")
    func floorKeysMatchRegisteredTable() throws {
        let source = try String(contentsOf: Self.url(Self.generatorRelativePath), encoding: .utf8)
        let actual = Self.floorKeys(inGenerator: source)
        #expect(
            actual == Self.expectedFloorKeys,
            "生成器少了 \(Self.expectedFloorKeys.subtracting(actual))，多了 \(actual.subtracting(Self.expectedFloorKeys))"
        )
    }
}
