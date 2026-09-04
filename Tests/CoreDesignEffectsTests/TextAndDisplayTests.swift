import CoreDesign
import Foundation
import SwiftUI
import Testing

@testable import CoreDesignEffects

// MARK: - #253：文本与展示动效（TypewriterText / AnimatedMeshGradient / BeforeAfterSlider / ParticleTransition）
//
// ⚠️ **本文件的四组判据各有一条"承重"断言**，其余是它的非退化前置（互锁）：
//
// | 组件 | 承重判据 | 形态 |
// |---|---|---|
// | `TypewriterText` | Reduce Motion ⇒ 直接显示完整文本 | 纯函数 + 源码（调用点只喂给它） |
// | `AnimatedMeshGradient` | 空色板 ⇒ 取调用方 `.tint`；后台 ⇒ 一个像素都不画 | 位图 |
// | `BeforeAfterSlider` | Reduce Motion ⇒ 不做入场摆动、拖拽照常；把手命中区 ≥ 44pt | 纯函数 + 源码 + 位图 |
// | `ParticleTransition` | Reduce Motion ⇒ 只留淡入淡出（**不是 no-op**）；恒等相位不画粒子 | 纯函数 + 位图 |
//
// ⚠️ **`\.accessibilityReduceMotion` 不可注入**（`EnvironmentValues` 上它是只读的系统偏好，
// 写它编译红——`EffectsPresentation` 的文档已实测过这条）。⇒ 凡 Reduce Motion 方向的判据
// 只能落在**纯函数**（"给定这个布尔值，这个函数返回什么"）与**源码**（"调用点是否真的
// 只用这个结论"）两条链上，位图路结构上不可达。本文件两条都写，缺一条就只剩函数体、
// 调用点可以自己再判一遍（#252 PR #269 第 2 轮终审 I-A 逐字记着这个失效形态）。
//
// ⚠️ **触控目标判据不放进 `CoreDesignTests.TouchTargetTests`**（`253.md` 逐字）：
// 那会让 `CoreDesignTests` 的依赖图包含 `CoreDesignEffects`，判红
// `shipswift-foundation` #245 立的 NFR-5② 隔离判据
// （`swift package describe` 里 `CoreDesignTests` 的依赖必须恰为 `["CoreDesign"]`）。
// ⇒ 在本 target 内**同形态**实现：`#if os(iOS)` + `ImageRenderer` 量渲染高度。

// MARK: - TypewriterText

@Suite("TypewriterText 的揭示契约")
@MainActor
struct TypewriterTextTests {

    /// ⚠️ **复用 `MicroInteractionReduceMotionGuard.sourceRoot`，不重抄仓库根的推导**
    ///（PR #273 Copilot inline）：上一版在这里又写了一遍三次 `deletingLastPathComponent`
    /// + `"Sources/CoreDesignEffects/"`，与那份守卫的扫描根**各自演化**——挪目录时
    /// 只有一处会跟着改，而另一处静默指向不存在的路径（`String(contentsOf:)` 抛错、
    /// 判据以"读不到文件"而不是"违规"的形态红，很难归因）。
    static func source(_ fileName: String) throws -> String {
        let url = MicroInteractionReduceMotionGuard.sourceRoot.appendingPathComponent(fileName)
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// `ImageRenderer` 的**布局尺寸**（跨平台）。
    ///
    /// ⚠️ 与位图不同：位图字节数在被测视图外面套了 `.frame(...)` 之后**恒定**，
    /// 用它比"布局有没有跳"是结构性恒真（终审 I-2）。要观测布局必须量尺寸，
    /// 且被测视图**不能**被外层 `.frame` 钉死。
    static func renderedSize(_ view: some View) -> CGSize {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        #if canImport(UIKit)
        return renderer.uiImage?.size ?? .zero
        #else
        return renderer.nsImage?.size ?? .zero
        #endif
    }

    /// ⚠️⚠️ **承重判据**：AC「Reduce Motion ⇒ 直接显示完整文本」。
    @Test("Reduce Motion ⇒ 揭示数直接跳到全文，与已打了多少字无关")
    func reduceMotionRevealsEverything() {
        for typed in [0, 1, 4, 99] {
            #expect(TypewriterReveal.plan(total: 12, typed: typed, reduceMotion: true).revealed == 12,
                    "Reduce Motion 下 typed=\(typed) 没有直接给出全文 —— 用户会看到一段被截断的文字")
        }
        // Reduce Motion 下还必须**不起计时器**——只把画面补全、却让状态机继续逐字跑，
        // 那是白烧一条每 40ms 醒一次的任务。
        #expect(TypewriterReveal.plan(total: 12, typed: 0, reduceMotion: true).types == false)
        // ⚠️ **互锁**：非 Reduce Motion 下它必须**不是**恒等于 total，
        // 否则上面那条对「直接返回 total」的实现也恒真。
        #expect(TypewriterReveal.plan(total: 12, typed: 0, reduceMotion: false).types == true)
        #expect(TypewriterReveal.plan(total: 12, typed: 4, reduceMotion: false).revealed == 4)
        #expect(TypewriterReveal.plan(total: 12, typed: 0, reduceMotion: false).revealed == 0)
    }

    @Test("揭示数被钳在 0...total（退化输入不越界）")
    func revealedCountIsClamped() {
        #expect(TypewriterReveal.plan(total: 5, typed: -3, reduceMotion: false).revealed == 0)
        #expect(TypewriterReveal.plan(total: 5, typed: 99, reduceMotion: false).revealed == 5)
        #expect(TypewriterReveal.plan(total: 0, typed: 3, reduceMotion: false).revealed == 0)
        #expect(TypewriterReveal.plan(total: 0, typed: 3, reduceMotion: true).revealed == 0)
    }

    /// 逐**字符**（`Character`，即字素簇）而不是逐 UTF-8 字节——否则 emoji / 组合字
    /// 会被拆成半个字符。
    @Test("前缀按字素簇取，不拆 emoji 与组合字")
    func prefixIsGraphemeSafe() {
        let text = "a👨‍👩‍👧b"
        #expect(TypewriterReveal.characterCount(of: text) == 3)
        #expect(TypewriterReveal.prefix(of: text, count: 2) == "a👨‍👩‍👧")
        #expect(TypewriterReveal.prefix(of: text, count: 0) == "")
        #expect(TypewriterReveal.prefix(of: text, count: 99) == text)
        #expect(TypewriterReveal.prefix(of: text, count: -1) == "")
    }

    @Test("三档速度的每字间隔严格递减（fast < regular < slow）")
    func speedIsMonotonic() {
        #expect(TypewriterSpeed.fast.secondsPerCharacter < TypewriterSpeed.regular.secondsPerCharacter)
        #expect(TypewriterSpeed.regular.secondsPerCharacter < TypewriterSpeed.slow.secondsPerCharacter)
        #expect(TypewriterSpeed.fast.secondsPerCharacter > 0, "间隔为 0 会让打字机瞬间打完")
    }

