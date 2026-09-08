import Testing
import SwiftUI
@testable import OhMyDesign

@Suite("CoreTypography.Token")
struct CoreTypographyTokenTests {
    @Test("12 档一一对应系统文本样式")
    func textStyleMapping() {
        #expect(CoreTypography.Token.largeTitle.textStyle == .largeTitle)
        #expect(CoreTypography.Token.title.textStyle == .title)
        #expect(CoreTypography.Token.title2.textStyle == .title2)
        #expect(CoreTypography.Token.title3.textStyle == .title3)
        #expect(CoreTypography.Token.headline.textStyle == .headline)
        #expect(CoreTypography.Token.body.textStyle == .body)
        #expect(CoreTypography.Token.callout.textStyle == .callout)
        #expect(CoreTypography.Token.subheadline.textStyle == .subheadline)
        #expect(CoreTypography.Token.footnote.textStyle == .footnote)
        #expect(CoreTypography.Token.caption.textStyle == .caption)
        #expect(CoreTypography.Token.captionMono.textStyle == .caption)
        #expect(CoreTypography.Token.caption2.textStyle == .caption2)
    }

    @Test("仅 captionMono 是等宽")
    func monospacedFlag() {
        #expect(CoreTypography.Token.captionMono.isMonospaced == true)
        for t in CoreTypography.Token.allCases where t != .captionMono {
            #expect(t.isMonospaced == false, "\(t) 不应是等宽")
        }
    }

    @Test("恰好 12 档，无隐藏 case")
    func allCasesCount() {
        #expect(CoreTypography.Token.allCases.count == 12)
    }
}
