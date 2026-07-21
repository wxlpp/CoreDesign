import SwiftUI
import Testing
@testable import CoreDesign

// Status 色的**真行为断言**（C2）：断言 status 语义 token 各指向正确的 colorset asset。
// 共 24 个：accent/success/attention/danger 各 5 档（fg/emphasis/muted/subtle/border），
// done 仅 4 档（无 border——B6c 只为前四家族补了 border colorset）。
//
// 旧版是 `let _: Color = .statusAccentForeground` ——只验证符号编译通过（恒真、
// 0 `#expect`）。改写后断言每个 token 的 asset 名（共享 `assetName`，见 TestSupport.swift），
// 能捕获「status 色被误指向别的 colorset」这类真实回退。
@Suite("StatusColors")
struct StatusColorsTests {

    @Test("status token 各指向正确的 colorset asset")
    func statusColorsMapToCorrectAssets() {
        // accent
        #expect(assetName(of: .statusAccentForeground) == "status-accent-fg")
        #expect(assetName(of: .statusAccentEmphasis) == "status-accent-emphasis")
        #expect(assetName(of: .statusAccentMuted) == "status-accent-muted")
        #expect(assetName(of: .statusAccentSubtle) == "status-accent-subtle")
        #expect(assetName(of: .statusAccentBorder) == "status-accent-border")
        // success
        #expect(assetName(of: .statusSuccessForeground) == "status-success-fg")
        #expect(assetName(of: .statusSuccessEmphasis) == "status-success-emphasis")
        #expect(assetName(of: .statusSuccessMuted) == "status-success-muted")
        #expect(assetName(of: .statusSuccessSubtle) == "status-success-subtle")
        #expect(assetName(of: .statusSuccessBorder) == "status-success-border")
        // attention
        #expect(assetName(of: .statusAttentionForeground) == "status-attention-fg")
        #expect(assetName(of: .statusAttentionEmphasis) == "status-attention-emphasis")
        #expect(assetName(of: .statusAttentionMuted) == "status-attention-muted")
        #expect(assetName(of: .statusAttentionSubtle) == "status-attention-subtle")
        #expect(assetName(of: .statusAttentionBorder) == "status-attention-border")
        // danger
        #expect(assetName(of: .statusDangerForeground) == "status-danger-fg")
        #expect(assetName(of: .statusDangerEmphasis) == "status-danger-emphasis")
        #expect(assetName(of: .statusDangerMuted) == "status-danger-muted")
        #expect(assetName(of: .statusDangerSubtle) == "status-danger-subtle")
        #expect(assetName(of: .statusDangerBorder) == "status-danger-border")
        // done（无 border 档）
        #expect(assetName(of: .statusDoneForeground) == "status-done-fg")
        #expect(assetName(of: .statusDoneEmphasis) == "status-done-emphasis")
        #expect(assetName(of: .statusDoneMuted) == "status-done-muted")
        #expect(assetName(of: .statusDoneSubtle) == "status-done-subtle")
    }
}
