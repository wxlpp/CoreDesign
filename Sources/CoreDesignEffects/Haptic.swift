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
    ///
    /// ⚠️ **`trigger` 是 `some Equatable`，刻意*不*约束 `Sendable`** ——
    /// 这与其余七个入口**完全一致**（它们同样只写 `some Equatable`），不是本文件的例外。
    /// 加上 `Sendable` 会让 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` 的下游工程
    /// （Xcode 26 新建工程的默认值）里任何 `enum Step: Equatable` 当 trigger 都报
    /// `main actor-isolated conformance ... cannot satisfy ... 'Sendable'`。
    /// 完整来龙去脉见 `TriggerRelay` 的文档，机器判据见测试 `triggerIsGeneric`
    /// （用一个 MainActor 隔离 conformance 的类型当 trigger，加约束即编译红）。
    /// ⚠️ #262 第 1 轮 review 曾提出"本入口是唯一没约束 `Sendable` 的"，前提不成立，未采纳。
    func haptic(
        _ feedback: SensoryFeedback,
        trigger: some Equatable
    ) -> some View {
        self.sensoryFeedback(feedback, trigger: trigger)
    }
}

// ⚠️ **本 `#Preview` 看不出任何东西，这是有意留的**（`#256` 补齐 40 个 API 单位的
// 「有 `#Preview`」那一条时发现本文件是八个微交互里唯一没有的）：
// 触感没有视觉表现，模拟器也没有 Taptic Engine ⇒ 它**不是**视觉冒烟，
// 只是「本入口点在库内可被构造、可被点按」的存在性冒烟 + 真机上手动验触感的入口。
// 想真的感觉到它，在**真机**上跑 `./scripts/run-preview.sh` 并进画廊的
// `.haptic(_:trigger:)` 条目。
#Preview("haptic") {
    @Previewable @State var taps = 0
    VStack(spacing: 24) {
        Text(verbatim: "taps: \(taps)")
        Button("播一次 .success") { taps += 1 }
            .haptic(.success, trigger: taps)
    }
    .padding()
}
