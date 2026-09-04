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

    @Test("leadingAmount: edgeToEdge→0, leading(x)→x")
    func leadingAmount() {
        #expect(Separator.Inset.edgeToEdge.leadingAmount == 0)
        #expect(Separator.Inset.leading(24).leadingAmount == 24)
        #expect(Separator.Inset.leading(0).leadingAmount == 0)
        // 负值 clamp 到 0——负 inset 会让分隔线向 leading 外扩、溢出边界。
        #expect(Separator.Inset.leading(-8).leadingAmount == 0)
    }

    @Test("Inset Equatable：leading(0) 与 edgeToEdge 是不同的 case")
    func insetEquatable() {
        #expect(Separator.Inset.edgeToEdge == .edgeToEdge)
        #expect(Separator.Inset.leading(4) == .leading(4))
        #expect(Separator.Inset.leading(4) != .leading(8))
        // `.edgeToEdge` 与 `.leading(0)` **渲染完全相同**（都归结为 `.padding(.leading, 0)`），
        // 但作为枚举值是两个不同 case——合成的 Equatable 应区分它们。这条守卫防的是
        // 「误把 .edgeToEdge 与 .leading(0) 合并成同一 case」这类 API 变更，不是行为差异。
        #expect(Separator.Inset.edgeToEdge != .leading(0))
    }
}

// MARK: - CardKind 取值域（Issue #41 裁决 1）
//
// ⚠️ **本 suite 刻意不放进下面的 `#if os(iOS)`**：那一段在 macOS 上既不执行、也**不做
// 类型检查**（inactive `#if` 分支只做语法解析，本机 `swiftc -typecheck` 实测对分支内的
// 未定义类型返回 exit 0）。`Card` 的取值域收窄是纯逻辑约束，两端平台都该守，放在这里
// 才有本地红/绿可言。

@Suite("CardKind 取值域")
struct CardKindTests {

    @Test("CardKind 恰好只有 .content / .grouped 两个 case")
    func domainIsExactlyTwoCases() {
        // ⚠️ **这条断言就是裁决 1「取值域必须收窄，不许全开」的机器化**（41-spec 评审 I5）：
        // `Card` 是 `.surface(.content)` 的薄封装，若把 `SurfaceKind` 全开，
        // `Card(kind: .canvas)`（卡片贴画布 ⇒ 隐形，正是 Issue #140 塌缩的形态）、
        // `Card(kind: .sidebar)` 都会成为合法 API。
        // 下面的穷尽 switch 是编译期闸：新增 case 会让它编译失败，逼人重新裁决；
        // 数组则挡住「删了一个 case」。两个方向各挡一半。
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
        // `.grouped` 与 `.content` 必须是**不同**的表面语义 —— 若有人把映射写成
        // 两个 case 都指向 `.content`，`Card(kind: .grouped)` 会静默带上描边，
        // 上面那条相等断言仍然能过一半，这条负向断言把它堵死。
        #expect(CardKind.content.surfaceKind != CardKind.grouped.surfaceKind)
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

    @Test(
        "Card 渲染出的背景与画布两种外观下都不同色（浮起可见）",
        arguments: [CardKind.content, .grouped]
    )
    func cardBackgroundDiffersFromCanvas(kind: CardKind) {
        // 两个 kind 都测——`.grouped` 失去描边这道兜底，可见性完全依赖背景对比
        //（恰是 #140 塌缩里更脆弱的形态），更要守。
        // ⚠️ #41 把 `Card(bordered: Bool)` 换成了 `Card(kind: CardKind)`：参数变了，
        // 被守的东西一个字没变——`.grouped` 就是原来的 `bordered: false`（同背景、
        // 同圆角、描边取 .clear）。改写而非删除，见 41-spec 总账 M12。
        for scheme in [ColorScheme.light, .dark] {
            // Card 内容用 clear 占位，中心采到的是 Card 自身背景（.surface(.content/.grouped)）。
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
