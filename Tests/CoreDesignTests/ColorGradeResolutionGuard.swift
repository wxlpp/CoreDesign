import Foundation
import SwiftUI
import Testing
@testable import CoreDesign

// MARK: - 第 1 层资源色的「解析得出来吗」守卫 / Layer-1 asset color resolvability (Issue #275)
//
// ## 它守什么
//
// 第 1 层（`Colors/ColorGrade.swift` 的 170 个色阶、`Colors/StatusColors.swift` 的 24 个
// status token、`Tokens/CoreElevation.swift` 的 4 个 shadow token，合计 **198 个
// `Color("…", bundle: .module)` 常量**）是**唯一**要走 asset catalog 查找的一层；
// 第 2/3 层走系统语义色 API，不碰 catalog。而 asset catalog 在本仓有**两种产物形态**，
// 由构建路径决定，两者对 `Color.resolve(in:)` 的后果完全相反：
//
// | 构建路径 | bundle 里的形态 | 第 1 层 `resolve(in:)` |
// |---|---|---|
// | `swift build` / `swift test`（SwiftPM native，macOS CLI） | `Resources.xcassets/` **目录原样拷贝** | **全部 `(0,0,0,0)`** |
// | `xcodebuild`（iOS Simulator 腿） | `Assets.car` | 真实取值 |
// | `swift test --build-system swiftbuild` | `Assets.car` | 真实取值 |
//
// 机理（实测，不是推理）：SwiftPM 的 native 构建计划**不调用 `actool`**，
// `.process("Resources")` 对 `.xcassets` 就是一次目录拷贝；而
// `NSColor(named:bundle:)`（`Color(_:bundle:)` 在 AppKit 下最终落到的东西）
// **只认编译后的 catalog**，读不到目录形态 ⇒ 每一次查找都 miss、返回 clear。
//
// ## 为什么必须是一条判据
//
// 失效形态是**静默的、且方向向绿**：位图 / `resolve` 判据里一旦出现第 1 层 token，
// 「两张图不同」会因为其中一张根本没画出来而通过，「α > 0.15」这类阈值判据则会
// 因为恒 0 而红得莫名其妙。前者尤其危险——它给出的是一条**永远为真**的判据，
// 而 `swift test` 全绿，没有任何东西提示作者他刚写下的是空转。
//
// ## 这条判据的形态：按 bundle 形态**分叉**，两侧都断言，不留「跳过即绿」
//
// - `Assets.car` 在 ⇒ 断言抽样 token **非全透明**（正向判据：防 bundle 在 iOS 腿悄悄烂掉）。
// - 只有目录形态 ⇒ 断言抽样 token **恒为全透明**（反向钉子：把本仓 macOS 腿的盲区
//   钉在这里。SwiftPM 哪天开始调 `actool`、或有人把这条腿切到 `swiftbuild`，
//   这条会立刻变红，逼人回来重读本节与 `CLAUDE.md`《验证边界与常见坑》）。
// - 两种形态都探不到 ⇒ `catalogFormIsDetectable` 判红。**这条不带 `.enabled(if:)`**，
//   否则 bundle 整个坏掉时上面两条会双双**跳过**，而跳过在退出码上与通过无异。
//   （`ResourceBundleCanaryTests.assetCatalogIsPresentInSomeForm` 守的是同一件事的
//   另一半——它只问「至少有一种形态」，不问解析结果。两条互不替代。）
//
// ## 抽样面
//
// 17 色相各取中间档（10 个色阶同源同 colorset 目录，逐档全查只是把 170 次 miss
// 重复一遍，不增加信号）+ 24 个 status token 全量 + 3 档非零 shadow。
// ⚠️ **`shadow-none` 有意不在抽样里**：它的 colorset 两种外观下 α 都是 `0.000`
//（占位档，`radius = 0` 时 SwiftUI 不绘制），是**设计上的全透明**，
// 放进正向判据会让它在 iOS 腿上恒红。

