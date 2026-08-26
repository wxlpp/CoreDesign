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
        ComponentMeta(id: "float-button", name: "FloatButton", description: "悬浮按钮：ExtendedFloatButtonStyle 胶囊玻璃 + CircularGlassButtonStyle 圆形玻璃", category: .button) {
            FloatButtonPreview()
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
        ComponentMeta(id: "rating", name: "Rating", description: "Binding<Double> 驱动的星级评分控件，step 参数控制步进粒度", category: .form) {
            RatingPreview()
        },
        ComponentMeta(id: "rating-display", name: "RatingDisplay", description: "只读评分展示（indicator）——无手势、不走原生 disabled 变灰", category: .form) {
            RatingDisplayPreview()
        },
        ComponentMeta(id: "pin-code", name: "PinCode", description: "验证码 / PIN 分格输入，隐藏 TextField 承接系统键盘 + iOS 单条码 OTP 自动填充", category: .form) {
            PinCodePreview()
        },
        ComponentMeta(id: "radio-group", name: "RadioGroup", description: "互斥单选组，与 CheckBox 成对的视觉语汇", category: .form) {
            RadioGroupPreview()
        },
        ComponentMeta(id: "tag-input", name: "TagInput", description: "标签输入框：Tag chip + 内联 TextField，回车/逗号提交", category: .form) {
            TagInputPreview()
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
        ComponentMeta(id: "progress-indicator", name: "ProgressIndicator", description: "通用圆形加载指示器，可选文案渲染于 spinner 下方", category: .indicator) {
            ProgressIndicatorGalleryPreview()
        },
        ComponentMeta(id: "skeleton", name: "Skeleton", description: "骨架屏容器：SkeletonLine / SkeletonRect / SkeletonCircle 占位形状 + shimmer 扫光", category: .indicator) {
            SkeletonPreview()
        },
        ComponentMeta(id: "steps", name: "Steps", description: "步骤条：4 种呈现（steps / segmentedBar / navigation / text）× 点状 / 数字指示器", category: .indicator) {
            StepsPreview()
        },
        ComponentMeta(id: "timeline", name: "Timeline", description: "时间线：4 种排布（vertical / alternate / horizontal / grouped），节点 + 连线 + 内容", category: .indicator) {
            TimelinePreview()
        },

        // Layout
        ComponentMeta(id: "avatar", name: "Avatar", description: "头像组件，按名称首字母生成", category: .layout) {
            AvatarPreview()
        },
        ComponentMeta(id: "list-row", name: "ListRow", description: "3-槽位泛型列表行：leading / label / trailing", category: .layout) {
            ListRowPreview()
        },
        ComponentMeta(id: "carousel", name: "Carousel", description: "走马灯：ScrollView 分页滚动 + 自动轮播 + 页点指示器", category: .layout) {
            CarouselPreview()
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
        ComponentMeta(id: "descriptions", name: "Descriptions", description: "描述列表：.core LabeledContentStyle + InsetGroupedSection，1/2 列 + 大字号自动塌列", category: .container) {
            DescriptionsPreview()
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
        ComponentMeta(id: "spinning", name: "Spinning", description: "View.spinning(_:text:presentation:)：overlay 遮罩（阻塞）/ topBar / inline（非阻塞）", category: .feedback) {
            SpinningPreview()
        },
        ComponentMeta(id: "spinning-nonblocking", name: "Spinning · 非阻塞", description: "topBar 顶条 / inline 行内：不铺遮罩、不禁用交互", category: .feedback) {
            SpinningNonBlockingPreview()
        },
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
                // `#64` 形态 D2：`.textOnly` 拆掉 leading 槽；候选 2 = 本 case + 既有尾图标参数。
                // ⚠️ `.textOnly` 下 systemImage 不渲染 ⇒ 约定统一写 ""（见 docs/components/sidebar.md）。
                // 该约定**不承重**：`SidebarLeadingSlotRenderTests.textOnlyIgnoresSystemImage`
                // 以位图证明取任何值渲染都相同，写 "" 只是卫生。
                SidebarUtilityRow(systemImage: "", title: "Archive", presentation: .textOnly) {}
                SidebarUtilityRow(systemImage: "", title: "Settings", trailingSystemImage: "chevron.forward", presentation: .textOnly) {}
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
                title: "Wi-Fi",
                subtitle: "HomeNetwork"
            ) {
                Text("On").foregroundStyle(Color.contentSecondary)
                SettingsRowChevron()
            }
            Separator(inset: .leading(58))
            SettingsRow(
                icon: .init(systemName: "bell.badge.fill", background: .red),
                title: "Notifications"
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
            SettingsRow(icon: .init(systemName: "airplane", background: .orange), title: "Airplane Mode") {
                Toggle("Airplane Mode", isOn: self.$airplane).labelsHidden()
            }
            SettingsRow(icon: .init(systemName: "wifi", background: .blue), title: "Wi-Fi") {
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
            SettingsRow(icon: .init(systemName: "wifi", background: .blue), title: "Wi-Fi") {
                Text("HomeNetwork").foregroundStyle(Color.contentSecondary)
                SettingsRowChevron()
            }
            .listRowInsets(EdgeInsets())
            SettingsRow(icon: .init(systemName: "bell.badge.fill", background: .red), title: "Notifications") {
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
                    SettingsRow(icon: .init(systemName: "airplane", background: .orange), title: "Airplane Mode") {
                        Toggle("Airplane Mode", isOn: self.$airplane).labelsHidden()
                    }
                    SettingsRow(icon: .init(systemName: "wifi", background: .blue), title: "Wi-Fi") {
                        Text("HomeNetwork").foregroundStyle(Color.contentSecondary)
                        SettingsRowChevron()
                    }
                    SettingsRow(icon: .init(systemName: "personalhotspot", background: .green), title: "Personal Hotspot") {
                        Text("Off").foregroundStyle(Color.contentSecondary)
                        SettingsRowChevron()
                    }
                }

                InsetGroupedSection(header: "Notifications", footer: "Choose how you receive alerts from apps.") {
                    SettingsRow(icon: .init(systemName: "bell.badge.fill", background: .red), title: "Notifications") {
                        Toggle("Notifications", isOn: self.$notificationsOn).labelsHidden()
                    }
                    SettingsRow(icon: .init(systemName: "speaker.wave.2.fill", background: .pink), title: "Sounds & Haptics") {
                        SettingsRowChevron()
                    }
                    SettingsRow(icon: .init(systemName: "moon.fill", background: .indigo), title: "Focus", subtitle: "Do Not Disturb") {
                        SettingsRowChevron()
                    }
                }
                .tint(.green)

                InsetGroupedSection(header: "About", dividerInset: .textAligned) {
                    SettingsRow(title: "Version") {
                        Text("0.4.0").foregroundStyle(Color.contentSecondary)
                    }
                    SettingsRow(title: "Legal") {
                        SettingsRowChevron()
                    }
                }
            }
            .padding()
        }
        .background(Color.surfaceCanvas)
    }
}

// MARK: - Phase 3 Previews（semi-mobile-components epic，0.7.0）

private struct FloatButtonPreview: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [.indigo, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                .clipShape(CoreShape.rounded(CoreRadius.medium))

            HStack(spacing: CoreSpacing.lg) {
                Button {} label: {
                    Label("New", systemImage: "plus")
                }
                .buttonStyle(.extendedFloat(size: .regular))
                .foregroundStyle(.white)

                Button {} label: {
                    Image(systemName: "paperplane")
                        .font(.system(size: CoreControlMetrics.iconSize(for: .regular), weight: .semibold))
                }
                .buttonStyle(.circularGlass(size: .regular))
                .foregroundStyle(.white)
            }
            .padding(CoreSpacing.xl)
        }
    }
}

