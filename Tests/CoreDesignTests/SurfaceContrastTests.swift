import SwiftUI
import Testing
@testable import CoreDesign

// MARK: - 叠加元素与父背景的可辨性守卫（Issue #122）
//
// #120 把语义色改指系统色后出现过一个静默缺陷：Badge 的 neutral 背景取
// `surfaceCanvasSubtle`（= `secondarySystemGroupedBackground`），而它在**浅色模式**下
// 与 `surfaceBase`（= `systemBackground`）同为 `#FFFFFF`——无描边的 neutral badge
// 放在普通页面背景上完全不可见。编译器、grep、既有测试全都发现不了。
//
// 根因是选错了 token **种类**：叠在别人之上的一小块色该用**填充色**（`FillColors`，
// 半透明、专为叠加设计），而不是**背景色**（`SurfaceColors`，专为充当底层而设计）。
//
// > ⚠️ 这类断言**必须跑在 iOS Simulator 上**。macOS 无 WindowServer 会话时，
// > 三个 surface token 会塌缩成同一 fallback 值，断言会给出误导性的"全部同色"结论。
// > 故整个 suite 限定 `#if os(iOS)`——它只在 CI 的 xcodebuild iOS 腿执行。
//
// **断言强度的边界（有意为之）**：这里断言的是「两个 `Color.Resolved` 逐位不同」，
// 不是「肉眼可辨」。Badge 那个 bug 正是逐位相同（双方都是 `#FFFFFF`），所以这个判据
// 对该类回归是足够的；但它抓不到「差一点点、肉眼仍不可辨」的情形。
//
// 之所以不上感知色差阈值：那需要选一个色彩空间感知均匀的度量（裸 sRGB 通道差不是）。
//
// ⚠️ **Issue #220 推翻了这段原本的理由**。此前这里写的是：库内不存在可用来标定阈值的
// 相近色案例，现有 token 两两之间都差着几十个色阶。#220 把
// `.floating` / `.overlay` / `.panel` 改指填充族后，**三档填充的 RGB 几乎相同、
// 只靠 α 区分**（实测 tertiaryFill 浅 `#7676801F` / 深 `#7676803D`），这就是**首批
// alpha-only 的近撞案例**——它们在本 suite 的逐位判据下会**平凡通过**，而肉眼是否
// 分得开，本 suite 答不了。
//
// 现在不上阈值的理由变成：观感判断已有专门归口——**视觉复核（Issue #225）的截图评审**，
// 那里才回答"浮起来了没有"。本 suite 的担保范围**仅止于逐位不同**，请勿据它下
// 「可辨」结论。

#if os(iOS)
@Suite("叠加元素与父背景不同色")
struct SurfaceContrastTests {

    private nonisolated static func env(_ scheme: ColorScheme) -> EnvironmentValues {
        var e = EnvironmentValues()
        e.colorScheme = scheme
        return e
    }

    /// 一个元素若要能叠在任意父容器上，它必须与所有常见父背景都可辨。
    private static let parents: [(String, Color)] = [
        ("surfaceBase", .surfaceBase),
        ("surfaceCanvas", .surfaceCanvas),
        ("surfaceRaised", .surfaceRaised),
    ]

