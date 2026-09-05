import Foundation
import SwiftUI
import Testing

@testable import CoreDesignShaders

// ⚠️ 本文件覆盖 `#283` 落地的两个**内容层**效果（`View.glassOrb` / `View.halftone`）里
// **不碰 Metal** 的那一半：语义档位的单调性、触控地板、跟手与 Reduce Transparency 的策略函数。
// 需要 GPU 的部分在 `RenderProofTests`（整包 `#if os(iOS)`，只在 iOS Simulator 腿上真跑）。
//
// ⚠️ 本文件因此在原生 `swift test` 下也能编译并通过；但 **CI 的 native SwiftPM 腿整个
// `--skip CoreDesignShadersTests`**，它在 CI 上的覆盖来自 swiftbuild 腿与 iOS Simulator 腿。
// 别把「本地 `swift test` 能跑」读成「CI 的原生腿覆盖了它」。

// MARK: - GlassOrb

@Suite("GlassOrb 的档位、触控地板与降级策略")
struct GlassOrbStopTests {

    /// iOS HIG 的最小触控目标。
    ///
    /// ⚠️⚠️ **本条有意写在 `CoreDesignShadersTests` 内，不得并进
    /// `CoreDesignTests.TouchTargetTests`**（`283.md` 的 AC 逐字点名）：并进去要
    /// `@testable import CoreDesignShaders`，那会把 `CoreDesignShaders` 拖进
    /// `CoreDesignTests` 的依赖图，判红 NFR-5②（`CoreDesignTests` 的
    /// `target_dependencies` 须**恰为** `["CoreDesign"]`）。
    private static let minimumHitTarget: CGFloat = 44

    /// ⚠️ **本条与 `TouchTargetTests` 的判据形态不同，别照那边读**：那边量的是
    /// `ImageRenderer` 渲出来的**布局 frame**；而放大镜没有布局 frame ——
    /// 它是一枚画在内容上的圆，被拖动的是它自己。⇒ 这里量的是**档位定义的直径**。
    /// ⚠️ 该形态的**已知边界**：它证不了"手势真的只在圆内响应"。
    /// 本实现的 `DragGesture` 挂在整个内容上（按哪里镜就去哪里），
    /// 因此"圆内可点"由"圆存在"平凡满足；一旦有人把手势收窄到圆内，
    /// 本条就**不再**覆盖那时才出现的命中区问题，要另立判据。
    @Test("三档放大镜的直径都不低于 44pt 触控地板")
    func touchTargetFloor() {
        for size in GlassOrbSize.allCases {
            #expect(
                size.diameter >= Self.minimumHitTarget,
                "GlassOrbSize.\(size) 的直径 \(size.diameter)pt 低于 \(Self.minimumHitTarget)pt 触控地板"
            )
        }
    }

    @Test("GlassOrbSize：半径严格递增，且直径恒为半径的两倍")
    func sizeStopsAreMonotonic() {
        let radii = GlassOrbSize.allCases.map(\.radius)
        #expect(radii.count == 3, "档位数变了（实际 \(radii.count)）—— 下面的关系断言要跟着复核")
        #expect(zip(radii, radii.dropFirst()).allSatisfy { $0 < $1 }, "半径不再严格递增：\(radii)")
        #expect(GlassOrbSize.allCases.allSatisfy { $0.diameter == $0.radius * 2 })
    }

    @Test("GlassOrbMagnification：倍率严格递增，且每一档都 > 1（否则是缩小不是放大）")
    func magnificationStopsAreMonotonic() {
        let factors = GlassOrbMagnification.allCases.map(\.factor)
        #expect(zip(factors, factors.dropFirst()).allSatisfy { $0 < $1 }, "倍率不再严格递增：\(factors)")
        #expect(factors.allSatisfy { $0 > 1 }, "有档位的倍率 ≤ 1：\(factors)")
    }

    @Test("手势未发生时，放大中心落在视图正中")
    func focusDefaultsToCentre() {
        let centre = GlassOrbModifier.focusPoint(gesture: nil, in: CGSize(width: 200, height: 80))
        #expect(centre == CGPoint(x: 100, y: 40))
    }

    /// ⚠️ **FR-12 的空间那一半**：放大镜跟手是**交互**，不是动效
    /// ⇒ 手势位置**原样**成为放大中心，不被任何 a11y 偏好改写。
    ///
    /// ⚠️ **另一半（冻结时间）在本批上为空，本 task 不作声称**：
    /// `coreDesignGlassOrb` 与 `coreDesignHalftone` 的形参表里都**没有** `time`
    ///（两者都是几何 / 空间效果）⇒ 没有可冻结的东西。
    /// 「Reduce Motion 不改变本效果」这条由 `RenderProofTests` 的
    /// `glassOrbIgnoresReduceMotion` 用**逐字节位图**证明（连同一条对照，
    /// 证明那台 harness 分辨得出环境差异、上面那条相等断言不是恒真的）。
    @Test("手势发生后，放大中心就是手势点本身（不做任何折算）")
    func focusFollowsGesture() {
        let touch = CGPoint(x: 17, y: 233)
        let resolved = GlassOrbModifier.focusPoint(gesture: touch, in: CGSize(width: 200, height: 400))
        #expect(resolved == touch)
    }

    /// ⚠️ 与 SC 原文措辞的偏离（「降级为不透明形态」）已写在
    /// `GlassOrbModifier.softness(reduceTransparency:)` 的文档注释里，此处只钉行为。
    @Test("Reduce Transparency 开启 ⇒ 柔化系数为 0（玻璃珠退化成均匀放大镜）")
    func softnessCollapsesUnderReduceTransparency() {
        #expect(GlassOrbModifier.softness(reduceTransparency: true) == 0)
        #expect(GlassOrbModifier.softness(reduceTransparency: false) == 1)
    }
}

