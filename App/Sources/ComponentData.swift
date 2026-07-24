import SwiftUI
import CoreDesign

// MARK: - ComponentCategory

enum ComponentCategory: String, CaseIterable, Identifiable {
    case button = "Button"
    case form = "Form"
    case indicator = "Indicator"
    case layout = "Layout"
    case container = "Container"
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
        ComponentMeta(id: "list-row", name: "ListRow", description: "3-槽位泛型列表行：leading / label / trailing", category: .layout) {
            ListRowPreview()
        },

        // Container（Phase 2）
        ComponentMeta(id: "settings-screen", name: "Settings Screen", description: "SC#10：仅用 CoreDesign 复刻一屏 iOS 设置页（InsetGroupedSection + SettingsRow）", category: .container) {
            SettingsScreenDemo()
        },
        ComponentMeta(id: "inset-grouped-section", name: "InsetGroupedSection", description: "iOS .insetGrouped 分组容器 + 自动分隔线 inset + 页眉页脚", category: .container) {
            InsetGroupedSectionPreview()
        },
        ComponentMeta(id: "settings-row", name: "SettingsRow", description: "设置行：图标方块 + 标题 + 副标题 + accessory（value / chevron / Toggle / 自定义）", category: .container) {
            SettingsRowPreview()
        },
        ComponentMeta(id: "settings-row-in-list", name: "SettingsRow in List", description: "AC9：SettingsRow 直接作原生 List 行 + .listRowInsets(EdgeInsets()) 消双重 inset", category: .container) {
            SettingsRowInListDemo()
        },
        ComponentMeta(id: "card", name: "Card", description: ".surface(.content) 具名封装 + 默认内边距，浮于画布之上", category: .container) {
            CardPreview()
        },
        ComponentMeta(id: "separator", name: "Separator", description: "可控 leading inset 的 hairline 分隔线，走 dividerDefault 系统色", category: .container) {
            SeparatorPreview()
        },
        ComponentMeta(id: "section-header-footer", name: "Section Header / Footer", description: "iOS 分组页眉（大写 footnote 灰）/ 页脚说明", category: .container) {
            SectionHeaderFooterPreview()
        },

        // Form（Phase 2 .core style）
        ComponentMeta(id: "core-progressview", name: ".core ProgressView", description: "系统 ProgressView 的 .core style，填充走 .tint", category: .form) {
            CoreProgressViewPreview()
        },
        ComponentMeta(id: "core-label", name: ".core Label", description: "系统 Label 的 .core style，icon 走 .tint", category: .form) {
            CoreLabelPreview()
        },
        ComponentMeta(id: "core-disclosuregroup", name: ".core DisclosureGroup", description: "系统 DisclosureGroup 的 .core style，chevron 走 .tint + leading 缩进", category: .form) {
            CoreDisclosureGroupPreview()
        },

        // Navigation
        ComponentMeta(id: "sidebar", name: "Sidebar", description: "侧栏导航组件组：section / navigation / utility / document / tag row", category: .navigation) {
            SidebarPreview()
        },
        ComponentMeta(id: "underlined-tab-bar", name: "UnderlinedTabBar", description: "下划线式 TabBar，token 化配色 + 选中态指示器", category: .navigation) {
            UnderlinedTabBarPreview()
        },

