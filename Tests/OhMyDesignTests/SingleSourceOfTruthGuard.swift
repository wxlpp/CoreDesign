import Foundation
import Testing

@Suite("判定说明的唯一真源（#316）")
struct SingleSourceOfTruthGuard {
    private static let sourceOfTruth = "docs/contract-defects.md"

    private static let anchors = ["D-299-1", "D-299-2"]

    /// ⚠️ **按裸子串匹配**：`全口径` 这类通用词组会被**含它的更长词**命中
    /// （实测「安**全口径**统一后再核」判红）。这是有意的 fail-closed，改措辞即可通过
    /// —— 失败消息带命中处上下文，就是为了让这种误伤一眼读得出来，不用去查扫描面配置。
    private static let sourceOnly = [
        "第 2 轮终审 F-2",
        "第 2 轮终审 F-4",
        "基数统一为 2",
        "全口径",
        "用放宽后的谓词判",
        "两处基数不得再打架",
        "3D Ellipse",
        "UICalendarViewDecoration.h",
        "arm64e-apple-ios.swiftinterface:2338",
        "MarkDimensions<DataElement>",
        "Creates a default decoration with a circle image",
    ]

    private static let landingSites = [
        "docs/components/activity-heatmap.md",
        "docs/components/radar-chart.md",
        "docs/components/ring-chart.md",
    ]

    private static let pointer = "`docs/contract-defects.md` 的 `D-299-1`"

    private static let pointerD2 = "`docs/contract-defects.md` 的 `D-299-2`"

    private static let registryComponents = ["ActivityHeatmap", "RadarChart", "RingChart"]

    /// `#316` 收口方案第 3 条要的那张「事实键 → 落点清单」表。
    ///
    /// 上面 `sourceOnly` 管的是**论证**（只许待在真源里）；本表管的是**结论**——它按设计
    /// 分散在各组件本地，收不掉，只能逐处钉死。
    ///
    /// ⚠️ 这一条不是假想：`#315` 第 4 轮普查发现「`RingChart` 计入数 3 → ≤1」这个事实
    /// **实有 5 处**——上一轮**只改了 1 处**（真源），终审点名「两份副本」（合计 3），
    /// **连终审自己的落点计数也少了两处**。扇出面已经大到人肉普查普遍数错。
    ///
    /// ⚠️⚠️ **清单按「处」登记，不是按文件**：评论 ② 数错的正是「同一文件里有两处、
    /// 人肉只数到一处」。只钉文件集合时，把同文件的第 2 处静默删掉**判不出来**（实测全绿）。
    ///
    /// ⚠️ **只钉这一条事实**，理由**不是**「其余几组已被 `sourceOnly` 覆盖」——四组样板短语里
    /// `sourceOnly` 收了三组，**唯一不收的是 `按 Swift Charts 口径`**：它是 PR #324 点名
    /// **有意不收口**的**结论限定词**，出现在每条组件本地的结论里、没有单一的更正值可钉，
    /// 本表也管不了它。
    /// ⚠️ **有意不写任何「几处」的计数**：写下计数的那句话本身就会变成新的一处
    /// （`#316` 实测过一次）。要数就现场 `git grep`。
    ///
    /// ⚠️ 本表判的是**短语计数 + 更正值正则**，不是 `#316` 收口方案第 3 条字面写的
    /// 「每个落点**逐字包含**当前措辞」——各落点的措辞本来就不逐字相同。这是有意的弱化。
    /// ⚠️ **同义改写**（「回到步骤 4」「退回步骤 4」）对短语键表天然不可见，是形态本身的射程。
    private static let factSites: [(key: String, phrase: String, corrected: String, sites: [(path: String, count: Int)])] = [
        (
            key: "RingChart 的计入数会从 3 掉到 ≤1、落点翻回步骤 4",
            phrase: "翻回步骤 4",
            // ⚠️ `≤1` 是 `#315` 第 4 轮的更正值，裸 `1` 是**旧的、已被推翻的**形态。
            // 理由在真源 `D-299-1`，本文件不复述（`全口径` 已进 `sourceOnly`）。
            // ⚠️ 用正则而不是 `contains("≤1")` —— 后者会被 `≤10` / `≤1.5` 满足。
            corrected: "≤ ?1(?![0-9.])",
            sites: [
                ("docs/contract-defects.md", 2),
                ("docs/component-contract-revisions.md", 1),
                ("docs/component-registry.json", 1),
                ("docs/components/ring-chart.md", 1),
            ]
        ),
    ]

    private static let landingSitesD2 = [
        "docs/components/orbiting-logos.md",
        "docs/component-contract-revisions.md",
    ]

