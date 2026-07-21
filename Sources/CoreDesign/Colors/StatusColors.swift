import SwiftUI

// MARK: - Status Colors (Primer-style 5-status × 4-variant)
//
// Implemented: accent / success / attention / danger / done.
// Primer's `neutral` family is intentionally omitted — neutral fills/text
// are already covered by the `FillColors` / `ContentColors` layers above.

public extension Color {

    // MARK: Accent (blue)
    /// Primer `accent.fg` — link / focus / selection foreground text.
    static let statusAccentForeground: Color = Color("status-accent-fg", bundle: .module)
    /// Primer `accent.emphasis` — bold accent background (selected row, active toggle).
    static let statusAccentEmphasis: Color = Color("status-accent-emphasis", bundle: .module)
    /// Primer `accent.muted` — muted accent background (hover state).
    static let statusAccentMuted: Color = Color("status-accent-muted", bundle: .module)
    /// Primer `accent.subtle` — faint accent background (selection highlight).
    static let statusAccentSubtle: Color = Color("status-accent-subtle", bundle: .module)

    /// 边框色。本仓库为 status 家族保留的独立 border 档，取值沿用重构前 legacy
    /// 组使用的原子色 3 档，保持既有视觉决定。
    static let statusAccentBorder: Color = Color("status-accent-border", bundle: .module)

    // MARK: Success (green)
    /// Primer `success.fg` — success / merged / CI pass foreground text.
    static let statusSuccessForeground: Color = Color("status-success-fg", bundle: .module)
    /// Primer `success.emphasis` — bold success background.
    static let statusSuccessEmphasis: Color = Color("status-success-emphasis", bundle: .module)
    /// Primer `success.muted` — muted success background.
    static let statusSuccessMuted: Color = Color("status-success-muted", bundle: .module)
    /// Primer `success.subtle` — faint success background.
    static let statusSuccessSubtle: Color = Color("status-success-subtle", bundle: .module)

    /// 边框色。本仓库为 status 家族保留的独立 border 档，取值沿用重构前 legacy
    /// 组使用的原子色 3 档，保持既有视觉决定。
    static let statusSuccessBorder: Color = Color("status-success-border", bundle: .module)

    // MARK: Attention (yellow)
    /// Primer `attention.fg` — warning / pending / review foreground text.
    static let statusAttentionForeground: Color = Color("status-attention-fg", bundle: .module)
    /// Primer `attention.emphasis` — bold attention background.
    static let statusAttentionEmphasis: Color = Color("status-attention-emphasis", bundle: .module)
    /// Primer `attention.muted` — muted attention background.
    static let statusAttentionMuted: Color = Color("status-attention-muted", bundle: .module)
    /// Primer `attention.subtle` — faint attention background.
    static let statusAttentionSubtle: Color = Color("status-attention-subtle", bundle: .module)

    /// 边框色。本仓库为 status 家族保留的独立 border 档，取值沿用重构前 legacy
    /// 组使用的原子色 3 档，保持既有视觉决定。
    static let statusAttentionBorder: Color = Color("status-attention-border", bundle: .module)

    // MARK: Danger (red)
    /// Primer `danger.fg` — error / delete / blocked foreground text.
    static let statusDangerForeground: Color = Color("status-danger-fg", bundle: .module)
    /// Primer `danger.emphasis` — bold danger background.
    static let statusDangerEmphasis: Color = Color("status-danger-emphasis", bundle: .module)
    /// Primer `danger.muted` — muted danger background.
    static let statusDangerMuted: Color = Color("status-danger-muted", bundle: .module)
    /// Primer `danger.subtle` — faint danger background.
    static let statusDangerSubtle: Color = Color("status-danger-subtle", bundle: .module)

    /// 边框色。本仓库为 status 家族保留的独立 border 档，取值沿用重构前 legacy
    /// 组使用的原子色 3 档，保持既有视觉决定。
    static let statusDangerBorder: Color = Color("status-danger-border", bundle: .module)

    // MARK: Done (purple)
    /// Primer `done.fg` — completed / closed / resolved foreground text.
    static let statusDoneForeground: Color = Color("status-done-fg", bundle: .module)
    /// Primer `done.emphasis` — bold done background.
    static let statusDoneEmphasis: Color = Color("status-done-emphasis", bundle: .module)
    /// Primer `done.muted` — muted done background.
    static let statusDoneMuted: Color = Color("status-done-muted", bundle: .module)
    /// Primer `done.subtle` — faint done background.
    static let statusDoneSubtle: Color = Color("status-done-subtle", bundle: .module)
}
