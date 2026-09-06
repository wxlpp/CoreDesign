import SwiftUI
import Testing
@testable import CoreDesign

@Suite("StatusColors")
struct StatusColorsTests {
    @Test("status token 各指向正确的 colorset asset")
    func statusColorsMapToCorrectAssets() {
        #expect(assetName(of: .statusAccentForeground) == "status-accent-fg")
        #expect(assetName(of: .statusAccentEmphasis) == "status-accent-emphasis")
        #expect(assetName(of: .statusAccentMuted) == "status-accent-muted")
        #expect(assetName(of: .statusAccentSubtle) == "status-accent-subtle")
        #expect(assetName(of: .statusAccentBorder) == "status-accent-border")
        #expect(assetName(of: .statusSuccessForeground) == "status-success-fg")
        #expect(assetName(of: .statusSuccessEmphasis) == "status-success-emphasis")
        #expect(assetName(of: .statusSuccessMuted) == "status-success-muted")
        #expect(assetName(of: .statusSuccessSubtle) == "status-success-subtle")
        #expect(assetName(of: .statusSuccessBorder) == "status-success-border")
        #expect(assetName(of: .statusAttentionForeground) == "status-attention-fg")
        #expect(assetName(of: .statusAttentionEmphasis) == "status-attention-emphasis")
        #expect(assetName(of: .statusAttentionMuted) == "status-attention-muted")
        #expect(assetName(of: .statusAttentionSubtle) == "status-attention-subtle")
        #expect(assetName(of: .statusAttentionBorder) == "status-attention-border")
        #expect(assetName(of: .statusDangerForeground) == "status-danger-fg")
        #expect(assetName(of: .statusDangerEmphasis) == "status-danger-emphasis")
        #expect(assetName(of: .statusDangerMuted) == "status-danger-muted")
        #expect(assetName(of: .statusDangerSubtle) == "status-danger-subtle")
        #expect(assetName(of: .statusDangerBorder) == "status-danger-border")
        #expect(assetName(of: .statusDoneForeground) == "status-done-fg")
        #expect(assetName(of: .statusDoneEmphasis) == "status-done-emphasis")
        #expect(assetName(of: .statusDoneMuted) == "status-done-muted")
        #expect(assetName(of: .statusDoneSubtle) == "status-done-subtle")
    }
}
