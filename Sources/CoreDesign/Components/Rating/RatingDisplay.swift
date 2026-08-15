//
//  RatingDisplay.swift
//  CoreDesign
//

import SwiftUI

// MARK: - RatingDisplay

/// **材质层**: 内容. **表面角色**: 内容.
///
/// 只读评分展示 / Read-only rating indicator。
///
/// ⚠️ **它是 `Rating` 的兄弟组件，但拆的是「control vs indicator 的交互语义」，
/// 不是外观变体**（#41 裁决 4b）——Apple 自己就是这么分的（`Slider` vs `ProgressView`、
/// `Toggle` vs 只读标签）。证据是两者**共用同一个 `RatingStyle`**：外观候选并没有被兄弟
/// 组件消化掉，扩展点照样存在。这个区分要留痕，因为它**不是**任务书点名的「未成文第四
/// 出口」（那条讲的是「用兄弟组件替代扩展点来消化**外观**候选」），别把两者混为一谈。
///
/// ⚠️ **为什么不是 `Rating(isReadOnly: true)`**：归并方案（删 `isReadOnly`、统一走
/// `.disabled(true)`）会让所有展示态评分走 SwiftUI 原生 disabled 视觉——**变灰 + 降低
/// 对比度**，语义是「这个控件现在不能用」。而展示态（列表里显示某本书的评分）不是
/// 「不能用」，是「本来就不是控件」。归并是语义错配导致的视觉回归，不是 API 收敛。
/// 拆分后「控制展示态的路径」只剩一条：**选哪个类型**；`isEnabled` 回归它原本的语义
/// （控件可用性），不再兼任展示态开关。
///
/// 外观由环境里注入的 `RatingStyle` 决定，默认 `StarRatingStyle`——与 `Rating` 同一个
/// 协议、同一个环境入口，`View.ratingStyle(_:)` 一次注入同时影响两者。
///
/// ⚠️ **刻意没有 `.frame(minHeight:)` 命中区地板**：44pt 的 HIG 下限约束的是**可交互**
/// 元素，而本组件恒不可交互（无手势、无 adjust action）。给它补命中区只会在列表里凭空
/// 撑高行距。`Rating` 那条地板照旧保留。
///
/// Accessibility：label 用 Phase 0 预登记键 `"Rating"`（与 `Rating` 同键——对辅助技术
/// 而言它们是同一个概念的两种形态），value 复用
/// `Rating.accessibilityValueText(value:count:)`，半星精确播报（不取整）。
/// 不挂 `.accessibilityAdjustableAction`：没有可调整的东西。
///
/// ```swift
/// RatingDisplay(value: 4.5)
/// RatingDisplay(value: 7, count: 10)
/// ```
public struct RatingDisplay: View {
    // 非 `private`：`value` / `count` 需要在 `@testable import` 的单测里直接断言构造参数
    // 是否原样保留（见 RatingDisplayTests）。这不扩大 public API 表面。
    let value: Double
    let count: Int

    @Environment(\.ratingStyle) private var style

    /// - Parameters:
    ///   - value: 要展示的评分（可含小数——半星由小数部分表达）。
    ///   - count: 档位总数，默认 5。负数 clamp 到 0（与 `Rating` 同一条仓内惯例）。
    public init(value: Double, count: Int = 5) {
        self.value = value
        self.count = max(0, count)
    }

    public var body: some View {
        AnyView(self.style.makeBody(
            configuration: RatingStyleConfiguration(value: self.value, count: self.count)
        ))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Rating", bundle: .module))
        .accessibilityValue(
            Text(verbatim: Self.accessibilityValueText(value: self.value, count: self.count))
        )
    }

    // MARK: - Pure logic (unit-testable via `@testable import`)

    /// `accessibilityValue` 文案组装——**直接转发给 `Rating`，不复制一份**。
    ///
    /// ⚠️ 拆组件时顺手复制文案组装逻辑是本 epic 反复打的「两份实现必然漂移」：
    /// `bundle: .module` 漏传或插值形状跑偏都是**静默 fallback**（英文环境下输出恰好
    /// 不变，直到非英文本地化才暴露）。`RatingDisplayTests` 有一条断言把这条转发钉死。
    static func accessibilityValueText(value: Double, count: Int) -> String {
        Rating.accessibilityValueText(value: value, count: count)
    }
}

// MARK: - Preview

#Preview("RatingDisplay — Light") {
    RatingDisplayPreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("RatingDisplay — Dark") {
    RatingDisplayPreviewGallery()
        .preferredColorScheme(.dark)
}

private struct RatingDisplayPreviewGallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.xl) {
            VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                Text("整星").coreFont(.footnote).foregroundStyle(.secondary)
                RatingDisplay(value: 4)
            }

            VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                Text("半星").coreFont(.footnote).foregroundStyle(.secondary)
                RatingDisplay(value: 3.5)
            }

            VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                Text("十档（count: 10）").coreFont(.footnote).foregroundStyle(.secondary)
                RatingDisplay(value: 7, count: 10)
            }

            VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                Text(".tint(.orange) 覆盖").coreFont(.footnote).foregroundStyle(.secondary)
                RatingDisplay(value: 4.5)
                    .tint(.orange)
            }
        }
        .padding()
        .background(Color.surfaceCanvas)
    }
}
