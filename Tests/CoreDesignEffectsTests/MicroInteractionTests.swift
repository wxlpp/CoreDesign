import CoreDesign
import SwiftUI
import Testing

/// ⚠️ **本类型刻意 *不* 标 `nonisolated`、*不* 声明 `Sendable`。**
///
/// 这是**第 5 项修复的钉子**（终审 I-6）：初版这里写的是
/// `private nonisolated enum TriggerPhase: Equatable, Sendable`，理由是"不加会报
/// `#IsolatedConformances`"——那在**修复前**成立，修复后不再成立。于是那条测试用的
/// 三个 trigger（显式 `Sendable` 的枚举、`String`、`Double`）**全都是 `Sendable`**
/// ⇒ 把代码回退成「泛型直接进动画 modifier」这枚变异，**测试照样绿**。
///
/// 现在它是一个 **MainActor 隔离 conformance** 的类型。
///
/// ⚠️⚠️ **上一版这里写「回退即编译失败」——第 3 轮终审 C-2 实测证伪**：把
/// `TriggerRelay` 删掉、泛型直接进动画 modifier，只得到一条
/// `warning: capture of non-Sendable type 'T.Type' in an isolated closure`，
/// **Build complete、测试全绿**；而 CI 没开 `-warnings-as-errors` ⇒ 那不是机器判据。
/// 本类型真正钉住的是**另一枚**变异：给 `T` 加回 `Sendable` 约束 ⇒
/// `#IsolatedConformances` **编译红**。
/// 「泛型直接进动画 modifier」那枚由 `MicroInteractionReduceMotionGuard`
/// 的 `coreModifiersAreNotGeneric` 接管。
private enum IsolatedTrigger: Equatable { case idle, done }

@testable import CoreDesignEffects

@Suite("MicroInteractionStrength 语义档位")
struct MicroInteractionStrengthTests {

    // ⚠️ 断言的是**档位之间的关系**，不是具体数值——数值是可调的实现细节，
    // 而"更强 ⇒ 位移更大"是这个枚举的语义承诺。

    @Test("三条轴都随档位单调递增")
    func monotonic() {
        let all = MicroInteractionStrength.allCases
        #expect(zip(all, all.dropFirst()).allSatisfy { $0.displacement < $1.displacement })
        #expect(zip(all, all.dropFirst()).allSatisfy { $0.scaleDelta < $1.scaleDelta })
        #expect(zip(all, all.dropFirst()).allSatisfy { $0.particleCount < $1.particleCount })
    }

    @Test("粒子数至少 1 —— 0 会让 spray 静默什么都不画")
    func particleCountIsPositive() {
        #expect(MicroInteractionStrength.allCases.allSatisfy { $0.particleCount >= 1 })
    }

    @Test("SpinDirection 的 sign 互为相反数")
    func spinDirection() {
        #expect(SpinDirection.clockwise.sign == -SpinDirection.counterClockwise.sign)
        #expect(SpinDirection.clockwise.sign > 0)
    }
}

@Suite("微交互的 API 契约")
@MainActor
struct MicroInteractionAPITests {

