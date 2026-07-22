import Testing
import SwiftUI
@testable import CoreDesign

// Issue #119 把 `CoreTypography.Token` 从手写 Primer 字号表改为直接映射系统文本样式，
// `Spec` 类型本身被删除。旧版本断言 Primer 字号表与 `captionSmall.scales == false` 的
// 整套测试因此作废，本文件按新契约重写。
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

    @Test("9 个弃用别名解析到映射固定的新档位")
    func deprecatedAliasesResolveToMappedToken() {
        #expect(CoreTypography.Token.displayLarge == .largeTitle)
        #expect(CoreTypography.Token.titleLarge == .title)
        #expect(CoreTypography.Token.titleMedium == .title2)
        #expect(CoreTypography.Token.subtitle == .title3)
        #expect(CoreTypography.Token.titleSmall == .headline)
        #expect(CoreTypography.Token.bodyLarge == .body)
        #expect(CoreTypography.Token.bodyMedium == .callout)
        #expect(CoreTypography.Token.bodySmall == .footnote)
        #expect(CoreTypography.Token.captionSmall == .caption2)
    }

    @Test("旧 *Font static var 仍可用，指向对应新档位的 font")
    func legacyFontStaticVarsStillResolve() {
        // 这些断言本身会触发弃用 warning（预期内），验证的是弃用别名在删除前
        // 仍然指向正确的新实现，而不是编译期悄悄断链。
        #expect(String(describing: CoreTypography.displayLargeFont) == String(describing: CoreTypography.Token.largeTitle.font))
        #expect(String(describing: CoreTypography.captionSmallFont) == String(describing: CoreTypography.Token.caption2.font))
    }
}