    /// ⚠️⚠️ **承重判据的另一半：调用点**。纯函数只钉「给定 `reduceMotion` 返回什么」，
    /// **调用点是否真的用这个结论**是另一条链，而它在位图上不可观测
    /// （`\.accessibilityReduceMotion` 不可注入）。
    /// ⇒ 与 `MicroInteractionReduceMotionGuard.reduceMotionIsOnlyConsumedByTheSharedGate`
    /// 同一形态：本文件里 `reduceMotion` 的每一次出现都必须正好是喂给纯函数那一次。
    @Test("调用点：TypewriterText.swift 里 reduceMotion 只喂给 TypewriterReveal.plan")
    func reduceMotionIsOnlyConsumedByTheRevealGate() throws {
        let code = MicroInteractionReduceMotionGuard.stripComments(try Self.source("TypewriterText.swift"))
        #expect(code.contains("accessibilityReduceMotion"),
                "TypewriterText 没有读 Reduce Motion —— AC 的降级无从谈起")
        let reads = code.components(separatedBy: "self.reduceMotion").count - 1
        let fed = code.components(separatedBy: "reduceMotion: self.reduceMotion").count - 1
        #expect(fed >= 1, "TypewriterText 没有把 reduceMotion 喂给揭示闸 —— 多半是被换成了字面量")
        #expect(reads == fed,
                "TypewriterText.swift 里 `self.reduceMotion` 出现 \(reads) 次、只有 \(fed) 次喂给闸 —— 多出来的是调用点自己又判了一遍")
        // ⚠️ **闸函数自己的函数体要先挖掉再查**：`plan(total:typed:reduceMotion:)`
        // 就住在同一份文件里，它体内那句 `guard !reduceMotion` 是**闸本身**，不是调用点
        //（能耗闸那几个文件的闸函数在 `EffectsEnergy.swift`，所以它们不会撞上这条）。
        // 挖掉之后剩下的每一处裸 `reduceMotion` 才是真正的逃逸位。
        let callSites = ConfettiTests.removingRegion(after: "static func plan(", in: code)
        #expect(callSites != code, "没能挖掉闸函数的函数体 —— 下面的断言会把闸本身报成违规")
        let strays = MicroInteractionReduceMotionGuard.bareReduceMotionOccurrences(in: callSites)
        #expect(strays.isEmpty, "裸写的 reduceMotion（去掉 `self.` 就能绕过上面的字面计数）：\n\(strays.joined(separator: "\n"))")
    }

    /// ⚠️⚠️ **调用点：`body` 交给绘制层与状态机的必须是 `plan` 的两个字段**（终审 I-1）。
    ///
    /// `reduceMotionIsOnlyConsumedByTheRevealGate` 只堵住闸的**输入**（`reduceMotion` 确实
    /// 被喂进 `plan`），**两个输出洞都开着**。终审逐枚实测：
    ///
    /// | 变异 | 后果 | 当时的测试 |
    /// |---|---|---|
    /// | `revealed: plan.revealed` → `revealed: total` | 瞬间显示全文，打字机效果整个消失 | 7/7 **绿** |
    /// | `types: plan.types` → `types: false` | 状态机不再逐字推进 | 15/15 **绿** |
    ///
    /// ⇒ 与 `reads == fed` 同一形态，逐次计数把两个出口也钉住：`plan` 必须是 `body`
    /// 能交给 `TypewriterBody` / `type(total:types:)` 的**唯一**东西。
    @Test("调用点：body 只把 plan.revealed / plan.types 交给绘制层与状态机")
    func planIsTheOnlyThingBodyHandsDown() throws {
        let code = MicroInteractionReduceMotionGuard.stripComments(try Self.source("TypewriterText.swift"))
        func count(_ needle: String) -> Int { code.components(separatedBy: needle).count - 1 }

        #expect(count("TypewriterBody(") == 1,
                "TypewriterText.swift 里构造了 \(count("TypewriterBody(")) 次 TypewriterBody —— 下面的逐次计数不再说明「唯一那次」用的是什么")
        #expect(count("revealed: plan.revealed") == 1, """
        绘制层拿到的不是 `plan.revealed`（命中 \(count("revealed: plan.revealed")) 次）——
        改成 `revealed: total` 会让组件瞬间显示全文、打字机效果整个消失，
        而闸的**输入**判据（reads == fed）仍然全绿。
        """)

        #expect(count("await self.type(") == 1,
                "打字状态机被调用了 \(count("await self.type(")) 次 —— 逐次计数不再说明唯一那次喂的是什么")
        #expect(count("types: plan.types") == 1, """
        状态机拿到的不是 `plan.types`（命中 \(count("types: plan.types")) 次）——
        改成 `types: false` 会让逐字推进整个停掉，而闸的输入判据仍然全绿。
        """)
    }

    /// 揭示是**真的**接到渲染上的：不同揭示数必须画出不同的东西。
    @Test("揭示数真的接到渲染：0 字与全文的位图不同")
    func revealedCountReachesRendering() {
        let full = "Hello typewriter"
        func body(_ revealed: Int) -> Data? {
            MicroInteractionAPITests.stablePixels(
                TypewriterBody(text: full, revealed: revealed)
                    .frame(width: 220, height: 40)
                    .background(Color.surfaceRaised)
            )
        }
        let none = body(0)
        let all = body(TypewriterReveal.characterCount(of: full))
        #expect(none != nil && all != nil, "渲染失败，下面的不等断言会静默变绿")
        #expect(none != all, "0 字与全文渲染完全相同 —— revealed 根本没接到 Text 上")
        // ⚠️ **上一版这里还有一条「两者位图字节数必须相同」，它结构性恒真**（终审 I-2）：
        // `pixels` 返回 `w*h*4` 的裸 RGBA 缓冲，而被测视图被外层 `.frame(220×40)` 钉死
        // ⇒ 两个字节数**永远**相等，`body` 干什么都一样。终审实证：把整个幽灵层机制
        // 换成裸 `Text(verbatim: shown)`，本 suite 7/7 仍绿。
        // ⇒ 布局那一半移交下面的 `ghostSizingKeepsLayoutStable`（量的是**尺寸**、且不套 frame）。
    }

    /// ⚠️⚠️ **「打字不跳字」的真判据**（终审 I-2 换掉了上一条恒真的字节数比较）。
    ///
    /// 被测视图**不套外层 `.frame`**，比的是 `ImageRenderer` 的布局尺寸：
    /// 幽灵层（全文 `opacity(0)` 做尺寸底稿）在时，前缀长短不改变布局；
    /// 删掉幽灵层就只剩前缀本身的尺寸 ⇒ 判红。互锁那条把"恒真"堵死。
    @Test("幽灵层做尺寸底稿：打到第 1 个字与全文的布局尺寸相同")
    func ghostSizingKeepsLayoutStable() {
        let full = "Hello typewriter, a long enough line that a prefix is visibly narrower"
        func size(_ revealed: Int) -> CGSize {
            Self.renderedSize(TypewriterBody(text: full, revealed: revealed))
        }
        let one = size(1)
        let all = size(TypewriterReveal.characterCount(of: full))
        #expect(all.width > 0 && all.height > 0, "渲染失败，下面的相等断言会静默变绿")
        #expect(one == all, """
        打到第 1 个字与全文的布局尺寸不同（\(one) vs \(all))——
        幽灵层尺寸底稿没有生效，打字过程中行宽 / 行数会跳，并把下方布局推来推去。
        """)

        // ⚠️ **互锁**：同一条件下裸 `Text` 的前缀与全文尺寸**必须**不同，
        // 否则上面那条相等断言是恒真的（这正是它替换掉的那条犯的错）。
        let barePrefix = Self.renderedSize(Text(verbatim: TypewriterReveal.prefix(of: full, count: 1)))
        let bareFull = Self.renderedSize(Text(verbatim: full))
        #expect(barePrefix != bareFull,
                "裸 Text 的前缀与全文尺寸相同（\(barePrefix)）—— 上面那条相等断言是恒真的")
    }

    @Test("公开入口：LocalizedStringResource 与 verbatim 两条都在，且可渲染")
    func publicInitsExist() {
        #expect(MicroInteractionAPITests.stablePixels(TypewriterText("Hello").frame(width: 200, height: 30)) != nil)
        #expect(MicroInteractionAPITests.stablePixels(
            TypewriterText(verbatim: "run-time content", speed: .fast).frame(width: 200, height: 30)
        ) != nil)
    }
}

// MARK: - AnimatedMeshGradient

@Suite("AnimatedMeshGradient 的取色、能耗与冻结契约")
@MainActor
struct AnimatedMeshGradientTests {

    static func source(_ fileName: String) throws -> String {
        try TypewriterTextTests.source(fileName)
    }

    /// 判据里用到的两组色板。**暖机与被测项必须用同一份**——见 `meshWarmUp`。
    static let palette: [Color] =
        Array(repeating: Color.surfaceRaised, count: 4) + Array(repeating: Color.contentPrimary, count: 5)
    static let basePalette: [Color] = Array(repeating: Color.surfaceRaised, count: MeshDrift.colorSlots)
    static let altPalette: [Color] = Array(repeating: Color.contentPrimary, count: MeshDrift.colorSlots)

    /// ⚠️ **`MeshGradient` 有自己的一层进程级首帧伪影**（与 `ConfettiTests.canvasWarmUp`
    /// 同源：本仓实测过「同一个视图渲两次、第一次是异类」）。先把这条渲染路径跑热。
    ///
    /// ⚠️⚠️ **必须把 `MeshGradient(colors:)` 那条分支也跑热**（#253 PR #273 终审 C-2）：
    /// 上一版只暖了 `.tint` / mask 那条（`colors: []`），而显式色板走的是**另一条**
    /// 渲染路径、有**自己的**首帧伪影 ⇒ `stablePixels` 那一次丢弃渲染不够，
    /// `emptyPaletteFollowsCallerTint` 里冷渲的 `paletteRed` 与暖渲的 `paletteBlue` 不等
    /// ⇒ 单独跑该用例终审实测 **15 / 15 全失败**，全量 `swift test` 也红。
    /// ⚠️ 它同时是 `alternatePaletteReachesRendering` 判别力的前提：伪影在时那条
    /// `single != dual` 可能因为「一个冷渲一个暖渲」而**因错误的原因通过**。
    /// ⇒ 三条渲染路径（`.tint` mask / 单色板 / 双色板混合）各跑热一遍。
    private static let meshWarmUp: Bool = {
        @MainActor func warm(_ view: some View) {
            for _ in 0..<8 { _ = MicroInteractionAPITests.stablePixels(view) }
        }
        warm(Self.rawBody(colors: [], alternateColors: []))
        warm(Self.rawBody(colors: Self.palette, alternateColors: []))
        warm(Self.rawBody(colors: Self.basePalette, alternateColors: []))
        warm(Self.rawBody(colors: [], alternateColors: Self.altPalette))
        warm(Self.rawBody(
            phase: MeshDrift.blendPeakPhase, colors: Self.basePalette, alternateColors: Self.altPalette
        ))
        return true
    }()

    /// 与 `body(...)` 同一棵视图树，但**不经过 `pixels`**——`meshWarmUp` 自己要用它，
    /// 而 `pixels` 会先求值 `meshWarmUp`（递归）。
    static func rawBody(
        phase: CGFloat = MeshDrift.restingPhase,
        colors: [Color] = [],
        alternateColors: [Color] = [],
        lowPower: Bool? = nil
    ) -> some View {
        AnimatedMeshBody(phase: phase, colors: colors, alternateColors: alternateColors)
            .frame(width: 160, height: 120)
            .background(Color.surfaceRaised)
            .environment(\.scenePhaseOverride, .active)
            .environment(\.lowPowerModeOverride, lowPower)
    }

    static func pixels(_ view: some View) -> Data? {
        _ = Self.meshWarmUp
        return MicroInteractionAPITests.stablePixels(view)
    }

    static func body(
        phase: CGFloat = MeshDrift.restingPhase,
        colors: [Color] = [],
        alternateColors: [Color] = [],
        lowPower: Bool? = nil
    ) -> some View {
        Self.rawBody(phase: phase, colors: colors, alternateColors: alternateColors, lowPower: lowPower)
    }

    /// ⚠️⚠️ **承重判据**：AC「不自带调色板，9 色 × 2 组全部由调用方传入或取 `.tint`」。
    @Test("空色板 ⇒ 取调用方 .tint；给了色板 ⇒ 不再跟随 .tint")
    func emptyPaletteFollowsCallerTint() {
        let red = Self.pixels(Self.body().tint(.red))
        let blue = Self.pixels(Self.body().tint(.blue))
        #expect(red != nil && blue != nil, "渲染失败，下面的不等断言会静默变绿")
        #expect(red?.contains(where: { $0 != 0 }) == true, "位图全 0 —— 断言恒真")
        #expect(red != blue, "空色板下换 .tint 位图不变 —— 说明取色没有走 .tint（多半是写死了 Color.accent）")

        // 反面：显式色板必须**压过** `.tint`，否则"调用方传入"这条路是假的。
        // ⚠️ 色板取 `Self.palette`（与 `meshWarmUp` 暖的是同一份）——终审 C-2：
        // `MeshGradient(colors:)` 那条分支不暖机时，这两次渲染一冷一暖必然不等。
        let paletteRed = Self.pixels(Self.body(colors: Self.palette).tint(.red))
        let paletteBlue = Self.pixels(Self.body(colors: Self.palette).tint(.blue))
        #expect(paletteRed != nil, "渲染失败")
        #expect(paletteRed == paletteBlue, "给了色板还跟着 .tint 变 —— 调用方参数没有生效")
    }

    /// ⚠️ **终审 C-2 的连带项**：伪影存在时这条 `single != dual` **可能因为错误的原因通过**
    ///（`single` 冷渲、`dual` 暖渲）。`meshWarmUp` 把两条路径都跑热之后它才承重
    /// ——变异实证见 PR #273 的评论（把 `blended` 改成永远忽略 `alternate` ⇒ 判红）。
    @Test("两组色板真的都接到渲染上：只换 alternateColors 位图必须变")
    func alternatePaletteReachesRendering() {
        // 相位取在两组之间混合最深处，否则混合系数为 0 时两者天然相同。
        let phase = MeshDrift.blendPeakPhase
        let single = Self.pixels(Self.body(phase: phase, colors: Self.basePalette))
        let dual = Self.pixels(
            Self.body(phase: phase, colors: Self.basePalette, alternateColors: Self.altPalette)
        )
        #expect(single != nil && dual != nil, "渲染失败")
        #expect(single?.contains(where: { $0 != 0 }) == true, "位图全 0 —— 不等断言恒真")
        #expect(single != dual, "第二组色板对渲染无影响 —— alternateColors 是死参数")
    }

    /// ⚠️ **登记 S-2 那个不对称组合**：`colors` 空 + `alternateColors` 非空 ⇒
    /// **静态使用备用色板、不回落 `.tint`**。类型文档与 `docs/components/animated-mesh-gradient.md`
    /// 上一版都无条件写着「`colors` 为空 ⇒ 回落 `.tint`」，与此不符 ⇒ 本判据把真实行为钉住，
    /// 免得下一个人照文档改成 `nil` 而没有任何东西判红。
    @Test("只给 alternateColors ⇒ 用那一组色板，不跟随 .tint（已登记的不对称组合）")
    func alternateOnlyPaletteDoesNotFollowTint() {
        #expect(MeshDrift.blended(base: [], alternate: Self.altPalette, phase: 0.3) != nil,
                "只给 alternateColors 时回落到了 .tint 形态 —— 与已登记的行为不符")
        #expect(MeshDrift.blended(base: [], alternate: [], phase: 0.3) == nil,
                "两组都空时没有回落 .tint —— 上面那条不再说明任何事")
        let red = Self.pixels(Self.body(alternateColors: Self.altPalette).tint(.red))
        let blue = Self.pixels(Self.body(alternateColors: Self.altPalette).tint(.blue))
        #expect(red != nil && blue != nil, "渲染失败，下面的相等断言会静默变绿")
        #expect(red == blue, "只给 alternateColors 时仍跟着 .tint 变 —— 与已登记的行为不符")
    }

    /// 色板长度契约：不足 9 补齐、超过 9 截断——否则 `MeshGradient` 会因
    /// `colors.count != width * height` 直接崩。
    @Test("色板恒被规整到 9 个（不足循环补齐、超出截断）")
    func paletteIsNormalisedToNineSlots() {
        #expect(MeshDrift.normalised([]).isEmpty, "空色板必须原样为空（那是 .tint 形态的信号）")
        #expect(MeshDrift.normalised([.surfaceRaised]).count == MeshDrift.colorSlots)
        #expect(MeshDrift.normalised(Array(repeating: Color.surfaceRaised, count: 20)).count == MeshDrift.colorSlots)
        #expect(MeshDrift.points(phase: 0).count == MeshDrift.colorSlots,
                "网格点数必须与色位数一致，否则 MeshGradient 崩")
        for p in [CGFloat(0), 0.25, 0.5, 0.87, 1] {
            for point in MeshDrift.points(phase: p) {
                #expect(point.x >= 0 && point.x <= 1 && point.y >= 0 && point.y <= 1,
                        "相位 \(p) 上网格点越界：\(point)")
            }
        }
    }

    /// NFR-7 停摆方向：注入"App 进了后台"⇒ 一个像素都不画。
    @Test("注入 .background / .inactive ⇒ 整层不画（与空视图逐字节相同）")
    func backgroundedGradientDrawsNothing() {
        func wrapped(_ phase: ScenePhase) -> Data? {
            Self.pixels(
                AnimatedMeshGradient()
                    .frame(width: 160, height: 120)
                    .background(Color.surfaceRaised)
                    .environment(\.scenePhaseOverride, phase)
            )
        }
        let baseline = Self.pixels(
            Color.clear.frame(width: 160, height: 120).background(Color.surfaceRaised)
        )
        #expect(baseline != nil, "基线渲染失败，下面的相等断言会静默变绿")
        #expect(baseline?.contains(where: { $0 != 0 }) == true, "基线位图全 0 —— 相等断言恒真")

        for phase in [ScenePhase.background, .inactive] {
            #expect(wrapped(phase) == baseline, "\(phase) 下仍然画了东西 —— NFR-7 的停摆没有落地")
        }
        #expect(wrapped(.active) != baseline, "\(ScenePhase.active) 下也什么都没画 —— 上面的停摆断言是恒真的")
    }

    /// NFR-7 低电量方向：**必须钉相位**，否则两次渲染落在不同时刻上，不等断言恒真。
    @Test("注入 .lowPower ⇒ 同一相位下位图与满电不同（柔化那层被去掉）")
    func lowPowerChangesRenderingAtSamePhase() {
        let full = Self.pixels(Self.body(lowPower: false))
        let low = Self.pixels(Self.body(lowPower: true))
        #expect(full != nil && low != nil, "渲染失败，下面的不等断言会静默变绿")
        #expect(full?.contains(where: { $0 != 0 }) == true, "位图全 0")
        #expect(full != low, "低电量与满电渲染完全一致 —— 注入的 \\.lowPowerModeOverride 没有影响渲染")
    }

    /// 相位真的接到渲染上：两个不同相位必须画出不同的东西。
    /// ⚠️ 它同时是"冻结在某一帧"这条 AC 的**非退化前置**——若任何相位都画同一张图，
    /// "冻结"就是无意义的。
    @Test("相位真的接到渲染：不同相位位图不同，静止相位画得出东西")
    func phaseReachesRendering() {
        let resting = Self.pixels(Self.body(phase: MeshDrift.restingPhase))
        let other = Self.pixels(Self.body(phase: MeshDrift.restingPhase + 0.25))
        #expect(resting != nil && other != nil, "渲染失败")
        #expect(resting != other, "换相位位图不变 —— 网格点没有随相位漂移")
    }

    @Test("相位恒落在 [0, 1)")
    func phaseStaysInRange() {
        for offset in [0.0, 0.3, 1.9, -2.7, 12345.6] {
            let p = MeshDrift.phase(at: Date(timeIntervalSinceReferenceDate: offset))
            #expect(p >= 0 && p < 1, "相位越界：\(p)")
        }
    }

    /// ⚠️⚠️ **AC「Reduce Motion ⇒ 冻结在某一帧」的调用点判据**。
    ///
    /// 位图路结构上不可达（`\.accessibilityReduceMotion` 不可注入）⇒ 只能钉源码：
    /// 静止分支必须画 `AnimatedMeshBody` 且相位取 `MeshDrift.restingPhase`
    /// ——**不是 `EmptyView()`**（那就是 no-op，#250 第 1 轮因此被打回）。
    @Test("Reduce Motion 分支渲染的是钉在静止相位上的网格，不是 no-op")
    func reduceMotionFreezesOnARealFrame() throws {
        let code = MicroInteractionReduceMotionGuard.stripComments(try Self.source("AnimatedMeshGradient.swift"))
        guard let restingRange = code.range(of: "case .resting:") else {
            Issue.record("AnimatedMeshGradient 里找不到 `.resting` 分支 —— 两道闸的共享裁决点没接上")
            return
        }
        let tail = String(code[restingRange.upperBound...])
        // 分支体到下一个 `case` 为止。
        let branch = tail.components(separatedBy: "case .animated:").first ?? tail
        #expect(branch.contains("AnimatedMeshBody("),
                "Reduce Motion 分支没有画 AnimatedMeshBody —— 降级成了 no-op")
        #expect(branch.contains("MeshDrift.restingPhase"),
                "Reduce Motion 分支没有把相位钉在 MeshDrift.restingPhase 上 —— 那不是「冻结在某一帧」")
        #expect(!branch.contains("TimelineView("),
                "Reduce Motion 分支里还建了 TimelineView —— 冻结没有落地")
    }

    /// `TimelineView` 只许出现在**动画**分支：停摆与静止两档都不该有活着的调度器。
    @Test("TimelineView 只在 .animated 分支里存在")
    func timelineOnlyExistsInTheAnimatedBranch() throws {
        let code = MicroInteractionReduceMotionGuard.stripComments(try Self.source("AnimatedMeshGradient.swift"))
        #expect(code.contains("TimelineView("), "整份文件都没有 TimelineView —— 这个效果根本没在动")
        // 驱动层的 `switch` 体内不得直接出现 `TimelineView(`：它被关在 `AnimatedMeshTimeline` 里。
        guard let switchRange = code.range(of: "switch presentation {") else {
            Issue.record("找不到共享裁决点 `switch presentation {` —— 两道闸的顺序无人守")
            return
        }
        let afterSwitch = String(code[switchRange.upperBound...])
        let switchBody = afterSwitch.components(separatedBy: "struct AnimatedMeshTimeline").first ?? afterSwitch
        #expect(!switchBody.contains("TimelineView("),
                "驱动层的 switch 体里直接建了 TimelineView —— 停摆/静止两档会跟着建出调度器")
    }
}

// MARK: - BeforeAfterSlider

@Suite("BeforeAfterSlider 的摆动、拖拽与触控目标契约")
@MainActor
struct BeforeAfterSliderTests {

    static func source(_ fileName: String) throws -> String {
        try TypewriterTextTests.source(fileName)
    }

    static func slider(
        fraction: CGFloat = BeforeAfterSweep.initialFraction,
        labels: BeforeAfterSliderLabels = .standard
    ) -> some View {
        BeforeAfterSliderBody(
            fraction: fraction,
            labels: labels,
            before: Color.surfaceRaised,
            after: Color.contentPrimary
        )
        .frame(width: 240, height: 140)
    }

    static func pixels(_ view: some View) -> Data? {
        MicroInteractionAPITests.stablePixels(view)
    }

    // MARK: - 逐像素取色（"哪边是哪个"的唯一可观测形态）

    /// 探针画布尺寸。**两侧各留 `probeInset`**，避开正中的把手与分隔线。
    static let probeWidth = 200
    static let probeHeight = 100
    static let probeInset = 20

    /// 从 `MicroInteractionAPITests.pixels` 的**裸 RGBA8** 缓冲里取一个像素。
    ///
    /// ⚠️ 那个缓冲是 `width * height * 4`、`premultipliedLast`（RGBA），逐行无 padding
    /// （`bytesPerRow = w * 4`）⇒ 下标可以直接算。宽度由字节数反推并核对，
    /// 免得 `ImageRenderer` 给出的不是请求的尺寸时静默读错位置。
    static func rgba(_ data: Data, at x: Int, y: Int) -> (r: Int, g: Int, b: Int, a: Int)? {
        let width = data.count / (Self.probeHeight * 4)
        guard width == Self.probeWidth, x >= 0, x < width, y >= 0, y < Self.probeHeight else { return nil }
        let i = (y * width + x) * 4
        return (Int(data[i]), Int(data[i + 1]), Int(data[i + 2]), Int(data[i + 3]))
    }

    static func probe(fraction: CGFloat, before: Color, after: Color) -> Data? {
        Self.pixels(
            BeforeAfterSliderBody(
                fraction: fraction, labels: .hidden, before: before, after: after
            )
            .frame(width: CGFloat(Self.probeWidth), height: CGFloat(Self.probeHeight))
        )
    }

    /// ⚠️⚠️ **承重判据（#253 PR #273 终审 C-1）：分隔线**左边是 `before`、右边是 `after`。
    ///
    /// 唯一的语义权威是 `BeforeAfterSlider.init` 的文档（「`before`：分隔线**左侧**露出的
    /// 内容」），`labelPair` 的 chip 顺序也是照它来的。上一版的绘制层把 `after` 叠在上面、
    /// mask 到 leading ⇒ **左右整个反了**，而 chip 顺序没跟着反 ⇒ 默认 `.standard` 标签
    /// 把两半**都**标错，`.shown(before:after:)` 对所有调用方同样标错。
    /// 终审的像素探针实证（`before: .red` / `after: .blue`，fraction 0.5）：
    /// `left=(39, 124, 225) right=(255, 56, 60)` —— 左半是蓝（`after`）。
    ///
    /// ⚠️ **没有这条判据，同一个反转可以静默重新引入**：当时全套测试全绿——
    /// `fractionReachesRendering` 只比"两个位置的位图不同"，
    /// `labelDomainIsAnEnumWithThreeDistinctRenderings` 只比"三档互不相同"，
    /// 两条都对"哪边是哪个"完全不敏感。
    @Test("before 画在分隔线左边、after 画在右边（init 文档的语义）")
    func beforeIsOnTheLeadingSide() throws {
        let data = try #require(
            Self.probe(fraction: 0.5, before: .red, after: .blue),
            "渲染失败，下面的断言会静默变绿"
        )
        let y = Self.probeHeight / 2
        let left = try #require(Self.rgba(data, at: Self.probeInset, y: y),
                                "取不到左侧像素 —— 渲染尺寸与请求尺寸不符")
        let right = try #require(Self.rgba(data, at: Self.probeWidth - Self.probeInset, y: y),
                                 "取不到右侧像素")

        #expect(left.r > left.b, """
        分隔线**左**侧画的不是 `before`（探针给它 .red，实测 rgba=\(left)）——
        `init` 文档逐字写着「before：分隔线左侧露出的内容」，而 `labelPair` 的
        "Before" chip 也压在左半上 ⇒ 现在标签把两半都标错了。
        """)
        #expect(right.b > right.r, """
        分隔线**右**侧画的不是 `after`（探针给它 .blue，实测 rgba=\(right)）。
        """)
    }

    /// 上一条的**互锁**：两个端点位置必须整块换成另一边，否则"左右"是一句没被观测的话。
    ///
    /// ⚠️ **采样点必须避开把手**：`leadingInset` 把 44pt 的命中区推到分隔线两侧，
    /// fraction=0 时它占 `[0, 44]`、fraction=1 时占 `[width-44, width]`，
    /// 而把手是不透明的 `contentOnAccent` ⇒ 落在里面会取到把手的颜色（实测灰 156）
    /// 而不是被测的两层。⇒ 端点判据取 `probeMidLeft` / `probeMidRight`（60 / 140），
    /// 两个端点形态下都在把手之外。
    static let probeMidLeft = 60
    static let probeMidRight = 140

    @Test("端点位置：fraction=0 整块是 after，fraction=1 整块是 before")
    func endpointsRevealASingleSide() throws {
        let y = Self.probeHeight / 2
        let allAfter = try #require(Self.probe(fraction: 0, before: .red, after: .blue), "渲染失败")
        let allBefore = try #require(Self.probe(fraction: 1, before: .red, after: .blue), "渲染失败")

        for x in [Self.probeMidLeft, Self.probeMidRight] {
            let a = try #require(Self.rgba(allAfter, at: x, y: y))
            #expect(a.b > a.r, "fraction=0 时 x=\(x) 处不是 after(.blue)：rgba=\(a)")
            let b = try #require(Self.rgba(allBefore, at: x, y: y))
            #expect(b.r > b.b, "fraction=1 时 x=\(x) 处不是 before(.red)：rgba=\(b)")
        }
    }

    /// ⚠️⚠️ **承重判据**：AC「Reduce Motion ⇒ 停止自动摆动，但**保留拖拽**」。
    @Test("Reduce Motion ⇒ 没有入场摆动；关闭时才有")
    func introSweepIsGatedByReduceMotion() {
        #expect(BeforeAfterSweep.introSweep(reduceMotion: true) == nil,
                "Reduce Motion 下仍然安排了入场摆动 —— FR-11 的正面违反")
        // ⚠️ **互锁**：非 Reduce Motion 下必须**有**摆动，否则上面那条对
        //「永远返回 nil」的实现也恒真（而那就是把这个效果整个删掉）。
        let sweep = BeforeAfterSweep.introSweep(reduceMotion: false)
        #expect(sweep != nil, "非 Reduce Motion 下也没有入场摆动 —— 上面那条断言是恒真的")
        #expect(sweep?.duration ?? 0 > 0, "摆动时长为 0 —— 等于没有摆动")
        #expect(sweep?.peak != BeforeAfterSweep.initialFraction,
                "摆动的峰值就是初始位置 —— 分隔线一动不动")
        #expect(sweep?.settle == BeforeAfterSweep.initialFraction,
                "摆动结束后没有回到初始位置")
    }

    /// ⚠️ **拖拽不受 Reduce Motion 门控**：`fraction(dragX:width:)` 是纯几何，
    /// 它的签名里**没有** `reduceMotion` 这个参数——这本身就是"拖拽照常"的判据。
    @Test("拖拽位置是纯几何：钳在 0...1，且随手指单调")
    func dragFractionIsPureGeometry() {
        #expect(BeforeAfterSweep.fraction(dragX: -50, width: 200) == 0)
        #expect(BeforeAfterSweep.fraction(dragX: 500, width: 200) == 1)
        #expect(abs(BeforeAfterSweep.fraction(dragX: 50, width: 200) - 0.25) < 0.0001)
        // 退化输入：宽度 0 不得产生 NaN。
        let degenerate = BeforeAfterSweep.fraction(dragX: 10, width: 0)
        #expect(!degenerate.isNaN, "宽度为 0 时算出了 NaN")
        #expect(degenerate >= 0 && degenerate <= 1)
    }

    /// ⚠️⚠️ **承重判据的另一半：调用点**。同 `TypewriterText` 的理由。
    @Test("调用点：BeforeAfterSlider.swift 里 reduceMotion 只喂给 BeforeAfterSweep.introSweep")
    func reduceMotionIsOnlyConsumedByTheSweepGate() throws {
        let code = MicroInteractionReduceMotionGuard.stripComments(try Self.source("BeforeAfterSlider.swift"))
        #expect(code.contains("accessibilityReduceMotion"),
                "BeforeAfterSlider 没有读 Reduce Motion —— AC 的降级无从谈起")
        let reads = code.components(separatedBy: "self.reduceMotion").count - 1
        let fed = code.components(separatedBy: "introSweep(reduceMotion: self.reduceMotion)").count - 1
        #expect(fed >= 1, "BeforeAfterSlider 没有把 reduceMotion 喂给入场摆动闸")
        #expect(reads == fed,
                "BeforeAfterSlider.swift 里 `self.reduceMotion` 出现 \(reads) 次、只有 \(fed) 次喂给闸")
        // ⚠️ 同上：先挖掉闸函数自己的函数体，理由见 `TypewriterTextTests` 里那条。
        let callSites = ConfettiTests.removingRegion(after: "static func introSweep(", in: code)
        #expect(callSites != code, "没能挖掉闸函数的函数体 —— 下面的断言会把闸本身报成违规")
        let strays = MicroInteractionReduceMotionGuard.bareReduceMotionOccurrences(in: callSites)
        #expect(strays.isEmpty, "裸写的 reduceMotion：\n\(strays.joined(separator: "\n"))")
    }

    /// ⚠️ 与三个"处理中"薄封装同一条纪律：本文件进了
    /// `MicroInteractionReduceMotionGuard.approvedNoMotion`（它里面**没有**任何
    /// `motionCalls` 变换——揭示与把手位置都由布局宽度给出）。
    /// 那条豁免只有在「本文件不自建第二套位移」时才站得住 ⇒ 由本判据钉住。
    @Test("揭示与把手位置只走布局宽度，不用 offset / position 这类变换")
    func sliderPositionsByLayoutNotByTransform() throws {
        let code = MicroInteractionReduceMotionGuard.stripComments(try Self.source("BeforeAfterSlider.swift"))
        for call in MicroInteractionReduceMotionGuard.motionCalls {
            #expect(!code.contains(call), """
            BeforeAfterSlider.swift 里出现了 `\(call)` —— 它在 approvedNoMotion 名单上，
            那条豁免的前提正是「本文件没有任何 motionCalls 变换」。
            要么改回布局定位，要么把它从名单里挪出来并按逐调用门控处理。
            """)
        }
        #expect(code.contains("BeforeAfterSweep.revealWidth("),
                "揭示宽度不再走共享几何函数 —— 判据与生产代码会各自漂移")
    }

    @Test("揭示宽度随 fraction 单调，端点恰为 0 与满宽")
    func revealWidthIsMonotonic() {
        #expect(BeforeAfterSweep.revealWidth(fraction: 0, width: 200) == 0)
        #expect(BeforeAfterSweep.revealWidth(fraction: 1, width: 200) == 200)
        #expect(BeforeAfterSweep.revealWidth(fraction: 0.25, width: 200)
                < BeforeAfterSweep.revealWidth(fraction: 0.75, width: 200))
    }

    /// fraction 真的接到渲染上——否则"拖拽照常"是一句无覆盖的话。
    @Test("fraction 真的接到渲染：两个位置的位图不同")
    func fractionReachesRendering() {
        let quarter = Self.pixels(Self.slider(fraction: 0.25))
        let threeQuarters = Self.pixels(Self.slider(fraction: 0.75))
        #expect(quarter != nil && threeQuarters != nil, "渲染失败，下面的不等断言会静默变绿")
        #expect(quarter?.contains(where: { $0 != 0 }) == true, "位图全 0")
        #expect(quarter != threeQuarters, "换 fraction 位图不变 —— 揭示宽度没有接到渲染上")
    }

    /// AC：`showLabels: Bool` 换成语义枚举，且三档在渲染上真的不同。
    @Test("标签取值域是枚举三档，且三档渲染互不相同")
    func labelDomainIsAnEnumWithThreeDistinctRenderings() {
        let hidden = Self.pixels(Self.slider(labels: .hidden))
        let standard = Self.pixels(Self.slider(labels: .standard))
        let custom = Self.pixels(Self.slider(labels: .shown(before: "Draft", after: "Final")))
        #expect(hidden != nil && standard != nil && custom != nil, "渲染失败")
        #expect(hidden != standard, "`.hidden` 与 `.standard` 渲染相同 —— 标签根本没画出来")
        #expect(standard != custom, "自定义文案与默认文案渲染相同 —— 调用方传入的文案没生效")
    }

    /// AC：默认 "Before" / "After" 是 `LocalizedStringResource`（公约 §4 A 类），
    /// 且**真的经本 target 自己的 `Bundle.module` 查表**——否则它永远只能落到宿主 App。
    @Test("默认文案走本 target 的 Bundle.module（哨兵键证明查表命中，而非静默回退）")
    func defaultLabelsResolveThroughModuleBundle() {
        // ⚠️ 哨兵的译文与 key **有意不同**：查表 miss 时 Foundation 原样返回 key，
        // 只有译文 != key 时才能区分「命中」与「静默回退」（同 `CoreDesignCharts` 的成法）。
        #expect(String(localized: .effectsChrome("__localization_probe__")) == "resource-bundle-resolved",
                "本 target 的 Bundle.module 查表没有命中 —— chrome 文案永远无法由本包提供翻译")
        #expect(String(localized: BeforeAfterSliderLabels.defaultBefore) == "Before")
        #expect(String(localized: BeforeAfterSliderLabels.defaultAfter) == "After")
    }

    /// ⚠️⚠️ **入场摆动不得覆盖用户的拖拽**（#253 PR #273 终审 I-6）。
    ///
    /// `playIntroSweep` 的回程发生在 `sweepDuration × 2 ≈ 1.1s` 之后，而
    /// `DragGesture.onChanged` 写的是**同一个** `fraction`。上一版两者无协调 ⇒ 用户在
    /// 0.55s 的外扫段抓住把手拖到别处，回程一触发就被 `withAnimation` 拽回 0.5。
    /// 对一个"就是要你马上抓"的组件，这个窗口非常现实。
    ///
    /// ⚠️ 与本 suite 其余 Reduce Motion 判据同形态：**纯函数 + 调用点源码**两条链。
    /// 位图路结构上不可达（`.task` 在 macOS 的 `ImageRenderer` 下根本不跑，
    /// 而"1.1s 之后有没有被拽回"是一个时序事实，静态帧拍不到）。
    @Test("入场摆动的回程被 hasInteracted 门控（纯函数）")
    func settleIsGatedByInteraction() {
        #expect(BeforeAfterSweep.settlesAfterSweep(hasInteracted: true) == false,
                "用户已经拖过了，回程还要执行 —— 显式输入会被一个提示动画拽回正中")
        // ⚠️ **互锁**：没碰过时回程必须执行，否则上面那条对「永远返回 false」的实现也恒真
        //（而那就是把入场摆动砍成"只出不回"）。
        #expect(BeforeAfterSweep.settlesAfterSweep(hasInteracted: false) == true,
                "没人碰过也不回程 —— 上面那条断言是恒真的")
    }

    @Test("调用点：onChanged 置位 hasInteracted，回程先过 settlesAfterSweep 闸")
    func introSweepYieldsToTheDrag() throws {
        let code = MicroInteractionReduceMotionGuard.stripComments(try Self.source("BeforeAfterSlider.swift"))
        func count(_ needle: String) -> Int { code.components(separatedBy: needle).count - 1 }

        #expect(count("self.hasInteracted = true") == 1, """
        拖拽没有置位 `hasInteracted`（命中 \(count("self.hasInteracted = true")) 次）——
        入场摆动的回程会把用户拖到的位置拽回 0.5。
        """)
        #expect(count("settlesAfterSweep(hasInteracted: self.hasInteracted)") == 1, """
        回程没有过 `BeforeAfterSweep.settlesAfterSweep` 闸
        （命中 \(count("settlesAfterSweep(hasInteracted: self.hasInteracted)")) 次）。
        """)

        // ⚠️ **顺序也是承重的**：闸必须在回程那次 `withAnimation` 之**前**。
        // 挖掉闸函数自己的函数体，剩下的就是调用点（同本 suite 其余源码判据的成法）。
        let callSites = ConfettiTests.removingRegion(after: "static func settlesAfterSweep(", in: code)
        #expect(callSites != code, "没能挖掉闸函数的函数体 —— 下面的顺序断言会被闸本身干扰")
        let gate = try #require(callSites.range(of: "settlesAfterSweep(hasInteracted: self.hasInteracted)"),
                                "调用点上找不到闸")
        let settle = try #require(callSites.range(of: "self.fraction = sweep.settle"),
                                  "找不到回程那次赋值 —— 入场摆动没有回程了？")
        #expect(gate.lowerBound < settle.lowerBound,
                "`settlesAfterSweep` 闸写在回程赋值之后 —— 挡不住任何东西")
    }

    /// AC：触控目标测试**在本 target 内同形态实现**，不进 `CoreDesignTests.TouchTargetTests`。
    /// 平台无关的那一半：把手的命中尺寸常量本身。
    @Test("把手命中尺寸常量 ≥ 44pt")
    func handleHitSizeConstantMeetsMinimum() {
        #expect(BeforeAfterSweep.handleHitSize >= 44,
                "把手命中尺寸 \(BeforeAfterSweep.handleHitSize)pt < 44pt —— 触控目标不达标")
    }
}

// ⚠️ **与 `CoreDesignTests.TouchTargetTests` 同形态**：`ImageRenderer` 量的是 SwiftUI
// **布局 frame**，它等于命中区的前提是 `contentShape` 挂在最外层、盖住完整 frame
// ——`BeforeAfterSliderHandle` 满足这个前提（`frame(width:height:)` 之后才施加
// `contentShape`）。整个 suite `#if os(iOS)`，只在 xcodebuild iOS Simulator 腿上执行；
// 平台无关的那一半在 `BeforeAfterSliderTests.handleHitSizeConstantMeetsMinimum`。
#if os(iOS)
@Suite("BeforeAfterSlider 触控目标 ≥ 44pt")
@MainActor
struct BeforeAfterSliderTouchTargetTests {

    private func renderedSize(_ view: some View) -> CGSize {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        return renderer.uiImage?.size ?? .zero
    }

    @Test("拖拽把手实测命中区两个方向都 ≥ 44pt")
    func handleMeetsMinimumTouchTarget() {
        let size = self.renderedSize(BeforeAfterSliderHandle().frame(height: 140))
        #expect(size.width >= 44, "把手实测命中宽度 \(size.width)pt < 44pt")
        #expect(size.height >= 44, "把手实测命中高度 \(size.height)pt < 44pt")
    }
}
#endif

// MARK: - ParticleTransition

@Suite("ParticleTransition 的相位、取色与降级契约")
@MainActor
struct ParticleTransitionTests {

    static func source(_ fileName: String) throws -> String {
        try TypewriterTextTests.source(fileName)
    }

    /// ⚠️ 粒子走 `Canvas`，与 `ConfettiTests.canvasWarmUp` 同一条首帧伪影，先跑热。
    private static let canvasWarmUp: Bool = {
        let probe = ParticleBurstLayer(progress: 0.4, count: 24, colors: [])
            .frame(width: 160, height: 160)
            .background(Color.surfaceRaised)
        for _ in 0..<8 { _ = MicroInteractionAPITests.stablePixels(probe) }
        return true
    }()

    static func pixels(_ view: some View) -> Data? {
        _ = Self.canvasWarmUp
        return MicroInteractionAPITests.stablePixels(view)
    }

    static func burst(progress: Double, colors: [Color] = []) -> some View {
        ParticleBurstLayer(progress: progress, count: 24, colors: colors)
            .frame(width: 160, height: 160)
            .background(Color.surfaceRaised)
    }

    @Test("相位映射：identity ⇒ 进度 0（不画粒子），进出两侧都在动")
    func progressMapping() {
        #expect(ParticleBurst.progress(phase: .identity) == 0)
        #expect(ParticleBurst.progress(phase: .willAppear) > 0)
        #expect(ParticleBurst.progress(phase: .didDisappear) > 0)
        // 内容自身：identity 必须完全不透明、不缩放，否则常驻态就被转场改了样子。
        #expect(ParticleBurst.contentOpacity(phase: .identity) == 1)
        #expect(ParticleBurst.contentScale(phase: .identity) == 1)
        #expect(ParticleBurst.contentOpacity(phase: .willAppear) < 1)
        #expect(ParticleBurst.contentScale(phase: .willAppear) != 1)
    }

    /// 终帧（identity）一颗粒子都不剩——否则转场结束后画面上永久挂着粒子。
    @Test("identity 相位一颗粒子都不画")
    func identityFrameDrawsNothing() {
        let empty = Self.pixels(Color.clear.frame(width: 160, height: 160).background(Color.surfaceRaised))
        #expect(empty != nil, "基线渲染失败，下面的相等断言会静默变绿")
        #expect(empty?.contains(where: { $0 != 0 }) == true, "基线位图全 0 —— 相等断言恒真")
        #expect(Self.pixels(Self.burst(progress: ParticleBurst.progress(phase: .identity))) == empty,
                "identity 相位还有粒子 —— 转场结束后会永久残留")
        // ⚠️ **互锁**：中途必须画得出粒子，否则上一条是恒真的。
        #expect(Self.pixels(Self.burst(progress: 0.4)) != empty,
                "progress = 0.4 都画不出粒子 —— 上一条相等断言是恒真的")
    }

    /// 三个**真实相位**下渲染 `ParticleTransitionChrome` 本体（不是绕过它直接渲绘制层）。
    static func chrome(phase: TransitionPhase, count: Int = 24) -> some View {
        Color.surfaceRaised
            .frame(width: 160, height: 160)
            .modifier(ParticleTransitionChrome(phase: phase, count: count, colors: []))
            .frame(width: 200, height: 200)
            .background(Color.contentPrimary)
    }

    private static let chromeWarmUp: Bool = {
        for _ in 0..<8 {
            _ = MicroInteractionAPITests.stablePixels(Self.chrome(phase: .willAppear))
            _ = MicroInteractionAPITests.stablePixels(Self.chrome(phase: .willAppear, count: 0))
        }
        return true
    }()

    static func chromePixels(phase: TransitionPhase, count: Int = 24) -> Data? {
        _ = Self.chromeWarmUp
        return MicroInteractionAPITests.stablePixels(Self.chrome(phase: phase, count: count))
    }

    /// SwiftUI 在一次动画事务里对 `Animatable` 视图做的**正是这三步**：
    /// 取两端的 `animatableData`、按 `amount` 插值、写回视图。本函数逐字复刻它。
    ///
    /// ⚠️ **走存在类型 `any View & Animatable` 而不是直接写具体类型**：
    /// 去掉 `ParticleBurstLayer` 的 `Animatable` 一致性时，判据是**运行时判红**
    /// （`as?` 返回 nil ⇒ 本函数返回 nil ⇒ `#require` 抛出），而不是"整个测试 target
    /// 编译不过"——后者在变异实证里读不出是哪一条判据在咬。
    static func interpolatedLayer(from: Double, to: Double, amount: Double) -> AnyView? {
        let lhs: Any = ParticleBurstLayer(progress: from, count: 24, colors: [])
        let rhs: Any = ParticleBurstLayer(progress: to, count: 24, colors: [])
        guard let start = lhs as? (any View & Animatable),
              let end = rhs as? (any Animatable) else { return nil }
        return Self.blend(start, towards: end, amount: amount)
    }

    private static func blend<A: View & Animatable>(
        _ start: A, towards end: any Animatable, amount: Double
    ) -> AnyView? {
        guard let target = end.animatableData as? A.AnimatableData else { return nil }
        var out = start
        var data = start.animatableData
        data.interpolate(towards: target, amount: amount)
        out.animatableData = data
        return AnyView(out)
    }

    /// ⚠️⚠️⚠️ **承重判据（#253 PR #273 终审 C-A）：粒子在动画中间真的画得出来。**
    ///
    /// ## 缺陷形态
    ///
    /// 上一版的粒子层在**任何真实相位**上都画不出一颗粒子，四步实证：
    ///
    /// 1. `TransitionPhase` 是 **3 case frozen enum**（`willAppear` / `identity` /
    ///    `didDisappear`）⇒ `body(content:phase:)` 只可能拿到这三个值；
    /// 2. 打表实测 `value = -1 / 0 / 1` ⇒ `ParticleBurst.progress` 的**可达取值只有
    ///    `{0.0, 1.0}`**；
    /// 3. 这两个值上所有粒子 alpha **恒为 0**（实测 `maxAlpha = 0.0`）；
    /// 4. 三个相位下直接渲 `ParticleTransitionChrome`，与「无粒子层版本」**逐字节相同**。
    ///
    /// 而 `ParticleBurstLayer` 当时是普通 `View`——不 conform `Animatable`、无
    /// `TimelineView` ⇒ **没有中间相位来救场**：SwiftUI 只插值可动画属性，
    /// 不插值 `Canvas` 的绘制内容。「一圈粒子飞散」从未发生过。
    ///
    /// ## 为什么判据不能写成「某个真实相位必须画出粒子」
    ///
    /// 那对**任何正确实现**都会判红：`progress == 0` 是恒等相位（画一颗都是永久残留），
    /// `progress == 1` 是"完全进入前 / 完全离开后"（内容不透明度也恰为 0，
    /// 那一端留可见粒子就是一次 pop）⇒ **两端都不画是正确形态**。
    /// ⇒ 承重的是**插值中间值**这条链，本判据钉它：把 SwiftUI 的插值步骤原样跑一遍，
    /// 结果必须画得出粒子、且必须等于直接用中间进度构造的层。
    @Test("粒子层可被 SwiftUI 插值：动画中间值真的画得出粒子")
    func chromeDrawsParticlesMidFlight() throws {
        let empty = try #require(
            Self.pixels(Color.clear.frame(width: 160, height: 160).background(Color.surfaceRaised)),
            "基线渲染失败"
        )
        #expect(empty.contains(where: { $0 != 0 }) == true, "基线位图全 0 —— 下面的不等断言恒真")

        // 端点取**真实相位**给出的两个值，而不是随手写的字面量。
        let from = ParticleBurst.progress(phase: .willAppear)   // 1
        let to = ParticleBurst.progress(phase: .identity)       // 0
        let amount = 0.6                                        // ⇒ 中间进度 0.4

        let interpolated = try #require(Self.interpolatedLayer(from: from, to: to, amount: amount), """
        `ParticleBurstLayer` 不是 `Animatable`（或它的 `animatableData` 不是 `Double`）——
        SwiftUI 于是只在三个离散相位上求值它，而那三个值上一颗粒子都画不出来
        ⇒ 「一圈粒子飞散」根本不会发生（终审 C-A）。
        """)
        let midFlight = try #require(
            Self.pixels(AnyView(interpolated).frame(width: 160, height: 160).background(Color.surfaceRaised)),
            "渲染失败"
        )
        #expect(midFlight != empty, """
        把两个真实相位的 `animatableData` 插到中间（\(from) → \(to) @ \(amount)）之后，
        粒子层仍然什么都不画 —— 这条转场的粒子在用户面前永远不会出现。
        """)

        // `animatableData` 必须**真的绑在 `progress` 上**，而不是某个不参与绘制的字段：
        // 插出来的那一帧必须与"直接用中间进度构造"的层逐字节相同。
        let direct = try #require(
            Self.pixels(Self.burst(progress: from + (to - from) * amount)), "渲染失败"
        )
        #expect(midFlight == direct, """
        插值出来的那一帧与 `ParticleBurstLayer(progress: \(from + (to - from) * amount))`
        不同 —— `animatableData` 没有绑在 `progress` 上，插值改不动绘制。
        """)
    }

    /// ⚠️⚠️ **C-A 的另一半（终审 I-B）：粒子层必须整段动画都在树上。**
    ///
    /// 上一版的 overlay 条件是 `progress > 0 && self.count > 0`（PR #273 Copilot inline
    /// 的「恒等相位跳过整层」）。它当时"无害"的**唯一**原因是粒子本来就画不出来
    /// ——注释却写成「这不改变任何一帧的像素（`identityFrameDrawsNothing` 仍逐字节相等）」，
    /// 而那条判据测的是 `ParticleBurstLayer` **自己**、从不经过
    /// `ParticleTransitionChrome` ⇒ 对这个分支**零可见性**。
    ///
    /// C-A 修好之后这个 `if` 会**在恒等那一端截断动画**（插值的前提是视图一直在树上），
    /// 且 `if` 翻转还会给子树套上默认 `.opacity` 转场。⇒ 条件里绝不能再出现 `progress`。
    ///
    /// ⚠️ **只能是源码判据**：位图路观测不到"动画中途视图有没有被摘掉"
    ///（`ImageRenderer` 拍的是静态帧，而三个真实相位下画的本来就都是空）。
    @Test("调用点：overlay 条件只看粒子数、不看进度（否则插值被截断）")
    func particleLayerSurvivesTheWholeTransition() throws {
        let code = MicroInteractionReduceMotionGuard.stripComments(try Self.source("ParticleTransition.swift"))
        func count(_ needle: String) -> Int { code.components(separatedBy: needle).count - 1 }

        #expect(count("let drawsParticles = self.count > 0") == 1, """
        overlay 的门控不是 `self.count > 0`（命中 \(count("let drawsParticles = self.count > 0")) 次）——
        条件里一旦带上 `progress`，恒等那一端会把整层摘掉：进场的收尾、出场的起手都被截断，
        粒子只在动画中段闪一下。
        """)

        guard let body = ConfettiTests.bracedRegion(after: "func body(content: Content) -> some View", in: code) else {
            Issue.record("找不到 `ParticleTransitionChrome.body(content:)` —— 下面的断言无从谈起")
            return
        }
        #expect(!body.contains("progress > 0"), """
        `ParticleTransitionChrome.body(content:)` 里出现了 `progress > 0` —— 这正是被移除的那个门控。
        """)
        #expect(body.contains("ParticleBurstLayer(progress: progress"),
                "overlay 里交给粒子层的不是本次相位算出的 `progress` —— 插值链断了")
    }

    /// ⚠️ **三个真实相位下 chrome 画不出粒子，这是正确形态、不是缺陷残留**（终审 C-A）。
    ///
    /// 本条把 `identityFrameDrawsNothing` 从绘制层**抬到 `ParticleTransitionChrome` 本体**
    /// ——那条测的是 `ParticleBurstLayer` 自己，对 chrome 的 `if drawsParticles`
    /// 分支零可见性（终审 I-B 逐字）。这里直接渲 chrome，并与「粒子数为 0」那一版比。
    ///
    /// ⚠️ **本条不是 C-A 的承重判据**（它今天和缺陷在时同样是绿的）：
    /// 承重的是 `chromeDrawsParticlesMidFlight`。留它是为了钉住「恒等相位不留残留」
    /// 与「`count == 0` 那一半确实什么都不改变」这两件事在 chrome 层被观测过。
    @Test("三个真实相位下 chrome 与「粒子数为 0」版逐字节相同（两端本就不画）")
    func chromeAtRealPhasesDrawsNothing() throws {
        for (name, phase) in [("willAppear", TransitionPhase.willAppear),
                              ("identity", .identity),
                              ("didDisappear", .didDisappear)] {
            let withParticles = try #require(Self.chromePixels(phase: phase), "渲染失败：\(name)")
            let without = try #require(Self.chromePixels(phase: phase, count: 0), "渲染失败：\(name)/count=0")
            #expect(withParticles.contains(where: { $0 != 0 }) == true, "位图全 0 —— 相等断言恒真")
            #expect(withParticles == without, """
            相位 \(name) 下 chrome 与「粒子数为 0」版不同 —— 该相位的 progress 是
            \(ParticleBurst.progress(phase: phase))，两端的粒子 alpha 都应恒为 0。
            恒等相位画出粒子 = 转场结束后永久残留；端点画出粒子 = 一次 pop。
            """)
        }
        // ⚠️ **互锁**：中间进度必须画得出粒子，否则上面三条相等断言只是在说
        // "粒子层永远什么都不画"（那正是 C-A 的缺陷形态）。
        #expect(Self.pixels(Self.burst(progress: 0.4))
                != Self.pixels(Color.clear.frame(width: 160, height: 160).background(Color.surfaceRaised)),
                "中间进度也画不出粒子 —— 上面三条相等断言是恒真的")
    }

    /// AC / FR-8：空色板 ⇒ 取调用方 `.tint`，不自带色板。
    @Test("空色板 ⇒ 粒子色跟随调用方 .tint；给了色板则不跟随")
    func particlesFollowCallerTint() {
        let red = Self.pixels(Self.burst(progress: 0.4).tint(.red))
        let blue = Self.pixels(Self.burst(progress: 0.4).tint(.blue))
        #expect(red != nil && blue != nil, "渲染失败")
        #expect(red != blue, "空色板下换 .tint 位图不变 —— 取色没有走 .tint")

        let palette: [Color] = [.surfaceRaised, .contentPrimary]
        #expect(Self.pixels(Self.burst(progress: 0.4, colors: palette).tint(.red))
                == Self.pixels(Self.burst(progress: 0.4, colors: palette).tint(.blue)),
                "给了色板还跟着 .tint 变 —— 调用方参数没有生效")
    }

    /// ⚠️⚠️ **Reduce Motion 降级不是 no-op**（#250 第 1 轮因此被打回）：
    /// 早退分支必须仍然让内容淡入淡出，只是不放粒子、不缩放。
    @Test("Reduce Motion 分支保留淡入淡出，且不建粒子层")
    func reduceMotionKeepsTheFade() throws {
        let code = MicroInteractionReduceMotionGuard.stripComments(try Self.source("ParticleTransition.swift"))
        // ⚠️ **配对括号取分支体**，不用"找下一个 `}`"——后者会在第一个嵌套闭包处截断。
        // 复用 `ConfettiTests` 已有的那份实现，不另抄一遍。
        guard let branch = ConfettiTests.bracedRegion(after: "guard !isReduced else", in: code) else {
            Issue.record("ParticleTransition 里找不到 Reduce Motion 早退 —— 降级没有落地")
            return
        }
        #expect(branch.contains("ParticleBurst.contentOpacity("),
                "Reduce Motion 分支没有保留淡入淡出 —— 那就是 no-op")
        #expect(!branch.contains("ParticleBurstLayer("),
                "Reduce Motion 分支还建了粒子层 —— 降级没有落地")
        #expect(!branch.contains("contentScale("),
                "Reduce Motion 分支还在缩放 —— 缩放同样属于 FR-11 的运动")
    }

    /// `.transition(.particle)` 点语法与含参重载都在，且可用于真实视图。
    @Test("Transition 静态成员存在，两种写法都可用")
    func staticTransitionMembersExist() {
        let plain = Text("x").transition(.particle)
        let configured = Text("x").transition(.particle(count: 8, colors: [.surfaceRaised]))
        #expect(MicroInteractionAPITests.stablePixels(plain) != nil)
        #expect(MicroInteractionAPITests.stablePixels(configured) != nil)
        #expect(ParticleTransition().count > 0, "默认粒子数为 0 —— 这个转场什么都不放")
    }
}
