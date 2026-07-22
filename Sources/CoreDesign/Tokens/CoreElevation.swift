//
//  CoreElevation.swift
//  CoreDesign
//

import SwiftUI

// MARK: - CoreElevation

/// 阴影 / 高度 (elevation) token。语义与数值均按 Apple HIG 的分层原则设计：
/// 平面层级优先靠 material（毛玻璃）与 separator（分隔线/描边）表达，阴影只用于
/// 真正悬浮于内容之上的元素。
///
/// 设计要点：
///
/// - **4 档语义**：`.none` / `.small` / `.medium` / `.large`——`.none` 无阴影；
///   `.small` / `.medium` 是近乎平坦的 resting 层级，普通卡片、列表行等常驻内容用它们，
///   不应产生明显"浮起"视觉；`.large` 才是留给 popover / 菜单 / 真正浮层的档位。
/// - **暗色模式自适应**：`Spec.color` 通过 `Resources.xcassets/shadow/shadow-*.colorset`
///   提供 light / dark 双取值；dark 模式不透明度 ≥ light 的 2 倍。这是常见的工程实践
///   而非 HIG 的明文规定（深色背景下的低对比阴影会"消失"，须靠加深浓度补回 elevation 视觉）。
/// - **克制的单层阴影**：Apple HIG 提倡阴影服务于内容层级而非装饰，日常静止内容
///   （resting）应尽量平坦，只有真正悬浮的内容（floating）才使用更明显的阴影。
///   本文件的 `.small` / `.medium` 因此刻意调低 blur 与 y-offset，让普通卡片更多依赖
///   surface + border 层级，而不是强浮起阴影；`.large` 保留给真正的浮层。
///
/// 调用方式：
///
/// ```swift
/// CoreShape.rounded(CoreRadius.medium)
///     .fill(Color.systemBackground)
///     .coreShadow(.medium)
/// ```
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
        ///
        /// > Note: 全屏 modal / sheet 级别的强阴影留待后续按需扩展，不在本仓库当前
        /// > 4 档语义内。
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

    // MARK: - Specs

    // MARK: - Asset-backed colors

    /// 集中管理 shadow colorset 的字符串引用，避免 stringly-typed 调用点散落在各 case，
    /// 重命名 colorset 时只需要改这里。命名约定见 `Resources.xcassets/shadow/`。
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
            // 占位规格：radius = 0 时 SwiftUI 不渲染阴影，color/y 实际不参与绘制。
            return Spec(
                color: Self.shadowNoneColor,
                radius: 0,
                x: 0,
                y: 0
            )
        case .small:
            // Apple HIG: resting elevation should be nearly flat; hierarchy comes from surface + border.
            return Spec(
                color: Self.shadowSmallColor,
                radius: 1,
                x: 0,
                y: 0.5
            )
        case .medium:
            // Apple HIG: ordinary cards should not float strongly above the page.
            return Spec(
                color: Self.shadowMediumColor,
                radius: 4,
                x: 0,
                y: 2
            )
        case .large:
            // Apple HIG: keep obvious elevation for true floating surfaces, but reduce gloss.
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
    /// ```swift
    /// VStack { ... }
    ///     .background(Color.systemBackground)
    ///     .clipShape(CoreShape.rounded(CoreRadius.medium))
    ///     .coreShadow(.medium)
    /// ```
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
