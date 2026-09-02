import Foundation
import Testing

// MARK: - AGENTS.md 与 CLAUDE.md 的一致性守卫（Issue #223）
//
// `AGENTS.md` 自称是 `CLAUDE.md` 的 Codex 版镜像，并承诺「未来 `CLAUDE.md` 更新时须同步
// 本文件」。**该义务已被违反过一次**：#41 把「`LightButtonStyle` 会按 `colorScheme` 分支」
// 这句实测为假的断言从 `CLAUDE.md` 删掉并补了更正段，`AGENTS.md` 没跟上——于是仓库里
// 长期存在一份对 Codex 生效、且携带已知假断言的指引。
//
// 「靠人记得同步」已被证伪一次，故改为机器守卫。
//
// **白名单是显式枚举，不是宽松正则**：只允许下列三处已知的定位差异，其余任何分歧即红。
// 用正则去"吃掉"任意差异会让守卫退化成永真断言——那正是它要防的东西。

@Suite("AGENTS.md 与 CLAUDE.md 保持同步")
struct AgentGuideSyncGuard {

    /// 允许的差异 1：`AGENTS.md` 顶部的镜像声明 banner（`CLAUDE.md` 无对应行）。
    private static let bannerPrefix = "> **本文件是 `CLAUDE.md` 的 Codex 版镜像。"

    /// 允许的差异 2：标题行。
    private static let titles = ["# CLAUDE.md", "# AGENTS.md"]

    /// 允许的差异 3：首段定位句。
    private static let intros = [
        "本文件为 Claude Code (claude.ai/code) 在本仓库中工作时提供指引。",
        "本文件为 Codex 在本仓库中工作时提供指引。",
    ]

    private static func repoRoot() -> URL {
        // Tests/CoreDesignTests/<this file> -> 上溯三级到仓库根
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    /// 归一化：剔除 banner，把标题与定位句替换成占位符，去掉空行。
    /// 空行差异不算实质分歧（两文件因 banner 导致的段落间距不同）。
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
        // 防止白名单腐烂成永真条款：若某条白名单对应的文本已不在文件里，
        // 它就是一条死规则，会掩护未来真正的分歧。
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
