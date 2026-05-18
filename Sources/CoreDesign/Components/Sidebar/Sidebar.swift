//
//  Sidebar.swift
//  CoreDesign
//

import SwiftUI

// MARK: - Sidebar Text Style

public enum SidebarTextStyle {
    public static let primary = Color.contentPrimary
    public static let secondary = Color.contentMuted
    public static let tertiary = Color.contentSubtle
}

// MARK: - Sidebar Section

public struct SidebarSection<Content: View>: View {
    public init(
        title: String,
        showsChevron: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.showsChevron = showsChevron
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.sm) {
            HStack(spacing: CoreSpacing.xs) {
                Text(self.title)
                    .font(CoreTypography.titleSmallFont)
                    .foregroundStyle(SidebarTextStyle.primary)

                if self.showsChevron {
                    Image(systemName: "chevron.right")
                        .font(CoreTypography.bodySmallFont)
                        .foregroundStyle(SidebarTextStyle.secondary)
                }

                Spacer()

                Image(systemName: "ellipsis")
                    .font(CoreTypography.bodyMediumFont)
                    .foregroundStyle(SidebarTextStyle.tertiary)
            }
            .padding(.horizontal, CoreSpacing.sm)

            VStack(spacing: CoreSpacing.xxs) {
                self.content
            }
        }
    }

    private let title: String
    private let showsChevron: Bool
    private let content: Content
}

// MARK: - Sidebar Rows

public struct SidebarNavigationRow: View {
    public init(
        systemImage: String,
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.title = title
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: self.action) {
            HStack(spacing: CoreSpacing.sm) {
                Image(systemName: self.systemImage)
                    .font(CoreTypography.bodyLargeFont)
                    .foregroundStyle(SidebarTextStyle.secondary)
                    .frame(width: CoreSpacing.xl)

                Text(self.title)
                    .font(CoreTypography.bodyLargeFont)
                    .foregroundStyle(SidebarTextStyle.primary)

                Spacer()
            }
            .frame(height: CoreControlMetrics.height(for: .large))
            .padding(.horizontal, CoreSpacing.sm)
            .sidebarSelectedBackground(self.isSelected)
            .contentShape(RoundedRectangle(cornerRadius: CoreRadius.mediumPlus))
        }
        .buttonStyle(.plain)
    }

    private let systemImage: String
    private let title: String
    private let isSelected: Bool
    private let action: () -> Void
}

public struct SidebarUtilityRow: View {
    public init(
        systemImage: String,
        title: String,
        trailingSystemImage: String? = nil,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.title = title
        self.trailingSystemImage = trailingSystemImage
        self.action = action
    }

    public var body: some View {
        Button(action: self.action) {
            HStack(spacing: CoreSpacing.sm) {
                Image(systemName: self.systemImage)
                    .font(CoreTypography.bodyLargeFont)
                    .foregroundStyle(SidebarTextStyle.secondary)
                    .frame(width: CoreSpacing.xl)

                Text(self.title)
                    .font(CoreTypography.bodyLargeFont)
                    .foregroundStyle(SidebarTextStyle.primary)

                Spacer()

                if let trailingSystemImage {
                    Image(systemName: trailingSystemImage)
                        .font(CoreTypography.bodyLargeFont)
                        .foregroundStyle(SidebarTextStyle.tertiary)
                }
            }
            .frame(height: CoreControlMetrics.height(for: .large))
            .padding(.horizontal, CoreSpacing.sm)
            .contentShape(RoundedRectangle(cornerRadius: CoreRadius.mediumPlus))
        }
        .buttonStyle(.plain)
    }

    private let systemImage: String
    private let title: String
    private let trailingSystemImage: String?
    private let action: () -> Void
}

public struct SidebarDocumentRow: View {
    public init(
        systemImage: String,
        title: String,
        detail: String,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.title = title
        self.detail = detail
        self.action = action
    }

    public var body: some View {
        Button(action: self.action) {
            HStack(spacing: CoreSpacing.sm) {
                Image(systemName: self.systemImage)
                    .font(CoreTypography.titleMediumFont)
                    .foregroundStyle(SidebarTextStyle.secondary)
                    .frame(width: CoreSpacing.xl)

                Text(self.title)
                    .font(CoreTypography.bodyLargeFont)
                    .foregroundStyle(SidebarTextStyle.primary)
                    .lineLimit(1)

                Spacer()

                Text(self.detail)
                    .font(CoreTypography.bodyMediumFont)
                    .foregroundStyle(SidebarTextStyle.tertiary)
                    .lineLimit(1)
            }
            .frame(height: CoreControlMetrics.height(for: .large))
            .padding(.horizontal, CoreSpacing.sm)
            .contentShape(RoundedRectangle(cornerRadius: CoreRadius.mediumPlus))
        }
        .buttonStyle(.plain)
    }

    private let systemImage: String
    private let title: String
    private let detail: String
    private let action: () -> Void
}

public struct SidebarTagRow: View {
    public init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: self.action) {
            HStack(spacing: CoreSpacing.sm) {
                Text("#")
                    .font(CoreTypography.titleMediumFont)
                    .foregroundStyle(SidebarTextStyle.secondary)
                    .frame(width: CoreSpacing.xl)

                Text(self.title)
                    .font(CoreTypography.bodyLargeFont)
                    .foregroundStyle(SidebarTextStyle.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(CoreTypography.bodySmallFont)
                    .foregroundStyle(SidebarTextStyle.tertiary)
            }
            .frame(height: CoreControlMetrics.height(for: .large))
            .padding(.horizontal, CoreSpacing.sm)
            .contentShape(RoundedRectangle(cornerRadius: CoreRadius.mediumPlus))
        }
        .buttonStyle(.plain)
    }

    private let title: String
    private let action: () -> Void
}

public struct SidebarStatusFooter: View {
    public init(title: String, detail: String, statusColor: Color = .green) {
        self.title = title
        self.detail = detail
        self.statusColor = statusColor
    }

    public var body: some View {
        HStack(spacing: CoreSpacing.sm) {
            Circle()
                .fill(self.statusColor)
                .frame(
                    width: CoreSpacing.sm,
                    height: CoreSpacing.sm
                )

            VStack(alignment: .leading, spacing: CoreSpacing.xxs) {
                Text(self.title)
                    .font(CoreTypography.bodySmallFont)
                    .fontWeight(.medium)
                    .foregroundStyle(SidebarTextStyle.primary)
                Text(self.detail)
                    .font(CoreTypography.bodySmallFont)
                    .foregroundStyle(SidebarTextStyle.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(CoreSpacing.sm)
    }

    private let title: String
    private let detail: String
    private let statusColor: Color
}

// MARK: - Selected Background

private struct SidebarSelectedBackgroundModifier: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        if self.isSelected {
            content
                .floatingGlass(
                    in: RoundedRectangle(cornerRadius: CoreRadius.mediumPlus),
                    isInteractive: true
                )
                .overlay {
                    RoundedRectangle(cornerRadius: CoreRadius.mediumPlus)
                        .strokeBorder(Color.borderSelected, lineWidth: CoreBorderWidth.thin)
                }
                .coreShadow(.medium)
                .glassEffect(
                    .regular.interactive(),
                    in: .rect(cornerRadius: CoreRadius.mediumPlus)
                )
        } else {
            content
        }
    }
}

public extension View {
    func sidebarSelectedBackground(_ isSelected: Bool) -> some View {
        self.modifier(SidebarSelectedBackgroundModifier(isSelected: isSelected))
    }
}