    private static var repoRoot: URL { GuardScanRoots.repoRoot }

    /// 本判据自己写着那些短语，扫描时必须跳过——**用精确路径而不是 `hasSuffix`**：
    /// 后者会让任何以同名结尾的文件（`Tests/OhMyDesignChartsTests/ZZSingleSourceOfTruthGuard.swift`）
    /// 一并免检，实测能藏进一句失真的散文而全绿。
    /// ⚠️ 代价：**本文件自身不受本判据保护**。它也是那条事实的一个落点
    /// （上面 `factSites` 的文档注释里写着 `3 → ≤1`）⇒ 改那个值时要连同这里一起改。
    private static let selfPath = "Tests/OhMyDesignTests/SingleSourceOfTruthGuard.swift"

    /// 把连续空白（含换行 / tab / CR）折成单个空格。
    /// ⚠️ 比 `componentDocsPointBack` 那处**更宽**（那边只折 `\n` 与 ≥2 个空格），不要说成「口径一致」。
    private static func folded(_ text: String) -> String {
        text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    /// 命中处前后各 20 个折叠字符，给失败消息用。
    private static func context(_ phrase: String, in body: String, radius: Int = 20) -> String {
        let flat = Self.folded(body)
        guard let hit = flat.range(of: phrase) else { return phrase }
        let start = flat.index(hit.lowerBound, offsetBy: -radius, limitedBy: flat.startIndex)
            ?? flat.startIndex
        let end = flat.index(hit.upperBound, offsetBy: radius, limitedBy: flat.endIndex)
            ?? flat.endIndex
        return String(flat[start..<end])
    }

    #if os(macOS)
    /// ⚠️ **`Process` 只在 macOS 的 Foundation 里有**。不加这个围栏，
    /// `OhMyDesignTests` **整个 target 在 iOS Simulator 腿编译失败**
    /// （`error: cannot find 'Process' in scope`），连带 `DynamicTypeLayoutTests` /
    /// `SurfaceContrastTests` 这些**只在 iOS 腿有效**的 suite 一起失守。
    /// ⚠️ 本地 `swift test` 看不见这个错——那正是 CLAUDE.md 讲的 macOS 假绿。
    private static func trackedFiles() throws -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        // `-z`：⚠️ 默认 `core.quotePath=true` 会把非 ASCII 路径输出成 C 风格转义
        //   （实测 `docs/探针.md` ⇒ `"docs/\346\216\242..."`），读不到就被静默跳过
        //   ——**又一条「本地红 / CI 绿」**（本机 `.gitconfig` 恰好关了 quotePath）。`-z` 下原样输出。
        // `--cached --others --exclude-standard`：连**未跟踪但未被 ignore** 的新文件一起列
        //   （实测：新加的 `docs/zz.md` 不用先 `git add` 就能被判；`.claude/omsp/` 仍不列）。
        process.arguments = ["git", "-C", Self.repoRoot.path, "ls-files", "-z",
                             "--cached", "--others", "--exclude-standard"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            // ⚠️ 不静默降级成 FileManager 枚举 —— 那会让扫描面在两种环境下不同而无人察觉。
            throw GitListFailure(status: process.terminationStatus)
        }
        return (String(data: data, encoding: .utf8) ?? "")
            .split(separator: "\0").map(String.init)
    }

    private struct GitListFailure: Error, CustomStringConvertible {
        let status: Int32
        var description: String { "git ls-files 退出码 \(status) —— 本判据要求在 git 工作树里跑" }
    }
    #endif