    /// 静息态渲染**位图**。
    ///
    /// ⚠️⚠️ **上一版量的是 `size`，对本 modifier 家族检出力实测为零**（第 3 轮终审 C-1）：
    /// `ImageRenderer` 的 `size` 是**布局尺寸**，而 `offset` / `scaleEffect` /
    /// `rotationEffect` / `overlay` / `background` / `mask` **全都不改变布局尺寸**——
    /// 而这八个 modifier 做的正好只有这些。评审实测：`.offset(x: 10)`、`.scaleEffect(3)`、
    /// `.rotationEffect(45°)`、`.overlay { Circle 200×200 }` 全部量到与裸视图相同的
    /// `(7.0, 16.0)`。⇒ `#expect(bare == stacked)` 结构上不可能判红，
    /// 与它替换掉的 `#expect(composed is any View)`（编译期恒真）是同一种病换了层级。
    /// ⇒ 改量**位图**，并按本仓 `SidebarLeadingSlotRenderTests` 的成法配一条**不等**断言互锁。
    /// ⚠️⚠️ **必须量解码后的像素，不能量编码容器字节**（第 5 轮终审 I5-3）。
    ///
    /// 上一版返回 `tiffRepresentation` / `pngData()`——那是**编码容器**。
    /// 评审实测：同一进程内同一 `star.fill` 连渲 12 次，**前 2 次冷渲的字节与之后不同**
    /// （长度相同、**像素逐点相同**，差的是容器内容）⇒ 照搬 `eachEffectRestsClean`
    /// 的形态只把内容换成 SF Symbol，就会得到 **8 个里 7 个假红**，
    /// 而 RGBA 逐点比对是 24 组全部 0 px 差异。
    ///
    /// ⚠️ **这个假红形态恰好就是第 4 轮那次事故的入口**：一次「shine 与裸视图字节不同」
    /// 的红，被解释成「已知例外」并写成了**保护缺陷**的回归测试。
    /// 当前绿是因为 `Text("x")` 恰好稳定，不是因为判据稳。
    static func pixels(_ view: some View) -> Data? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        #if canImport(UIKit)
        guard let cg = renderer.uiImage?.cgImage else { return nil }
        #else
        var rect = CGRect(origin: .zero, size: renderer.nsImage?.size ?? .zero)
        guard let cg = renderer.nsImage?.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        else { return nil }
        #endif
        // 重绘进一个自有的 RGBA8 缓冲 ⇒ 与编码格式、色彩空间标注全部解耦。
        //
        // ⚠️⚠️ **缓冲必须整段封在 `withUnsafeMutableBytes` 里**（#262 第 2 轮 review）：
        // 上一版写的是 `CGContext(data: &buffer, ...)`。`&array` 传给
        // `UnsafeMutableRawPointer?` 走的是 inout-to-pointer 隐式转换，Swift 只保证
        // 该指针在**那一次调用期间**有效；而 `CGContext` 会把它**存下来**、在之后的
        // `ctx.draw(...)` 里继续写 ⇒ 跨调用使用一个已过期的指针（UB）。
        // 它当前"看起来能跑"只是因为 `Array` 的存储恰好没被搬动，不是语言保证。
        // ⇒ 把「建 context → draw」整段放进闭包，让指针在其被使用的全程都有效。
        let w = cg.width, h = cg.height
        guard w > 0, h > 0 else { return nil }
        var buffer = [UInt8](repeating: 0, count: w * h * 4)
        let drawn = buffer.withUnsafeMutableBytes { raw -> Bool in
            guard let base = raw.baseAddress, let ctx = CGContext(
                data: base, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard drawn else { return nil }
        return Data(buffer)
    }

    /// ⚠️⚠️ **进程级暖机**（#262 第 4 轮 review S-2 / S-3 的副产物，本轮实测）。
    ///
    /// `ImageRenderer` 在**进程内最早的若干次渲染**上给出的字形光栅化与之后不同。
    /// 实测：把 `Text("Unlock").frame(320×44).background(Color.accent)` 连渲 8 次，
    /// **第 0 / 1 / 2 次彼此逐字节相同，第 3 次起整体差 7 个字节并从此稳定**，
    /// 差异像素全落在 "Unlock" 的字形上。
    ///
    /// ⚠️ 两条推论，都直接关系到本文件所有相等断言的可信度：
    /// 1. 「连渲到两次相同就算收敛」**行不通**——前三次正好彼此相同，会锁在错的那个值上；
    ///    必须**固定次数**地把渲染栈跑热。
    /// 2. 只暖机一次（上一版）时，**谁先被渲染谁就是那个异类**：某条判据的基线若恰好落在
    ///    暖机窗口里，它会与随后所有被测项差 7 字节。而 Swift Testing 不保证测试顺序
    ///    ⇒ 绿不绿取决于当次调度。**这正是本文件反复堵的病型**
    ///    （`pixels` 的注释原话：「当前绿是因为 `Text("x")` 恰好稳定，不是因为判据稳」）。
    ///
    /// ⚠️ 它同时是上一版那条「第三种内容差 7 字节 ⇒ 不纳入判据」结论的**真正成因**：
    /// 那 7 字节不是"视图树结构影响边缘光栅化"，是基线取在了暖机窗口里
    /// ——见 `eachEffectRestsClean` 的说明。
    ///
    /// ⇒ 首次取像素前把渲染栈跑热。实测暖机之后**新出现的**宽内容（换一段文字、
    /// 换一个尺寸）首帧即收敛 ⇒ 这是**进程级**暖机，不是逐视图的。
    /// 次数取 8（实测拐点在第 3 次）留足余量；一次暖机不到 1 ms。
    private static let processWarmUp: Bool = {
        let probe = Text("Unlock").frame(width: 320, height: 44).background(Color.accent)
        for _ in 0..<8 { _ = Self.pixels(probe) }
        return true
    }()

    /// ⚠️ 进程级暖机 + 视图级暖机各一道，见 `processWarmUp`。
    ///
    /// ## ⚠️⚠️ 本 harness 的第三条限度：**拿到的位图不能直接进 `#expect(==)`**（Issue #293）
    ///
    /// 本函数返回的是一块**大 `Collection`**（200×200 的画布就是 160 000 字节）。
    /// 把两块这样的 `Data` 直接交给 `#expect(a == b)`，swift-testing 会为渲染失败信息
    /// 去求 `CollectionDifference`（Myers 差分）⇒ **断言判红时不判红，而是挂住**。
    ///
    /// 本仓端到端实测（`MaskRevealRenderTests.identityIsBytewiseIdentityEvenWithOverflow`
    /// + 一枚「恒等相位仍在裁剪」的库变异，两幅 160 000 字节的位图）：
    ///
    /// | 断言形态 | 结果 |
    /// |---|---|
    /// | `#expect(identity == bare, …)` | **200 秒 SIGALRM**，汇总行没打印，日志 860 KB、单行 430 225 字符，6 个 kind 只报出 2 个 |
    /// | `expectBitmapsEqual(identity, bare, …)` | **0.569 秒**判红，6 个 kind 全报，日志 6.4 KB |
    ///
    /// ⚠️ **失效的恰好是最该判红的那一类变异**：整层被绕过 = 整幅图都变 = 差分规模爆炸。
    /// 而失效形态是「进程卡住、读不出是哪条判据在咬」——比静默绿更难诊断，
    /// 因为它看起来像机器慢或死锁。既有断言至今没被咬到，只是因为迄今判红的场景里
    /// 两幅图差异都很小（改了一个数值、挪了几个像素）。
    ///
    /// ⇒ **本函数的返回值一律走 `expectBitmapsEqual` / `expectBitmapsDiffer`**
    /// （`BitmapExpectations.swift`），或本仓既有的 `let matches = a == b; #expect(matches, …)`
    /// 成法。`BitmapExpectationGuard`（`Tests/CoreDesignTests/`）机器守着这条纪律，
    /// 它**堵不住**的等价改写逐条列在那个文件的文件头里。
    ///
    /// ⚠️ 补一条本轮实测出来的**非直觉事实**：`Optional<Data>` 本身不是 `Collection`
    /// ⇒ 两侧都是 `Data?` 时**不会挂**（同一对位图 0.039 s）。会挂的是**非可选** `Data`
    /// ——也就是凡是走 `try #require(Self.stablePixels(...))` 拿到位图的断言。
    /// 「可选 ⇒ 非可选」只有一次重构的距离，故纪律对两者一视同仁，别按可选性开例外。
    static func stablePixels(_ view: some View) -> Data? {
        _ = Self.processWarmUp
        _ = Self.pixels(view)
        return Self.pixels(view)
    }

    // ⚠️ **本 suite 现在有真断言了**（#262 终审 I-4 / S-1）。
    //
    // 初版这里写着「在 macOS 单测里不可观测 ⇒ 靠 #Preview 人工验证」，并据此把
    // 两条 AC 记为未满足。**那个判断是错的**：
    // · 「叠加互不干扰」用 `ImageRenderer` 的**静息尺寸相等**就能测——本仓已有
    //   9 个文件在用这套 harness（`ToastPresentationRenderTests` 等）；
    // · 「Reduce Motion 降级」由 `MicroInteractionReduceMotionGuard`（源码扫描）
    //   机器守住，那正是本仓的主流测试形态。
    //
    // ⚠️ **真正不可观测的只是动画的中间帧**——`ImageRenderer` 拍的是静态帧，
    // 本仓 `ToastPresentationRenderTests` 已经把这条限度写死。记账应当写
    // 「动画中间帧不可观测」，而不是把整个 Reduce Motion 归入不可测。
    //
    // ⚠️ **Bool 纪律（J-1）不在本 suite 覆盖范围内**——真正的守卫是
    // `BoolExemptionGuard`，它要等 #246 扩到本 target 才生效。初版曾有一条
    // `#expect(Bool(true))` 的 `noBoolParameters`，会以"J-1 已覆盖"的名义出现在
    // 测试报告里，已删除。

    @Test("九个入口全部存在且可链式组合")
    func allEntryPointsCompose() {
        // 全部叠在同一个视图上 —— 同时也验证它们互不冲突（US-1 的"可叠加"）。
        let composed = Text("x")
            .shake(trigger: 1)
            .jump(trigger: 1)
            .spin(trigger: 1)
            .ping(trigger: 1)
            .spray(trigger: 1, symbol: "heart.fill")
            .rise(trigger: 1, text: "+1")
            .haptic(.success, trigger: 1)
            .shine(trigger: 1)
            .confetti(trigger: 1)
        // ⚠️ 编译期契约：九个入口存在且可链式组合。
        #expect(Self.stablePixels(composed) != nil, "叠加 9 个后渲染失败")
    }
    /// US-1「可叠加、互不干扰」在**静息位图**层面的断言。
    ///
    /// ⚠️⚠️ **上一版把 `.shine` 从这条里剔了出去，理由是「`.mask` 强制离屏合成 ⇒
    /// 抗锯齿差异」——那个成因是假的，而被它掩盖的是一个真视觉 bug**
    ///（第 4 轮终审 C4-1）。三个对照实验当场证伪：高光设 `.clear` ⇒ 与裸视图**逐字节
    /// 相同**；`Color.clear.mask(content)` ⇒ **逐字节相同**；差异像素全在字形内部、
    /// 全部变亮，是一层半透明白盖上去而不是抗锯齿。
    /// 真因见 `Shine.swift`：`keyframeAnimator` 的 `initialValue` 在首次求值时
    /// `proxy.size == .zero` ⇒ 固化成 0 ⇒ **光带永久停在内容上**。
    ///
    /// ⚠️ 而上一版为它写的「已知例外」测试断言 `bare != shined`
    /// ⇒ **修好这个 bug 会让那条测试变红** ⇒ 我留下了一条**保护缺陷**的回归测试。
    /// 前三轮的病型是「判据宣称假事实」，这一轮升级为「假事实**掩盖了真缺陷**」。
    /// ⇒ bug 已修，`.shine` **并回八件套**，那条例外测试已删除。
    @Test("静息态：九个叠加后位图与裸视图逐字节相同")
    func restingPixelsUnchanged() {
        let bare = Self.stablePixels(Text("x"))
        let stacked = Self.stablePixels(
            Text("x")
                .shake(trigger: 1)
                .jump(trigger: 1)
                .spin(trigger: 1)
                .ping(trigger: 1)
                .spray(trigger: 1, symbol: "heart.fill")
                .rise(trigger: 1, text: "+1")
                .haptic(.success, trigger: 1)
                .shine(trigger: 1)
                .confetti(trigger: 1)
        )
        // ⚠️ **非空断言先行**（本仓明文纪律）：两边都渲染失败时相等断言恒真。
        #expect(bare != nil && stacked != nil, "渲染失败，下面的相等断言会静默变绿")
        expectBitmapsEqual(bare, stacked, "叠加 9 个微交互后静息位图变了 —— 有效果在静息态就在画东西")
    }

    /// ⚠️ **逐个单独测**，不只测叠加——叠加相等时两个效果的相反偏差可能互相抵消。
    /// 上一轮的 `.shine` bug 正是靠逐个二分才定位到的。
    /// 八个效果 × **三种内容**逐个测。
    ///
    /// ⚠️ **多种内容不是凑数**（第 5 轮终审）：只用 `Text("x")` 时判据的稳定性来自
    /// 那个内容恰好稳定，而不是来自判据本身。
    ///
    /// ⚠️⚠️ **基线与被测项的视图包装层数必须一致**，否则八个效果会**全部**判红。
    /// 实测：裸视图与 `AnyView(裸视图)` 在带背景的宽视图上相差 **7 字节**
    /// （而 `AnyView` vs `AnyView×2` 是 0）⇒ 差异来自**包装本身**。
    /// 我第一版用 `[(String, AnyView)]` 存内容，基线与用例各差一层 ⇒ 八个全红，
    /// **且差值完全相同（7 B）、连不画任何东西的 `.haptic` 也在内**
    /// ——「全体等量偏差」就是伪影的指纹，不是八个独立缺陷。
    /// ⇒ 改用泛型闭包，基线与用例走**同一条路径**，层数天然一致。
    ///
    /// ⚠️⚠️ **上一版这里写着「第三种内容不纳入本判据」，而测试名仍写「三种内容」**
    ///（#262 第 4 轮 review S-2 / S-3）——名字宣称的覆盖面大于实际跑的两种。
    ///
    /// 那条排除的理由是：带背景的宽视图
    /// （`Text("Unlock").frame(320×44).background(Color.accent)`）上
    /// 「八个效果全部差 7 字节 ≈ 2 像素、差值完全相同、连不画任何东西的 `.haptic`
    /// 也在内」，且多种包装形态都对不齐到 0。
    ///
    /// ⚠️ **那 7 个字节是真的、当场就能复现**（本轮实测），但**成因写错了**，
    /// 而错误的成因把一个可修的 harness 缺陷记成了"物理下限"：
    /// · 它**与被测的是哪个效果无关**——连 `.haptic`（什么都不画）都在内，
    ///   八个效果彼此**逐字节相同**，唯一的异类是**基线**；
    /// · 把该内容连渲 8 次：第 0 / 1 / 2 次彼此相同，**第 3 次起整体差 7 字节并从此稳定**
    ///   ⇒ 异类不是"结构"，是**谁落在了渲染栈的暖机窗口里**。
    ///   `check` 先渲基线、再渲八个效果 ⇒ 只有基线掉在窗口内。
    /// ⇒ 真正的修法是**把渲染栈跑热**，不是排除内容。见 `stablePixels.processWarmUp`。
    ///
    /// ⚠️ 这也解释了为什么它"多种包装形态都对不齐到 0"——换包装换不出暖机窗口。
    ///
    /// ⇒ 装上进程级暖机后重测：该内容在 macOS 与 iOS Simulator **两条腿**上、
    /// 八个效果**全部 0 字节差异**（另试过 `Circle` / 纯色块 / 圆角矩形 / 带内边距的
    /// `Text` / 胶囊背景，同样全 0）。**第三种内容补回来**，测试名与实际覆盖对齐。
    ///
    /// ⚠️ 选它而不选别的：它是三种里唯一带**大面积不透明背景**的，射程明显更大。
    /// **变异实证**：往 `ShineCore` 加一个 `.offset(x: 100)` 的 1×1 脏点
    /// ——`Text("x")` 与 SF Symbol 都只有几像素宽，那个点**落在画面之外、两者全绿**，
    /// 只有本内容判红。第三种内容不是凑数。
    @Test("静息态：九个各自单独用、三种内容都不改变位图")
    func eachEffectRestsClean() {
        func check(_ contentName: String, _ content: some View) {
            // 基线：同一条路径、零效果。
            let bare = Self.stablePixels(content.modifier(EmptyModifier()))
            #expect(bare != nil, "\(contentName) 渲染失败")
            let cases: [(String, Data?)] = [
                ("shake", Self.stablePixels(content.shake(trigger: 1))),
                ("jump", Self.stablePixels(content.jump(trigger: 1))),
                ("spin", Self.stablePixels(content.spin(trigger: 1))),
                ("ping", Self.stablePixels(content.ping(trigger: 1))),
                ("spray", Self.stablePixels(content.spray(trigger: 1, symbol: "heart.fill"))),
                ("rise", Self.stablePixels(content.rise(trigger: 1, text: "+1"))),
                ("haptic", Self.stablePixels(content.haptic(.success, trigger: 1))),
                ("shine", Self.stablePixels(content.shine(trigger: 1))),
                ("confetti", Self.stablePixels(content.confetti(trigger: 1))),
            ]
            for (name, pixels) in cases {
                expectBitmapsEqual(pixels, bare, "\(name) 在 \(contentName) 上静息就改变了位图")
            }
        }
        check("Text", Text("x"))
        check("SFSymbol", Image(systemName: "star.fill").font(.system(size: 40)))
        check("WideBackground", Text("Unlock").frame(width: 320, height: 44).background(Color.accent))
    }

    /// `.rise(text:)` 文档里写的**跨 package 绕行方式**的机器判据（#262 第 3 轮 review）。
    ///
    /// 该参数是 `LocalizedStringKey`，走 `Bundle.main` 查表 ⇒ 另一个 package 的
    /// `.module` 本地化不会命中。成文绕行是「调用方先用自己的 bundle 解析成 `String`，
    /// 再包成 `LocalizedStringKey` 传进来」——它成立**只因为** `Bundle.main` 查不到该
    /// 键时 `Text` 原样回落。
    ///
    /// ⚠️ 「注释写了绕行、代码里却没人走过」正是本 PR 前几轮反复堵的失真病型
    /// ⇒ 这里用**位图比对**把回落语义钉死：`Text(verbatim:)` 与
    /// `Text(LocalizedStringKey(runtimeString))` 必须逐字节相同。回落一旦不成立
    /// （例如未来改用带默认值 / 抛错的解析路径），文档那条绕行就是假的，本条判红。
    @Test("rise 的跨 bundle 绕行：预解析字符串包成 LocalizedStringKey 后原样渲染")
    func riseAcceptsPreResolvedLocalizedString() {
        // 模拟「另一个 package 已用自己的 bundle 解析好的译文」——刻意选一个
        // `Bundle.main` 里必然查不到、且不含 markdown 记号的串。
        let resolved = "已加一分"
        let verbatim = Self.stablePixels(Text(verbatim: resolved))
        let viaKey = Self.stablePixels(Text(LocalizedStringKey(resolved)))
        // ⚠️ **非空断言先行**（本仓明文纪律）：两边都渲染失败时相等断言恒真。
        #expect(verbatim != nil && viaKey != nil, "渲染失败，下面的相等断言会静默变绿")
        expectBitmapsEqual(verbatim, viaKey, "Bundle.main 查不到该键时未原样回落 —— rise 文档写的绕行方式失效")
        // 且这个 key 真能喂给 `.rise`（编译期契约，防止将来把参数换成不接受运行期串的类型）。
        let applied = Self.stablePixels(
            Text("x").rise(trigger: 1, text: LocalizedStringKey(resolved))
        )
        #expect(applied != nil, "预解析字符串包成的 key 无法传给 .rise")
    }

    /// ⚠️ **入口数与三处硬编码清单的交叉判据**（第 5 轮终审 C4-5 / I5-4）：
    /// `scanActuallyMatches` 会强制新增效果的作者去动 `ReduceMotionGuard.swift`，
    /// 但**没有任何机制**把他推去动本文件——两个文件之间零交叉判据
    /// ⇒ 第九个效果就算被 RM 判据逼着补齐降级，静息像素这一层仍是零覆盖。
    @Test("public 入口数 == 叠加/逐件清单的长度")
    func entryCountMatchesLists() throws {
        // ⚠️ **必须递归枚举**（#262 第 2 轮 review）：上一版用 `contentsOfDirectory`
        // 只扫顶层，而 `MicroInteractionReduceMotionGuard.swiftFiles()` 早就为同一个
        // 逃逸位改成了递归。效果文件一旦挪进子目录（本仓 `Sources/CoreDesign/Components/*/`
        // 正是这么组织的），新入口就不再被计入 ⇒ 入口数仍是 8、清单也是 8 ⇒ **静默全绿**，
        // 「入口数 == 清单长度」这条交叉判据自己先漏掉了覆盖漂移。
        // ⇒ 直接复用那个已递归、且目录缺失时 fail-closed 判红的枚举，不另立一套。
        // ⚠️ 只数 `public extension View` **之后**的顶层 `func` —— 入口的签名是跨行的，
        // 「同一行同时含 `func` 与 `trigger:`」会 0 命中（我第一版就是这样）。
        var entries = 0
        for url in try MicroInteractionReduceMotionGuard.swiftFiles() {
            let code = try String(contentsOf: url, encoding: .utf8)
            guard let r = code.range(of: "public extension View") else { continue }
            entries += code[r.upperBound...].components(separatedBy: "\n")
                .filter { $0.hasPrefix("    func ") }.count
        }
        let detail = "`public extension View` 里有 \(entries) 个 trigger 入口，"
            + "而本文件两处清单是 9 个 —— 新增效果后请同步，否则它在静息像素这一层零覆盖"
        // ⚠️ `#252` 把 8 抬到 9（新增 `.confetti(trigger:)`）。抬这个数的**同轮**必须把
        // 新入口加进上面两处清单，否则它在静息像素这一层零覆盖——这正是本判据存在的理由。
        #expect(entries == 9, "\(detail)")
    }


    /// 把 Shine 的光带**钉在指定 `progress` 上**渲染出来。
    ///
    /// ⚠️ 光带几何（`ShineBand.gradient`）与「进度 → 位移」（`ShineBand.offset`）
    /// **全部取自生产代码**；这里只重演 `ShineCore` 的组合方式
    /// （`overlay` + `GeometryReader` + `mask`）——因为 `ShineCore` 是 `private`，
    /// 且它那一层的 `keyframeAnimator` 在 `ImageRenderer` 下永远跑不到终帧。
    /// 组合一旦与生产代码漂移，`terminalFrameIsIdentity` 里 `progress = 0`
    /// 那条**不等**互锁会判红。
    static func shinePinned(_ content: some View, progress: CGFloat) -> some View {
        content.overlay {
            GeometryReader { proxy in
                let travel = proxy.size.width + proxy.size.height
                ShineBand.gradient(travel: travel, highlight: .specularHighlight)
                    .offset(x: ShineBand.offset(progress: progress, travel: travel))
            }
            .mask(content)
        }
    }

    /// ⚠️⚠️ **上面两条只覆盖「首次 trigger 之前」的静息态**（第 5 轮终审 C5-2）：
    /// 它们的 trigger 是字面量 `1`、永不变化 ⇒ `TriggerRelay.fire` 恒为 0
    /// ⇒ 动画从未跑过 ⇒ 渲染的是 `initialValue` 态。
    ///
    /// 而 `keyframeAnimator` 的静息态**有两个**：`initialValue` 态，与**终帧态**
    /// （每次动画结束后停在最后一个 keyframe，且**那是用户实际长期看到的那个**）。
    /// `Spin` 的 360° 残留正是从这个缺口漏过去的。
    ///
    /// ⚠️⚠️ **上一版这条判据自己就掉在同一个缺口里**（#262 第 4 轮 review S-1，
    /// 已逐条复核成立）：
    /// · **Shine 那半截**写的是 `Text("x").shine(trigger: 1)`——**又是常量 trigger**，
    ///   `TriggerRelay.fire` 恒为 0、`onChange` 永不触发 ⇒ 量到的仍是 `initialValue`
    ///   态，与它上面两条静息判据量的是**同一帧**，跟"终帧"没有任何关系；
    /// · **Spin 那半截**写的是 `(360.0 * sign).truncatingRemainder(dividingBy: 360) == 0`
    ///   ——一条**纯算术恒等式**，一行生产代码都没读到：把 `SpinCore` 里的取模删掉
    ///   （就是 C5-1 修掉的那枚缺陷本身），它照样全绿。
    ///
    /// ⇒ 换成**真求值 + 真渲染**。`ImageRenderer` 拍的是静态帧，**没有办法让动画
    /// 在单测里跑到终点**（本仓 `ToastPresentationRenderTests` 已写死这条限度），
    /// 但 keyframe **轨道本身是可求值的数据**：
    /// 1. 用 `KeyframeTimeline` 对**生产代码里的那条轨道**求 `value(time: duration)`
    ///    ⇒ 拿到真实终帧值；
    /// 2. 把它喂给**生产代码里的**取角 / 取偏移函数；
    /// 3. 把结果那一帧渲染出来，与裸视图逐字节比。
    /// 每一步吃的都是 `SpinTurn` / `ShineBand`，没有测试自抄的常量。
    ///
    /// ⚠️ **覆盖射程如实写在这里**：本条只覆盖 `Spin` 与 `Shine`。其余六个用动画器的
    /// 文件（`Shake` / `Jump` / `Ping` / `Spray` / `Rise` 与降级用的 `OpacityPulse`）
    /// 终帧仍是零覆盖——它们的动画状态是多轨道自定义 struct（`Jump` 更是
    /// `phaseAnimator`，没有 `KeyframeTimeline` 这样的求值入口），要同样"补真"
    /// 需要逐个把状态与轨道抽成 internal，另开一轮做。
    /// 这个缺口由下面的 `animatorFilesAreEnumerated` 钉成机器可见的。
    @Test("动画终帧态：Spin / Shine 的终点变换是恒等（真轨道求值 + 位图）")
    func terminalFrameIsIdentity() {
        let bare = Self.stablePixels(Text("x"))
        // ⚠️ **非空断言先行**（本仓明文纪律）：渲染失败时下面的相等断言恒真。
        #expect(bare != nil, "渲染失败，下面的相等断言会静默变绿")

        // MARK: Spin —— 终帧转角取模后必须是 0，且施加它与裸视图逐字节相同

        for direction in SpinDirection.allCases {
            let timeline = KeyframeTimeline(initialValue: SpinTurn.initialTurns) {
                SpinTurn.track(direction: direction)
            }
            // ⚠️ `value(time: duration)` = 轨道真正停住的那一帧。
            let turns = timeline.value(time: timeline.duration)
            let angle = SpinTurn.angle(turns: turns, isReduced: false)
            let detail = "Spin(\(direction)) 终帧转到 \(turns)°，取角后是 \(angle)° —— "
                + "不是恒等，动画结束后会永久残留一个变换"
            #expect(angle == 0, "\(detail)")
            expectBitmapsEqual(Self.stablePixels(Text("x").rotationEffect(.degrees(angle))), bare,
                    "Spin(\(direction)) 终帧角 \(angle)° 施加后位图与裸视图不同")
        }
        // ⚠️ **互锁**：证明同一条渲染路径确实分辨得出"非恒等的角度"，
        // 否则上面那条相等断言是恒真的。
        expectBitmapsDiffer(Self.stablePixels(Text("x").rotationEffect(.degrees(37))), bare,
                "harness 分辨不出 37° 旋转 —— Spin 那条相等断言是恒真的")

        // MARK: Shine —— 终帧光带必须完全扫出遮罩之外

        let timeline = KeyframeTimeline(initialValue: ShineBand.initialProgress) {
            ShineBand.track()
        }
        let terminal = timeline.value(time: timeline.duration)
        expectBitmapsEqual(Self.stablePixels(Self.shinePinned(Text("x"), progress: terminal)), bare,
                "Shine 终帧 progress = \(terminal) —— 光带没有完全扫出界，会永久留在内容上")
        // ⚠️ **互锁**：`progress = 0`（光带正压在内容上）必须判出差异。
        // 那正是第 4 轮那枚真 bug 的形态（`initialValue` 被固化成 0 ⇒ 常驻斜切）。
        // 这一条同时兜住「钉帧路径与 `ShineCore` 的组合漂移了」——漂移后光带画不出来，
        // 本条判红，上一条就不会静默退化成恒真。
        expectBitmapsDiffer(Self.stablePixels(Self.shinePinned(Text("x"), progress: 0)), bare,
                "钉帧路径在 progress = 0 都量不出光带 —— 上一条相等断言是恒真的")
    }

    /// ⚠️ **把终帧覆盖的缺口钉成机器可见的**（#262 第 4 轮 review S-1）。
    ///
    /// `terminalFrameIsIdentity` 只覆盖 `Spin` / `Shine` 两个效果，另外六个用动画器的
    /// 文件终帧无人钉。与 `entryCountMatchesLists` 同一形态：**新增（或挪走）一个用
    /// `keyframeAnimator` / `phaseAnimator` 的文件即判红**，把作者推回上一条去补，
    /// 而不是让第九个效果静悄悄地又落在缺口里。
    @Test("用动画器的文件清单固定 —— 新增一个就必须回头补它的终帧判据")
    func animatorFilesAreEnumerated() throws {
        var animatorFiles: Set<String> = []
        for url in try MicroInteractionReduceMotionGuard.swiftFiles() {
            let code = MicroInteractionReduceMotionGuard.stripComments(
                try String(contentsOf: url, encoding: .utf8)
            )
            guard code.contains("keyframeAnimator(") || code.contains("phaseAnimator(")
            else { continue }
            animatorFiles.insert(url.lastPathComponent)
        }
        // 当前已被 `terminalFrameIsIdentity` 覆盖终帧的只有前两个。
        let known: Set<String> = [
            "Spin.swift", "Shine.swift",
            "Shake.swift", "Jump.swift", "Ping.swift", "Spray.swift", "Rise.swift",
            "MicroInteractionSupport.swift",
        ]
        let detail = "用动画器的文件从 \(known.sorted()) 变成了 \(animatorFiles.sorted()) —— "
            + "请同步本清单，并到 terminalFrameIsIdentity 补上新文件的终帧判据"
        #expect(animatorFiles == known, "\(detail)")
    }

    /// ⚠️ **上一条相等断言的非退化前置**（本仓 `SidebarLeadingSlotRenderTests` 的互锁成法）。
    ///
    /// 相等断言的退化路径是「两张全是空图 / 本平台根本量不出差异 ⇒ 恒真」。
    /// 这一条从反面证明：同一套 harness 在本平台**确能**分辨出差异。
    /// **删掉任一条，另一条会静默退化成恒真。**
    @Test("互锁：同一 harness 能分辨出真实差异")
    func harnessDetectsDifference() {
        let bare = Self.stablePixels(Text("x"))
        let probe = Self.stablePixels(Text("x").opacity(0.4))
        #expect(bare != nil && probe != nil)
        // ⚠️ **「缓冲真的被画进去了」这一条也必须断言**（#262 第 2 轮 review）：
        // `CGContext` 若拿到过期指针（上一版 `data: &buffer` 的隐患），
        // `Data(buffer)` 返回的就是一片**全 0**——两边全 0 ⇒ 相等断言恒真。
        // 全 0 是这类退化的指纹，直接判红。
        #expect(bare?.contains(where: { $0 != 0 }) == true,
                "位图全 0 —— CGContext 没有写进我们比较的这块缓冲，所有相等断言都是恒真的")
        expectBitmapsDiffer(bare, probe, "harness 分辨不出 opacity 差异 —— 上一条相等断言是恒真的")
    }

