# jump

下蹲 → 起跳 → 落地，带挤压拉伸 / A squash-and-stretch hop on trigger.

`View.jump(trigger:strength:)`（`CoreDesignEffects/Jump.swift`，Issue #250）。
典型用途：成功、点赞、达成。

⚠️ **本 API 在 `CoreDesignEffects` 里，不在 `CoreDesign`**：

```swift
import CoreDesignEffects
```

## API

```swift
public extension View {

    func jump(
        trigger: some Equatable,
        strength: MicroInteractionStrength = .regular
    ) -> some View
}
```

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| trigger | `some Equatable` | - | 值**变化**时跳一次。首次出现（初始值）**不**跳 |
| strength | `MicroInteractionStrength` | `.regular` | 同时缩放位移与形变量 |

本效果**同时**读档位的两条轴：`displacement`（4 / 9 / 16 pt）驱动纵向位移，
`scaleDelta`（0.06 / 0.14 / 0.24）驱动挤压拉伸。

### 相位

⚠️ 用具名枚举而不是 `[CGFloat]`——挤压与位移**不同步**（下蹲时压扁、腾空时拉长），
两条轨道各自取值才写得清楚（源码里的 `private enum Phase`）：

| 相位 | 纵向位移（× `displacement`） | 挤压 (x, y)（× `scaleDelta`） | 动画 |
|---|---|---|---|
| `rest` | 0 | (0, 0) | `.easeInOut(duration: 0.12)` |
| `squat` | +0.18 | (0.5, −0.5) 压扁 | 同上 |
| `launch` | −0.55 | (−0.35, 0.35) 拉长 | 同上 |
| `apex` | −1.0 | (0, 0) | `.easeOut(duration: 0.18)` |
| `land` | 0 | (0.3, −0.3) 再压一下 | `.spring(duration: 0.28, bounce: 0.45)` |

缩放锚点是 `.bottom`（脚不离地）。

### `MicroInteractionStrength` 与 `nonisolated`

`MicroInteractionStrength` 是 `public nonisolated enum`。⚠️ **`nonisolated` 是承重的**
——理由、报错原文与判据见 [`shake.md`](shake.md#microinteractionstrength-与-nonisolated)；
一句话版：它只由 `scripts/downstream-probe` 钉住，本库的 `swift build` / `swift test`
摘掉它照样全绿。

## 取色（FR-8）

不适用——本 modifier 不绘制任何新图层、没有颜色参数，只对被修饰内容做位移与缩放。

## Reduce Motion

⚠️ **不是 no-op**。走共享降级**形态 1**：位移与缩放**逐表达式门控**，链尾再调
`reduceMotionFallback` 换成一次透明度脉冲（`1.0 → 0.45 → 1.0`，
`.easeInOut(duration: 0.12)`）。

⚠️ **缩放也必须被门控**（#262 终审 C1）：FR-11 逐字写的是「含位移 / 旋转 / **缩放**
的效果」。初版只门控了 `offset`，结果 Reduce Motion 下用户同时收到"压扁-拉长-再压扁"
的形变**和**降级用的透明度脉冲——两份反馈都在。现在
`scaleEffect(x: isReduced ? 1 : …, y: isReduced ? 1 : …)` 与
`offset(y: isReduced ? 0 : …)` 两处都门控。

## a11y 分工（FR-13）

本效果不新增任何图层，因此没有可以 `accessibilityHidden(true)` 的对象。

⚠️ 源码入口注释逐字写的是：**承载状态语义时（如"已完成"）a11y 通告由调用方负责**
（FR-13）。跳跃对 VoiceOver 用户不可见，本 modifier **不会**替你播报——
调用方须自行 `accessibilityLabel` / `accessibilityValue` /
`AccessibilityNotification.Announcement`。

## 使用示例 / Usage

⚠️ 本节示例**没有任何机器校验**（同 [`confetti.md`](confetti.md) 记的限度）。

```swift
import CoreDesignEffects
import SwiftUI

struct TaskRow: View {
    @State private var completions = 0

    var body: some View {
        Image(systemName: "checkmark.seal.fill")
            .font(.system(size: 44))
            .jump(trigger: completions, strength: .pronounced)
            .accessibilityLabel("已完成 \(completions) 项")
        Button("完成一项") { completions += 1 }
    }
}
```

## 相关

- [`shake.md`](shake.md) —— 同族的位移反馈，表达"错了"而不是"成了"
- [`spray.md`](spray.md) / [`confetti.md`](confetti.md) —— 更外向的庆祝形态，会画装饰层
- [`haptic.md`](haptic.md) —— 常与本效果叠加：跳一下 + 一次 `.success` 触感
- [`rise.md`](rise.md) —— "+1" 上浮，同样表达"刚得分"
