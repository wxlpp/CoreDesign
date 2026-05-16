//
//  CoreElevation.swift
//  CoreDesign
//
//  Source of truth: docs/PRIMER_VERSION.md
//

import SwiftUI

// MARK: - CoreElevation

/// 阴影 / 高度 (elevation) token。语义层级沿用 Primer Primitives 的 `shadow.*` 标度，
/// 数值按 Craft workbench 风格调轻。
///
/// 设计要点：
///
/// - **4 档语义**：`.none` / `.small` / `.medium` / `.large`，语义对应 Primer
///   `resting` 与 `floating` 两组的代表性档位（详见 `docs/PRIMER_VERSION.md`），
///   但 blur / y-offset 数值已按 Craft workbench 降低。
/// - **暗色模式自适应**：`Spec.color` 通过 `Resources.xcassets/shadow/shadow-*.colorset`
///   提供 light / dark 双取值；dark 模式不透明度 ≥ light 的 2 倍——这是 Primer 与
///   Apple HIG 的共识（深色背景下的低对比阴影会"消失"，必须靠加深浓度补回 elevation 视觉）。
/// - **单层近似 + workbench 调轻**：Primer 上游用 1–5 层叠加；SwiftUI `.shadow(...)`
///   一次只渲染一层。本文件保留 Primer 的档位语义与 asset-backed shadow color，
///   但将 `.small` / `.medium` / `.large` 的 blur 与 y-offset 调低，让普通卡片更多依赖
///   surface + border 层级，而不是强浮起阴影。
///
/// 调用方式：
///
/// ```swift
/// RoundedRectangle(cornerRadius: CoreRadius.medium)
///     .fill(Color.systemBackground)
///     .coreShadow(.medium)
/// ```
public enum CoreElevation {

    // MARK: - Level

    /// 高度档位。每档对应 Primer shadow 标度的一档语义。
    public enum Level: Sendable, CaseIterable {
        /// 无阴影。等价于平面元素，不产生 elevation 视觉。
        case none

        /// 小阴影。语义对应 Primer `shadow.resting.small`，数值按 workbench 风格调轻。
        case small

        /// 中阴影。语义对应 Primer `shadow.resting.medium`，普通卡片不会强烈浮起。
        case medium

        /// 大阴影。语义对应 Primer `shadow.floating.medium`，用于 popover、菜单、浮层。
        ///
        /// > Note: Primer 的 `floating.large` / `xlarge` 用于 modal / sheet；
        /// > 本仓库 4 档语义将 `large` 对齐到 `floating.medium`，避免一档"过冲"。
        /// > 真·全屏遮罩的强阴影留待后续按需扩展。
        case large
    }

    // MARK: - Spec

    /// 单档 elevation 的视觉规格。直接对应 SwiftUI
    /// `.shadow(color:radius:x:y:)` 四个参数；radius / y 为 Craft workbench 调轻后的值。
    public struct Spec: Sendable {
        /// 阴影颜色。来自 `Resources.xcassets/shadow/shadow-*.colorset`，自动 light/dark。
        public let color: Color

        /// SwiftUI `.shadow` blur radius，单位 **pt**（点）。本值保留 Primer 档位语义，
        /// 但不是 Primer 原始数值的逐字映射。
        public let radius: CGFloat

        /// 水平偏移。对应 Primer `offsetX`。
        public let x: CGFloat

        /// 垂直偏移。保留 Primer `offsetY` 语义，数值按 Craft workbench 调轻。
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
            // Craft workbench: small resting elevation is nearly flat; hierarchy comes from surface + border.
            return Spec(
                color: Self.shadowSmallColor,
                radius: 1,
                x: 0,
                y: 0.5
            )
        case .medium:
            // Craft workbench: ordinary cards should not float strongly above the page.
            return Spec(
                color: Self.shadowMediumColor,
                radius: 4,
                x: 0,
                y: 2
            )
        case .large:
            // Craft workbench: keep obvious elevation for true floating surfaces, but reduce gloss.
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
    ///     .clipShape(RoundedRectangle(cornerRadius: CoreRadius.medium))
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
                    RoundedRectangle(cornerRadius: CoreRadius.medium)
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