        // Feedback
        ComponentMeta(id: "toast", name: "Toast", description: "Scene-scoped toast host + 队列状态机", category: .feedback, preview: {
            Text("Toast 通过 `.toastHost(edge:)` modifier 挂载到 WindowGroup 根级别")
                .font(CoreTypography.Token.footnote.font)
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
            .font(CoreTypography.Token.footnote.font)
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

private struct ListRowPreview: View {
    var body: some View {
        VStack(spacing: 0) {
            ListRow(label: { Text("Full row").foregroundStyle(Color.contentPrimary) })
            ListRow(
                leading: { Image(systemName: "doc.text").foregroundStyle(Color.contentMuted) },
                label: { Text("With icon").foregroundStyle(Color.contentPrimary) },
                trailing: { Image(systemName: "chevron.forward").foregroundStyle(Color.contentMuted) }
            )
        }
    }
}

private struct SidebarPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.md) {
            SidebarSection(title: "Core", showsChevron: false) {
                SidebarNavigationRow(systemImage: "calendar", title: "Today", isSelected: true) {}
                SidebarNavigationRow(systemImage: "tray.full", title: "Inbox", isSelected: false) {}
            }

            SidebarSection(title: "Library") {
                SidebarDocumentRow(systemImage: "doc.text", title: "Exam Sprint", detail: "47 days") {}
                SidebarTagRow(title: "Math") {}
            }

            SidebarSection(title: "Tools", showsChevron: false) {
                SidebarUtilityRow(systemImage: "gearshape", title: "Settings") {}
                SidebarUtilityRow(systemImage: "trash", title: "Trash", trailingSystemImage: "arrow.up.right") {}
            }

            SidebarStatusFooter(title: "Synced", detail: "Updated just now")
        }
        .background(Color.surfaceSidebar)
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

// MARK: - Phase 2 Container Previews

private struct CardPreview: View {
    var body: some View {
        VStack(spacing: CoreSpacing.md) {
            Card {
                VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                    Text("Card 标题").coreFont(.headline)
                    Text("卡片浮于画布之上，深浅双模式都与背景拉开。")
                        .coreFont(.subheadline)
                        .foregroundStyle(Color.contentSecondary)
                }
            }
            Card(padding: CoreSpacing.md, alignment: .center) {
                Text("居中 + 紧凑内边距").coreFont(.subheadline)
            }
        }
    }
}

private struct SeparatorPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.md) {
            Text("贯穿").coreFont(.footnote).foregroundStyle(Color.contentSecondary)
            Separator()
            Text("leading 缩进（58pt，对齐设置行标题）").coreFont(.footnote).foregroundStyle(Color.contentSecondary)
            Separator(inset: .leading(58))
        }
    }
}

private struct SectionHeaderFooterPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.sm) {
            SectionHeader("General")
            Card { Text("分组内容").coreFont(.body) }
            SectionFooter("Applies to all accounts on this device.")
        }
    }
}

private struct SettingsRowPreview: View {
    @State private var on = true
    var body: some View {
        VStack(spacing: 0) {
            SettingsRow(
                icon: .init(systemName: "wifi", background: .blue),
                title: Text("Wi-Fi"),
                subtitle: Text("HomeNetwork")
            ) {
                Text("On").foregroundStyle(Color.contentSecondary)
                SettingsRowChevron()
            }
            Separator(inset: .leading(58))
            SettingsRow(
                icon: .init(systemName: "bell.badge.fill", background: .red),
                title: Text("Notifications")
            ) {
                Toggle("Notifications", isOn: self.$on).labelsHidden()
            }
            .tint(.green)
        }
        .background(Color.surfaceCard)
        .clipShape(CoreShape.rounded(CoreRadius.medium))
    }
}

private struct InsetGroupedSectionPreview: View {
    @State private var airplane = false
    var body: some View {
        InsetGroupedSection(header: "Connectivity", footer: "Airplane Mode disables Wi-Fi and Bluetooth.") {
            SettingsRow(icon: .init(systemName: "airplane", background: .orange), title: Text("Airplane Mode")) {
                Toggle("Airplane Mode", isOn: self.$airplane).labelsHidden()
            }
            SettingsRow(icon: .init(systemName: "wifi", background: .blue), title: Text("Wi-Fi")) {
                Text("HomeNetwork").foregroundStyle(Color.contentSecondary)
                SettingsRowChevron()
            }
        }
        .tint(.green)
    }
}

private struct CoreProgressViewPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.lg) {
            ProgressView(value: 0.6, label: { Text("Downloading") }, currentValueLabel: { Text("60%") })
                .progressViewStyle(.core)
            ProgressView(value: 0.6)
                .progressViewStyle(.core)
                .tint(.red)
        }
    }
}

