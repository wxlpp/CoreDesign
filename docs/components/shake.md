# shake

输入校验失败时横向抖一下 / A damped horizontal shake on trigger.

`View.shake(trigger:strength:)`（`CoreDesignEffects/Shake.swift`，Issue #250）。

⚠️ **本 API 在 `CoreDesignEffects` 里，不在 `CoreDesign`**：

```swift
import CoreDesignEffects
```

## API

```swift
public extension View {

    func shake(
        trigger: some Equatable,
        strength: MicroInteractionStrength = .regular
    ) -> some View
}
```

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| trigger | `some Equatable` | - | 值**变化**时抖一次。首次出现（初始值）**不**抖 |
| strength | `MicroInteractionStrength` | `.regular` | 振幅档位，九个微交互共用同一枚举 |

⚠️ **`trigger` 刻意*不*约束 `Sendable`**（九个入口一致）：加上它会让
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` 的下游工程（Xcode 26 新建工程默认值）里，
任何 `enum Step: Equatable` 当 trigger 都报
`main actor-isolated conformance … cannot satisfy … 'Sendable'`。
泛型只停在内部的 `TriggerRelay`，动画 modifier 一律非泛型（只吃 `Int`）——
理由与实测记录见 `MicroInteractionSupport.swift` 的 `TriggerRelay` 文档。

### `MicroInteractionStrength` 与 `nonisolated`

```swift
public nonisolated enum MicroInteractionStrength: Sendable, CaseIterable {
    case subtle, regular, pronounced
}
```

本效果读它的 `displacement`（`.subtle` 4 pt / `.regular` 9 pt / `.pronounced` 16 pt）。

⚠️⚠️ **`nonisolated` 是承重的、不是装饰**：本 target 开了
`.defaultIsolation(MainActor.self)`，不标它则该枚举的 `Equatable` / `CaseIterable`
一致性都是 MainActor 隔离的，下游从 nonisolated 上下文写 `strength == .regular`
会拿到**硬 error**（`#IsolatedConformances`），不是 warning。

⚠️ **这条只由 `scripts/downstream-probe` 钉住**——判据是
`EffectsNonisolatedUsage.swift` 的 `readMicroInteractionStrengths()`。
本库自己的 `swift build` / `swift test` **看不见它**：两者全跑在被隔离的 target
**内部**，把 `nonisolated` 摘掉照样全绿。

## 取色（FR-8）

不适用——本 modifier 不绘制任何新图层、没有颜色参数，只对被修饰内容做位移。

## Reduce Motion

⚠️ **不是 no-op**。开启「减弱动态效果」时位移被逐表达式门控为 0
（`view.offset(x: isReduced ? 0 : offset)`），并在链尾调用 `reduceMotionFallback`
换成**一次透明度脉冲**（`1.0 → 0.45 → 1.0`，`.easeInOut(duration: 0.12)`）。

这是共享降级**形态 1**：抖动承载的是"这次输入错了"这个信息，直接抹掉会让开启该偏好的
用户收不到反馈 ⇒ 保留"有反馈"、去掉"有运动"（FR-11）。降级基线由
`MicroInteractionSupport.reduceMotionFallback(active:trigger:)` 统一提供，
各效果**不自建**降级路径。

## a11y 分工（FR-13）

⚠️ **本效果承载状态语义**（"这次输入错了"），**不是纯装饰**——它不新增任何图层，
因此也没有可以 `accessibilityHidden(true)` 的对象。

⚠️ **通告由调用方负责**：抖动对 VoiceOver 用户不可见，本 modifier **不会**替你播报。
调用方须自行 `accessibilityValue` / `AccessibilityNotification.Announcement`
（源码入口注释逐字写着这条）。

## 使用示例 / Usage

⚠️ 本节示例**没有任何机器校验**（与 [`confetti.md`](confetti.md) 记的是同一条限度）：
`import` 漏写、API 改名、参数标签变更都只能靠人工发现，CI 的任何一条腿都不会因此变红。
改动 `CoreDesignEffects` 公开 API 时需人工过一遍。

```swift
import CoreDesignEffects
import SwiftUI

struct PasscodeView: View {
    @State private var failedAttempts = 0
    @State private var code = ""

    var body: some View {
        SecureField("密码", text: $code)
            .shake(trigger: failedAttempts)
            // ⚠️ 状态语义由调用方通告 —— 抖动本身 VoiceOver 读不到。
            .accessibilityValue(failedAttempts > 0 ? "密码错误" : "")
    }
}
```

## 相关

- [`jump.md`](jump.md) —— 同族的位移 + 缩放反馈，表达"成了"而不是"错了"
- [`ping.md`](ping.md) / [`spray.md`](spray.md) —— 同批落地的装饰层效果，走早退式 Reduce Motion 降级
- [`haptic.md`](haptic.md) —— 常与本效果叠加：抖动 + 一次 `.error` 触感
- [`confetti.md`](confetti.md) —— 共用 `MicroInteractionStrength` 的第九个入口
