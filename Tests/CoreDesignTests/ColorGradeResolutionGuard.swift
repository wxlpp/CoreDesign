import Foundation
import SwiftUI
import Testing
@testable import CoreDesign

// MARK: - asset catalog 取色的「解析得出来吗」守卫 / Asset-catalog color resolvability (Issue #275)
//
// ## 术语先约定：这里说的是「走 asset catalog 查找的 198 个常量」
//
// ⚠️ **有意不用「第 1 层」这个词**：`CLAUDE.md`《分层色彩系统》里的 layer 1 = 仅
// `ColorGrade` 的 170 个色阶（`StatusColors` 被列在 layer 3，`CoreElevation` 的阴影
// 根本不在色彩分层里），与本文件要圈的集合**外延不同**。本文件圈的是**构建产物意义上**
// 的一个集合——所有以 `Color("…", bundle: .module)` 形式、必须命中 asset catalog 才能取到
// 值的常量，磁盘上一一对应 `Sources/CoreDesign/Resources/Resources.xcassets/**/*.colorset`：
//
// | 来源 | 个数 | 磁盘目录 |
// |---|---|---|
// | `Colors/ColorGrade.swift` 色阶 | 170 | 17 色相 × `<hue>-0` … `<hue>-9`，**每档一个独立 colorset 目录** |
// | `Colors/StatusColors.swift` status token | 24 | `status/` |
// | `Tokens/CoreElevation.swift` shadow token | 4 | `shadow/` |
// | 合计 | **198** | 实测 `find … -name '*.colorset' \| wc -l` = 198 |
//
// 其余各层走系统语义色 API（`UIColor`/`NSColor` 桥接、`Color.accentColor`、`Color.mix`），
// 不碰 catalog。而 asset catalog 在本仓有**两种产物形态**，由构建路径决定，
// 两者对 `Color.resolve(in:)` 的后果完全相反：
//
// | 构建路径 | bundle 里的形态 | 这 198 个常量的 `resolve(in:)` |
// |---|---|---|
// | `swift build` / `swift test`（SwiftPM native，macOS CLI） | `Resources.xcassets/` **目录原样拷贝** | **全部 `(0,0,0,0)`** |
// | `xcodebuild`（iOS Simulator 腿） | `Assets.car` | 真实取值 |
// | `swift test --build-system swiftbuild` | `Assets.car` | 真实取值 |
//
// 机理（实测，不是推理）：SwiftPM 的 native 构建计划**不调用 `actool`**，
// `.process("Resources")` 对 `.xcassets` 就是一次目录拷贝；而
// `NSColor(named:bundle:)`（`Color(_:bundle:)` 在 AppKit 下最终落到的东西）
// **只认编译后的 catalog**，读不到目录形态 ⇒ 每一次查找都 miss、返回 clear。
// ⚠️ 这个机理**不是本 issue 首次查明**：`ColorAssetGuardTests` 的
// `rawXcassetsAvailable` 文档注释（「xcodebuild 会调 `actool` 把整个 xcassets 编译成单个
// `Assets.car`」）与 `CoreDesignEffectsTests/CrossPlatformTests.swift` 的
// `branchWarmUp` 注释（`#274` 实测「`swift test` 进程里资源色解析成完全透明」）
// 早已各记了一半。本文件做的是把两半合并、量化到 token 级、并装上机器判据。
//
// ## 为什么必须是一条判据
//
// 失效形态是**静默的、且方向向绿**：位图 / `resolve` 判据里一旦出现这批 token，
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
// - 两条分叉判据各带 `.enabled(if:)`，而跳过在退出码上与通过无异 ⇒ 需要**无条件**判据兜底。
//   本文件有三条：`catalogFormIsDetectable`（兜双 skip）、
//   `sampleBasisHasExpectedCardinality`（兜抽样面被清空 / 缩水）与
//   `sampleLabelsMatchTheirColors`（兜 label 与取值不同源）。
//
// ### ⚠️ 更正：`catalogFormIsDetectable` 与既有 canary 的真实关系
//
// 本文件初版称它与 `ResourceBundleCanaryTests.assetCatalogIsPresentInSomeForm`
// 「一个只问形态、一个问解析结果，两条互不替代」——**那是假的**，照录更正：
// 两条问的是**同一件事**，谓词代数上恒等
// （`hasCar ∨ (¬hasCar ∧ hasXcassets)` ≡ `hasCar ∨ hasXcassets`），
// 本文件这条**也**不问解析结果。终审实测：改私有探测让本条判红时，
// `assetCatalogIsPresentInSomeForm` 照绿 ⇒ 当时是同 target 内同一事实的两份独立实现。
//
// 处置（判断与理由）：**断言保留，实现也保留两份——两者都是有意的**。
// - 断言保留：兜双 skip 的网必须与被它守的两条 `.enabled(if:)` **同文件**。既有 canary 的
//   存在理由是 `#119` 的 colorset 目录守卫，与本文件无关；它将来按自己的理由被改或被删时，
//   没有任何东西会提示改动者本文件在指望它。跨文件的隐式兜底就是下一次静默失守。
// - ⚠️ **实现一度被去重（改 internal 给 canary 直接消费），第 2 轮终审实测推翻、已回退**
//   ——照录撤回痕迹，别再去重。变异 **X3c**：`swift build --build-tests` 后从产物 bundle 里
//   `rm -rf Resources.xcassets`，并把 `assetCatalogIsRawDirectoryOnly` 放宽一行
//   （`|| resourceBundleHas("Info.plist")`），再 `swift test --skip-build`。
//   · 去重**后**：`catalogFormIsDetectable`、canary 的
//     `assetCatalogIsPresentInSomeForm`、以及整个 `ColorAssetGuardTests`
//     **三处同时静默**（后者被跳过），`8 tests … passed`、`EXIT=0`
//     （当时三个 suite 合计 8 条；本文件加上 `sampleLabelsMatchTheirColors` 后是 9 条）。
//   · 去重**前 / 回退后**：canary 查自己的 `fileExists`，同一变异下它**判红**、`EXIT=1`。
//   ⇒ 去重把两条断言的失效从「独立」变成「完全相关」，第二条的边际检出力降为 **0**
//   ——那正是本文件通篇在防的空转判据。**这份重复是有意的：两条断言的价值就在实现独立。**
//   ⚠️ 顺带更正一句上一版的措辞：`ColorAssetGuardTests.swift` canary 文档注释里
//   「两者会因各自的理由被独立修改」，在去重期间只对**断言**成立、对**被断言的谓词**不成立；
//   回退后两侧都成立。谁再想去重，先把 X3c 重跑一遍。
//
// ## 抽样面：44 个（共 198 个中），以及它**没**覆盖到的
//
// - 色阶 **17 / 170**：17 色相各取 grade 5 一档。
//   ⚠️ **更正**：初版给的理由是「10 个色阶同源同 colorset 目录」——**事实错误**。
//   磁盘上是 `brand/brand-0.colorset` … `brand-9.colorset`，**10 个独立目录**，各有自己的
//   `Contents.json`。逐档全查会真的多查 153 次，不是「把同一次 miss 重复一遍」。
//   仍只抽一档，理由改为：本判据要抓的回归是**形态级**的（catalog 编没编、bundle 烂没烂），
//   它对同一 hue 的 10 档一荣俱荣；逐档的**存在性**另有专管的判据（见下）。
// - status **24 / 24**、shadow **3 / 4**。
//   ⚠️ **`shadow-none` 有意不在抽样里**：它的 colorset 两种外观下 α 都是 `0.000`
//   （占位档，`radius = 0` 时 SwiftUI 不绘制），是**设计上的全透明**，
//   放进正向判据会让它在 iOS 腿上恒红。
// - ⚠️ **覆盖缺口，如实登记**：未抽样的 153 个色阶如果 colorset 目录被改名 / 删除，
//   **编译腿（`xcodebuild` / `swiftbuild`）上不会判红**——那条腿只跑本文件抽样的 44 个。
//   抓它的是 `ColorAssetGuardTests.hueRampColorsetsPresent`（逐目录 `fileExists`），
//   而那个 suite 恰恰**只在 macOS native 腿上启用**（编译腿的产物里没有 `Resources.xcassets/`
//   目录可查）。⇒ 两条腿各兜一半，CI 整体兜得住目录改名；单看任一条腿都有缺口。
//   实测（把 `brand/brand-3.colorset` 改名，只跑本文件 + `ColorAssetGuardTests` +
//   `ResourceBundleCanaryTests` 三个 suite）：`swift test --build-system swiftbuild`
//   ⇒ `8 tests … passed`、`EXIT=0`；`swift test`（native）⇒ 同样 8 条里
//   `ColorAssetGuardTests.hueRampColorsetsPresent` 判红、`EXIT=1`。