/// 资源 bundle 里是否存在给定名字的条目。
private nonisolated func resourceBundleHas(_ name: String) -> Bool {
    guard let root = Bundle.module.resourceURL else { return false }
    return FileManager.default.fileExists(atPath: root.appendingPathComponent(name).path)
}

/// `actool` 跑过：bundle 里是编译产物 `Assets.car`。
private nonisolated var compiledAssetCatalogAvailable: Bool {
    resourceBundleHas("Assets.car")
}

/// `actool` 没跑：bundle 里只有原样拷贝的 `Resources.xcassets/` 目录。
private nonisolated var rawXcassetsOnly: Bool {
    !compiledAssetCatalogAvailable && resourceBundleHas("Resources.xcassets")
}

@Suite("第 1 层资源色解析")
struct ColorGradeResolutionGuard {

    private nonisolated static func env(_ scheme: ColorScheme) -> EnvironmentValues {
        var e = EnvironmentValues()
        e.colorScheme = scheme
        return e
    }

    /// 抽样的第 1 层 token。名字随取值一起带上，失败信息才指得出是哪一个。
    ///
    /// ⚠️ 有意**不加** `nonisolated`：`CoreElevation.spec(for:)` 在本包的
    /// `defaultIsolation` 下是 MainActor 隔离的，从 nonisolated 上下文取它是编译错误。
    /// 三条 `@Test` 本身也是 MainActor 隔离的，取用这里不需要跨隔离。
    private static var samples: [(String, Color)] {
        var out: [(String, Color)] = [
            ("brand5", .brand5), ("amber5", .amber5), ("blue5", .blue5),
            ("cyan5", .cyan5), ("green5", .green5), ("grey5", .grey5),
            ("indigo5", .indigo5), ("lightBlue5", .lightBlue5),
            ("lightGreen5", .lightGreen5), ("lime5", .lime5),
            ("orange5", .orange5), ("pink5", .pink5), ("purple5", .purple5),
            ("red5", .red5), ("teal5", .teal5), ("violet5", .violet5),
            ("yellow5", .yellow5),
            // status：五个语义家族 × 各自档位（done 无 border 档）。
            ("statusAccentForeground", .statusAccentForeground),
            ("statusAccentEmphasis", .statusAccentEmphasis),
            ("statusAccentMuted", .statusAccentMuted),
            ("statusAccentSubtle", .statusAccentSubtle),
            ("statusAccentBorder", .statusAccentBorder),
            ("statusSuccessForeground", .statusSuccessForeground),
            ("statusSuccessEmphasis", .statusSuccessEmphasis),
            ("statusSuccessMuted", .statusSuccessMuted),
            ("statusSuccessSubtle", .statusSuccessSubtle),
            ("statusSuccessBorder", .statusSuccessBorder),
            ("statusAttentionForeground", .statusAttentionForeground),
            ("statusAttentionEmphasis", .statusAttentionEmphasis),
            ("statusAttentionMuted", .statusAttentionMuted),
            ("statusAttentionSubtle", .statusAttentionSubtle),
            ("statusAttentionBorder", .statusAttentionBorder),
            ("statusDangerForeground", .statusDangerForeground),
            ("statusDangerEmphasis", .statusDangerEmphasis),
            ("statusDangerMuted", .statusDangerMuted),
            ("statusDangerSubtle", .statusDangerSubtle),
            ("statusDangerBorder", .statusDangerBorder),
            ("statusDoneForeground", .statusDoneForeground),
            ("statusDoneEmphasis", .statusDoneEmphasis),
            ("statusDoneMuted", .statusDoneMuted),
            ("statusDoneSubtle", .statusDoneSubtle),
        ]
        // shadow：唯一的公开取用口是 `CoreElevation.spec(for:)`（colorset 引用本身是 private）。
        for level in [CoreElevation.Level.small, .medium, .large] {
            out.append(("CoreElevation.spec(for: .\(level)).color", CoreElevation.spec(for: level).color))
        }
        return out
    }

