import SwiftUI
import CoreDesign

// MARK: - Snapshot Previews
// 每个组件至少一个 #Preview 宏，供 SnapshotTest 自动收编生成 PNG。
// 命名为简单组件名称即可——SnapshotPreviews 会自动追加 _Light / _Dark 变体后缀。

#Preview("Badge") {
    HStack(spacing: CoreSpacing.sm) {
        Badge("Info", variant: .info)
        Badge("Success", variant: .success)
        Badge("Warning", variant: .warning)
        Badge("Danger", variant: .danger)
        Badge("Neutral")
    }
    .padding()
}

#Preview("Tag") {
    HStack(spacing: CoreSpacing.sm) {
        Tag("bug", color: .red)
        Tag("enhancement", color: .blue)
        Tag("doc", color: .cyan, removable: true, onRemove: {})
    }
    .padding()
}

#Preview("Banner") {
    VStack(spacing: CoreSpacing.sm) {
        Banner(level: .info) { Text("Info message") }
        Banner(level: .success) { Text("Success message") }
        Banner(level: .warning) { Text("Warning message") }
        Banner(level: .danger) { Text("Danger message") }
    }
    .padding()
}

#Preview("Button") {
    VStack(spacing: CoreSpacing.sm) {
        Button("Solid Primary") {}.buttonStyle(.solid(role: .primary))
        Button("Light Secondary") {}.buttonStyle(.light(role: .secondary))
        Button("Borderless Danger") {}.buttonStyle(.borderless(role: .danger))
    }
    .padding()
}

#Preview("Form Icons") {
    HStack(spacing: CoreSpacing.md) {
        LabelIcon(systemName: "person.fill", backgroundColor: .blue)
        ChevronRightIcon()
        DangerIcon()
    }
    .padding()
}

#Preview("SegmentedControl") {
    SegmentedControl(items: ["One", "Two", "Three"], selection: .constant("One"), title: { $0 })
        .padding()
}

#Preview("SearchField") {
    SearchField(text: .constant("filter results"))
        .padding()
}

#Preview("Avatar") {
    HStack(spacing: CoreSpacing.md) {
        Avatar(name: "Evan")
        Avatar(name: "CoreDesign")
    }
    .padding()
}

#Preview("ListRow") {
    VStack(spacing: 0) {
        ListRow(label: { Text("Label only").foregroundStyle(Color.contentPrimary) })
        ListRow(
            leading: { Image(systemName: "doc.text").foregroundStyle(Color.contentMuted) },
            label: { Text("With icon + chevron").foregroundStyle(Color.contentPrimary) },
            trailing: { Image(systemName: "chevron.forward").foregroundStyle(Color.contentMuted) }
        )
    }
    .padding()
}

#Preview("Sidebar") {
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
    .padding()
    .background(Color.surfaceSidebar)
}

#Preview("UnderlinedTabBar") {
    UnderlinedTabBar(
        items: ["Tab 1", "Tab 2", "Tab 3"],
        selection: .constant("Tab 1"),
        title: { $0 }
    )
    .padding()
}

#Preview("Toast") {
    ToastSnapshotHarness()
        .toastHost(edge: .top)
}

/// Toast snapshot demo：按钮点击触发 toast 显示，初始状态展示场景脚手架。
private struct ToastSnapshotHarness: View {
    @Environment(\.toastHost) private var toast

    var body: some View {
        VStack(spacing: CoreSpacing.md) {
            Text("Tap button to show a toast.")
                .font(CoreTypography.Token.callout.font)
                .foregroundStyle(Color.contentMuted)
            Button("Info") { self.toast?.show("Info: demo", level: .info) }
            Button("Success") { self.toast?.show("Success: demo", level: .success) }
            Button("Warning") { self.toast?.show("Warning: demo", level: .warning) }
            Button("Danger") { self.toast?.show("Danger: demo", level: .danger) }
        }
        .padding(CoreSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.surfaceCanvas)
        .task { self.toast?.show("Toast snapshot", level: .info) }
    }
}

#Preview("BottomInputBar") {
    Text("BottomInputBar 通过 `.bottomInputBar` modifier 使用，非独立 View。")
        .font(CoreTypography.Token.footnote.font)
        .foregroundStyle(Color.contentMuted)
        .padding()
}

