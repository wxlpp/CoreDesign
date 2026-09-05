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
// churn in this task.
//
// ⚠️ **更正传播（`#275`）**：本段原本引用 `CLAUDE.md` 的「增量构建不会拷贝新加的
// colorset 目录，资源缺失是静默失败」——那句已被 `#275` **实测推翻并从 `CLAUDE.md`
// 删除**（新增 colorset 目录后裸跑 `swift build`，日志就是 `[1/2] Copying
// Resources.xcassets`，新目录当场进 bundle；`swift package clean` 对此毫无作用）。
// 本文件仍然成立，但理由换成正确的那个：macOS SwiftPM 不调 `actool`，`.xcassets`
// 以**目录**形态进 bundle ⇒ `Color(named:bundle:)` 查找**必然 miss 并静默 fallback
// 成 clear**，所以「colorset 目录少了一个」这类回归只有 `FileManager` 逐目录查得到，
// 解析型断言在这条腿上抓不到（量化与判据见
// `ColorGradeResolutionGuard.catalogColorsAreFullyTransparentOnRawXcassets`）。

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
///
/// ⚠️ **别与 `ColorGradeResolutionGuard.swift` 的 `assetCatalogIsRawDirectoryOnly`
/// 混为一谈**（同 target、名字近似、语义不同）：本条只问「目录在不在」
/// （`hasXcassets`）；那条还要求**没有** `Assets.car`（`¬hasCar ∧ hasXcassets`）。
/// 本条要的是「逐目录断言有没有意义」，那条要的是「解析结果该断言哪一侧」。
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
///
/// ⚠️ **与 `ColorGradeResolutionGuard.catalogFormIsDetectable` 断言的是同一件事**
/// （`#275` 终审查明：两者谓词代数上恒等，不是互补）。两条都留着是有意的——那条要与它
/// 守的两个 `.enabled(if:)` 同文件，本条是 `#119` colorset 守卫自己的适用性兜底，
/// 两者会因各自的理由被独立修改。
///
/// ⚠️ **探测实现也有意各留一份，别去重**（`#275` 第 2 轮终审实测推翻了上一版的去重）：
/// 上一版把 `ColorGradeResolutionGuard.swift` 的两个探测从 private 改成 internal、
/// 本条直接消费它们。变异 **X3c**（`swift build --build-tests` 后从产物 bundle 里
/// `rm -rf Resources.xcassets`，再把那边的目录形态谓词放宽一行）实测：本条会跟着一起
/// **变绿**，`catalogFormIsDetectable` 与整个 `ColorAssetGuardTests` 同时静默，
/// `8 tests … passed`、`EXIT=0`（当时三个 suite 合计 8 条，现为 9 条）；
/// 回退成下面这份自己的 `fileExists` 后，同一变异下
/// 本条**判红**、`EXIT=1`。
/// ⇒ 去重会让两条断言同真同假，第二条的边际检出力降为 0。
/// **这份重复是有意的：两条断言的价值就在实现独立。**
@Suite("资源 bundle canary")
struct ResourceBundleCanaryTests {
    @Test("bundle 里必须能找到 xcassets——目录形式或编译后的 Assets.car")
    func assetCatalogIsPresentInSomeForm() {
        guard let resourceURL = Bundle.module.resourceURL else {
            Issue.record("Bundle.module.resourceURL 为 nil——资源根本没被打进 bundle")
            return
        }
        // ⚠️ 这里**有意**自己拼路径查 `fileExists`，不复用 `ColorGradeResolutionGuard.swift`
        //    的同名探测——理由见上方文档注释里的 X3c 实测。
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

    // canvas 三档 colorset（`canvas-default` / `canvas-subtle` / `canvas-inset`）的守卫
    // 已随 Issue #120 移除——`SurfaceColors` 改指系统色后不再引用它们，资产本身也删了。
    //
    // 这条曾是一个 git 察觉不到的跨分支语义冲突：#119 建守卫时断言它们存在，#120 并行
    // 删除了它们，两支各自 CI 全绿、合并后测试必红（实测确认：合并后
    // "missing canvas-default"）。处置原则是「删资产的分支负责更新守卫」，
    // 已在 `.claude/epics/coredesign-native-foundation/120.md` 列为合并门槛项。

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
