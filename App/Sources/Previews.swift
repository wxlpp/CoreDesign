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

#Preview("BookCover") {
    BookCover(data: nil, title: "CoreDesign")
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
                .font(CoreTypography.bodyMediumFont)
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
        .font(CoreTypography.bodySmallFont)
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
    }
    .padding()
}

#Preview("ProgressBar") {
    VStack(spacing: CoreSpacing.md) {
        ProgressBar(value: 0.0)
        ProgressBar(value: 0.5, label: "50%")
        ProgressBar(value: 1.0, tint: .statusSuccessEmphasis, label: "Done")
    }
    .padding()
}

#Preview("StateLabel") {
    VStack(alignment: .leading, spacing: CoreSpacing.sm) {
        StateLabel(.active)
        StateLabel(.draft)
        StateLabel(.completed)
        StateLabel(.cancelled)
        StateLabel(.active, label: "In Progress")
    }
    .padding()
}

#Preview("RefPill") {
    VStack(alignment: .leading, spacing: CoreSpacing.sm) {
        RefPill("main")
        RefPill(base: "main", head: "feat/foo")
        RefPill("a1b2c3d4e5f6")
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

#Preview("TimelineItem") {
    VStack(alignment: .leading, spacing: 0) {
        TimelineItem(icon: {
            Circle().fill(Color.statusAccentEmphasis).frame(width: 32, height: 32)
                .overlay(Image(systemName: "plus").foregroundStyle(.white).font(.caption))
        }, showsTopConnector: false) {
            VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                Text("evan opened this pull request").font(CoreTypography.bodyMediumFont)
                Text("3 days ago").font(CoreTypography.bodySmallFont).foregroundStyle(.secondary)
                TimelineItem(icon: {
                    Circle().fill(Color.statusDoneEmphasis).frame(width: 20, height: 20)
                        .overlay(Image(systemName: "checkmark").foregroundStyle(.white).font(.caption2))
                }, isLast: true) {
                    Text("CI passed").font(CoreTypography.bodySmallFont)
                }
            }
        }
        TimelineItem(icon: {
            Circle().fill(Color.statusSuccessEmphasis).frame(width: 32, height: 32)
                .overlay(Image(systemName: "checkmark").foregroundStyle(.white).font(.caption))
        }, isLast: true) {
            Text("merged 1 hour ago").font(CoreTypography.bodyMediumFont)
        }
    }
    .padding()
}

#Preview("EventRow") {
    VStack(alignment: .leading, spacing: CoreSpacing.sm) {
        EventRow(actor: "renovate", action: "added the", timeAgo: "2 days ago") {
            Tag("dependencies", color: .blue)
        }
        EventRow(actor: "renovate", action: "force-pushed from", timeAgo: "2 days ago") {
            RefPill("4d2040c")
        }
        EventRow(actor: "evan", action: "commented", timeAgo: "1 hour ago")
    }
    .padding()
}

#Preview("CommentCard") {
    VStack(spacing: CoreSpacing.md) {
        CommentCard(author: "evan", role: "Contributor", timestamp: "2 hours ago") {
            Text("LGTM — ready to ship 🚀").font(CoreTypography.bodyMediumFont)
        }
        CommentCard(
            author: "renovate",
            role: "Bot",
            timestamp: "2 days ago",
            isMinimized: Binding.constant(true)
        ) {
            Text("chore(deps): update github actions")
        }
    }
    .padding()
}

#Preview("StatusRow") {
    VStack(spacing: 0) {
        StatusRow(label: "build (arm64)", duration: "2m 14s", result: .success)
        Divider()
        StatusRow(label: "test (macOS)", duration: "3m 01s", result: .success)
        Divider()
        StatusRow(label: "lint", duration: "0m 12s", result: .failure)
        Divider()
        StatusRow(label: "deploy (preview)", duration: "—", result: .pending)
        Divider()
        StatusRow(label: "analyze", duration: "—", result: .skipped)
    }
    .padding()
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
