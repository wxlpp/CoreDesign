import SwiftUI
import Testing
@testable import CoreDesign

// MARK: - SurfaceKind 映射层的 α 契约（Issue #345）

@Suite("SurfaceKind 映射层的 α 契约")
struct SurfaceKindAlphaContractGuard {
    private enum AlphaContract {
        case opaque
        case translucent
    }

    /// ⚠️ **无 `default` 是刻意的**：新增 `SurfaceKind` case 时本函数**编译不过**，
    /// 逼调用者当场为它定 α 契约。这是本判据唯一的 fail-closed 机制。
    ///
    /// ⚠️ **`.floating` 按外观分道，所以本函数吃 `scheme`**：iOS 浅色它走
    /// `systemBackground`（实测 α = 1.0），其余三档走填充族（0 < α < 1）。
    /// 分道是**确定性的**，所以两侧都钉死，**不留「只断下界」的活口**——
    /// 只断下界会把这一档留在 `#342` 的射程里（那边守的是 token，不经本映射层）。
    private nonisolated static func contract(
        for kind: SurfaceKind, scheme: ColorScheme
    ) -> AlphaContract {
        switch kind {
        case .canvas, .content, .grouped, .canvasSubtle, .sidebar, .card: .opaque
        case .control, .overlay, .panel: .translucent
        case .floating:
            #if canImport(UIKit)
                scheme == .light ? .opaque : .translucent
            #else
                .translucent
            #endif
        }
    }

    /// ⚠️ **这份清单本身不是 fail-closed 的**：新增 case 只会让上面那个 `switch` 判红，
    /// 漏加进本表则**静默少测一档**。`SurfaceKind` 有意不加 `CaseIterable`
    /// （那是公开 API 变更），所以这一格只能靠上面那条编译期错误把人引到这里。
    private nonisolated static let allKinds: [(name: String, kind: SurfaceKind)] = [
        ("canvas", .canvas), ("content", .content), ("grouped", .grouped),
        ("canvasSubtle", .canvasSubtle), ("sidebar", .sidebar), ("card", .card),
        ("control", .control), ("floating", .floating),
        ("overlay", .overlay), ("panel", .panel),
    ]

    @Test("#345：每个 SurfaceKind 经映射层取到的色都满足它那一档的 α 契约")
    func everyKindSatisfiesItsAlphaContract() {
        for scheme in [ColorScheme.light, ColorScheme.dark] {
            var e = EnvironmentValues()
            e.colorScheme = scheme
            for (name, kind) in Self.allKinds {
                let a = kind.background.resolve(in: e).opacity
                switch Self.contract(for: kind, scheme: scheme) {
                case .opaque:
                    #expect(a == 1, """
                    \(scheme)：背景档 `.\(name)` 经 `SurfaceKind.background` 取到 α = \(a)，
                    契约要求**不透明**。背景档半透明会让它下面那层透上来。
                    ⚠️ **本判据只看 α，看不出「换成了另一个同样不透明的色」**——
                    那一族由各腿的取值 / 身份判据守（如 `macOSCanvasStandsApart`）。
                    ⚠️ 本条守的是**映射层**，不是 token —— `#342` 补的下界断的是
                    `Color.surfaceInteractive` 一族，而消费者写的是 `.surface(.\(name))`，
                    中间隔着 `SurfaceModifier` 里这层 `switch`。改错那一行 `#342` 抓不到。
                    """)
                case .translucent:
                    #expect(a > 0 && a < 1, """
                    \(scheme)：叠加档 `.\(name)` 经映射层取到 α = \(a)，契约要求 **0 < α < 1**。
                    α = 0 ⇒ 这一层画不出来；α = 1 ⇒ 它不再是叠加档。
                    ⚠️ `.floating` 在 **iOS 浅色**下契约是 `α == 1`（走 `systemBackground`），
                    不走本分支——见 `contract(for:scheme:)`。
                    """)
                }
            }
        }
    }
}