    @Test("trigger 接受任意 Equatable —— 含 MainActor 隔离 conformance 的类型")
    func triggerIsGeneric() {
        // ⚠️ `IsolatedTrigger` **刻意是 MainActor 隔离 conformance**——见其声明处。
        // 这一行编得过，本身就是「泛型没有渗进动画 modifier」的证明。
        let v = Text("x")
            .shake(trigger: IsolatedTrigger.done)
            .spin(trigger: "string")
            .ping(trigger: 3.14)
        // 同上：换成可观测断言，不留恒真表达式。
        let stacked = Self.stablePixels(v)
        #expect(stacked != nil)
        expectBitmapsEqual(stacked, Self.stablePixels(Text("x")))
    }

}

// MARK: - #262 第 1 轮 review：AC 逐字对齐

/// ⚠️ **本 suite 钉的是「公开 API 形状与 #250 的 AC 逐字一致」**，不是渲染行为。
///
/// 起因：第 1 轮 review 抓到两处「实现自行改名 / 自行换形态、再在任务记账里
/// 登记成有意偏离」——`palette:` vs AC 的 `colors:`、`.shine(trigger:)` vs AC 的
/// `Shine { }`。登记本身不构成豁免（AC 约束的是**公开 API 长什么样**），
/// 而这类偏离**没有任何机器判据**能在下一次改名时判红 ⇒ 补在这里。
@Suite("AC 逐字契约")
@MainActor
struct MicroInteractionACContractTests {

