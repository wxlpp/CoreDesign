import SwiftUI
import Testing
@testable import CoreDesign

// Carousel 的自动轮播回绕逻辑（`nextID(after:in:)`）与页点 accessibility 文案组装
// （`positionText(index:count:)`）均抽成 `static` 纯函数，脱离 SwiftUI 运行时单测——
// 覆盖 issue #171 Technical Details 明确要求的边界：空集合 / nil 当前值 / 当前值不在
// 集合中 / 末尾回绕到首个 / 单元素恒返回自身。
@Suite("Carousel")
@MainActor
struct CarouselTests {
    private typealias Carousel_ = Carousel<[CarouselTestItem], Int, Text>

    // MARK: - nextID(after:in:)

    @Test("空集合恒返回 nil")
    func nextIDEmptyCollection() {
        #expect(Carousel_.nextID(after: nil, in: []) == nil)
        #expect(Carousel_.nextID(after: 0, in: []) == nil)
    }

    @Test("current 为 nil 时回落到首个元素")
    func nextIDNilCurrentFallsBackToFirst() {
        #expect(Carousel_.nextID(after: nil, in: [10, 20, 30]) == 10)
    }

    @Test("current 不在集合中时回落到首个元素（防御式处理数据源变化）")
    func nextIDCurrentNotFoundFallsBackToFirst() {
        #expect(Carousel_.nextID(after: 999, in: [10, 20, 30]) == 10)
    }

    @Test("推进到集合中间的下一个元素")
    func nextIDAdvancesToNextElement() {
        #expect(Carousel_.nextID(after: 10, in: [10, 20, 30]) == 20)
        #expect(Carousel_.nextID(after: 20, in: [10, 20, 30]) == 30)
    }

    @Test("末尾元素之后回绕到首个元素")
    func nextIDWrapsAroundAfterLast() {
        #expect(Carousel_.nextID(after: 30, in: [10, 20, 30]) == 10)
    }

    @Test("单元素集合恒返回自身")
    func nextIDSingleElementReturnsItself() {
        #expect(Carousel_.nextID(after: 10, in: [10]) == 10)
        #expect(Carousel_.nextID(after: nil, in: [10]) == 10)
    }

    // MARK: - positionText(index:count:)

    @Test("位置文案格式化为「index of count」（本地化 %@ of %@ 键，两端 formatted()）")
    func positionTextFormatting() {
        #expect(Carousel_.positionText(index: 1, count: 5) == "1 of 5")
        #expect(Carousel_.positionText(index: 3, count: 5) == "3 of 5")
        #expect(Carousel_.positionText(index: 5, count: 5) == "5 of 5")
    }

    @Test("单页边界：1 of 1")
    func positionTextSinglePage() {
        #expect(Carousel_.positionText(index: 1, count: 1) == "1 of 1")
    }

    // MARK: - init 不崩溃 / 基本属性

    @Test("空数据源可安全构造")
    func initWithEmptyData() {
        let carousel = Carousel([CarouselTestItem]()) { item in
            Text(item.title)
        }
        _ = carousel.body
    }

    @Test("非空数据源可安全构造并生成 body")
    func initWithData() {
        let items = [
            CarouselTestItem(id: 0, title: "A"),
            CarouselTestItem(id: 1, title: "B"),
        ]
        let carousel = Carousel(items, autoAdvance: false) { item in
            Text(item.title)
        }
        _ = carousel.body
    }
}

private struct CarouselTestItem: Identifiable {
    let id: Int
    let title: String
}
