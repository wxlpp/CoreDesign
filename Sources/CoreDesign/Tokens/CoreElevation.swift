import SwiftUI

// MARK: - CoreElevation

/// 阴影 / 高度 (elevation) token，只用于真正悬浮于内容之上的元素。
public enum CoreElevation {
    // MARK: - Level

    /// 高度档位。每档对应 Apple HIG elevation 语义的一档。
    public nonisolated enum Level: Sendable, CaseIterable {
        /// 无阴影。等价于平面元素，不产生 elevation 视觉。
        case none

        /// 小阴影。resting 层级，近乎平坦，日常静止内容（Badge、紧凑控件）用它。
        case small

        /// 中阴影。resting 层级，普通卡片不应强烈浮起——层级交给 surface + border 表达。
        case medium

        /// 大阴影。floating 层级，用于 popover、菜单、真正悬浮于内容之上的浮层。
        case large
    }

    // MARK: - Spec

    /// 单档 elevation 的视觉规格。直接对应 SwiftUI
    /// `.shadow(color:radius:x:y:)` 四个参数。
    public struct Spec: Sendable {
        /// 阴影颜色。来自 `Resources.xcassets/shadow/shadow-*.colorset`，自动 light/dark。
        public let color: Color

        /// SwiftUI `.shadow` blur radius，单位 **pt**（点）。
        public let radius: CGFloat

        /// 水平偏移。
        public let x: CGFloat

        /// 垂直偏移。
        public let y: CGFloat

        public init(color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            self.color = color
            self.radius = radius
            self.x = x
            self.y = y
        }
    }

    // MARK: - Asset-backed colors

    private static let shadowNoneColor = Color("shadow-none", bundle: .module)
    private static let shadowSmallColor = Color("shadow-small", bundle: .module)
    private static let shadowMediumColor = Color("shadow-medium", bundle: .module)
    private static let shadowLargeColor = Color("shadow-large", bundle: .module)

    /// 查询给定 `Level` 的视觉规格。
    ///
    /// - Parameter level: elevation 档位。
    /// - Returns: 对应档位的 `Spec` 结构体（含 `color` / `radius` / `x` / `y` 四个字段，
    ///   直接对应 SwiftUI `.shadow(color:radius:x:y:)` 的四个参数）。
    public static func spec(for level: Level) -> Spec {
        switch level {
        case .none:
            return Spec(
                color: Self.shadowNoneColor,
                radius: 0,
                x: 0,
                y: 0
            )
        case .small:
            return Spec(
                color: Self.shadowSmallColor,
                radius: 1,
                x: 0,
                y: 0.5
            )
        case .medium:
            return Spec(
                color: Self.shadowMediumColor,
                radius: 4,
                x: 0,
                y: 2
            )
        case .large:
            return Spec(
                color: Self.shadowLargeColor,
                radius: 12,
                x: 0,
                y: 6
            )
        }
    }
}

// MARK: - View.coreShadow

public extension View {
    /// 应用 CoreDesign elevation 阴影。颜色随 colorScheme 自动切换 light / dark。
    ///
    /// - Parameter level: elevation 档位（`.none` / `.small` / `.medium` / `.large`）。
    /// - Returns: 已应用阴影的视图。
    func coreShadow(_ level: CoreElevation.Level) -> some View {
        let spec = CoreElevation.spec(for: level)
        return self.shadow(color: spec.color, radius: spec.radius, x: spec.x, y: spec.y)
    }
}

// MARK: - Preview

#Preview("Light") {
    CoreElevationPreview()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    CoreElevationPreview()
        .preferredColorScheme(.dark)
}

// MARK: - Preview Helper

private struct CoreElevationPreview: View {
    var body: some View {
        VStack(spacing: 32) {
            ForEach(CoreElevation.Level.allCases, id: \.self) { level in
                VStack(spacing: 6) {
                    CoreShape.rounded(CoreRadius.medium)
                        .fill(Color.systemBackground)
                        .frame(width: 160, height: 80)
                        .coreShadow(level)
                    Text(label(for: level))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.systemGroupedBackground)
    }

    private func label(for level: CoreElevation.Level) -> String {
        switch level {
        case .none: return ".none"
        case .small: return ".small"
        case .medium: return ".medium"
        case .large: return ".large"
        }
    }
}