    static func source(_ fileName: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/CoreDesignEffects/\(fileName)")
        return try String(contentsOf: url, encoding: .utf8)
    }

    // MARK: spray 的色板契约

    /// AC：「颜色只有三个合法来源：调用方参数 / `.tint` / 语义 token
    /// （`.spray` 的粒子色**默认取 `.tint`**）」。
    ///
    /// ⚠️ `.tint` 在静息位图上**不可观测**（粒子静息 `opacity` 为 0，且 `.tint` 的解析
    /// 发生在渲染期而非视图构建期）⇒ 这条规则只能在**取色函数**这一层断言，
    /// 不能靠 `ImageRenderer` 比像素。`nil` 即"无显式色 ⇒ 交给 `.tint`"。
    @Test("spray 空色板 ⇒ 无显式色（交给 .tint），非空 ⇒ 按下标轮转")
    func sprayPaletteContract() {
        #expect([Color]().particleColor(at: 0) == nil, "空色板必须回落到 .tint，而不是取某个具体色")
        #expect([Color]().particleColor(at: 7) == nil)

        let two: [Color] = [.red, .blue]
        #expect(two.particleColor(at: 0) == .red)
        #expect(two.particleColor(at: 1) == .blue)
        #expect(two.particleColor(at: 2) == .red, "非空色板必须按下标轮转")
        #expect(two.particleColor(at: 3) == .blue)
    }