    @Test("Badge neutral 背景与任意父容器、任意外观下都不同色")
    func badgeNeutralIsNotSameColorAsAnyParent() {
        for scheme in [ColorScheme.light, .dark] {
            let e = Self.env(scheme)
            let badge = Color.secondaryFill.resolve(in: e)
            for (name, parent) in Self.parents {
                #expect(
                    badge != parent.resolve(in: e),
                    "\(scheme)：Badge neutral 背景与 \(name) 同色——无描边时将完全不可见"
                )
            }
        }
    }

    @Test("status subtle 填充在深色纯黑画布上仍可辨，且四档两两不同")
    func statusSubtleFillsAreDistinguishableInDark() {
        // Task #125 视觉终审发现的缺陷：四个 status subtle 色的**深色 α 全是 0.067**。
        // 6.7% 的色叠在纯黑画布（深色下 `surfaceCanvas` = `systemGroupedBackground`
        // = 纯黑）上几乎不可见，四个语义档位在深色模式下无法区分——而 `Badge` 的
        // **文字颜色不随 variant 变化**，于是「用颜色编码语义」这件事在深色下完全失效。
        //
        // 这是个纯视觉缺陷：编译绿、测试绿、grep 干净，只有把 app 跑起来看深色截图
        // 才发现得了。对照组是 Badge 的 neutral 档用的 `secondaryFill`（深色 α=0.32），
        // 早已验证在三种父容器两种外观下均可辨——修复后取 0.28，同一量级。
        var dark = EnvironmentValues()
        dark.colorScheme = .dark
        let canvas = Color.surfaceCanvas.resolve(in: dark)

        let fills: [(String, Color)] = [
            ("statusAccentSubtle", .statusAccentSubtle),
            ("statusSuccessSubtle", .statusSuccessSubtle),
            ("statusAttentionSubtle", .statusAttentionSubtle),
            ("statusDangerSubtle", .statusDangerSubtle),
            // `statusDoneSubtle` 当前无生产消费者（见 `StatusColors.swift` 的说明），
            // 但它与上面四个是同一批被修的 colorset（α 0.067 → 0.280）。一并纳入守卫，
            // 免得将来它被接进 Badge 之类的组件时，alpha 已经悄悄漂回去而无人发现。
            ("statusDoneSubtle", .statusDoneSubtle),
        ]

        for (name, fill) in fills {
            let f = fill.resolve(in: dark)
            #expect(
                f.opacity > 0.15,
                "\(name) 深色 α 只有 \(f.opacity)——叠在纯黑画布上会几乎不可见"
            )
            #expect(f != canvas, "\(name) 与深色画布同色")
        }

        // 四档必须两两可分，否则「用颜色编码语义」失去意义。
        for i in fills.indices {
            for j in fills.indices where j > i {
                #expect(
                    fills[i].1.resolve(in: dark) != fills[j].1.resolve(in: dark),
                    "\(fills[i].0) 与 \(fills[j].0) 在深色下同色——语义档位不可区分"
                )
            }
        }
    }

    @Test("surfaceCard 与 surfaceCanvas 两种外观下都不同色（Issue #140）")
    func surfaceCardDiffersFromCanvasInBothAppearances() {
        // 断言 surfaceCard 本身（非 surfaceRaised != surfaceCanvas，那个不改代码就恒真）。
        // 两种外观都验：浅色下 #F2F2F7 vs #FFFFFF、深色下由塌缩的纯黑变为可辨——
        // 都是本次修复的产物，浅色侧的回归同样要防。
        for scheme in [ColorScheme.light, .dark] {
            let e = Self.env(scheme)
            #expect(
                Color.surfaceCard.resolve(in: e) != Color.surfaceCanvas.resolve(in: e),
                "\(scheme)：surfaceCard 与 surfaceCanvas 同色——卡片在画布上不可辨"
            )
        }
    }

    @Test("填充色族整体可叠加——半透明且与各父背景不同色")
    func fillTokensLayerOverAnySurface() {
        for scheme in [ColorScheme.light, .dark] {
            let e = Self.env(scheme)
            for (name, fill) in [("secondaryFill", Color.secondaryFill),
                                 ("tertiaryFill", Color.tertiaryFill),
                                 ("quaternaryFill", Color.quaternaryFill)] {
                let f = fill.resolve(in: e)
                #expect(f.opacity < 1.0, "\(scheme)：\(name) 不再半透明——填充色的可叠加性依赖这一点")
                for (pname, parent) in Self.parents {
                    #expect(f != parent.resolve(in: e), "\(scheme)：\(name) 与 \(pname) 同色")
                }
            }
        }
    }

    // MARK: - SurfaceKind 取值分化（Issue #220）

    /// `SurfaceKind` 各档位背后的 token。**守卫打在 token 层**——
    /// `SurfaceKind.background` 的 switch 在 `private extension`（`SurfaceModifier.swift`），
    /// `@testable` 也够不到，故本组断言**不护 kind→token 映射**，只护 token 别名指向。
    /// 映射本身由视觉复核（#225）覆盖。
    private static let kindTokens: [(kind: String, token: Color)] = [
        ("canvas", .surfaceCanvas),
        ("content/card/grouped", .surfaceCard),
        ("canvasSubtle", .surfaceCanvasSubtle),
        ("sidebar", .surfaceSidebar),
        ("control", .surfaceInteractive),
        ("floating", .surfaceOverlay),
        ("overlay/panel", .surfacePanel),
    ]

    @Test("iOS 深色：SurfaceKind 的 token 解析出 6 个 distinct 值")
    func surfaceKindTokensAreSixDistinctInDark() {
        let e = Self.env(.dark)
        let resolved = Set(Self.kindTokens.map { $0.token.resolve(in: e) })
        let detail = Self.kindTokens.map { "\($0.kind)=\($0.token.resolve(in: e))" }.joined(separator: " / ")
        #expect(
            resolved.count == 6,
            "iOS 深色 distinct 应为 6，实际 \(resolved.count)：\(detail)"
        )
    }

    @Test("iOS 浅色：SurfaceKind 的 token 解析出 5 个 distinct 值（canvas 与 sidebar 同值）")
    func surfaceKindTokensAreFiveDistinctInLight() {
        let e = Self.env(.light)
        let resolved = Set(Self.kindTokens.map { $0.token.resolve(in: e) })
        let detail = Self.kindTokens.map { "\($0.kind)=\($0.token.resolve(in: e))" }.joined(separator: " / ")
        // ⚠️ **浅色 4 而非 5，这是结构性上限、不是回归**（Issue #225 视觉终审后改）：
        // `.floating` 按外观分道后浅色取 `systemBackground`（`#FFFFFF`）——浅色下
        // **不存在比 `.content`（已是纯白）更亮的不透明色**，故二者必然同值。
        // iOS 浅色靠**阴影**表达抬起，而 `SurfaceKind` 只返回 Color、表达不了阴影。
        #expect(
            resolved.count == 4,
            "iOS 浅色 distinct 应为 4，实际 \(resolved.count)：\(detail)"
        )
    }

    @Test("已知相等项钉死：content 族恒等、浅色 canvas 与 sidebar 同值")
    func knownEqualitiesArePinned() {
        // 这些不是缺陷，是有意的设计——钉成显式断言，避免将来被「顺手改掉」而无人察觉，
        // 也避免有人误读 distinct 数为「每个 kind 各有一色」。
        for scheme in [ColorScheme.light, .dark] {
            let e = Self.env(scheme)
            #expect(
                Color.surfaceCard.resolve(in: e) == Color.surfaceCanvasSubtle.resolve(in: e),
                "\(scheme)：content/card/grouped 与 canvasSubtle 应同值（文档化别名族）"
            )
        }
        // ⚠️ **`.overlay` 与 `.panel` 的恒等本组守卫护不了，这里刻意不写断言。**
        // 二者走同一个 token（`SurfaceModifier.swift` 的 switch），border 与
        // cornerRadius 也完全相同——恒等是**结构性**的，不是取值巧合。
        // 而 switch 在 `private extension`、`@testable` 够不到，token 层能写出的
        // 只有 `surfacePanel == surfacePanel` 这种**恒真断言**：它永不失败，
        // 写了等于把「结构上无需守」包装成「已有断言守着」。
        // kind→token 映射的正确性归视觉复核（Issue #225）。
        // 浅色下 systemGroupedBackground 与 tertiarySystemGroupedBackground 同为 #F2F2F7。
        let light = Self.env(.light)
        #expect(
            Color.surfaceCanvas.resolve(in: light) == Color.surfaceSidebar.resolve(in: light),
            "浅色：canvas 与 sidebar 应同值——这是 iOS 浅色背景族的物理下限，不是缺陷"
        )
        // 深色下三者必须分开。
        let dark = Self.env(.dark)
        #expect(
            Color.surfaceCanvas.resolve(in: dark) != Color.surfaceSidebar.resolve(in: dark),
            "深色：canvas 与 sidebar 应可分"
        )
        #expect(
            Color.surfaceCard.resolve(in: dark) != Color.surfaceSidebar.resolve(in: dark),
            "深色：content 与 sidebar 应可分"
        )
    }

    @Test("三个叠加档位（control / floating / overlay+panel）走填充族且两两不同")
    func overlayKindsUseDistinctFills() {
        for scheme in [ColorScheme.light, .dark] {
            let e = Self.env(scheme)
            let control = Color.surfaceInteractive.resolve(in: e)
            let floating = Color.surfaceOverlay.resolve(in: e)
            let panel = Color.surfacePanel.resolve(in: e)
            // ⚠️ **`.floating` 按外观分道**（#225）：浅色是**不透明**的抬起色、
            // 深色才是半透明填充。故半透明断言只对 control 与 overlay/panel 恒成立，
            // floating 只在深色下成立。
            for (name, v) in [("control", control), ("overlay/panel", panel)] {
                #expect(v.opacity < 1.0, "\(scheme)：\(name) 不再半透明——叠加档位应走 FillColors")
            }
            if scheme == .dark {
                #expect(floating.opacity < 1.0, "深色：floating 应走半透明填充")
            } else {
                #expect(floating.opacity == 1.0, "浅色：floating 应走不透明抬起色（分道的浅色分支）")
            }

            // α 的**实测值**（iPhone 17 Pro / iOS 26.4 模拟器，Issue #220 实测钉死；
            // 不是从文档抄来的预期值）：
            //   secondaryFill (floating)      浅 #78788029 α≈0.161 / 深 #78788052 α≈0.322
            //   tertiaryFill  (control)       浅 #7676801F α≈0.122 / 深 #7676803D α≈0.239
            //   quaternaryFill(overlay/panel) 浅 #74748014 α≈0.078 / 深 #7676802E α≈0.180
            //
            // 三档的 RGB 几乎相同（#787880 / #767680 / #747480），**区分几乎全靠 α**。
            // 这正是本 suite 逐位判据的软肋：下面的 != 断言会平凡通过，但"叠上去看不看得出
            // 层级"本 suite 答不了——那由视觉复核（Issue #225）回答。
            //
            // 断言 α 的**序**而非具体值：序才是设计意图（z 序越高、存在感越强），
            // 具体值随系统版本可动。
            // α 序只在**同为填充族**时有意义；floating 浅色已不是填充族，故只比
            // control 与 overlay/panel，并在深色下额外比 floating。
            #expect(
                control.opacity > panel.opacity,
                "\(scheme)：control(tertiaryFill) 的 α 应高于 overlay/panel(quaternaryFill)"
            )
            if scheme == .dark {
                #expect(
                    floating.opacity > control.opacity,
                    "深色：floating(secondaryFill) 的 α 应高于 control(tertiaryFill)——z 序最高的浮件需要最强存在感"
                )
            }
            #expect(control != floating, "\(scheme)：control 与 floating 同值")
            #expect(control != panel, "\(scheme)：control 与 overlay/panel 同值")
            #expect(floating != panel, "\(scheme)：floating 与 overlay/panel 同值")
            // ⚠️ 钉死浅色下的结构性同值：`.floating` 与 `.content` 在浅色下**必然同值**
            // （纯白是天花板）。钉成显式断言而非留作隐性回归——它同时是一条文档：
            // 浅色下 `.floating` 叠在 `.content` 上必须补阴影或改用 floatingGlass。
            if scheme == .light {
                #expect(
                    floating == Color.surfaceCard.resolve(in: e),
                    "浅色：floating 应与 content 同为纯白（结构性上限；若不再同值说明取值变了，须重审语义）"
                )
            }
        }
    }
}
#endif

