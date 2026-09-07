import Foundation
import Testing

// MARK: - 散文里的裸行号引用：只出不进（Issue #337）

@Suite("散文里的裸行号引用只出不进（#337）")
struct BareLineRefGate {
    /// 存量登记：**文件 → 该文件里 `X.swift:NN` 形式的裸行号引用（逐条命中串，已排序）**。
    ///
    /// ⚠️ **登记的是「命中串」不是「条数」**：只数条数时，把 `Sidebar.swift:157` 原地改成
    /// `Totally/Wrong.swift:9999` **判据全绿**（终审实测）—— 而「改一段文字时顺手把行号
    /// 更新成新数字 / 把引用换到另一个文件」正是**最日常的编辑形态**，比新增更常见。
    ///
    /// ⚠️ **这是「只出不进」的门禁，不是「都合规」的清单** —— 表里绝大多数已经失真。
    /// 本表只把**新增与改写**挡在门外，存量按 `#337` 的形态 2 分批清。
    ///
    /// ⚠️ **射程**：`docs/**/*.{md,json}` + **仓根全部 `*.md`**。`.claude/` 下的 PRD / epic /
    /// archived 是历史档，有意不进（`#346` 已按此办）。
    /// ⚠️ **`docs/superpowers/` 下的 plan / spec 也算活文档**（它们在 `docs/` 里）——
    /// 分界就是「在不在 `docs/` 下」，不按内容是否已执行完判。
    ///
    /// ⚠️ **射程外还有约 49 条同病的裸行号**（终审量化）：44 条引 **非 `.swift`** 文件
    /// （`.md` / `.metal` 等），约 5 条中文「第 N 行」。⇒ 今天约 **23%** 的裸行号引用不在门禁里。
    /// 收它们要把正则放宽成 `\.(swift|md|json|metal|yml):[0-9]+` 并重生成本表 —— 未做，登记在此。
    private nonisolated static let allowance: [(path: String, refs: [String])] = [
        ("docs/contract-defects.md", [
            "ActivityHeatmap.swift:12-13", "ActivityHeatmap.swift:12-13", "AvatarGroup.swift:46",
            "ComponentJudgeRules.swift:70-72", "ComponentJudgeRules.swift:71", "ComponentJudgeRules.swift:86-88",
            "FocusModeContainer.swift:32", "Form.swift:115-117", "Form.swift:87-98",
            "NetworkGraph.swift:12-13", "NetworkGraph.swift:13", "RadarChart.swift:12",
            "RadarChart.swift:12", "RingChart.swift:12-13", "RingChart.swift:13",
            "Sidebar.swift:355-363", "Sidebar.swift:404-406", "Sidebar.swift:62-67",
            "Sources/CoreDesign/Components/AvatarGroup/AvatarGroup.swift:18", "Sources/CoreDesign/Components/Form/Form.swift:107-120", "Sources/CoreDesign/Components/Form/Form.swift:27-75",
            "Sources/CoreDesign/Components/Form/Form.swift:87-98", "Sources/CoreDesign/Components/Section/SectionFooter.swift:20-41", "Sources/CoreDesign/Components/Section/SectionHeader.swift:15-17",
            "Sources/CoreDesign/Components/SettingsRow/SettingsRow.swift:56-65", "Sources/CoreDesign/Components/Sidebar/Sidebar.swift:116-159", "Sources/CoreDesign/Components/Sidebar/Sidebar.swift:220-224",
            "Sources/CoreDesign/Components/Sidebar/Sidebar.swift:221", "Sources/CoreDesign/Components/Sidebar/Sidebar.swift:307-334", "Sources/CoreDesign/Components/Sidebar/Sidebar.swift:33-80",
            "Sources/CoreDesign/Components/StateLabel/StateLabel.swift:31", "Sources/CoreDesign/Components/Style/Descriptions.swift:99", "Sources/CoreDesign/Modifier/FloatingGlassModifier.swift:10-17",
            "Sources/CoreDesign/Modifier/TelegramGlassButtonModifier.swift:58-95", "StoryScaffold.swift:47", "SurfaceModifier.swift:12-13",
            "Tests/CoreDesignTests/ComponentExtensionPointGuard.swift:134", "Tests/CoreDesignTests/ComponentExtensionPointGuard.swift:134", "Tests/CoreDesignTests/ComponentJudgeRules.swift:378",
            "Tests/CoreDesignTests/ComponentJudgeRules.swift:70-113", "Tests/CoreDesignTests/ComponentJudgeRules.swift:71", "Tests/CoreDesignTests/ComponentJudgeRules.swift:71",
            "Tests/CoreDesignTests/ComponentJudgeRules.swift:71", "Timeline.swift:64", "ToolCallRow.swift:159",
            "X.swift:12-13",
        ]),
        ("docs/component-registry.json", [
            "AvatarGroup.swift:46", "Descriptions.swift:112-122", "FloatingGlassModifier.swift:10-17",
            "Form.swift:114", "Form.swift:115-117", "Form.swift:36",
            "Form.swift:84-86", "Form.swift:87-98", "Form.swift:87-98",
            "Form.swift:87-98", "OrbitRing.swift:44", "OrbitingLogos.swift:275-293",
            "ProgressIndicator.swift:53-78", "SectionFooter.swift:20-41", "SectionHeader.swift:42-44",
            "SectionHeader.swift:42-44", "SettingsRow.swift:129", "SettingsRow.swift:39-51",
            "SettingsRow.swift:56-65", "SettingsRow.swift:61-62", "Sidebar.swift:220-230",
            "Sidebar.swift:313-329", "Sidebar.swift:320-321", "Sidebar.swift:34-42",
            "Sidebar.swift:404-406", "Sidebar.swift:404-406", "Sidebar.swift:46-68",
            "Sidebar.swift:62-67", "Sidebar.swift:62-67", "Sources/CoreDesign/Components/Radio/Radio.swift:37-39",
            "Sources/CoreDesign/Components/Sidebar/Sidebar.swift:116-159", "Sources/CoreDesign/Components/StateLabel/StateLabel.swift:31", "Sources/CoreDesignCharts/ActivityHeatmap.swift:12-13",
            "Sources/CoreDesignCharts/NetworkGraph.swift:13-14", "Sources/CoreDesignCharts/RadarChart.swift:12", "Sources/CoreDesignCharts/RingChart.swift:12-13",
            "SpinningModifier.swift:44-60", "Style/CoreProgressViewStyle.swift:37", "TelegramGlassButtonModifier.swift:59-64",
            "Timeline.swift:151",
        ]),
        ("docs/component-contract-revisions.md", [
            "AvatarGroup.swift:46", "CircularGlassButtonStyle.swift:12", "CodexEntry.swift:11-12",
            "CodexEntry.swift:173", "ComponentJudgeScanner.swift:135-136", "Descriptions.swift:112-122",
            "FloatingGlassModifier.swift:10-17", "Form.swift:115-117", "Form.swift:87-98",
            "Form.swift:87-98", "LightButtonStyle.swift:14", "NetworkGraph.swift:13",
            "SectionFooter.swift:20-41", "SectionHeader.swift:42-44", "SettingsRow.swift:56-65",
            "Sidebar.swift:313-329", "Sidebar.swift:34-42", "Sidebar.swift:404-406",
            "Sidebar.swift:62-67", "SolidButtonStyle.swift:18", "Sources/CoreDesign/Components/Sidebar/Sidebar.swift:116-159",
            "Sources/CoreDesign/Components/StateLabel/StateLabel.swift:31", "Sources/CoreDesign/Modifier/SurfaceModifier.swift:12-13", "Steps.swift:49",
            "SurfaceModifier.swift:32", "TelegramGlassButtonModifier.swift:59-64", "Tests/CoreDesignTests/ComponentJudgeRules.swift:378",
            "Timeline.swift:220", "Timeline.swift:61",
        ]),
        ("docs/issues/234-a11y-smoke.md", [
            "App/Sources/ComponentData.swift:418", "BottomInputBar.swift:151", "Carousel.swift:115",
            "Carousel.swift:115", "CoreMenuButton.swift:143", "PinCode.swift:106",
            "Radio.swift:82", "Radio.swift:82", "Rating.swift:188-197",
            "SearchField.swift:18", "SearchField.swift:40", "SectionHeader.swift:27",
            "SegmentedControl.swift:147", "SegmentedControl.swift:147", "Sidebar.swift:109",
            "SpinningModifier.swift:128",
        ]),
        ("docs/component-contract.md", [
            "Banner.swift:77", "CodexEntry.swift:11-12", "CodexEntry.swift:11-12",
            "CodexEntry.swift:11-12", "ComponentJudgeScanner.swift:135-136", "ComponentRegistryGuard.swift:366",
            "CrossRepoRegistryGuard.swift:98-105", "CrossRepoRegistryGuard.swift:98-105", "SegmentedControl.swift:66",
            "Sources/CoreDesign/Components/Sidebar/Sidebar.swift:221", "Sources/CoreDesign/Components/Steps/Steps.swift:49", "Sources/CoreDesign/Components/Timeline/Timeline.swift:220",
            "Sources/CoreDesign/Components/Timeline/Timeline.swift:64", "TextParamScan.swift:127", "TextParamScan.swift:127",
        ]),
        ("docs/superpowers/plans/2026-05-31-blossom-theme.md", [
            "Package.swift:6-32", "Sources/CoreDesign/Colors/ColorGrade.swift:11-23", "Sources/CoreDesign/Colors/FunctionalColor.swift:17-20",
            "Sources/CoreDesign/Colors/InteractionColors.swift:10-13", "Sources/CoreDesign/Colors/SurfaceColors.swift:49-67",
        ]),
        ("docs/superpowers/specs/2026-05-13-async-button-design.md", [
            "BorderlessButtonStyle.swift:49", "SolidButtonStyle.swift:40", "Toast.swift:287-289",
        ]),
        ("docs/bool-exemptions.json", [
            "BottomInputBar.swift:468", "FloatingGlassModifier.swift:20",
        ]),
        ("docs/components/orbiting-logos.md", [
            "OrbitRing.swift:44", "OrbitingLogos.swift:275-293",
        ]),
        ("docs/BREAKING-CHANGES.md", [
            "Sidebar.swift:157",
        ]),
        ("docs/a11y-exemptions.json", [
            "TagInput.swift:105",
        ]),
        ("docs/reachable-type-registry.json", [
            "CodexEntry.swift:11-12",
        ]),
        ("docs/spikes/248-metal-packaging.md", [
            "Tests/CoreDesignTests/ColorAssetGuardTests.swift:70",
        ]),
    ]