// MARK: - Three-in-one components

#Preview("ProgressIndicator") {
    VStack(spacing: CoreSpacing.md) {
        ProgressIndicator()
            .controlSize(.small)
        ProgressIndicator()
            .controlSize(.regular)
        ProgressIndicator()
            .controlSize(.large)
        // Issue #172 增强：可选文案 init，渲染于 spinner 下方。
        ProgressIndicator(text: "Loading…")
            .controlSize(.large)
    }
    .padding()
}

// ProgressBar 的快照 #Preview 已随弃用移除（0.6.0）——索引不再引用其图，
// 迁移期请看 "Core Control Styles" 预览的 .core ProgressView。

#Preview("StateLabel") {
    VStack(alignment: .leading, spacing: CoreSpacing.sm) {
        StateLabel(style: .active)
        StateLabel(style: .draft)
        StateLabel(style: .completed)
        StateLabel(style: .cancelled)
        StateLabel(style: .active, label: "In Progress")
    }
    .padding()
}

#Preview("AvatarGroup") {
    VStack(spacing: CoreSpacing.md) {
        AvatarGroup {
            Circle().fill(.blue).frame(width: 32, height: 32)
            Circle().fill(.green).frame(width: 32, height: 32)
            Circle().fill(.red).frame(width: 32, height: 32)
            Circle().fill(.orange).frame(width: 32, height: 32)
            Circle().fill(.purple).frame(width: 32, height: 32)
        }
        AvatarGroup(max: 2) {
            Circle().fill(.blue).frame(width: 24, height: 24)
            Circle().fill(.green).frame(width: 24, height: 24)
            Circle().fill(.red).frame(width: 24, height: 24)
        }
    }
    .padding()
}

#Preview("FlowLayout") {
    FlowLayout(spacing: CoreSpacing.xs) {
        ForEach(
            ["bug", "enhancement", "help wanted", "documentation", "good first issue", "dependencies"],
            id: \.self
        ) { label in
            Tag(label, color: .blue)
        }
    }
    .padding()
    .frame(width: 280)
}

#Preview("AsyncButton") {
    VStack(spacing: CoreSpacing.sm) {
        AsyncButton("Solid Primary") { }.buttonStyle(.solid(role: .primary))
        AsyncButton("Light Secondary") { }.buttonStyle(.light(role: .secondary))
        AsyncButton("Borderless Danger") { }.buttonStyle(.borderless(role: .danger))
        AsyncButton {
            // idle 态 snapshot,这里无需真的 sleep
        } label: {
            Image(systemName: "arrow.clockwise")
        }
        .buttonStyle(.circularGlass)
    }
    .padding()
}

// MARK: - Phase 2（0.4.0）

#Preview("Card") {
    VStack(spacing: CoreSpacing.md) {
        Card {
            VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                Text("Card 标题").coreFont(.headline)
                Text("卡片浮于画布之上").coreFont(.subheadline).foregroundStyle(Color.contentSecondary)
            }
        }
        Card(padding: CoreSpacing.md, alignment: .center) {
            Text("居中 + 紧凑内边距").coreFont(.subheadline)
        }
    }
    .padding()
    .background(Color.surfaceCanvas)
}

#Preview("Separator") {
    VStack(alignment: .leading, spacing: CoreSpacing.md) {
        Text("贯穿").coreFont(.footnote).foregroundStyle(Color.contentSecondary)
        Separator()
        Text("leading 缩进 58pt").coreFont(.footnote).foregroundStyle(Color.contentSecondary)
        Separator(inset: .leading(58))
    }
    .padding()
    .background(Color.surfaceCanvas)
}

#Preview("Section Header Footer") {
    VStack(alignment: .leading, spacing: CoreSpacing.sm) {
        SectionHeader("General")
        Card { Text("分组内容").coreFont(.body) }
        SectionFooter("Applies to all accounts on this device.")
    }
    .padding()
    .background(Color.surfaceCanvas)
}

