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
//
// **断言强度的边界（有意为之）**：这里断言的是「两个 `Color.Resolved` 逐位不同」，
// 不是「肉眼可辨」。Badge 那个 bug 正是逐位相同（双方都是 `#FFFFFF`），所以这个判据
// 对该类回归是足够的；但它抓不到「差一点点、肉眼仍不可辨」的情形。
//
// 之所以不上感知色差阈值：那需要选一个色彩空间感知均匀的度量（裸 sRGB 通道差不是），
// 并且**当前代码库里没有任何近似撞色的真实案例可用来标定阈值**——现有 token 两两之间
// 都差着几十个色阶。在没有具体驱动案例的情况下引入阈值，只会带来误报风险而无实际收益。
// 若将来真出现近似撞色，再按那个案例标定。

#if os(iOS)
@Suite("叠加元素与父背景不同色")
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

    @Test("Badge neutral 背景与任意父容器、任意外观下都不同色")
    func badgeNeutralIsNotSameColorAsAnyParent() {
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

    @Test("status subtle 填充在深色纯黑画布上仍可辨，且四档两两不同")
    func statusSubtleFillsAreDistinguishableInDark() {
        // Task #125 视觉终审发现的缺陷：四个 status subtle 色的**深色 α 全是 0.067**。
        // 6.7% 的色叠在纯黑画布（深色下 `surfaceCanvas` = `systemGroupedBackground`
        // = 纯黑）上几乎不可见，四个语义档位在深色模式下无法区分——而 `Badge` 的
        // **文字颜色不随 variant 变化**，于是「用颜色编码语义」这件事在深色下完全失效。
        //
        // 这是个纯视觉缺陷：编译绿、测试绿、grep 干净，只有把 app 跑起来看深色截图
        // 才发现得了。对照组是 Badge 的 neutral 档用的 `secondaryFill`（深色 α=0.32），
        // 早已验证在三种父容器两种外观下均可辨——修复后取 0.28，同一量级。
        var dark = EnvironmentValues()
        dark.colorScheme = .dark
        let canvas = Color.surfaceCanvas.resolve(in: dark)

        let fills: [(String, Color)] = [
            ("statusAccentSubtle", .statusAccentSubtle),
            ("statusSuccessSubtle", .statusSuccessSubtle),
            ("statusAttentionSubtle", .statusAttentionSubtle),
            ("statusDangerSubtle", .statusDangerSubtle),
            // `statusDoneSubtle` 当前无生产消费者（见 `StatusColors.swift` 的说明），
            // 但它与上面四个是同一批被修的 colorset（α 0.067 → 0.280）。一并纳入守卫，
            // 免得将来它被接进 Badge 之类的组件时，alpha 已经悄悄漂回去而无人发现。
            ("statusDoneSubtle", .statusDoneSubtle),
        ]

        for (name, fill) in fills {
            let f = fill.resolve(in: dark)
            #expect(
                f.opacity > 0.15,
                "\(name) 深色 α 只有 \(f.opacity)——叠在纯黑画布上会几乎不可见"
            )
            #expect(f != canvas, "\(name) 与深色画布同色")
        }

        // 四档必须两两可分，否则「用颜色编码语义」失去意义。
        for i in fills.indices {
            for j in fills.indices where j > i {
                #expect(
                    fills[i].1.resolve(in: dark) != fills[j].1.resolve(in: dark),
                    "\(fills[i].0) 与 \(fills[j].0) 在深色下同色——语义档位不可区分"
                )
            }
        }
    }

    @Test("surfaceCard 与 surfaceCanvas 两种外观下都不同色（Issue #140）")
    func surfaceCardDiffersFromCanvasInBothAppearances() {
        // 断言 surfaceCard 本身（非 surfaceRaised != surfaceCanvas，那个不改代码就恒真）。
        // 两种外观都验：浅色下 #F2F2F7 vs #FFFFFF、深色下由塌缩的纯黑变为可辨——
        // 都是本次修复的产物，浅色侧的回归同样要防。
        for scheme in [ColorScheme.light, .dark] {
            var e = EnvironmentValues(); e.colorScheme = scheme
            #expect(
                Color.surfaceCard.resolve(in: e) != Color.surfaceCanvas.resolve(in: e),
                "\(scheme)：surfaceCard 与 surfaceCanvas 同色——卡片在画布上不可辨"
            )
        }
    }

    @Test("填充色族整体可叠加——半透明且与各父背景不同色")
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