// MARK: - Halftone

@Suite("Halftone 的档位与网屏常量")
struct HalftoneStopTests {

    @Test("HalftoneDot：格宽与点半径同向递增")
    func dotStopsAreMonotonic() {
        let cells = HalftoneDot.allCases.map(\.cell)
        let scales = HalftoneDot.allCases.map(\.dotScale)
        #expect(cells.count == 3, "档位数变了（实际 \(cells.count)）—— 下面的关系断言要跟着复核")
        #expect(zip(cells, cells.dropFirst()).allSatisfy { $0 < $1 }, "格宽不再严格递增：\(cells)")
        #expect(zip(scales, scales.dropFirst()).allSatisfy { $0 < $1 }, "点半径不再严格递增：\(scales)")
    }

    /// ⚠️ 上界不是审美偏好，是**几何**：点半径以格宽为单位，超过 `√2 / 2` 时
    /// 圆会盖过格角，相邻格的点互相吞掉 —— 纯黑区域糊成一片，半调的意义消失。
    @Test("最黑处的点半径留在格子内切圆之内（< √2 / 2）")
    func dotScaleStaysInsideCell() {
        let bound = Float(2.0.squareRoot() / 2)
        for dot in HalftoneDot.allCases {
            #expect(dot.dotScale > 0, "HalftoneDot.\(dot) 的点半径非正：\(dot.dotScale)")
            #expect(
                dot.dotScale < bound,
                "HalftoneDot.\(dot) 的点半径 \(dot.dotScale) 已越过 \(bound)，纯黑区会糊成一片"
            )
        }
    }

    /// 单色网屏的 45° 惯例。⚠️ 钉的是**值**：它是印刷业的通行取值，
    /// 改动它属于设计变更，应当被一条判据拦下来问一句。
    @Test("单色网屏角度是 45°")
    func screenAngleIsFortyFiveDegrees() {
        #expect(HalftoneModifier.screenAngle == Float.pi / 4)
    }
}
