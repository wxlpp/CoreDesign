//
//  MicroInteractionSupport.swift
//  CoreDesignEffects
//
//  微交互的公共约定 / Shared conventions for micro-interactions.
//

import CoreDesign
import SwiftUI

// MARK: - 强度档位

/// 微交互的强度。**所有**微交互共用这一个枚举。
///
/// ⚠️ 不暴露"位移像素数""旋转角度"这类裸数值——本仓的调参惯例是语义档位单一来源
/// （对照 `ButtonRoleStyleRole`：role 调色板的唯一来源，新增 role 扩枚举而不是各自定义）。
public enum MicroInteractionStrength: Sendable, CaseIterable {
    case subtle, regular, pronounced

    /// 位移类效果的振幅（pt）。
    var displacement: CGFloat {
        switch self {
        case .subtle: 4
        case .regular: 9
        case .pronounced: 16
        }
    }

    /// 缩放类效果的形变量（1.0 = 不变）。
    var scaleDelta: CGFloat {
        switch self {
        case .subtle: 0.06
        case .regular: 0.14
        case .pronounced: 0.24
        }
    }

    /// 粒子类效果的数量。
    var particleCount: Int {
        switch self {
        case .subtle: 6
        case .regular: 12
        case .pronounced: 22
        }
    }
}

// MARK: - ⚠️ 写微交互前必读：两个隔离约束

// 1. **`keyframeAnimator` / `phaseAnimator` 的 body 闭包是 `@Sendable`（nonisolated）**。
//    本包开了 `.defaultIsolation(MainActor.self)`，所以在闭包里读 `@Environment` 属性
//    （如 `self.reduceMotion`）会报
//    `main actor-isolated property ... can not be referenced from a Sendable closure`。
//    ⇒ **在 `body` 里先取成局部 `let`，再捕获进闭包。**
//
// 2. **泛型 trigger 约束成 `Equatable & Sendable`**（比 SwiftUI 自己的
//    `keyframeAnimator(trigger: some Equatable)` 严一档）。不加会报
//    `capture of non-Sendable type 'T.Type' in an isolated closure`——实测**多 10 条警告**，
//    而本仓基线是 0 条。
//
//    ⚠️ **代价与它的实际射程**：在**同样设了 `defaultIsolation(MainActor)` 的模块**里，
//    嵌套声明的 `enum Foo: Equatable` 会得到 MainActor 隔离的 conformance，
//    满足不了 `Sendable`，报
//    `main actor-isolated conformance of 'Foo' to 'Equatable' cannot satisfy
//    conformance requirement for a 'Sendable' type parameter`。
//    ⚠️ **解法是标 `nonisolated`；只提到文件作用域不够**——`defaultIsolation` 作用于
//    **整个 target**，文件作用域的枚举照样拿到隔离的 conformance（实测）。
//    ⚠️ **但下游 App 通常不设 `defaultIsolation`**，那里的嵌套枚举天然满足 `Sendable`
//    ⇒ 这道摩擦主要落在本包自己的测试 target 上，不是调用方的日常路径。
//
// ⚠️ 这两条与 `CoreDesignShaders` 踩到的是同一类问题（`Bundle.module` 也是 MainActor
// 隔离的）——本包的 `defaultIsolation` 让"闭包里随手读 self"变成一个反复出现的坑。

// MARK: - Reduce Motion 降级

extension View {

    /// Reduce Motion 开启时把**位移 / 旋转 / 缩放**换成一次不移动的透明度脉冲。
    ///
    /// ⚠️ **降级不是"什么都不做"**：微交互承载的是"这件事发生了"这个信息，
    /// 直接抹掉会让开启该偏好的用户收不到反馈。⇒ 保留"有反馈"，去掉"有运动"（FR-11）。
    ///
    /// ⚠️ 本仓的降级基线由此统一。各效果**不要**各自实现降级路径——那样必然漂移。
    @ViewBuilder
    func reduceMotionFallback(active: Bool, trigger: some Equatable & Sendable) -> some View {
        if active {
            self.modifier(OpacityPulse(trigger: trigger))
        } else {
            self
        }
    }
}

/// Reduce Motion 下的统一降级形态：一次快速的透明度脉冲。
private struct OpacityPulse<T: Equatable & Sendable>: ViewModifier {
    let trigger: T

    func body(content: Content) -> some View {
        content.phaseAnimator([1.0, 0.45, 1.0], trigger: self.trigger) { view, opacity in
            view.opacity(opacity)
        } animation: { _ in
            .easeInOut(duration: 0.12)
        }
    }
}
