//
//  CoreControlMetrics.swift
//  CoreDesign
//
//  Source of truth: docs/PRIMER_VERSION.md
//

import CoreGraphics
import SwiftUI

// MARK: - CoreControlMetrics

/// 控件尺寸 token，按 SwiftUI `ControlSize`（mini / small / regular / large / extraLarge）
/// 暴露 height / horizontalPadding / verticalPadding / font / iconSize 五项查询表 helper。
///
/// 调用方式（caseless enum + 5 个 `static func`）：
///
/// ```swift
/// // SegmentedControl / SearchField / SolidButtonStyle 内部
/// @Environment(\.controlSize) private var controlSize
/// ...
/// .padding(.horizontal, CoreControlMetrics.horizontalPadding(for: controlSize))
/// .padding(.vertical, CoreControlMetrics.verticalPadding(for: controlSize))
/// .font(CoreControlMetrics.font(for: controlSize))
/// .frame(minHeight: CoreControlMetrics.height(for: controlSize))
/// ```
///
/// > Important: 默认推荐用 **`frame(minHeight:)`**（地板）而非 `frame(height:)`（钳制）。
/// > 原因：本仓库 padding 取值贴 CoreSpacing scale（8/12/16），与 Primer 原始
/// > paddingBlock（6/10/14）有 2–4pt 上抬；当字体偏大时（譬如 extraLarge 用
/// > titleMedium 20pt），padding × 2 + font 会超过 `height(for:)` 的 Primer 精确值，
/// > 用 `frame(height:)` 会裁切 / 压缩 label。
/// >
/// > 若设计上必须严格命中 Primer 控件高度（譬如对接现有视觉 spec），改用
/// > `primerVerticalPadding(for:)`（返回 Primer `paddingBlock` 精确值 6/10/14）配
/// > `frame(height:)` 钳制——padding 数值仍集中在本 token 内，不在调用方散落字面量。
///
/// ## 取值依据
///
/// 主要参考 Primer Primitives `functional/size/size.json5` 的 `control.{xsmall,small,medium,large,xlarge}`
/// 表（详见 `docs/PRIMER_VERSION.md` 锁定的版本）。SwiftUI `ControlSize` 5 个 case 与 Primer
/// 5 档一一对应：`mini ↔ xsmall`、`small ↔ small`、`regular ↔ medium`、`large ↔ large`、
/// `extraLarge ↔ xlarge`。
///
/// 真实参考基线：`Sources/CoreDesign/Components/Button/styles/SolidButtonStyle.swift` 现有
/// `EdgeInsets` 表（`mini=2/12, small=2/12, regular=6/12, large=8/16, extraLarge=10/20`）。
/// 本 token 把这些字面量上抬到 `CoreSpacing.*`，并在 padding 与 Primer 不能精确对齐时
/// **就近选择 CoreSpacing 上已有的档位**——这是 token 化 vs. 像素级对齐的取舍：组件层
/// 不应再出现魔法数字。
///
/// > Important: padding helper 必须返回 `CoreSpacing.*` 命名常量，font helper 必须返回
/// > `CoreTypography.*Font`，不内联魔法数字——这是本 token 存在的全部意义。
/// > height 与 iconSize 没有对应的 CoreSpacing 档位，按 Primer 直接给定 pt 值。
public enum CoreControlMetrics {

    // MARK: - height

    /// 控件高度（pt）。用于 capsule / pill / SegmentedControl / SearchField 等需要固定外框
    /// 高度的场景。
    ///
    /// 取值参考 Primer `control.{size}.size` token：
    /// `mini=24 / small=28 / regular=32 / large=40 / extraLarge=48`。
    /// `regular = 32pt` 对应 Primer `control.medium.size`，是 GitHub 桌面 UI 默认按钮高度。
    ///
    /// - Parameter controlSize: SwiftUI 环境 `\.controlSize`。
    /// - Returns: 该尺寸下的推荐外框高度，单位 pt。
    public static func height(for controlSize: ControlSize) -> CGFloat {
        switch controlSize {
        case .mini: return 24
        case .small: return 28
        case .regular: return 32
        case .large: return 40
        case .extraLarge: return 48
        @unknown default:
            return 32
        }
    }

    // MARK: - horizontalPadding

    /// 控件横向 padding（pt）。包裹 label 的左右内边距，配合 `height(for:)` 决定外框宽度。
    ///
    /// 取值参考 Primer `control.{size}.paddingInline.normal`：
    /// `xsmall=8 / small=12 / medium=12 / large=12 / xlarge=12`。Primer 在 small 及以上
    /// 都使用 12pt 横向内边距，仅 mini (xsmall) 收紧到 8pt。本 token 直接照搬这一规律。
    ///
    /// - Parameter controlSize: SwiftUI 环境 `\.controlSize`。
    /// - Returns: 该尺寸下推荐的左右 padding，单位 pt，必为 `CoreSpacing.*` 命名常量。
    public static func horizontalPadding(for controlSize: ControlSize) -> CGFloat {
        switch controlSize {
        case .mini: return CoreSpacing.sm        // 8pt — Primer xsmall.paddingInline.normal
        case .small: return CoreSpacing.md       // 12pt — Primer small.paddingInline.normal
        case .regular: return CoreSpacing.md     // 12pt — Primer medium.paddingInline.normal
        case .large: return CoreSpacing.md       // 12pt — Primer large.paddingInline.normal
        case .extraLarge: return CoreSpacing.md  // 12pt — Primer xlarge.paddingInline.normal
        @unknown default:
            return CoreSpacing.md
        }
    }

    // MARK: - verticalPadding