    private static func text(_ relativePath: String) throws -> String {
        try String(contentsOf: Self.repoRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }

    @Test("真源文件存在且带着两个锚点")
    func sourceOfTruthExists() throws {
        let source = try Self.text(Self.sourceOfTruth)
        for anchor in Self.anchors {
            #expect(source.contains(anchor), "\(Self.sourceOfTruth) 里找不到锚点 \(anchor)")
        }
    }

    @Test("样板与逐字证据只出现在真源里")
    func boilerplateStaysInSourceOfTruth() throws {
        GuardScanRoots.assertRootsExist(GuardScanRoots.allRoots)
        var roots = GuardScanRoots.allRoots.map(\.url)
        for extra in ["docs", "Tests"] {
            let url = Self.repoRoot.appendingPathComponent(extra)
            #expect(FileManager.default.fileExists(atPath: url.path), "扫描根不存在：\(extra)")
            roots.append(url)
        }

        var scannedPaths = Set<String>()
        var offenders: [String] = []
        for root in roots {
            let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
            while let url = enumerator?.nextObject() as? URL {
                guard ["md", "json", "swift"].contains(url.pathExtension) else { continue }
                let relative = GuardScanRoots.relativePath(url, from: Self.repoRoot)
                guard relative != Self.sourceOfTruth else { continue }
                guard relative != Self.selfPath else { continue }
                guard let body = try? String(contentsOf: url, encoding: .utf8) else { continue }
                scannedPaths.insert(relative)
                for phrase in Self.sourceOnly where body.contains(phrase) {
                    offenders.append(
                        "\(relative) 出现了只应在真源里的「\(phrase)」：…\(Self.context(phrase, in: body))…"
                    )
                }
            }
        }
        let required = Self.landingSites + [
            "docs/component-registry.json",
            "Sources/OhMyDesign/Colors/InteractionColors.swift",
            "Sources/OhMyDesignCharts/RingChart.swift",
            "Sources/OhMyDesignEffects/Confetti.swift",
            "Tests/OhMyDesignTests/GuardScanRoots.swift",
        ]
        for path in required {
            #expect(scannedPaths.contains(path), "扫描面缺少 \(path)，枚举异常")
        }
        #expect(offenders.isEmpty, "\(offenders.joined(separator: " | "))")
    }

    @Test("三份组件文档各自留了指回真源的指针")
    func componentDocsPointBack() throws {
        for site in Self.landingSites {
            let body = try Self.text(site)
            let flattened = body
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
            #expect(flattened.contains(Self.pointer), "\(site) 缺少指针「\(Self.pointer)」")
        }
    }

    @Test("D-299-2 侧的落点也各自留了指针")
    func d2SitesPointBack() throws {
        for site in Self.landingSitesD2 {
            let body = try Self.text(site)
            let flattened = body
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
            #expect(flattened.contains(Self.pointerD2), "\(site) 缺少指针「\(Self.pointerD2)」")
        }
        let data = try Data(contentsOf: Self.repoRoot.appendingPathComponent("docs/component-registry.json"))
        struct Registry: Decodable {
            struct Component: Decodable { let component: String; let notes: String }
            let components: [Component]
        }
        let registry = try JSONDecoder().decode(Registry.self, from: data)
        let orbiting = registry.components.first { $0.component == "OrbitingLogos" }
        #expect(orbiting != nil, "登记表里找不到 OrbitingLogos")
        #expect(orbiting?.notes.contains(Self.pointerD2) == true,
                "OrbitingLogos 的 notes 缺少指针「\(Self.pointerD2)」")
    }

    @Test("registry 的三条 notes 各自留了指回真源的指针")
    func registryNotesPointBack() throws {
        struct Registry: Decodable {
            struct Component: Decodable {
                let component: String
                let notes: String
            }
            let components: [Component]
        }
        let data = try Data(contentsOf: Self.repoRoot.appendingPathComponent("docs/component-registry.json"))
        let registry = try JSONDecoder().decode(Registry.self, from: data)
        for name in Self.registryComponents {
            let entry = registry.components.first { $0.component == name }
            #expect(entry != nil, "登记表里找不到 \(name)")
            guard let notes = entry?.notes else { continue }
            #expect(notes.contains(Self.pointer), "\(name) 的 notes 缺少指针「\(Self.pointer)」")
        }
    }

    /// ⚠️ 用 `.enabled(if:)` **trait** 而不是在体内 `print` 一行 SKIP —— 与
    /// `ColorGradeResolutionGuard` 同形（那条也是 trait，不是 print）。
    /// 差别不是风格：`print` 版在 **xcresult 里记成 `passedTests`**，`skippedTests` 仍是 0
    /// ⇒ 「跳过」只活在 console，而 CLAUDE.md 写明 `xcodebuild` 的 console 不可承重、
    /// 权威值取 result bundle。那样等于往 iOS 腿的 passed 基线里灌一条 no-op。
    nonisolated static let canListTrackedFiles: Bool = {
        #if os(macOS)
        true
        #else
        false
        #endif
    }()

