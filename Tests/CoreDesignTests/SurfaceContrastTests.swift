import SwiftUI
import Testing
@testable import CoreDesign

// MARK: - 叠加元素与父背景的可辨性守卫（Issue #122）
//
// #120 把语义色改指系统色后出现过一个静默缺陷：Badge 的 neutral 背景取
// `surfaceCanvasSubtle`（= `secondarySystemGroupedBackground`），而它在**浅色模式**下
// 与 `surfaceBase`（= `systemBackground`）同为 `#FFFFFF`——无描边的 neutral badge
// 放在普通页面背景上完全不可见。编译器、grep、既有测试全都发现不了。
//
// 根因是选错了 token **种类**：叠在别人之上的一小块色该用**填充色**（`FillColors`，
// 半透明、专为叠加设计），而不是**背景色**（`SurfaceColors`，专为充当底层而设计）。
//
// > ⚠️ 这类断言**必须跑在 iOS Simulator 上**。macOS 无 WindowServer 会话时，
// > 三个 surface token 会塌缩成同一 fallback 值，断言会给出误导性的"全部同色"结论。
// > 故整个 suite 限定 `#if os(iOS)`——它只在 CI 的 xcodebuild iOS 腿执行。

#if os(iOS)
@Suite("叠加元素与父背景可辨")
struct SurfaceContrastTests {

    private nonisolated static func env(_ scheme: ColorScheme) -> EnvironmentValues {
        var e = EnvironmentValues()
        e.colorScheme = scheme
        return e
    }

    /// 一个元素若要能叠在任意父容器上，它必须与所有常见父背景都可辨。
    private static let parents: [(String, Color)] = [
        ("surfaceBase", .surfaceBase),
        ("surfaceCanvas", .surfaceCanvas),
        ("surfaceRaised", .surfaceRaised),
    ]

    @Test("Badge neutral 背景在任意父容器、任意外观下都可辨")
    func badgeNeutralIsVisibleAnywhere() {
        for scheme in [ColorScheme.light, .dark] {
            let e = Self.env(scheme)
            let badge = Color.secondaryFill.resolve(in: e)
            for (name, parent) in Self.parents {
                #expect(
                    badge != parent.resolve(in: e),
                    "\(scheme)：Badge neutral 背景与 \(name) 同色——无描边时将完全不可见"
                )
            }
        }
    }

    @Test("填充色族整体可叠加——半透明且与各父背景可辨")
    func fillTokensLayerOverAnySurface() {
        for scheme in [ColorScheme.light, .dark] {
            let e = Self.env(scheme)
            for (name, fill) in [("secondaryFill", Color.secondaryFill),
                                 ("tertiaryFill", Color.tertiaryFill),
                                 ("quaternaryFill", Color.quaternaryFill)] {
                let f = fill.resolve(in: e)
                #expect(f.opacity < 1.0, "\(scheme)：\(name) 不再半透明——填充色的可叠加性依赖这一点")
                for (pname, parent) in Self.parents {
                    #expect(f != parent.resolve(in: e), "\(scheme)：\(name) 与 \(pname) 同色")
                }
            }
        }
    }
}
#endif
