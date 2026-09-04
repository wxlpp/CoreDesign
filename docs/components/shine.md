# shine

一次性高光扫过，**遮罩到内容形状** / A one-shot specular sweep masked to the content.

两种形态，同一套实现（`CoreDesignEffects/Shine.swift`，Issue #250）：

- `View.shine(trigger:highlight:)` —— **「这件事刚发生」**，由 `trigger` 值变化驱动，
  可重复触发，与其余七个微交互同形态、可自由叠加。
- `Shine { }` —— **「这块内容刚出现」**，容器视图形态，出现时扫一次，无需调用方持有状态。
  ⚠️ 它是 #250 的 AC 里**唯一大写**的一项，大小写不是笔误、是形态。

⚠️ **本 API 在 `CoreDesignEffects` 里，不在 `CoreDesign`**：

```swift
import CoreDesignEffects
```

## API

```swift
public struct Shine<Content: View>: View {

    public init(
        highlight: Color = .specularHighlight,
        @ViewBuilder content: () -> Content
    )
}

public extension View {

    func shine(
        trigger: some Equatable,
        highlight: Color = .specularHighlight
    ) -> some View
}
```

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| trigger（modifier） | `some Equatable` | - | 值**变化**时扫一次。首次出现（初始值）**不**扫 |
| highlight | `Color` | `.specularHighlight` | 高光色（第 3 层 token） |

⚠️ **没有 `strength` 参数**——光带几何全部从内容尺寸推导：`travel = 宽 + 高`，
光带宽 `travel × 0.35`、倾角 28°，进度 `-1 → 1`（`LinearKeyframe(-1, 0.05)` +
`CubicKeyframe(1, 0.65)`），位移 `progress × travel` ⇒ 首尾两端光带都完全落在遮罩之外。

⚠️ **容器形态内部直接复用 `.shine(trigger:)`，没有第二套实现**——Reduce Motion 降级、
`.mask(content)` 的已知限度全部继承自它。这条由
`MicroInteractionACContractTests.shineContainerDelegatesToModifier` 钉住：容器体内
必须出现 `.shine(trigger:`，且不得出现 `keyframeAnimator(` / `phaseAnimator(` /
`LinearGradient(` / `.mask(`。⚠️ 它守的是一个真实风险——容器若自建一套高光，
三条 Reduce Motion 判据仍然全绿，但降级就只覆盖 modifier、不覆盖容器。

### 与 `nonisolated` 枚举的关系

