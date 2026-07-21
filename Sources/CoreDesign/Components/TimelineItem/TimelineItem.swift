//
//  TimelineItem.swift
//  CoreDesign
//

import SwiftUI

// MARK: - timelineDepth

extension EnvironmentValues {
    /// 时间线嵌套深度 / Timeline nesting depth。
    @Entry var timelineDepth: Int = 0
}

// MARK: - TimelineDotDiameter

/// 脊柱图标圆点直径 / Icon-dot diameters（元素尺寸，非 spacing 档位）。
/// 根节点 32pt、嵌套子节点 20pt——`CoreSpacing` 是间距刻度且不含 20pt，
/// 故提为命名常量而非硬套 token，保持数值零变化。
/// （`TimelineItem` 是泛型类型，不支持 static stored property，故常量落在此文件级
/// caseless enum 命名空间中。）
private enum TimelineDotDiameter {
    static let root: CGFloat = 32
    static let nested: CGFloat = 20
}

// MARK: - TimelineItem

/// Native Primer timeline item.
///
/// Content-layer row. Vertical timeline entry with a leading rail (dot +
/// optional connector lines). Designed for scanning: low chrome, restrained
/// borders, no glass. Polish comes from the leading-rail rhythm and
/// typography, not from material.
///
/// **Material layer**: content. **Surface role**: content.
///
/// 时间线脊柱节点容器。
///
/// 左侧脊柱（连接线 + 图标圆点）+ 右侧内容槽。通过 `@Environment(\.timelineDepth)`
/// 自动管理缩进递归——父级嵌套子 `TimelineItem` 时缩进自动 +1，无需手动传参。
public struct TimelineItem<Icon: View, Content: View>: View {
    @ViewBuilder let icon: () -> Icon
    @ViewBuilder let content: () -> Content
    let showsTopConnector: Bool
    let isLast: Bool

    public init(
        @ViewBuilder icon: @escaping () -> Icon,
        showsTopConnector: Bool = true,
        isLast: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.icon = icon
        self.showsTopConnector = showsTopConnector
        self.isLast = isLast
        self.content = content
    }

    @Environment(\.timelineDepth) private var depth

    private var indent: CGFloat {
        CGFloat(self.depth) * CoreSpacing.xl
    }

    public var body: some View {
        HStack(alignment: .top, spacing: CoreSpacing.sm) {
            // Spine column
            self.spineView
            // Content column
            VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                self.content()
            }
            .environment(\.timelineDepth, self.depth + 1)
        }
        .padding(.leading, self.indent)
    }

    private var spineView: some View {
        VStack(spacing: CoreSpacing.none) {
            if self.showsTopConnector {
                // Top connection line (from previous node)
                Rectangle()
                    .fill(Color.borderMuted)
                    .frame(width: CoreBorderWidth.thin, height: CoreSpacing.sm)
            } else {
                Color.clear
                    .frame(width: CoreBorderWidth.thin, height: CoreSpacing.sm)
            }

            // Icon dot
            self.icon()
                .frame(width: self.dotSize, height: self.dotSize)

            // Bottom connection line (to next node, hidden if last)
            if !self.isLast {
                Rectangle()
                    .fill(Color.borderMuted)
                    .frame(width: CoreBorderWidth.thin, height: CoreSpacing.sm)
            }
        }
        .accessibilityHidden(true)
    }

    private var dotSize: CGFloat {
        switch self.depth {
        case 0: return TimelineDotDiameter.root
        default: return TimelineDotDiameter.nested
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 0) {
        TimelineItem(icon: {
            Circle().fill(.blue).frame(width: 32, height: 32)
                .overlay(Text("A").foregroundStyle(.white).font(.caption))
        }, showsTopConnector: false, isLast: false) {
            VStack(alignment: .leading) {
                Text("First event").font(.headline)
                TimelineItem(icon: {
                    Circle().fill(.green).frame(width: 20, height: 20)
                }, isLast: true) {
                    Text("Nested reply").font(.subheadline)
                }
            }
        }
        TimelineItem(icon: {
            Circle().fill(.gray).frame(width: 32, height: 32)
        }, isLast: true) {
            Text("Last event").font(.headline)
        }
    }
    .padding()
}
