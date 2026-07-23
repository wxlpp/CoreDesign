import SwiftUI

// MARK: - Status Colors (5-status × 4-variant)
//
// Implemented: accent / success / attention / danger / done. A `neutral`
// family is intentionally omitted — neutral fills/text are already covered
// by the `FillColors` / `ContentColors` layers above.
//
// 这 5 组状态色的语义（accent/success/attention/danger/done 各自的
// fg/emphasis/muted/subtle/border）在 Apple HIG 里没有系统对应物——不存在
// "系统级的成功色/警示色语义色板"这类桥接目标，全部 24 个 token 保持自有取值，
// 不改指系统色。
//
// 部分 token（`statusAccentEmphasis`、`statusAccentMuted` / `statusSuccessMuted` /
// `statusAttentionMuted` / `statusDangerMuted` / `statusDoneMuted` /
// `statusDoneSubtle`）当前在仓库内没有生产消费者，**仍全部保留**，不删除符号、
// 不删除对应 colorset、不改动 `StatusColorsTests.swift` 的断言。理由：
// 1. 本层是 `public` API——下游调用方可能直接引用这些 token 自建状态类 UI
//    （例如自定义的"已归档"/"草稿"提示），仓库内部消费点的多寡不等价于该符号
//    对外部使用者的价值；删除属破坏性变更，需要独立的公开 API 收敛评估，
//    而非在色板取值调整时顺手清理。
// 2. 这 5 组状态色是按"5-status × 4-variant"系统性设计的完整色板（每个状态都是
//    fg/emphasis/muted/subtle[/border] 的对称结构），仓库内组件目前只按需接入了
//    其中一部分变体，未接入不代表该变体设计上是多余的——例如 `statusDoneForeground`
//    同样无生产消费者，说明"有无消费者"本就不是这批色板的取舍依据，删除会打破
//    色板的系统性、只留下被组件偶然选中的子集。

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