private struct RatingPreview: View {
    @State private var value: Double = 3.5
    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.sm) {
            Rating(value: self.$value, step: 0.5)
            Rating(value: .constant(4))
                .disabled(true)
        }
    }
}

private struct RatingDisplayPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.sm) {
            RatingDisplay(value: 4)
            RatingDisplay(value: 3.5)
        }
    }
}

private struct PinCodePreview: View {
    @State private var code = "12"
    var body: some View {
        PinCode(value: self.$code, length: 6)
    }
}

private struct RadioGroupPreview: View {
    @State private var selection = "pro"
    var body: some View {
        RadioGroup(
            selection: self.$selection,
            options: [
                RadioOption(value: "basic", title: "Basic"),
                RadioOption(value: "pro", title: "Pro"),
                RadioOption(value: "enterprise", title: "Enterprise"),
            ]
        )
    }
}

private struct TagInputPreview: View {
    @State private var tags: [String] = ["bug", "enhancement"]
    var body: some View {
        // Phase 3 / #173 视觉复查发现：默认 tagColor（.contentSecondary）经 Tag 的
        // `.opacity(0.12)` 背景公式，在暗色纯黑画布上对比度接近不可辨——这是 Tag 既有
        // 公式对中性色的固有表现，不是本次改动引入的缺陷（组件默认值本身不在本任务改动
        // 范围内）。画廊演示改用更有辨识度的 .blue，让暗色变体清晰可读；调用方仍可自由
        // 传入任意颜色，含中性色。
        TagInput(tags: self.$tags, placeholder: "Add tag", tagColor: .blue)
    }
}

private struct ProgressIndicatorGalleryPreview: View {
    var body: some View {
        VStack(spacing: CoreSpacing.md) {
            ProgressIndicator()
                .controlSize(.regular)
            ProgressIndicator(text: "Loading…")
                .controlSize(.large)
        }
    }
}

