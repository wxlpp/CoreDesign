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
    static func pixels(_ view: some View) -> Data? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        #if canImport(UIKit)
        return renderer.uiImage?.pngData()
        #else
        return renderer.nsImage?.tiffRepresentation
        #endif
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

    @Test("八个入口全部存在且可链式组合")
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
        // ⚠️ 编译期契约：八个入口存在且可链式组合。
        #expect(Self.pixels(composed) != nil, "叠加 8 个后渲染失败")
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
    @Test("静息态：八个叠加后位图与裸视图逐字节相同")
    func restingPixelsUnchanged() {
        let bare = Self.pixels(Text("x"))
        let stacked = Self.pixels(
            Text("x")
                .shake(trigger: 1)
                .jump(trigger: 1)
                .spin(trigger: 1)
                .ping(trigger: 1)
                .spray(trigger: 1, symbol: "heart.fill")
                .rise(trigger: 1, text: "+1")
                .haptic(.success, trigger: 1)
                .shine(trigger: 1)
        )
        // ⚠️ **非空断言先行**（本仓明文纪律）：两边都渲染失败时相等断言恒真。
        #expect(bare != nil && stacked != nil, "渲染失败，下面的相等断言会静默变绿")
        #expect(bare == stacked, "叠加 8 个微交互后静息位图变了 —— 有效果在静息态就在画东西")
    }

    /// ⚠️ **逐个单独测**，不只测叠加——叠加相等时两个效果的相反偏差可能互相抵消。
    /// 上一轮的 `.shine` bug 正是靠逐个二分才定位到的。
    @Test("静息态：八个各自单独用也不改变位图")
    func eachEffectRestsClean() {
        let bare = Self.pixels(Text("x"))
        #expect(bare != nil)
        let cases: [(String, AnyView)] = [
            ("shake", AnyView(Text("x").shake(trigger: 1))),
            ("jump", AnyView(Text("x").jump(trigger: 1))),
            ("spin", AnyView(Text("x").spin(trigger: 1))),
            ("ping", AnyView(Text("x").ping(trigger: 1))),
            ("spray", AnyView(Text("x").spray(trigger: 1, symbol: "heart.fill"))),
            ("rise", AnyView(Text("x").rise(trigger: 1, text: "+1"))),
            ("haptic", AnyView(Text("x").haptic(.success, trigger: 1))),
            ("shine", AnyView(Text("x").shine(trigger: 1))),
        ]
        for (name, view) in cases {
            #expect(Self.pixels(view) == bare, "\(name) 在静息态就改变了位图")
        }
    }


    /// ⚠️ **上一条相等断言的非退化前置**（本仓 `SidebarLeadingSlotRenderTests` 的互锁成法）。
    ///
    /// 相等断言的退化路径是「两张全是空图 / 本平台根本量不出差异 ⇒ 恒真」。
    /// 这一条从反面证明：同一套 harness 在本平台**确能**分辨出差异。
    /// **删掉任一条，另一条会静默退化成恒真。**
    @Test("互锁：同一 harness 能分辨出真实差异")
    func harnessDetectsDifference() {
        let bare = Self.pixels(Text("x"))
        let probe = Self.pixels(Text("x").opacity(0.4))
        #expect(bare != nil && probe != nil)
        #expect(bare != probe, "harness 分辨不出 opacity 差异 —— 上一条相等断言是恒真的")
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
        let stacked = Self.pixels(v)
        #expect(stacked != nil)
        #expect(stacked == Self.pixels(Text("x")))
    }

}
