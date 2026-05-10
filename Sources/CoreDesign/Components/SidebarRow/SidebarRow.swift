//
//  SidebarRow.swift
//  CoreDesign
//

import SwiftUI

// MARK: - SidebarRow

/// 侧栏行 / Sidebar Row：GitHub 桌面客户端风格的侧栏导航行。
///
/// 使用场景：左侧导航 / 项目侧栏 / 二级目录列表等需要"紧凑高度 + 选中态强调"
/// 的列表项位置。Primer 概念上对应 `NavList.Item` / `ActionList.Item` 的"选中"
/// 分支——本组件在选中时通过左侧 accent 条 + 浅色背景同时表达 selected 语义。
///
/// 关键参数：
/// - `isSelected`：是否处于选中态。selected 优先级高于 hover——选中行 hover 时
///   不再切换背景，避免视觉抖动。
/// - `label`：行内容；任意 `View`。便利构造支持 `Text` 直传字符串。
///
/// Primer 概念对应：
/// - selected 左侧 accent 条厚度 → `borderWidth.thick` (`CoreBorderWidth.thick` / 2pt，
///   per epic ADR #7 / PRD FR-B-5)；颜色 → `borderColor.accent.emphasis`
///   (`Color.borderFocus`)。
/// - 紧凑高度对应 `control.small.size` (28pt)，与桌面客户端侧栏密度匹配。
/// - label 字号采用 `bodyMedium` (14pt regular)，是侧栏导航文字默认权重。
///
/// light / dark 差异：
/// - selected / hover 背景统一使用 `Color.surfaceCanvasSubtle`，由 colorset 提供
///   light/dark 双值——light 偏白灰、dark 偏深灰，分别拉开与 `surfaceCanvas` 的对比。
/// - 左侧 accent 条颜色 `Color.borderFocus` 同样由 colorset 提供 light/dark 双值
///   （Primer `accent.emphasis`：light `#0969da` / dark `#1f6feb`）。
///
/// **Hover token debt**：hover 态使用 `Color.surfaceCanvasSubtle` 而非
/// `Color.hoverBackground`：后者已存在于 `InteractionColors.swift` 但取值是系统 fill
/// 未对齐 Primer。本组件直接用 `surfaceCanvasSubtle` 是**取值层取舍**，不是 token
/// 缺失代偿。详见 PRD `coredesign-v2-components.md` §Notes hover token debt。
public struct SidebarRow<Label: View>: View {
    public init(isSelected: Bool, @ViewBuilder label: () -> Label) {
        self.isSelected = isSelected
        self.label = label()
    }

    public var body: some View {
        HStack(spacing: CoreSpacing.none) {
            // 左侧 accent 条：仅在 selected 时可见。厚度走 `CoreBorderWidth.thick`
            // token，避免 inline 字面量 2（per epic ADR #7 / PRD FR-B-5）。
            Rectangle()
                .fill(self.isSelected ? Color.borderFocus : Color.clear)
                .frame(width: CoreBorderWidth.thick)

            self.label
                .font(CoreTypography.bodyMediumFont)
                .foregroundStyle(Color.contentPrimary)
                .padding(
                    .horizontal,
                    CoreControlMetrics.horizontalPadding(for: .small)
                )
                .padding(
                    .vertical,
                    CoreControlMetrics.verticalPadding(for: .small)
                )
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: CoreControlMetrics.height(for: .small))
        .background(self.backgroundColor)
        .contentShape(Rectangle())
        .onHover { hovering in
            self.isHovered = hovering
        }
    }

    /// selected 优先级高于 hover；非选中且 hover 时回退到 hover 浅色背景；
    /// 默认态保持透明，让父容器的 `surfaceSidebar` 透出。
    private var backgroundColor: Color {
        if self.isSelected || self.isHovered {
            return Color.surfaceCanvasSubtle
        } else {
            return Color.clear
        }
    }

    private let isSelected: Bool
    private let label: Label

    @State private var isHovered: Bool = false
}

// MARK: - Convenience init for Text

extension SidebarRow where Label == Text {
    /// 字符串便利构造：等价于 `SidebarRow(isSelected:) { Text(text) }`。
    public init(_ text: String, isSelected: Bool) {
        self.init(isSelected: isSelected) {
            Text(text)
        }
    }
}

// MARK: - Previews

#Preview("Light") {
    VStack(spacing: CoreSpacing.none) {
        SidebarRow("Inbox", isSelected: false)
        SidebarRow("Pull Requests", isSelected: true)
        SidebarRow("Issues", isSelected: false)
        SidebarRow("Discussions", isSelected: false)
        SidebarRow(isSelected: false) {
            HStack(spacing: CoreSpacing.sm) {
                Image(systemName: "star.fill")
                Text("Starred")
            }
        }
    }
    .frame(width: 240)
    .background(Color.surfaceSidebar)
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    VStack(spacing: CoreSpacing.none) {
        SidebarRow("Inbox", isSelected: false)
        SidebarRow("Pull Requests", isSelected: true)
        SidebarRow("Issues", isSelected: false)
        SidebarRow("Discussions", isSelected: false)
        SidebarRow(isSelected: false) {
            HStack(spacing: CoreSpacing.sm) {
                Image(systemName: "star.fill")
                Text("Starred")
            }
        }
    }
    .frame(width: 240)
    .background(Color.surfaceSidebar)
    .preferredColorScheme(.dark)
}
