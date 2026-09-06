import Foundation
import Testing

// MARK: - 快照产物的「产地」判据 / Snapshot artifact provenance guard（Issue #256）

@Suite("#256 快照产物的产地纪律")
struct SnapshotArtifactGuard {
    nonisolated static let committedPrefix = "CoreDesignPreview_"

    static var snapshotsDirectory: URL {
        ComponentRegistryGuard.repoRoot.appendingPathComponent("docs/snapshots")
    }

    static var runScriptURL: URL {
        ComponentRegistryGuard.repoRoot.appendingPathComponent("scripts/run-snapshots.sh")
    }

    nonisolated static func isCommittable(_ fileName: String) -> Bool {
        fileName.hasPrefix(Self.committedPrefix)
    }

    @Test("J1：docs/snapshots 里不得出现任何库内 `#Preview` 的产物")
    func committedSnapshotsAreHostOnly() throws {
        let directory = Self.snapshotsDirectory
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

        #expect(SnapshotArtifactGuard.isCommittable("CoreDesignPreview_Previews.swift_Badge.png"))
        #expect(SnapshotArtifactGuard.isCommittable("CoreDesignPreview_Previews.swift_Badge.json"))

        for leaked in [
            "CoreDesign_Badge.swift_Badge_-_light.png",
            "CoreDesignEffects_Confetti.swift_confetti.png",
            "CoreDesignCharts_RadarChart.swift_RadarChart.png",
            "CoreDesignShaders_GlassOrb.swift_GlassOrb.png",
        ] {
            #expect(!SnapshotArtifactGuard.isCommittable(leaked),
                    "「\(leaked)」应当被判为不可提交，实际放行了")
        }
    }
}
