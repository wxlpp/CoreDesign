//
//  TimelineItem.swift
//  CoreDesign
//

import SwiftUI

// MARK: - TimelineDepthKey

struct TimelineDepthKey: EnvironmentKey {
    static let defaultValue: Int = 0
}

extension EnvironmentValues {
    var timelineDepth: Int {
        get { self[TimelineDepthKey.self] }
        set { self[TimelineDepthKey.self] = newValue }
    }
}

// MARK: - TimelineItem

/// 时间线脊柱节点容器。
///
/// 左侧脊柱（连接线 + 图标圆点）+ 右侧内容槽。通过 `@Environment(\.timelineDepth)`
/// 自动管理缩进递归——父级嵌套子 `TimelineItem` 时缩进自动 +1，无需手动传参。
public struct TimelineItem<Icon: View, Content: View>: View {
    @ViewBuilder let icon: () -> Icon
    @ViewBuilder let content: () -> Content
    public let isLast: Bool

    public init(
        @ViewBuilder icon: @escaping () -> Icon,
        isLast: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.icon = icon
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
        VStack(spacing: 0) {
            // Top connection line (from previous node)
            Rectangle()
                .fill(Color.borderMuted)
                .frame(width: CoreBorderWidth.thin, height: CoreSpacing.sm)

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
        case 0: return 32
        default: return 20
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 0) {
        TimelineItem(icon: {
            Circle().fill(.blue).frame(width: 32, height: 32)
                .overlay(Text("A").foregroundStyle(.white).font(.caption))
        }, isLast: false) {
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