    /// 控件纵向 padding（pt）。包裹 label 的上下内边距。
    ///
    /// Primer `control.{size}.paddingBlock` 给出 `xsmall=2 / small=4 / medium=6 / large=10 /
    /// xlarge=14`。CoreSpacing 标度（2/4/8/12/16）覆盖前两档但不覆盖 6/10/14——本 token
    /// 在 regular 起就近上调到 CoreSpacing 档位（regular=8 / large=12 / extraLarge=16），
    /// 让 padding 始终命中 token，不出现魔法数字。这会让对应档位的总高度比 Primer 略增
    /// 2–4pt，组件层若需精确对齐可在外部 `frame(height:)` 显式强制 `height(for:)`。
    ///
    /// - Parameter controlSize: SwiftUI 环境 `\.controlSize`。
    /// - Returns: 该尺寸下推荐的上下 padding，单位 pt，必为 `CoreSpacing.*` 命名常量。
    public static func verticalPadding(for controlSize: ControlSize) -> CGFloat {
        switch controlSize {
        case .mini: return CoreSpacing.xxs       // 2pt — 与 Primer xsmall.paddingBlock 完全一致
        case .small: return CoreSpacing.xs       // 4pt — 与 Primer small.paddingBlock 完全一致
        case .regular: return CoreSpacing.sm     // 8pt — Primer medium 为 6，CoreSpacing 就近上调
        case .large: return CoreSpacing.md       // 12pt — Primer large 为 10，CoreSpacing 就近上调
        case .extraLarge: return CoreSpacing.lg  // 16pt — Primer xlarge 为 14，CoreSpacing 就近上调
        @unknown default:
            return CoreSpacing.sm
        }
    }

    // MARK: - primerVerticalPadding (escape hatch)

    /// **严格 Primer 高度路径**专用：返回 Primer `control.{size}.paddingBlock` 的精确值
    /// （xsmall=2 / small=4 / medium=6 / large=10 / xlarge=14）。
    ///
    /// 与 `verticalPadding(for:)` 的差别：本 helper 不上调到 `CoreSpacing` 档位——
    /// regular / large / extraLarge 三档分别返回 6 / 10 / 14（**这三档 Primer 取值不在
    /// CoreSpacing scale 上**）。代价是：调用方必须明确意图是"装得下 Primer 精确高度"，
    /// 否则默认仍应使用 `verticalPadding(for:)` 命中 CoreSpacing 标度。
    ///
    /// 仅当组件需要严格命中 `height(for:)` 的 Primer 精确值（搭配 `frame(height:)`
    /// 而非 `frame(minHeight:)`）时才用。一般场景默认 `verticalPadding(for:)`。
    ///
    /// 字面量集中在本 helper 的语义：避免组件层散落 6/10/14 这种非 token scale 的
    /// 魔法数字（与 `CoreSpacing` "组件不引入 padding 魔法数字"约定一致）。
    ///
    /// - Parameter controlSize: SwiftUI 环境 `\.controlSize`。
    /// - Returns: 该尺寸下 Primer `paddingBlock` 精确值（pt）。
    public static func primerVerticalPadding(for controlSize: ControlSize) -> CGFloat {
        switch controlSize {
        case .mini: return 2         // Primer xsmall.paddingBlock
        case .small: return 4        // Primer small.paddingBlock
        case .regular: return 6      // Primer medium.paddingBlock
        case .large: return 10       // Primer large.paddingBlock
        case .extraLarge: return 14  // Primer xlarge.paddingBlock
        @unknown default:
            return 6
        }
    }

    // MARK: - font

    /// 控件 label 推荐字号。直接返回 `CoreTypography.*Font`，调用方可选择是否再补 lineSpacing
    /// 与 tracking 三件套（按钮 / SegmentedControl / SearchField 多为单行容器，
    /// `lineSpacing` 不会显出视觉效果，省略亦可）。
    ///
    /// 档位映射理由：mini / small 走 `bodySmall`（12pt）保证密集 UI 不溢出；regular 走
    /// 推荐的默认 UI 字号 `bodyMedium`（14pt）；large / extraLarge 上抬到
    /// `bodyLarge`（16pt）/ `titleMedium`（20pt semibold），让 CTA 类按钮视觉权重与
    /// 较大尺寸的外框匹配。
    ///
    /// - Parameter controlSize: SwiftUI 环境 `\.controlSize`。
    /// - Returns: 该尺寸下推荐的 SwiftUI `Font`，必为 `CoreTypography.*Font` 命名常量。
    public static func font(for controlSize: ControlSize) -> Font {
        switch controlSize {
        case .mini: return CoreTypography.bodySmallFont       // 12pt regular
        case .small: return CoreTypography.bodySmallFont      // 12pt regular
        case .regular: return CoreTypography.bodyMediumFont   // 14pt regular — 默认 UI 字号
        case .large: return CoreTypography.bodyLargeFont      // 16pt regular
        case .extraLarge: return CoreTypography.titleMediumFont // 20pt semibold — CTA 视觉权重
        @unknown default:
            return CoreTypography.bodyMediumFont
        }
    }

    // MARK: - iconSize

    /// 控件内联 icon 边长（pt）。比对应字号约大 1.0–1.2 倍，以视觉等重原则与 label 文字
    /// 对齐——SF Symbol / SVG glyph 的视觉重心通常略低于 cap height，需要稍大边长才能感觉
    /// 与字母 x-height 等高。
    ///
    /// 取值参考：mini=12 (与 12pt 字 1.0×) / small=14 / regular=16 (≈14pt 字 × 1.14) /
    /// large=20 (16pt 字 × 1.25) / extraLarge=24 (20pt 字 × 1.20)。
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
