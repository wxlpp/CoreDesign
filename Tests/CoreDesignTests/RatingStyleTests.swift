import SwiftUI
import Testing
@testable import CoreDesign

@Suite("RatingStyle 扩展点")
@MainActor
struct RatingStyleTests {
    private struct NumericRatingStyle: RatingStyle {
        func makeBody(configuration: Configuration) -> some View {
            Text(verbatim: "\(configuration.value)/\(configuration.count)")
        }
    }

    @Test("环境值默认实现是 StarRatingStyle")
    func defaultStyleIsStarRatingStyle() {
        #expect(EnvironmentValues().ratingStyle is StarRatingStyle)
    }

    @Test("RatingStyleConfiguration 只携带外观所需状态（value / count），不带行为")
    func configurationCarriesAppearanceStateOnly() {
        let configuration = RatingStyleConfiguration(value: 3.5, count: 5)
        #expect(configuration.value == 3.5)
        #expect(configuration.count == 5)

        let fieldNames = Set(Mirror(reflecting: configuration).children.compactMap(\.label))
        #expect(fieldNames == ["value", "count"],
                "RatingStyleConfiguration 的字段集合变成了 \(fieldNames.sorted())——新增字段必须先过公约第 2 节边界条款（Configuration 不得携带行为）")
    }

    @Test("View.ratingStyle(_:) 把 style 写进环境值，换得掉默认实现")
    func ratingStyleModifierInjectsIntoEnvironment() {
        var environment = EnvironmentValues()
        #expect(environment.ratingStyle is StarRatingStyle)

        environment.ratingStyle = NumericRatingStyle()
        #expect(environment.ratingStyle is NumericRatingStyle)
        #expect(!(environment.ratingStyle is StarRatingStyle))

        _ = Text(verbatim: "x").ratingStyle(NumericRatingStyle())
    }

    // MARK: - `Rating.body` 真的消费 `style.makeBody`（评审 finding，非人审符号存在性）

    @MainActor
    private final class MakeBodyCallRecorder {
        private(set) var callCount = 0
        private(set) var lastConfiguration: RatingStyleConfiguration?

        func record(_ configuration: RatingStyleConfiguration) {
            self.callCount += 1
            self.lastConfiguration = configuration
        }
    }

    private struct SpyRatingStyle: RatingStyle {
        let recorder: MakeBodyCallRecorder

        func makeBody(configuration: Configuration) -> some View {
            self.recorder.record(configuration)
            return Rectangle().fill(Color.red)
        }
    }

    @Test("Rating.body 真的经 style.makeBody 渲染——不是声明协议但绕过它硬编码星形")
    func bodyRendersThroughStyleMakeBody() {
        let recorder = MakeBodyCallRecorder()
        let view = Rating(value: .constant(3), count: 5)
            .ratingStyle(SpyRatingStyle(recorder: recorder))
            .frame(width: 100, height: 40)

        let renderer = ImageRenderer(content: view)
        _ = renderer.cgImage

        #expect(recorder.callCount >= 1, "makeBody 从未被调用——Rating.body 绕过了 self.style，是假扩展点")
        #expect(recorder.lastConfiguration?.value == 3, "makeBody 收到的 value 与 Rating 的真实构造参数不一致")
        #expect(recorder.lastConfiguration?.count == 5, "makeBody 收到的 count 与 Rating 的真实构造参数不一致")
    }

    // MARK: - `RatingDisplay.body` 真的消费 `style.makeBody`（Task 6 评审 finding I-1）

    @Test("RatingDisplay.body 真的经 style.makeBody 渲染——不是声明协议但绕过它硬编码星形")
    func displayBodyRendersThroughStyleMakeBody() {
        let recorder = MakeBodyCallRecorder()
        let view = RatingDisplay(value: 3.5, count: 7)
            .ratingStyle(SpyRatingStyle(recorder: recorder))
            .frame(width: 100, height: 40)

        let renderer = ImageRenderer(content: view)
        _ = renderer.cgImage

        #expect(recorder.callCount >= 1, "makeBody 从未被调用——RatingDisplay.body 绕过了 self.style，是假扩展点")
        #expect(recorder.lastConfiguration?.value == 3.5, "makeBody 收到的 value 与 RatingDisplay 的真实构造参数不一致")
        #expect(recorder.lastConfiguration?.count == 7, "makeBody 收到的 count 与 RatingDisplay 的真实构造参数不一致")
    }
}
