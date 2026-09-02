import SwiftUI
import Testing
@testable import CoreDesign

@Suite("SearchField")
struct SearchFieldTests {
    @MainActor
    @Test("search field constructs with default placeholder")
    func searchFieldConstructsWithDefaultPlaceholder() {
        let field = SearchField(text: .constant(""))
        #expect(type(of: field) == SearchField.self)
    }

    @MainActor
    @Test("search field constructs with submit handler")
    func searchFieldConstructsWithSubmitHandler() {
        let field = SearchField(text: .constant("query"), placeholder: "Filter") { _ in }

        #expect(type(of: field) == SearchField.self)
    }
}

// MARK: - a11y 串的本地化（Issue #222）

@Suite("SearchField a11y 本地化")
@MainActor
struct SearchFieldL10nTests {
    @Test("placeholder 为空时，清除按钮的可访问名内外层都走 catalog")
    func clearLabelLocalizesBothLayers() {
        let label = SearchField.clearLabel(for: "")
        // 外层位置键 "Clear %@" + **插值内层** 的 "search" fallback。
        // 内层那个是按行扫描的守卫看不见的形态——本断言是它唯一的运行时覆盖。
        #expect(label == "Clear search", "内外层未都走 catalog：\(label)")
    }

    @Test("placeholder 非空时用调用方传入值，库不翻译它")
    func clearLabelKeepsCallerPlaceholder() {
        #expect(SearchField.clearLabel(for: "Filter issues") == "Clear Filter issues")
    }
}
