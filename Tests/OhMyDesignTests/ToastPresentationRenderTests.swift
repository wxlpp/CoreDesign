import SwiftUI
import Testing
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif
@testable import OhMyDesign

@MainActor
struct ToastPresentationRenderTests {
    private static let containerWidth: CGFloat = 320

    // MARK: harness

    private func cgImage(_ view: some View) -> CGImage? {
        let renderer = ImageRenderer(content: view.dynamicTypeSize(.large))
        renderer.scale = 1
        #if canImport(UIKit)
        return renderer.uiImage?.cgImage
        #else
        var rect = CGRect(origin: .zero, size: renderer.nsImage?.size ?? .zero)
        return renderer.nsImage?.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        #endif
    }

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
            for x in 0..<w where buf[(y * w + x) * 4 + 3] > 0 {
                minX = min(minX, x)
                maxX = max(maxX, x)
            }
        }
        return maxX >= minX ? maxX - minX + 1 : nil
    }

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
        expectBitmapsDiffer(capsule, banner, "banner 与 capsule 位图相同 —— 形态分支没生效")
    }

    @Test("A5b 承重：容器形状真的不同（banner 是矩形，capsule 有圆角）")
    func containerShapeDiffers() {
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
        expectBitmapsEqual(top, bottom,
                ".centeredHUD 下 edge 仍在影响渲染 —— 「edge 静默无效」的定案在像素层面为假")
    }

    @Test("A10b 承重：A10 的非退化前置 —— 换 edge 在本平台确实能产生位图差异")
    func edgeDoesAffectCapsule() {
        let top = self.overlayPixels(.floatingCapsule, edge: .top)
        let bottom = self.overlayPixels(.floatingCapsule, edge: .bottom)
        #expect(top != nil, "渲染失败 —— 不得当作通过")
        expectBitmapsDiffer(top, bottom,
                ".floatingCapsule 下换 edge 位图相同 —— 说明 edge 根本没进渲染，A10 的相等就没有意义了")
    }

    // MARK: A11 —— 「占多宽」这个差异真的存在

    @Test("A11 承重：三形态的实际占宽符合各自定义")
    func inkWidthsMatchPresentation() {
        let capsule = self.overlayInk(.floatingCapsule)
        let banner = self.overlayInk(.fullWidthBanner)
        let hud = self.overlayInk(.centeredHUD)
        for (name, ink) in [("capsule", capsule), ("banner", banner), ("hud", hud)] {
            #expect(ink != nil, "\(name) ink 量测失败 —— 不得当作通过")
            #expect((ink ?? 0) > 0, "\(name) ink 为 0 —— 渲染为空图，下面的比较会假通过")
        }
        #expect(banner == Int(Self.containerWidth),
                "banner 没有撑满容器：\(banner ?? -1) ≠ \(Int(Self.containerWidth))（背景/描边可能没画到矩形边界）")
        #expect((banner ?? 0) > (capsule ?? 0),
                "banner 未比 capsule 宽：banner \(banner ?? -1) / capsule \(capsule ?? -1)")
        #expect((hud ?? Int.max) < (capsule ?? 0),
                "hud 未比 capsule 窄：hud \(hud ?? -1) / capsule \(capsule ?? -1)")
    }

    @Test("A11b 承重：.centeredHUD 真的 content-hugging（ink 不随容器宽变化）")
    func centeredHUDHugsContent() {
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

        let shortInk = self.overlayInk(.centeredHUD, message: "Hi")
        let longInk = self.overlayInk(.centeredHUD, message: "A considerably longer toast message")
        #expect(shortInk != nil && longInk != nil, "量测失败 —— 不得当作通过")
        #expect((longInk ?? 0) > (shortInk ?? 0),
                ".centeredHUD 的 ink 不随内容长度变（短 \(shortInk ?? -1) / 长 \(longInk ?? -1)）—— 它被钉成了固定宽度，不是 content-hugging")
        #expect((longInk ?? Int.max) <= Int(Self.containerWidth),
                ".centeredHUD 的长文本 ink \(longInk ?? -1) 超出容器宽 \(Int(Self.containerWidth)) —— hugging 不该突破容器")

        #expect((capsule320 ?? 0) < (capsule500 ?? 0),
                "capsule 的 ink 没随容器宽变 —— 换容器宽这个操作没生效，上一条的相等就没有意义了")
    }

    // MARK: A7 —— 遍历 allCases

    @Test("A7 兜底：全部形态都能渲染出非空内容")
    func allPresentationsRender() {
        for presentation in ToastPresentation.allCases {
            let ink = self.overlayInk(presentation)
            #expect(ink != nil, "\(presentation) 渲染失败")
            #expect((ink ?? 0) > 0, "\(presentation) 渲染为空图")
        }
    }
}
