import SwiftUI
import Testing
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif
@testable import CoreDesign

// `ToastPresentation`（`#65`，公约 §2 形态 D2）的**渲染护栏**。
//
// ⚠️ **harness 层级逐断言钉死，不要统一**（`65-plan` 复审 I-A）：
//   · `mountedSize(...)`（**挂载层级**，经 `ToastHostModifier` 走产线 `body`）
//     —— 给 `A5` / `A6` / `A9` 用：它们断的是「挂载方式」，只有在那一层才有意义。
//   · `overlayInk(...)` / `overlayPixels(...)`（**`ToastOverlay` 层级**）
//     —— 给 `A10` / `A10b` / `A11` 用。
//
// ⚠️ **`A10b` 的变异在挂载层级会逃逸**，这是层级必须分开的硬理由：capsule 经
// `safeAreaInset(edge:)` 挂载后，`.top` 与 `.bottom` 的 toast **位置本就不同**；
// 把贴边 padding 改成不随 `edge` 换侧后位图**仍然不等** ⇒ `A10b` 照样绿、无红证据。
//
// ⚠️ **ink 扫描的 alpha 阈值一律 `> 0`、无容差**。同一视图在 `> 0` 与 `> 30` 下量出
// **288 vs 40** —— 阈值直接翻转结论（spec §7.1b 裁定探针）。玻璃背景的绝大多数像素
// alpha 落在 `1–31` 桶，取任何容差都会把整片背景丢掉、只剩前景文字。
// ⚠️ **本 suite 守不住的那一条，如实写在这里**（T5 变异实测，M7）：
// `ToastOverlay.transition`（`.centeredHUD` 用不依赖方向的缩放/淡入淡出，另两个用
// `.move(edge:)`）**没有机器判据** —— 把它改回方向性过渡，9 条断言**全绿**。
// 原因是结构性的：`transition` 只在 item 增删的**动画过程**中生效，而 `ImageRenderer`
// 拍的是静态帧，动画根本不在它的射程内。
// ⇒ 这条属 `65-spec` §7.2 的**人工抽查**项，别因为本 suite 全绿就以为它被守住了。
//
// ⚠️ **曾经守不住、现已补上的**（PR #210 终审 I-1，留作教训）：`View.toastHost(...)` 的
// **转发行**一度是全测试体系唯一没覆盖的产线行 —— 9 条渲染断言全部经
// `ToastHostModifier(host:...)` 直接构造进入，判据只读签名不看函数体，App 又不进 CI。
// 「转发时把 `presentation` 写死」这枚变异**全绿逃逸**。现由 `A12` 经公开 API 堵住。
// ⇒ **加注入缝时要顺带问「缝之上还剩哪一行没人走过」** —— 缝会把未覆盖边界**上移**，
// 而不是消灭它。
// （同族限度：光栅渲染同样证不了 `allowsHitTesting` / `accessibilityHidden` / 手势是否真的被关掉。）
@MainActor
struct ToastPresentationRenderTests {
    /// 测量用的容器宽度。⚠️ 它是**测试自选的提案宽度**，与设备无关
    /// （`ImageRenderer` 不看屏幕），不会腐。
    private static let containerWidth: CGFloat = 320

    // MARK: harness

    private func cgImage(_ view: some View) -> CGImage? {
        let renderer = ImageRenderer(content: view.dynamicTypeSize(.large))
        // ⚠️ 钉死 scale：否则位图像素宽是 320×scale，`== containerWidth` 要换算。
        renderer.scale = 1
        #if canImport(UIKit)
        return renderer.uiImage?.cgImage
        #else
        var rect = CGRect(origin: .zero, size: renderer.nsImage?.size ?? .zero)
        return renderer.nsImage?.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        #endif
    }

