# haptic

`trigger` 变化时播一次触感反馈 / Plays one haptic on trigger change.

`View.haptic(_:trigger:)`（`CoreDesignEffects/Haptic.swift`，Issue #250）。

⚠️ **本 API 在 `CoreDesignEffects` 里，不在 `CoreDesign`**：

```swift
import CoreDesignEffects
```

## API

```swift
public extension View {

    func haptic(
        _ feedback: SensoryFeedback,
        trigger: some Equatable
    ) -> some View
}
```

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `_ feedback` | `SensoryFeedback` | - | **SwiftUI 自己的**反馈类型，原样透传 |
| trigger | `some Equatable` | - | 值**变化**时播一次 |

⚠️ **本 API 没有 `strength` / `color` 参数**，也不接受 `MicroInteractionStrength`
——它的公开面就是上面这两行。

## 这是薄封装，不是重造

⚠️ **`body` 的全部内容是 `self.sensoryFeedback(feedback, trigger: trigger)`**
——一行透传，没有第二层逻辑。它**不做**去抖、不做节流、不做平台分支、不读
`accessibilityReduceMotion`、不参与本模块的 Reduce Motion 降级链。**别指望它做
`sensoryFeedback` 之外的任何事。**

存在的唯一理由是**可发现性**：其余七个微交互都在本模块，触感却要调用方去想起系统 API，
会导致「视觉反馈有、触感没有」的不一致。

⚠️ 反馈类型**原样透传 `SensoryFeedback`**，不自定义一套枚举——自定义会丢掉系统未来
新增的类型（对照 CLAUDE.md：`.core` style「换皮不重造控件」）。

⚠️ **模拟器里感知不到**：iOS Simulator 没有 Taptic Engine，`sensoryFeedback` 在模拟器
上不会产生任何可感知的反馈。验证触感必须上真机。
（这是平台事实、不是本库的行为——库这一侧只有那行透传，源码里也没有任何模拟器分支。）

### `trigger` 刻意不约束 `Sendable`

与其余七个入口**完全一致**（它们同样只写 `some Equatable`），不是本文件的例外。
加上 `Sendable` 会让 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` 的下游工程
（Xcode 26 新建工程的默认值）里，任何 `enum Step: Equatable` 当 trigger 都报
`main actor-isolated conformance … cannot satisfy … 'Sendable'`。
机器判据是 `MicroInteractionAPITests.triggerIsGeneric`——用一个 MainActor 隔离
conformance 的类型当 trigger，加约束即编译红。

### 与 `nonisolated` 枚举的关系

本入口**不吃** `MicroInteractionStrength` / `SpinDirection`，所以那条
`nonisolated` 契约与它无关。两个枚举为什么必须标 `nonisolated`、以及那条为什么
**只由 `scripts/downstream-probe` 钉住**（不是本库的 `swift build` / `swift test`），
见 [`shake.md`](shake.md#microinteractionstrength-与-nonisolated) 与
[`spin.md`](spin.md#spindirection-与-nonisolated)。

## 取色（FR-8）

不适用——本 modifier 不绘制任何东西，没有颜色面。

## Reduce Motion

⚠️ **本 modifier 不读 `accessibilityReduceMotion`，源码里没有任何降级分支**。
`Haptic.swift` 列在守卫的 `MicroInteractionReduceMotionGuard.approvedNoMotion`
名单上，理由逐字是「只有 `sensoryFeedback`，无视觉运动」——这是**分类**（本文件确认
不含视觉运动），不是降级。

⚠️ 触感是否随系统的辅助功能偏好变化，由 SwiftUI / 系统决定，**本库不介入**
——库这一侧只有那行透传。**本仓没有任何判据覆盖这一点**，也未实测过，
所以这里不给结论。

## a11y 分工（FR-13）

本 modifier **不新增任何视图层**，因此既没有可以 `accessibilityHidden(true)` 的对象，
也不会在 VoiceOver 滑动顺序里留下元素。

⚠️ 触感承载状态语义（"成了" / "错了"），而**触感不是通告**：VoiceOver 用户不会因为
一次震动就知道发生了什么 ⇒ **通告由调用方负责**，须自行
`AccessibilityNotification.Announcement` 或更新相关元素的 `accessibilityLabel` /
`accessibilityValue`。

⚠️ 这条与 `.shake` / `.jump` 同侧，但**在 `Haptic.swift` 里没有逐字写着**
（源码的 FR-13 注释在 `.shake` / `.jump` / `.ping` / `.spray` / `.rise` / `.shine` 上）
——这里是按 FR-13 归类的。

## 叠加时的一条已知坑

⚠️ **不要把 `.haptic` 放在 `.shine()` 之内**：`.shine()` 会把被修饰内容的视图树
**实例化两次**（`.mask(content)`），带副作用的 modifier 会跟着跑两遍——
`view.haptic(.success, trigger: n).shine(trigger: n)` 会把 `sensoryFeedback`
一并复制进遮罩副本。详见 [`shine.md`](shine.md#已知限度视图树实例化两次)。

## 使用示例 / Usage

⚠️ 本节示例**没有任何机器校验**（同 [`confetti.md`](confetti.md) 记的限度）。

```swift
import CoreDesignEffects
import SwiftUI

struct PurchaseButton: View {
    @State private var purchased = 0

    var body: some View {
        Button("购买") { purchased += 1 }
            .haptic(.success, trigger: purchased)
            // 触感不是通告 —— 状态由这里播报。
            .accessibilityValue(purchased > 0 ? "已购买" : "")
    }
}
```

## 相关

- [`shake.md`](shake.md) —— 常与 `.error` 触感叠加
- [`jump.md`](jump.md) —— 常与 `.success` 触感叠加
- [`shine.md`](shine.md) —— ⚠️ 叠加顺序有坑，见上一节
- [`confetti.md`](confetti.md) —— 同族的第九个 `trigger` 入口
