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

    // Task #121 完成全部调用点迁移后，删除了 9 个 `@available(deprecated, renamed:)`
    // Token 别名与 10 个旧 `*Font` static var——曾在此验证它们解析到正确新档位的两个
    // 测试（`deprecatedAliasesResolveToMappedToken` / `legacyFontStaticVarsStillResolve`）
    // 随别名一起删除：别名本身不存在了，断言"别名解析正确"无对象可测。
}