    /// ⚠️ 与 `#337` 普查用的是**同一条**正则，换了它两边的数就对不上。
    private nonisolated static let pattern = "[A-Za-z0-9_/.-]+\\.swift:[0-9]+(-[0-9]+)?"

    private nonisolated static func refs(in text: String) throws -> [String] {
        let re = try NSRegularExpression(pattern: Self.pattern)
        let ns = text as NSString
        return re.matches(in: text, range: NSRange(location: 0, length: ns.length))
            .map { ns.substring(with: $0.range) }
            .sorted()
    }

    @Test("#337：活文档里的裸行号引用只出不进——新增、改写、换目标一律判红")
    func bareLineRefsAreRegistered() throws {
        let root = GuardScanRoots.repoRoot
        let docsRoot = root.appendingPathComponent("docs")

        // ⚠️ **扫描根不存在要判红，不是 skip**：整个根读不出来时「零违规」是假的
        // （终审实测：`.enabled(if:)` 形态下 `mv docs docs_` ⇒ 静默 skip、EXIT=0）。
        // 本仓成例见 `GuardScanRoots.assertRootsExist`：「判据无法工作，这不是零违规」。
        #expect(FileManager.default.fileExists(atPath: docsRoot.path),
                "扫描根 docs/ 不存在 —— 判据无法工作，这不是零违规")