    @Test(
        "每个事实的落点清单是穷尽的：清单里的文件都有它，清单外的文件都没有",
        .enabled(
            if: canListTrackedFiles,
            "跳过：本条走 `git ls-files`（`Process` 只在 macOS 的 Foundation 里有），只在 macOS 腿跑。"
        )
    )
    func factSitesAreExhaustive() throws {
        // ⚠️ 体内这道 `#if` 与上面那个 trait **缺一不可，不是冗余**：
        // `#if` 是**编译**需要（`trackedFiles()` 整个定义在 `#if os(macOS)` 里，删了 iOS 腿
        // 就回到 `cannot find 'Process' in scope` 那条硬红）；trait 是**记账**需要
        // （只靠 `#if` 的话这条在 iOS 上是个空跑的 passed，xcresult 的 `skippedTests` 为 0）。
        #if os(macOS)
        // ⚠️ **扫的是 `git ls-files`，不是 `FileManager` 枚举。** 两个理由：
        // ① 结论类事实的扩散面比论证宽得多——`CLAUDE.md` / `.claude/epics/**` / `App/` 里
        //    写一句同样判不出来（实测），而 `boilerplateStaysInSourceOfTruth` 只扫
        //    `allRoots` + `docs` + `Tests`；
        // ② 一旦把根扩到 `.claude` / `App` / `scripts`，`.gitignore` 掉的
        //    `.claude/omsp/` `App/.derivedData/` `scripts/downstream-probe/.build/`
        //    就都落在扫描面里 ⇒ **判据结果依赖本地状态**（实测：往 `.claude/omsp/` 里写一句
        //    本地判红、CI 绿；主检出上那两个构建目录里有 1300 个会被读的文件）。
        //    只扫**已跟踪文件**同时解决这两条。
        let tracked = try Self.trackedFiles()
        #expect(tracked.count > 100, "git ls-files 只返回 \(tracked.count) 个文件 —— 枚举异常")
        for canary in ["CLAUDE.md", "docs/contract-defects.md", "Package.swift",
                       "App/Sources/ComponentData.swift", "scripts/run-preview.sh"] {
            #expect(tracked.contains(canary), "扫描面缺少 \(canary) —— `git ls-files` 异常")
        }

        for fact in Self.factSites {
            var found: [String: Int] = [:]
            let needle = Self.folded(fact.phrase)
            for relative in tracked {
                guard ["md", "json", "swift"].contains((relative as NSString).pathExtension) else { continue }
                if relative == Self.selfPath { continue }
                let url = Self.repoRoot.appendingPathComponent(relative)
                // ⚠️ 读不出来**抛错**，不 `continue` —— 静默跳过正是上面 quotePath 那条的成因。
                let body = try String(contentsOf: url, encoding: .utf8)
                // ⚠️ **比对前折叠空白**：`#316` 正文 ③ 点名的正是「同一句样板在各副本里换行
                // 位置不同 ⇒ `grep` 兜不住」，而这条判据就是来替代 grep 的。不折叠的第一版
                // 对「翻回步骤\n4」这种未登记副本实测全绿。
                let hits = Self.folded(body).components(separatedBy: needle).count - 1
                if hits > 0 { found[relative] = hits }
            }
            let paths = fact.sites.map(\.path)
            #expect(Set(paths).count == paths.count,
                    "事实「\(fact.key)」的落点清单里有重复路径 \(paths) —— 表本身的笔误应当判红，不是让进程崩")
            let expected = Dictionary(paths.indices.map { (paths[$0], fact.sites[$0].count) },
                                      uniquingKeysWith: { a, _ in a })
            #expect(found == expected, """
            事实「\(fact.key)」的落点清单对不上（**按「处」比，不是按文件**）。
            清单：\(expected.sorted { $0.key < $1.key })
            实得：\(found.sorted { $0.key < $1.key })

            ⚠️ 三个方向都要处理：**新增落点必须登进清单**（否则下次更正又会漏掉它，
            `#315` 第 4 轮就是这么漏了两处的）；**清单里的落点消失也要判红**；
            **同一文件里少一处 / 多一处同样判红** —— 评论 ② 数错的正是这一层，
            只钉文件集合时它判不出来。
            """)
        }
        #endif
    }

    @Test("每个落点上写的都是更正后的取值，不是被推翻的旧值")
    func factSitesCarryTheCorrectedValue() throws {
        for fact in Self.factSites {
            for site in fact.sites.map(\.path) {
                let body = Self.folded(try Self.text(site))
                var cursor = body.startIndex
                var occurrence = 0
                let needle = Self.folded(fact.phrase)
                while let range = body.range(of: needle, range: cursor..<body.endIndex) {
                    occurrence += 1
                    cursor = range.upperBound
                    let lower = body.index(range.lowerBound, offsetBy: -160, limitedBy: body.startIndex)
                        ?? body.startIndex
                    let context = String(body[lower..<range.lowerBound])
                    let matched = context.range(of: fact.corrected, options: .regularExpression) != nil
                    #expect(matched, """
                    \(site) 第 \(occurrence) 处「\(fact.phrase)」附近没有更正后的取值
                    （正则 `\(fact.corrected)`）——写成裸 `1` 是已被 `#315` 第 4 轮推翻的旧形态
                    （精确值是 `≤1` 不是 `1`；理由见真源 `D-299-1`）。

                    上下文：…\(context.suffix(80))
                    """)
                }
            }
        }
    }
}