/// 资源 bundle 里是否存在给定名字的条目。
///
/// ⚠️ **`private` 是有意的**：`ColorAssetGuardTests.swift` 的 canary 另有一份自己的
/// `fileExists`，那份重复不是浪费——理由与 X3c 实测见文件头《更正》一节。
private nonisolated func resourceBundleHas(_ name: String) -> Bool {
    guard let root = Bundle.module.resourceURL else { return false }
    return FileManager.default.fileExists(atPath: root.appendingPathComponent(name).path)
}

/// `actool` 跑过：bundle 里是编译产物 `Assets.car`。
///
/// ⚠️ **`private` 是有意的，别为了「只留一份实现」再改成 internal**：
/// `ColorAssetGuardTests.swift` 的 `ResourceBundleCanaryTests` 自己查 `fileExists`，
/// **这份重复是有意的——两条断言的价值就在实现独立**（去重后两条会同真同假，
/// 第二条的边际检出力归零；X3c 实测见文件头《更正》一节）。
private nonisolated var assetCatalogIsCompiled: Bool {
    resourceBundleHas("Assets.car")
}

/// `actool` 没跑：bundle 里只有原样拷贝的 `Resources.xcassets/` 目录。
///
/// ⚠️ 与 `ColorAssetGuardTests.swift` 里的 `rawXcassetsAvailable` **语义不同**，
/// 别混：后者只问「目录在不在」（`hasXcassets`），本条还要求**没有** `Assets.car`
/// （`¬hasCar ∧ hasXcassets`）。两者在 macOS native 腿上同为 true，在编译腿上
/// 一 false 一 false——但如果哪天两种形态同时出现，两者就会分道扬镳。
///
/// ⚠️ **`private` 是有意的，别为了「只留一份实现」再改成 internal**：
/// `ColorAssetGuardTests.swift` 的 `ResourceBundleCanaryTests` 自己查 `fileExists`，
/// **这份重复是有意的——两条断言的价值就在实现独立**。把本条放宽一行就能同时静默
/// `catalogFormIsDetectable`、那条 canary 与整个 `ColorAssetGuardTests` 三处
/// （X3c 实测，见文件头《更正》一节）。
private nonisolated var assetCatalogIsRawDirectoryOnly: Bool {
    !assetCatalogIsCompiled && resourceBundleHas("Resources.xcassets")
}

