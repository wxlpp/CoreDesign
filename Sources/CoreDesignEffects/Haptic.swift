//
//  Haptic.swift
//  CoreDesignEffects
//

import SwiftUI

public extension View {

    /// `trigger` 变化时播一次触感反馈。
    ///
    /// ⚠️ **这是 `sensoryFeedback` 的薄封装，不是重造**——存在的唯一理由是
    /// **可发现性**：其余七个微交互都在本模块，触感却要调用方去想起系统 API，
    /// 会导致「视觉反馈有、触感没有」的不一致。
    ///
    /// ⚠️ **本仓不重造系统已提供的能力**（对照 CLAUDE.md：`.core` style「换皮不重造控件」；
    /// `Toggle` / `TextField` 有意不提供 `.core` style）。所以这里**原样透传**
    /// `SensoryFeedback`，不自定义一套反馈枚举——自定义会丢掉系统未来新增的类型。
    ///
    /// ```swift
    /// view.haptic(.success, trigger: purchased)
    /// ```
    func haptic(
        _ feedback: SensoryFeedback,
        trigger: some Equatable
    ) -> some View {
        self.sensoryFeedback(feedback, trigger: trigger)
    }
}
