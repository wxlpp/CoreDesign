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
        Button("Solid Primary") {}.buttonStyle(.solidButton(role: .primary))
        Button("Light Secondary") {}.buttonStyle(.lightButton(role: .secondary))
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

#Preview("BookCover") {
    BookCover(data: nil, title: "CoreDesign")
        .padding()
}

#Preview("EmptyState") {
    EmptyState(systemName: "magnifyingglass", title: "No results", description: "Try adjusting your search or filters.")
        .padding()
}

#Preview("ListRow") {
    VStack(spacing: 0) {
        ListRow(label: { Text("Label only").foregroundStyle(Color.contentPrimary) })
        ListRow(
            leading: { Image(systemName: "doc.text").foregroundStyle(Color.contentMuted) },
            label: { Text("With icon + chevron").foregroundStyle(Color.contentPrimary) },
            trailing: { Image(systemName: "chevron.right").foregroundStyle(Color.contentMuted) }
        )
    }
    .padding()
}

#Preview("SidebarRow") {
    SidebarRow(isSelected: true) {
        Label("Dashboard", systemImage: "square.grid.2x2")
    }
    .padding()
}

#Preview("UnderlinedTabBar") {
    UnderlinedTabBar(
        items: ["Tab 1", "Tab 2", "Tab 3"],
        selection: .constant("Tab 1"),
        title: { $0 }
    )
    .padding()
}

#Preview("BottomInputBar") {
    Text("BottomInputBar 通过 `.bottomInputBar` modifier 使用，非独立 View。")
        .font(CoreTypography.bodySmallFont)
        .foregroundStyle(Color.contentMuted)
        .padding()
}
