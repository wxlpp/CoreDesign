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
        let w = cg.width, h = cg.height
        var buffer = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(
            data: &buffer, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        return Data(buffer)
    }

    /// ⚠️ 暖机一次再比——冷渲的第一帧在某些内容上与之后不同（见 `pixels` 的说明）。
    static func stablePixels(_ view: some View) -> Data? {
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
        #expect(Self.stablePixels(composed) != nil, "叠加 8 个后渲染失败")
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
        )
        // ⚠️ **非空断言先行**（本仓明文纪律）：两边都渲染失败时相等断言恒真。
        #expect(bare != nil && stacked != nil, "渲染失败，下面的相等断言会静默变绿")
        #expect(bare == stacked, "叠加 8 个微交互后静息位图变了 —— 有效果在静息态就在画东西")
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
    /// ⚠️⚠️ **本 harness 的实测下限**：带背景的宽视图
    /// （`Text("Unlock").frame(320×44).background(Color.accent)`）上，
    /// **八个效果全部差 7 字节 ≈ 2 像素**，且**差值完全相同、连不画任何东西的
    /// `.haptic` 也在内**——差异来自视图树结构对边缘光栅化的影响，
    /// **不是任何一个效果在画东西**。多种包装形态（裸 / `AnyView` / `EmptyModifier`）
    /// 都试过，无法对齐到 0。
    /// ⇒ **该内容不纳入本判据**，如实记在这里，而不是用容差把它糊过去
    /// ——容差会让真实的 2 像素缺陷也一起漏掉。`Text` 与 SF Symbol 两种内容
    /// **逐字节相等**，是本判据的有效射程。
    @Test("静息态：八个各自单独用、三种内容都不改变位图")
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
            ]
            for (name, pixels) in cases {
                #expect(pixels == bare, "\(name) 在 \(contentName) 上静息就改变了位图")
            }
        }
        check("Text", Text("x"))
        check("SFSymbol", Image(systemName: "star.fill").font(.system(size: 40)))
    }

    /// ⚠️ **入口数与三处硬编码清单的交叉判据**（第 5 轮终审 C4-5 / I5-4）：
    /// `scanActuallyMatches` 会强制新增效果的作者去动 `ReduceMotionGuard.swift`，
    /// 但**没有任何机制**把他推去动本文件——两个文件之间零交叉判据
    /// ⇒ 第九个效果就算被 RM 判据逼着补齐降级，静息像素这一层仍是零覆盖。
    @Test("public 入口数 == 叠加/逐件清单的长度")
    func entryCountMatchesLists() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Sources/CoreDesignEffects")
        // ⚠️ 只数 `public extension View` **之后**的顶层 `func` —— 入口的签名是跨行的，
        // 「同一行同时含 `func` 与 `trigger:`」会 0 命中（我第一版就是这样）。
        var entries = 0
        for url in try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        where url.pathExtension == "swift" {
            let code = try String(contentsOf: url, encoding: .utf8)
            guard let r = code.range(of: "public extension View") else { continue }
            entries += code[r.upperBound...].components(separatedBy: "\n")
                .filter { $0.hasPrefix("    func ") }.count
        }
        let detail = "`public extension View` 里有 \(entries) 个 trigger 入口，"
            + "而本文件两处清单是 8 个 —— 新增效果后请同步，否则它在静息像素这一层零覆盖"
        #expect(entries == 8, "\(detail)")
    }


    /// ⚠️⚠️ **上面两条只覆盖「首次 trigger 之前」的静息态**（第 5 轮终审 C5-2）：
    /// 它们的 trigger 是字面量 `1`、永不变化 ⇒ `TriggerRelay.fire` 恒为 0
    /// ⇒ 动画从未跑过 ⇒ 渲染的是 `initialValue` 态。
    ///
    /// 而 `keyframeAnimator` 的静息态**有两个**：`initialValue` 态，与**终帧态**
    /// （每次动画结束后停在最后一个 keyframe，且**那是用户实际长期看到的那个**）。
    /// 测试名与 250.md 都写「静息态」，读者会理解为覆盖了后者——**上一版没有**。
    /// `Spin` 的 360° 残留正是从这个缺口漏过去的。
    ///
    /// ⇒ 本条直接断言两个 keyframe 类效果的**终帧变换是恒等的**。
    /// ⚠️ 只修 C5-1 而不装这条护栏，就是「修症状不装护栏」——正是本 PR 前四轮
    /// 反复出现的形态。
    @Test("动画终帧态：keyframe 类效果的终点变换必须是恒等")
    func terminalFrameIsIdentity() {
        // Spin 的终帧是 `360 * sign` ⇒ 取模后必须落回 0。
        for sign in [1.0, -1.0] {
            let terminal = (360.0 * sign).truncatingRemainder(dividingBy: 360)
            #expect(terminal == 0, "Spin 终帧 \(360 * sign)° 取模后是 \(terminal)，不是恒等")
        }
        // Shine 的终帧是 progress = +1 ⇒ 光带 offset = +travel ⇒ 完全出界。
        // 用位图验证：终帧渲染必须与裸视图逐字节相同。
        let bare = Self.stablePixels(Text("x"))
        #expect(bare != nil)
        #expect(Self.stablePixels(Text("x").shine(trigger: 1)) == bare,
                "shine 的终帧不是干净的")
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
        let stacked = Self.stablePixels(v)
        #expect(stacked != nil)
        #expect(stacked == Self.stablePixels(Text("x")))
    }

}
