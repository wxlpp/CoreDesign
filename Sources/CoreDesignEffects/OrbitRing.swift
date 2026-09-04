//
//  OrbitRing.swift
//  CoreDesignEffects
//
//  同心轨道环的几何契约 / Geometry contract for the concentric orbit rings.
//

import CoreDesign
import SwiftUI

// MARK: - 轨道环几何 / Orbit ring geometry

/// `OrbitingLogos` 的纯几何：同心环上的点位、logo 的 slot 分配、轮播窗口、
/// pop 曲线，以及**替代 SpriteKit 物理体**的解析挤压位移场。
///
/// ## 它替换掉了什么（AD-E 的 `OrbitingLogos` 一件）
///
/// 上游 `SWOrbitingLogos` 是一个 `SKScene`：4 个同心环 × 23 个 `SKShapeNode`，
/// 每个点挂一个 `SKPhysicsBody`；被点名的那个点放大到 4 倍，**靠物理碰撞**把邻居
/// 挤开，随后一个 `SKAction.move(to:)` 序列把它们送回原位。
///
/// 本仓不落 SpriteKit，理由**不是**"macOS 上编译不过"（SpriteKit 在 macOS 上有，
/// `SpriteView` 也有），而是三条与本仓公约正面冲突：
///
/// 1. **两套渲染时钟**：`SKScene` 自带 display link，`EffectsRenderPolicy` 的
///    `minimumInterval` / `drawsAnything`（NFR-7 的后台与低电量闸）对它一概无效
///    ——那道闸是靠"根本不建 `TimelineView`"实现的，管不到一个自转的场景；
/// 2. **Reduce Motion 无处插手**：`SKAction.repeatForever` 一旦 `run` 就自己跑，
///    降级要在场景内部再实现一遍，必然与本仓共用的降级形态漂移（FR-11）；
/// 3. **物理体的位移不可测**：本仓的判据形态是纯函数 + 位图，而
///    `SKPhysicsBody` 的解算结果既不是纯函数、也不进 `ImageRenderer`。
///
/// ⇒ 挤压改成**解析位移场**（`pushed(_:awayFrom:radius:strength:)`）：同一观感、
/// 纯函数、逐条可测，且天然跟着 `Canvas` 的那一帧走。
///
/// ⚠️ **照录差异**：上游的挤压是"点被撞开之后再用 0.6s 缓动送回"，有惯性余韵；
/// 本实现的位移**只是当前帧的函数**，没有惯性。这是刻意的取舍（可测性优先），
/// 不是漏做。
nonisolated enum OrbitRing {

    // MARK: 常量（取值沿用上游的观感）

    /// 同心环数。
    static let ringCount: Int = 4

    /// 每环的点数。
    static let dotsPerRing: Int = 23

    /// 一圈自转的默认周期（秒）。
    static let rotationPeriod: Double = 10

    /// 每个 logo 被点名的时长（秒）。
    static let featureSeconds: Double = 2.4

    /// pop 的峰值缩放。
    static let popPeak: Double = 1.85

    /// 挤压半径占容器短边的比例。
    static let pushRadiusRatio: Double = 0.12

    /// 挤压强度占容器短边的比例。
    static let pushStrengthRatio: Double = 0.035

    /// 角向明暗波的上下界。上游在这里放的是一条写死的绿色渐变（`SKColor(red:…)`），
    /// 本仓按 AD-D 换成**同一个色相上的明暗**：色由调用方的 `.tint` 或色板给，
    /// 环上的层次由不透明度给。
    static let minimumAlpha: Double = 0.35
    static let maximumAlpha: Double = 1.0

    /// Reduce Motion / 静止形态所用的相位（同 `SphereField.restingPhase` 的理由）。
    static let restingPhase: Double = 0.125

    // MARK: 环与点

    /// 由时刻取自转圈数。整数部分无所谓——三角函数吃的是角度。
    static func turns(at date: Date, period: Double = OrbitRing.rotationPeriod) -> Double {
        guard period > 0 else { return 0 }
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period)
        return (t < 0 ? t + period : t) / period
    }

    /// 第 `ring` 环的半径（0 = 最外环）。`size` 是容器短边。
    static func ringRadius(ring: Int, size: Double) -> Double {
        let outer = size * 0.5 * 0.86
        let step = size * 0.5 * 0.075
        return max(0, outer - Double(ring) * step)
    }

    /// 第 `ring` 环上单个点的直径。外环最大、向内递减（上游是 `dotSize` 的锯齿序列，
    /// 本仓改成单调递减——锯齿在那边只是随手写的，读不出设计意图）。
    static func dotDiameter(ring: Int, size: Double) -> Double {
        let base = size * 0.021
        return max(size * 0.006, base - Double(ring) * size * 0.0025)
    }

    /// 第 `index` 个点在第 `ring` 环上的角度（弧度）。
    ///
    /// 每环带一个固定的角度错位（上游的 `angleOffset += 0.4`），否则四个环的点
    /// 会径向对齐成一条条辐条。
    static func angle(index: Int, of count: Int, turns: Double, ring: Int) -> Double {
        guard count > 0 else { return 0 }
        let step = 2 * Double.pi / Double(count)
        return step * Double(index) + Double(ring) * 0.4 - turns * 2 * .pi
    }

    /// 极坐标 → 屏幕坐标。
    static func point(angle: Double, radius: Double, center: CGPoint) -> CGPoint {
        CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
    }

    /// 角向明暗波：整圈走一个完整余弦周期 ⇒ 首尾自然相接，没有缝。
    static func alpha(angle: Double) -> Double {
        let t = (cos(angle) + 1) / 2
        return Self.minimumAlpha + (Self.maximumAlpha - Self.minimumAlpha) * t
    }

    // MARK: logo 的 slot 与轮播

    /// 第 `logoIndex` 个 logo 落在外环的哪个 slot 上。
    ///
    /// ⚠️ 上游用 `round(dotsPerRing / images.count)` 当步长，logo 数不整除时
    /// 末尾几个会挤在一起；这里按浮点均分再取整，任意数量都尽量摊开。
    static func slot(of logoIndex: Int, logoCount: Int) -> Int {
        guard logoCount > 0 else { return 0 }
        let stride = Double(Self.dotsPerRing) / Double(logoCount)
        let raw = Int((Double(logoIndex) * stride).rounded(.down))
        return ((raw % Self.dotsPerRing) + Self.dotsPerRing) % Self.dotsPerRing
    }

    /// 当前被点名的 logo 与它在自己那段窗口里的进度。
    static func feature(at date: Date, logoCount: Int) -> (index: Int, progress: Double) {
        guard logoCount > 0, Self.featureSeconds > 0 else { return (0, 0) }
        let elapsed = date.timeIntervalSinceReferenceDate
        let window = Self.featureSeconds
        let slotIndex = Int((elapsed / window).rounded(.down))
        let index = ((slotIndex % logoCount) + logoCount) % logoCount
        let raw = elapsed.truncatingRemainder(dividingBy: window)
        let progress = (raw < 0 ? raw + window : raw) / window
        return (index, min(max(0, progress), 1))
    }

    /// 静止形态下"谁被点名"：第 0 个，进度 0 ⇒ `popScale == 1`，谁都不放大。
    static let restingFeature: (index: Int, progress: Double) = (0, 0)

    /// pop 曲线：两端归 1、中段抬到 `popPeak`。用一个正弦拱，两端一阶导也为 0
    /// （直接用三角形折线的话，回到 1 的那一瞬间会有肉眼可见的折角）。
    static func popScale(progress: Double) -> Double {
        let t = min(max(0, progress), 1)
        let bump = sin(t * .pi)
        return 1 + (Self.popPeak - 1) * bump * bump
    }

    // MARK: 挤压位移场（替代 SpriteKit 物理体）

    /// 把 `dot` 沿着"远离 `source`"的方向推开，位移随距离衰减，半径之外原样返回。
    ///
    /// ⚠️ 三处退化都显式处理：`radius <= 0`、`strength == 0`、以及**点与源重合**
    /// （方向无定义，除以 0 会放 NaN 进 `Canvas`）。
    static func pushed(_ dot: CGPoint, awayFrom source: CGPoint, radius: Double, strength: Double) -> CGPoint {
        guard radius > 0, strength != 0 else { return dot }
        let dx = Double(dot.x - source.x)
        let dy = Double(dot.y - source.y)
        let distance = (dx * dx + dy * dy).squareRoot()
        guard distance > 0, distance < radius else { return dot }
        // 线性衰减：贴着源最强、到半径为 0。
        let falloff = 1 - distance / radius
        let amount = strength * falloff
        return CGPoint(x: dot.x + dx / distance * amount, y: dot.y + dy / distance * amount)
    }
}
