import Testing
import Foundation
@testable import OhMyDesign

// MARK: - Colorset 存在性守卫（Issue #119 前置）

private nonisolated func xcassetsURL() -> URL? {
    Bundle.module.resourceURL?.appendingPathComponent("Resources.xcassets")
}

private nonisolated func colorsetExists(_ group: String, _ name: String) -> Bool {
    guard let base = xcassetsURL() else { return false }
    let path = base.appendingPathComponent("\(group)/\(name).colorset").path
    return FileManager.default.fileExists(atPath: path)
}

private nonisolated var rawXcassetsAvailable: Bool {
    guard let base = xcassetsURL() else { return false }
    return FileManager.default.fileExists(atPath: base.path)
}

@Suite("资源 bundle canary")
struct ResourceBundleCanaryTests {
    @Test("bundle 里必须能找到 xcassets——目录形式或编译后的 Assets.car")
    func assetCatalogIsPresentInSomeForm() {
        guard let resourceURL = Bundle.module.resourceURL else {
            Issue.record("Bundle.module.resourceURL 为 nil——资源根本没被打进 bundle")
            return
        }
        let fm = FileManager.default
        let rawDir = resourceURL.appendingPathComponent("Resources.xcassets").path
        let compiled = resourceURL.appendingPathComponent("Assets.car").path
        #expect(
            fm.fileExists(atPath: rawDir) || fm.fileExists(atPath: compiled),
            "bundle 里既无 Resources.xcassets/ 目录也无 Assets.car——所有颜色都会静默 fallback。resourceURL = \(resourceURL.path)"
        )
    }
}

@Suite("Colorset 资源存在性守卫", .enabled(if: rawXcassetsAvailable))
struct ColorAssetGuardTests {
    private static let hues = [
        "amber", "blue", "brand", "cyan", "green", "grey", "indigo",
        "light-blue", "light-green", "lime", "orange", "pink", "purple",
        "red", "teal", "violet", "yellow",
    ]

    @Test("17 色相 × 10 色阶 colorset 全部存在")
    func hueRampColorsetsPresent() {
        for hue in Self.hues {
            for i in 0...9 {
                #expect(colorsetExists(hue, "\(hue)-\(i)"), "missing \(hue)-\(i)")
            }
        }
    }

    @Test("shadow 四档 colorset 存在（CoreElevation 消费）")
    func shadowColorsetsPresent() {
        for name in ["shadow-none", "shadow-small", "shadow-medium", "shadow-large"] {
            #expect(colorsetExists("shadow", name), "missing \(name)")
        }
    }

    @Test("status 语义色 colorset 全部存在（StatusColors 消费）")
    func statusColorsetsPresent() {
        let categories = ["accent", "attention", "danger", "success"]
        let suffixes = ["border", "emphasis", "fg", "muted", "subtle"]
        for category in categories {
            for suffix in suffixes {
                let name = "status-\(category)-\(suffix)"
                #expect(colorsetExists("status", name), "missing \(name)")
            }
        }
        for suffix in ["emphasis", "fg", "muted", "subtle"] {
            let name = "status-done-\(suffix)"
            #expect(colorsetExists("status", name), "missing \(name)")
        }
    }
}
