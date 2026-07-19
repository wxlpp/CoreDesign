import SwiftUI
import Testing
@testable import CoreDesign

@Suite("StatusColors")
@MainActor
struct StatusColorsTests {
    @Test("accent status has 4 variants")
    func accentVariants() {
        let _: Color = .statusAccentForeground
        let _: Color = .statusAccentEmphasis
        let _: Color = .statusAccentMuted
        let _: Color = .statusAccentSubtle
    }

    @Test("success status has 4 variants")
    func successVariants() {
        let _: Color = .statusSuccessForeground
        let _: Color = .statusSuccessEmphasis
        let _: Color = .statusSuccessMuted
        let _: Color = .statusSuccessSubtle
    }

    @Test("attention status has 4 variants")
    func attentionVariants() {
        let _: Color = .statusAttentionForeground
        let _: Color = .statusAttentionEmphasis
        let _: Color = .statusAttentionMuted
        let _: Color = .statusAttentionSubtle
    }

    @Test("danger status has 4 variants")
    func dangerVariants() {
        let _: Color = .statusDangerForeground
        let _: Color = .statusDangerEmphasis
        let _: Color = .statusDangerMuted
        let _: Color = .statusDangerSubtle
    }

    @Test("done status has 4 variants")
    func doneVariants() {
        let _: Color = .statusDoneForeground
        let _: Color = .statusDoneEmphasis
        let _: Color = .statusDoneMuted
        let _: Color = .statusDoneSubtle
    }
}
