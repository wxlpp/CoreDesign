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

⚠️ **静态层没有自己的计时器**：它由 `ConfettiCore` 的 `burstStart` 驱动，自身是 `active`
的纯函数。上一版它自带 `@State` + `.task(id: fire)`，而那个分支会随 `scenePhase`
出现/消失 ⇒ 开启「减弱动态效果」的用户**每次从后台切回 App 都会重放一次庆祝**
（PR #269 第 2 轮修的正是这条）。

**停留时长按呈现档位取**（`ConfettiBurst.holdDuration(presentation:)`，`#272`）：
计时器仍然只有一个、仍然长在 `ConfettiCore` 上，只是它 sleep 多久由档位决定。

| 档位 | 停留终点 | 完全消失于 |
|---|---|---|
| **`.resting`**（Reduce Motion，静态层） | `staticHoldDuration = 1.2` | **1.55 s** |
| `.animated`（`ConfettiLayer`） | `ConfettiBurst.duration = 2.0` | 2.0 s |

⚠️ **喂给 `holdDuration` 的那个档位不是 `body` 里裁决「画什么」的那个**：它是
`EnergyState(scenePhase: .active, isLowPower: state.isLowPower).presentation(reduceMotion:)`
——**把 scenePhase 钉成 `.active` 再过一遍同一个共享闸**，于是它永远只会是 `.resting`
或 `.animated`，`.hidden` 落不到 `holdDuration` 上。理由见下方《为什么时长要避开能耗闸》。
⚠️ **`isLowPower` 今天不参与档位**：`presentation(reduceMotion:)` 只看
`policy.drawsAnything`，而那只看 `scenePhase == .active` ⇒ 这一行今天恒等于
`reduceMotion ? .resting : .animated`。传真实值而不是 `false`，只为「将来共享闸的口径变了
这里跟着变」——**不是**因为低电量影响时长。

**口径**：`staticFadeDuration = 0.35` 只挂在**静态层**的 `.opacity` 动画上；淡入那 0.35 s
与「停留」是**重叠**的（`.opacity` 从 0 动到 1 的同时停留计时已在走）⇒ 静态层完全消失
= 停留终点 + `staticFadeDuration`。⚠️ 停留终点**不是可见时长**——拿 `1.2` 直接当可见
时长会少算一次淡出。
⚠️ **动画层没有这一层**：`ConfettiLayer` 在 `burstStart` 转 `nil` 时**无过渡地**从
`if let` 分支移除，且 `ConfettiBurst.opacity` 在 `progress >= particle.lifetime`（≤ 1.0）
时已返回 0 ⇒ t = 2.0 时画面本就空了。**别把 2.35 s 记到它头上。**

#### 为什么时长要避开能耗闸

⚠️ **档位在 burst 起点一次定死，中途不重算**：`.task(id:)` 的语义是「`id` 变化时取消并
重启」，`id` 不变的后续 body 求值生成的新闭包**不会**被执行 ⇒ `hold` 取的是**点下去
那一刻**的档位。

⚠️⚠️ **上面这句只对「视图一直在场」的路径成立**（`#330` 更正）：`.task(id:)` 在**视图重新
出现**时**会**以**当前 id** 重跑——不只是 id 变化时。⇒ 被 disappear 打断的 burst 在
reappear 时走 `.resume` 续睡，而那一次用的是**重新求值的 body 捕获的 `holdPresentation`**
⇒ **隐藏期间用户切了 Reduce Motion，续睡时长按新档位取**，不是点下去那一刻的。
两条不冲突：**不重放**（`consumedFire` 记账）与**档位一次定死**是两件事，后者只在
不跨 appear 的那条路径上成立。判据：`ConfettiTests.burstDecisionCoversEveryState`。

若直接把 `body` 里那个带能耗闸的 `presentation` 喂给 `holdDuration`，就会出现这条坏形态：
burst 恰在 `.inactive` / `.background`（来电、通知横幅、切走再切回都会短暂经过）触发
⇒ 档位是 `.hidden` ⇒ `hold` 被定死成 2.0 s ⇒ 回到前台后若 Reduce Motion 开着，
静态层仍然到 **2.35 s** 才消失，正是本 issue 要修的那个数。
⇒ 时长走**把 scenePhase 钉成 `.active`** 的那一遍闸；能耗闸只管画不画，不管画多久。
这与本文件下方《状态机挂在能耗闸之外：进后台只是不画，burst 的计时照走》是同一条原则。

⚠️ **不能改成让 `holdDuration` 直接收 `reduceMotion:`**（那样 `.hidden` 也不必挑取值）：
`ReduceMotionGuard.reduceMotionIsOnlyConsumedByTheSharedGate` 要求走能耗闸的文件里
`self.reduceMotion` 出现几次就得有几次是喂给 `EnergyState.presentation(reduceMotion:)` 的，
且不许出现裸的 `reduceMotion` —— 实测那个写法当场判红。
⚠️ **但那条判据挡的是写法，不是「把闸再过一遍」**：上面这个形态里
`self.reduceMotion` 读 2 次、喂 2 次，判据全绿。

