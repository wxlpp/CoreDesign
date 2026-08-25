import Testing
import SwiftUI
@testable import CoreDesign

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

// `SidebarUtilityRowPresentation`（#64，公约 §2 形态 D2）的**渲染护栏**。
//
// ⚠️ **本 suite 是跨平台的**，与仓内其余 5 个 `ImageRenderer` 量测 suite
// （`TouchTargetTests` / `DynamicTypeLayoutTests` / `SpinningModifierSizeTests` /
// `SettingsRowHeightTests` / `CardVisibilityTests`）**不同** —— 它们全部包在 `#if os(iOS)` 里。
// 独占一个文件正是为了不被后人顺手包进 `#if os(iOS)`、让护栏静默变单腿。
//
// ⚠️ **与 `SpinningModifierTests.swift:11-12` 那条相反先例对账**：那里写「只在 iOS 腿跑
// （macOS 无 WindowServer 会塌缩系统色/材质）」—— 那句讲的是**颜色 / 材质**，**不是布局 frame**。
// 本 suite 量的是布局尺寸，macOS 实测可行（`nsImage` 返回非 nil，量得 111.0 / 83.0 / 50.0）。
//
// ⚠️ **这条护栏守的是判定法层面的结论**：`docs/component-contract.md` 的候选 2 覆盖论证
// （见 `oh-my-story` 的 `64-spec.md` §3.3 / §5.1.4）以「`.textOnly` 的排布事实是
// `[title][Spacer][glyph]`」为前提。若 leading 位仍占着地方，实际是
// `[gap][title][Spacer][glyph]` ⇒ **排布事实不一致 ⇒ 覆盖论证当场失效**。
// ⇒ 本文件是那条论证的机器护栏，不是普通的样式测试。
@Suite("SidebarUtilityRow leading 槽渲染护栏（#64）")
@MainActor
struct SidebarLeadingSlotRenderTests {
    /// a11y 命中目标下限。⚠️ **字面量 44，不写 `CoreControlMetrics.height(for: .large)`** ——
    /// 被测代码（`Sidebar.swift` 的 `SidebarRow`）用的就是后者，写它就**同源** ⇒ 改 token 时
    /// 双向移动、**永不判红**（恒真守卫，本 epic 在 `90a09fb` 逐字登记过该病型）。
    /// 44 是**外部 a11y 契约数**、不由本仓 token 决定；先例 `TouchTargetTests.swift:61` 同款。
    private static let minimumHitTarget: CGFloat = 44

    /// 内容固有尺寸。⚠️ **永不接受宽度约束** —— 被测视图一旦被钉成固定宽度，两个变体的
    /// 宽度就都等于那个值、**差值恒 0**，护栏静默失效且不会红。
    /// （`TouchTargetTests.renderedHeight` 的默认参数是 `width: 320`，**不要复用它**。）
    private func intrinsicSize(_ view: some View) -> CGSize {
        let renderer = ImageRenderer(content: view)
        // scale 影响绝对值（实测 1 → 111.0 / 2 → 110.5 / 3 → 110.333），仓内四处先例全部显式设 1。
        renderer.scale = 1
        #if canImport(UIKit)
        return renderer.uiImage?.size ?? .zero
        #else
        return renderer.nsImage?.size ?? .zero
        #endif
    }

    private func row(
        _ presentation: SidebarUtilityRowPresentation,
        trailing: String? = nil
    ) -> some View {
        SidebarUtilityRow(
            systemImage: "gearshape",
            title: "Settings",
            trailingSystemImage: trailing,
            presentation: presentation
        ) {}
    }

