import SwiftUI

// MARK: - Status Colors (Primer 6-status × 4-variant)

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

    // MARK: Success (green)
    /// Primer `success.fg` — success / merged / CI pass foreground text.
    static let statusSuccessForeground: Color = Color("status-success-fg", bundle: .module)
    /// Primer `success.emphasis` — bold success background.
    static let statusSuccessEmphasis: Color = Color("status-success-emphasis", bundle: .module)
    /// Primer `success.muted` — muted success background.
    static let statusSuccessMuted: Color = Color("status-success-muted", bundle: .module)
    /// Primer `success.subtle` — faint success background.
    static let statusSuccessSubtle: Color = Color("status-success-subtle", bundle: .module)

    // MARK: Attention (yellow)
    /// Primer `attention.fg` — warning / pending / review foreground text.
    static let statusAttentionForeground: Color = Color("status-attention-fg", bundle: .module)
    /// Primer `attention.emphasis` — bold attention background.
    static let statusAttentionEmphasis: Color = Color("status-attention-emphasis", bundle: .module)
    /// Primer `attention.muted` — muted attention background.
    static let statusAttentionMuted: Color = Color("status-attention-muted", bundle: .module)
    /// Primer `attention.subtle` — faint attention background.
    static let statusAttentionSubtle: Color = Color("status-attention-subtle", bundle: .module)

    // MARK: Danger (red)
    /// Primer `danger.fg` — error / delete / blocked foreground text.
    static let statusDangerForeground: Color = Color("status-danger-fg", bundle: .module)
    /// Primer `danger.emphasis` — bold danger background.
    static let statusDangerEmphasis: Color = Color("status-danger-emphasis", bundle: .module)
    /// Primer `danger.muted` — muted danger background.
    static let statusDangerMuted: Color = Color("status-danger-muted", bundle: .module)
    /// Primer `danger.subtle` — faint danger background.
    static let statusDangerSubtle: Color = Color("status-danger-subtle", bundle: .module)

    // MARK: Done (purple)
    /// Primer `done.fg` — completed / closed / resolved foreground text.
    static let statusDoneForeground: Color = Color("status-done-fg", bundle: .module)
    /// Primer `done.emphasis` — bold done background.
    static let statusDoneEmphasis: Color = Color("status-done-emphasis", bundle: .module)
    /// Primer `done.muted` — muted done background.
    static let statusDoneMuted: Color = Color("status-done-muted", bundle: .module)
    /// Primer `done.subtle` — faint done background.
    static let statusDoneSubtle: Color = Color("status-done-subtle", bundle: .module)

    // MARK: Legacy compatibility (existing v1 API surface, preserved for callers)

    static let infoForeground = Color.blue7
    static let infoBackground = Color.blue1
    static let infoBorder = Color.blue3

    static let successForeground = Color.green7
    static let successBackground = Color.green1
    static let successBorder = Color.green3

    static let warningForeground = Color.orange7
    static let warningBackground = Color.orange1
    static let warningBorder = Color.orange3

    static let dangerForeground = Color.red7
    static let dangerBackground = Color.red1
    static let dangerBorder = Color.red3
}