    /// ⚠️ **直取那处回归**：初版是 `palette.isEmpty ? [Color.accent] : palette`。
    /// `Color.accent` == `Color.accentColor`，**不跟随逐视图 `.tint(_:)`**
    /// ⇒ 调用方 `.tint(.pink)` 对默认粒子色静默失效。
    @Test("spray 的公开入口用 colors: 标签、默认空数组，且实现里没有 Color.accent 回退")
    func sprayEntrySignatureMatchesAC() throws {
        let code = try Self.source("Spray.swift")
        #expect(code.contains("colors: [Color] = []"),
                "AC 逐字写的是 `.spray(trigger:symbol:colors:)`，且默认应为空 ⇒ 回落 .tint")
        #expect(!code.contains("[Color.accent]"),
                "空色板不得回退到 Color.accent —— 它不跟随 .tint(_:)")
    }

    /// 编译期契约：`colors:` 这个标签真的存在（源码扫描只证明字符串在场）。
    @Test("spray 可用 colors: 标签调用，也可省略")
    func sprayCallableWithColorsLabel() {
        let explicit = Text("x").spray(trigger: 1, symbol: "heart.fill", colors: [.red, .blue])
        let defaulted = Text("x").spray(trigger: 1, symbol: "heart.fill")
        #expect(MicroInteractionAPITests.stablePixels(explicit) != nil)
        #expect(MicroInteractionAPITests.stablePixels(defaulted) != nil)
    }

    // MARK: Shine 的容器形态

    /// AC 逐字列的第 8 个 API 是 `Shine { }`——八个里**唯一大写**的一项。
    @Test("Shine { } 容器形态存在，且静息位图与裸视图逐字节相同")
    func shineContainerExists() {
        let bare = MicroInteractionAPITests.stablePixels(Text("x"))
        let wrapped = MicroInteractionAPITests.stablePixels(Shine { Text("x") })
        #expect(bare != nil && wrapped != nil, "渲染失败，下面的相等断言会静默变绿")
        expectBitmapsEqual(bare, wrapped, "Shine 容器在静息态就改变了位图")
    }

    /// ⚠️⚠️ **这条才是容器形态的真正风险点**：容器若自己实现一遍高光，
    /// `MicroInteractionReduceMotionGuard` 的三条判据仍然全绿
    /// （`Shine.swift` 在早退名单里、`accessibilityReduceMotion` 也在场），
    /// 但 Reduce Motion 降级就会**只覆盖 modifier、不覆盖容器**。
    /// ⇒ 钉死「容器必须委托给 `.shine(trigger:)`」，不得有第二套实现。
    @Test("Shine 容器必须委托给 .shine(trigger:)，不得绕过它自建一套（RM 降级由 modifier 承载）")
    func shineContainerDelegatesToModifier() throws {
        let code = try Self.source("Shine.swift")
        guard let start = code.range(of: "public struct Shine<Content: View>: View {") else {
            Issue.record("找不到 Shine 容器声明")
            return
        }
        // 容器声明到文件里下一个顶层 `public extension View` 之间的那一段。
        let tail = code[start.upperBound...]
        let end = tail.range(of: "\npublic extension View")?.lowerBound ?? tail.endIndex
        let body = String(tail[tail.startIndex..<end])

        #expect(body.contains(".shine(trigger:"),
                "Shine 容器必须复用 `.shine(trigger:)`，RM 降级与 .mask 限度都继承自它")
        let forbidden = ["keyframeAnimator(", "phaseAnimator(", "LinearGradient(", ".mask("]
        let offenders = forbidden.filter { body.contains($0) }
        #expect(offenders.isEmpty,
                "Shine 容器里出现了自建的动画/绘制实现 \(offenders) —— 那会绕过 modifier 的 Reduce Motion 降级")
    }
}
