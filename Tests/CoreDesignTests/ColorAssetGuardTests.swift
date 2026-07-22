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

private nonisolated func xcassetsURL() -> URL? {
    Bundle.module.resourceURL?.appendingPathComponent("Resources.xcassets")
}

private nonisolated func colorsetExists(_ group: String, _ name: String) -> Bool {
    guard let base = xcassetsURL() else { return false }
    let path = base.appendingPathComponent("\(group)/\(name).colorset").path
    return FileManager.default.fileExists(atPath: path)
}

/// 本守卫是否适用于当前构建方式。
///
/// 目录形式的 `.xcassets` 只在 **SwiftPM**（`swift build` / `swift test`）下成立——
/// 它不调 `actool`，资源按原样拷进 bundle。**xcodebuild 会调 `actool` 把整个
/// xcassets 编译成单个 `Assets.car`**，原始 `.colorset` 目录在产物里根本不存在，
/// 此时逐目录断言会全数失败（201 个 issue），而那是构建方式差异、不是资源缺失。
///
/// 老的 `BlossomAssetTests` 当年是靠 CI 里一行 `-skip-testing` 规避的；那行随
/// Issue #118 删除该测试时一并消失。改由测试自身判断适用性——CI 配置是会漂移的
/// 外部状态，而这里能把原因和判据放在一起。
private nonisolated var rawXcassetsAvailable: Bool {
    guard let base = xcassetsURL() else { return false }
    return FileManager.default.fileExists(atPath: base.path)
}

/// **无条件 canary**——不带 `.enabled(if:)`，任何构建方式下都必须跑。
///
/// 下面那个守卫 suite 用 `rawXcassetsAvailable` 判断适用性，但**这个判据和它要守卫的
/// 对象是同一件事**：如果 `Resources.xcassets` 整个丢失（未被拷进 bundle、被改名、
/// `resourceURL` 为 nil），判据返回 false，suite 被**跳过**而不是变红——而那恰恰是
/// 该守卫最该抓住的一类回归，此时 SwiftPM 与 xcodebuild 两条腿会同时静默失守。
///
/// 本 canary 断言两种形态**至少存在其一**：目录形式的 `Resources.xcassets/`（SwiftPM，
/// 不调 actool）或编译产物 `Assets.car`（xcodebuild 调 actool）。两者皆无 = bundle 坏了，
/// 必须响。它同时覆盖「SwiftPM 将来改为调用 actool」这种工具链漂移。
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
            "bundle 里既无 Resources.xcassets/ 目录也无 Assets.car——所有颜色都会静默 fallback"
        )
    }
}

@Suite("Colorset 资源存在性守卫", .enabled(if: rawXcassetsAvailable))
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