#Preview("SettingsRow") {
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
            Toggle("Notifications", isOn: .constant(true)).labelsHidden()
        }
        .tint(.green)
    }
    .background(Color.surfaceCard)
    .clipShape(CoreShape.rounded(CoreRadius.medium))
    .padding()
    .background(Color.surfaceCanvas)
}

#Preview("InsetGroupedSection") {
    InsetGroupedSection(header: "Connectivity", footer: "Airplane Mode disables Wi-Fi and Bluetooth.") {
        SettingsRow(icon: .init(systemName: "airplane", background: .orange), title: "Airplane Mode") {
            Toggle("Airplane Mode", isOn: .constant(false)).labelsHidden()
        }
        SettingsRow(icon: .init(systemName: "wifi", background: .blue), title: "Wi-Fi") {
            Text("HomeNetwork").foregroundStyle(Color.contentSecondary)
            SettingsRowChevron()
        }
    }
    .tint(.green)
    .padding()
    .background(Color.surfaceCanvas)
}

#Preview("Core Control Styles") {
    VStack(alignment: .leading, spacing: CoreSpacing.xl) {
        ProgressView(value: 0.6, label: { Text("Downloading") }, currentValueLabel: { Text("60%") })
            .progressViewStyle(.core)
            .tint(.red)
        Label("Sync", systemImage: "arrow.triangle.2.circlepath").labelStyle(.core).tint(.blue)
        DisclosureGroup("Details", isExpanded: .constant(true)) {
            Text("Additional information goes here.").foregroundStyle(Color.contentSecondary)
        }
        .disclosureGroupStyle(.core)
        .tint(.red)
    }
    .padding()
    .background(Color.surfaceCanvas)
}

// MARK: - Phase 3（semi-mobile-components epic，0.7.0）

#Preview("Skeleton") {
    SkeletonPreviewsPreviewGallery()
        .padding()
        .background(Color.surfaceCanvas)
}

private struct SkeletonPreviewsPreviewGallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.md) {
            HStack(alignment: .top, spacing: CoreSpacing.md) {
                SkeletonCircle(diameter: 40)
                SkeletonLine(lineCount: 2)
            }
            SkeletonRect(height: 100)
        }
    }
}

#Preview("Steps") {
    VStack(alignment: .leading, spacing: CoreSpacing.lg) {
        Steps(
            items: [
                StepItem(title: "Cart", description: "Review items"),
                StepItem(title: "Shipping", description: "Add address"),
                StepItem(title: "Payment", description: "Enter card details"),
                StepItem(title: "Confirm", description: "Review & place order"),
            ],
            currentIndex: 1,
            axis: .horizontal,
            indicatorStyle: .dot
        )
        Steps(
            items: [
                StepItem(title: "Cart"),
                StepItem(title: "Shipping"),
                StepItem(title: "Payment"),
                StepItem(title: "Confirm"),
            ],
            currentIndex: 2,
            axis: .vertical,
            indicatorStyle: .numbered
        )
    }
    .padding()
    .background(Color.surfaceCanvas)
}

#Preview("Timeline") {
    Timeline(items: [
        TimelineItem(status: .success) {
            Text("审核通过").coreFont(.callout)
        },
        TimelineItem(status: .warning) {
            Text("即将过期提醒").coreFont(.callout)
        },
        TimelineItem(status: .danger) {
            Text("处理失败").coreFont(.callout)
        },
    ])
    .padding()
    .background(Color.surfaceCanvas)
}

#Preview("Rating") {
    VStack(alignment: .leading, spacing: CoreSpacing.lg) {
        Rating(value: .constant(3))
        Rating(value: .constant(2.5), step: 0.5)
        Rating(value: .constant(3), step: 0.5)
            .disabled(true)
    }
    .padding()
    .background(Color.surfaceCanvas)
}

#Preview("RatingDisplay") {
    VStack(alignment: .leading, spacing: CoreSpacing.lg) {
        RatingDisplay(value: 4)
        RatingDisplay(value: 3.5)
        RatingDisplay(value: 7, count: 10)
    }
    .padding()
    .background(Color.surfaceCanvas)
}

#Preview("PinCode") {
    VStack(alignment: .leading, spacing: CoreSpacing.lg) {
        PinCode(value: .constant("123"), length: 6)
        PinCode(value: .constant("42"), length: 4, isSecure: true)
    }
    .padding()
    .background(Color.surfaceCanvas)
}

