import SwiftUI
import Testing
@testable import CoreDesign

@Suite("StatusColors")
struct StatusColorsTests {
    @Test("accent status has 4 variants")
    func accentVariants() {
        let fg: Color = .statusAccentForeground
        let emphasis: Color = .statusAccentEmphasis
        let muted: Color = .statusAccentMuted
        let subtle: Color = .statusAccentSubtle
        #expect(fg != nil)
        #expect(emphasis != nil)
        #expect(muted != nil)
        #expect(subtle != nil)
    }

    @Test("success status has 4 variants")
    func successVariants() {
        let fg: Color = .statusSuccessForeground
        let emphasis: Color = .statusSuccessEmphasis
        let muted: Color = .statusSuccessMuted
        let subtle: Color = .statusSuccessSubtle
        #expect(fg != nil)
        #expect(emphasis != nil)
        #expect(muted != nil)
        #expect(subtle != nil)
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

    @Test("existing info/warning/danger/success foreground-background-border tokens preserved")
    func existingTokensPreserved() {
        let _: Color = .infoForeground
        let _: Color = .infoBackground
        let _: Color = .infoBorder
        let _: Color = .successForeground
        let _: Color = .successBackground
        let _: Color = .successBorder
        let _: Color = .warningForeground
        let _: Color = .warningBackground
        let _: Color = .warningBorder
        let _: Color = .dangerForeground
        let _: Color = .dangerBackground
        let _: Color = .dangerBorder
    }
}
