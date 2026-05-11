import SwiftUI
import CoreDesign

// MARK: - ComponentCategory

enum ComponentCategory: String, CaseIterable, Identifiable {
    case button = "Button"
    case form = "Form"
    case indicator = "Indicator"
    case layout = "Layout"
    case navigation = "Navigation"
    case feedback = "Feedback"

    var id: String { self.rawValue }
}

// MARK: - ComponentMeta

struct ComponentMeta: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let category: ComponentCategory
    let preview: () -> AnyView
    let demoAction: (() -> AnyView)?

    static func == (lhs: ComponentMeta, rhs: ComponentMeta) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(self.id) }

    init(
        id: String,
        name: String,
        description: String,
        category: ComponentCategory,
        @ViewBuilder preview: @escaping () -> some View,
        demoAction: (() -> AnyView)? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.preview = { AnyView(preview()) }
        self.demoAction = demoAction
    }
}

// MARK: - Component Registry

extension ComponentMeta {
    @MainActor static let all: [ComponentMeta] = [
        // Button
        ComponentMeta(id: "button", name: "Button", description: "3 种 ButtonStyle：solid / light / borderless，按 role 参数化配色", category: .button) {
            ButtonPreview()
        },

        // Form
        ComponentMeta(id: "label-icon", name: "Form Icons", description: "表单图标：LabelIcon / ChevronRightIcon / DangerIcon", category: .form) {
            FormIconsPreview()
        },
        ComponentMeta(id: "segmented-control", name: "SegmentedControl", description: "分段控件，token 化配色 + 选中态", category: .form) {
            SegmentedControlPreview()
        },
        ComponentMeta(id: "search-field", name: "SearchField", description: "搜索输入框 — magnifyingglass + clear button + focus ring", category: .form) {
            SearchFieldPreview()
        },
        ComponentMeta(id: "bottom-input-bar", name: "BottomInputBar", description: "底部输入栏 modifier，带自动补全 + 提交逻辑", category: .form) {
            BottomInputBarPreview()
        },

        // Indicator
        ComponentMeta(id: "badge", name: "Badge", description: "5 状态等级指示器：info / success / warning / danger / neutral", category: .indicator) {
            BadgePreview()
        },
        ComponentMeta(id: "tag", name: "Tag", description: "调用方自定义颜色的分类标签，支持 removable", category: .indicator) {
            TagPreview()
        },
        ComponentMeta(id: "banner", name: "Banner", description: "通知横幅，支持 info / success / warning / danger 四级", category: .indicator) {
            BannerPreview()
        },

        // Layout
        ComponentMeta(id: "avatar", name: "Avatar", description: "头像组件，按名称首字母生成", category: .layout) {
            AvatarPreview()
        },
        ComponentMeta(id: "book-cover", name: "BookCover", description: "书封渲染，按 Primer 视觉收齐", category: .layout) {
            BookCoverPreview()
        },
        ComponentMeta(id: "empty-state", name: "EmptyState", description: "空状态占位，可选 CTA 按钮", category: .layout) {
            EmptyStatePreview()
        },
        ComponentMeta(id: "list-row", name: "ListRow", description: "3-槽位泛型列表行：leading / label / trailing", category: .layout) {
            ListRowPreview()
        },

        // Navigation
        ComponentMeta(id: "sidebar-row", name: "SidebarRow", description: "侧栏行，hover 高亮 + selected accent 条", category: .navigation) {
            SidebarRowPreview()
        },
        ComponentMeta(id: "underlined-tab-bar", name: "UnderlinedTabBar", description: "下划线式 TabBar，token 化配色 + 选中态指示器", category: .navigation) {
            UnderlinedTabBarPreview()
        },

        // Feedback
        ComponentMeta(id: "toast", name: "Toast", description: "Scene-scoped toast host + 队列状态机", category: .feedback, preview: {
            Text("Toast 通过 `.toastHost(edge:)` modifier 挂载到 WindowGroup 根级别")
                .font(CoreTypography.bodySmallFont)
                .foregroundStyle(Color.contentMuted)
        }, demoAction: { AnyView(ToastDemoButton()) }),
    ]
}

// MARK: - Component Previews

