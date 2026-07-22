import Testing
import SwiftUI
@testable import CoreDesign

// Issue #123：把「全部交互组件在 .regular 控件尺寸下实测可点击高度 ≥ 44pt」这条
// 可访问性承诺兑现成断言。与 `DynamicTypeLayoutTests` 同样的限定：本 suite 整个
// `#if os(iOS)`，只在 CI 的 xcodebuild iOS Simulator 腿上执行——四条 SwiftPM
// 命令下本 suite 为空，不构成假绿；改动本文件覆盖的组件都须跑那条命令验证。
//
// 断言的是**真实命中区域**（`contentShape` 撑到的 frame），不是「视觉高度」——
// 两者在部分组件上并不相等（参见 `CoreControlMetrics.verticalPadding` 的
// doc-comment：`frame(minHeight:)` 是地板，不是钳制）。用 `ImageRenderer` 渲染
// 并量整个视图的 bounding box 高度，对「整个视图即单一命中区域」的组件（四种
// Button style、SearchField、ListRow、CheckBox、CoreMenuButton、Sidebar 行、
// UnderlinedTabBar item）是可靠的代理：这些组件的 `contentShape` 都直接盖在
// 报告出的 frame 上，bounding box 高度就是命中区域高度。
//
// **已知不适用的例外**：`SegmentedControl` 内部由多个独立分段 Button 组成，整体
// 容器高度（44pt，`frame(height:)` 钳制）与单个分段的真实命中高度是两回事——
// 分段容器四边各有 `CoreSpacing.xxs`（2pt）内缩（`NativeGlassSegmentedControlView`
// / `SwiftUISegmentedControl` 两条渲染路径都有），单段实测命中高度约 40pt，
// 低于 44pt 地板。这条不是本文件能用整体 bounding box 测出的（外层容器仍报
// 44pt），已作为 Task #123 的发现在 PR / issue 说明中记录，留给设计判断
// （改动分段内缩量涉及玻璃胶囊的视觉比例，属于 Task #125 视觉终审范畴）。
#if os(iOS)
@Suite("触控目标 ≥ 44pt")
@MainActor
struct TouchTargetTests {
    private static let minimumHitTarget: CGFloat = 44

    /// 渲染并量高度——与 `DynamicTypeLayoutTests.renderedHeight` 同一模式。
    /// `width` 给需要横向撑满（`frame(maxWidth: .infinity)`）的行类组件一个
    /// 确定的画布宽度；不需要的（独立 Button）传 `nil` 走 intrinsic 尺寸。
    private func renderedHeight<V: View>(_ view: V, width: CGFloat? = 320) -> CGFloat {
        let content: AnyView = if let width {
            AnyView(view.frame(width: width))
        } else {
            AnyView(view)
        }
        let renderer = ImageRenderer(content: content)
        renderer.scale = 1
        return renderer.uiImage?.size.height ?? 0
    }

    // MARK: - Button 四种 style

    @Test("SolidButtonStyle 在 .regular 档实测命中高度 ≥ 44pt")
    func solidButtonMeetsMinimumTouchTarget() {
        let button = Button("Save") {}
            .buttonStyle(.solid(role: .primary))
            .controlSize(.regular)
        let height = self.renderedHeight(button, width: nil)
        #expect(height >= Self.minimumHitTarget, "SolidButtonStyle 实测高度 \(height)pt < 44pt")
    }

    @Test("LightButtonStyle 在 .regular 档实测命中高度 ≥ 44pt")
    func lightButtonMeetsMinimumTouchTarget() {
        let button = Button("Cancel") {}
            .buttonStyle(.light(role: .secondary))
            .controlSize(.regular)
        let height = self.renderedHeight(button, width: nil)
        #expect(height >= Self.minimumHitTarget, "LightButtonStyle 实测高度 \(height)pt < 44pt")
    }

    @Test("CoreBorderlessButtonStyle 在 .regular 档实测命中高度 ≥ 44pt")
    func borderlessButtonMeetsMinimumTouchTarget() {
        let button = Button("Learn more") {}
            .buttonStyle(.borderless(role: .primary))
            .controlSize(.regular)
        let height = self.renderedHeight(button, width: nil)
        #expect(height >= Self.minimumHitTarget, "CoreBorderlessButtonStyle 实测高度 \(height)pt < 44pt")
    }

    @Test("CircularGlassButtonStyle 默认档（.large）与显式 .regular 档均实测 ≥ 44pt")
    func circularGlassButtonMeetsMinimumTouchTarget() {
        let defaultButton = Button {} label: {
            Image(systemName: "paperplane")
        }
        .buttonStyle(.circularGlass)
        let regularButton = Button {} label: {
            Image(systemName: "paperplane")
        }
        .buttonStyle(.circularGlass(size: .regular))

        let defaultHeight = self.renderedHeight(defaultButton, width: nil)
        let regularHeight = self.renderedHeight(regularButton, width: nil)
        #expect(defaultHeight >= Self.minimumHitTarget, "CircularGlassButtonStyle 默认档实测高度 \(defaultHeight)pt < 44pt")
        #expect(regularHeight >= Self.minimumHitTarget, "CircularGlassButtonStyle .regular 档实测高度 \(regularHeight)pt < 44pt")
    }

    // MARK: - SearchField

    @Test("SearchField 在 .regular 档实测命中高度 ≥ 44pt")
    func searchFieldMeetsMinimumTouchTarget() {
        let field = SearchField(text: .constant(""))
        let height = self.renderedHeight(field)
        #expect(height >= Self.minimumHitTarget, "SearchField 实测高度 \(height)pt < 44pt")
    }

