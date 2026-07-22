//
//  CoreControlMetrics.swift
//  CoreDesign
//

import CoreGraphics
import SwiftUI

// MARK: - CoreControlMetrics

/// 控件尺寸 token，按 SwiftUI `ControlSize`（mini / small / regular / large / extraLarge）
/// 暴露 5 个查询 helper（height / horizontalPadding / verticalPadding / font / iconSize）。
///
/// 调用方式（caseless enum + `static func`）：
///
/// ```swift
/// // SegmentedControl / SearchField / SolidButtonStyle 内部
/// @Environment(\.controlSize) private var controlSize
/// ...
/// .padding(.horizontal, CoreControlMetrics.horizontalPadding(for: controlSize))
/// .padding(.vertical, CoreControlMetrics.verticalPadding(for: controlSize))
/// .coreFont(CoreControlMetrics.fontToken(for: controlSize))
/// .frame(minHeight: CoreControlMetrics.height(for: controlSize))
/// ```
///
/// > Important: 推荐用 **`frame(minHeight:)`**（地板）而非 `frame(height:)`（钳制）。
/// > `height(for:)` 给出的是 Apple HIG 参考高度，padding + 系统文本样式字号的实际渲染
/// > 高度未必逐 pt 精确命中；用 `minHeight` 保证不裁切，超出时自然撑高。
///
/// ## 取值依据
///
/// Apple HIG 的控件尺寸建议：常规交互控件的最小可点击区域约 44pt（`regular`），
/// 密集 chrome 场景可收紧到 28–32pt（`mini` / `small`），大尺寸 CTA 类控件可以到
/// 50–56pt（`large` / `extraLarge`）。SwiftUI `ControlSize` 5 个 case 直接对应
/// 这 5 档语义，不再挂靠任何第三方标度。
///
/// > Important: padding helper 必须返回 `CoreSpacing.*` 命名常量，font helper 必须返回
/// > `CoreTypography.Token` 新档位，不内联魔法数字——这是本 token 存在的全部意义。
/// > height 与 iconSize 没有对应的 CoreSpacing 档位，按 HIG 直接给定 pt 值。
public nonisolated enum CoreControlMetrics {

    // MARK: - height

    /// 控件高度（pt）。用于 capsule / pill / SegmentedControl / SearchField 等需要固定外框
    /// 高度的场景。
    ///
    /// 取值对齐 Apple HIG 控件高度参考：
    /// `mini=28 / small=32 / regular=44 / large=50 / extraLarge=56`。
    /// `regular = 44pt` 是 Apple 平台推荐的最小可点击目标高度。
    ///
    /// - Parameter controlSize: SwiftUI 环境 `\.controlSize`。
    /// - Returns: 该尺寸下的推荐外框高度，单位 pt。
    public static func height(for controlSize: ControlSize) -> CGFloat {
        switch controlSize {
        case .mini: return 28
        case .small: return 32
        case .regular: return 44
        case .large: return 50
        case .extraLarge: return 56
        @unknown default:
            return 44
        }
    }

    // MARK: - horizontalPadding

    /// 控件横向 padding（pt）。包裹 label 的左右内边距，配合 `height(for:)` 决定外框宽度。
    ///
    /// `mini=8 / small=12 / regular=16 / large=16 / extraLarge=24`——`regular` 起给出更
    /// 舒展的横向留白，贴近 Apple 系统按钮的视觉密度；`extraLarge`（CTA 类）进一步放宽。
    ///
    /// - Parameter controlSize: SwiftUI 环境 `\.controlSize`。
    /// - Returns: 该尺寸下推荐的左右 padding，单位 pt，必为 `CoreSpacing.*` 命名常量。
    public static func horizontalPadding(for controlSize: ControlSize) -> CGFloat {
        switch controlSize {
        case .mini: return CoreSpacing.sm        // 8pt
        case .small: return CoreSpacing.md       // 12pt
        case .regular: return CoreSpacing.lg     // 16pt
        case .large: return CoreSpacing.lg        // 16pt
        case .extraLarge: return CoreSpacing.xl  // 24pt — CTA 类，更宽松
        @unknown default:
            return CoreSpacing.lg
        }
    }

    // MARK: - verticalPadding

    /// 控件纵向 padding（pt）。包裹 label 的上下内边距。
    ///
    /// `mini=4 / small=4 / regular=12 / large=16 / extraLarge=16`。
    ///
    /// > Important: **哪些档位由地板决定、哪些由 padding 决定，取决于平台与 Dynamic Type 档**——
    /// > 下面的算术只在 **iOS 默认 Dynamic Type 档**成立，不要当成无条件结论。
    /// >
    /// > **iOS 默认档**（footnote 13 / callout 16 / body 17 / title2 22，行高约 18/21/22/28）：
    /// > `mini` / `small` 算得 `4×2+18 = 26pt` 低于两档地板（28 / 32），由 `frame(minHeight:)`
    /// > **地板**决定，二者因此可见地不同高；`regular` 及以上相反——`12×2+21 ≈ 45 > 44`、
    /// > `16×2+22 ≈ 54 > 50`、`16×2+28 ≈ 60 > 56`，由 **padding** 决定，`height(for:)`
    /// > 退化为不生效的下限。
    /// >
    /// > **macOS**：系统文本样式明显更小（实测 footnote 10 / callout 12 / body 13 / title2 17），
    /// > 算得 mini / small `4×2+13 = 21 < 28 / 32`、regular `24+15 ≈ 39 < 44`、
    /// > large `32+16 ≈ 48 < 50`、extraLarge `32+22 ≈ 54 < 56`——**五档全部由地板决定**，
    /// > 与 iOS 默认档的情形相反。
    /// >
    /// > **iOS 大字号档**：Dynamic Type 调大后 `mini` / `small` 也会越过地板、转为由 padding
    /// > 决定，结论再次翻转。
    /// >
    /// > 取舍：宁可比 `height(for:)` 的参考高度略高，也不压缩 label——`minHeight` 不裁切，
    /// > `frame(height:)` 会。五档在各平台各档位的实际渲染高度待视觉终审确认。
    /// >
    /// > 历史：早先版本取 `mini=8 / small=8`，算得 34pt 同时越过两个地板，导致 mini 与 small
    /// > 渲染同高、而注释仍声称靠地板区分——数值上不成立的机制。改回 4pt 修复。
    ///
    /// - Parameter controlSize: SwiftUI 环境 `\.controlSize`。
    /// - Returns: 该尺寸下推荐的上下 padding，单位 pt，必为 `CoreSpacing.*` 命名常量。
    public static func verticalPadding(for controlSize: ControlSize) -> CGFloat {
        switch controlSize {
        case .mini: return CoreSpacing.xs        // 4pt
        case .small: return CoreSpacing.xs       // 4pt
        case .regular: return CoreSpacing.md     // 12pt
        case .large: return CoreSpacing.lg       // 16pt
        case .extraLarge: return CoreSpacing.lg  // 16pt
        @unknown default:
            return CoreSpacing.md
        }
    }

    // MARK: - font

    /// 控件 label 推荐字号 token。直接返回 `CoreTypography.Token`，调用方经
    /// `.coreFont(_:)` 施加。
    ///
    /// 档位映射理由：mini / small 走 `footnote` 保证密集 UI 不溢出；regular 走
    /// `callout`（默认 UI 字号）；large 上抬到 `body`；extraLarge 用 `title2`，
    /// 让 CTA 类按钮视觉权重与较大尺寸的外框匹配。
    ///
    /// - Parameter controlSize: SwiftUI 环境 `\.controlSize`。
    /// - Returns: 该尺寸下推荐的 `CoreTypography.Token`。
    public static func fontToken(for controlSize: ControlSize) -> CoreTypography.Token {
        switch controlSize {
        case .mini:       .footnote
        case .small:      .footnote
        case .regular:    .callout
        case .large:      .body
        case .extraLarge: .title2
        @unknown default: .callout
        }
    }

    // MARK: - iconSize

    /// 控件内联 icon 边长（pt）。比对应字号约大 1.0–1.2 倍，以视觉等重原则与 label 文字
    /// 对齐——SF Symbol / SVG glyph 的视觉重心通常略低于 cap height，需要稍大边长才能感觉
    /// 与字母 x-height 等高。
    ///
    /// 取值参考：mini=12 / small=14 / regular=16 / large=20 / extraLarge=24。
    /// 这些值不在 CoreSpacing 标度上（CoreSpacing 用于布局间距，与 icon 几何尺寸不同
    /// 语义），故直接以 pt 给定。
    ///
    /// - Parameter controlSize: SwiftUI 环境 `\.controlSize`。
    /// - Returns: 该尺寸下推荐的 icon 边长，单位 pt。
    public static func iconSize(for controlSize: ControlSize) -> CGFloat {
        switch controlSize {
        case .mini: return 12
        case .small: return 14
        case .regular: return 16
        case .large: return 20
        case .extraLarge: return 24
        @unknown default:
            return 16
        }
    }
}
