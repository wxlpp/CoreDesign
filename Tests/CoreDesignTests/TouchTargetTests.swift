import Testing
import SwiftUI
@testable import CoreDesign

#if os(iOS)
@Suite("触控目标 ≥ 44pt")
@MainActor
struct TouchTargetTests {
    private static let minimumHitTarget: CGFloat = 44

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
        let bar = UnderlinedTabBar(
            items: ["全部"],
            selection: .constant("全部"),
            title: { $0 }
        )
        let height = self.renderedHeight(bar)
        #expect(height >= Self.minimumHitTarget, "UnderlinedTabBar item 实测高度 \(height)pt < 44pt")
    }

    // MARK: - SegmentedControl（只测整体容器；单段命中区域未覆盖）

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

    // MARK: - semi-mobile-components epic 新交互组件（Phase 3 / #173 汇入）

    @Test("Rating 在 .regular 档实测命中高度 ≥ 44pt（星形视觉尺寸本身小于 44pt，靠 frame(minHeight:) 补足）")
    func ratingMeetsMinimumTouchTarget() {
        let rating = Rating(value: .constant(3))
            .controlSize(.regular)
        let height = self.renderedHeight(rating, width: nil)
        #expect(height >= Self.minimumHitTarget, "Rating 实测高度 \(height)pt < 44pt")
    }

    @Test("RadioGroup 单选项实测命中高度 ≥ 44pt")
    func radioGroupMeetsMinimumTouchTarget() {
        let group = RadioGroup(
            selection: .constant("basic"),
            options: [RadioOption(value: "basic", title: "Basic")]
        )
        let height = self.renderedHeight(group, width: nil)
        #expect(height >= Self.minimumHitTarget, "RadioGroup 单选项实测高度 \(height)pt < 44pt")
    }

    @Test("PinCode 在 .regular 档实测高度 ≥ 44pt（格子本身即 CoreControlMetrics.height(for:)，无需 contentShape 撑高）")
    func pinCodeMeetsMinimumTouchTarget() {
        let pinCode = PinCode(value: .constant("12"), length: 6)
            .controlSize(.regular)
        let height = self.renderedHeight(pinCode, width: nil)
        #expect(height >= Self.minimumHitTarget, "PinCode 实测高度 \(height)pt < 44pt")
    }

    @Test("TagInput 空态输入框实测高度 ≥ 44pt（TextField 自身 frame(minHeight:)，非 contentShape 撑高）")
    func tagInputMeetsMinimumTouchTarget() {
        let field = TagInput(tags: .constant([]), placeholder: "Add tag")
        let height = self.renderedHeight(field, width: 320)
        #expect(height >= Self.minimumHitTarget, "TagInput 空态实测高度 \(height)pt < 44pt")
    }

    @Test("ExtendedFloatButtonStyle 默认档（.large）与显式 .regular 档均实测 ≥ 44pt")
    func extendedFloatButtonMeetsMinimumTouchTarget() {
        let defaultButton = Button {} label: {
            Label("New", systemImage: "plus")
        }
        .buttonStyle(.extendedFloat)
        let regularButton = Button {} label: {
            Label("New", systemImage: "plus")
        }
        .buttonStyle(.extendedFloat(size: .regular))

        let defaultHeight = self.renderedHeight(defaultButton, width: nil)
        let regularHeight = self.renderedHeight(regularButton, width: nil)
        #expect(defaultHeight >= Self.minimumHitTarget, "ExtendedFloatButtonStyle 默认档实测高度 \(defaultHeight)pt < 44pt")
        #expect(regularHeight >= Self.minimumHitTarget, "ExtendedFloatButtonStyle .regular 档实测高度 \(regularHeight)pt < 44pt")
    }
}
#endif