private struct SkeletonPreview: View {
    @State private var isLoading = true
    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.md) {
            Toggle(isOn: self.$isLoading) { Text("isLoading") }
                .tint(Color.accent)
            Skeleton(isLoading: self.isLoading) {
                HStack(alignment: .top, spacing: CoreSpacing.md) {
                    SkeletonCircle(diameter: 40)
                    SkeletonLine(lineCount: 2)
                }
            } content: {
                HStack(alignment: .top, spacing: CoreSpacing.md) {
                    Circle().fill(Color.accent).frame(width: 40, height: 40)
                    VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                        Text("王晓龙").coreFont(.subheadline)
                        Text("CoreDesign 维护者").coreFont(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct StepsPreview: View {
    static let items: [StepItem] = [
        StepItem(title: "Cart"),
        StepItem(title: "Shipping"),
        StepItem(title: "Payment"),
        StepItem(title: "Confirm"),
    ]
    // ⚠️ 设备端画廊是 `#Preview` 之外的**第二条**视觉通路，且是唯一跑在真机 / 模拟器上的
    // 那条（`swift test` 与 CI 都不构建 App/）。`#60` 新增的呈现必须在这里出现，否则它们在
    // 真机上零覆盖（PR #206 第 2 轮 review 抓到）。
    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.lg) {
            Steps(items: Self.items, currentIndex: 1, axis: .horizontal, indicatorStyle: .numbered)
            Steps(items: Self.items, currentIndex: 2, presentation: .segmentedBar)
            Steps(items: Self.items, currentIndex: 1, presentation: .navigation)
            Steps(items: Self.items, currentIndex: 1, presentation: .text)
        }
    }
}

private struct TimelinePreview: View {
    private static var items: [TimelineItem] {
        [
            TimelineItem(status: .success) { Text("审核通过").coreFont(.callout) },
            TimelineItem(status: .warning) { Text("即将过期提醒").coreFont(.callout) },
            TimelineItem(status: .danger) { Text("处理失败").coreFont(.callout) },
        ]
    }

    // ⚠️ `.alternate` 与 `.horizontal` 的几何**只在渲染时可见**，`swift build` / `swift test`
    // 一定绿 —— 这条通路是它们在真机上唯一的检查点（PR #206 第 2 轮 review 抓到）。
    // `.alternate` 那条特意混入一个**宽内容**（固定 220pt），因为「节点恒在同一条中轴」
    // 恰恰是在内容固有宽度超过半槽时才会破。
    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.lg) {
            Timeline(items: Self.items)
            Timeline(
                items: [
                    TimelineItem(status: .info) {
                        Color.statusAccentEmphasis.frame(width: 220, height: 32)
                    },
                    TimelineItem(status: .success) { Text("短").coreFont(.callout) },
                    TimelineItem(status: .warning) { Text("再一条").coreFont(.callout) },
                ],
                layout: .alternate
            )
            Timeline(items: Self.items, layout: .horizontal)
            Timeline(items: Self.items, layout: .grouped)
        }
    }
}

private struct CarouselPreviewItem: Identifiable {
    let id: Int
    let title: String
    let color: Color
}

private struct CarouselPreview: View {
    private let cards: [CarouselPreviewItem] = [
        CarouselPreviewItem(id: 0, title: "第一页", color: .blue),
        CarouselPreviewItem(id: 1, title: "第二页", color: .purple),
        CarouselPreviewItem(id: 2, title: "第三页", color: .orange),
    ]
    var body: some View {
        Carousel(self.cards, autoAdvance: false) { item in
            CoreShape.rounded(CoreRadius.large)
                .fill(item.color.gradient)
                .overlay {
                    Text(item.title).coreFont(.subheadline).fontWeight(.semibold).foregroundStyle(.white)
                }
        }
        .frame(height: 120)
    }
}

private struct DescriptionsPreview: View {
    var body: some View {
        Descriptions(header: "Order") {
            LabeledContent("Status") { Text("Active") }
            LabeledContent("Total") { Text("$42.00") }
            LabeledContent("Placed") { Text("2026-07-20") }
        }
    }
}

private struct SpinningPreview: View {
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                Text("卡片标题").coreFont(.headline)
                Text("被 spinning 遮罩覆盖时应保持自身尺寸不变。")
                    .coreFont(.subheadline)
                    .foregroundStyle(Color.contentSecondary)
            }
        }
        .spinning(true, text: "Refreshing…")
    }
}

private struct SpinningNonBlockingPreview: View {
    // ⚠️ `.topBar` 的扫条动画与 `.inline` 的几何只在渲染时可见（PR #206 第 2 轮 review）。
    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.lg) {
            Card {
                Text("topBar：顶边细条，内容不被遮罩、仍可交互").coreFont(.subheadline)
            }
            .spinning(true, presentation: .topBar)

            HStack(spacing: CoreSpacing.lg) {
                Text("保存中").coreFont(.callout).spinning(true, presentation: .inline)
                Text("已保存").coreFont(.callout).spinning(false, presentation: .inline)
            }
        }
    }
}
