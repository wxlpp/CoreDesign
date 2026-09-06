#if canImport(AppKit)
import AppKit
import SwiftUI
import Testing
@testable import CoreDesign

// MARK: - macOS 分组背景降级守卫（Issue #120）

@Suite("macOS 分组背景降级")
struct SystemBackgroundColorsMacOSTests {
    @Test("canvas 与 raised 的底层 token 不同色")
    func groupedBackgroundsDiffer() {
        #expect(
            Color.systemGroupedBackground != Color.secondarySystemGroupedBackground,
            "macOS 上 canvas 与 raised 塌缩成同色——raised 层将完全隐形"
        )
    }

    @Test("语义层 surfaceCanvas 与 surfaceRaised 不同色")
    func semanticSurfacesDiffer() {
        #expect(
            Color.surfaceCanvas != Color.surfaceRaised,
            "surfaceCanvas 与 surfaceRaised 同色——卡片在画布上不可辨"
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

    @Test("macOS：canvas 与上述五路不同色")
    func macOSCanvasStandsApart() {
        #expect(Color.surfaceCanvas != Color.surfaceCard, "macOS：画布与内容表面塌缩")
        #expect(Color.surfaceCanvas != Color.surfaceSidebar, "macOS：画布与侧栏塌缩")
        #expect(Color.surfaceCanvas != Color.surfaceCanvasSubtle, "macOS：画布与 canvasSubtle 塌缩")
    }

    @Test("macOS：token 的**底层 NSColor** 两两不同——身份比较抓不到的那层")
    func macOSUnderlyingNSColorsAreDistinct() {
        let named: [(String, Color)] = [
            ("surfaceCanvas", .surfaceCanvas),
            ("surfaceCard", .surfaceCard),
            ("surfaceSidebar", .surfaceSidebar),
            ("surfaceInteractive(control)", .surfaceInteractive),
            ("surfaceOverlay(floating)", .surfaceOverlay),
            ("surfacePanel(overlay/panel)", .surfacePanel),
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

    @Test("macOS：三个填充档位两两不同，且与两个背景档位不同")
    func macOSFillTokensAreDistinct() {
        let fills: [(String, Color)] = [
            ("surfaceInteractive(control)", .surfaceInteractive),
            ("surfaceOverlay(floating)", .surfaceOverlay),
            ("surfacePanel(overlay/panel)", .surfacePanel),
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
