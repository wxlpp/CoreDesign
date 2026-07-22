//
//  AvatarGroup.swift
//  CoreDesign
//

import SwiftUI

// MARK: - AvatarGroup

/// Content-layer composition of stacked avatars with overlap + overflow
/// counter. Uses thin border (`CoreBorderWidth.thin`) to separate stacked
/// avatars and overflow pill. No glass.
///
/// **Material layer**: content. **Surface role**: content.
///
/// 堆叠头像组。
///
/// 前 N 个 avatar 交叠显示，超出 `max` 的部分显示 "+N" 计数 pill。
/// 使用 `Group(subviews:)` 遍历子视图。
public struct AvatarGroup<Avatars: View>: View {
    let max: Int
    @ViewBuilder let avatars: () -> Avatars

    public init(max: Int = 3, @ViewBuilder avatars: @escaping () -> Avatars) {
        self.max = Swift.max(0, max)
        self.avatars = avatars
    }

    @Environment(\.controlSize) private var controlSize

    /// 头像交叠量 / Avatar overlap offset（按 controlSize 递增负 offset）。
    /// 元素尺寸 ramp，刻意与 `CoreControlMetrics` 同构（裸字面量 switch），
    /// 不路由到 `CoreSpacing`——后者是间距刻度，且负值 / 20pt 无对应档位。
    private var overlapOffset: CGFloat {
        switch self.controlSize {
        case .mini, .small: return -6
        case .regular: return -8
        case .large, .extraLarge: return -10
        @unknown default: return -8
        }
    }

    public var body: some View {
        Group(subviews: self.avatars()) { subviews in
            let visible = subviews.prefix(self.max)
            let overflow = subviews.count - self.max

            HStack(spacing: self.overlapOffset) {
                ForEach(Array(zip(visible.indices, visible)), id: \.0) { _, subview in
                    subview
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .strokeBorder(Color.surfaceCanvas, lineWidth: CoreBorderWidth.thin)
                        )
                }

                if overflow > 0 {
                    Text("+\(overflow)")
                        .coreFont(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: self.avatarSize, height: self.avatarSize)
                        .background(
                            Circle()
                                .fill(Color.surfaceCanvasInset)
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(Color.borderMuted, lineWidth: CoreBorderWidth.thin)
                        )
                        .accessibilityLabel(AvatarGroupAccessibility.overflowLabel(for: overflow))
                }
            }
        }
    }

    /// 头像直径 / Avatar diameter（按 controlSize，20…48pt）。
    /// 同上：元素尺寸 ramp，与 `CoreControlMetrics` 同构，不套 spacing token。
    private var avatarSize: CGFloat {
        switch self.controlSize {
        case .mini: return 20
        case .small: return 24
        case .regular: return 32
        case .large: return 40
        case .extraLarge: return 48
        @unknown default: return 32
        }
    }
}

enum AvatarGroupAccessibility {
    static func overflowLabel(for count: Int) -> String {
        String(localized: "\(count) more avatars", bundle: .module)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
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
    .background(Color.surfaceCanvas)
}
