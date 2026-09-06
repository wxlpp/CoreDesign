import SwiftUI
import Testing
@testable import CoreDesign

// MARK: - 基础容器（Issue #141）

@Suite("基础容器 Separator.Inset 逻辑")
struct SeparatorInsetTests {
    @Test("leadingAmount: edgeToEdge→0, leading(x)→x")
    func leadingAmount() {
        #expect(Separator.Inset.edgeToEdge.leadingAmount == 0)
        #expect(Separator.Inset.leading(24).leadingAmount == 24)
        #expect(Separator.Inset.leading(0).leadingAmount == 0)
        #expect(Separator.Inset.leading(-8).leadingAmount == 0)
    }

    @Test("Inset Equatable：leading(0) 与 edgeToEdge 是不同的 case")
    func insetEquatable() {
        #expect(Separator.Inset.edgeToEdge == .edgeToEdge)
        #expect(Separator.Inset.leading(4) == .leading(4))
        #expect(Separator.Inset.leading(4) != .leading(8))
        #expect(Separator.Inset.edgeToEdge != .leading(0))
    }
}

// MARK: - CardKind 取值域（Issue #41 裁决 1）

@Suite("CardKind 取值域")
struct CardKindTests {
    @Test("CardKind 恰好只有 .content / .grouped 两个 case")
    func domainIsExactlyTwoCases() {
        let all: [CardKind] = [.content, .grouped]
        #expect(all.count == 2)
        for kind in all {
            switch kind {
            case .content, .grouped: break
            }
        }
    }

    @Test("CardKind 到 SurfaceKind 的映射逐一正确")
    func mapsToSurfaceKind() {
        #expect(CardKind.content.surfaceKind == .content)
        #expect(CardKind.grouped.surfaceKind == .grouped)
        #expect(CardKind.content.surfaceKind != CardKind.grouped.surfaceKind)
    }
}

#if os(iOS)
import UIKit

@Suite("基础容器 Card 可见性（iOS 腿）")
@MainActor
struct CardVisibilityTests {
    private func centerPixel(_ view: some View, scheme: ColorScheme) -> [UInt8]? {
        let renderer = ImageRenderer(content:
            view.environment(\.colorScheme, scheme)
        )
        renderer.scale = 1
        guard let cg = renderer.uiImage?.cgImage else { return nil }
        var pixel = [UInt8](repeating: 0, count: 4)
        let space = CGColorSpaceCreateDeviceRGB()
        let ok = pixel.withUnsafeMutableBytes { buffer -> Bool in
            guard let ctx = CGContext(
                data: buffer.baseAddress,
                width: 1, height: 1,
                bitsPerComponent: 8, bytesPerRow: 4,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            ctx.draw(
                cg,
                in: CGRect(
                    x: -CGFloat(cg.width) / 2 + 0.5,
                    y: -CGFloat(cg.height) / 2 + 0.5,
                    width: CGFloat(cg.width),
                    height: CGFloat(cg.height)
                )
            )
            return true
        }
        return ok ? pixel : nil
    }

    @Test(
        "Card 渲染出的背景与画布两种外观下都不同色（浮起可见）",
        arguments: [CardKind.content, .grouped]
    )
    func cardBackgroundDiffersFromCanvas(kind: CardKind) {
        for scheme in [ColorScheme.light, .dark] {
            let card = Card(kind: kind) { Color.clear.frame(width: 60, height: 60) }
            let canvas = Color.surfaceCanvas.frame(width: 100, height: 100)

            let cardPixel = self.centerPixel(card, scheme: scheme)
            let canvasPixel = self.centerPixel(canvas, scheme: scheme)

            #expect(cardPixel != nil, "Card 渲染失败（kind=\(kind), \(scheme)）")
            #expect(canvasPixel != nil, "画布渲染失败（\(scheme)）")
            expectBitmapsDiffer(
                cardPixel, canvasPixel,
                "Card(kind: \(kind)) 背景在 \(scheme) 下与画布同色 → 卡片隐形（Issue #140 塌缩回归）"
            )
        }
    }
}
#endif
