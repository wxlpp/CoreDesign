//
//  FilterTransitionSupport.swift
//  CoreDesignEffects
//
//  滤镜类转场的公共约定 / Shared conventions for the filter transitions.
//

import SwiftUI

// MARK: - ⚠️ 写滤镜类转场前必读：这一簇为什么不套「降级为淡入淡出」

// `#266`（拆自 `#251` 的 16 种转场）的四种——`blur` / `filmExposure` / `snapshot` /
// `flicker`——共同点是**不改变几何、只改变成像**：全簇没有一处位移 / 旋转 / 缩放，
// 四个文件里一个 `MicroInteractionReduceMotionGuard.motionCalls` 关键字都不出现
//（判据：`FilterTransitionTests.filterClusterChangesImagingNotGeometry`）。
//
// ⇒ `#251` 给整簇转场定的「位移 / 旋转类降级为淡入淡出」在这里**没有适用对象**。
// 照套的话四种会一起塌成 `.opacity`，把本来就不构成前庭诱因的三种也一并抹掉。
// ⇒ **逐个判**（`266.md` 逐字要求），结论如下表；每一条的理由写在各自文件的类型文档里。
//
// | 转场 | 前庭（光流）风险 | 闪烁（亮度骤变）风险 | 读哪个信号 | 降级形态 |
// |---|---|---|---|---|
// | `blur` | 无——无位移/缩放/旋转 ⇒ 无光流 | 无——半径与不透明度都**单调**，亮度不往复 | **都不读** | **不降级**（降了等于把这条转场本身抹掉） |
// | `filmExposure` | 无 | **有（弱）**：一次单向过曝峰值 = 大面积亮度上冲 | `\.accessibilityDimFlashingLights` | 峰值压到 `calmedBrightnessCeiling` 以下 |
// | `snapshot` | 无 | **有（强）**：快门白场比过曝更陡 | 同上 | 同上 |
// | `flicker` | 无位移，但高频往复本身是「非必要的重复动画」 | **强**：WCAG 2.3.1 明确点名 | `\.accessibilityDimFlashingLights` **或** `\.accessibilityReduceMotion` | 往复整个去掉，退化为单调淡出 |
//
// ⚠️ **为什么闪烁这一侧读的是 `\.accessibilityDimFlashingLights` 而不是 Reduce Motion**：
// 前者（iOS 17+ / macOS 14+，「减弱闪烁灯光」）正是系统为**光敏性**提供的信号，
// 语义与 WCAG 2.3.1 逐字对应；Reduce Motion 管的是**运动**，拿它当闪烁开关是张冠李戴
// ——会漏掉「开了减弱闪烁但没开减弱动态效果」的用户，那恰恰是本簇最该保护的人。
// `flicker` 两个都读，理由见 `FlickerTransition` 的类型文档（往复也算不必要动画）。
//
// ⚠️ **两个环境键都不可注入**（`.environment(\.accessibilityDimFlashingLights, true)`
// 编译红：`EnvironmentValues` 上它们是只读的系统偏好，实测两者皆然）
// ⇒ 「档位真的被消费」这件事走本仓既有成法：**纯函数**（本文件）+ **调用点源码判据**
//（`FilterTransitionTests` 的 `safetySignalsAreOnlyConsumedByTheSharedGate`，
// 形态照抄 `MicroInteractionReduceMotionGuard.reduceMotionIsOnlyConsumedByTheSharedGate`）。
// 位图那一路只能验「给定档位画出什么」，验不了「档位从哪来」。

// MARK: - 相位 → 进度

/// 滤镜类转场的**相位契约**（纯函数，生产代码与判据共用同一份）。
///
/// ⚠️⚠️ **`TransitionPhase` 是 3 case frozen enum**（`willAppear` / `identity` /
/// `didDisappear`，`value` 分别是 `-1` / `0` / `1`）⇒ 本函数的**可达取值只有 `{0, 1}`**。
/// 任何在这两个值之外才发生的事情（过曝峰值、快门白场、往复闪烁），
/// **必须**由 SwiftUI 对 `Animatable.animatableData` 的插值产生，
/// 而不是指望 `body(content:phase:)` 会拿到中间相位——它不会。
/// 这条教训是 `#253` 的 `ParticleTransition` 用「粒子从未在任何真实相位上出现过」
/// 换来的（见那份文件的 `ParticleBurstLayer` 类型文档），本簇三种非单调曲线
/// 逐个复用它：`FilmExposureFilm` / `SnapshotFilm` / `FlickerFilm` 都是
/// `ViewModifier & Animatable`，`animatableData` 直接绑在 `progress` 上。
/// ⚠️ 唯一的例外是 `blur`——它的两条曲线**在进度上是仿射的**，
/// SwiftUI 对 `radius` / `opacity` 自身的插值与「先插值进度再求值」逐点相等
/// ⇒ 不需要 `Animatable`。这条豁免由 `FilterTransitionTests.blurCurvesAreAffine`
/// 钉住：谁把 blur 的曲线改成非仿射，那条判据当场判红，逼人回来加 `Animatable`。
nonisolated enum FilterTransitionPhase {

    /// 把任意 `Double` 夹进 `0...1`，`NaN` 归 0。
    ///
    /// ⚠️ **`NaN` 必须显式处理**：`min`/`max` 对 `NaN` 的行为按参数顺序而定，
    /// 漏掉它会让一个 `NaN` 进度直接变成 `NaN` 的滤镜实参
    ///（`.opacity(nan)` / `.blur(radius: nan)` 在渲染层是未定义的）。
    /// 本簇全部纯函数的入口都过这一道。
    static func clamped01(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return Swift.min(Swift.max(value, 0), 1)
    }

    /// 相位 → 转场进度，落在 `0...1`。
    ///
    /// ⚠️ **`.identity` 必须恒为 0**：那是转场停住之后长期停留的那一帧。
    /// 它为 0 ⇒ 本簇每一条滤镜曲线在那里都取**中性值**（模糊半径 0、亮度增量 0、
    /// 饱和度 1、对比度 1、不透明度 1）⇒ 常驻态与「没用过这条转场」逐字节相同。
    /// 判据：`FilterTransitionTests.identityIsNeutralForEveryFilter`。
    static func progress(phase: TransitionPhase) -> Double {
        Self.clamped01(abs(phase.value))
    }
}

