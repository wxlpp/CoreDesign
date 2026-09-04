//
//  FullScreenTransitionPlan.swift
//  CoreDesignEffects
//
//  FullScreenButton 的转场裁决 / The transition decision behind FullScreenButton.
//

import SwiftUI

// MARK: - 转场裁决 / Transition decision

/// `FullScreenButton` 用哪一种导航转场。
///
/// ## 为什么是一个纯枚举而不是就地写 `#if`
///
/// AD-E 的四件里只有这一件走"隔离 + 文档标注"，而**隔离本身也要能被判据看见**：
/// `.zoom(sourceID:in:)` 在 macOS 上标了 `unavailable`（实测编译错误逐字：
/// `'zoom(sourceID:in:)' is unavailable in macOS`），若把平台分支与 Reduce Motion
/// 分支混在 `body` 的 `#if` 里，macOS 上那半段代码**根本不参与编译**
/// ⇒ 判据在 macOS 单测里对它无话可说。
///
/// ⇒ 把"用哪种转场"提成一个**两端都编译、两端都可求值**的纯函数，
/// `#if` 只留在真正无法跨平台的那一行（`.navigationTransition(.zoom(...))`）。
/// macOS 上的单测因此能对**iOS 的那条分支**求值（`platformSupportsZoom: true`），
/// 这是本仓能在 macOS 上验证 iOS 行为的唯一可行形态。
///
/// ⚠️ **刻意 `internal`**（同 `EffectsPresentation` 的理由）：
/// `resolve(reduceMotion:platformSupportsZoom:)` 一旦 `public`，两个裸 `Bool` 参数
/// 就会命中 `BoolExemptionGuard`、要求署名豁免并抬棘轮基线
/// （`CoreDesignEffects` 当前是 0 条）。测试走 `@testable import` 够用。
enum FullScreenTransitionPlan: Sendable, Equatable, CaseIterable {

    /// 系统的几何匹配放大转场（`.zoom(sourceID:in:)`）。**iOS 专有。**
    case zoom

    /// 系统默认的推入转场。macOS 上的唯一形态，也是 Reduce Motion 下两端共同的降级形态。
    case plain

    /// 当前编译目标是否有 `.zoom`。
    ///
    /// ⚠️ 这是**唯一**一处平台常量；`body` 里的 `#if` 与它成对出现，
    /// 由 `PlatformSupportGuard.zoomIsFencedToIOS` 钉住两者不脱节。
    static var platformSupportsZoom: Bool {
        #if os(iOS)
        true
        #else
        false
        #endif
    }

    /// 两道闸：平台先，Reduce Motion 后。任一不满足都落到 `.plain`。
    ///
    /// ⚠️ **Reduce Motion 这道闸不是多余的**：`.zoom` 是一次几何放大（卡片长到整屏），
    /// 正是 FR-11 要求去掉的那类运动。降级形态是系统默认转场——**不是 no-op**：
    /// 目的地照常推入，用户仍然知道"换页了"。
    static func resolve(reduceMotion: Bool, platformSupportsZoom: Bool) -> FullScreenTransitionPlan {
        guard platformSupportsZoom else { return .plain }
        return reduceMotion ? .plain : .zoom
    }
}