private struct ButtonPreview: View {
    var body: some View {
        VStack(spacing: CoreSpacing.sm) {
            Button("Solid") {}.buttonStyle(.solid(role: .primary))
            Button("Light") {}.buttonStyle(.light(role: .primary))
            Button("Borderless") {}.buttonStyle(.borderless(role: .primary))
        }
    }
}

private struct FormIconsPreview: View {
    var body: some View {
        HStack(spacing: CoreSpacing.md) {
            LabelIcon(systemName: "person.fill", backgroundColor: .blue)
            LabelIcon(systemName: "star.fill", backgroundColor: .yellow)
            ChevronRightIcon()
            DangerIcon()
        }
    }
}

private struct SegmentedControlPreview: View {
    let items = ["One", "Two", "Three"]
    @State private var selection = "One"
    var body: some View {
        SegmentedControl(items: self.items, selection: self.$selection, title: { $0 })
    }
}

private struct SearchFieldPreview: View {
    @State private var text = "filter results"
    var body: some View { SearchField(text: self.$text) }
}

private struct BottomInputBarPreview: View {
    var body: some View {
        Text("BottomInputBar 通过 `.bottomInputBar` modifier 使用，非独立 View。")
            .font(CoreTypography.bodySmallFont)
            .foregroundStyle(Color.contentMuted)
            .padding()
    }
}

private struct BadgePreview: View {
    var body: some View {
        HStack(spacing: CoreSpacing.sm) {
            Badge("Info", variant: .info)
            Badge("Success", variant: .success)
            Badge("Warning", variant: .warning)
            Badge("Danger", variant: .danger)
            Badge("Neutral")
        }
    }
}

private struct TagPreview: View {
    var body: some View {
        HStack(spacing: CoreSpacing.sm) {
            Tag("bug", color: .red)
            Tag("enhancement", color: .blue)
            Tag("good first issue", color: .purple)
            Tag("doc", color: .cyan, removable: true, onRemove: {})
        }
    }
}

private struct BannerPreview: View {
    var body: some View {
        VStack(spacing: CoreSpacing.sm) {
            Banner(level: .info) { Text("Info message") }
            Banner(level: .success) { Text("Success message") }
            Banner(level: .warning) { Text("Warning message") }
            Banner(level: .danger) { Text("Danger message") }
        }
    }
}

private struct AvatarPreview: View {
    var body: some View {
        HStack(spacing: CoreSpacing.md) {
            Avatar(name: "Evan")
            Avatar(name: "CoreDesign")
        }
    }
}

private struct BookCoverPreview: View {
    var body: some View {
        BookCover(data: nil, title: "CoreDesign")
    }
}

private struct EmptyStatePreview: View {
    var body: some View {
        EmptyState(systemName: "magnifyingglass", title: "No results", description: "Try adjusting your search or filters.")
    }
}

private struct ListRowPreview: View {
    var body: some View {
        VStack(spacing: 0) {
            ListRow(label: { Text("Full row").foregroundStyle(Color.contentPrimary) })
            ListRow(
                leading: { Image(systemName: "doc.text").foregroundStyle(Color.contentMuted) },
                label: { Text("With icon").foregroundStyle(Color.contentPrimary) },
                trailing: { Image(systemName: "chevron.right").foregroundStyle(Color.contentMuted) }
            )
        }
    }
}

private struct SidebarRowPreview: View {
    var body: some View {
        SidebarRow(isSelected: true) {
            Label("Dashboard", systemImage: "square.grid.2x2")
        }
    }
}

private struct UnderlinedTabBarPreview: View {
    let items = ["Tab 1", "Tab 2", "Tab 3"]
    @State private var selection = "Tab 1"
    var body: some View {
        UnderlinedTabBar(items: self.items, selection: self.$selection, title: { $0 })
    }
}

// MARK: - ToastDemoButton

/// Subview to read `\.toastHost` inside the scope where `.toastHost(edge:)` is applied.
/// Referenced by `ComponentMeta.all` via `demoAction` closure.
private struct ToastDemoButton: View {
    @Environment(\.toastHost) private var toast

    var body: some View {
        Button("Show Demo Toast") {
            self.toast?.show("Toast message", level: .info)
        }
        .buttonStyle(.solid(role: .primary))
    }
}
