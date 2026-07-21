import Testing
import Foundation
@testable import CoreDesign

// MARK: - Colorset 存在性守卫（Issue #119 前置）
//
// On macOS, SPM ships .xcassets as a plain directory inside the bundle (not compiled
// to .car), so `Color(named:bundle:)`-style assertions can't catch a missing colorset
// directory — they resolve to a fallback color instead of failing loudly. Issue #118
// deleted the only test that caught this class of bug via `FileManager`
// (`BlossomAssetTests`, together with its `xcassetsURL()` / `colorsetExists(_:_:)`
// helpers) when it removed the Blossom trait. This file rebuilds that guard,
// generalized to the current (non-Blossom) asset surface, ahead of the Tokens/
// churn in this task (CLAUDE.md: 增量构建不会拷贝新加的 colorset 目录，资源缺失是
// 静默失败).

private func xcassetsURL() -> URL? {
    Bundle.module.resourceURL?.appendingPathComponent("Resources.xcassets")
}

private func colorsetExists(_ group: String, _ name: String) -> Bool {
    guard let base = xcassetsURL() else { return false }
    let path = base.appendingPathComponent("\(group)/\(name).colorset").path
    return FileManager.default.fileExists(atPath: path)
}

@Suite("Colorset 资源存在性守卫")
struct ColorAssetGuardTests {
    /// 17 种命名色相（`Colors/ColorGrade.swift`），每种 10 个色阶 `<hue>-0` … `<hue>-9`。
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

    @Test("canvas 三档 colorset 存在（SurfaceColors 消费）")
    func canvasColorsetsPresent() {
        for name in ["canvas-default", "canvas-subtle", "canvas-inset"] {
            #expect(colorsetExists("canvas", name), "missing \(name)")
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
        // `done` 语义没有 `border` 档（与 Colors/StatusColors.swift 的消费面一致）。
        for suffix in ["emphasis", "fg", "muted", "subtle"] {
            let name = "status-done-\(suffix)"
            #expect(colorsetExists("status", name), "missing \(name)")
        }
    }
}
