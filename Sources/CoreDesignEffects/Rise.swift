//
//  Rise.swift
//  CoreDesignEffects
//

import CoreDesign
import SwiftUI

/// 从视图上方浮起并淡出的一小段文字（"+1" 那种）。
/// ⚠️ **非泛型**——理由见 `TriggerRelay`。
private struct RiseCore: ViewModifier {
    let fire: Int
    let text: LocalizedStringKey
    let strength: MicroInteractionStrength
    let textColor: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let isReduced = self.reduceMotion
        let reach = self.strength.displacement * 3
        let text = self.text
        let color = self.textColor

        return content
            .overlay(alignment: .top) {
                Text(text)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
                    .keyframeAnimator(initialValue: RiseState(), trigger: self.fire) { view, state in
                        view
                            // RM-FORM-2: 本效果的反馈**本身**就是"淡入 → 上浮 → 淡出"，
                            // 去掉上浮后仍留有完整的淡入淡出，再叠一次透明度脉冲会变成
                            // 两次反馈。⇒ 走形态 2：静止位移 + 保留原有的淡入淡出。
                            //
                            // ⚠️ **为什么真分支是 `-reach * 0.5` 而不是 `0`**
                            //（#262 第 1 轮 review 明确要求归零，未采纳，理由如下）：
                            // 这里是**常量**位移，`isReduced` 为真时它每一帧都相同
                            // ⇒ 屏幕上**不产生任何运动**，FR-11 约束的是运动而非静态摆位。
                            // 而 `.overlay(alignment: .top)` 下 `offset 0` 恰好把这段文字
                            // **压在被修饰内容的顶部**（动画的起点位置，正常路径上它会立刻升走）
                            // ⇒ 归零反而让开启 Reduce Motion 的用户读到一段与数字重叠的
                            // "+1"，是可读性回退，不是无障碍改进。
                            // ⚠️ `MicroInteractionReduceMotionGuard.everyMotionCallIsGated`
                            // 的判据「真分支不得引用动画状态」正是为这一形态定的
                            //（要求恒等字面量曾造成一次误红，见该判据注释）。
                            .offset(y: isReduced ? -reach * 0.5 : state.lift)
                            .opacity(state.opacity)
                    } keyframes: { _ in
                        KeyframeTrack(\.lift) {
                            LinearKeyframe(0, duration: 0.02)
                            CubicKeyframe(-reach, duration: 0.85)
                        }
                        KeyframeTrack(\.opacity) {
                            LinearKeyframe(1, duration: 0.1)
                            LinearKeyframe(1, duration: 0.35)
                            LinearKeyframe(0, duration: 0.42)
                        }
                    }
                    .allowsHitTesting(false)
                    // ⚠️ **按装饰层处理**（#262 终审 I4）：初版留它对 VoiceOver 可读，
                    // 理由是"+1 是内容"——但同一段注释又说"权威数值应放在被修饰的视图上"，
                    // 那这段文字对 VO 就是**冗余**，且 overlay 常驻视图树（首尾 opacity 0），
                    // 会在 VO 滑动顺序里留下一个幽灵元素。
                    // ⇒ 与 `.shake` / `.jump` 对齐：隐藏，**通告由调用方负责**（FR-13）。
                    .accessibilityHidden(true)
            }
    }

    private struct RiseState {
        var lift: CGFloat = 0
        var opacity: Double = 0
    }
}

public extension View {

    /// `trigger` 变化时，从视图上方浮起一段文字。
    ///
    /// - Parameter text: 浮起的文字。⚠️ 类型是 `LocalizedStringKey` 而非 `String`
    ///   ——它是**调用方传入的界面文案**（公约第 4 节 **B 类**），必须可本地化（FR-7）。
    ///
    /// ⚠️ **不是 A 类**（初版注释写「组件自带的 UI 文案（公约 A 类）」，是误引）：
    /// A 的判别特征是「文案**写在组件源码里**，调用方看不见也改不了」，而公约同节明写
    /// 「A 类按定义不会出现在 `textParams[]` 里……参数按定义对调用方可见」
    /// ⇒ 一个 public 参数只可能是 B / C，不可能是 A。`"+1"` 由调用方给、内容是界面文案
    /// ⇒ **B**。（#262 第 3 轮 review 正是循着这处误引，推出「应改
    /// `LocalizedStringResource`」的建议。）
    ///
    /// ⚠️ **为什么不是 `LocalizedStringResource`**（#262 第 3 轮 review 建议，未采纳）：
    /// 1. 公约第 4 节有成文裁决——「**新增 B 类参数用 `LocalizedStringKey`**，与本仓既有
    ///    `SectionHeader` 一致、`Bundle.main` 解析语义不变，**不是**
    ///    `LocalizedStringResource`」（`docs/component-contract.md`）。本仓 6 个 B 类
    ///    文本参数（`SectionHeader` / `InsetGroupedSection` / `ProgressIndicator` /
    ///    `SettingsRow`）全是 `LocalizedStringKey`，只把这一个改掉是制造不一致。
    /// 2. 建议援引的 FR-7 自身写的是「`LocalizedStringResource` / `LocalizedStringKey`」
    ///    **二选一**（`.claude/prds/shipswift-harvest.md`）⇒ 现状已合规，不存在契约削弱。
    /// 3. 换成 `LocalizedStringResource` **并不自动**修好 bundle：字面量走
    ///    `init(stringLiteral:)`，实测其 `_bundleURL` 同样是 `Bundle.main`
    ///    （`String(reflecting:)` 可见）——只有调用方显式写 `bundle:` 才有区别，
    ///    而那条能力下面的绕行方式已经提供。
    ///
    /// ⚠️ **已知且有意接受的限制**：`LocalizedStringKey` 走 **`Bundle.main`** 查表
    /// ——App 调用方即其自身 bundle，没问题；**来自另一个 package 的调用方**，
    /// 其 `.module` 里的本地化不会被命中。
    /// **绕行方式**：调用方先用自己的 bundle 解析成字符串，再包成 key 传进来——
    /// `text: LocalizedStringKey(String(localized: "plus_one", bundle: .module))`。
    /// `Bundle.main` 查不到该键时 `Text` 原样回落，显示的正是调用方已解析好的译文
    /// （该回落由 `MicroInteractionAPITests.riseAcceptsPreResolvedLocalizedString`
    /// 用位图比对钉住；⚠️ 前提是译文本身不与宿主 App 的某个键字面相同）。
    func rise(
        trigger: some Equatable,
        text: LocalizedStringKey,
        strength: MicroInteractionStrength = .regular,
        color: Color = .accent
    ) -> some View {
        self.modifier(
            TriggerRelay(trigger: trigger) {
                RiseCore(fire: $0, text: text, strength: strength, textColor: color)
            }
        )
    }
}

#Preview("rise") {
    @Previewable @State var score = 0
    VStack(spacing: 60) {
        Text("\(score)")
            .font(.largeTitle.bold().monospacedDigit())
            .rise(trigger: score, text: "+1")
        Button("加分") { score += 1 }
    }
    .padding(60)
}
