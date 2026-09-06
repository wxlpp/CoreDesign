import Testing
import SwiftUI
@testable import CoreDesign

#if os(iOS)
@Suite("Dynamic Type 布局")
@MainActor
struct DynamicTypeLayoutTests {
    private func renderedHeight<V: View>(
        _ view: V,
        at size: DynamicTypeSize
    ) -> CGFloat {
        let renderer = ImageRenderer(
            content: view
                .environment(\.dynamicTypeSize, size)
                .frame(width: 320)
        )
        renderer.scale = 1
        return renderer.uiImage?.size.height ?? 0
    }

    @Test("spike：ImageRenderer 尊重注入的 dynamicTypeSize")
    func imageRendererRespectsDynamicType() {
        let text = Text("Ag").coreFont(.body)
        #expect(self.renderedHeight(text, at: .accessibility5) > self.renderedHeight(text, at: .large),
                "ImageRenderer 未按注入档缩放——Task 5 的整套断言不成立")
    }

    @Test("Sidebar 四种 row 的高度随 Dynamic Type 单调不减")
    func sidebarRowsGrowWithDynamicType() {
        let row = SidebarNavigationRow(systemImage: "star", title: "Long enough title to wrap at accessibility sizes", isSelected: false) {}

        let small = self.renderedHeight(row, at: .large)
        let xxxl  = self.renderedHeight(row, at: .xxxLarge)
        let ax5   = self.renderedHeight(row, at: .accessibility5)

        #expect(small > 0, "渲染失败（uiImage nil）——下面的比较会以 0 假通过")
        #expect(ax5 > small, "accessibility5 未比 large 高——字号没缩放或被固定高度裁切")
        #expect(xxxl >= small, "xxxLarge 应 ≥ large")
        #expect(ax5 >= xxxl, "accessibility5 应 ≥ xxxLarge")
    }

    @Test("Sidebar 单行钳制 row（Document）在放大档同样撑高不裁切")
    func sidebarSingleLineRowGrows() {
        let row = SidebarDocumentRow(systemImage: "doc", title: "Document title", detail: "3 days ago") {}
        let small = self.renderedHeight(row, at: .large)
        let ax5   = self.renderedHeight(row, at: .accessibility5)
        #expect(small > 0, "渲染失败（uiImage nil）")
        #expect(ax5 > small, "Document row 在 accessibility5 未撑高——单行钳制下字号没缩放或被裁")
    }

    @Test("coreFont 的字号在 iOS 下确实随 Dynamic Type 变化")
    func coreFontActuallyScales() {
        let text = Text("Ag").coreFont(.body)
        let small = self.renderedHeight(text, at: .large)
        let ax5   = self.renderedHeight(text, at: .accessibility5)
        #expect(small > 0, "渲染失败（uiImage nil）")
        #expect(ax5 > small, "coreFont 未缩放——ScaledMetric 或 textStyle 基准错了")
    }

    @Test("captionSmall 现在是 caption2 的别名，随 Dynamic Type 缩放")
    func captionSmallNowScalesViaCaption2Alias() {
        let text = Text("9").coreFont(.caption2)
        let small = self.renderedHeight(text, at: .large)
        let ax5   = self.renderedHeight(text, at: .accessibility5)
        #expect(small > 0, "渲染失败（uiImage nil）")
        #expect(ax5 > small, "captionSmall（→ caption2）未随 Dynamic Type 缩放——别名映射或 caption2 的 textStyle 错了")
    }

    // MARK: - 全部 12 档 token 覆盖（Issue #123）

    @Test(
        "CoreTypography 全部 12 档 token 在 iOS 下均随 Dynamic Type 缩放",
        arguments: CoreTypography.Token.allCases
    )
    func everyTypographyTokenScalesWithDynamicType(_ token: CoreTypography.Token) {
        let text = Text("Ag").coreFont(token)
        let small = self.renderedHeight(text, at: .large)
        let ax5 = self.renderedHeight(text, at: .accessibility5)
        #expect(small > 0, "\(token)：渲染失败（uiImage nil）")
        #expect(ax5 > small, "\(token) 未随 Dynamic Type 缩放（large=\(small)pt, accessibility5=\(ax5)pt）")
    }

    // MARK: - 复合布局在最大辅助功能字号下不裁切、不重叠（Issue #123）

    @Test("ListRow 两行 label 在 accessibility5 下随 Dynamic Type 撑高、不裁切")
    func listRowGrowsWithDynamicTypeWithoutClipping() {
        let row = ListRow(
            leading: {
                Image(systemName: "doc.text")
            },
            label: {
                VStack(alignment: .leading, spacing: CoreSpacing.xxs) {
                    Text("A sufficiently long title to wrap at accessibility sizes")
                        .coreFont(.callout)
                    Text("Updated 2 hours ago")
                        .coreFont(.footnote)
                }
            },
            trailing: {
                Image(systemName: "chevron.forward")
            }
        )
        let small = self.renderedHeight(row, at: .large)
        let ax5 = self.renderedHeight(row, at: .accessibility5)
        #expect(small > 0, "渲染失败（uiImage nil）")
        #expect(ax5 > small, "ListRow 在 accessibility5 未撑高——两行 label 没缩放或被裁切/重叠")
    }

    @Test("SegmentedControl 在 accessibility5 下高度仍被钳制在 44pt（现状记录；是否裁切文字见 #125，未在此断言）")
    func segmentedControlHeightStaysClampedAtLargestSize() {
        let control = SegmentedControl(
            items: ["一个比较长的选项", "另一个"],
            selection: .constant("一个比较长的选项"),
            title: { $0 }
        )
        let normal = self.renderedHeight(control, at: .large)
        let ax5 = self.renderedHeight(control, at: .accessibility5)
        #expect(normal > 0, "渲染失败")
        let delta: CGFloat = ax5 > normal ? ax5 - normal : normal - ax5
        #expect(
            delta < 1,
            "SegmentedControl 高度随字号变化了（\(normal) → \(ax5)）——若已改为 minHeight，本断言与其注释需同步更新"
        )
    }

    // MARK: - semi-mobile-components epic 塌列 / Dynamic Type 断言（Phase 3 / #173 汇入）

    @Test("Descriptions：columns: .two 在 accessibility5 下真正塌成单列——渲染高度收敛到与 columns: .one 一致，而非仅仅字号变大")
    func descriptionsTwoColumnCollapsesToOneColumnAtAccessibilitySize() {
        @ViewBuilder
        func rows() -> some View {
            LabeledContent("Status") { Text("Active") }
            LabeledContent("Total") { Text("$42.00") }
        }

        let twoColumn = Descriptions(columns: .two) { rows() }
        let oneColumn = Descriptions(columns: .one) { rows() }

        let twoAtLarge = self.renderedHeight(twoColumn, at: .large)
        let oneAtLarge = self.renderedHeight(oneColumn, at: .large)
        #expect(twoAtLarge > 0 && oneAtLarge > 0, "渲染失败（uiImage nil）")
        #expect(twoAtLarge < oneAtLarge, "常规字号下 .two 应比 .one 矮（两行并排成一组）——基线不成立，下面的塌列断言无意义")

        let twoAtAX5 = self.renderedHeight(twoColumn, at: .accessibility5)
        let oneAtAX5 = self.renderedHeight(oneColumn, at: .accessibility5)
        let delta: CGFloat = abs(twoAtAX5 - oneAtAX5)
        #expect(
            delta < 1,
            "columns: .two 未在 accessibility5 下渲染成与 .one 一致的高度（two=\(twoAtAX5), one=\(oneAtAX5)）——塌列失效或行分组逻辑跑偏"
        )
    }

    @Test("Steps 纵向布局在 accessibility5 下随 Dynamic Type 撑高、不裁切（标题 + 描述两行文字）")
    func stepsVerticalGrowsWithDynamicTypeWithoutClipping() {
        let steps = Steps(
            items: [
                StepItem(title: "A sufficiently long step title to wrap at accessibility sizes", description: "With a description line too"),
                StepItem(title: "Second step"),
            ],
            currentIndex: 0,
            axis: .vertical
        )
        let small = self.renderedHeight(steps, at: .large)
        let ax5 = self.renderedHeight(steps, at: .accessibility5)
        #expect(small > 0, "渲染失败（uiImage nil）")
        #expect(ax5 > small, "Steps 纵向布局在 accessibility5 未撑高——标题/描述文字没有随 Dynamic Type 缩放或被裁切")
    }

    @Test("PinCode 格位在 accessibility5 下随 Dynamic Type 撑高、不裁切（现状记录）")
    func pinCodeGrowsWithDynamicType() {
        let pinCode = PinCode(value: .constant("123456"), length: 6)
        let normal = self.renderedHeight(pinCode, at: .large)
        let ax5 = self.renderedHeight(pinCode, at: .accessibility5)
        #expect(normal > 0, "渲染失败")
        #expect(ax5 > normal, "PinCode 在 accessibility5 未撑高（\(normal) → \(ax5)）——格内数字字号未随 Dynamic Type 缩放")
    }

    // MARK: - Rating / Radio / TagInput / Timeline 补充覆盖（Issue #188）

    @Test("Rating 星形在 accessibility5 下仍正常渲染、不塌成 0 高度（星形边长走固定 iconSize、不随 Dynamic Type 缩放——记录现状，非回归判据，只守住不消失/不裁切）")
    func ratingStarsRenderAtAccessibility5WithoutCollapsing() {
        let rating = Rating(value: .constant(3), count: 5)
        let ax5 = self.renderedHeight(rating, at: .accessibility5)
        #expect(ax5 > 0, "Rating 在 accessibility5 下渲染失败或塌缩为 0 高度")
        #expect(
            ax5 >= CoreControlMetrics.height(for: .regular),
            "Rating 在 accessibility5 下高度（\(ax5)）低于 44pt 命中区地板——minHeight 地板失效"
        )
    }

    @Test("RadioGroup 在 accessibility5 下总高随 Dynamic Type 增长（长标题折行 + 逐行命中区撑高）")
    func radioGroupGrowsWithDynamicType() {
        let group = RadioGroup(
            selection: .constant("basic"),
            options: [
                RadioOption(value: "basic", title: "A sufficiently long radio option title to wrap at accessibility sizes"),
                RadioOption(value: "pro", title: "Another option"),
            ]
        )
        let small = self.renderedHeight(group, at: .large)
        let ax5 = self.renderedHeight(group, at: .accessibility5)
        #expect(small > 0, "渲染失败（uiImage nil）")
        #expect(ax5 > small, "RadioGroup 在 accessibility5 未撑高——长标题没有随 Dynamic Type 缩放/折行，或被裁切")
    }

    @Test("TagInput 多标签在 accessibility5 下随 Dynamic Type 折行增多、总高增长")
    func tagInputGrowsWithDynamicTypeAsTagsWrap() {
        let tagInput = TagInput(
            tags: .constant([
                "bug", "enhancement", "help wanted", "documentation",
                "good first issue", "dependencies", "question", "wontfix",
            ])
        )
        let small = self.renderedHeight(tagInput, at: .large)
        let ax5 = self.renderedHeight(tagInput, at: .accessibility5)
        #expect(small > 0, "渲染失败（uiImage nil）")
        #expect(ax5 > small, "TagInput 在 accessibility5 未撑高——chip 文字/输入框没有随 Dynamic Type 缩放折行")
    }

    @Test("Timeline 节点+内容行在 accessibility5 下行高随 Dynamic Type 增长、不重叠裁切")
    func timelineGrowsWithDynamicTypeWithoutOverlap() {
        let timeline = Timeline(items: [
            TimelineItem(status: .info) {
                VStack(alignment: .leading, spacing: CoreSpacing.xxs) {
                    Text("A sufficiently long timeline entry title to wrap at accessibility sizes")
                        .coreFont(.callout)
                    Text("2026-07-20 10:00").coreFont(.footnote)
                }
            },
            TimelineItem(status: .success) {
                Text("Second entry").coreFont(.callout)
            },
        ])
        let small = self.renderedHeight(timeline, at: .large)
        let ax5 = self.renderedHeight(timeline, at: .accessibility5)
        #expect(small > 0, "渲染失败（uiImage nil）")
        #expect(ax5 > small, "Timeline 在 accessibility5 未撑高——节点+内容行文字没有随 Dynamic Type 缩放，或行间发生重叠裁切")
    }
}
#endif