@Suite("asset catalog 取色的解析可用性")
struct ColorGradeResolutionGuard {

    private nonisolated static func env(_ scheme: ColorScheme) -> EnvironmentValues {
        var e = EnvironmentValues()
        e.colorScheme = scheme
        return e
    }

    // MARK: - 抽样面
    //
    // 三组分开声明，`sampleBasisHasExpectedCardinality` 逐组各钉一个数——
    // 只钉总数的话，一组缩水可以被另一组增长掩盖。

    /// 17 色相各取 grade 5 一档。
    ///
    /// ⚠️ 有意**不加** `nonisolated`：与下面 `shadowSamples` 同源的隔离约束，见那里。
    private static var hueSamples: [(String, Color)] {
        [
            ("brand5", .brand5), ("amber5", .amber5), ("blue5", .blue5),
            ("cyan5", .cyan5), ("green5", .green5), ("grey5", .grey5),
            ("indigo5", .indigo5), ("lightBlue5", .lightBlue5),
            ("lightGreen5", .lightGreen5), ("lime5", .lime5),
            ("orange5", .orange5), ("pink5", .pink5), ("purple5", .purple5),
            ("red5", .red5), ("teal5", .teal5), ("violet5", .violet5),
            ("yellow5", .yellow5),
        ]
    }

