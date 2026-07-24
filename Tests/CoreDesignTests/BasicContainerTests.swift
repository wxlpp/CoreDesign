import SwiftUI
import Testing
@testable import CoreDesign

// MARK: - 基础容器（Issue #141）
//
// Card / Separator / SectionHeader / SectionFooter 是薄封装，视觉正确性主要靠
// 各文件的 `#Preview` 与 #144 的实机视觉终审（ADR-4 硬门）兜底。这里覆盖两类
// 机械可断言的东西：
//   1. `Separator.Inset` 的映射逻辑（纯逻辑，两端平台都跑）。
//   2. `Card` 的**可见性契约**——它的背景必须与画布拉开，否则卡片隐形。这正是
//      Issue #140 修的塌缩；在 Card 组件层再钉一根守卫，证明 `.surface(.content)`
//      被正确接进 Card（token 层的守卫在 `SurfaceContrastTests`）。渲染类断言同样
//      只在 iOS 腿作数（macOS 无 WindowServer 会塌缩系统色）。

@Suite("基础容器 Separator.Inset 逻辑")
struct SeparatorInsetTests {

    @Test("leadingAmount: none→0, leading(x)→x")
    func leadingAmount() {
        #expect(Separator.Inset.none.leadingAmount == 0)
        #expect(Separator.Inset.leading(24).leadingAmount == 24)
        #expect(Separator.Inset.leading(0).leadingAmount == 0)
        // 负值 clamp 到 0——负 inset 会让分隔线向 leading 外扩、溢出边界。
        #expect(Separator.Inset.leading(-8).leadingAmount == 0)
    }

    @Test("Inset Equatable：leading(0) 与 none 是不同的 case")
    func insetEquatable() {
        #expect(Separator.Inset.none == .none)
        #expect(Separator.Inset.leading(4) == .leading(4))
        #expect(Separator.Inset.leading(4) != .leading(8))
        // `.none` 与 `.leading(0)` **渲染完全相同**（都归结为 `.padding(.leading, 0)`），
        // 但作为枚举值是两个不同 case——合成的 Equatable 应区分它们。这条守卫防的是
        // 「误把 .none 与 .leading(0) 合并成同一 case」这类 API 变更，不是行为差异。
        #expect(Separator.Inset.none != .leading(0))
    }
}

#if os(iOS)
import UIKit

@Suite("基础容器 Card 可见性（iOS 腿）")
@MainActor
struct CardVisibilityTests {

    /// 渲染 `view` 并采样中心像素。系统色在 iOS Simulator 上有真实渲染上下文，
    /// ImageRenderer 能正确解析（不像 macOS 无 WindowServer 时塌缩）。
    private func centerPixel(_ view: some View, scheme: ColorScheme) -> [UInt8]? {
        let renderer = ImageRenderer(content:
            view.environment(\.colorScheme, scheme)
        )
        renderer.scale = 1
        guard let cg = renderer.uiImage?.cgImage else { return nil }
        var pixel = [UInt8](repeating: 0, count: 4)
        let space = CGColorSpaceCreateDeviceRGB()
        // `CGContext(data:)` 只在 init 期借用指针；draw 必须在指针仍有效时发生。
        // 用 withUnsafeMutableBytes 把 context 的创建与 draw 全放进指针有效的闭包，
        // 避免 `&pixel` 桥接出的临时指针在 draw 时已悬垂（Swift UB）。
        let ok = pixel.withUnsafeMutableBytes { buffer -> Bool in
            guard let ctx = CGContext(
                data: buffer.baseAddress,
                width: 1, height: 1,
                bitsPerComponent: 8, bytesPerRow: 4,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            // 把整张图平移，使其中心恰好落在 1×1 上下文上，采到中心像素。
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

    @Test("Card 渲染出的背景与画布两种外观下都不同色（浮起可见）", arguments: [true, false])
    func cardBackgroundDiffersFromCanvas(bordered: Bool) {
        // bordered 与 borderless 两种形态都测——borderless 失去描边这道兜底，可见性
        // 完全依赖背景对比（恰是 #140 塌缩里更脆弱的形态），更要守。
        for scheme in [ColorScheme.light, .dark] {
            // Card 内容用 clear 占位，中心采到的是 Card 自身背景（.surface(.content)）。
            let card = Card(bordered: bordered) { Color.clear.frame(width: 60, height: 60) }
            let canvas = Color.surfaceCanvas.frame(width: 100, height: 100)

            let cardPixel = self.centerPixel(card, scheme: scheme)
            let canvasPixel = self.centerPixel(canvas, scheme: scheme)

            #expect(cardPixel != nil, "Card 渲染失败（bordered=\(bordered), \(scheme)）")
            #expect(canvasPixel != nil, "画布渲染失败（\(scheme)）")
            #expect(
                cardPixel != canvasPixel,
                "Card(bordered: \(bordered)) 背景在 \(scheme) 下与画布同色 → 卡片隐形（Issue #140 塌缩回归）"
            )
        }
    }
}
#endif
