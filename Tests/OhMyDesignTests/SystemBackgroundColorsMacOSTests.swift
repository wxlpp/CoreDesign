#if canImport(AppKit)
import AppKit
import SwiftUI
import Testing
@testable import OhMyDesign

// MARK: - macOS 分组背景降级守卫（Issue #120）

@Suite("macOS 分组背景降级")
struct SystemBackgroundColorsMacOSTests {
    @Test("canvas 与 raised 的底层 token 不同色")
    func groupedBackgroundsDiffer() {
        #expect(
            Color.systemGroupedBackground != Color.secondarySystemGroupedBackground,
            "macOS 上 canvas 与 raised 指向了同一个 Color（判的是身份；⚠️ 这两个 token 的**取值**在 macOS 上本来就相同，见 #239）"
        )
    }

    @Test("语义层 surfaceCanvas 与 surfaceRaised 不同色")
    func semanticSurfacesDiffer() {
        #expect(
            Color.surfaceCanvas != Color.surfaceRaised,
            "surfaceCanvas 与 surfaceRaised 指向了同一个 Color（判的是身份；⚠️ 取值本来就相同，见 #239）"
        )
    }

    @Test("三档分组背景：canvas 独立，secondary 与 tertiary 已知塌缩")
    func groupedFamilyDistinctness() {
        #expect(Color.systemGroupedBackground != Color.secondarySystemGroupedBackground)
        #expect(Color.systemGroupedBackground != Color.tertiarySystemGroupedBackground)

        withKnownIssue("AppKit 无第三级 grouped 背景，secondary 与 tertiary 同落 controlBackgroundColor") {
            #expect(Color.secondarySystemGroupedBackground != Color.tertiarySystemGroupedBackground)
        }
    }

    // MARK: - SurfaceKind 取值分化的 macOS 侧（Issue #220）

    @Test("macOS：五路碰撞——content 族与 sidebar 同落 controlBackgroundColor")
    func macOSFiveWayCollapseIsPinned() {
        let group: [(String, Color)] = [
            ("surfaceCard", .surfaceCard),
            ("surfaceCanvasSubtle", .surfaceCanvasSubtle),
            ("surfaceSidebar", .surfaceSidebar),
        ]
        for (name, c) in group.dropFirst() {
            #expect(c == group[0].1, "macOS：\(name) 应与 surfaceCard 同值（五路碰撞的一员）")
        }
    }

    @Test("macOS：canvas 与上述五路的 Color **身份**不同——⚠️ 取值相同，见 #239")
    func macOSCanvasStandsApart() {
        let why = "（判的是 Color 身份，用来抓「有人把分支改回同一个 NSColor」；⚠️ 取值本来就相同，见 #239）"
        #expect(Color.surfaceCanvas != Color.surfaceCard, "macOS：画布与内容表面指向了同一个 Color\(why)")
        #expect(Color.surfaceCanvas != Color.surfaceSidebar, "macOS：画布与侧栏指向了同一个 Color\(why)")
        #expect(Color.surfaceCanvas != Color.surfaceCanvasSubtle, "macOS：画布与 canvasSubtle 指向了同一个 Color\(why)")
    }

    // MARK: - #239：`.floating` 与 `.canvas` 在 macOS 上不同值

    @Test("#239：五路碰撞涉及的四个 token 各自明暗互异——本文件取值层判据的前提")
    func resolutionIsAppearanceSensitive() {
        var light = EnvironmentValues(); light.colorScheme = .light
        var dark = EnvironmentValues(); dark.colorScheme = .dark
        for (name, color) in [("surfaceCanvas", Color.surfaceCanvas),
                              ("surfaceCard", Color.surfaceCard),
                              ("surfaceCanvasSubtle", Color.surfaceCanvasSubtle),
                              ("surfaceSidebar", Color.surfaceSidebar)] {
            #expect(color.resolve(in: light) != color.resolve(in: dark), """
            macOS 上 \(name) 明暗两档解析值相同 —— 它丢了动态外观（多半被换成了静态色），
            下面那条五路判据的明暗两档循环会退化成同一档跑两遍（不是失去意义，是少掉一档覆盖）。
            ⚠️ **四个 token 必须逐个断言，不能只断言 surfaceCanvas**：只钉一个时，把另外三个
            换成静态色会让五路判据判红、而本条照绿 —— 读者按那条的消息会以为「取值真的分开了，
            那是好事」，实际是回归。
            ⚠️ 本条**无条件判红，不得改成跳过**：`#120` 描述的退化形态是「塌成**同一**
            fallback RGBA」——同值但**不透明**，任何靠 `opacity > 0` 的探针都判不出来，
            探针一 false 判据就双双跳过、退出码仍是 0。
            （`#120` 的那段文件头注已随 `#328` 删除，原文见 `git show 4cd5fc1^:` 本文件。）
            """)
        }
    }

    @Test("#239：macOS 上 .floating 与 .canvas **取值**不同，不是只有身份不同")
    func macOSFloatingDiffersFromCanvasByValue() {
        for scheme in [ColorScheme.light, ColorScheme.dark] {
            var e = EnvironmentValues()
            e.colorScheme = scheme
            let canvas = Color.surfaceCanvas.resolve(in: e)
            let floating = Color.surfaceOverlay.resolve(in: e)
            #expect(floating != canvas, """
            \(scheme)：macOS 上 `.floating` 与 `.canvas` **取值相同** —— 这正是
            PRD v1 那个「`.floating == .canvas` on macOS」塌缩，`#225` / `#226` 期间连撞两次。
            ⚠️ 身份比较（`Color != Color`）抓不到这一层：`#239` 实测
            `Color.surfaceCanvas != Color.surfaceCard` 为 `true`，而两者解析值逐位相同。
            canvas=\(canvas) floating=\(floating)
            """)
        }
    }

    @Test("#239：五路碰撞在**取值**层同样成立——身份判据抓不到，如实钉住")
    func macOSFiveWayCollapseIsRealAtValueLevel() {
        for scheme in [ColorScheme.light, ColorScheme.dark] {
            var e = EnvironmentValues()
            e.colorScheme = scheme
            let canvas = Color.surfaceCanvas.resolve(in: e)
            for (name, color) in [("surfaceCard", Color.surfaceCard),
                                  ("surfaceCanvasSubtle", Color.surfaceCanvasSubtle),
                                  ("surfaceSidebar", Color.surfaceSidebar)] {
                #expect(color.resolve(in: e) == canvas, """
                \(scheme)：\(name) 与 surfaceCanvas 的取值**不再相同**了。
                ⚠️ 若下面两个 hex 看起来一模一样，那是**颜色空间**不同（`Color.Resolved` 的 `==`
                比 hex 严）——按上面那条交叉判据走，别以为是判据坏了。
                \(name)=\(color.resolve(in: e)) canvas=\(canvas)

                ⚠️ 这条是**如实钉住现状**，不是在庆祝它：`#239` 实测这四个 token 在 macOS 上
                解析值逐位相同（浅色 `#FFFFFFFF` / 深色 `#1E1E1EFF`），因为
                `windowBackgroundColor` 与 `controlBackgroundColor` 在本版 macOS 上同值。
                ⚠️ 同文件上面那条 `macOSCanvasStandsApart` 判的是 `Color` **身份**，
                **按 `#120` 的设计如此**（用来抓「有人把分支改回 `controlBackgroundColor`」）
                ——**断言没错，错的是它原来的消息措辞**（写成了「塌缩」这种取值层说法）。
                ⚠️ **本条判红时分三种情形，正确动作不同，别弄反**：
                ① `resolutionIsAppearanceSensitive` 也红 ⇒ 这些 token 丢了动态外观
                （多半被换成静态色）——**回归，去修代码**。
                ② 它全绿、但 `SystemBackgroundColors.swift` 的 `#else` 分支已不是
                `windowBackgroundColor` / `controlBackgroundColor` ⇒ 被换成了**别的动态色**
                （换成 `labelColor` 这类错色时本条同样只有这里红）——**也是回归，去修代码**。
                ③ 它全绿、`#else` 分支未动 ⇒ 取值真的分开了（**好事**），
                同步 `macOSCanvasStandsApart` 的消息与 `docs/DESIGN-FOUNDATION.md`。
                """)
            }
        }
    }

    @Test("macOS：token 的**底层 NSColor** 两两不同——身份比较抓不到的那层")
    func macOSUnderlyingNSColorsAreDistinct() {
        let named: [(String, Color)] = [
            ("surfaceCanvas", .surfaceCanvas),
            ("surfaceCard", .surfaceCard),
            ("surfaceSidebar", .surfaceSidebar),
            ("surfaceInteractive(control)", .surfaceInteractive),
            ("surfaceOverlay(floating)", .surfaceOverlay),
            ("surfacePanel(panel)", .surfacePanel),
        ]
        let knownSameAsCard: Set<String> = ["surfaceCard", "surfaceSidebar"]

        let floating = NSColor(named.first { $0.0.hasPrefix("surfaceOverlay") }!.1)
        let card = NSColor(named.first { $0.0 == "surfaceCard" }!.1)
        #expect(
            floating != card,
            """
            macOS：surfaceOverlay 与 surfaceCard 的**底层 NSColor 相同**——浮层与内容表面
            像素级同色。⚠️ 身份比较对此假绿（构造路径不同即判不等），故本条按底层比。
            AppKit 只有 windowBackgroundColor / controlBackgroundColor 两个不透明背景取值，
            已被 canvas 与 content 族占满；浮层档位必须走填充族，不能挑不透明色。
            """
        )
        let canvas = NSColor(named.first { $0.0 == "surfaceCanvas" }!.1)
        #expect(floating != canvas, "macOS：surfaceOverlay 与 surfaceCanvas 底层同色")
        _ = knownSameAsCard
    }

    @Test("#342：三个叠加档位的 **token** 都真的画得出来——0 < α < 1，不是全透明")
    func macOSOverlayTiersAreActuallyPaintable() {
        for scheme in [ColorScheme.light, ColorScheme.dark] {
            var e = EnvironmentValues()
            e.colorScheme = scheme
            for (name, color) in [("control", Color.surfaceInteractive),
                                  ("floating", Color.surfaceOverlay),
                                  ("panel", Color.surfacePanel)] {
                let a = color.resolve(in: e).opacity
                #expect(a > 0, """
                \(scheme)：叠加档 \(name) 解析出 α = \(a) —— **它画不出来**。
                ⚠️ 本条存在的理由：本文件其余**涉及叠加档的**判据问的全是「**不同**吗」，
                而 `.clear` 与什么都不同 ⇒ 把这个 token 换成 `.clear`，
                `macOSFloatingDiffersFromCanvasByValue` / `macOSUnderlyingNSColorsAreDistinct`
                / `macOSFillTokensAreDistinct` **十条全绿**（`#342` 实测）。
                没有一条问过「它**在**吗」。
                ⚠️ **背景档（`.canvas` / `.content`）有意不进本判据**：它们本来就不透明，
                对它们断言 `α > 0` 恒真、是噪声。「它们必须不透明」由
                `SurfaceKindAlphaContractGuard` 守（`#345`）。
                ⚠️ **本条射程只到 token**：`SurfaceKind` → token 的映射层
                （`SurfaceModifier` 的 `background`）被改坏时本条照绿，
                那一层同样由 `SurfaceKindAlphaContractGuard` 守。
                """)
                #expect(a < 1, """
                \(scheme)：叠加档 \(name) 变成不透明（α = \(a)）——叠加档位应走填充族。
                依据是 `macOSUnderlyingNSColorsAreDistinct` 的消息：AppKit 只有
                `windowBackgroundColor` / `controlBackgroundColor` 两个不透明背景取值，
                已被 canvas 与 content 族占满，浮层档位挑不到第三个。
                ⚠️ **若这一档是「有意」改成不透明**：先确认它没跟那两个 `NSColor` 像素撞色
                （撞了的话 `macOSUnderlyingNSColorsAreDistinct` 会同时红），
                再照 iOS 浅色 `floating` 的先例**分道**写成 `== 1`，而不是放宽本条。
                """)
            }
        }
    }

    @Test("macOS：三个填充档位两两不同，且与两个背景档位不同")
    func macOSFillTokensAreDistinct() {
        let fills: [(String, Color)] = [
            ("surfaceInteractive(control)", .surfaceInteractive),
            ("surfaceOverlay(floating)", .surfaceOverlay),
            ("surfacePanel(panel)", .surfacePanel),
        ]
        for i in fills.indices {
            for j in fills.indices where j > i {
                #expect(fills[i].1 != fills[j].1, "macOS：\(fills[i].0) 与 \(fills[j].0) 同值")
            }
        }
        let backgrounds: [(String, Color)] = [
            ("surfaceCanvas", .surfaceCanvas),
            ("surfaceCard", .surfaceCard),
        ]
        for (fname, f) in fills {
            for (bname, b) in backgrounds {
                #expect(f != b, "macOS：填充档 \(fname) 与背景档 \(bname) 同值")
            }
        }
    }
}
#endif
