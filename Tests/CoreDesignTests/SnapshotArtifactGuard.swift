import Foundation
import Testing

// MARK: - 快照产物的「产地」判据 / Snapshot artifact provenance guard（Issue #256）
//
// ## 它守什么
//
// `scripts/run-snapshots.sh` 用 SnapshotPreviews 渲染**所有链入模块**的 `#Preview`，
// 产物文件名前缀是**模块名**：`<Module>_<file>_<preview name>.{png,json}`。
// 提交态的约定是「只收 `App/Sources/Previews.swift` 驱动的产物」（`CoreDesignPreview_*`）——
// 库内 `#Preview` 是副产品，脚本在默认模式的收尾一步把它们删掉。
//
// ## 为什么要一条判据，而不是「脚本里那一行就够了」
//
// ⚠️ 脚本那一行在 `#245` 之后**静默失效过**：它当时是 `-name "CoreDesign_*"`（黑名单），
// 而 glob 要求 "CoreDesign" 后紧跟下划线 ⇒ `CoreDesignEffects_*` / `CoreDesignCharts_*`
// 一个都不匹配。**在 `#256` 把两个新 product 接进画廊之前，这个洞看不出来**——
// 两个模块的 preview 压根没被渲染（未被 App 引用 ⇒ 扫描器看不到它们）。
// 一接进画廊，默认模式就会把 40 个库内产物连同 JSON 提交进 `docs/snapshots`。
//
// ⇒ 「脚本改对了」这件事本身需要一条**树内**判据看着：脚本只在有人手跑时才执行，
// 而 `swift test` 每次都跑。
//
// ## 射程与已知边界（不要读成比实际更强）
//
// ⚠️ **本判据不跑渲染**，只看两样东西：提交态的**文件名**，与脚本里那一行的**形态**。
// 它挡的是「库内产物漏进提交态」和「有人把白名单改回按模块名的黑名单」。
// 它**不**判断任何 PNG 的内容是否确定——「非确定 PNG」这件事本身由**产地**规则解决
// （库内 preview 一律不进提交态，确定与否都不进），逐 preview 的确定性实测记录在
// `scripts/run-snapshots.sh` 默认模式那段注释里。
//
// ⚠️ 本判据也**不**管既有的 3 个漂移的宿主快照
// （`ProgressIndicator` / `Spinning` / `Spinning_Presentations`，实测三次渲染次次不同）。
// 那是 `#256` 之前就存在的状况、且它们是**合法的**宿主产物（产地对），
// 本判据按定义放行。要治它得改那三个 `#Preview` 本身，不在 `#256` 射程内。
@Suite("#256 快照产物的产地纪律")
struct SnapshotArtifactGuard {

    /// 唯一允许出现在提交态 `docs/snapshots/` 里的文件名前缀。
    ///
    /// ⚠️ 它是**模块名 + 下划线**：宿主 App 的 target 叫 `CoreDesignPreview`。
    nonisolated static let committedPrefix = "CoreDesignPreview_"

    static var snapshotsDirectory: URL {
        ComponentRegistryGuard.repoRoot.appendingPathComponent("docs/snapshots")
    }

    static var runScriptURL: URL {
        ComponentRegistryGuard.repoRoot.appendingPathComponent("scripts/run-snapshots.sh")
    }

    /// 判定一个产物文件名是否允许进提交态。**判据本体，抽成纯函数以便自证会开火。**
    nonisolated static func isCommittable(_ fileName: String) -> Bool {
        fileName.hasPrefix(Self.committedPrefix)
    }

