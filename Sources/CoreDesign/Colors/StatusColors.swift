import SwiftUI

// MARK: - Status Colors (Primer-style 5-status × 4-variant)
//
// Implemented: accent / success / attention / danger / done.
// Primer's `neutral` family is intentionally omitted — neutral fills/text
// are already covered by the `FillColors` / `ContentColors` layers above.
//
// Issue #120 定案：StatusColors 全体保持现值。Primer 的 5-status × 4-variant 语义
// （accent/success/attention/danger/done 各自的 fg/emphasis/muted/subtle/border）
// 在 Apple HIG 里没有系统对应物——不存在"系统级的成功色/警示色语义色板"这类桥接
// 目标，因此本任务的"改指系统色"不适用于本文件，全部 24 个 token 保持现值。
//
// 孤儿符号定案（Issue #120 AC 明确要求逐一定案，而非沉默保留）：
//
// - `statusAccentEmphasis`（本文件 :15 附近）——已因 Issue #117 删除
//   `TimelineItem`（其在 App 预览宿主的唯一消费点）而失去全部生产消费者。
// - 另有 6 个在 Issue #117 之前就已无生产消费者：`statusAccentMuted` /
//   `statusSuccessMuted` / `statusAttentionMuted` / `statusDangerMuted` /
//   `statusDoneMuted` / `statusDoneSubtle`。
//
// **定案：全部保留**，不删除符号、不删除对应 colorset、不改动
// `StatusColorsTests.swift` 的断言。理由：
// 1. 本层是 `public` API——下游调用方可能直接引用这些 token 自建状态类 UI
//    （例如自定义的"已归档"/"草稿"提示），仓库内部消费点的多寡不等价于该符号
//    对外部使用者的价值；删除属破坏性变更，理应经 Task #122（同名换值 / API 面
//    收敛）或 #126（BREAKING-CHANGES 汇总）的正式流程评估，而不是在"重铸映射"
//    任务里顺手清理。
// 2. 这 5 组状态色是按"Primer 5-status × 4-variant"系统性设计的完整色板
//    （每个状态都是 fg/emphasis/muted/subtle[/border] 的对称结构），仓库内组件
//    目前只按需接入了其中一部分变体，未接入不代表该变体设计上是多余的——例如
//    `statusDoneForeground` 也无生产消费者但不在这次点名的孤儿名单里，说明
//    "有无消费者"本就不是这批色板的取舍依据，删除会打破色板的系统性、只留下
//    被组件偶然选中的子集。
//
// 唯一实际处置的孤儿相关项：无——上述 7 个符号（含 `statusDoneForeground`）
// 均保留，`StatusColorsTests.swift` 的 24 项断言不改动。

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
