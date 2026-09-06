import Foundation
import Testing

@Suite("判定说明的唯一真源（#316）")
struct SingleSourceOfTruthGuard {
    private static let sourceOfTruth = "docs/contract-defects.md"

    private static let anchors = ["D-299-1", "D-299-2"]

    private static let sourceOnly = [
        "第 2 轮终审 F-2",
        "第 2 轮终审 F-4",
        "基数统一为 2",
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

    private static let landingSitesD2 = [
        "docs/components/orbiting-logos.md",
        "docs/component-contract-revisions.md",
    ]

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
                guard !relative.hasSuffix("SingleSourceOfTruthGuard.swift") else { continue }
                guard let body = try? String(contentsOf: url, encoding: .utf8) else { continue }
                scannedPaths.insert(relative)
                for phrase in Self.sourceOnly where body.contains(phrase) {
                    offenders.append("\(relative) 出现了只应在真源里的「\(phrase)」")
                }
            }
        }
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
}
