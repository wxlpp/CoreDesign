# ping

从视图背后扩散的同心圆环 / Concentric rings radiating from behind the view.

`View.ping(trigger:strength:color:)`（`CoreDesignEffects/Ping.swift`，Issue #250）。
典型用途：新消息、实时状态、位置定位。

⚠️ **本 API 在 `CoreDesignEffects` 里，不在 `CoreDesign`**：

```swift
import CoreDesignEffects
```

## API

```swift
public extension View {

    func ping(
        trigger: some Equatable,
        strength: MicroInteractionStrength = .regular,
        color: Color = .accent
    ) -> some View
}
```

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| trigger | `some Equatable` | - | 值**变化**时扩散一组环。首次出现（初始值）**不**放 |
| strength | `MicroInteractionStrength` | `.regular` | **环数**：`.subtle` 1 环 / `.regular` 2 环 / `.pronounced` 3 环 |
| color | `Color` | `.accent` | 环色（第 3 层语义 token） |

⚠️ 本效果的 `strength` **不走** `particleCount`，而是在 `body` 里直接按档位取 1 / 2 / 3
——它画的是环，不是粒子。环放在 `.background { }` 里（在内容**背后**），
描边宽度取 `CoreBorderWidth.thin`。

每一环延迟 `0.16 s × index` 出发，形成"一圈追一圈"；缩放 `1.0 → 2.2`（0.7 s cubic），
透明度 `0 → 0.75`（0.05 s）`→ 0`（0.65 s cubic）——两条轨道时序不同，
必须各自成 `KeyframeTrack`。

### `MicroInteractionStrength` 与 `nonisolated`

`MicroInteractionStrength` 是 `public nonisolated enum`。⚠️ **`nonisolated` 是承重的**
——完整理由、报错原文与判据见
[`shake.md`](shake.md#microinteractionstrength-与-nonisolated)。一句话版：它只由
`scripts/downstream-probe`（`readMicroInteractionStrengths()`）钉住，本库自己的
`swift build` / `swift test` 摘掉它照样全绿。

## 取色（FR-8）

环色走**调用方参数**，默认 `Color.accent`（第 3 层语义 token）——FR-8 的三个合法来源
里占两个。

⚠️ **这里与 shader 不同，本可以走 `.tint`**（`strokeBorder(.tint)`），但那样调用方就
无法单独调环色而不影响内容色 ⇒ 仍取参数、默认语义 token（源码入口注释逐字记着这条裁决）。

```swift
import CoreDesign        // `Color.statusSuccessForeground` 来自这里
import CoreDesignEffects

StatusDot()
    .ping(trigger: unreadCount, color: .statusSuccessForeground)
```

⚠️ **两个 import 一个都不能少**：全仓 `@_exported` 为 0，`CoreDesignEffects` 不会把
`CoreDesign` 的符号带出来（默认实参 `.accent` 由库内部解析，不需要调用方 import；
**显式**写第 3 层 token 就需要）。

## Reduce Motion

⚠️ **不是 no-op**，且**不是逐处门控**——本效果走**早退**：
`guard !isReduced else { return AnyView(content.reduceMotionFallback(active: true, …)) }`，
Reduce Motion 下**整个环层根本不构建**，降级为一次透明度脉冲
（`1.0 → 0.45 → 1.0`，`.easeInOut(duration: 0.12)`）。

⚠️ **为什么必须早退**（#262 终审 I-1）：初版只门控了 `scaleEffect`、没门控 `.opacity`，
也没调 `reduceMotionFallback`。后果是 Reduce Motion + `.pronounced` 时三个环停在
scale 1（几何完全重合）、各自在 50 ms 内阶跃变亮再衰减 ⇒ **给 Reduce Motion 用户的
正是闪烁**，而被修饰的内容本身零反馈。现与 `.spray` / `.shine` 对齐走早退。

`Ping.swift` 在守卫 `MicroInteractionReduceMotionGuard.approvedEarlyExit` 的**集中
豁免名单**上（双向差集判据，名单与实际不一致即判红）。

## a11y 分工（FR-13）

环层是**纯装饰**，已 `accessibilityHidden(true)`、`allowsHitTesting(false)`。

⚠️ `allowsHitTesting(false)` **不是可有可无**（#262 终审 I-3）：`.background { }` 的
内容在 SwiftUI 里是可命中的，而 `scaleEffect` 是几何变换、**会影响命中测试**——
环放大到 2.2× 时描边区域伸出内容 frame 之外，在动画的约 0.7 s 内可以截走本该落到
相邻视图的点击。

⚠️ **「有新消息 / 状态变了」这个语义由调用方通告**——本 modifier 不知道被修饰的是什么。
调用方应自行 `AccessibilityNotification.Announcement`，或更新相关元素的
`accessibilityLabel` / `accessibilityValue`。

## 使用示例 / Usage

⚠️ 本节示例**没有任何机器校验**（同 [`confetti.md`](confetti.md) 记的限度）。

```swift
import CoreDesignEffects
import SwiftUI

struct NotificationBell: View {
    @State private var unread = 0

    var body: some View {
        Image(systemName: "bell.fill")
            .font(.system(size: 28))
            .ping(trigger: unread, strength: .pronounced)
            // 装饰层是隐藏的 —— 状态由这里通告。
            .accessibilityLabel("通知")
            .accessibilityValue("\(unread) 条未读")
    }
}
```

## 相关

- [`spray.md`](spray.md) / [`shine.md`](shine.md) —— 同批的另外两个早退式装饰层效果
- [`confetti.md`](confetti.md) —— 规模更大的一次性庆祝层
- [`shake.md`](shake.md) —— `MicroInteractionStrength` 与 `nonisolated` 的完整说明在那边
