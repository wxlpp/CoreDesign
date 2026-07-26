import Testing
import SwiftUI
@testable import CoreDesign

// macOS 无 Dynamic Type：ScaledMetric 恒返回 wrappedValue（NSFont.preferredFont(.body)
// 恒 13pt）。故整套断言 #if os(iOS)，只在第 5 条 xcodebuild iOS Simulator 命令下执行；
// 四条 SwiftPM 命令下本 suite 为空，不构成假绿——凡改本文件覆盖的组件都须跑第 5 条命令。
#if os(iOS)
@Suite("Dynamic Type 布局")
@MainActor
struct DynamicTypeLayoutTests {
    /// 在给定 Dynamic Type 尺寸下渲染并量高度。
    /// 用 ImageRenderer（不依赖颜色——asset 色在测试下解析为透明，本处只读尺寸）。
    private func renderedHeight<V: View>(
        _ view: V,
        at size: DynamicTypeSize
    ) -> CGFloat {
        let renderer = ImageRenderer(
            content: view
                .environment(\.dynamicTypeSize, size)
                .frame(width: 320)   // 固定宽度，让高度反映字号/换行
        )
        renderer.scale = 1
        return renderer.uiImage?.size.height ?? 0
    }

    // Task 1 Step 4 的 spike，保留作机制回归锚点（改用 renderedHeight）。
    @Test("spike：ImageRenderer 尊重注入的 dynamicTypeSize")
    func imageRendererRespectsDynamicType() {
        let text = Text("Ag").coreFont(.body)
        #expect(self.renderedHeight(text, at: .accessibility5) > self.renderedHeight(text, at: .large),
                "ImageRenderer 未按注入档缩放——Task 5 的整套断言不成立")
    }

    @Test("Sidebar 四种 row 的高度随 Dynamic Type 单调不减")
    func sidebarRowsGrowWithDynamicType() {
        // 注意：本断言的高度增长依赖 `SidebarRow` 的 **title** 字号缩放（Task 3 已把
        // SidebarRow 的 title 迁到 coreFont）。若 title 仍是固定 Font，此断言不通电。
        let row = SidebarNavigationRow(systemImage: "star", title: "Long enough title to wrap at accessibility sizes", isSelected: false) {}

        let small = self.renderedHeight(row, at: .large)          // 默认档
        let xxxl  = self.renderedHeight(row, at: .xxxLarge)
        let ax5   = self.renderedHeight(row, at: .accessibility5)

        #expect(small > 0, "渲染失败（uiImage nil）——下面的比较会以 0 假通过")
        // 主断言用**最大跨度** large vs accessibility5——`row` 有 `minHeight` 地板，
        // 相邻/近档可能都被夹到地板值。最大跨度才必然突破地板。
        #expect(ax5 > small, "accessibility5 未比 large 高——字号没缩放或被固定高度裁切")
        #expect(xxxl >= small, "xxxLarge 应 ≥ large")
        #expect(ax5 >= xxxl, "accessibility5 应 ≥ xxxLarge")
    }

    @Test("Sidebar 单行钳制 row（Document）在放大档同样撑高不裁切")
    func sidebarSingleLineRowGrows() {
        // Document row 传 titleLineLimit: 1（与 Navigation 的 nil 换行行为不同），
        // 单独覆盖单行钳制路径——AC 是「四种 row 不裁切」。
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

    // Issue #119 之前：`captionSmall` 是故意不缩放的固定 9pt chrome 字号
    // （旧 `Spec.scales == false`）。Issue #119 之后：`captionSmall` 只是
    // `caption2`（`@available(*, deprecated, renamed: "caption2")`）的弃用别名，
    // 语义完全由 `caption2`（系统 `.caption2` 文本样式）决定，会随 Dynamic Type 缩放。
    // 本测试断言方向相对旧版本**故意翻转**——这是 119.md AC 明确要求的行为变化，
    // 不是回归；保留旧名 `captionSmallDoesNotScale` 会误导读者，故一并更名。
    @Test("captionSmall 现在是 caption2 的别名，随 Dynamic Type 缩放")
    func captionSmallNowScalesViaCaption2Alias() {
        let text = Text("9").coreFont(.caption2)
        let small = self.renderedHeight(text, at: .large)
        let ax5   = self.renderedHeight(text, at: .accessibility5)
        #expect(small > 0, "渲染失败（uiImage nil）")
        #expect(ax5 > small, "captionSmall（→ caption2）未随 Dynamic Type 缩放——别名映射或 caption2 的 textStyle 错了")
    }

    // MARK: - 全部 12 档 token 覆盖（Issue #123）
    //
    // 上面几个既有测试只抽样验证了 `.body` / `.caption2` 两档——`CoreTypography.Token`
    // 重铸后一一对应 12 个系统 `Font.TextStyle`（Task #119），"重铸带来的可访问性
    // 承诺"须对全部 12 档兑现，不能只信抽样。用 `Token.allCases` 参数化，每档独立
    // 断言 large → accessibility5 单调增长——任何一档的 `textStyle` 映射写错（比如
    // 误连到不随 Dynamic Type 缩放的 `.system(size:)` 定值写法）都会在这里单独现形，
    // 而不是被抽样掩盖。
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
    //
    // 上面的 Sidebar 断言只覆盖 Sidebar 一族；`ListRow` 是另一个高频复合布局
    // （leading icon + 两行 label + trailing），且 label 的标题/副标题两个
    // `coreFont` 档位不同（`.callout` / `.footnote`，参见 `ListRow.swift` 预览）。
    // 用同一「large → accessibility5 高度不减」判据验证：若两行文字在放大档
    // 被固定高度裁掉，或 leading icon 与文字重叠导致渲染高度反而不变/更小，
    // 这里会失败。
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
        // 本仓库其余组件都用 `frame(minHeight:)`（地板，内容可撑高），唯独
        // `SegmentedControl.swift:149` 用 `frame(height:)`——**钳制**。
        // `CoreControlMetrics` 自己的文档就警告过：钳制在字号变大时会裁切 label，
        // 而地板不会。这是全库唯一采用该机制的地方，因此也是最可能在最大辅助功能
        // 字号下出问题的组件，本断言专门盯它。
        let control = SegmentedControl(
            items: ["一个比较长的选项", "另一个"],
            selection: .constant("一个比较长的选项"),
            title: { $0 }
        )
        let normal = self.renderedHeight(control, at: .large)
        let ax5 = self.renderedHeight(control, at: .accessibility5)
        #expect(normal > 0, "渲染失败")
        // 钳制的预期行为就是高度不变；这里断言的是「高度确实被钳住」这一事实，
        // 让它显式可见。文字在该高度下是否被截断，属视觉判断，交 #125。
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

        // 常规字号下 `.two` 把两行配成一个 Grid 行（并排），应明显矮于把两行各自
        // 独占一行的 `.one`——这是「未塌列」的正常状态，先确认基线成立。
        let twoAtLarge = self.renderedHeight(twoColumn, at: .large)
        let oneAtLarge = self.renderedHeight(oneColumn, at: .large)
        #expect(twoAtLarge > 0 && oneAtLarge > 0, "渲染失败（uiImage nil）")
        #expect(twoAtLarge < oneAtLarge, "常规字号下 .two 应比 .one 矮（两行并排成一组）——基线不成立，下面的塌列断言无意义")

        // accessibility5 下 `DescriptionsLayout.effectiveColumns` 强制 `.two` → `.one`
        // （见 DescriptionsTests.swift 的纯函数覆盖）；本测试从**渲染**角度验证同一
        // 结论——真正塌列后，`.two` 应与显式传入 `.one` 渲染出（近似）相同的高度。
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
        // `PinCode.cellSize` 本身取 `CoreControlMetrics.height(for: controlSize)`——
        // 一个固定 pt 值、不经 `ScaledMetric`，格子外框 `.frame(width:height:)` 名义上
        // 是精确尺寸而非地板。但格内数字用 `.coreFont(.title2)`，字号本身随 Dynamic
        // Type 缩放（见上方「全部 12 档 token」断言）；`.frame(width:height:)` 默认
        // 不裁切溢出内容，字号变大时文本视觉尺寸超出该 frame 的名义边界，
        // `ImageRenderer` 量到的整体渲染高度因此仍随之增长（实测 large=44pt →
        // accessibility5=65pt）——这与 `SegmentedControl`（用
        // `frame(height:)` + 明确裁切策略）的钳制现状不同源，此处记录实际渲染行为，
        // 供未来若改用 `ScaledMetric` 驱动 `cellSize` 本身时对照回归。
        let pinCode = PinCode(value: .constant("123456"), length: 6)
        let normal = self.renderedHeight(pinCode, at: .large)
        let ax5 = self.renderedHeight(pinCode, at: .accessibility5)
        #expect(normal > 0, "渲染失败")
        #expect(ax5 > normal, "PinCode 在 accessibility5 未撑高（\(normal) → \(ax5)）——格内数字字号未随 Dynamic Type 缩放")
    }

    // MARK: - Rating / Radio / TagInput / Timeline 补充覆盖（Issue #188）
    //
    // Descriptions 塌列断言之外，semi-mobile-components epic 引入的另外四个组件此前
    // 没有 accessibility 大字号下的关键布局断言。逐组件挑一条有实义的判据，手法沿用
    // 上方既有断言（`renderedHeight` + large → accessibility5 对比）。

    @Test("Rating 星形在 accessibility5 下仍正常渲染、不塌成 0 高度（星形边长走固定 iconSize、不随 Dynamic Type 缩放——记录现状，非回归判据，只守住不消失/不裁切）")
    func ratingStarsRenderAtAccessibility5WithoutCollapsing() {
        let rating = Rating(value: .constant(3), count: 5)
        let ax5 = self.renderedHeight(rating, at: .accessibility5)
        #expect(ax5 > 0, "Rating 在 accessibility5 下渲染失败或塌缩为 0 高度")
        // `frame(minHeight:)` 命中区地板保证下限，即便星形本身不随字号缩放。
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
