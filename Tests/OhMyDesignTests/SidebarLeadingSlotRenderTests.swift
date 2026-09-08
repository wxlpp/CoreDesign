import Testing
import SwiftUI
@testable import OhMyDesign

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

@Suite("SidebarUtilityRow leading 槽渲染护栏（#64）")
@MainActor
struct SidebarLeadingSlotRenderTests {
    private static let minimumHitTarget: CGFloat = 44

    private func intrinsicSize(_ view: some View) -> CGSize {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        #if canImport(UIKit)
        return renderer.uiImage?.size ?? .zero
        #else
        return renderer.nsImage?.size ?? .zero
        #endif
    }

    private func pixels(_ view: some View) -> Data? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        #if canImport(UIKit)
        return renderer.uiImage?.pngData()
        #else
        guard let rep = renderer.nsImage?.tiffRepresentation else { return nil }
        return rep
        #endif
    }

    private func row(
        _ presentation: SidebarUtilityRowPresentation,
        trailing: String? = nil,
        systemImage: String = "gearshape"
    ) -> some View {
        SidebarUtilityRow(
            systemImage: systemImage,
            title: "Settings",
            trailingSystemImage: trailing,
            presentation: presentation
        ) {}
    }

    @Test("承重：.textOnly 不渲染 leading 槽、也不占位")
    func textOnlyDropsLeadingSlot() {
        let iconLeading = self.intrinsicSize(self.row(.iconLeading))
        let textOnly = self.intrinsicSize(self.row(.textOnly))

        #expect(iconLeading.width > 0, "渲染失败（尺寸为零）—— 本平台无法量测，不得当作通过")
        #expect(textOnly.width > 0, "渲染失败（尺寸为零）")

        let expected = CoreControlMetrics.iconSize(for: .large) + CoreSpacing.sm
        #expect(iconLeading.width - textOnly.width == expected,
                "leading 槽未被拆掉：实测差 \(iconLeading.width - textOnly.width)，期望 \(expected)")
    }

    @Test("承重：leading 字形真的由 systemImage 决定（组件不得忽略该入参）")
    func leadingGlyphIsDrivenBySystemImage() {
        let a = self.pixels(self.row(.iconLeading))
        let b = self.pixels(
            SidebarUtilityRow(systemImage: "trash", title: "Settings", presentation: .iconLeading) {}
        )
        #expect(a != nil && b != nil, "渲染失败 —— 本平台无法量测，不得当作通过")
        expectBitmapsDiffer(a, b, "换了 systemImage 但渲染逐字节相同 ⇒ 组件忽略了该入参（或 leading 根本没画字形）")
    }

    @Test("全部呈现组合的命中高度均 ≥ 44pt")
    func allPresentationsMeetMinimumTouchTarget() {
        for presentation in SidebarUtilityRowPresentation.allCases {
            for trailing in [nil, "chevron.forward"] as [String?] {
                let size = self.intrinsicSize(self.row(presentation, trailing: trailing))
                #expect(size.height >= Self.minimumHitTarget,
                        "\(presentation) trailing=\(trailing ?? "nil") 实测高度 \(size.height)pt < \(Self.minimumHitTarget)pt")
            }
        }
    }

    @Test("现状钉：全部呈现组合的高度互等且为 50（≠ a11y 契约，改 token 时须回来改这个数）")
    func rowHeightMatchesCurrentToken() {
        for presentation in SidebarUtilityRowPresentation.allCases {
            for trailing in [nil, "chevron.forward"] as [String?] {
                let size = self.intrinsicSize(self.row(presentation, trailing: trailing))
                #expect(size.height == 50,
                        "行高偏离现状值：\(presentation) trailing=\(trailing ?? "nil") 实测 \(size.height)，现状 50")
            }
        }
    }

    @Test("承重：.textOnly 完全忽略 systemImage —— 故写 \"\" 的约定不承重")
    func textOnlyIgnoresSystemImage() {
        let blank = self.pixels(self.row(.textOnly, systemImage: ""))
        let gear = self.pixels(self.row(.textOnly, systemImage: "gearshape"))
        let trash = self.pixels(self.row(.textOnly, systemImage: "trash"))

        #expect(blank != nil, "渲染失败 —— 本平台无法量测，不得当作通过")
        expectBitmapsEqual(blank, gear, ".textOnly 仍受 systemImage 影响：\"\" 与 gearshape 位图不同")
        expectBitmapsEqual(blank, trash, ".textOnly 仍受 systemImage 影响：\"\" 与 trash 位图不同")
    }

    @Test("候选 2 的组合：行尾字形真的占了位，且不影响 leading 侧差值")
    func trailingGlyphOccupiesSpace() {
        let textOnly = self.intrinsicSize(self.row(.textOnly))
        let withTrailing = self.intrinsicSize(self.row(.textOnly, trailing: "chevron.forward"))
        #expect(withTrailing.width > textOnly.width, "行尾字形没有占位 ⇒ 候选 2 的排布事实不成立")

        let iconLeading = self.intrinsicSize(self.row(.iconLeading, trailing: "chevron.forward"))
        let expected = CoreControlMetrics.iconSize(for: .large) + CoreSpacing.sm
        #expect(iconLeading.width - withTrailing.width == expected,
                "行尾字形影响了 leading 侧差值：实测差 \(iconLeading.width - withTrailing.width)，期望 \(expected)")
    }

    @Test("兜底：SidebarUtilityRow 与 SidebarNavigationRow 同 title 时宽度逐点相等")
    func siblingRowWidthsStayAligned() {
        let util = self.intrinsicSize(self.row(.iconLeading))
        let nav = self.intrinsicSize(
            SidebarNavigationRow(systemImage: "gearshape", title: "Settings", isSelected: false) {}
        )
        #expect(util.width > 0)
        #expect(util.width == nav.width,
                "两者走同一骨架、同 titleLineLimit、同 isSelected: false、trailing 皆空 ⇒ 宽度应相等；实测 Util=\(util.width) / Nav=\(nav.width)")
    }
}