    @Test("J1：docs/snapshots 里不得出现任何库内 `#Preview` 的产物")
    func committedSnapshotsAreHostOnly() throws {
        let directory = Self.snapshotsDirectory
        // ⚠️ **必须先断言目录存在且非空**：`contentsOfDirectory` 对不存在的路径会 throw，
        // 但一个**空**目录会让下面的全称断言在空集上恒真 ——「零文件 ⇒ 零违规 ⇒ 绿」
        // 正是本仓反复记在案的病型。
        let names = try FileManager.default
            .contentsOfDirectory(atPath: directory.path)
            .filter { $0 != ".DS_Store" }
        try #require(names.count > 20, """
        docs/snapshots 只有 \(names.count) 个文件 —— 目录疑似被清空或路径读错，
        这不是「零违规」。
        """)

        let leaked = names.filter { !Self.isCommittable($0) }.sorted()
        #expect(leaked.isEmpty, """
        提交态里出现了非宿主产物（前缀不是 `\(Self.committedPrefix)`）：
        \(leaked.joined(separator: "\n"))

        它们是 `Sources/CoreDesign*/` 里的库内 `#Preview` 渲染出来的副产品，
        约定不入库（`scripts/run-snapshots.sh` 默认模式收尾会删掉它们）。
        出现在这里说明：要么有人手工拷进来，要么脚本那条清理规则被改坏了。
        """)
    }

    /// 脚本里**去掉注释行**之后的可执行文本。
    ///
    /// ⚠️ **这一步是必需的，不是洁癖**：本判据的失败信息里逐字引用了那条旧的黑名单
    /// `-name "CoreDesign_*"`，脚本自己的注释里也复述了它。不剥注释的话，
    /// 「不得再出现黑名单」那条会被**注释里的引用**打红 —— 判据会因为
    /// 「有人把历史写清楚了」而变红，那是错误的激励方向（实测：本判据首跑即此形态红）。
    nonisolated static func executableLines(of script: String) -> String {
        script
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("#") }
            .joined(separator: "\n")
    }

    @Test("J2：清理规则必须是按产地的白名单，不是按模块名的黑名单")
    func cleanupRuleIsAProvenanceAllowList() throws {
        let raw = try String(contentsOf: Self.runScriptURL, encoding: .utf8)
        let script = Self.executableLines(of: raw)
        try #require(script.contains("find docs/snapshots"), """
        `scripts/run-snapshots.sh` 里找不到对 docs/snapshots 的清理步骤 ——
        判据无法工作，这不是「规则没问题」。
        """)

        #expect(
            script.contains(#"! -name "CoreDesignPreview_*""#),
            """
            默认模式的清理步骤不是「保留 `CoreDesignPreview_*`、其余全删」的白名单形态。

            ⚠️ 这条判据存在的理由是一次**真实失效**：`#245` 加了
            `CoreDesignEffects` / `CoreDesignCharts` 两个 product 之后，
            原来的黑名单 `-name "CoreDesign_*"` 对这两个模块的产物
            **一个都不匹配**（glob 要求 "CoreDesign" 后紧跟下划线），
            而在 `#256` 把它们接进画廊之前**这个洞观察不到**。
            黑名单对「新出现的模块」是空真 —— 换回去等于把洞打开。
            """
        )
        #expect(
            !script.contains(#"-name "CoreDesign_*""#),
            """
            清理步骤里仍留着按模块名前缀的黑名单 `-name "CoreDesign_*"` ——
            它与白名单并存只会让下一个读者以为黑名单还在承重。
            """
        )
    }

    @Test("J3：判据自证会开火 —— 合成文件名与合成脚本逐个打红")
    func judgeActuallyFires() {
        // 注释剥离必须真的在剥：一段只有注释的脚本里，黑名单不算数、白名单也不算数。
        let commentOnly = """
        # /usr/bin/find docs/snapshots -type f ! -name "CoreDesignPreview_*" -delete
        #   旧形态：-name "CoreDesign_*"
        """
        #expect(!SnapshotArtifactGuard.executableLines(of: commentOnly).contains("CoreDesign"),
                "注释剥离失效 —— J2 的两条断言都会读到注释里的字面量")
        let codeOnly = """
        /usr/bin/find docs/snapshots -type f ! -name "CoreDesignPreview_*" -delete
        """
        #expect(SnapshotArtifactGuard.executableLines(of: codeOnly).contains(#"! -name "CoreDesignPreview_*""#))

        // ⚠️ 没有这条，J1 与「目录里恰好没有违规」不可分辨：`isCommittable` 若被改成
        // 恒真（比如 `hasPrefix("CoreDesign")`），J1 照样绿，而 `CoreDesignEffects_*`
        // 与 `CoreDesign_*` 会被一起放行 —— 那正是 `#245` 那个洞的形状。
        #expect(SnapshotArtifactGuard.isCommittable("CoreDesignPreview_Previews.swift_Badge.png"))
        #expect(SnapshotArtifactGuard.isCommittable("CoreDesignPreview_Previews.swift_Badge.json"))

        for leaked in [
            "CoreDesign_Badge.swift_Badge_-_light.png",
            "CoreDesignEffects_Confetti.swift_confetti.png",
            "CoreDesignCharts_RadarChart.swift_RadarChart.png",
            // ⚠️ 未来的第四个模块：黑名单形态对它同样是空真，白名单形态挡得住。
            "CoreDesignShaders_GlassOrb.swift_GlassOrb.png",
        ] {
            #expect(!SnapshotArtifactGuard.isCommittable(leaked),
                    "「\(leaked)」应当被判为不可提交，实际放行了")
        }
    }
}
