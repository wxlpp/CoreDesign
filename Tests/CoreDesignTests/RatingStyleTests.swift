import SwiftUI
import Testing
@testable import CoreDesign

// RatingStyle（Issue #41 裁决 4c）——`Rating` 在登记表里是
// `kind: semantic` / `decidedBy: step2` / `needsExtensionPoint: true` 而
// `customStyleProtocol: null`，是 J-2 两条已知红之一。本轮按公约第 2 节形态 B 补齐。
//
// ⚠️ 真实渲染留给 iOS Simulator 视觉评审（见 CLAUDE.md 验证边界章节），
// 这里覆盖三件在 macOS 上也作数、且真的承重的事：
//   1. 环境值默认实现是 StarRatingStyle（默认没被换掉）；
//   2. Configuration 的字段集合恰为 {value, count}——**不带行为**（公约第 2 节边界条款）；
//   3. View.ratingStyle(_:) 真的把 style 写进了环境值（不是一个空 modifier）。
@Suite("RatingStyle 扩展点")
@MainActor
struct RatingStyleTests {

    /// 测试用的替代样式——用来证明「换得掉」，不是用来渲染的。
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

        // ⚠️ **这条断言就是公约第 2 节边界条款的机器化，不是「顺手数一下字段」**：
        // 往 Configuration 里塞 `step`（手势 / VoiceOver 的调整粒度）或 `isInteractive`
        // （可交互性）就是把**行为**交给样式实现者，公约明令禁止；`isInteractive` 还会
        // 因为是 Bool 而当场触发 J-1。字段一增本条立刻红，逼人重新裁决。
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

        // modifier 本身的存在性：编译得过即证明 public 表面在（`some RatingStyle` 泛型入口）。
        _ = Text(verbatim: "x").ratingStyle(NumericRatingStyle())
    }
}