本入口**不吃** `MicroInteractionStrength` / `SpinDirection`。那条 `nonisolated` 契约
（以及"它只由 `scripts/downstream-probe` 钉住、本库的 `swift build` / `swift test`
看不见"这件事）见
[`shake.md`](shake.md#microinteractionstrength-与-nonisolated) 与
[`spin.md`](spin.md#spindirection-与-nonisolated)。

## 已知限度：视图树实例化两次

⚠️⚠️ **本 modifier 会把被修饰内容的视图树实例化两次**（#262 第 3 轮终审 I-3，
评审用计数视图实测：裸视图 body 求值 1 次、加 `.shine()` 后 **2 次**）。成因是
`content` 同时被用作「被修饰视图」与「遮罩」——`.mask(content)`。

后果不只是性能：内容里**带副作用的 modifier 会跑两遍**（`onAppear` 打点、`task {}`、
`@FocusState` 自动聚焦）。而本模块鼓励叠加，
`view.haptic(.success, trigger: n).shine(trigger: n)` 会把 `sensoryFeedback`
一并复制进遮罩副本。

⇒ **不要把带副作用的 modifier 放在 `.shine()` 之内**，`Shine { }` 同样受此约束。

## 取色（FR-8）

高光色走**调用方参数**，默认 `Color.specularHighlight`（第 3 层 token，取值
`Color.white.opacity(0.45)`）。

⚠️ **该 token 固定为白、不随外观取反**：扫光是**光源反射**，明暗两端都应当比底下的
内容更亮。初版默认值是 `Color.contentPrimary.opacity(0.35)`，而 `contentPrimary`
就是 `.label`，浅色外观下近黑 ⇒ 浅色下扫过去的是一道 **35% 的黑带**。
`label` 保证的是「与背景**对比**」，**不是**「比背景**亮**」。

⚠️ **已知限度**：白高光遇到**浅色 / 近白内容**会看不见，而 `.mask(content)` 把高光裁在
内容形状内 ⇒ "内容本身是浅色"是常见场景而非边缘。这种场景调用方应**显式传 `highlight:`**。
（根治方向是把高光改成加性合成 `.plusLighter` / `.screen`，本轮未做，留作已知问题。）

## Reduce Motion

⚠️ **不是 no-op**，且**不是逐处门控**——本效果走**早退**：
`guard !isReduced else { return AnyView(content.reduceMotionFallback(active: true, …)) }`，
Reduce Motion 下**不画光带**，降级为一次透明度脉冲
（`1.0 → 0.45 → 1.0`，`.easeInOut(duration: 0.12)`）。

⚠️ **为什么不能只把光带停在界外**（#262 终审 I1）：初版正是那样，结果 Reduce Motion 下
**零反馈**，与本模块"降级不是什么都不做"的原则自相矛盾。

`Shine.swift` 在守卫 `MicroInteractionReduceMotionGuard.approvedEarlyExit` 的**集中
豁免名单**上（双向差集，名单与实际不一致即判红）。

## a11y 分工（FR-13）

高光层是**纯装饰**，已 `accessibilityHidden(true)`、`allowsHitTesting(false)`（源码逐字
注释 `// 纯装饰（FR-13）`）。

⚠️ **「解锁了 / 升级了 / 徽章点亮了」这个语义由调用方通告**——本 modifier 不知道被修饰
的是什么。调用方应自行 `AccessibilityNotification.Announcement`，或更新相关元素的
`accessibilityLabel` / `accessibilityValue`。

## 终帧必须扫出界

`keyframeAnimator` 动画结束后**停在最后一个 keyframe，不回 `initialValue`**
⇒ 终帧就是用户实际长期看到的那一帧，它必须也在界外（`ShineBand.terminalProgress == 1`）。

⚠️ 这不是理论顾虑：第 4 轮终审 C4-1 抓到的真 bug 正是 `initialValue` 直接写
`-travel`，而首次求值时 `GeometryReader` 的 `proxy.size` 还是 `.zero` ⇒ 初值固化成
**0** ⇒ **光带永久停在内容正上方**（实测 `PRO` 胶囊左缘常驻斜切、`star.fill` 整体被洗淡）。
修法是把 `initialValue` 换成**无量纲常量 −1**，`travel` 只在闭包内相乘。
判据是 `MicroInteractionTests.terminalFrameIsIdentity`（对真轨道求值 + 位图比对，
另有 `progress = 0` 的反向互锁）。

## 使用示例 / Usage

⚠️ 本节示例**没有任何机器校验**（同 [`confetti.md`](confetti.md) 记的限度）。

```swift
import CoreDesign        // `Color.accent` / `Color.contentOnAccent` 来自这里
import CoreDesignEffects
import SwiftUI

struct ProBadge: View {
    @State private var unlocked = 0

    var body: some View {
        Text("PRO")
            .font(.largeTitle.bold())
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(Color.accent, in: Capsule())
            .foregroundStyle(Color.contentOnAccent)
            .shine(trigger: unlocked)
            // 高光层是隐藏的 —— 语义由这里通告。
            .accessibilityLabel(unlocked > 0 ? "已解锁 PRO" : "PRO")
    }
}

// 容器形态：出现即扫一次，调用方不持有状态。
Shine {
    Text("PRO")
        .padding()
        .background(Color.accent, in: Capsule())
}
```

⚠️ **两个 import 一个都不能少**：全仓 `@_exported` 为 0，`CoreDesignEffects` 不会把
`CoreDesign` 的符号带出来。

## 相关

- [`skeleton.md`](skeleton.md) —— `.skeletonShimmer()` 是骨架屏的**持续**扫光，与本效果同族不同物
- [`light-sweep.md`](light-sweep.md) —— 常驻的"处理中"光带，同样是掠过表面
- [`ping.md`](ping.md) / [`spray.md`](spray.md) —— 同批的另外两个早退式装饰层效果
- [`haptic.md`](haptic.md) —— ⚠️ 不要放进 `.shine()` 之内，见《已知限度》
