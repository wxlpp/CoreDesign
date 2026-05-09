//
//  CoreTypography.swift
//  CoreDesign
//
//  Source of truth: docs/PRIMER_VERSION.md
//

import CoreGraphics
import SwiftUI

// MARK: - CoreTypography

/// 字体 token，对齐 Primer Primitives `functional/typography/typography.json5`
/// 中的 `text.*` text styles（display / title / subtitle / body / caption）。
///
/// 调用方式（caseless enum + 三件套：Font / LineSpacing / Tracking）：
///
/// ```swift
/// Text("Hello, world.")
///     .font(CoreTypography.bodyMediumFont)
///     .lineSpacing(CoreTypography.bodyMediumLineSpacing)
///     .tracking(CoreTypography.bodyMediumTracking)
/// ```
///
/// ## SwiftUI ↔ Primer 对应关系
///
/// - Primer `fontSize` (rem → pt @1rem=16pt) → SwiftUI `Font.system(size:weight:)`
/// - Primer `lineHeight`（**multiplier**，如 1.5 / 1.625）→ SwiftUI `lineSpacing` 形式：
///   先把 multiplier 还原成绝对 pt（`fontSize * lineHeightMultiplier`），再减字号本身：
///   `lineSpacing = max(0, fontSize * lineHeightMultiplier - fontSize)`
///   等价于 `fontSize * max(0, lineHeightMultiplier - 1)`。
///   （SwiftUI `lineSpacing` 是「行间距」而非「行高」，需把 Primer 行高减去字号才是补偿值。）
/// - Primer 当前锁定版本（见 `docs/PRIMER_VERSION.md`）的 typography 文件**未定义**
///   letter-spacing token，故所有档位 `*Tracking = 0`；保留接口以便未来 Primer
///   引入字距时无破坏式扩展。
///
/// > Important: 单行容器（按钮 label、SegmentedControl 选项、ListRow 单行文本、
/// > Toolbar item 等）观察不到 `lineSpacing` 的视觉效果——`lineSpacing` 只作用于
/// > 文本的*行与行之间*，单行无相邻行可补偿。**这是 SwiftUI 的预期行为，不视为缺陷。**
/// > 仍然推荐统一调用三件套，组件未来切换为多行（譬如 `Text` 自动换行）时无需改动。
///
/// > Note: 取值参考 docs/PRIMER_VERSION.md 锁定的 Primer 版本。
/// > Primer 用 `1rem = 16px`，本文件直接以 pt 为单位（Apple 平台 1pt ≈ 1px @1x）。
public enum CoreTypography {

    // MARK: - Display

    /// Display Large。对应 Primer `text.display`。
    /// fontSize 40 / lineHeight 1.375 (snug) / weight medium (500)。
    /// Hero / 落地页 / 品牌过渡页用，窄视口建议降级到 `titleLarge`。
    ///
    /// 单行容器（按钮 label / 列表行）不会观察到 lineSpacing 效果，这是预期行为，不视为缺陷。
    public static let displayLargeFont: Font = .system(size: 40, weight: .medium)

    // lineSpacing = max(0, fontSize * lineHeightMultiplier - fontSize) = max(0, 40 * 1.375 - 40) = 15
    public static let displayLargeLineSpacing: CGFloat = 15

    public static let displayLargeTracking: CGFloat = 0

    // MARK: - Title

    /// Title Large。对应 Primer `text.title.large`。
    /// fontSize 32 / lineHeight 1.5 (normal) / weight semibold (600)。
    /// 用户生成对象的页面标题（Issue / PR title），窄视口降级到 `titleMedium`。
    ///
    /// 单行容器（按钮 label / 列表行）不会观察到 lineSpacing 效果，这是预期行为，不视为缺陷。
    public static let titleLargeFont: Font = .system(size: 32, weight: .semibold)

    // lineSpacing = max(0, fontSize * lineHeightMultiplier - fontSize) = max(0, 32 * 1.5 - 32) = 16
    public static let titleLargeLineSpacing: CGFloat = 16

    public static let titleLargeTracking: CGFloat = 0

    /// Title Medium。对应 Primer `text.title.medium`。
    /// fontSize 20 / lineHeight 1.625 (relaxed) / weight semibold (600)。
    /// 推荐的默认页面标题；Section 标题、Dialog 标题。
    ///
    /// 单行容器（按钮 label / 列表行）不会观察到 lineSpacing 效果，这是预期行为，不视为缺陷。
    public static let titleMediumFont: Font = .system(size: 20, weight: .semibold)

    // lineSpacing = max(0, fontSize * lineHeightMultiplier - fontSize) = max(0, 20 * 1.625 - 20) = 12.5
    public static let titleMediumLineSpacing: CGFloat = 12.5

