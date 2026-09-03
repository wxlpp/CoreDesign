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
| `\.scenePhaseOverride` | `ScenePhase?` | `nil` ⇒ 读系统 `\.scenePhase` | `.inactive` / `.background` ⇒ 彩纸层**不绘制**（含 Reduce Motion 路径，见下） |
| `\.lowPowerModeOverride` | `Bool?` | `nil` ⇒ 读 `ProcessInfo.isLowPowerModeEnabled` | `true` ⇒ 降到 15 fps、彩纸数减半 |

⚠️ **注入的默认值是 `nil`（＝"没有人注入"），不是 `false`**：`nil` 时才会去读
`ProcessInfo`；注入 `false` 的语义是宿主明确说"按常规供电渲染"，不该被系统读数覆盖。

⚠️ **这两个键住在 `CoreDesign`，不在 `CoreDesignEffects`**（PR #269 终审 S-2 的裁决）：
它们是任何常驻渲染件都要的通用能耗信号，`shipswift-shaders` 的 `colorEffect` 背景同样按它们
降级——键留在 Effects 会逼「只想要 shader 的消费者」链上整个 Effects product。
⇒ 只想注入这两个键的宿主 `import CoreDesign` 就够。低电量键的类型也因此是**通用的 `Bool?`**
（它是 `ProcessInfo.processInfo.isLowPowerModeEnabled` 的可注入镜像），
动效层的语义档位 `EffectsPowerMode` 是 `CoreDesignEffects` 在它上面自己包的一层。

### 宿主主动注入的完整配方

⚠️ **别照抄 `ContentView().environment(\.lowPowerModeOverride, true)`**——那是**永久锁定
低电量**，不是"跟随系统"。这个键存在的第二个理由（第一个是可测）是让宿主拿回**响应性**：
`EnvironmentValues` 的默认值只在被读取时求值一次，不会因为
`NSProcessInfoPowerStateDidChange` 而让视图失效。要"用户中途打开低电量模式就立刻降级"，
宿主得自己订阅那条通知：

```swift
import CoreDesign
import Foundation
import SwiftUI

struct RootView: View {
    @State private var isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

    var body: some View {
        ContentView()
            .environment(\.lowPowerModeOverride, self.isLowPower)
            .onReceive(
                NotificationCenter.default.publisher(
                    for: .NSProcessInfoPowerStateDidChange
                )
            ) { _ in
                self.isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
    }
}
```

⚠️ 初值直接读一遍 `ProcessInfo`（＝当次启动时的真实状态），之后每收到一次通知重读一次。
不订阅通知就别注入这个键——留 `nil` 走默认路径反而更对。

⚠️ 已知不对称（本 PR 登记，未处置）：`usesGlow` 是在 `TimelineView` 闭包内**每帧**重解析的，
所以即便不注入这个键它也会跟着系统变；而 `minimumInterval`（帧率）与彩纸数由外层求一次，
不注入就不会中途改变。详见 `ProcessingSweepBody` 的类型文档。

⚠️ **两道闸的顺序是承重的：能耗闸在 Reduce Motion 闸之前**。也就是说
「后台 / 非活跃 ⇒ 一个像素都不画」对**开启了「减弱动态效果」的用户同样成立**——
静态庆祝层在这种状态下同样整层不建（PR #269 第 1 轮修的正是这条：此前顺序反了，
RM 开启时两个能耗键对 Confetti 完全无效）。裁决抽在
`EffectsEnergyState.presentation(reduceMotion:)` 一个纯函数里，
与三个"处理中"效果**共用同一份**，判据是
`EffectsEnergyStateTests.energyGateOutranksReduceMotion`。

⚠️ **状态机挂在能耗闸之外**：进后台只是不画，`burst` 的计时照走——否则回到前台会
重放一次已经结束的庆祝。

### burst 结束后没有常驻调度

驱动彩纸的是 `TimelineView(.animation)`（不是 `Timer` / `CADisplayLink`）。
burst 起始时刻存在 `@State var burstStart: Date?` 里，`ConfettiBurst.duration`（2 s）之后
被清成 `nil`，**整个 `TimelineView` 分支随之从视图树里消失**——不是"建了但 `paused: true`"。

⚠️ 已知覆盖限度：`ImageRenderer` 拍的是静态帧，"两秒后那个节点真的消失了"**没有**
端到端的机器判据（`.task` 在 macOS 的 `ImageRenderer` 下不跑；iOS Simulator 下会被调度，
但落点不确定，拿它当判据只会得到一条随机判红的测试）。机器守住的是三段结构
（全文件只有一处 `TimelineView(`、它只在 `burstStart` 非空且两道闸裁出 `.animated` 时
被构造、状态机等的是 `ConfettiBurst.duration` 且随后清空），加上两条渲染判据：
"没有 burst 时与裸视图逐字节相同"，以及"burst 早已结束的那一帧与空基线逐字节相同"。

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
