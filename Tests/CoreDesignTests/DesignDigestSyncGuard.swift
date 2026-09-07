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
    /// 生成器里做基数比对的那一行，逐字钉住。把 `!=` 改成 `<`（退回下界语义）时
    /// key 集合不变、产物不变、其余判据全绿——只有这一条会响。
    nonisolated static let expectedComparison =
        "if counts.get(key, 0) != expected"

    nonisolated static let expectedFloorKeys: Set<String> = [
        "spacing", "radius", "border", "typography", "elevation", "controlsize",
        "colors", "components", "enums", "enumcases", "protocols",
        "viewext", "styleext", "others",
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
        let steps = MainActorStaticRatchetGuard.stepBlocks(inJobBlock: block)
        let mine = steps.filter { step in
            step.split(separator: "\n", omittingEmptySubsequences: false)
                .contains { $0.trimmingCharacters(in: .whitespaces) == wanted }
        }
        guard let step = mine.first else {
            return ["`\(Self.jobName)` job 里找不到逐字独占一行的 `\(wanted)`"]
        }
        // 这一步自己的中和面：step 级 `if:` / `continue-on-error:` / `shell:` 及同义拼法，
        // 以及把 `run:` 折成跨行普通标量后在续行挂 `|| true`。job 级与 workflow 顶层的
        // 中和面由 `MainActorStaticRatchetGuard` 对同一个 job 兜住，不在此重复实现。
        var problems: [String] = []
        problems += MainActorStaticRatchetGuard.disallowedStepKeys(inStep: step)
            .map { "这一步的直接子键里出现 \($0)" }
        problems += MainActorStaticRatchetGuard.runScalarContinuationLines(inStep: step)
            .map { "`run:` 有续行：\($0)" }
        return problems
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

    nonisolated static func syntheticWorkflow(runLine: String, stepKeys: [String] = []) -> String {
        // ⚠️ 缩进必须与 `run:` 同层：写深了这些键就不是 step 的直接子键，
        // `disallowedStepKeys` 一条都看不到，fixture 会因为**别的规则**判红而空转。
        let extra = stepKeys.map { "        \($0)" }.joined(separator: "\n")
        return """
        jobs:
          swiftpm:
            steps:
              - name: design-digest 未过期
                \(runLine)
        \(extra)
        """
    }

    @Test("合成输入：干净形态判绿（正对照，防解析失效导致负 fixture 空转）")
    func syntheticCleanWorkflowIsAccepted() {
        let yaml = Self.syntheticWorkflow(runLine: "run: \(Self.expectedRunCommand)")
        #expect(Self.violations(inWorkflow: yaml).isEmpty, "干净形态被误判红 ⇒ 解析失效")
    }

    @Test("合成输入：这一步加 `if: false` ⇒ 判红")
    func syntheticWorkflowWithStepConditionIsRejected() {
        let yaml = Self.syntheticWorkflow(
            runLine: "run: \(Self.expectedRunCommand)", stepKeys: ["if: false"]
        )
        #expect(!Self.violations(inWorkflow: yaml).isEmpty)
    }

    @Test("合成输入：这一步加 `continue-on-error: true` ⇒ 判红")
    func syntheticWorkflowWithContinueOnErrorIsRejected() {
        let yaml = Self.syntheticWorkflow(
            runLine: "run: \(Self.expectedRunCommand)", stepKeys: ["continue-on-error: true"]
        )
        #expect(!Self.violations(inWorkflow: yaml).isEmpty)
    }

    @Test("合成输入：`run:` 折成跨行标量、续行挂 `|| true` ⇒ 判红")
    func syntheticWorkflowWithScalarContinuationIsRejected() {
        let yaml = """
        jobs:
          swiftpm:
            steps:
              - name: design-digest 未过期
                run: \(Self.expectedRunCommand)
                  || true
        """
        #expect(!Self.violations(inWorkflow: yaml).isEmpty)
    }

    @Test("生成器的基数比对逐字是 `!=`（精确值语义，不是下界）")
    func generatorPinsExactComparison() throws {
        let source = try String(contentsOf: Self.url(Self.generatorRelativePath), encoding: .utf8)
        #expect(
            source.contains(Self.expectedComparison),
            "找不到 `\(Self.expectedComparison)` —— 基数判据可能已被退回下界语义"
        )
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

    /// `docs/component-registry.json` 里 `repo=coredesign` 却在源码中查无此类型的名字。
    /// 每一条都是一处存量假登记；表为空是目标状态，往里加需在 PR 正文写明理由。
    nonisolated static let registryNamesWithoutType: Set<String> = [
        // `Toast` 是契约名不是类型名——真名 `ToastItem` / `ToastHost`。
        "Toast",
    ]

    @Test("registry 的 coredesign 组件名都能在摘要里找到对应类型（已知分歧除外）")
    func registryNamesResolveToRealTypes() throws {
        let registryURL = Self.url("docs/component-registry.json")
        let data = try Data(contentsOf: registryURL)
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let entries = (root?["components"] as? [[String: Any]]) ?? []
        #expect(!entries.isEmpty, "registry 解析不出 components ⇒ 判红而不是当作零违规")

        let digest = try String(contentsOf: Self.url(Self.digestRelativePath), encoding: .utf8)
        var declared: Set<String> = []
        for line in digest.split(separator: "\n") where line.hasPrefix("- ") {
            for chunk in line.components(separatedBy: "**`").dropFirst() {
                guard let name = chunk.components(separatedBy: "`**").first else { continue }
                declared.insert(name)
                if let last = name.split(separator: ".").last { declared.insert(String(last)) }
            }
        }
        #expect(!declared.isEmpty, "摘要里抠不出任何类型名 ⇒ 解析失效")

        let missing = entries
            .filter { ($0["repo"] as? String) == "coredesign" }
            .compactMap { $0["component"] as? String }
            .filter { !declared.contains($0) }
        let added = Set(missing).subtracting(Self.registryNamesWithoutType)
        let gone = Self.registryNamesWithoutType.subtracting(Set(missing))
        #expect(
            Set(missing) == Self.registryNamesWithoutType,
            "registry 里查无此类型的名字变了：新增 \(added)，已消失 \(gone)"
        )
    }

    /// header 手写着「`ProgressBar` 是全仓**唯一**一个 `@available(*, deprecated)` 的公开
    /// 符号」，而 `is_deprecated` 只认 `@available(*, deprecated` 这一种拼法，且只在类型
    /// 声明上查（modifier / 颜色两条抽取路径都不查）。多出第二个弃用符号、或换成
    /// `@available(iOS, deprecated:)` 这一族时：header 变假、产物可能漏标、其余判据全绿。
    /// 这条把两侧一起钉住——fail-closed：出现任何未登记的弃用写法即判红。
    @Test("弃用符号恰一处、拼法逐字，且产物里的弃用标注恰一次")
    func deprecationClaimHoldsOnBothSides() throws {
        var lines: [String] = []
        for entry in GuardScanRoots.allRoots {
            guard let walker = FileManager.default.enumerator(at: entry.url, includingPropertiesForKeys: nil)
            else { continue }
            for case let url as URL in walker where url.pathExtension == "swift" {
                let text = try String(contentsOf: url, encoding: .utf8)
                for line in text.split(separator: "\n", omittingEmptySubsequences: false)
                where line.contains("@available(") && line.contains("deprecated") {
                    lines.append(String(line).trimmingCharacters(in: .whitespaces))
                }
            }
        }
        let found = lines.count
        #expect(
            found == 1,
            "弃用符号数量变了（现 \(found) 处）——header 那句「全仓唯一」随之失真"
        )
        let recognised = lines.allSatisfy { $0.hasPrefix("@available(*, deprecated") }
        let shown = lines.joined(separator: " | ")
        #expect(recognised, "出现 `is_deprecated` 不认识的弃用拼法：\(shown)")

        let digest = try String(contentsOf: Self.url(Self.digestRelativePath), encoding: .utf8)
        let marks = digest.components(separatedBy: "**[已弃用]**").count - 1
        #expect(marks == 1, "产物里的弃用标注有 \(marks) 处，应与源码的 1 处弃用对上")
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