    public static let titleMediumTracking: CGFloat = 0

    /// Title Small。对应 Primer `text.title.small`。
    /// fontSize 16 / lineHeight 1.5 (normal) / weight semibold (600)。
    /// 与 `bodyLarge` 同字号，semibold 加粗以作章节内子标题；List title / 侧栏标题。
    ///
    /// 单行容器（按钮 label / 列表行）不会观察到 lineSpacing 效果，这是预期行为，不视为缺陷。
    public static let titleSmallFont: Font = .system(size: 16, weight: .semibold)

    // lineSpacing = max(0, fontSize * lineHeightMultiplier - fontSize) = max(0, 16 * 1.5 - 16) = 8
    public static let titleSmallLineSpacing: CGFloat = 8

    public static let titleSmallTracking: CGFloat = 0

    // MARK: - Subtitle

    /// Subtitle。对应 Primer `text.subtitle`。
    /// fontSize 20 / lineHeight 1.625 (relaxed) / weight normal (400)。
    /// 标题下方的辅助说明文字；与 `titleMedium` 同字号同行高，仅 weight 区分。
    ///
    /// 单行容器（按钮 label / 列表行）不会观察到 lineSpacing 效果，这是预期行为，不视为缺陷。
    public static let subtitleFont: Font = .system(size: 20, weight: .regular)

    // lineSpacing = max(0, fontSize * lineHeightMultiplier - fontSize) = max(0, 20 * 1.625 - 20) = 12.5
    public static let subtitleLineSpacing: CGFloat = 12.5

    public static let subtitleTracking: CGFloat = 0

    // MARK: - Body

    /// Body Large。对应 Primer `text.body.large`。
    /// fontSize 16 / lineHeight 1.5 (normal) / weight normal (400)。
    /// 用户生成内容（Markdown 渲染、文章正文、长评论）。
    ///
    /// 单行容器（按钮 label / 列表行）不会观察到 lineSpacing 效果，这是预期行为，不视为缺陷。
    public static let bodyLargeFont: Font = .system(size: 16, weight: .regular)

    // lineSpacing = max(0, fontSize * lineHeightMultiplier - fontSize) = max(0, 16 * 1.5 - 16) = 8
    public static let bodyLargeLineSpacing: CGFloat = 8

    public static let bodyLargeTracking: CGFloat = 0

    /// Body Medium。对应 Primer `text.body.medium`。
    /// fontSize 14 / lineHeight 1.5 (normal) / weight normal (400)。
    /// **推荐的默认 UI 文字**：按钮 label、表单 label、导航、绝大多数界面文字。
    ///
    /// 单行容器（按钮 label / 列表行）不会观察到 lineSpacing 效果，这是预期行为，不视为缺陷。
    public static let bodyMediumFont: Font = .system(size: 14, weight: .regular)

    // lineSpacing = max(0, fontSize * lineHeightMultiplier - fontSize) = max(0, 14 * 1.5 - 14) = 7
    public static let bodyMediumLineSpacing: CGFloat = 7

    public static let bodyMediumTracking: CGFloat = 0

    /// Body Small。对应 Primer `text.body.small`。
    /// fontSize 12 / lineHeight 1.625 (relaxed) / weight normal (400)。
    /// 辅助文字（helper / footnote / metadata / timestamp），慎用，不建议作为主要内容。
    ///
    /// 单行容器（按钮 label / 列表行）不会观察到 lineSpacing 效果，这是预期行为，不视为缺陷。
    public static let bodySmallFont: Font = .system(size: 12, weight: .regular)

    // lineSpacing = max(0, fontSize * lineHeightMultiplier - fontSize) = max(0, 12 * 1.625 - 12) = 7.5
    public static let bodySmallLineSpacing: CGFloat = 7.5

    public static let bodySmallTracking: CGFloat = 0

    // MARK: - Caption

    /// Caption。对应 Primer `text.caption`。
    /// fontSize 12 / lineHeight 1.25 (tight) / weight normal (400)。
    /// 紧凑场景：Badge text、单行 metadata、单行 label。
    /// Primer 提示：caption 不满足 body text 的可访问性要求，仅用于单行/极短文本。
    ///
    /// 单行容器（按钮 label / 列表行）不会观察到 lineSpacing 效果，这是预期行为，不视为缺陷。
    public static let captionFont: Font = .system(size: 12, weight: .regular)

    // lineSpacing = max(0, fontSize * lineHeightMultiplier - fontSize) = max(0, 12 * 1.25 - 12) = 3
    public static let captionLineSpacing: CGFloat = 3

    public static let captionTracking: CGFloat = 0
}
