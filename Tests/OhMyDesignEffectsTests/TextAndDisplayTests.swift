import OhMyDesign
import Foundation
import SwiftUI
import Testing

@testable import OhMyDesignEffects

// MARK: - #253：文本与展示动效（TypewriterText / AnimatedMeshGradient / BeforeAfterSlider / ParticleTransition）

// MARK: - TypewriterText

@Suite("TypewriterText 的揭示契约")
@MainActor
struct TypewriterTextTests {
    static func source(_ fileName: String) throws -> String {
        let url = MicroInteractionReduceMotionGuard.sourceRoot.appendingPathComponent(fileName)
        return try String(contentsOf: url, encoding: .utf8)
    }

    static func renderedSize(_ view: some View) -> CGSize {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        #if canImport(UIKit)
        return renderer.uiImage?.size ?? .zero
        #else
        return renderer.nsImage?.size ?? .zero
        #endif
    }

    @Test("Reduce Motion ⇒ 揭示数直接跳到全文，与已打了多少字无关")
    func reduceMotionRevealsEverything() {
        for typed in [0, 1, 4, 99] {
            #expect(TypewriterReveal.plan(total: 12, typed: typed, reduceMotion: true).revealed == 12,
                    "Reduce Motion 下 typed=\(typed) 没有直接给出全文 —— 用户会看到一段被截断的文字")
        }
        #expect(TypewriterReveal.plan(total: 12, typed: 0, reduceMotion: true).types == false)
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
        let callSites = ConfettiTests.removingRegion(after: "static func plan(", in: code)
        #expect(callSites != code, "没能挖掉闸函数的函数体 —— 下面的断言会把闸本身报成违规")
        let strays = MicroInteractionReduceMotionGuard.bareReduceMotionOccurrences(in: callSites)
        #expect(strays.isEmpty, "裸写的 reduceMotion（去掉 `self.` 就能绕过上面的字面计数）：\n\(strays.joined(separator: "\n"))")
    }

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
        // `#330` 起 `plan.types` 不再直接传给状态机，而是先包进 `run`（`.task(id:)` 与
        // 状态机共用同一个值），所以要钉的是**构造 run 的那一句**加**两处都用同一个 run**。
        #expect(count("TypewriterRun(text: self.text, typing: plan.types, speed: self.speed)") == 1, """
        `run` 不是由 `plan.types` 构造的（命中 \(count("TypewriterRun(text: self.text, typing: plan.types, speed: self.speed)")) 次）——
        写成 `typing: false` 会让逐字推进整个停掉，而闸的输入判据仍然全绿。
        """)
        #expect(count("await self.type(run: run,") == 1, """
        状态机拿到的不是上面绑定的那个 `run`（命中 \(count("await self.type(run: run,")) 次）。
        ⚠️ `#330` 把 run 从 `.task(id:)` 的内联表达式提成了绑定，**新增了一个攻击面**：
        id 用一个 run、状态机用另一个 run，两边就不再同步——`typedRun != run` 的归零判断会失准。
        """)
    }

    @Test("TypewriterPlan 只许在 TypewriterReveal.plan 的函数体内被构造")
    func planIsOnlyEverBuiltByTheGate() throws {
        let marker = "static func plan(total: Int, typed: Int, reduceMotion: Bool)"
        var offenders: [String] = []
        var gateCalls = 0
        for url in try MicroInteractionReduceMotionGuard.swiftFiles() {
            let code = MicroInteractionReduceMotionGuard.stripComments(
                try String(contentsOf: url, encoding: .utf8)
            )
            gateCalls += code.components(separatedBy: "TypewriterReveal.plan(").count - 1

            let declarations = code.components(separatedBy: "static func plan(").count - 1
            if declarations > 1 {
                offenders.append("""
                \(url.lastPathComponent)：`plan` 声明了 \(declarations) 次（有重载）——
                重载会把自己的函数体一起从"闸之外"的扫描面里挖掉，本判据对它零可见性。
                """)
                continue
            }
            guard code.contains("TypewriterPlan(") else { continue }
            let outside = ConfettiTests.removingRegion(after: marker, in: code)
            let remaining = outside.components(separatedBy: "TypewriterPlan(").count - 1
            if remaining > 0 { offenders.append("\(url.lastPathComponent)：\(remaining) 处") }
        }
        #expect(offenders.isEmpty, """
        `TypewriterPlan` 在 `TypewriterReveal.plan` 的函数体之外被构造了，或 `plan` 有重载：
        \(offenders.joined(separator: "\n"))
        —— 那正是"闸的结论被后处理掉"这枚变异的形态（终审 S-A ① / I-3）：
        `plan(...).recomputed(...)` 会让 Reduce Motion 在渲染路径上完全失效，
        而三条逐次计数判据全部照绿。
        """)

        #expect(gateCalls == 1, """
        `TypewriterReveal.plan(` 在 `Sources/OhMyDesignEffects` 里被调用了 \(gateCalls) 次
        —— 只许有 `TypewriterText.body` 那一次。多出来的那次可以写成
        `reduceMotion: false` 把闸的结论重算掉，且因为它把构造转包给闸自己，
        上面那条"只许在闸的函数体里构造"完全看不见它。
        """)

        let gate = MicroInteractionReduceMotionGuard.stripComments(try Self.source("TypewriterText.swift"))
        guard let body = ConfettiTests.bracedRegion(after: marker, in: gate) else {
            Issue.record("找不到 `TypewriterReveal.plan` 的函数体 —— 上面那条判据是恒真的")
            return
        }
        #expect(body.components(separatedBy: "TypewriterPlan(").count - 1 == 2,
                "闸的函数体里构造 `TypewriterPlan` 的次数不是 2（Reduce Motion 一次 + 常规一次）")

        guard let planType = ConfettiTests.bracedRegion(after: "struct TypewriterPlan", in: gate) else {
            Issue.record("找不到 `TypewriterPlan` 的类型体 —— 下面的 `let` 断言无从谈起")
            return
        }
        #expect(ParticleTransitionTests.squeezed(planType) == "{ let revealed: Int let types: Bool }", """
        `TypewriterPlan` 不再是「两个 `let` 存储属性」（实测 \(ParticleTransitionTests.squeezed(planType))）。
        只要有一个字段可变，`var p = TypewriterReveal.plan(...); p.revealed = total`
        就能在**不构造第二个 `TypewriterPlan`** 的前提下把闸的结论覆盖掉
        ⇒ 上面那条恒绿、三条逐次计数也照绿，而 Reduce Motion 在渲染路径上完全失效。
        """)
    }

    @Test("调用点：打字任务的 id 带上 plan.types 与 speed，且不多读一次环境")
    func typingTaskRestartsOnPlanAndSpeed() throws {
        let code = MicroInteractionReduceMotionGuard.stripComments(try Self.source("TypewriterText.swift"))
        func count(_ needle: String) -> Int { code.components(separatedBy: needle).count - 1 }

        #expect(count(".task(id:") == 1,
                "本文件里有 \(count(".task(id:")) 个 `.task(id:)` —— 下面的逐字判据不再说明「那一个」用的是什么")
        // ⚠️ **钉整段，不是钉几行。** `#330` 把 `run` 从 `.task(id:)` 的内联表达式提成了绑定，
        // 原来「id 与状态机入参同源」是**语法上必然**的，现在只是**写法上碰巧**。
        // 逐条 `count(...) == 1` 挡不住**遮蔽**：在 `.task(id: run) { }` 闭包内插一句
        // `let run = TypewriterRun(text: self.text, typing: false, speed: self.speed)`，
        // 上面那些计数全部照旧 == 1、套件 14/14 全绿（实测），而 id 与状态机已经是两个 run。
        // 这与 `CelebrationAndProcessingTests` 钉 `runBurst` 整段是同一族对策、同一个理由。
        guard let bodyRegion = ConfettiTests.bracedRegion(
            after: "public var body: some View {", in: code
        ) else {
            Issue.record("找不到 TypewriterText.body 声明")
            return
        }
        let expectedBody = """
        {
            let total = TypewriterReveal.characterCount(of: self.text)
            let plan = TypewriterReveal.plan(
                total: total, typed: self.typed, reduceMotion: self.reduceMotion
            )
            let run = TypewriterRun(text: self.text, typing: plan.types, speed: self.speed)
            TypewriterBody(text: self.text, revealed: plan.revealed)
                .task(id: run) {
                    await self.type(run: run, total: total)
                }
        }
        """
        #expect(
            ConfettiTests.dense(bodyRegion)
                == ConfettiTests.dense(expectedBody),
            """
            `TypewriterText.body` 与期望**整段**不一致（比对前去掉全部空白）。

            少了 `plan.types` ⇒ 切换 Reduce Motion 时旧任务不被取消，会继续逐字写状态跑到底；
            少了 `speed` ⇒ 换速度不重启；id 与 `type(run:)` 用上不同的 `run` ⇒
            `typedRun != run` 的归零判断失准、`#330` 的修复静默失效。

            代价：合法地改 body 必须同步更新上面那段期望串。这是**有意付的**——
            见上方注释里那条遮蔽变异。

            实得：
            \(bodyRegion)
            """
        )
    }

    @Test("#330：视图重新出现时不从头重打——归零只发生在 run 真的变了的时候")
    func reappearDoesNotRestartTyping() throws {
        let code = MicroInteractionReduceMotionGuard.stripComments(try Self.source("TypewriterText.swift"))
        func count(_ needle: String) -> Int { code.components(separatedBy: needle).count - 1 }

        #expect(count("self.typed = 0") == 1,
                "把 typed 归零的地方有 \(count("self.typed = 0")) 处 —— 下面那条「只在 run 变了时归零」不再说明全部归零点")
        #expect(code.contains("""
        if self.typedRun != run {
                    self.typedRun = run
                    self.typed = 0
                }
        """.trimmingCharacters(in: .whitespacesAndNewlines)), """
        归零不再被 `typedRun != run` 门控（`#330`）。
        ⚠️ `.task(id:)` 在**视图重新出现**时会以**当前 id** 重跑（不只是 id 变化时），
        所以无条件 `typed = 0` 会让默认样式 TabView 切回 / LazyVStack 滚回时**整段文字从头重打**。
        实测：切回 0.5 s 时截图只到句子中段，3 s 后才补全。
        """)
        #expect(code.contains("for index in (self.typed + 1)...total"), """
        循环不再从 `self.typed + 1` 起（`#330`）—— 从 1 起会把已打出的字重打一遍，
        「不归零」也就白做了；打到一半切走再回来的续打同样依赖这一句。
        """)
        #expect(code.contains("guard self.typed < total else { return }"), """
        少了 `self.typed < total` 的提前返回（`#330`）—— `typed == total` 时
        `(total + 1)...total` 是**非法区间，会运行期崩溃**。
        """)
    }

    @Test("#330：入场扫动的三态裁决——被打断时只补回程，不重放也不卡在 peak")
    func introActionCoversEveryPhase() {
        let sweep = BeforeAfterSweep.introSweep(reduceMotion: false)
        #expect(sweep != nil)

        #expect(BeforeAfterSweep.introAction(phase: .pending, sweep: sweep) == .sweep)
        #expect(BeforeAfterSweep.introAction(phase: .pending, sweep: nil) == .idle,
                "Reduce Motion 开着时首次出现不该扫动")
        #expect(BeforeAfterSweep.introAction(phase: .done, sweep: sweep) == .idle,
                "已经播完还再播一次 —— 这就是 `#330` 的重放")
        #expect(BeforeAfterSweep.introAction(phase: .sweeping, sweep: sweep) == .settleOnly, """
        扫到 peak 之后、回程之前被 disappear 打断，重新出现时应当**只补回程**。
        判 `.sweep` ⇒ 重放；判 `.idle` ⇒ 把手**永远停在 peak(0.78)**。
        """)
        #expect(BeforeAfterSweep.introAction(phase: .sweeping, sweep: nil) == .settleOnly, """
        ⚠️ `.sweeping` 遇上 `sweep == nil`（隐藏期间用户打开了 Reduce Motion）
        必须**照样补回程** —— 跟着判 `.idle` 就又卡在 peak 上了。
        """)
    }

    @Test("#330：三个记号都真的是 @State，且没有第二条路径复位它们")
    func reappearMarkersAreStateAndWrittenOnce() throws {
        // ⚠️ **这一条守的是「记号存活」本身，不是它长什么样。** 终审实证：三个修法的**全部**
        // 效力都系在「记号跨 appear 存活」这一个事实上，而按形状写的判据对以下两族**零射程**：
        //   · 记号被**第二条路径**复位（`.onAppear { consumedFire = 0 }`、guard 之前先复位）；
        //   · 记号**不是 `@State`**（换成恒返回初值的计算属性，声明行还在、语义全废）。
        // 六种此类变异当时全部 44/44 绿。⇒ 钉**声明逐字** + **写点计数**。
        func code(_ file: String) throws -> String {
            MicroInteractionReduceMotionGuard.stripComments(try Self.source(file))
        }
        func count(_ needle: String, in text: String) -> Int {
            text.components(separatedBy: needle).count - 1
        }

        let slider = try code("BeforeAfterSlider.swift")
        #expect(count("@State private var introPhase = BeforeAfterSweep.IntroPhase.pending", in: slider) == 1,
                "`introPhase` 的声明不再是那一行 `@State` —— 换成计算属性它就不跨 appear 存活了")
        #expect(count("self.introPhase = ", in: slider) == 3, """
        写 `introPhase` 的地方有 \(count("self.introPhase = ", in: slider)) 处，期望 **3**
        （`.settleOnly` 置 `.done`；`.sweep` 置 `.sweeping` 再置 `.done`）。
        多出来的一处多半是「在 guard 之前先复位」——那会把整个门原样废掉。
        """)

        let confetti = try code("Confetti.swift")
        #expect(count("@State private var consumedFire = 0", in: confetti) == 1,
                "`consumedFire` 的声明不再是那一行 `@State`")
        #expect(count("self.consumedFire = ", in: confetti) == 1, """
        写 `consumedFire` 的地方有 \(count("self.consumedFire = ", in: confetti)) 处，期望 **1**
        （只在 `.start` 分支记账）。第二处写入 —— 例如 `.onAppear { self.consumedFire = 0 }` ——
        会把 `#330` 的重放原样招回，而 `runBurst` 的整段比对**看不到函数体之外**。
        """)

        let typewriter = try code("TypewriterText.swift")
        #expect(count("@State private var typedRun: TypewriterRun?", in: typewriter) == 1,
                "`typedRun` 的声明不再是那一行 `@State`")
        #expect(count("self.typedRun = ", in: typewriter) == 1,
                "写 `typedRun` 的地方不止一处 —— 第二处复位会让每次 reappear 都重新归零")
        #expect(count("self.typed = ", in: typewriter) == 3, """
        写 `typed` 的地方有 \(count("self.typed = ", in: typewriter)) 处，期望 **3**
        （门控内归零、`guard run.typing` 的 `= total`、循环里的 `= index`）。
        ⚠️ 原来那条 `count("self.typed = 0") == 1` 只数字面 `= 0`，
        终审用 `self.typed = .zero` 一行就绕过了。
        """)
    }

    @Test("TypewriterRun 的相等性真的看三个字段（否则 .task(id:) 形同只看 text）")
    func typewriterRunEqualityUsesEveryField() {
        let base = TypewriterRun(text: "a", typing: true, speed: .slow)

        #expect(base == TypewriterRun(text: "a", typing: true, speed: .slow),
                "同值都不相等 —— `==` 恒 false，下面三条恒真、什么都没证明")
        #expect(base != TypewriterRun(text: "b", typing: true, speed: .slow),
                "`text` 不参与相等 —— 换文案不重启打字任务")
        #expect(base != TypewriterRun(text: "a", typing: false, speed: .slow),
                "`typing` 不参与相等 —— 视图存活期间切换 Reduce Motion 时旧任务不被取消，会继续逐字写状态跑到底")
        #expect(base != TypewriterRun(text: "a", typing: true, speed: .fast),
                "`speed` 不参与相等 —— 换速度不重启，新速度要等下次换文案才生效")
    }

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
        expectBitmapsDiffer(none, all, "0 字与全文渲染完全相同 —— revealed 根本没接到 Text 上")
    }

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

    static let palette: [Color] =
        Array(repeating: Color.surfaceRaised, count: 4) + Array(repeating: Color.contentPrimary, count: 5)
    static let basePalette: [Color] = Array(repeating: Color.surfaceRaised, count: MeshDrift.colorSlots)
    static let altPalette: [Color] = Array(repeating: Color.contentPrimary, count: MeshDrift.colorSlots)

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

    @Test("空色板 ⇒ 取调用方 .tint；给了色板 ⇒ 不再跟随 .tint")
    func emptyPaletteFollowsCallerTint() {
        let red = Self.pixels(Self.body().tint(.red))
        let blue = Self.pixels(Self.body().tint(.blue))
        #expect(red != nil && blue != nil, "渲染失败，下面的不等断言会静默变绿")
        #expect(red?.contains(where: { $0 != 0 }) == true, "位图全 0 —— 断言恒真")
        expectBitmapsDiffer(red, blue, "空色板下换 .tint 位图不变 —— 说明取色没有走 .tint（多半是写死了 Color.accent）")

        let paletteRed = Self.pixels(Self.body(colors: Self.palette).tint(.red))
        let paletteBlue = Self.pixels(Self.body(colors: Self.palette).tint(.blue))
        #expect(paletteRed != nil, "渲染失败")
        expectBitmapsEqual(paletteRed, paletteBlue, "给了色板还跟着 .tint 变 —— 调用方参数没有生效")
    }

    @Test("两组色板真的都接到渲染上：只换 alternateColors 位图必须变")
    func alternatePaletteReachesRendering() {
        let phase = MeshDrift.blendPeakPhase
        let single = Self.pixels(Self.body(phase: phase, colors: Self.basePalette))
        let dual = Self.pixels(
            Self.body(phase: phase, colors: Self.basePalette, alternateColors: Self.altPalette)
        )
        #expect(single != nil && dual != nil, "渲染失败")
        #expect(single?.contains(where: { $0 != 0 }) == true, "位图全 0 —— 不等断言恒真")
        expectBitmapsDiffer(single, dual, "第二组色板对渲染无影响 —— alternateColors 是死参数")
    }

    @Test("只给 alternateColors ⇒ 用那一组色板，不跟随 .tint（已登记的不对称组合）")
    func alternateOnlyPaletteDoesNotFollowTint() {
        #expect(MeshDrift.blended(base: [], alternate: Self.altPalette, phase: 0.3) != nil,
                "只给 alternateColors 时回落到了 .tint 形态 —— 与已登记的行为不符")
        #expect(MeshDrift.blended(base: [], alternate: [], phase: 0.3) == nil,
                "两组都空时没有回落 .tint —— 上面那条不再说明任何事")
        let red = Self.pixels(Self.body(alternateColors: Self.altPalette).tint(.red))
        let blue = Self.pixels(Self.body(alternateColors: Self.altPalette).tint(.blue))
        #expect(red != nil && blue != nil, "渲染失败，下面的相等断言会静默变绿")
        expectBitmapsEqual(red, blue, "只给 alternateColors 时仍跟着 .tint 变 —— 与已登记的行为不符")
    }

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
            expectBitmapsEqual(wrapped(phase), baseline, "\(phase) 下仍然画了东西 —— NFR-7 的停摆没有落地")
        }
        expectBitmapsDiffer(wrapped(.active), baseline, "\(ScenePhase.active) 下也什么都没画 —— 上面的停摆断言是恒真的")
    }

    @Test("注入 .lowPower ⇒ 同一相位下位图与满电不同（柔化那层被去掉）")
    func lowPowerChangesRenderingAtSamePhase() {
        let full = Self.pixels(Self.body(lowPower: false))
        let low = Self.pixels(Self.body(lowPower: true))
        #expect(full != nil && low != nil, "渲染失败，下面的不等断言会静默变绿")
        #expect(full?.contains(where: { $0 != 0 }) == true, "位图全 0")
        expectBitmapsDiffer(full, low, "低电量与满电渲染完全一致 —— 注入的 \\.lowPowerModeOverride 没有影响渲染")
    }

    @Test("相位真的接到渲染：不同相位位图不同，静止相位画得出东西")
    func phaseReachesRendering() {
        let resting = Self.pixels(Self.body(phase: MeshDrift.restingPhase))
        let other = Self.pixels(Self.body(phase: MeshDrift.restingPhase + 0.25))
        #expect(resting != nil && other != nil, "渲染失败")
        expectBitmapsDiffer(resting, other, "换相位位图不变 —— 网格点没有随相位漂移")
    }

    @Test("相位恒落在 [0, 1)")
    func phaseStaysInRange() {
        for offset in [0.0, 0.3, 1.9, -2.7, 12345.6] {
            let p = MeshDrift.phase(at: Date(timeIntervalSinceReferenceDate: offset))
            #expect(p >= 0 && p < 1, "相位越界：\(p)")
        }
    }

    @Test("Reduce Motion 分支渲染的是钉在静止相位上的网格，不是 no-op")
    func reduceMotionFreezesOnARealFrame() throws {
        let code = MicroInteractionReduceMotionGuard.stripComments(try Self.source("AnimatedMeshGradient.swift"))
        guard let restingRange = code.range(of: "case .resting:") else {
            Issue.record("AnimatedMeshGradient 里找不到 `.resting` 分支 —— 两道闸的共享裁决点没接上")
            return
        }
        let tail = String(code[restingRange.upperBound...])
        let branch = tail.components(separatedBy: "case .animated:").first ?? tail
        #expect(branch.contains("AnimatedMeshBody("),
                "Reduce Motion 分支没有画 AnimatedMeshBody —— 降级成了 no-op")
        #expect(branch.contains("MeshDrift.restingPhase"),
                "Reduce Motion 分支没有把相位钉在 MeshDrift.restingPhase 上 —— 那不是「冻结在某一帧」")
        #expect(!branch.contains("TimelineView("),
                "Reduce Motion 分支里还建了 TimelineView —— 冻结没有落地")
    }

    @Test("TimelineView 只在 .animated 分支里存在")
    func timelineOnlyExistsInTheAnimatedBranch() throws {
        let code = MicroInteractionReduceMotionGuard.stripComments(try Self.source("AnimatedMeshGradient.swift"))
        #expect(code.contains("TimelineView("), "整份文件都没有 TimelineView —— 这个效果根本没在动")
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

// MARK: - AnimatedMeshGradient 的 alpha 量程（Issue #276）

@Suite("AnimatedMeshGradient `.tint` 档的 alpha 量程")
struct AnimatedMeshGradientAlphaRangeTests {
    @Test("tintAlphaMask 的实际 alpha 量程必须等于 minimumAlpha…maximumAlpha")
    func tintAlphaMaskSpansItsDeclaredRange() {
        let tolerance = 1.0 / 255
        for (schemeName, scheme) in [("light", ColorScheme.light), ("dark", ColorScheme.dark)] {
            var env = EnvironmentValues()
            env.colorScheme = scheme
            var samples: [Double] = []
            for step in 0...360 {
                let phase = CGFloat(step) / 360
                let colors = MeshDrift.tintAlphaMask(phase: phase)
                #expect(colors.count == MeshDrift.colorSlots,
                        "色位数是 \(colors.count)，不是 \(MeshDrift.colorSlots) —— 下面的量程断言会失去意义")
                samples += colors.map { Double($0.resolve(in: env).opacity) }
            }
            let low = samples.min() ?? -1
            let high = samples.max() ?? -1
            #expect(abs(low - MeshDrift.minimumAlpha) <= tolerance, """
            \(schemeName)：实际最小 alpha = \(low)，而 `MeshDrift.minimumAlpha` 声称 \(MeshDrift.minimumAlpha)。
            `mask` 吃的是 alpha ⇒ 遮罩基色不是满不透明时，这两个常量就不再是实际量程
            （Issue #276：`Color.primary` **macOS 实测 α = 0.8471、iOS 实测 1.0**
            ⇒ 整体暗 15% 只在 macOS 腿上）。基色必须走 `Color.maskOpaque`（契约 α = 1）。
            """)
            #expect(abs(high - MeshDrift.maximumAlpha) <= tolerance, """
            \(schemeName)：实际最大 alpha = \(high)，而 `MeshDrift.maximumAlpha` 声称 \(MeshDrift.maximumAlpha)。
            同上 —— 这正是 Issue #276 的实质损害：常量声称的量程与渲染出来的量程
            在 **macOS** 上差一个 0.847（iOS 上 `label` 实测 α = 1.0，那一腿没有偏差）。
            """)
            let outOfRange = samples.filter {
                $0 < MeshDrift.minimumAlpha - tolerance || $0 > MeshDrift.maximumAlpha + tolerance
            }
            let outOfRangeCount = outOfRange.count
            #expect(outOfRangeCount == 0, """
            \(schemeName)：\(outOfRangeCount) / \(samples.count) 个样本落在
            [\(MeshDrift.minimumAlpha), \(MeshDrift.maximumAlpha)] 之外
            （前 5 个：\(outOfRange.prefix(5).map { String(format: "%.4f", $0) })）。
            """)
        }
    }
}

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

    static let probeWidth = 200
    static let probeHeight = 100
    static let probeInset = 20

    static func rgba(_ data: Data, at x: Int, y: Int) -> (r: Int, g: Int, b: Int, a: Int)? {
        let width = data.count / (Self.probeHeight * 4)
        guard width == Self.probeWidth, x >= 0, x < width, y >= 0, y < Self.probeHeight else { return nil }
        let i = (y * width + x) * 4
        return (Int(data[i]), Int(data[i + 1]), Int(data[i + 2]), Int(data[i + 3]))
    }

    static func probe(
        fraction: CGFloat,
        before: Color,
        after: Color,
        labels: BeforeAfterSliderLabels = .hidden
    ) -> Data? {
        Self.pixels(
            BeforeAfterSliderBody(
                fraction: fraction, labels: labels, before: before, after: after
            )
            .frame(width: CGFloat(Self.probeWidth), height: CGFloat(Self.probeHeight))
        )
    }

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

    @Test("chip 与图层对应：before 的 chip 压在 before 那半（长文案跟着实参走）")
    func beforeChipIsOnTheLeadingSide() throws {
        let narrow: LocalizedStringKey = "l"
        let wide: LocalizedStringKey = "MMMMMMMMMMMM"
        let base = try #require(Self.probe(fraction: 0.5, before: .red, after: .red),
                                "基线渲染失败，下面的计数断言会静默变绿")
        let beforeIsWide = try #require(Self.probe(
            fraction: 0.5, before: .red, after: .red, labels: .shown(before: wide, after: narrow)
        ), "渲染失败")
        let afterIsWide = try #require(Self.probe(
            fraction: 0.5, before: .red, after: .red, labels: .shown(before: narrow, after: wide)
        ), "渲染失败")

        let handle = Self.handleSpan(fraction: 0.5)
        let leftBand = 0..<handle.lowerBound
        let rightBand = handle.upperBound..<Self.probeWidth
        let topBand = 0..<(Self.probeHeight / 2)

        let leftWideBefore = Self.differingPixels(beforeIsWide, from: base, x: leftBand, y: topBand)
        let leftWideAfter = Self.differingPixels(afterIsWide, from: base, x: leftBand, y: topBand)
        let rightWideBefore = Self.differingPixels(beforeIsWide, from: base, x: rightBand, y: topBand)
        let rightWideAfter = Self.differingPixels(afterIsWide, from: base, x: rightBand, y: topBand)

        for (name, n) in [("left/wide-before", leftWideBefore), ("left/wide-after", leftWideAfter),
                          ("right/wide-before", rightWideBefore), ("right/wide-after", rightWideAfter)] {
            #expect(n > 0, "\(name) 一个差异像素都没有 —— chip 根本没画出来，下面的比较是空话")
        }

        #expect(leftWideBefore > leftWideAfter, """
        把长文案给 `before` 时，**左**半的 chip 并没有变宽
        （左半差异像素 \(leftWideBefore) vs 反过来时 \(leftWideAfter)）——
        "Before" 的 chip 没有压在 `before` 那半上。绘制层左边画的是 `before`
        （`beforeIsOnTheLeadingSide` 已钉住），两者对不上 ⇒ 默认标签把两半都标错。
        """)
        #expect(rightWideAfter > rightWideBefore, """
        把长文案给 `after` 时，**右**半的 chip 并没有变宽
        （右半差异像素 \(rightWideAfter) vs 反过来时 \(rightWideBefore)）。
        """)
    }

    @Test("默认档 .standard 的 chip 接线与已被钉住的 .shown 一致")
    func standardLabelsMatchTheShownWiring() throws {
        let before = LocalizedStringKey(String(localized: BeforeAfterSliderLabels.defaultBefore))
        let after = LocalizedStringKey(String(localized: BeforeAfterSliderLabels.defaultAfter))
        func shot(_ labels: BeforeAfterSliderLabels) throws -> Data {
            try #require(Self.probe(fraction: 0.5, before: .red, after: .red, labels: labels),
                         "渲染失败，下面的计数断言会静默变绿")
        }

        let standard = try shot(.standard)
        let inOrder = try shot(.shown(before: before, after: after))
        let swapped = try shot(.shown(before: after, after: before))
        let hidden = try shot(.hidden)

        let full = 0..<Self.probeWidth
        let rows = 0..<Self.probeHeight
        func diff(_ lhs: Data, _ rhs: Data) -> Int {
            Self.differingPixels(lhs, from: rhs, x: full, y: rows)
        }

        #expect(diff(inOrder, swapped) > 0, """
        把两个兜底文案对调之后位图完全没变 —— 它们多半被改成了同一个词，
        下面那条"`.standard` 离顺序正确的那张更近"于是恒真、什么都没证明。
        """)
        #expect(diff(standard, hidden) > 0,
                "`.standard` 与 `.hidden` 逐字节相同 —— 默认档根本没画 chip")
        #expect(diff(standard, inOrder) < diff(standard, swapped), """
        默认档 `.standard` 画出来的更像 `.shown(before: defaultAfter, after: defaultBefore)`
        ——与顺序正确那张差 \(diff(standard, inOrder)) 个像素，与顺序**反过来**那张只差
        \(diff(standard, swapped)) 个 ⇒ `labelOverlay(width:)` 的 `case .standard:`
        那两个实参反了。`.shown` 的左右由 `beforeChipIsOnTheLeadingSide` 钉住、
        绘制层方向由 `beforeIsOnTheLeadingSide` 钉住 ⇒ 现在**默认配置下**
        "Before" 压在 `after` 那半，这正是 C-1 的用户可见后果。
        """)
    }

    static func differingPixels(_ data: Data, from base: Data, x: Range<Int>, y: Range<Int>) -> Int {
        var count = 0
        for row in y {
            for column in x {
                guard let lhs = Self.rgba(data, at: column, y: row),
                      let rhs = Self.rgba(base, at: column, y: row) else { continue }
                if lhs != rhs { count += 1 }
            }
        }
        return count
    }

    static let probeMidLeft = (Int(BeforeAfterSweep.handleHitSize) + Self.probeWidth / 2) / 2
    static let probeMidRight = Self.probeWidth - Self.probeMidLeft

    static func handleSpan(fraction: CGFloat) -> Range<Int> {
        let lead = Int(BeforeAfterSweep.leadingInset(fraction: fraction, width: CGFloat(Self.probeWidth)))
        return lead..<(lead + Int(BeforeAfterSweep.handleHitSize))
    }

    @Test("端点采样点由 handleHitSize 推导，且两个端点形态下都在把手之外")
    func endpointProbesStayOutsideTheHandle() {
        for fraction in [CGFloat(0), 1] {
            let span = Self.handleSpan(fraction: fraction)
            for x in [Self.probeMidLeft, Self.probeMidRight] {
                #expect(!span.contains(x), """
                fraction=\(fraction) 时把手占 \(span)，采样点 x=\(x) 落在里面 ——
                端点判据会对着把手的颜色断言"这是 before / after"。
                改了 probeWidth / handleHitSize 就要重看 probeMidLeft 的推导。
                """)
            }
        }
        #expect(Self.probeMidLeft < Self.probeMidRight, "两个采样点重合或反了")
    }

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

    @Test("端点上被盖住的那一层完全不参与合成（换它的颜色，位图一个字节都不变）")
    func endpointRenderIsIndependentOfTheHiddenLayer() {
        // ⚠️ 探针色用 `.dataAccent`（系统蓝）而不是 `.accent`：后者自 accent 墨色化后
        // 在 **iOS 上与 `.contentPrimary` 同为 `UIColor.label`**，两者位图逐字节相同 ⇒
        // 下面的 `expectBitmapsDiffer` 会恒红，而 macOS 上因 textColor/labelColor 的 α 差
        // 仍差几字节、照绿——典型的「macOS 绿、iOS 红」。探针色必须与 label 族无关。
        //
        // ⚠️⚠️ 两条相等断言走**容差**入口（`#358`）。原来的逐字节 `expectBitmapsEqual`
        // 在单独跑这一条时**失败 8/10**（被其它测试预热后才多数通过，所以全量跑里只有
        // 5–10%）。实测差异是 **3/20000 像素、逐通道 ±1**，位置在 x=197…199 / y=49…51
        // ——`fraction = 1` 时旋钮正落在右边缘，那是它的 SF Symbol 字形抗锯齿边。
        // 决定性证据：**同参数连渲两次也不相同** ⇒ 与 `after` 的取值无关，
        // 是光栅化量化舍入，不是本判据下面消息里说的「遮罩不满不透明」。
        // 该 flake 在 `dd72ff6`（`#356` 之前）同样 3/3 复现，**不是本次改动引入的**。
        let fullyBefore = Self.probe(fraction: 1, before: .surfaceRaised, after: .dataAccent)
        let fullyBeforeOtherAfter = Self.probe(fraction: 1, before: .surfaceRaised, after: .contentPrimary)
        expectBitmapsEquivalent(fullyBefore, fullyBeforeOtherAfter, maxChannelDelta: 1, """
        `fraction = 1`（完全揭示 `before`）时换掉 `after` 的颜色，位图**逐通道偏差超过 1** ——
        说明 `after` 那一层**透上来了**：揭示遮罩不是满不透明的
        （Issue #276：`Color.primary` **macOS 实测 α = 0.8471**、**iOS 实测 1.0**
        ⇒ 露出的那半在 macOS 上以 84.7% 合成，对比越强的两张图 ghosting 越明显）。
        揭示应当走**裁剪**（`BeforeAfterRevealClip`），
        裁剪不涉及 alpha，不存在"揭示到 85%"这种状态。
        """)

        let fullyAfter = Self.probe(fraction: 0, before: .surfaceRaised, after: .dataAccent)
        let fullyAfterOtherBefore = Self.probe(fraction: 0, before: .contentPrimary, after: .dataAccent)
        expectBitmapsEquivalent(fullyAfter, fullyAfterOtherBefore, maxChannelDelta: 1, """
        `fraction = 0`（完全揭示 `after`）时换掉 `before` 的颜色，位图**逐通道偏差超过 1** ——
        `before` 那一层在完全不该出现的位置上仍有像素。
        """)

        let halfA = Self.probe(fraction: 0.5, before: .surfaceRaised, after: .dataAccent)
        let halfB = Self.probe(fraction: 0.5, before: .surfaceRaised, after: .contentPrimary)
        expectBitmapsDiffer(halfA, halfB, """
        `fraction = 0.5` 上换掉 `after` 的颜色位图没变 —— 那说明本用例此刻根本分辨不出
        `after` 的贡献（探针色塌缩 / 渲染失败），上面两条相等断言因此是恒真的。
        """)
    }

    @Test("Reduce Motion ⇒ 没有入场摆动；关闭时才有")
    func introSweepIsGatedByReduceMotion() {
        #expect(BeforeAfterSweep.introSweep(reduceMotion: true) == nil,
                "Reduce Motion 下仍然安排了入场摆动 —— FR-11 的正面违反")
        let sweep = BeforeAfterSweep.introSweep(reduceMotion: false)
        #expect(sweep != nil, "非 Reduce Motion 下也没有入场摆动 —— 上面那条断言是恒真的")
        #expect(sweep?.duration ?? 0 > 0, "摆动时长为 0 —— 等于没有摆动")
        #expect(sweep?.peak != BeforeAfterSweep.initialFraction,
                "摆动的峰值就是初始位置 —— 分隔线一动不动")
        #expect(sweep?.settle == BeforeAfterSweep.initialFraction,
                "摆动结束后没有回到初始位置")
    }

    @Test("拖拽位置是纯几何：钳在 0...1，且随手指单调")
    func dragFractionIsPureGeometry() {
        #expect(BeforeAfterSweep.fraction(dragX: -50, width: 200) == 0)
        #expect(BeforeAfterSweep.fraction(dragX: 500, width: 200) == 1)
        #expect(abs(BeforeAfterSweep.fraction(dragX: 50, width: 200) - 0.25) < 0.0001)
        let degenerate = BeforeAfterSweep.fraction(dragX: 10, width: 0)
        #expect(!degenerate.isNaN, "宽度为 0 时算出了 NaN")
        #expect(degenerate >= 0 && degenerate <= 1)
    }

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
        let callSites = ConfettiTests.removingRegion(after: "static func introSweep(", in: code)
        #expect(callSites != code, "没能挖掉闸函数的函数体 —— 下面的断言会把闸本身报成违规")
        let strays = MicroInteractionReduceMotionGuard.bareReduceMotionOccurrences(in: callSites)
        #expect(strays.isEmpty, "裸写的 reduceMotion：\n\(strays.joined(separator: "\n"))")
    }

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

    @Test("fraction 真的接到渲染：两个位置的位图不同")
    func fractionReachesRendering() {
        let quarter = Self.pixels(Self.slider(fraction: 0.25))
        let threeQuarters = Self.pixels(Self.slider(fraction: 0.75))
        #expect(quarter != nil && threeQuarters != nil, "渲染失败，下面的不等断言会静默变绿")
        #expect(quarter?.contains(where: { $0 != 0 }) == true, "位图全 0")
        expectBitmapsDiffer(quarter, threeQuarters, "换 fraction 位图不变 —— 揭示宽度没有接到渲染上")
    }

    @Test("标签取值域是枚举三档，且三档渲染互不相同")
    func labelDomainIsAnEnumWithThreeDistinctRenderings() {
        let hidden = Self.pixels(Self.slider(labels: .hidden))
        let standard = Self.pixels(Self.slider(labels: .standard))
        let custom = Self.pixels(Self.slider(labels: .shown(before: "Draft", after: "Final")))
        #expect(hidden != nil && standard != nil && custom != nil, "渲染失败")
        expectBitmapsDiffer(hidden, standard, "`.hidden` 与 `.standard` 渲染相同 —— 标签根本没画出来")
        expectBitmapsDiffer(standard, custom, "自定义文案与默认文案渲染相同 —— 调用方传入的文案没生效")
    }

    @Test("默认文案走本 target 的 Bundle.module（哨兵键证明查表命中，而非静默回退）")
    func defaultLabelsResolveThroughModuleBundle() {
        #expect(String(localized: .effectsChrome("__localization_probe__")) == "resource-bundle-resolved",
                "本 target 的 Bundle.module 查表没有命中 —— chrome 文案永远无法由本包提供翻译")
        #expect(String(localized: BeforeAfterSliderLabels.defaultBefore) == "Before")
        #expect(String(localized: BeforeAfterSliderLabels.defaultAfter) == "After")
    }

    @Test("入场摆动的回程被 hasInteracted 门控（纯函数）")
    func settleIsGatedByInteraction() {
        #expect(BeforeAfterSweep.settlesAfterSweep(hasInteracted: true) == false,
                "用户已经拖过了，回程还要执行 —— 显式输入会被一个提示动画拽回正中")
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

        guard let onChanged = ConfettiTests.bracedRegion(after: ".onChanged", in: code) else {
            Issue.record("找不到 `.onChanged` 闭包 —— 拖拽入口没了？")
            return
        }
        #expect(onChanged.contains("self.hasInteracted = true"), """
        `self.hasInteracted = true` 不在 `.onChanged` 闭包里（挪到 `.onEnded` 是终审
        实证过的等价绕过：计数与顺序断言全绿，而摆动窗口内的整段拖拽仍会被回程拽回 0.5）。
        """)

        let callSites = ConfettiTests.removingRegion(after: "static func settlesAfterSweep(", in: code)
        #expect(callSites != code, "没能挖掉闸函数的函数体 —— 下面的顺序断言会被闸本身干扰")
        let gate = try #require(callSites.range(of: "settlesAfterSweep(hasInteracted: self.hasInteracted)"),
                                "调用点上找不到闸")
        let settle = try #require(
            callSites.range(of: "self.fraction = BeforeAfterSweep.initialFraction"),
            "找不到回程那次赋值 —— 入场摆动没有回程了？（`#330` 起回程在 `settleAfterIntro` 里）"
        )
        #expect(gate.lowerBound < settle.lowerBound,
                "`settlesAfterSweep` 闸写在回程赋值之后 —— 挡不住任何东西")
    }

    @Test("把手命中尺寸常量 ≥ 44pt")
    func handleHitSizeConstantMeetsMinimum() {
        #expect(BeforeAfterSweep.handleHitSize >= 44,
                "把手命中尺寸 \(BeforeAfterSweep.handleHitSize)pt < 44pt —— 触控目标不达标")
    }
}

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
        #expect(ParticleBurst.contentOpacity(phase: .identity) == 1)
        #expect(ParticleBurst.contentScale(phase: .identity) == 1)
        #expect(ParticleBurst.contentOpacity(phase: .willAppear) < 1)
        #expect(ParticleBurst.contentScale(phase: .willAppear) != 1)
    }

    @Test("identity 相位一颗粒子都不画")
    func identityFrameDrawsNothing() {
        let empty = Self.pixels(Color.clear.frame(width: 160, height: 160).background(Color.surfaceRaised))
        #expect(empty != nil, "基线渲染失败，下面的相等断言会静默变绿")
        #expect(empty?.contains(where: { $0 != 0 }) == true, "基线位图全 0 —— 相等断言恒真")
        expectBitmapsEqual(Self.pixels(Self.burst(progress: ParticleBurst.progress(phase: .identity))), empty,
                "identity 相位还有粒子 —— 转场结束后会永久残留")
        expectBitmapsDiffer(Self.pixels(Self.burst(progress: 0.4)), empty,
                "progress = 0.4 都画不出粒子 —— 上一条相等断言是恒真的")
    }

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

    @Test("粒子层可被 SwiftUI 插值：动画中间值真的画得出粒子")
    func chromeDrawsParticlesMidFlight() throws {
        let empty = try #require(
            Self.pixels(Color.clear.frame(width: 160, height: 160).background(Color.surfaceRaised)),
            "基线渲染失败"
        )
        #expect(empty.contains(where: { $0 != 0 }) == true, "基线位图全 0 —— 下面的不等断言恒真")

        let from = ParticleBurst.progress(phase: .willAppear)
        let to = ParticleBurst.progress(phase: .identity)
        let amount = 0.6

        let interpolated = try #require(Self.interpolatedLayer(from: from, to: to, amount: amount), """
        `ParticleBurstLayer` 不是 `Animatable`（或它的 `animatableData` 不是 `Double`）——
        SwiftUI 于是只在三个离散相位上求值它，而那三个值上一颗粒子都画不出来
        ⇒ 「一圈粒子飞散」根本不会发生（终审 C-A）。
        """)
        let midFlight = try #require(
            Self.pixels(AnyView(interpolated).frame(width: 160, height: 160).background(Color.surfaceRaised)),
            "渲染失败"
        )
        expectBitmapsDiffer(midFlight, empty, """
        把两个真实相位的 `animatableData` 插到中间（\(from) → \(to) @ \(amount)）之后，
        粒子层仍然什么都不画 —— 这条转场的粒子在用户面前永远不会出现。
        """)

        let direct = try #require(
            Self.pixels(Self.burst(progress: from + (to - from) * amount)), "渲染失败"
        )
        expectBitmapsEqual(midFlight, direct, """
        插值出来的那一帧与 `ParticleBurstLayer(progress: \(from + (to - from) * amount))`
        不同 —— `animatableData` 没有绑在 `progress` 上，插值改不动绘制。
        """)
    }

    @Test("调用点：ParticleTransitionChrome 整个类型逐字钉死（任何相位门控都判红）")
    func particleLayerSurvivesTheWholeTransition() throws {
        let code = MicroInteractionReduceMotionGuard.stripComments(try Self.source("ParticleTransition.swift"))
        #expect(code.components(separatedBy: "struct ParticleTransitionChrome").count - 1 == 1,
                "`ParticleTransitionChrome` 不是恰好声明一次 —— 下面取到的可能不是被测的那个")
        guard let chrome = ConfettiTests.bracedRegion(after: "struct ParticleTransitionChrome", in: code) else {
            Issue.record("找不到 `ParticleTransitionChrome` 的类型体 —— 下面的断言无从谈起")
            return
        }

        let expected = #"""
        {
            let phase: TransitionPhase
            let count: Int
            let colors: [Color]

            @Environment(\.accessibilityReduceMotion) private var reduceMotion

            func body(content: Content) -> some View {
                let isReduced = self.reduceMotion
                let phase = self.phase

                guard !isReduced else {
                    return AnyView(content.opacity(ParticleBurst.contentOpacity(phase: phase)))
                }

                let progress = ParticleBurst.progress(phase: phase)
                let drawsParticles = self.count > 0
                let count = self.count
                let colors = self.colors

                return AnyView(content
                    .scaleEffect(ParticleBurst.contentScale(phase: phase))
                    .opacity(ParticleBurst.contentOpacity(phase: phase))
                    .overlay {
                        if drawsParticles {
                            ParticleBurstLayer(progress: progress, count: count, colors: colors)
                        }
                    })
            }
        }
        """#

        #expect(Self.squeezed(chrome) == Self.squeezed(expected), """
        `ParticleTransitionChrome` 与期望形态逐字不符。

        实测：\(Self.squeezed(chrome))

        期望：\(Self.squeezed(expected))

        ⚠️ 先看**门控里有没有掺进相位**（`&& phase != .identity`、嵌一层 `if progress > 0`、
        三元、`switch`，或把相位项折进 `drawsParticles` / `count` / `colors` 任一绑定，
        再或把 `count` 改成读 `phase` 的计算属性）——那会让恒等那一端把整层摘掉或让它
        拿到 0 颗粒子：进场的收尾、出场的起手都被截断，且 `if` 翻转本身还会给子树套上
        默认 `.opacity` 转场、把粒子峰值再乘一遍。
        若这次是**有意**改这个类型，连同上面的期望串一起改，并在评审里说明为什么它仍然
        满足「粒子层整段动画都在树上、且拿到的是本次相位算出的 progress / count / colors」。
        """)
    }

    static func squeezed(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    @Test("三个真实相位下 chrome 与「粒子数为 0」版逐字节相同（两端本就不画）")
    func chromeAtRealPhasesDrawsNothing() throws {
        for (name, phase) in [("willAppear", TransitionPhase.willAppear),
                              ("identity", .identity),
                              ("didDisappear", .didDisappear)] {
            let withParticles = try #require(Self.chromePixels(phase: phase), "渲染失败：\(name)")
            let without = try #require(Self.chromePixels(phase: phase, count: 0), "渲染失败：\(name)/count=0")
            #expect(withParticles.contains(where: { $0 != 0 }) == true, "位图全 0 —— 相等断言恒真")
            expectBitmapsEqual(withParticles, without, """
            相位 \(name) 下 chrome 与「粒子数为 0」版不同 —— 该相位的 progress 是
            \(ParticleBurst.progress(phase: phase))，两端的粒子 alpha 都应恒为 0。
            恒等相位画出粒子 = 转场结束后永久残留；端点画出粒子 = 一次 pop。
            """)
        }
        expectBitmapsDiffer(
            Self.pixels(Self.burst(progress: 0.4)),
            Self.pixels(Color.clear.frame(width: 160, height: 160).background(Color.surfaceRaised)),
            "中间进度也画不出粒子 —— 上面三条相等断言是恒真的")
    }

    @Test("空色板 ⇒ 粒子色跟随调用方 .tint；给了色板则不跟随")
    func particlesFollowCallerTint() {
        let red = Self.pixels(Self.burst(progress: 0.4).tint(.red))
        let blue = Self.pixels(Self.burst(progress: 0.4).tint(.blue))
        #expect(red != nil && blue != nil, "渲染失败")
        expectBitmapsDiffer(red, blue, "空色板下换 .tint 位图不变 —— 取色没有走 .tint")

        let palette: [Color] = [.surfaceRaised, .contentPrimary]
        expectBitmapsEqual(
            Self.pixels(Self.burst(progress: 0.4, colors: palette).tint(.red)),
            Self.pixels(Self.burst(progress: 0.4, colors: palette).tint(.blue)),
            "给了色板还跟着 .tint 变 —— 调用方参数没有生效")
    }

    @Test("Reduce Motion 分支保留淡入淡出，且不建粒子层")
    func reduceMotionKeepsTheFade() throws {
        let code = MicroInteractionReduceMotionGuard.stripComments(try Self.source("ParticleTransition.swift"))
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

    @Test("Transition 静态成员存在，两种写法都可用")
    func staticTransitionMembersExist() {
        let plain = Text("x").transition(.particle)
        let configured = Text("x").transition(.particle(count: 8, colors: [.surfaceRaised]))
        #expect(MicroInteractionAPITests.stablePixels(plain) != nil)
        #expect(MicroInteractionAPITests.stablePixels(configured) != nil)
        #expect(ParticleTransition().count > 0, "默认粒子数为 0 —— 这个转场什么都不放")
    }
}
