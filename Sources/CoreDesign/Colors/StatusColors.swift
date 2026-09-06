import SwiftUI

// MARK: - Status Colors (5-status × 4-variant)

public extension Color {
    // MARK: Accent (blue)

    /// 强调前景色：链接 / focus / 选中态文字。
    static let statusAccentForeground: Color = Color("status-accent-fg", bundle: .module)
    /// 强调实色背景：选中行、激活开关等需要强对比的场景。
    static let statusAccentEmphasis: Color = Color("status-accent-emphasis", bundle: .module)
    /// 强调弱化背景：hover 态。
    static let statusAccentMuted: Color = Color("status-accent-muted", bundle: .module)
    /// 强调淡背景：选中高亮。
    static let statusAccentSubtle: Color = Color("status-accent-subtle", bundle: .module)

    /// 边框色。本仓库为 status 家族保留的独立 border 档，取值沿用重构前 legacy
    /// 组使用的原子色 3 档，保持既有视觉决定。
    static let statusAccentBorder: Color = Color("status-accent-border", bundle: .module)

    // MARK: Success (green)

    /// 成功前景色：成功 / 已合并 / CI 通过文字。
    static let statusSuccessForeground: Color = Color("status-success-fg", bundle: .module)
    /// 成功实色背景。
    static let statusSuccessEmphasis: Color = Color("status-success-emphasis", bundle: .module)
    /// 成功弱化背景。
    static let statusSuccessMuted: Color = Color("status-success-muted", bundle: .module)
    /// 成功淡背景。
    static let statusSuccessSubtle: Color = Color("status-success-subtle", bundle: .module)

    /// 边框色。本仓库为 status 家族保留的独立 border 档，取值沿用重构前 legacy
    /// 组使用的原子色 3 档，保持既有视觉决定。
    static let statusSuccessBorder: Color = Color("status-success-border", bundle: .module)

    // MARK: Attention (yellow)

    /// 警示前景色：警告 / 待处理 / 待审阅文字。
    static let statusAttentionForeground: Color = Color("status-attention-fg", bundle: .module)
    /// 警示实色背景。
    static let statusAttentionEmphasis: Color = Color("status-attention-emphasis", bundle: .module)
    /// 警示弱化背景。
    static let statusAttentionMuted: Color = Color("status-attention-muted", bundle: .module)
    /// 警示淡背景。
    static let statusAttentionSubtle: Color = Color("status-attention-subtle", bundle: .module)

    /// 边框色。本仓库为 status 家族保留的独立 border 档，取值沿用重构前 legacy
    /// 组使用的原子色 3 档，保持既有视觉决定。
    static let statusAttentionBorder: Color = Color("status-attention-border", bundle: .module)

    // MARK: Danger (red)

    /// 危险前景色：错误 / 删除 / 已拒绝文字。
    static let statusDangerForeground: Color = Color("status-danger-fg", bundle: .module)
    /// 危险实色背景。
    static let statusDangerEmphasis: Color = Color("status-danger-emphasis", bundle: .module)
    /// 危险弱化背景。
    static let statusDangerMuted: Color = Color("status-danger-muted", bundle: .module)
    /// 危险淡背景。
    static let statusDangerSubtle: Color = Color("status-danger-subtle", bundle: .module)

    /// 边框色。本仓库为 status 家族保留的独立 border 档，取值沿用重构前 legacy
    /// 组使用的原子色 3 档，保持既有视觉决定。
    static let statusDangerBorder: Color = Color("status-danger-border", bundle: .module)

    // MARK: Done (purple)

    /// 完成前景色：已完成 / 已关闭 / 已解决文字。
    static let statusDoneForeground: Color = Color("status-done-fg", bundle: .module)
    /// 完成实色背景。
    static let statusDoneEmphasis: Color = Color("status-done-emphasis", bundle: .module)
    /// 完成弱化背景。
    static let statusDoneMuted: Color = Color("status-done-muted", bundle: .module)
    /// 完成淡背景。
    static let statusDoneSubtle: Color = Color("status-done-subtle", bundle: .module)
}
