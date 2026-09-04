//
//  SphereField.swift
//  CoreDesignEffects
//
//  球面点云的几何与取色契约 / Geometry and tinting contract for the sphere point clouds.
//

import CoreDesign
import SwiftUI

// MARK: - 球面几何 / Sphere geometry

/// `DotSphere` 与 `CharSphere` **共用**的纯几何：Vogel 螺旋点集、绕 Y 轴旋转、
/// 单轴透视投影、景深不透明度、以及"从下往上洗"的色波。
///
/// ⚠️ **抽出来的唯一理由是可测性**（与 `MeshDrift` / `ConfettiBurst` / `ProcessingSweep`
/// 同一条纪律）：判据要能对**这条真轨道**求值，而不是在测试里重抄一遍常量。
/// ⚠️ **不要把字面量写回绘制层**——那会让钉帧判据重新变成"测试自说自话"。
///
/// ## 为什么它一行 `#if` 都没有（AD-E 的核心）
///
/// 上游 `SWDotSphere` / `SWCharSphere` 的 `import UIKit` **只服务一件事**：
/// `UIColor(color).getRed(&r, &g, &b, &a)` 把 `Color` 拆成分量做插值
/// （它自己的 `#else` 分支已经在用跨平台的 `Color.resolve(in:)`）。
/// 本仓两条纪律各堵掉那件事的一半：
///
/// - **取色只有三个合法来源**（AD-D）⇒ 不许写 `Color(red:green:blue:)`，
///   `EffectsColorLiteralGuard` 对数值构造直接判红；
/// - 插值改走 SwiftUI 自己的 `Color.mix(with:by:)`（iOS 18+ / macOS 15+）
///   ⇒ **不需要**把颜色拆成分量，那个 UIKit 依赖连同它的平台分支一起消失。
///
/// ⇒ 三维投影本身是纯算术，本来就与 UIKit 无关。**本文件与两个球面件在 macOS 上
/// 与 iOS 上是同一份代码**，不是"能编译但空转"。
nonisolated enum SphereField {

    // MARK: 常量

    /// 透视焦距与世界半径的比值。上游是 `focal = 300` 对 `radius = 100`。
    ///
    /// ⚠️ 写成**比值**而不是绝对值：世界半径随容器尺寸走，焦距若钉死成 300，
    /// 小尺寸容器上的透视会强到把球压成一个碟子。
    static let focalRatio: Double = 3

    /// 世界半径占容器短边半径的比例。留出余量，让近侧放大的点不被裁掉。
    static let radiusRatio: Double = 0.62

    /// 一圈自转的默认周期（秒）。
    static let rotationPeriod: Double = 24

    /// 一次完整换色（渐变 + 停顿）的周期（秒）。
    static let waveCycle: Double = 10.5

    /// 换色本身占多久，其余是停顿。
    static let waveFade: Double = 5.5

    /// Reduce Motion / 静止形态所用的相位。
    ///
    /// 取 `0.125` 而不是 `0`（同 `MeshDrift.restingPhase` 的理由）：`0` 那一帧
    /// 螺旋的接缝正对着观察者，看起来像"没做任何事"。
    static let restingPhase: Double = 0.125

    /// 景深不透明度的上下界。下界不取 0——远侧完全透明会让球看起来只有半个壳。
    static let minimumAlpha: Double = 0.28
    static let maximumAlpha: Double = 1.0

    // MARK: 点集

    /// 把点数钳进 `0...limit`。
    ///
    /// ⚠️ **不 `precondition`**（AD-F 逐字：库代码对数据规模抛断言就是让宿主 App crash）。
    static func clamped(count: Int, limit: Int) -> Int {
        min(max(0, count), max(0, limit))
    }

    /// 球面 Fibonacci（Vogel 螺旋）点集里的第 `index` 个点，落在**单位球面**上。
    ///
    ///     y = 1 − 2i / (N − 1)
    ///     θ = i · π(3 − √5)
    ///     (x, z) = √(1 − y²) · (cos θ, sin θ)
    ///
    /// ⚠️ `count == 1` 时上游的 `(N − 1)` 会除零 ⇒ 这里显式退化到赤道。
    static func unitPoint(index: Int, count: Int) -> SIMD3<Double> {
        let y: Double = count > 1 ? 1 - (Double(index) / Double(count - 1)) * 2 : 0
        let clampedY = min(max(-1, y), 1)
        let radiusAtY = (max(0, 1 - clampedY * clampedY)).squareRoot()
        let goldenAngle = Double.pi * (3 - 5.0.squareRoot())
        let theta = goldenAngle * Double(index)
        return SIMD3(radiusAtY * cos(theta), clampedY, radiusAtY * sin(theta))
    }

    /// 第 `index` 个点分到字表里的哪一个字。
    ///
    /// ⚠️ **确定性散列，不是 `Int.random`**（上游是后者）：随机分配会让同一份输入
    /// 每次渲染都不同 ⇒ 位图判据与 `run-snapshots.sh` 都拿它没办法。
    /// ⚠️ 也不能是 `index % count`——那会让字表沿着 Vogel 螺旋整齐重复，
    /// 肉眼能看出一圈圈的规律。
    ///
    /// ⚠️⚠️ **这里必须是"雪崩型"混合，Knuth 乘法散列在这个用法下不算数**
    ///（本轮渲图实测到、`SphereFieldTests.glyphSlotIsScrambledNotModulo` 钉住）：
    /// `(index &* 2654435761) % 5` = `(index * (2654435761 % 5)) % 5` = `index % 5`
    /// ——乘法散列把熵推到**高位**，而"直接对一个小数取模"只看**低位**
    /// ⇒ 它当场退化成恒等映射，与朴素取模逐项相同。
    /// ⇒ 改用 SplitMix64 的最终混合（两轮"右移异或 + 乘"再一次右移异或），
    /// 它把高位的熵**搬回低位**，取模之后才真的散开。
    static func glyphSlot(index: Int, glyphCount: Int) -> Int {
        guard glyphCount > 0 else { return 0 }
        var x = UInt64(bitPattern: Int64(index)) &+ 0x9E37_79B9_7F4A_7C15
        x = (x ^ (x >> 30)) &* 0xBF58_476D_1CE4_E5B9
        x = (x ^ (x >> 27)) &* 0x94D0_49BB_1331_11EB
        x ^= x >> 31
        return Int(x % UInt64(glyphCount))
    }

    /// 点在球面上的高度，归一化到 `0...1`（0 = 南极，1 = 北极）。色波的逐点延迟吃它。
    static func elevation(of point: SIMD3<Double>) -> Double {
        min(max(0, (point.y + 1) / 2), 1)
    }

    /// 绕 **Y 轴**旋转 `turns` 圈。y 不变。
    static func spun(_ point: SIMD3<Double>, byTurns turns: Double) -> SIMD3<Double> {
        let a = turns * 2 * .pi
        let c = cos(a)
        let s = sin(a)
        return SIMD3(point.x * c - point.z * s, point.y, point.x * s + point.z * c)
    }

    /// 由时刻取相位，落在 `[0, 1)`。
    ///
    /// ⚠️ 用 `timeIntervalSinceReferenceDate` 取模而不是"起始时刻到现在"（同
    /// `MeshDrift.phase(at:)`）：球是**常驻呈现**、没有起点，无状态的取模让任意
    /// 时刻进入 / 退出都不跳帧，也不必为它留一个 `@State var start`。
    static func phase(at date: Date, period: Double = SphereField.rotationPeriod) -> Double {
        guard period > 0 else { return 0 }
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period)
        return (t < 0 ? t + period : t) / period
    }

    // MARK: 投影

    /// 单轴透视投影的结果：屏幕坐标 + 景深系数。
    struct Projected: Equatable {
        /// 屏幕横坐标（已含容器中心偏移）。
        let x: Double
        /// 屏幕纵坐标。
        let y: Double
        /// 景深系数 `focal / (focal + z)`：> 1 是近侧、< 1 是远侧。
        let depth: Double
    }

    /// 把单位球面上的点投到屏幕。
    ///
    /// ⚠️ `worldRadius == 0`（尺寸为 0 的容器）时焦距也是 0，`focal / (focal + z)`
    /// 会变成 `0 / 0` ⇒ 显式退化到 `depth = 1`，绝不放 NaN 进 `Canvas`。
    static func project(_ point: SIMD3<Double>, worldRadius: Double, center: CGPoint) -> Projected {
        let focal = worldRadius * Self.focalRatio
        let z = point.z * worldRadius
        let denominator = focal + z
        let depth = (focal > 0 && denominator > 0) ? focal / denominator : 1
        return Projected(
            x: center.x + point.x * worldRadius * depth,
            y: center.y + point.y * worldRadius * depth,
            depth: depth
        )
    }

    /// 远侧（背面）判定。`z > 0` 是背对观察者的那一半。
    static func isFarSide(_ point: SIMD3<Double>) -> Bool { point.z > 0 }

    /// 景深不透明度：近的实、远的虚。
    static func alpha(depth: Double) -> Double {
        // 景深的可达区间由 `focalRatio` 定死：z ∈ [−r, r] ⇒ depth ∈ [k/(k+1), k/(k−1)]。
        let lower = Self.focalRatio / (Self.focalRatio + 1)
        let upper = Self.focalRatio / (Self.focalRatio - 1)
        let t = min(max(0, (depth - lower) / (upper - lower)), 1)
        return Self.minimumAlpha + (Self.maximumAlpha - Self.minimumAlpha) * t
    }

    // MARK: 色波

    /// 某一时刻正在从哪一档色换到哪一档色。
    struct Wave: Equatable {
        let base: Int
        let next: Int
        /// 本周期内已经过去多久（秒）。逐点延迟吃它。
        let timeInCycle: Double
    }

    /// 当前时刻的色波。空色板 / 单色色板都退化为"两端同一档"，不除零。
    static func wave(at date: Date, paletteCount: Int) -> Wave {
        let slots = max(1, paletteCount)
        let elapsed = date.timeIntervalSinceReferenceDate
        let cycle = max(0.001, Self.waveCycle)
        let raw = elapsed.truncatingRemainder(dividingBy: cycle)
        let timeInCycle = raw < 0 ? raw + cycle : raw
        let index = Int((elapsed / cycle).rounded(.down))
        // ⚠️ Swift 的 `%` 对负数给负余数 ⇒ 参考时刻之前的时间会落到负索引上。
        let base = ((index % slots) + slots) % slots
        return Wave(base: base, next: (base + 1) % slots, timeInCycle: timeInCycle)
    }

    /// 静止形态下的色波：钉在换色刚开始那一刻，整个球是同一档色。
    static func restingWave(paletteCount: Int) -> Wave {
        let slots = max(1, paletteCount)
        return Wave(base: 0, next: slots > 1 ? 1 : 0, timeInCycle: 0)
    }

    /// 逐点的换色进度。**高处延迟更久** ⇒ 浪从下往上洗。
    static func waveProgress(elevation: Double, timeInCycle: Double) -> Double {
        let fade = max(0.001, Self.waveFade)
        let delay = min(max(0, elevation), 1) * fade
        return min(max(0, (timeInCycle - delay) / fade), 1)
    }

    /// 本点该用的颜色。**空色板返回 `nil`** ⇒ 绘制层改用调用方的 `.tint`（FR-8）。
    ///
    /// ⚠️ 插值走 SwiftUI 的 `Color.mix(with:by:)`，**不拆分量**——见类型文档。
    static func tone(palette: [Color], wave: Wave, progress: Double) -> Color? {
        guard !palette.isEmpty else { return nil }
        let base = palette[wave.base % palette.count]
        let next = palette[wave.next % palette.count]
        guard base != next else { return base }
        return base.mix(with: next, by: min(max(0, progress), 1))
    }
}
