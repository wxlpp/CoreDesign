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
}

@Suite("CoreGradient tokens")
struct CoreGradientTests {
    @Test("all gradient tokens are constructible")
    func tokensConstructible() {
        _ = CoreGradient.brand
        _ = CoreGradient.cta
        _ = CoreGradient.canvas
        #expect(Bool(true))
    }
}
