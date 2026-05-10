import SwiftUI
import Testing
@testable import CoreDesign

@Suite("Badge")
struct BadgeTests {
    @Test("designated init stores variant + outlined + label without erasure")
    func designatedInitPreservesParameters() {
        let badge = Badge(variant: .info, outlined: true) {
            Text("Beta")
        }
        #expect(badge.variant == .info)
        #expect(badge.outlined == true)
    }

    @Test("convenience text init defaults variant to neutral and outlined to false")
    func convenienceTextInitDefaults() {
        let badge = Badge("v1.0")
        #expect(badge.variant == .neutral)
        #expect(badge.outlined == false)
    }

    @Test("convenience text init forwards variant + outlined")
    func convenienceTextInitForwardsParameters() {
        let badge = Badge("Draft", variant: .warning, outlined: true)
        #expect(badge.variant == .warning)
        #expect(badge.outlined == true)
    }

    @Test(
        "BadgeVariant covers the 5 status indicator levels",
        arguments: [BadgeVariant.info, .success, .warning, .danger, .neutral]
    )
    func variantIsConstructibleForAllLevels(_ variant: BadgeVariant) {
        let badge = Badge("status", variant: variant)
        #expect(badge.variant == variant)
    }
}

extension BadgeVariant: @retroactive Equatable {
    public static func == (lhs: BadgeVariant, rhs: BadgeVariant) -> Bool {
        switch (lhs, rhs) {
        case (.info, .info), (.success, .success), (.warning, .warning),
             (.danger, .danger), (.neutral, .neutral):
            true
        default:
            false
        }
    }
}
