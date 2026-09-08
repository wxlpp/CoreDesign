import Foundation
import Testing

// MARK: - AGENTS.md 与 CLAUDE.md 的一致性守卫（Issue #223）

@Suite("AGENTS.md 与 CLAUDE.md 保持同步")
struct AgentGuideSyncGuard {
    private static let bannerPrefix = "> **本文件是 `CLAUDE.md` 的 Codex 版镜像。"

    private static let titles = ["# CLAUDE.md", "# AGENTS.md"]

    private static let intros = [
        "本文件为 Claude Code (claude.ai/code) 在本仓库中工作时提供指引。",
        "本文件为 Codex 在本仓库中工作时提供指引。",
    ]

    private static func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private static func normalized(_ url: URL) throws -> [String] {
        let text = try String(contentsOf: url, encoding: .utf8)
        return text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { !$0.hasPrefix(Self.bannerPrefix) }
            .map { line -> String in
                if Self.titles.contains(line) { return "__TITLE__" }
                if Self.intros.contains(line) { return "__INTRO__" }
                return line
            }
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    @Test("规范化后两份指引逐行一致")
    func guidesAreInSync() throws {
        let root = Self.repoRoot()
        let claude = try Self.normalized(root.appendingPathComponent("CLAUDE.md"))
        let agents = try Self.normalized(root.appendingPathComponent("AGENTS.md"))

        #expect(
            claude.count == agents.count,
            "行数不一致：CLAUDE.md \(claude.count) 行 vs AGENTS.md \(agents.count) 行——有内容只加到了其中一边"
        )

        for (i, pair) in zip(claude, agents).enumerated() where pair.0 != pair.1 {
            #expect(
                Bool(false),
                """
                第 \(i + 1) 行（规范化后）分歧：
                  CLAUDE.md: \(pair.0)
                  AGENTS.md: \(pair.1)
                两者须保持同步；若这是一处新的、合法的定位差异，把它显式加进本文件的白名单，
                不要放宽比较规则。
                """
            )
        }
    }

    @Test("白名单本身有效——三处已知定位差异确实存在于文件中")
    func whitelistEntriesActuallyExist() throws {
        let root = Self.repoRoot()
        let claude = try String(contentsOf: root.appendingPathComponent("CLAUDE.md"), encoding: .utf8)
        let agents = try String(contentsOf: root.appendingPathComponent("AGENTS.md"), encoding: .utf8)

        #expect(agents.contains(Self.bannerPrefix), "AGENTS.md 的镜像 banner 已不存在——白名单第 1 条失效")
        #expect(claude.contains(Self.titles[0]), "CLAUDE.md 标题行已变——白名单第 2 条失效")
        #expect(agents.contains(Self.titles[1]), "AGENTS.md 标题行已变——白名单第 2 条失效")
        #expect(claude.contains(Self.intros[0]), "CLAUDE.md 定位句已变——白名单第 3 条失效")
        #expect(agents.contains(Self.intros[1]), "AGENTS.md 定位句已变——白名单第 3 条失效")
    }
}