#Preview("Radio Group") {
    VStack(alignment: .leading, spacing: CoreSpacing.lg) {
        RadioGroup(
            selection: .constant("pro"),
            options: [
                RadioOption(value: "basic", title: "Basic"),
                RadioOption(value: "pro", title: "Pro"),
                RadioOption(value: "enterprise", title: "Enterprise"),
            ]
        )
        RadioGroup(
            selection: .constant(2),
            options: [
                RadioOption(value: 1, title: "S"),
                RadioOption(value: 2, title: "M"),
                RadioOption(value: 3, title: "L"),
            ],
            axis: .horizontal
        )
    }
    .padding()
    .background(Color.surfaceCanvas)
}

#Preview("TagInput") {
    // tagColor: .blue——见 ComponentData.swift 的 TagInputPreview 同款注释：默认
    // .contentSecondary 经 Tag 的 .opacity(0.12) 背景公式在暗色画布上对比度过低。
    TagInput(
        tags: .constant(["bug", "enhancement", "help wanted"]),
        placeholder: "Add tag",
        tagColor: .blue
    )
    .padding()
    .frame(width: 320)
    .background(Color.surfaceCanvas)
}

#Preview("Descriptions") {
    Descriptions(header: "Order") {
        LabeledContent("Status") { Text("Active") }
        LabeledContent("Total") { Text("$42.00") }
        LabeledContent("Placed") { Text("2026-07-20") }
    }
    .padding()
    .background(Color.surfaceCanvas)
}

#Preview("Float Button") {
    // 有界画布：FAB 需要深色背景才能看清玻璃质感，但不应像早期版本那样用
    // `.ignoresSafeArea()` 铺满整屏——那会让快照按设备全屏尺寸渲染，PNG 压缩率
    // 极差（4.6MB vs 其它组件的几百 KB）。改为固定尺寸卡片 + clipShape，与
    // ComponentData.swift 里 app 内 FloatButtonPreview 的有界卡片形态一致；
    // 背景改纯色（而非渐变）——平滑渐变本身也是 PNG 压缩率差的主因，纯色块
    // 几乎无损压缩，同时仍能反衬出玻璃按钮的通透质感。
    ZStack {
        Color.indigo

        VStack(spacing: CoreSpacing.xl) {
            Button {} label: {
                Label("New", systemImage: "plus")
            }
            .buttonStyle(.extendedFloat)
            .foregroundStyle(.white)

            Button {} label: {
                Image(systemName: "paperplane")
                    .font(.system(size: CoreControlMetrics.iconSize(for: .regular), weight: .semibold))
            }
            .buttonStyle(.circularGlass)
            .foregroundStyle(.white)
        }
        .padding(CoreSpacing.xxxl)
    }
    .frame(width: 320, height: 280)
    .clipShape(CoreShape.rounded(CoreRadius.large))
    .padding()
    .background(Color.surfaceCanvas)
}

#Preview("Carousel") {
    CarouselPreviewsPreviewGallery()
        .frame(height: 160)
        .padding()
        .background(Color.surfaceCanvas)
}

private struct CarouselPreviewsPreviewGalleryItem: Identifiable {
    let id: Int
    let title: String
    let color: Color
}

private struct CarouselPreviewsPreviewGallery: View {
    private let cards: [CarouselPreviewsPreviewGalleryItem] = [
        CarouselPreviewsPreviewGalleryItem(id: 0, title: "第一页", color: .blue),
        CarouselPreviewsPreviewGalleryItem(id: 1, title: "第二页", color: .purple),
        CarouselPreviewsPreviewGalleryItem(id: 2, title: "第三页", color: .orange),
    ]

    var body: some View {
        Carousel(self.cards, autoAdvance: false) { item in
            CoreShape.rounded(CoreRadius.large)
                .fill(item.color.gradient)
                .overlay {
                    Text(item.title)
                        .coreFont(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, CoreSpacing.xs)
        }
    }
}

#Preview("Spinning") {
    VStack(spacing: CoreSpacing.lg) {
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
    .padding()
    .background(Color.surfaceCanvas)
}
