# confetti

任务完成时喷发一次彩纸 / A one-shot confetti burst on completion.

`View.confetti(trigger:strength:colors:)`（`CoreDesignEffects/Confetti.swift`，Issue #252）。

⚠️ **本 API 在 `CoreDesignEffects` 里，不在 `CoreDesign`**：

```swift
import CoreDesignEffects
```

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| trigger | `some Equatable` | - | 值**变化**时喷发一次。首次出现（初始值）**不**喷 |
| strength | `MicroInteractionStrength` | `.regular` | 彩纸数量档位，与其余八个微交互共用同一枚举 |
| colors | `[Color]` | `[]` | 取色池，按下标轮转。**空数组 ⇒ 全部取调用方的 `.tint`** |

### 取色（FR-8）

⚠️ **不自带彩虹色板**——那是品牌决定，不是设计系统该替调用方做的。
颜色只有三个合法来源：调用方参数 / `.tint` / 语义 token。默认走 `.tint`：

```swift
CheckoutSummary()
    .confetti(trigger: order.paidCount)
    .tint(.pink)          // 彩纸变粉
```

⚠️ 空色板**回落 `.tint` 而不是 `Color.accent`**：后者不跟随逐视图 `.tint(_:)`，
调用方的 `.tint(.pink)` 会静默失效。取色函数与 `.spray` 是同一个
（`[Color].particleStyle(at:)`），两处不会各自漂移。

## Reduce Motion

⚠️ **不是 no-op**。开启「减弱动态效果」时**不播放粒子**，降级为
**一次淡入淡出的静态庆祝层**——把同一套彩纸图形钉在一个固定相位上，整层淡入、停留、淡出。

庆祝本身承载「这件事成了」这个信息，直接抹掉会让开启该偏好的用户收不到反馈。
本效果走的是共享降级**形态 2**（保留"长什么样"、去掉运动，**不再叠透明度脉冲**——
静态层本身就是一次淡入淡出，叠脉冲就是两次反馈）。

## 后台与低电量（NFR-7）

两个信号都做成了**可注入的 `EnvironmentValues`**（默认从系统读）：

| 键 | 类型 | 默认 | 行为 |
|---|---|---|---|
| `\.effectsScenePhase` | `ScenePhase?` | `nil` ⇒ 读系统 `\.scenePhase` | `.inactive` / `.background` ⇒ 彩纸层**不绘制** |
| `\.effectsPowerMode` | `EffectsPowerMode?` | `nil` ⇒ 读 `ProcessInfo.isLowPowerModeEnabled` | `.lowPower` ⇒ 降到 15 fps、彩纸数减半 |

```swift
// 宿主自己订阅 NSProcessInfoPowerStateDidChange 后可主动注入：
ContentView().environment(\.effectsPowerMode, .lowPower)
```

⚠️ **状态机挂在能耗闸之外**：进后台只是不画，`burst` 的计时照走——否则回到前台会
重放一次已经结束的庆祝。

### burst 结束后没有常驻调度

驱动彩纸的是 `TimelineView(.animation)`（不是 `Timer` / `CADisplayLink`）。
burst 起始时刻存在 `@State var burstStart: Date?` 里，`ConfettiBurst.duration`（2 s）之后
被清成 `nil`，**整个 `TimelineView` 分支随之从视图树里消失**——不是"建了但 `paused: true`"。

⚠️ 已知覆盖限度：`ImageRenderer` 拍的是静态帧、`.task` 在单测里不跑，
"两秒后那个节点真的消失了"**没有**端到端的机器判据。机器守住的是三段结构
（全文件只有一处 `TimelineView(`、它只在 `burstStart` 非空时被构造、状态机等的是
`ConfettiBurst.duration` 且随后清空）加上"没有 burst 时与裸视图逐字节相同"的渲染判据。

## a11y 分工（FR-13）

彩纸层是**纯装饰**，已 `accessibilityHidden(true)`、`allowsHitTesting(false)`。

⚠️ **「任务完成」这个语义由调用方通告**——本 modifier 不知道被修饰的是什么。
调用方应自行 `AccessibilityNotification.Announcement` 或更新相关元素的
`accessibilityLabel` / `accessibilityValue`。

## 使用示例 / Usage

```swift
import CoreDesign
import CoreDesignEffects
import SwiftUI

struct GoalView: View {
    @State private var completed = 0

    var body: some View {
        VStack(spacing: CoreSpacing.xl) {
            Text("\(completed) / 5")
            Button("完成一项") { completed += 1 }
        }
        .confetti(trigger: completed, strength: .pronounced)
        .tint(.accent)
    }
}
```

## 相关

- [`.spray`](../../Sources/CoreDesignEffects/Spray.swift) —— 同族的粒子效果，规模更小、贴着被点的元素
- [`scanning-overlay.md`](scanning-overlay.md) / [`glow-sweep.md`](glow-sweep.md) / [`light-sweep.md`](light-sweep.md) —— 同批落地的三个"处理中"常驻效果，共用同一套 NFR-7 能耗键
