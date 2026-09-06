import Foundation
import Testing

/// 判定说明的「一处事实一个落点」判据（`#316`）。
///
/// ⚠️ **它接住的是什么**：`#299` 那批判定说明曾被**逐字抄进 6 份落点**
/// （3 份 `docs/component-registry.json` 的 `components[].notes` +
/// 3 份 `docs/components/*.md`），一处更正要人工同步 6 次。
/// `#315` 第 3 轮终审的 C-1 就是那么漏的——「可逆性降级」那条更正只扫到一半、4 处残留。
///
/// ⚠️ **已知缺口，别把本套判据读成完备**：它只认**逐字**短语 ⇒ **同义复述后再抄回来抓不住**。
/// 兜的是「原样复制」，不是「改写复制」。
///
/// ⚠️ **为什么 `grep` 兜不住、必须有判据**：同一句样板在各副本里**换行位置不同**
/// ——`grep -c "C-2 要求逐条重判" docs/components/radar-chart.md` 得 1，
/// 同一命令对 `activity-heatmap.md` 得 0。⇒ 按行 grep 会漏，判据按**全文**匹配。
@Suite("判定说明的唯一真源（#316）")
struct SingleSourceOfTruthGuard {

    /// 真源文件。⚠️ 改名 / 删除必须让本套判据判红，不能静默放过。
    private static let sourceOfTruth = "docs/contract-defects.md"

    /// 真源里必须存在的锚点。
    private static let anchors = ["D-299-1", "D-299-2"]

    /// **只允许出现在真源里**的样板 / 逐字证据。
    ///
    /// ⚠️ 选取标准：**同一份事实**的表述，而不是「碰巧同名的词」。
    /// 各组件自己的结论句（如「候选 1 与候选 2 …不命中」，候选编号逐条不同）
    /// **不在此列**——那是组件本地的判定结果，收口它会让每条枚举没有结论。
    /// ⚠️ **每一段都必须同时钉「标签」与「论证内容」**：只钉标签会被**丢掉一句标签**绕过
    /// ——复述时最先丢的就是「`#315` 第 2 轮终审 F-2：」这个前缀，而评审轮次标签
    /// 每轮还在改名（F-2 / I-4 / S-2…）。实测：把论证整段粘回 `radar-chart.md`、
    /// 只不带标签句，只钉标签的版本**全绿**。
    private static let sourceOnly = [
        // 引用标签
        "第 2 轮终审 F-2",
        "第 2 轮终审 F-4",
        // ⚠️ `基数统一为 2` 与上面那个 F-4 标签在真源里是**同一行**，不是两个独立锚点
        //（`docs/contract-defects.md` 的 F-4 段行首）⇒ 只有它们时，把下面两行论证
        // 原样粘回副本、不带那一句，判据仍绿（实测）。
        "基数统一为 2",
        // 论证内容本身（标签被丢掉时由它们接住）
        "用放宽后的谓词判",
        "两处基数不得再打架",
        "3D Ellipse",
        // 逐字外部证据
        "UICalendarViewDecoration.h",
        "arm64e-apple-ios.swiftinterface:2338",
        "MarkDimensions<DataElement>",
        "Creates a default decoration with a circle image",
    ]

    /// 组件文档侧的落点（registry 侧见 `registryComponents`）。
    private static let landingSites = [
        "docs/components/activity-heatmap.md",
        "docs/components/radar-chart.md",
        "docs/components/ring-chart.md",
    ]

    /// 指针的**连续**形态。
    ///
    /// ⚠️ **不能只断言「notes 里出现过 `D-299-1`」**：那三条 notes 里它各出现 4–5 次
    /// （另有指向 `D-299-2` 的），会被任意一处偶然提及满足。⇒ 断言指针本身的连续串。
    private static let pointer = "`docs/contract-defects.md` 的 `D-299-1`"

    /// `D-299-2` 侧的指针（`OrbitingLogos` 那批落点）。
    private static let pointerD2 = "`docs/contract-defects.md` 的 `D-299-2`"

    /// registry 里必须留 `D-299-1` 指针的三条。
    private static let registryComponents = ["ActivityHeatmap", "RadarChart", "RingChart"]

    /// `D-299-2` 侧的落点：文档三处 + registry 一条。
    private static let landingSitesD2 = [
        "docs/components/orbiting-logos.md",
        "docs/component-contract-revisions.md",
    ]

    /// ⚠️ 直接用 `GuardScanRoots.repoRoot`，不复制一份 —— 那个文件自陈是「根列表的
    /// 单一来源」，在一个主题是「唯一真源」的判据里复制它，形态上说不过去。
    private static var repoRoot: URL { GuardScanRoots.repoRoot }

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

    /// ⚠️ 本条是整套判据的**承重条**：它把「样板又被抄进副本」变成 fail-closed。
    @Test("样板与逐字证据只出现在真源里")
    func boilerplateStaysInSourceOfTruth() throws {
        // ⚠️ 扫描面不能只有 `docs/`：`D-299-1` 自陈这批说明曾被「逐字抄进四份 `notes`
        // 与**四份类型文档**」，类型文档在 `Sources/` 下。今天那里干净，但抄回去要判红。
        // ⚠️ `GuardScanRoots` 自己写着「**任何跨根扫描前都要先调它**……缺一个都留下一条
        // 『扫描器在空输入上必绿』的缝」。`FileManager.enumerator(at:)` 对不存在的根返回
        // `nil`、`while let` 一次都不进 ⇒ 失效方向**向绿**。实测：把 `Sources/` 那几条根
        // 去掉后判据照绿（I-6 的四个必查路径全在 `docs/` 下，兜不住这条腿）。
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
                // ⚠️ 排除本文件自身：它的注释里带着全部样板短语，不排除会自判红。
                guard !relative.hasSuffix("SingleSourceOfTruthGuard.swift") else { continue }
                guard let body = try? String(contentsOf: url, encoding: .utf8) else { continue }
                scannedPaths.insert(relative)
                for phrase in Self.sourceOnly where body.contains(phrase) {
                    offenders.append("\(relative) 出现了只应在真源里的「\(phrase)」")
                }
            }
        }
        // ⚠️ **结构性下限，不是魔数**：这四份是本判据的落点，扫不到它们就说明枚举收窄了
        // ——一个把范围缩到 `docs/components/` 的改动仍能过魔数下限，但过不了这一条。
        let required = Self.landingSites + [
            "docs/component-registry.json",
            "Sources/CoreDesign/Colors/InteractionColors.swift",
            "Sources/CoreDesignCharts/RingChart.swift",
            "Sources/CoreDesignEffects/Confetti.swift",
            "Tests/CoreDesignTests/GuardScanRoots.swift",
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
            // ⚠️ md 里指针可能跨行，比对前先把换行折成空格。
            let flattened = body
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
            #expect(flattened.contains(Self.pointer), "\(site) 缺少指针「\(Self.pointer)」")
        }
    }

    /// ⚠️ 与上一条同构、**必须单列**：上一版只覆盖了 `D-299-1` 侧的三份 chart 文档，
    /// `OrbitingLogos` 那批新落点的指针删掉判据不红（实测）。
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
}