private struct CoreLabelPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.md) {
            Label("Sync", systemImage: "arrow.triangle.2.circlepath").labelStyle(.core)
            Label("Delete", systemImage: "trash.fill").labelStyle(.core).tint(.red)
        }
    }
}

private struct CoreDisclosureGroupPreview: View {
    @State private var expanded = true
    var body: some View {
        DisclosureGroup("Details", isExpanded: self.$expanded) {
            Text("Additional information goes here.").foregroundStyle(Color.contentSecondary)
        }
        .disclosureGroupStyle(.core)
        .tint(.red)
    }
}

// MARK: - SettingsRow in native List（AC9 验证）

/// SettingsRow 直接作原生 List 的行,配 .listRowInsets(EdgeInsets()) 清零 List 侧
/// inset,由 SettingsRow 独占 16pt 内边距——验证无双重 inset。
private struct SettingsRowInListDemo: View {
    @State private var on = true
    var body: some View {
        List {
            SettingsRow(icon: .init(systemName: "wifi", background: .blue), title: Text("Wi-Fi")) {
                Text("HomeNetwork").foregroundStyle(Color.contentSecondary)
                SettingsRowChevron()
            }
            .listRowInsets(EdgeInsets())
            SettingsRow(icon: .init(systemName: "bell.badge.fill", background: .red), title: Text("Notifications")) {
                Toggle("Notifications", isOn: self.$on).labelsHidden()
            }
            .listRowInsets(EdgeInsets())
            .tint(.green)
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Settings Screen Demo（Success Criteria #10）

/// 仅用 CoreDesign 组件复刻一屏 iOS 设置页——不写任何 CoreDesign 之外的样式代码。
private struct SettingsScreenDemo: View {
    @State private var airplane = false
    @State private var wifiOn = true
    @State private var bluetoothOn = true
    @State private var notificationsOn = true

    var body: some View {
        ScrollView {
            VStack(spacing: CoreSpacing.xl) {
                InsetGroupedSection {
                    SettingsRow(icon: .init(systemName: "airplane", background: .orange), title: Text("Airplane Mode")) {
                        Toggle("Airplane Mode", isOn: self.$airplane).labelsHidden()
                    }
                    SettingsRow(icon: .init(systemName: "wifi", background: .blue), title: Text("Wi-Fi")) {
                        Text("HomeNetwork").foregroundStyle(Color.contentSecondary)
                        SettingsRowChevron()
                    }
                    SettingsRow(icon: .init(systemName: "personalhotspot", background: .green), title: Text("Personal Hotspot")) {
                        Text("Off").foregroundStyle(Color.contentSecondary)
                        SettingsRowChevron()
                    }
                }

                InsetGroupedSection(header: "Notifications", footer: "Choose how you receive alerts from apps.") {
                    SettingsRow(icon: .init(systemName: "bell.badge.fill", background: .red), title: Text("Notifications")) {
                        Toggle("Notifications", isOn: self.$notificationsOn).labelsHidden()
                    }
                    SettingsRow(icon: .init(systemName: "speaker.wave.2.fill", background: .pink), title: Text("Sounds & Haptics")) {
                        SettingsRowChevron()
                    }
                    SettingsRow(icon: .init(systemName: "moon.fill", background: .indigo), title: Text("Focus"), subtitle: Text("Do Not Disturb")) {
                        SettingsRowChevron()
                    }
                }
                .tint(.green)

                InsetGroupedSection(header: "About", dividerInset: .textAligned) {
                    SettingsRow(title: Text("Version")) {
                        Text("0.4.0").foregroundStyle(Color.contentSecondary)
                    }
                    SettingsRow(title: Text("Legal")) {
                        SettingsRowChevron()
                    }
                }
            }
            .padding()
        }
        .background(Color.surfaceCanvas)
    }
}
