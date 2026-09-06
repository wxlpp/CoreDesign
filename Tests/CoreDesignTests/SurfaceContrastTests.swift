import SwiftUI
import Testing
@testable import CoreDesign

// MARK: - 叠加元素与父背景的可辨性守卫（Issue #122）

#if os(iOS)
@Suite("叠加元素与父背景不同色")
struct SurfaceContrastTests {
    private nonisolated static func env(_ scheme: ColorScheme) -> EnvironmentValues {
        var e = EnvironmentValues()
        e.colorScheme = scheme
        return e
    }

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
        var dark = EnvironmentValues()
        dark.colorScheme = .dark
        let canvas = Color.surfaceCanvas.resolve(in: dark)

        let fills: [(String, Color)] = [
            ("statusAccentSubtle", .statusAccentSubtle),
            ("statusSuccessSubtle", .statusSuccessSubtle),
            ("statusAttentionSubtle", .statusAttentionSubtle),
            ("statusDangerSubtle", .statusDangerSubtle),
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

    @Test("iOS 浅色：SurfaceKind 的 token 解析出 4 个 distinct 值（canvas==sidebar，floating==content）")
    func surfaceKindTokensAreFourDistinctInLight() {
        let e = Self.env(.light)
        let resolved = Set(Self.kindTokens.map { $0.token.resolve(in: e) })
        let detail = Self.kindTokens.map { "\($0.kind)=\($0.token.resolve(in: e))" }.joined(separator: " / ")
        #expect(
            resolved.count == 4,
            "iOS 浅色 distinct 应为 4，实际 \(resolved.count)：\(detail)"
        )
    }

    @Test("已知相等项钉死：content 族恒等、浅色 canvas 与 sidebar 同值")
    func knownEqualitiesArePinned() {
        for scheme in [ColorScheme.light, .dark] {
            let e = Self.env(scheme)
            #expect(
                Color.surfaceCard.resolve(in: e) == Color.surfaceCanvasSubtle.resolve(in: e),
                "\(scheme)：content/card/grouped 与 canvasSubtle 应同值（文档化别名族）"
            )
        }
        let light = Self.env(.light)
        #expect(
            Color.surfaceCanvas.resolve(in: light) == Color.surfaceSidebar.resolve(in: light),
            "浅色：canvas 与 sidebar 应同值——这是 iOS 浅色背景族的物理下限，不是缺陷"
        )
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
            for (name, v) in [("control", control), ("overlay/panel", panel)] {
                #expect(v.opacity < 1.0, "\(scheme)：\(name) 不再半透明——叠加档位应走 FillColors")
            }
            if scheme == .dark {
                #expect(floating.opacity < 1.0, "深色：floating 应走半透明填充")
            } else {
                #expect(floating.opacity == 1.0, "浅色：floating 应走不透明抬起色（分道的浅色分支）")
            }

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