    @Test("承重：.textOnly 不渲染 leading 槽、也不占位")
    func textOnlyDropsLeadingSlot() {
        let iconLeading = self.intrinsicSize(self.row(.iconLeading))
        let textOnly = self.intrinsicSize(self.row(.textOnly))

        // ⚠️ 非空断言先行（仓内明文纪律）：只断差值时，「两边同时偏移」不会被发现；
        // 且 `nsImage` / `uiImage` 为 nil 时必须**判红**，不得静默跳过。
        #expect(iconLeading.width > 0, "渲染失败（尺寸为零）—— 本平台无法量测，不得当作通过")
        #expect(textOnly.width > 0, "渲染失败（尺寸为零）")

        // ⚠️ 期望值用 **token 表达式**（与高度那条相反，见文件末尾的「同源」说明）：
        // 变异「乙′」改的是「组件用哪个 token」而这里写死 `.large` ⇒ 两边不同源 ⇒ 判红成立。
        let expected = CoreControlMetrics.iconSize(for: .large) + CoreSpacing.sm
        #expect(iconLeading.width - textOnly.width == expected,
                "leading 槽未被拆掉：实测差 \(iconLeading.width - textOnly.width)，期望 \(expected)")
    }

    @Test("三种呈现的命中高度均 ≥ 44pt")
    func allPresentationsMeetMinimumTouchTarget() {
        let cases: [(String, CGSize)] = [
            (".iconLeading", self.intrinsicSize(self.row(.iconLeading))),
            (".textOnly", self.intrinsicSize(self.row(.textOnly))),
            (".textOnly + trailing", self.intrinsicSize(self.row(.textOnly, trailing: "chevron.forward"))),
        ]
        for (name, size) in cases {
            #expect(size.height >= Self.minimumHitTarget,
                    "\(name) 实测高度 \(size.height)pt < \(Self.minimumHitTarget)pt")
        }
    }

    @Test("候选 2 的组合：行尾字形真的占了位，且不影响 leading 侧差值")
    func trailingGlyphOccupiesSpace() {
        let textOnly = self.intrinsicSize(self.row(.textOnly))
        let withTrailing = self.intrinsicSize(self.row(.textOnly, trailing: "chevron.forward"))
        // 候选 2 承载论证里唯一还没被任何断言碰过的事实。
        #expect(withTrailing.width > textOnly.width, "行尾字形没有占位 ⇒ 候选 2 的排布事实不成立")

        // 行尾字形不应影响 leading 侧的差值。
        let iconLeading = self.intrinsicSize(self.row(.iconLeading, trailing: "chevron.forward"))
        let expected = CoreControlMetrics.iconSize(for: .large) + CoreSpacing.sm
        #expect(iconLeading.width - withTrailing.width == expected)
    }

    @Test("兜底：SidebarUtilityRow 与 SidebarNavigationRow 同 title 时宽度逐点相等")
    func siblingRowWidthsStayAligned() {
        // ⚠️ **限度自陈**：本兜底只抓「**只影响 SidebarUtilityRow 一条行**」的改动 ——
        // 例如有人在其 body 外层加了 `.padding()` ⇒ Util ≠ Nav ⇒ 本条红，而承重差值断言
        // （两个变体等量受影响）**不会**红。
        // ⚠️ 反过来，对**四条兄弟行一起变**的**骨架级**改动本条**结构性失明** —— 因为它断的是
        // 两条行「相对相等」，而 `SidebarRow` 是共用骨架、改动对两条等量生效。
        // 实测：`iconSize` 20→16 时 Util=Nav=107.0、`spacing`→0 时 Util=Nav=95.0，**两次都绿**，
        // 全靠承重差值断言抓（24 / 20 ≠ 28）。⇒ 看到「承重红、兜底绿」是**预期**，别去"加强"本条。
        let util = self.intrinsicSize(self.row(.iconLeading))
        let nav = self.intrinsicSize(
            SidebarNavigationRow(systemImage: "gearshape", title: "Settings", isSelected: false) {}
        )
        #expect(util.width > 0)
        #expect(util.width == nav.width,
                "两者走同一骨架、同 titleLineLimit、同 isSelected: false、trailing 皆空 ⇒ 宽度应相等")
    }
}