// MARK: - 安全档位

/// 滤镜类转场的**安全档位**：两道 a11y 信号裁出来的结果。
///
/// ⚠️ **刻意 `internal`**（同 `EffectsPresentation` 的理由，逐字见 `EffectsEnergy.swift`）：
/// 本类型只服务同模块四个转场，没有跨模块消费者；而两个解析函数一旦 `public`，
/// 它们的裸 `Bool` 参数就会命中 `BoolExemptionGuard` 的判据、要求署名豁免并抬
/// `docs/bool-exemptions-baseline.json` 的棘轮（`CoreDesignEffects` 当前是 0 条，
/// 而本 epic 的净增预算只有 2 条）。测试走 `@testable import CoreDesignEffects`，够用。
enum FilterTransitionSafety: Sendable, Equatable, CaseIterable {

    /// 完整呈现。
    case full

    /// 压制：亮度骤变压到安全上限以下、往复整个去掉。
    ///
    /// ⚠️ **不是 no-op**：转场承载的是"这块内容出现 / 消失了"这个信息，
    /// 抹掉它会让开启该偏好的用户看到界面瞬间跳变。四种在本档下都仍然
    /// 淡入淡出（`blur` 还保留模糊、`snapshot` 还保留显影）。
    case calmed

    /// `calmed` 档允许的亮度增量上限。
    ///
    /// ⚠️ **`0.08` 不是随手取的**：WCAG 2.3.1《Three Flashes or Below Threshold》的
    /// 通用闪光阈值把「相对亮度变化 ≥ **0.1**」作为大面积闪光的判据之一
    /// ⇒ 取 0.08 让本簇在 `calmed` 档下留在那条线**以下**。
    /// ⚠️ **口径要照实说**：`.brightness(_:)` 是对各通道做**加性**偏移，
    /// 不等于相对亮度的精确定义；0.08 是一个**保守的替身**，不是逐像素达标证明。
    /// 真正达标要看具体内容的底色，那不是设计系统这一层能替调用方算的。
    static let calmedBrightnessCeiling: Double = 0.08

    /// **曝光类**（`filmExposure` / `snapshot`）的档位判定：只看「减弱闪烁灯光」。
    ///
    /// ⚠️ **有意不看 Reduce Motion**：这两条曲线一处位移都没有，
    /// 把它们挂到运动偏好上既保护不了该保护的人（只开减弱闪烁的那批），
    /// 又会让只开减弱动态效果的用户白白丢掉一条无害的成像效果。
    static func exposure(dimFlashingLights: Bool) -> FilterTransitionSafety {
        dimFlashingLights ? .calmed : .full
    }

    /// **往复类**（`flicker`）的档位判定：两个信号**任一**开启即压制。
    ///
    /// ⚠️ 这里把 Reduce Motion 也算进来，理由与曝光类相反：往复闪烁是一段
    /// **重复的、非必要的**动画，`flicker` 又是全簇唯一会在一次转场里来回好几遍的
    /// ——它落在「减弱动态效果」这个偏好想关掉的那一类里。判据见
    /// `FilterTransitionTests.oscillationGateTakesEitherSignal`（四种组合逐个钉）。
    static func oscillation(dimFlashingLights: Bool, reduceMotion: Bool) -> FilterTransitionSafety {
        (dimFlashingLights || reduceMotion) ? .calmed : .full
    }

    /// 把调用方请求的曝光峰值按档位压到安全范围。
    ///
    /// ⚠️ **返回的是"最终画出来的那个数"**，调用点不再自己判档位——
    /// 这正是 `EffectsEnergyState.presentation(reduceMotion:)` 立下的那条纪律：
    /// 档位的结论物化成一个值交给绘制层，绘制层不再看见原始信号。
    func exposurePeak(_ requested: Double) -> Double {
        let sane = FilterTransitionPhase.clamped01(requested)
        switch self {
        case .full: return sane
        case .calmed: return Swift.min(sane, Self.calmedBrightnessCeiling)
        }
    }

    /// 把调用方请求的往复次数按档位压到安全范围。`calmed` ⇒ 0（无往复）。
    func oscillationCycles(_ requested: Int) -> Int {
        switch self {
        case .full: return Swift.max(0, requested)
        case .calmed: return 0
        }
    }
}