⚠️ **历史（别再走一遍）**：`#269` 把 RM 与正常路径合并进同一个状态机时删掉了
`staticHoldDuration`，静态层因此与 burst 共用 `duration`，完全消失时刻由 1.55 s 变成
2.35 s（**+52%**）。那是修 C-1 的副产品、不是裁决——对一个在系统设置里明确要求「减弱
动态效果」的用户，把纯装饰覆盖层的可见时长拉长一半与该设置的意图相反。`#272` 改回
1.55 s 的方式是上面那条：**不得**把计时器还给静态层——那正是「后台往返即重放」的成因。
给 `ConfettiStaticCelebration` 加一个 `@State` 会被 `confettiKeepsOneShapeAcrossScenePhase`
判红（变异实证见 PR 正文）。

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
（它是 `ProcessInfo.processInfo.isLowPowerModeEnabled` 的可注入镜像）。
⚠️ **`#271` 起由它们派生的通用策略表（`RenderPolicy` / `EnergyState` /
`MotionPresentation`）也在 `CoreDesign`**；此前这里说的「动效层的语义档位」是
`CoreDesignEffects` 里那个二态枚举，实测已无人读其 case、**已随 `#271` 删除**
（见 `docs/BREAKING-CHANGES.md`）。留在动效层的是 `usesGlow` / `particleScale` /
`frozenIfPeriodIsDegenerate(_:)` 三个 effects 专用旋钮。

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
不注入就不会中途改变。

⚠️ **两道闸的顺序是承重的：能耗闸在 Reduce Motion 闸之前**。也就是说
「后台 / 非活跃 ⇒ 一个像素都不画」对**开启了「减弱动态效果」的用户同样成立**——
静态庆祝层在这种状态下同样整层不建（PR #269 第 1 轮修的正是这条：此前顺序反了，
RM 开启时两个能耗键对 Confetti 完全无效）。裁决抽在
`EnergyState.presentation(reduceMotion:)` 一个纯函数里，
与三个"处理中"效果**共用同一份**，判据是
`EnergyPolicyTests.energyGateOutranksReduceMotion`。

⚠️ **状态机挂在能耗闸之外**：进后台只是不画，`burst` 的计时照走——否则回到前台会
重放一次已经结束的庆祝。

⚠️⚠️ 这句话此前**只在非 Reduce Motion 路径上成立**：那一版把 RM 分支写成
`guard !isReduced else { return AnyView(…) }`，于是 `body` 有两个出口，
**而出口的选择依赖 `scenePhase`**（RM 开启时 `.active ⇒ .resting ⇒ 出口 A`、
后台 `⇒ .none ⇒ 出口 B`）。出口 A 里根本没有那个 `.task`，两条后果：
RM 用户每次后台往返都重放一次庆祝；**被 `.confetti` 包住的整棵调用方子树**
随之换身份，里面的 `@State` / 动画 / `.task` 全部重置。
⇒ 现在 `body` 只有**一种形状**：`content` 与 `.task(id:)` 恒在，两道闸只决定
`overlay` 里画什么（`switch presentation`）。
判据 `ConfettiTests.confettiKeepsOneShapeAcrossScenePhase` 钉住这个形状
（`content` × 1、`.task(` × 1、`AnyView` × 0、`return` × 1，静态层不得自带
`@State` / `.task` / `fire`）——`\.accessibilityReduceMotion` 不可注入、
且"视图身份是否保持"本就不在一张静态位图里，源码结构是唯一可行的判据形态。

### burst 结束后没有常驻调度

驱动彩纸的是 `TimelineView(.animation)`（不是 `Timer` / `CADisplayLink`）。
burst 起始时刻存在 `@State var burstStart: Date?` 里，`ConfettiBurst.holdDuration(presentation:)`
之后被清成 `nil`（`TimelineView` 只在 Reduce Motion **关**的分支里构造 ⇒ 对它而言就是
`ConfettiBurst.duration` = 2 s），**整个 `TimelineView` 分支随之从视图树里消失**
——不是"建了但 `paused: true`"。

⚠️ 已知覆盖限度：`ImageRenderer` 拍的是静态帧，"两秒后那个节点真的消失了"**没有**
端到端的机器判据（`.task` 在 macOS 的 `ImageRenderer` 下不跑；iOS Simulator 下会被调度，
但落点不确定，拿它当判据只会得到一条随机判红的测试）。机器守住的是三段结构
（全文件只有一处 `TimelineView(`、它只在 `switch presentation` 的 `.animated` 分支里
对 `burstStart` 做 `if let` 时被构造、状态机等的是 `ConfettiBurst.holdDuration(presentation:)`
算出的那个 `hold` 且随后清空），
加上两条渲染判据：
"没有 burst 时与裸视图逐字节相同"，以及"burst 早已结束的那一帧与空基线逐字节相同"。

## a11y 分工（FR-13）

彩纸层是**纯装饰**，已 `accessibilityHidden(true)`、`allowsHitTesting(false)`。

⚠️ **「任务完成」这个语义由调用方通告**——本 modifier 不知道被修饰的是什么。
调用方应自行 `AccessibilityNotification.Announcement` 或更新相关元素的
`accessibilityLabel` / `accessibilityValue`。

## 使用示例 / Usage

⚠️ **本节（以及 `glow-sweep.md` / `light-sweep.md` / `scanning-overlay.md` 三份姊妹文档的
同名小节）的示例代码，当前没有任何机器校验**（PR #269 第 4 轮 S2-5）——
`import` 漏写、API 改名、参数标签变更都只能靠人工发现，`swift build` / `swift test` /
CI 的任何一条腿都不会因为它们过期而变红。第 4 轮修掉的正是两份文档缺 `import` 这类问题。

为什么不便机器化：这些示例是**片段**，要编译就得先补一层宿主脚手架（`struct … : View`
外壳 + 状态变量），而那层脚手架一旦写进测试 target，"被校验的"就变成脚手架而不是文档本身；
片段与脚手架之间还会各自漂移。`.build/` 里能看到一个
`__DocExampleCompileCheck.swift.o`——那是一次这样的尝试留下的**陈旧产物，
树里已经没有对应源文件**，别把它当成"其实有覆盖"的证据。
⇒ 现状按**人工**记账：改动 `CoreDesignEffects` 的公开 API 时，四份文档的示例需人工过一遍。

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