        var files: [URL] = []
        let enumerator = FileManager.default.enumerator(at: docsRoot, includingPropertiesForKeys: nil)
        #expect(enumerator != nil, "docs/ 枚举器建不出来 —— 同上，不是零违规")
        while let url = enumerator?.nextObject() as? URL {
            guard ["md", "json"].contains(url.pathExtension) else { continue }
            files.append(url)
        }
        // 仓根全部 `*.md`（⚠️ 不是只有 CLAUDE.md / README.md —— `AGENTS.md` 是
        // `CLAUDE.md` 的 Codex 镜像，同样是活文档）
        for url in (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        where url.pathExtension == "md" {
            files.append(url)
        }

        var actual: [String: [String]] = [:]
        for url in files {
            let relative = GuardScanRoots.relativePath(url, from: root)
            // ⚠️ 读不出来就抛错，不 `continue` —— 静默跳过会让新增混进来。
            let hits = try Self.refs(in: try String(contentsOf: url, encoding: .utf8))
            if !hits.isEmpty { actual[relative] = hits }
        }

        // ⚠️ 重复键要判红，不能让 `Dictionary(uniqueKeysWithValues:)` 崩掉整个进程
        // （终审实测：崩溃会连累同 bundle 的其它 suite 一起没跑）。
        let paths = Self.allowance.map(\.path)
        #expect(Set(paths).count == paths.count, "allowance 有重复键：\(paths.count - Set(paths).count) 个")
        let expected = Dictionary(Self.allowance.map { ($0.path, $0.refs) }, uniquingKeysWith: { a, _ in a })

        for path in Set(expected.keys).union(actual.keys).sorted() {
            let now = actual[path] ?? []
            let cap = expected[path] ?? []
            guard now != cap else { continue }
            let onDisk = FileManager.default.fileExists(atPath: root.appendingPathComponent(path).path)
            let added = now.filter { !cap.contains($0) }
            let gone = cap.filter { !now.contains($0) }
            Issue.record("""
            \(path) 的裸行号引用与登记表不符（本判据比的是**逐条命中串**，不是条数）。
            \(onDisk ? "" : "⚠️ 该文件**已不在磁盘上** —— 删了请从 allowance 去掉；改名请同步键。\n")\
            多出来 \(added.count) 条：\(added.isEmpty ? "（无）" : added.joined(separator: "、"))
            少掉了 \(gone.count) 条：\(gone.isEmpty ? "（无）" : gone.joined(separator: "、"))

            · **多出来** ⇒ 改成**引文逐字**（形态 2）：写「`Foo.body` 逐字是 `.coreFont(.footnote)`」
              这类**符号 + 原文片段**，而不是 `Foo.swift:23-25`。
              ⚠️ 行号漂了指向的是「看起来合理的别的内容」，读者**以为自己核过了**；
              逐字引文漂了会 `grep` 得 **0 命中**，读者**知道**自己没核到。
            · **少掉了** ⇒ 好事，**把 allowance 一起改小**，否则棘轮松掉。
            · **两边都有** ⇒ 引用被**原地改写**了（换行号或换目标文件）。⚠️ 这是最日常的编辑形态，
              也是「只数条数」的判据完全看不见的那一种。
            """)
        }
    }
}