    /// **无条件**：两种 catalog 形态必须至少能探到一种。
    ///
    /// 下面两条判据各自带 `.enabled(if:)`，而 Swift Testing 的跳过在退出码上等同于通过
    /// ——bundle 整个坏掉（`resourceURL` 为 nil / 资源没被打进去 / 目录被改名）时，
    /// 两条会双双跳过、整跑照绿。这条不带条件的判据是那种情形唯一的红点。
    @Test("bundle 必须呈现 Assets.car 或原样 xcassets 之一")
    func catalogFormIsDetectable() {
        #expect(
            compiledAssetCatalogAvailable || rawXcassetsOnly,
            """
            资源 bundle 里既没有 Assets.car 也没有 Resources.xcassets/——\
            第 1 层的 198 个 token 会静默 fallback，而本文件另外两条判据会双双跳过。\
            resourceURL = \(Bundle.module.resourceURL?.path ?? "nil")
            """
        )
    }

    /// 正向判据：`actool` 跑过的路径（iOS Simulator 腿 / `--build-system swiftbuild`）上，
    /// 抽样 token 必须解析出非零 α。
    @Test(
        "编译后的 asset catalog 上，第 1 层资源色必须解析为非全透明",
        .enabled(
            if: compiledAssetCatalogAvailable,
            """
            跳过：本次构建的 bundle 里没有 Assets.car（`actool` 没跑）。\
            SwiftPM native 构建（`swift build` / `swift test`）就是这种情形——\
            第 1 层色**必然**解析为 (0,0,0,0)，正向断言在这条腿上无意义。\
            要覆盖这一条，跑 iOS Simulator 腿（xcodebuild -scheme CoreDesign-Package）\
            或 `swift test --build-system swiftbuild`。此时改由同文件的\
            `layerOneIsFullyTransparentOnRawXcassets` 钉住反向事实。
            """
        )
    )
    func layerOneResolvesOpaqueOnCompiledCatalog() {
        for scheme in [ColorScheme.light, .dark] {
            let e = Self.env(scheme)
            for (name, color) in Self.samples {
                let r = color.resolve(in: e)
                #expect(
                    r.opacity > 0,
                    "\(scheme)：\(name) 解析为 α=\(r.opacity)——编译后的 catalog 里查不到它，asset 名多半错了"
                )
            }
        }
    }

    /// 反向钉子：SwiftPM native 路径上，抽样 token **必然**全透明。
    ///
    /// 这条判据故意断言一件坏事成立。它不是在祝福现状，而是在给现状装报警器：
    /// 工具链哪天让 SwiftPM 也跑 `actool`、或有人把 macOS 腿切到 `swiftbuild`，
    /// 这条会红，读者被迫回到本文件顶部那张表和 `CLAUDE.md`《验证边界与常见坑》
    /// 重新判断「颜色断言在 macOS 腿抓不到」还成不成立。
    @Test(
        "原样拷贝的 xcassets 上，第 1 层资源色恒为全透明（钉住 macOS 腿的盲区）",
        .enabled(
            if: rawXcassetsOnly,
            """
            跳过：本次构建的 bundle 里有 Assets.car，`actool` 跑过 \
            ⇒ 第 1 层色能正常解析，反向钉子不适用。此时由同文件的 \
            `layerOneResolvesOpaqueOnCompiledCatalog` 正向覆盖。
            """
        )
    )
    func layerOneIsFullyTransparentOnRawXcassets() {
        for scheme in [ColorScheme.light, .dark] {
            let e = Self.env(scheme)
            for (name, color) in Self.samples {
                let r = color.resolve(in: e)
                #expect(
                    r.opacity == 0,
                    """
                    \(scheme)：\(name) 解析出了 α=\(r.opacity)——SwiftPM native 腿\
                    竟然能解析 asset 色了。这是好消息，但 `CLAUDE.md`《验证边界与常见坑》\
                    与本文件顶部那张表已经过期，先改文档再删这条判据。
                    """
                )
            }
        }
    }
}
