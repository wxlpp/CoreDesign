# rise

从视图上方浮起并淡出的一小段文字（"+1" 那种）/ A small label floating up and fading out.

`View.rise(trigger:text:strength:color:)`（`CoreDesignEffects/Rise.swift`，Issue #250）。

⚠️ **本 API 在 `CoreDesignEffects` 里，不在 `CoreDesign`**：

```swift
import CoreDesignEffects
```

## API

```swift
public extension View {

    func rise(
        trigger: some Equatable,
        text: LocalizedStringKey,
        strength: MicroInteractionStrength = .regular,
        color: Color = .accent
    ) -> some View
}
```

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| trigger | `some Equatable` | - | 值**变化**时浮起一次。首次出现（初始值）**不**浮 |
| text | `LocalizedStringKey` | - | 浮起的文字。**必须可本地化**（FR-7） |
| strength | `MicroInteractionStrength` | `.regular` | 上浮距离 `displacement × 3` = 12 / 27 / 48 pt |
| color | `Color` | `.accent` | 文字色（第 3 层语义 token） |

文字挂在 `.overlay(alignment: .top)` 上，字体 `.caption.weight(.semibold)`；
上浮轨道 `0 →（0.85 s cubic）→ -reach`，透明度 `1（0.1 s）→ 1（0.35 s）→ 0（0.42 s）`。

### `text` 为什么是 `LocalizedStringKey`

它是**调用方传入的界面文案**（组件公约第 4 节 **B 类**）⇒ 必须可本地化（FR-7）。
公约同节有成文裁决：**新增 B 类参数用 `LocalizedStringKey`**，与本仓既有
`SectionHeader` / `InsetGroupedSection` / `ProgressIndicator` / `SettingsRow`
一致，**不是** `LocalizedStringResource`。

⚠️ **已知且有意接受的限度**：`LocalizedStringKey` 走 **`Bundle.main`** 查表——
App 调用方即其自身 bundle，没问题；**来自另一个 package 的调用方**，其 `.module`
里的本地化不会被命中。

**绕行方式**：调用方先用自己的 bundle 解析成字符串，再包成 key 传进来：

```swift
.rise(trigger: score, text: LocalizedStringKey(String(localized: "plus_one", bundle: .module)))
```

`Bundle.main` 查不到该键时 `Text` 原样回落，显示的正是调用方已解析好的译文。
这条绕行由 `MicroInteractionAPITests.riseAcceptsPreResolvedLocalizedString` 用**位图比对**
钉住（⚠️ 前提是译文本身不与宿主 App 的某个键字面相同）。

### `MicroInteractionStrength` 与 `nonisolated`

`MicroInteractionStrength` 是 `public nonisolated enum`。⚠️ **`nonisolated` 是承重的**
——完整理由与报错原文见
[`shake.md`](shake.md#microinteractionstrength-与-nonisolated)。一句话版：它只由
`scripts/downstream-probe`（`readMicroInteractionStrengths()`）钉住，本库自己的
`swift build` / `swift test` 摘掉它照样全绿。

## 取色（FR-8）

文字色走**调用方参数**，默认 `Color.accent`（第 3 层语义 token）。本效果不额外取
`.tint`——参数已经覆盖了"调用方要自定"的场景。

## Reduce Motion

⚠️ **本效果是 #250 这八个微交互里唯一走降级形态 2 的**（同批的第九个入口
[`confetti`](confetti.md) 也走形态 2，但它是 #252 的）：**不叠透明度脉冲**，
保留原有的**淡入淡出**，只把上浮换成**静止位移**。理由：本效果的反馈本身就是
"淡入 → 上浮 → 淡出"，去掉上浮后仍留有完整的淡入淡出，再叠一次脉冲会变成**两次反馈**。

⚠️ **真分支是 `-reach * 0.5` 而不是 `0`**（#262 第 1 轮 review 曾要求归零，未采纳）：
这里是**常量**位移，`isReduced` 为真时它每一帧都相同 ⇒ 屏幕上**不产生任何运动**，
FR-11 约束的是运动而非静态摆位。而 `.overlay(alignment: .top)` 下 `offset 0` 恰好把
这段文字**压在被修饰内容的顶部** ⇒ 归零反而让开启 Reduce Motion 的用户读到一段与
数字重叠的 "+1"，是可读性回退，不是无障碍改进。

⚠️ **形态 2 的门禁是集中豁免名单，不是文件内标记**：`Rise.swift` 列在
`MicroInteractionReduceMotionGuard.approvedFormTwo` 上，并由 `formTwoListMatchesReality`
做**双向差集**——名单里有而文件没走形态 2、或文件走了形态 2 而不在名单里，两个方向
都判红。文件里那行 `// RM-FORM-2:` 只是给人读的理由说明，**不构成放行条件**
（守卫的 `stripComments` 会先把行注释整段剥掉）。

## a11y 分工（FR-13）

⚠️ 浮起的这段文字**按装饰层处理**：`accessibilityHidden(true)` + `allowsHitTesting(false)`。

⚠️ **VoiceOver 读不到这个 "+1"** —— 这是有意的（#262 终审 I4）：权威数值应放在**被修饰
的视图**上，那这段文字对 VO 就是**冗余**；且 overlay 常驻视图树（首尾 opacity 0），
不隐藏会在 VO 滑动顺序里留下一个幽灵元素。

⇒ 与 `.shake` / `.jump` 对齐：**通告由调用方负责**——调用方应把权威数值放在被修饰
视图的 `accessibilityValue` 上，或发 `AccessibilityNotification.Announcement`。

## 使用示例 / Usage

⚠️ 本节示例**没有任何机器校验**（同 [`confetti.md`](confetti.md) 记的限度）。

```swift
import CoreDesignEffects
import SwiftUI

struct ScoreView: View {
    @State private var score = 0

    var body: some View {
        VStack(spacing: 40) {
            Text("\(score)")
                .font(.largeTitle.bold().monospacedDigit())
                .rise(trigger: score, text: "+1")
                // 浮起的 "+1" 对 VoiceOver 隐藏 —— 权威数值在这里。
                .accessibilityLabel("得分")
                .accessibilityValue("\(score)")
            Button("加分") { score += 1 }
        }
    }
}
```

## 相关

- [`jump.md`](jump.md) —— 同一时机的另一种表达（元素本身跳一下）
- [`spray.md`](spray.md) / [`confetti.md`](confetti.md) —— 更外向的粒子形态
- [`shake.md`](shake.md) —— `MicroInteractionStrength` 与 `nonisolated` 的完整说明在那边
