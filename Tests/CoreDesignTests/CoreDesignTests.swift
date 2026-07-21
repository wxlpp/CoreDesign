import Testing
import Foundation
@testable import CoreDesign

// MARK: - Blossom asset guard tests
//
// On macOS, SPM delivers .xcassets as a plain directory inside the bundle
// (not compiled to .car), so NSColor(named:bundle:) always returns nil.
// We test colorset presence via FileManager on the bundle directory instead.

private func xcassetsURL() -> URL? {
    Bundle.module.resourceURL?.appendingPathComponent("Resources.xcassets")
}

private func colorsetExists(_ group: String, _ name: String) -> Bool {
    guard let base = xcassetsURL() else { return false }
    let path = base.appendingPathComponent("\(group)/\(name).colorset").path
    return FileManager.default.fileExists(atPath: path)
}

@Suite("Blossom assets")
struct BlossomAssetTests {
    @Test("all blossom-brand colorsets are present")
    func brandColorsetsPresent() {
        for i in 0...9 {
            #expect(colorsetExists("blossom-brand", "blossom-brand-\(i)"),
                    "missing blossom-brand-\(i)")
        }
    }

    @Test("all blossom-canvas colorsets are present")
    func canvasColorsetsPresent() {
        for name in ["blossom-canvas-default", "blossom-canvas-subtle", "blossom-canvas-inset"] {
            #expect(colorsetExists("blossom-canvas", name), "missing \(name)")
        }
    }

    @Test("Blossom 分流依赖的 violet / cyan colorsets 存在")
    func gradientDepColorsetsPresent() {
        // AC C4b 指定 violet-0…9 全覆盖。实测真实消费点更窄：
        // CoreGradient.canvas 的 Blossom 分支用 violet-2 + cyan-1（CoreGradient.swift:57）；
        // InteractionColors.secondaryAccent 用 violet-5/6/7。全 0…9 覆盖是 AC 指定的过度守卫。
        for i in 0...9 {
            #expect(colorsetExists("violet", "violet-\(i)"), "missing violet-\(i)")
        }
        #expect(colorsetExists("cyan", "cyan-1"), "missing cyan-1")
    }
}

@Suite("CoreGradient tokens")
struct CoreGradientTests {
    // CoreGradient 的 trait 分流**真行为**断言（顺带清理原来那条恒真占位断言）。
    //
    // 默认主题下三个 token 退化为纯色（AnyShapeStyle 内部为 ColorBox<NamedColor>），
    // Blossom 下为真实 LinearGradient（ShapeStyleBox<LinearGradient>）。swift test 无法
    // 渲染 ShapeStyle，String(describing:) 是唯一能内省底层 box 类别的途径（与 C4a 的
    // NamedColor 内省同性质）。断言的是粗类别（纯色 vs 渐变），比精确 asset 名更稳。
    @Test("gradient token 随 trait 在纯色 / 渐变间分流")
    func gradientTokensDivergeByTrait() {
        for style in [CoreGradient.brand, CoreGradient.cta, CoreGradient.canvas] {
            let desc = String(describing: style)
            #if Blossom
            #expect(desc.contains("LinearGradient"), "Blossom 下应为真渐变，实为 \(desc)")
            #else
            #expect(desc.contains("ColorBox"), "默认应退化为纯色，实为 \(desc)")
            #endif
        }
    }
}
