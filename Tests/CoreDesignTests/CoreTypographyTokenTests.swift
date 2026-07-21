import Testing
import SwiftUI
@testable import CoreDesign

@Suite("CoreTypography.Token")
struct CoreTypographyTokenTests {
    @Test("基准字号与 Primer 对齐，且未漂移")
    func baseSizes() {
        #expect(CoreTypography.Token.displayLarge.spec.size == 40)
        #expect(CoreTypography.Token.titleLarge.spec.size == 32)
        #expect(CoreTypography.Token.titleMedium.spec.size == 20)
        #expect(CoreTypography.Token.titleSmall.spec.size == 16)
        #expect(CoreTypography.Token.subtitle.spec.size == 20)
        #expect(CoreTypography.Token.bodyLarge.spec.size == 16)
        #expect(CoreTypography.Token.bodyMedium.spec.size == 14)
        #expect(CoreTypography.Token.bodySmall.spec.size == 12)
        #expect(CoreTypography.Token.caption.spec.size == 12)
        #expect(CoreTypography.Token.captionMono.spec.size == 12)
        #expect(CoreTypography.Token.captionSmall.spec.size == 9)
    }

    @Test("captionSmall 明确不缩放，其余缩放")
    func scalingFlags() {
        #expect(CoreTypography.Token.captionSmall.spec.scales == false)
        for t in CoreTypography.Token.allCases where t != .captionSmall {
            #expect(t.spec.scales == true, "\(t) 应缩放")
        }
    }

    @Test("captionMono 是等宽")
    func monoFlag() {
        #expect(CoreTypography.Token.captionMono.spec.monospaced == true)
        #expect(CoreTypography.Token.caption.spec.monospaced == false)
    }
}
