# spin

`trigger` 变化时整圈旋转一次 / One full rotation per trigger change.

`View.spin(trigger:direction:)`（`CoreDesignEffects/Spin.swift`，Issue #250）。
典型用途：刷新、重试、切换。

⚠️ **与 `CoreDesign` 的 `.spinning(_:text:presentation:)` 不是一回事**：那个是**持续**的加载遮罩
（material + 居中 `ProgressIndicator`，见 [`spinning.md`](spinning.md)），
本效果是 `trigger` 驱动的**一次性**旋转。

⚠️ **本 API 在 `CoreDesignEffects` 里，不在 `CoreDesign`**：

```swift
import CoreDesignEffects
```

## API

```swift
public nonisolated enum SpinDirection: Sendable, CaseIterable {
    case clockwise, counterClockwise
}

public extension View {

    func spin(
        trigger: some Equatable,
        direction: SpinDirection = .clockwise
    ) -> some View
}
```

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| trigger | `some Equatable` | - | 值**变化**时转一圈。首次出现（初始值）**不**转 |
| direction | `SpinDirection` | `.clockwise` | 方向。**没有** `strength` 参数——整圈就是整圈 |

轨道是单个 `CubicKeyframe(360 * direction.sign, duration: 0.55)`。

### `SpinDirection` 与 `nonisolated`

⚠️ **不用 `Bool`**（J-1 禁未豁免 Bool 参数）——`clockwise: true` 在调用处读不出含义，
语义枚举可以。

⚠️⚠️ **`nonisolated` 是承重的、不是装饰**：本 target 开了
`.defaultIsolation(MainActor.self)`，不标它则 `SpinDirection` 的 `Equatable` /
`CaseIterable` 一致性都是 MainActor 隔离的，下游从 nonisolated 上下文写
`direction == .clockwise` 会拿到**硬 error**
（`main actor-isolated conformance of 'SpinDirection' to 'Equatable' cannot be used
in nonisolated context [#IsolatedConformances]`），不是 warning。

⚠️ **这条只由 `scripts/downstream-probe` 钉住**——判据是
`EffectsNonisolatedUsage.swift` 的 `readSpinDirections()`。本库自己的
`swift build` / `swift test` **看不见它**（都跑在被隔离的 target 内部）。
⚠️ 且 `SpinDirection` **不只服务 `.spin`**：`Transition.clock(direction:)`（#268）
的实参也是它，摘掉 `nonisolated` 会同时打断两个 API 单位的下游配置层。

枚举内部的 `sign` 也标了 `nonisolated`，且刻意用 `switch` 而不是 `self == .clockwise`
——同一个 `#IsolatedConformances` 原因。

### 终帧取模不是多余的

`SpinTurn.angle(turns:isReduced:)` 对轨道取值做了
`.truncatingRemainder(dividingBy: 360)`。⚠️ **这不是防御性代码**（第 5 轮终审 C5-1，
评审用活体 `NSHostingView` 探针实测）：`keyframeAnimator` 动画结束后**停在最后一个
keyframe 值，不回 `initialValue`**，而 `rotationEffect(.degrees(360))` **不是恒等变换**
——实测 `Text("x")` 上残留 33/112 px 差异（maxΔ 24/255）、`Text("Refresh")` 上 35 px
⇒ 任何 `Text(...).spin()` 在第一次转完之后字形边缘会永久带上约 9% 的重采样软化。
取模后终态是 `rotationEffect(0)`（实测恒等），而 360° ≡ 0° 视觉无跳变。

判据是 `MicroInteractionAPITests.terminalFrameIsIdentity`：用 `KeyframeTimeline` 对
**生产代码里那条真轨道**求 `value(time: duration)`，再喂给**真取角函数**，
最后把结果角度渲染出来与裸视图逐字节比。

## 取色（FR-8）

不适用——本 modifier 不绘制任何新图层、没有颜色参数，只对被修饰内容做旋转。

## Reduce Motion

⚠️ **不是 no-op**。走共享降级**形态 1**：`SpinTurn.angle(turns:isReduced:)` 在
`isReduced` 为真时把转角取成 0（门控在取角函数里，不是在 `body` 里写字面量），
链尾再调 `reduceMotionFallback` 换成一次透明度脉冲
（`1.0 → 0.45 → 1.0`，`.easeInOut(duration: 0.12)`）。

## a11y 分工（FR-13）

本效果不新增任何图层，因此没有可以 `accessibilityHidden(true)` 的对象。

⚠️ 旋转承载状态语义（"刷新已开始 / 已完成"），对 VoiceOver 用户不可见
⇒ **通告由调用方负责**：调用方须自行 `accessibilityLabel` /
`AccessibilityNotification.Announcement`。

⚠️ **如实说明这条的来源**：`Spin.swift` 的入口注释里**没有**像 `.shake` / `.jump`
那样写下这句（源码里只在 `.shake` / `.jump` / `.ping` / `.spray` / `.rise` / `.shine`
上有 FR-13 注释）。上面这条是按 FR-13 与同族约定归类的——本效果既然不产生装饰层，
就只可能落在"调用方通告"这一侧，但它在源码里不是逐字写着的。

## 使用示例 / Usage

⚠️ 本节示例**没有任何机器校验**（同 [`confetti.md`](confetti.md) 记的限度）。

```swift
import CoreDesignEffects
import SwiftUI

struct RefreshButton: View {
    @State private var reloads = 0

    var body: some View {
        Button {
            reloads += 1
        } label: {
            Image(systemName: "arrow.clockwise")
                .spin(trigger: reloads)
        }
        .accessibilityLabel("刷新")
    }
}
```

## 相关

- [`spinning.md`](spinning.md) —— `CoreDesign` 的**持续**加载遮罩，与本效果同名不同物
- [`shake.md`](shake.md) / [`jump.md`](jump.md) —— 同族的形态 1 降级微交互
- [`haptic.md`](haptic.md) —— 刷新触发时常一并给一次触感