    /// 取 RGBA 字节。相等/不等类断言都用它。
    private func pixels(_ view: some View) -> Data? {
        guard let cg = self.cgImage(view) else { return nil }
        let w = cg.width, h = cg.height
        guard w > 0, h > 0 else { return nil }
        var buf = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(
            data: &buf, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        return Data(buf)
    }

    /// **ink 宽度**：位图里 alpha `> 0` 的像素的左右边界跨度。
    ///
    /// ⚠️ 量的是 **toast 自身的绘制宽度**，不是整图宽 —— 整图宽恒等于容器宽，
    /// 三个形态量出来会**全一样**（spec §7.1b 实测二）。
    private func overlayInk(
        _ presentation: ToastPresentation,
        edge: VerticalEdge = .top,
        containerWidth: CGFloat? = nil,
        message: String = "Hi"
    ) -> Int? {
        let host = ToastHost()
        host.show(message, level: .info)
        let view = ToastOverlay(host: host, edge: edge, presentation: presentation)
            .frame(width: containerWidth ?? Self.containerWidth)
        guard let cg = self.cgImage(view) else { return nil }
        let w = cg.width, h = cg.height
        guard w > 0, h > 0 else { return nil }
        var buf = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(
            data: &buf, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        var minX = w, maxX = -1
        for y in 0..<h {
            for x in 0..<w where buf[(y * w + x) * 4 + 3] > 0 {   // ⚠️ alpha > 0，无容差
                minX = min(minX, x)
                maxX = max(maxX, x)
            }
        }
        return maxX >= minX ? maxX - minX + 1 : nil
    }

    /// 取**指定高度比例那一行**的 ink 跨度。用于判**容器形状**：
    /// 矩形的顶行与中行跨度相同；胶囊/圆角矩形的顶行会被圆角切窄。
    private func rowInk(_ presentation: ToastPresentation, atFraction f: Double) -> Int? {
        let host = ToastHost()
        host.show("Hi", level: .info)
        let view = ToastOverlay(host: host, edge: .top, presentation: presentation)
            .frame(width: Self.containerWidth)
        guard let cg = self.cgImage(view) else { return nil }
        let w = cg.width, h = cg.height
        guard w > 0, h > 0 else { return nil }
        var buf = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(
            data: &buf, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        // 只在有 ink 的行范围内取，避开 padding 造成的空白行。
        var inkRows: [Int] = []
        for y in 0..<h where (0..<w).contains(where: { buf[(y * w + $0) * 4 + 3] > 0 }) {
            inkRows.append(y)
        }
        guard let first = inkRows.first, let last = inkRows.last, last > first else { return nil }
        let y = first + Int(Double(last - first) * f)
        var minX = w, maxX = -1
        for x in 0..<w where buf[(y * w + x) * 4 + 3] > 0 {
            minX = min(minX, x)
            maxX = max(maxX, x)
        }
        return maxX >= minX ? maxX - minX + 1 : nil
    }

    private func overlayPixels(_ presentation: ToastPresentation, edge: VerticalEdge) -> Data? {
        let host = ToastHost()
        host.show("Hi", level: .info)
        return self.pixels(
            ToastOverlay(host: host, edge: edge, presentation: presentation)
                .frame(width: Self.containerWidth)
        )
    }

    /// **挂载层级**：经产线 `ToastHostModifier` 渲染，量整个容器的尺寸。
    ///
    /// ⚠️ `host:` 注入缝是 `A9` 的全部意义所在 —— 没有它，测试只能自己手写一层挂载，
    /// 于是「把挂载方式改回去」这个变异发生在测试**根本没走的**产线代码上、永不判红。
    private func mountedSize(_ presentation: ToastPresentation, edge: VerticalEdge = .top, empty: Bool = false) -> CGSize? {
        let host = ToastHost()
        if !empty { host.show("Hi", level: .info) }
        let view = Color.blue.frame(width: Self.containerWidth, height: 120)
            .modifier(ToastHostModifier(host: host, edge: edge, presentation: presentation))
        let renderer = ImageRenderer(content: view.dynamicTypeSize(.large))
        renderer.scale = 1
        #if canImport(UIKit)
        return renderer.uiImage?.size
        #else
        return renderer.nsImage?.size
        #endif
    }

    // MARK: A9 —— 注入缝真的接上了（其余挂载层级断言的前置）

    @Test("A9 承重：注入的 host 真的驱动了产线挂载路径")
    func injectedHostDrivesProductionMount() {
        let empty = self.mountedSize(.floatingCapsule, empty: true)
        let filled = self.mountedSize(.floatingCapsule)
        #expect(empty != nil, "渲染失败 —— 本平台无法量测，不得当作通过")
        #expect(filled != nil, "渲染失败")
        // 空队列 → 零尺寸占位；有 toast → safeAreaInset 把容器撑高。
        #expect((filled?.height ?? 0) > (empty?.height ?? 0),
                "注入的 host 没驱动渲染：空 \(empty?.height ?? -1) / 有 toast \(filled?.height ?? -1)")
    }

    // MARK: A6 —— .centeredHUD 不走 safeAreaInset

    @Test("A6 承重：.centeredHUD 不因挂载增高，另两个形态会")
    func centeredHUDDoesNotInsetContainer() {
        let baseline = self.mountedSize(.centeredHUD, empty: true)
        let hud = self.mountedSize(.centeredHUD)
        let capsule = self.mountedSize(.floatingCapsule)
        let banner = self.mountedSize(.fullWidthBanner)
        for (name, size) in [("hud", hud), ("capsule", capsule), ("banner", banner), ("baseline", baseline)] {
            #expect(size != nil, "\(name) 渲染失败 —— 不得当作通过")
        }
        // .overlay 不参与布局 ⇒ 容器高度不变；safeAreaInset 会把容器撑高。
        #expect(hud?.height == baseline?.height,
                ".centeredHUD 仍在撑高容器（说明还走着 safeAreaInset）：\(hud?.height ?? -1) vs 基线 \(baseline?.height ?? -1)")
        #expect((capsule?.height ?? 0) > (baseline?.height ?? 0), "capsule 没撑高容器 —— 挂载路径可能已坏")
        #expect((banner?.height ?? 0) > (baseline?.height ?? 0), "banner 没撑高容器 —— 挂载路径可能已坏")
    }

    // MARK: A5 —— banner 与 capsule 渲染不同

    @Test("A5 承重：fullWidthBanner 与 floatingCapsule 渲染不同")
    func bannerDiffersFromCapsule() {
        let capsule = self.overlayPixels(.floatingCapsule, edge: .top)
        let banner = self.overlayPixels(.fullWidthBanner, edge: .top)
        #expect(capsule != nil, "渲染失败 —— 不得当作通过")
        #expect(banner != nil, "渲染失败")
        #expect(capsule != banner, "banner 与 capsule 位图相同 —— 形态分支没生效")
    }

    @Test("A5b 承重：容器形状真的不同（banner 是矩形，capsule 有圆角）")
    func containerShapeDiffers() {
        // ⚠️ **A5 单独抓不到「容器形状被换掉」**（T5 变异实测）：把 banner 的
        // `Rectangle()` 改回 `Capsule()` 后 A5 **仍然绿** —— 因为两者还差着水平 padding，
        // 位图照样不等。A5 测的是「有任何差异」，不是「形状不同」。
        //
        // ⇒ 本条用**形状的定义性判据**：矩形没有圆角 ⇒ 顶行与中行的 ink 跨度**相等**；
        // 胶囊 / 圆角矩形的顶行会被圆角切窄。实测 banner 320/320、capsule 266/288。
        //
        // ⚠️ **粒度边界，如实写明**（PR #210 终审 S-3）：采样行离顶约 3px，所以本条实际守的是
        // 「**方顶 vs 圆顶**」，不是「登记的那三个具体形状」——
        //   · banner 换成 `RoundedRectangle(cornerRadius: ≤3)`，圆角收窄发生在采样行**之上**，
        //     `顶行 == 中行` 照过；
        //   · capsule 侧同样区分不了 `Capsule` 与 `RoundedRectangle(large)`。
        // 够挡住已实测的那枚变异（`Rectangle` ↔ `Capsule`），但别把它读成「形状被逐一钉死」。
        //
        // ⚠️ **还有一条更隐蔽的**（Copilot CLI 复审提出，推理未跑）：在容器上叠一条**贴顶
        // 通栏装饰**（`.overlay(alignment: .top) { Rectangle().frame(height: 2) }` ——
        // 「顶部强调条」这类正当视觉需求）会让顶行 ink 跨度**恒等于满宽**，于是
        // `bannerTop == bannerMid` 恒真、底层形状被换掉这件事在本条下彻底隐形。
        // ⇒ 真加这类装饰时，本条要跟着改（改采样点或改判据），别让它静默退化。
        let bannerTop = self.rowInk(.fullWidthBanner, atFraction: 0.06)
        let bannerMid = self.rowInk(.fullWidthBanner, atFraction: 0.5)
        let capsuleTop = self.rowInk(.floatingCapsule, atFraction: 0.06)
        let capsuleMid = self.rowInk(.floatingCapsule, atFraction: 0.5)
        for (name, v) in [("bannerTop", bannerTop), ("bannerMid", bannerMid),
                          ("capsuleTop", capsuleTop), ("capsuleMid", capsuleMid)] {
            #expect(v != nil, "\(name) 量测失败 —— 不得当作通过")
        }
        #expect(bannerTop == bannerMid,
                "banner 顶行 \(bannerTop ?? -1) ≠ 中行 \(bannerMid ?? -1) —— 它不是矩形（容器形状分支可能被换掉了）")
        #expect((capsuleTop ?? 0) < (capsuleMid ?? 0),
                "capsule 顶行 \(capsuleTop ?? -1) 未窄于中行 \(capsuleMid ?? -1) —— 圆角没了。⚠️ 本条同时是上一条的非退化前置：证明「顶行<中行」在本平台确实可区分")
    }

    // MARK: A10 / A10b —— edge 在 .centeredHUD 下真的无效

    @Test("A10 承重：.centeredHUD 下 edge 不影响渲染（逐字节相等）")
    func edgeHasNoEffectUnderCenteredHUD() {
        let top = self.overlayPixels(.centeredHUD, edge: .top)
        let bottom = self.overlayPixels(.centeredHUD, edge: .bottom)
        #expect(top != nil, "渲染失败 —— 不得当作通过（否则本条会因两张空图而恒真）")
        #expect(top == bottom,
                ".centeredHUD 下 edge 仍在影响渲染 —— 「edge 静默无效」的定案在像素层面为假")
    }

    @Test("A10b 承重：A10 的非退化前置 —— 换 edge 在本平台确实能产生位图差异")
    func edgeDoesAffectCapsule() {
        // ⚠️ 与 A10 **互为非退化前置，不得单独删除或单腿门控**：
        //   · 没有本条，A10 可能只是在比两张空图（相等类断言的退化路径）；
        //   · 没有 A10，本条的不等可能只是渲染非确定性。
        let top = self.overlayPixels(.floatingCapsule, edge: .top)
        let bottom = self.overlayPixels(.floatingCapsule, edge: .bottom)
        #expect(top != nil, "渲染失败 —— 不得当作通过")
        #expect(top != bottom,
                ".floatingCapsule 下换 edge 位图相同 —— 说明 edge 根本没进渲染，A10 的相等就没有意义了")
    }

    // MARK: A11 —— 「占多宽」这个差异真的存在

    @Test("A11 承重：三形态的实际占宽符合各自定义")
    func inkWidthsMatchPresentation() {
        let capsule = self.overlayInk(.floatingCapsule)
        let banner = self.overlayInk(.fullWidthBanner)
        let hud = self.overlayInk(.centeredHUD)
        // 非退化前置先行。
        for (name, ink) in [("capsule", capsule), ("banner", banner), ("hud", hud)] {
            #expect(ink != nil, "\(name) ink 量测失败 —— 不得当作通过")
            #expect((ink ?? 0) > 0, "\(name) ink 为 0 —— 渲染为空图，下面的比较会假通过")
        }
        // banner 去掉水平 padding 后撑满容器 —— 等于容器宽是**可判定的事实**而非魔数。
        #expect(banner == Int(Self.containerWidth),
                "banner 没有撑满容器：\(banner ?? -1) ≠ \(Int(Self.containerWidth))（背景/描边可能没画到矩形边界）")
        #expect((banner ?? 0) > (capsule ?? 0),
                "banner 未比 capsule 宽：banner \(banner ?? -1) / capsule \(capsule ?? -1)")
        #expect((hud ?? Int.max) < (capsule ?? 0),
                "hud 未比 capsule 窄：hud \(hud ?? -1) / capsule \(capsule ?? -1)")
    }

    @Test("A11b 承重：.centeredHUD 真的 content-hugging（ink 不随容器宽变化）")
    func centeredHUDHugsContent() {
        // ⚠️ **`hud < capsule` 挡不住「给 hud 加回撑满」那个变异**（T5 变异实测，
        // 而 spec 四审预言它能挡住）：变异后 hud 撑满到 **288**，而 capsule 是 **290**
        // （`strokeBorder` 的 hairline 越过了 padding 边界）⇒ `288 < 290` **恰好还成立**，
        // 断言差 **2 个像素**溜过去。
        //
        // ⇒ 本条改用 **content-hugging 的定义本身**：hugging 的东西**不随容器宽变化**。
        // 实测 hud 在 320/500 容器下都是 59；撑满的 capsule 是 290/470、banner 是 320/500。
        // 这是可判定的事实，不是魔数，也不会因为差几个像素而失效。
        let hud320 = self.overlayInk(.centeredHUD, containerWidth: 320)
        let hud500 = self.overlayInk(.centeredHUD, containerWidth: 500)
        let capsule320 = self.overlayInk(.floatingCapsule, containerWidth: 320)
        let capsule500 = self.overlayInk(.floatingCapsule, containerWidth: 500)
        for (name, v) in [("hud320", hud320), ("hud500", hud500),
                          ("capsule320", capsule320), ("capsule500", capsule500)] {
            #expect(v != nil, "\(name) 量测失败 —— 不得当作通过")
            #expect((v ?? 0) > 0, "\(name) 为 0 —— 空图，下面的比较会假通过")
        }
        #expect(hud320 == hud500,
                ".centeredHUD 的 ink 随容器宽变了（\(hud320 ?? -1) → \(hud500 ?? -1)）—— 它在撑满，不是 content-hugging")

        // ⚠️ **「不随容器宽变」只是 hugging 的必要条件，不是充分条件**（PR #210 终审 I-2）：
        // 一个被钉成固定宽度的 HUD 同样满足它。⇒ hugging 的**另一半定义是「随内容变」**，
        // 两半都断言才关得住。
        //
        // ⚠️ **钉死宽度取决于 `.frame` 相对 glass 背景的层序**（实测，两个放置点都跑过）：
        //   · `.frame(width:)` 在 **glass 之内**（`.padding()` 与 `ToastContainerDecoration`
        //     之间）⇒ glass 的 `background` 填满那个 frame ⇒ **单一变异即钉死**，
        //     ink 恒 200（短 200 / 长 200），本条判红 ✅
        //   · `.frame(width:)` 在 **glass 之外** ⇒ glass 仍 hug 内容 ⇒ ink 随内容变
        //     （59 → 162），本条绿。
        //
        // ⚠️ **本段上一版写错了两句，留作反例**（PR #210 复审 Important-2 抓到）：
        //   ① 「`.frame(width:)` 只给出宽度提案」—— **错**，它无条件固定 frame 自身宽度，
        //      hug 的只是其子视图；
        //   ② 「真正能钉死宽度的是组合变异『加回 Spacer + 定宽』」—— **错**，glass 之内的
        //      单一 frame 就够。
        // 错因：**只试了一个放置点（glass 之外）就下了全称结论**。⚠️ 这是本 PR 里第二次
        // 犯同型 —— 第一次是 ink 扫描的 alpha 阈值只试了 `> 30`，同样翻转了结论。
        // ⇒ **改动位置有层序含义时（modifier 链），必须把两侧都试过再下判断。**
        let shortInk = self.overlayInk(.centeredHUD, message: "Hi")
        let longInk = self.overlayInk(.centeredHUD, message: "A considerably longer toast message")
        #expect(shortInk != nil && longInk != nil, "量测失败 —— 不得当作通过")
        #expect((longInk ?? 0) > (shortInk ?? 0),
                ".centeredHUD 的 ink 不随内容长度变（短 \(shortInk ?? -1) / 长 \(longInk ?? -1)）—— 它被钉成了固定宽度，不是 content-hugging")
        #expect((longInk ?? Int.max) <= Int(Self.containerWidth),
                ".centeredHUD 的长文本 ink \(longInk ?? -1) 超出容器宽 \(Int(Self.containerWidth)) —— hugging 不该突破容器")

        // ⚠️ **本条的采样是离散的，如实写明**（Copilot CLI 复审提出，推理未跑）：只取
        // 「`"Hi"` / 长句」× 「320 / 500 容器」四个点。一个**按内容长度分段的查表式实现**
        // （`frame(width: message.count > 10 ? 200 : 60)`）能精确卡过全部四条断言 ——
        // 它与容器宽无关（过 `hud320 == hud500`）、两档随长度阈值变（过 `short < long`）、
        // 且 ≤ 320（过越界检查），但**根本不是 hugging**：中等长度或阈值边界附近的消息会
        // 明显失真。⇒ 本条守的是「不定宽 + 大致随内容」，不是「逐点等于内容理想宽」。
        // ⚠️ 非退化前置：证明「换容器宽」在本平台确实能改变 ink，否则上一条可能恒真。
        #expect((capsule320 ?? 0) < (capsule500 ?? 0),
                "capsule 的 ink 没随容器宽变 —— 换容器宽这个操作没生效，上一条的相等就没有意义了")
    }

    // MARK: A7 —— 遍历 allCases

    @Test("A7 兜底：全部形态都能渲染出非空内容")
    func allPresentationsRender() {
        // ⚠️ 遍历 `allCases` 而非硬编码三个 —— 将来加第四个 case 时本条**自动覆盖它**。
        for presentation in ToastPresentation.allCases {
            let ink = self.overlayInk(presentation)
            #expect(ink != nil, "\(presentation) 渲染失败")
            #expect((ink ?? 0) > 0, "\(presentation) 渲染为空图")
        }
    }
}