    /// status：五个语义家族 × 各自档位（done 无 border 档），24 个全量。
    private static var statusSamples: [(String, Color)] {
        [
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
    }

    /// shadow：3 档非零（`shadow-none` 排除，理由见文件头）。
    ///
    /// 唯一的公开取用口是 `CoreElevation.spec(for:)`（colorset 引用本身是 private）。
    ///
    /// ⚠️ 有意**不加** `nonisolated`：`CoreElevation.spec(for:)` 在本包的
    /// `defaultIsolation` 下是 MainActor 隔离的，从 nonisolated 上下文取它是编译错误。
    /// 四条 `@Test` 本身也是 MainActor 隔离的，取用这里不需要跨隔离。
    private static var shadowSamples: [(String, Color)] {
        [CoreElevation.Level.small, .medium, .large].map { level in
            ("CoreElevation.spec(for: .\(level)).color", CoreElevation.spec(for: level).color)
        }
    }

    /// 抽样的 catalog 取色 token。名字随取值一起带上，失败信息才指得出是哪一个。
    private static var samples: [(String, Color)] {
        hueSamples + statusSamples + shadowSamples
    }

    /// **无条件**：抽样面不许被清空或缩水。
    ///
    /// ⚠️ 这条是本文件自己的「防空转判据」——本文件通篇在防别人写出空转判据，
    /// 而它自己一度没装这个下限：`samples` 返回 `[]` 时，下面两条分叉判据的
    /// `for` 循环一次都不进，**两条腿都给出 `EXIT=0` 全绿**（终审实测）。
    /// 三组各钉一个数，而不是只钉总数 44——只钉总数的话，一组被重构清空可以被
    /// 另一组增长掩盖。改动抽样面时**必须**同步这里，并说明为什么。
    @Test("抽样面必须覆盖三组、且基数与登记相符")
    func sampleBasisHasExpectedCardinality() {
        // 一、三组各钉一个数。
        #expect(
            Self.hueSamples.count == 17,
            "色相抽样应为 17（17 色相各一档），实为 \(Self.hueSamples.count)"
        )
        #expect(
            Self.statusSamples.count == 24,
            "status 抽样应为 24（全量），实为 \(Self.statusSamples.count)"
        )
        #expect(
            Self.shadowSamples.count == 3,
            "shadow 抽样应为 3（4 档去掉设计上全透明的 shadow-none），实为 \(Self.shadowSamples.count)"
        )
        // 二、合计钉一个数，且**按名字去重后**再数——防「拿重复项凑数」。
        let names = Set(Self.samples.map(\.0))
        #expect(
            names.count == 44,
            "抽样合计（按名字去重）应为 44（共 198 个 catalog 取色常量中），实为 \(names.count)"
        )
        // 三、三组必须**真的**进了 `samples`。只钉组基数不够：`samples` 的组装表达式
        //     被改掉时，三组各自的 `count` 照样对得上，缺口仍然是静默的。
        for (group, entries) in [
            ("色相", Self.hueSamples), ("status", Self.statusSamples), ("shadow", Self.shadowSamples),
        ] {
            let missing = entries.map(\.0).filter { !names.contains($0) }
            #expect(
                missing.isEmpty,
                "\(group) 组有 \(missing.count) 个没进 samples：\(missing.joined(separator: ", "))"
            )
        }
    }

    // MARK: - label ↔ 取值 的同源核对

    /// `camelCase` → `kebab-case`，数字前也断一刀。
    ///
    /// `brand5` → `brand-5`、`lightBlue5` → `light-blue-5`——正是磁盘上 colorset 的命名。
    private static func kebabCased(_ label: String) -> String {
        var out = ""
        for ch in label {
            if ch.isUppercase {
                out += "-" + ch.lowercased()
            } else if ch.isNumber {
                out += "-" + String(ch)
            } else {
                out.append(ch)
            }
        }
        return out
    }

    /// `statusSamples` 的 label → asset 名。
    ///
    /// 与色相组的差别只有一处：`StatusColors` 的 `…Foreground` 在磁盘上叫 `…-fg`
    /// （见 `Colors/StatusColors.swift` 与 `ColorAssetGuardTests.statusColorsetsPresent`）。
    private static func statusAssetName(_ label: String) -> String {
        let kebab = Self.kebabCased(label)
        guard kebab.hasSuffix("-foreground") else { return kebab }
        return kebab.replacingOccurrences(of: "-foreground", with: "-fg")
    }

    /// `shadowSamples` 的 label（`CoreElevation.spec(for: .medium).color`）→ asset 名
    /// （`shadow-medium`）。抠的是 label 里那个档位名。
    private static func shadowAssetName(_ label: String) -> String? {
        guard let head = label.range(of: "for: ."),
              let tail = label[head.upperBound...].firstIndex(of: ")")
        else { return nil }
        return "shadow-" + label[head.upperBound..<tail]
    }

    /// 三组各按自己的转换推出「label 该指向哪个 asset」，拼成一张对表。
    private static var labelToAssetName: [(label: String, expected: String, color: Color)] {
        Self.hueSamples.map { ($0.0, Self.kebabCased($0.0), $0.1) }
            + Self.statusSamples.map { ($0.0, Self.statusAssetName($0.0), $0.1) }
            + Self.shadowSamples.map {
                ($0.0, Self.shadowAssetName($0.0) ?? "<label 里抠不出档位名>", $0.1)
            }
    }

    /// **无条件**：抽样的 label 必须与它的取值**同源**。
    ///
    /// ⚠️ 这条补的是 `sampleBasisHasExpectedCardinality` 够不着的一格：那条只核名字集合的
    /// **基数与归属**，不核「label 说的是不是这个 color」。终审变异 **M7** 实测——把
    /// `("brand5", .brand5)` 改成 `("brand5", .amber5)`——**两条腿全绿 `EXIT=0`**。
    /// 后果不是正确性问题（两个都是真 token，正/反向断言照样成立），而是**失败信息指错
    /// token**：读者按报错去查 `brand-5`，坏的却是别的 asset。
    ///
    /// 做法：用 `TestSupport.swift` 里既有的共享内省辅助把 `Color` 内部的 asset 名抠出来
    /// （形如 `NamedColor(name: "brand-5", bundle: …)`；⚠️ 那是 **SwiftUI 内部描述格式**，
    /// 不是公开契约，该文件已把这条脆弱点登记在案），与 label 按三组各自的转换推出的名字
    /// 对表。⚠️ **这里有意复用那份辅助、不另写一份**——它是**辅助**不是断言，没有
    /// 「两条判据实现独立」的价值可言（与本文件头《更正》一节讲的 canary 情形正相反）。
    /// ⚠️ 内省抠不出名字时本条**判红**（`Issue.record`）而不是跳过：判据一旦失去依据，
    /// 必须有人回来重读，不能静默退化成空转。
    @Test("抽样的 label 必须与取值同源")
    func sampleLabelsMatchTheirColors() {
        let table = Self.labelToAssetName
        // 非退化前置：对表面必须就是那 44 个抽样，不能被清空。
        #expect(table.count == 44, "对表面应覆盖全部 44 个抽样，实为 \(table.count)")
        for entry in table {
            guard let actual = assetName(of: entry.color) else {
                Issue.record(
                    """
                    \(entry.label)：`String(describing:)` 里抠不出 asset 名——\
                    `NamedColor(name: "…")` 这个 description 形状被 SDK 换掉了。\
                    本条判据已失去内省依据，**先回来重读 `assetName(of:)` 的注释**再动它，\
                    别让它静默退化成空转。实际 description = \(String(describing: entry.color))
                    """
                )
                continue
            }
            #expect(
                actual == entry.expected,
                """
                \(entry.label) 的取值实际指向 asset `\(actual)`，而 label 推出的是 \
                `\(entry.expected)`——名字与取值不同源，这条抽样的失败信息会指错 token。
                """
            )
        }
    }

    /// **无条件**：两种 catalog 形态必须至少能探到一种。
    ///
    /// 下面两条判据各自带 `.enabled(if:)`，而 Swift Testing 的跳过在退出码上等同于通过
    /// ——bundle 整个坏掉（`resourceURL` 为 nil / 资源没被打进去 / 目录被改名）时，
    /// 两条会双双跳过、整跑照绿。这条不带条件的判据是那种情形唯一的红点。
    ///
    /// ⚠️ 它与 `ResourceBundleCanaryTests.assetCatalogIsPresentInSomeForm` 的谓词
    /// **代数上恒等**（不是互补）。为什么仍然各留一条、以及实现层面怎么去的重，
    /// 见文件头《更正：`catalogFormIsDetectable` 与既有 canary 的真实关系》。
    @Test("bundle 必须呈现 Assets.car 或原样 xcassets 之一")
    func catalogFormIsDetectable() {
        #expect(
            assetCatalogIsCompiled || assetCatalogIsRawDirectoryOnly,
            """
            资源 bundle 里既没有 Assets.car 也没有 Resources.xcassets/——\
            那 198 个走 catalog 查找的 token 会静默 fallback，\
            而本文件的两条分叉判据会双双跳过。\
            resourceURL = \(Bundle.module.resourceURL?.path ?? "nil")
            """
        )
    }

    /// 正向判据：`actool` 跑过的路径（iOS Simulator 腿 / `--build-system swiftbuild`）上，
    /// 抽样 token 必须解析出非零 α。
    @Test(
        "编译后的 asset catalog 上，抽样的 catalog 取色必须解析为非全透明",
        .enabled(
            if: assetCatalogIsCompiled,
            """
            跳过：本次构建的 bundle 里没有 Assets.car（`actool` 没跑）。\
            SwiftPM native 构建（`swift build` / `swift test`）就是这种情形——\
            catalog 取色**必然**解析为 (0,0,0,0)，正向断言在这条腿上无意义。\
            要覆盖这一条，跑 iOS Simulator 腿（xcodebuild -scheme CoreDesign-Package）\
            或 `swift test --build-system swiftbuild`。此时改由同文件的\
            `catalogColorsAreFullyTransparentOnRawXcassets` 钉住反向事实。
            """
        )
    )
    func catalogColorsResolveOpaqueOnCompiledCatalog() {
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
        "原样拷贝的 xcassets 上，抽样的 catalog 取色恒为全透明（钉住 macOS 腿的盲区）",
        .enabled(
            if: assetCatalogIsRawDirectoryOnly,
            """
            跳过：本次构建的 bundle 里有 Assets.car，`actool` 跑过 \
            ⇒ catalog 取色能正常解析，反向钉子不适用。此时由同文件的 \
            `catalogColorsResolveOpaqueOnCompiledCatalog` 正向覆盖。
            """
        )
    )
    func catalogColorsAreFullyTransparentOnRawXcassets() {
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
