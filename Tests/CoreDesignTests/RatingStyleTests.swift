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

    // MARK: - `Rating.body` 真的消费 `style.makeBody`（评审 finding，非人审符号存在性）
    //
    // 上面三条只测环境管道（默认值 / Configuration 字段集合 / 注入换出），都能在
    // `Rating.body` 硬编码星形、完全绕过 `self.style` 的「假扩展点」下继续全绿——
    // J-2 的 `customStyleProtocol` 判据同样只查符号存在性（协议已声明 + 至少一个类型
    // 采纳），见 `Rating.body` 上方注释。这条补齐机器判据：用 spy style 记录
    // `makeBody` 是否真的被调用、收到的 configuration 是否与 `Rating` 的真实构造参数
    // 一致，经 `ImageRenderer` 触发一次真实的 SwiftUI body 求值——不是「看起来应该会
    // 调用」的推断。手法与 `CoreControlStyleTintTests.averageColor` 同源（`ImageRenderer`
    // 是本仓验证「样式真的接入」的既有惯例）。

    /// 记录 `makeBody` 调用次数与最近一次收到的 configuration。class + `@MainActor`——
    /// 本包 `.defaultIsolation(MainActor.self)`，与渲染发生在同一隔离域，不需要额外同步。
    @MainActor
    private final class MakeBodyCallRecorder {
        private(set) var callCount = 0
        private(set) var lastConfiguration: RatingStyleConfiguration?

        func record(_ configuration: RatingStyleConfiguration) {
            self.callCount += 1
            self.lastConfiguration = configuration
        }
    }

    /// 除了记录调用，`makeBody` 仍返回一个非空视图——`ImageRenderer` 需要真实内容
    /// 才能完成渲染管线，一个空 `EmptyView` 也足够触发求值，但用可见矩形更贴近
    /// 真实样式实现的形状。
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
        _ = renderer.cgImage // 强制触发渲染管线对 body 求值

        #expect(recorder.callCount >= 1, "makeBody 从未被调用——Rating.body 绕过了 self.style，是假扩展点")
        #expect(recorder.lastConfiguration?.value == 3, "makeBody 收到的 value 与 Rating 的真实构造参数不一致")
        #expect(recorder.lastConfiguration?.count == 5, "makeBody 收到的 count 与 Rating 的真实构造参数不一致")
    }

    // MARK: - `RatingDisplay.body` 真的消费 `style.makeBody`（Task 6 评审 finding I-1）
    //
    // 上面那条 spy 测试只渲染了 `Rating`——`RatingDisplay` 侧此前只有 J-2 判据的
    // `satisfied["RatingDisplay"]` 断言，而那条判据同样只查符号存在性（协议已声明 +
    // `StarRatingStyle` 采纳）。把 `RatingDisplay.body` 改成硬编码星形、绕开
    // `self.style`，J-2 与上面那条 `Rating` 专属的 spy 测试会照样全绿——这正是
    // `Rating.body` 注释里点名的精度上限。这条测试补齐 `RatingDisplay` 一侧的机器钉子，
    // 复用同一套 spy style / recorder。
    //
    // ⚠️ `count == 7` 是刻意的强断言：`RatingDisplay` 判定法论证里讲过
    // `ProgressViewStyle.Configuration` 会丢掉 `count`（3.5/5 与 7/10 都坍缩成
    // 0.7）——用非默认的 `count: 7` 断言，同时证明「count 真的被原样传给了 makeBody」。
    @Test("RatingDisplay.body 真的经 style.makeBody 渲染——不是声明协议但绕过它硬编码星形")
    func displayBodyRendersThroughStyleMakeBody() {
        let recorder = MakeBodyCallRecorder()
        let view = RatingDisplay(value: 3.5, count: 7)
            .ratingStyle(SpyRatingStyle(recorder: recorder))
            .frame(width: 100, height: 40)

        let renderer = ImageRenderer(content: view)
        _ = renderer.cgImage // 强制触发渲染管线对 body 求值

        #expect(recorder.callCount >= 1, "makeBody 从未被调用——RatingDisplay.body 绕过了 self.style，是假扩展点")
        #expect(recorder.lastConfiguration?.value == 3.5, "makeBody 收到的 value 与 RatingDisplay 的真实构造参数不一致")
        #expect(recorder.lastConfiguration?.count == 7, "makeBody 收到的 count 与 RatingDisplay 的真实构造参数不一致")
    }
}