    // MARK: - ListRow

    @Test("ListRow 在 .regular 档实测命中高度 ≥ 44pt")
    func listRowMeetsMinimumTouchTarget() {
        let row = ListRow {
            Text("All issues")
        }
        let height = self.renderedHeight(row)
        #expect(height >= Self.minimumHitTarget, "ListRow 实测高度 \(height)pt < 44pt")
    }

    // MARK: - CheckBox（Toggle 类）

    @Test("CheckBoxToggleStyle 实测命中高度 ≥ 44pt（Issue #123 修复：原先无 contentShape/minHeight）")
    func checkBoxMeetsMinimumTouchTarget() {
        let toggle = Toggle("Accept terms", isOn: .constant(false))
            .toggleStyle(CheckBoxToggleStyle())
        let height = self.renderedHeight(toggle, width: nil)
        #expect(height >= Self.minimumHitTarget, "CheckBoxToggleStyle 实测高度 \(height)pt < 44pt")
    }

    // MARK: - CoreMenuButton（BottomInputBar 内部）

    @Test("CoreMenuButton labeled 档实测命中高度 ≥ 44pt")
    func coreMenuButtonLabeledMeetsMinimumTouchTarget() {
        let button = CoreMenuButton(isExpanded: .constant(false), style: .labeled)
        let height = self.renderedHeight(button, width: nil)
        #expect(height >= Self.minimumHitTarget, "CoreMenuButton(.labeled) 实测高度 \(height)pt < 44pt")
    }

    @Test("CoreMenuButton circular 档实测命中高度 ≥ 44pt")
    func coreMenuButtonCircularMeetsMinimumTouchTarget() {
        let button = CoreMenuButton(isExpanded: .constant(false), style: .circular)
        let height = self.renderedHeight(button, width: nil)
        #expect(height >= Self.minimumHitTarget, "CoreMenuButton(.circular) 实测高度 \(height)pt < 44pt")
    }

    // MARK: - BottomInputBar（整体，含内部 circularGlass 尾部按钮）

    @Test("BottomInputBar 整体实测高度 ≥ 44pt（内部尾部按钮走 circularGlass .large 档）")
    func bottomInputBarMeetsMinimumTouchTarget() {
        let bar = BottomInputBar(
            isShowingSuggestions: .constant(false),
            onSubmit: { _ in }
        )
        let height = self.renderedHeight(bar, width: 320)
        #expect(height >= Self.minimumHitTarget, "BottomInputBar 实测高度 \(height)pt < 44pt")
    }

    // MARK: - Sidebar 四种 row

    @Test("SidebarNavigationRow 实测命中高度 ≥ 44pt")
    func sidebarNavigationRowMeetsMinimumTouchTarget() {
        let row = SidebarNavigationRow(systemImage: "house", title: "Home", isSelected: false) {}
        let height = self.renderedHeight(row)
        #expect(height >= Self.minimumHitTarget, "SidebarNavigationRow 实测高度 \(height)pt < 44pt")
    }

    @Test("SidebarUtilityRow 实测命中高度 ≥ 44pt")
    func sidebarUtilityRowMeetsMinimumTouchTarget() {
        let row = SidebarUtilityRow(systemImage: "gearshape", title: "Settings") {}
        let height = self.renderedHeight(row)
        #expect(height >= Self.minimumHitTarget, "SidebarUtilityRow 实测高度 \(height)pt < 44pt")
    }

    @Test("SidebarDocumentRow 实测命中高度 ≥ 44pt")
    func sidebarDocumentRowMeetsMinimumTouchTarget() {
        let row = SidebarDocumentRow(systemImage: "doc.text", title: "Design Spec", detail: "3d") {}
        let height = self.renderedHeight(row)
        #expect(height >= Self.minimumHitTarget, "SidebarDocumentRow 实测高度 \(height)pt < 44pt")
    }

    @Test("SidebarTagRow 实测命中高度 ≥ 44pt")
    func sidebarTagRowMeetsMinimumTouchTarget() {
        let row = SidebarTagRow(title: "swiftui") {}
        let height = self.renderedHeight(row)
        #expect(height >= Self.minimumHitTarget, "SidebarTagRow 实测高度 \(height)pt < 44pt")
    }

    // MARK: - UnderlinedTabBar item

    @Test("UnderlinedTabBar 单项实测命中高度 ≥ 44pt（Issue #123 修复：原先无 minHeight）")
    func underlinedTabBarItemMeetsMinimumTouchTarget() {
        // `UnderlinedTabItem` 是文件私有类型，无法从测试文件直接实例化；用单项
        // bar 间接测量——bar 的 body 除 `ScrollViewReader` 外无其它纵向内容，
        // 整体高度即该单项的高度。
        let bar = UnderlinedTabBar(
            items: ["全部"],
            selection: .constant("全部"),
            title: { $0 }
        )
        let height = self.renderedHeight(bar)
        #expect(height >= Self.minimumHitTarget, "UnderlinedTabBar item 实测高度 \(height)pt < 44pt")
    }

    // MARK: - SegmentedControl（整体容器；单段命中区域的已知缺口见文件头注释）

    @Test("SegmentedControl 整体容器实测高度 ≥ 44pt")
    func segmentedControlContainerMeetsMinimumTouchTarget() {
        let control = SegmentedControl(
            items: ["A", "B"],
            selection: .constant("A"),
            title: { $0 }
        )
        let height = self.renderedHeight(control)
        #expect(height >= Self.minimumHitTarget, "SegmentedControl 容器实测高度 \(height)pt < 44pt")
    }
}
#endif
