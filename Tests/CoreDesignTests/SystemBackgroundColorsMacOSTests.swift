#if canImport(AppKit)
import AppKit
import SwiftUI
import Testing
@testable import CoreDesign

// MARK: - macOS 分组背景降级守卫（Issue #120）
//
// AppKit 没有 grouped background 系列。Issue #120 之前，`systemGroupedBackground`
// 与 `secondarySystemGroupedBackground` 的 macOS 分支**双双**落到
// `.controlBackgroundColor`——照搬 iOS 映射会让 `surfaceCanvas`（画布）与
// `surfaceRaised`（卡片）同色、raised 层完全隐形。那不是"macOS 观感不打磨"，
// 是功能性退化。现改为 window / control 两分支。
//
// **验证手法的取舍**：本想解析成具体 RGBA 再比明度，但在无 WindowServer 会话的
// 沙箱里两者会塌缩成同一 fallback RGBA——那是解析环境的产物，不是真实的设计塌缩。
// 故改为断言**本库 token 本身**互不相等：SwiftUI `Color` 对 `Color(nsColor:)` 的
// 相等性基于其承载的 NSColor，一旦有人把某个分支改回 `.controlBackgroundColor`，
// 两个 token 就会判等，本测试立刻变红。
//
// > 早先版本这里比较的是 `NSColor.windowBackgroundColor != NSColor.controlBackgroundColor`
// > ——那是 AppKit 自身常量的性质，与 CoreDesign 无关，无论本库怎么改都恒真。
// > 被测对象必须是本库代码。

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
        // canvas 与其余两档必须分开——这是 Issue #120 修的那一层。
        #expect(Color.systemGroupedBackground != Color.secondarySystemGroupedBackground)
        #expect(Color.systemGroupedBackground != Color.tertiarySystemGroupedBackground)

        // secondary 与 tertiary 在 macOS 上仍然同色：AppKit 没有第三级 grouped 背景，
        // 两者都落 `.controlBackgroundColor`。
        //
        // 塌缩只发生在 **tertiary 一侧**：`secondarySystemGroupedBackground` 的取值本就正确，
        // 且它**有真实组件消费者**（经 `surfaceCanvasSubtle` / `surfaceRaised` 到达
        // `ListRow.swift` hover 背景、`Badge.swift` neutral 背景、
        // `SegmentedControl.swift` thumb）——**改动 secondary 不是零风险操作**。
        //
        // ⚠️ **Issue #220 推翻了这段论证当初的前提**：彼时 tertiary（`surfaceElevated` /
        // `surfaceGroupedElevated`）在组件层没有任何引用，故当初"猜错色不如诚实塌缩、
        // 反正受益方也没人用"这条权衡成立。#220 把 `surfaceSidebar` 改指
        // `surfaceElevated` 后，它经 `.surface(.sidebar)` 与 App 宿主三处直接消费点
        // 获得了**真实消费者**，那条权衡的前提不复存在。
        //
        // 结论仍是不硬塞近似色（`underPageBackgroundColor` 语义是"页面之下"、比画布更暗，
        // 而非"更抬升"），但理由变了：不再是"反正没人用"，而是**没有语义正确的 AppKit
        // 对应物**。代价随之变实：macOS 下侧栏与内容表面同色，已在下方钉成显式断言。
        //
        // 用 `withKnownIssue` 而不是删掉断言：一旦将来有人给 tertiary 找到合适的
        // AppKit 对应物，这里会因"预期失败却通过了"而提醒更新，不会静默失效。
        withKnownIssue("AppKit 无第三级 grouped 背景，secondary 与 tertiary 同落 controlBackgroundColor") {
            #expect(Color.secondarySystemGroupedBackground != Color.tertiarySystemGroupedBackground)
        }
    }

    // MARK: - SurfaceKind 取值分化的 macOS 侧（Issue #220）

    /// ⚠️ **本组断言在 token 身份层，不解析 RGBA**——沿用本文件顶部记载的取舍：
    /// 无 WindowServer 会话时解析值会塌成同一 fallback，那是解析环境的产物、
    /// 不是真实的设计塌缩。`Color` 对 `Color(nsColor:)` 的相等性基于其承载的 NSColor，
    /// 不需要 WindowServer。
    ///
    /// iOS 侧的 `Color.Resolved` 逐位断言在 `SurfaceContrastTests`（`#if os(iOS)`）。

    @Test("macOS：五路碰撞——content 族与 sidebar 同落 controlBackgroundColor")
    func macOSFiveWayCollapseIsPinned() {
        // AppKit 无 grouped 三级族，`surfaceCard`（→ secondary）与 `surfaceSidebar`
        // （→ tertiary，Issue #220 起）双双落 `.controlBackgroundColor`。
        // 这是系统色族的物理下限，非本库缺陷——钉成显式相等，避免留作隐性回归。
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
    }

    @Test("macOS：三个填充档位两两不同，且与两个背景档位不同")
    func macOSFillTokensAreDistinct() {
        // ⚠️ 本 suite 此前**完全不覆盖 fill**（Issue #220 之前 `grep -c fill` 为 0）。
        // #220 首次把填充族引入 `SurfaceKind` 的背景通路（`.floating` / `.overlay`
        // / `.panel`），故这块覆盖是新增的，不是扩写既有断言。
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

