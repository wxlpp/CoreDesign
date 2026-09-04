# spray

向上喷出一束 SF Symbol 粒子 / A cone of SF Symbol particles sprayed upward.

`View.spray(trigger:symbol:strength:colors:)`（`CoreDesignEffects/Spray.swift`，
Issue #250）。典型用途：点赞、收藏、庆祝。

⚠️ **本 API 在 `CoreDesignEffects` 里，不在 `CoreDesign`**：

```swift
import CoreDesignEffects
```

## API

```swift
public extension View {

    func spray(
        trigger: some Equatable,
        symbol: String,
        strength: MicroInteractionStrength = .regular,
        colors: [Color] = []
    ) -> some View
}
```

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| trigger | `some Equatable` | - | 值**变化**时喷一次。首次出现（初始值）**不**喷 |
| symbol | `String` | - | SF Symbol 名，粒子的图形 |
| strength | `MicroInteractionStrength` | `.regular` | 粒子数 6 / 12 / 22（`particleCount`）；射程基数 `displacement × 6` = 24 / 54 / 96 pt，每颗再乘一个 0.55–1.0 的确定性系数 |
| colors | `[Color]` | `[]` | 取色池，按下标轮转。**空数组 ⇒ 全部取调用方的 `.tint`** |

⚠️ **参数名是 `colors:` 而不是 `palette:`**——#250 的 AC 逐字写的是
`.spray(trigger:symbol:colors:)`。初版以「与 SwiftUI 渐变的 `colors:` 撞名但语义不同」
为由改了名，那不足以抵消**与自己的规格不一致**（#262 第 1 轮 review）。
现由 `MicroInteractionACContractTests.sprayEntrySignatureMatchesAC` 扫源码钉住。

粒子字号取 `CoreControlMetrics.iconSize(for: .mini)`；方向是以正上方为中心的锥形
（`-90° ± 35°`），每颗的角度与射程由 **index 派生的确定性伪随机**决定
——⚠️ **不用 `random`**，否则每次重绘粒子都会跳，且测试无法复现。

### `MicroInteractionStrength` 与 `nonisolated`

`MicroInteractionStrength` 是 `public nonisolated enum`。⚠️ **`nonisolated` 是承重的**
——完整理由与报错原文见
[`shake.md`](shake.md#microinteractionstrength-与-nonisolated)。一句话版：它只由
`scripts/downstream-probe`（`readMicroInteractionStrengths()`）钉住，本库自己的
`swift build` / `swift test` 摘掉它照样全绿。

⚠️ 另有一条与本效果直接相关的语义承诺：`particleCount` 恒 ≥ 1
（判据 `MicroInteractionStrengthTests.particleCountIsPositive`）——取 0 会让 spray
**静默什么都不画**。

## 取色（FR-8）

⚠️ **不给彩虹默认色板**——那是品牌决定，不是设计系统该替调用方做的。颜色只有三个
合法来源：调用方参数 / `.tint` / 语义 token。默认（空色板）走 `.tint`：

```swift
LikeButton()
    .spray(trigger: likes, symbol: "heart.fill")
    .tint(.pink)          // 粒子变粉
```

⚠️ 空色板**回落 `.tint` 而不是 `Color.accent`**：后者就是 `Color.accentColor`，
**不跟随逐视图 `.tint(_:)`** ⇒ 调用方的 `.tint(.pink)` 会静默失效。
（初版曾以「SwiftUI 无公开 API 把 `.tint` 解析成 `Color`」为由回退到 `Color.accent`
——那个前提是错的：粒子要的是 `ShapeStyle`，`.foregroundStyle(.tint)` 本来就成立。）

取色规则抽成了 `[Color].particleColor(at:)` / `particleStyle(at:)` 两个 internal 函数，
**为的是可被单测直接断言**——`.tint` 在静息位图上不可观测（粒子静息 `opacity` 为 0）。
判据是 `MicroInteractionACContractTests.sprayPaletteContract`：空 ⇒ `nil`（交给 `.tint`），
非空 ⇒ 按下标轮转。[`confetti`](confetti.md) 用的是**同一对函数**，两处不会各自漂移。

## Reduce Motion

⚠️ **不是 no-op**，且**不是逐处门控**——本效果走**早退**：
`guard !isReduced else { return AnyView(content.reduceMotionFallback(active: true, …)) }`，
Reduce Motion 下**整个粒子层不渲染**，降级为一次透明度脉冲
（`1.0 → 0.45 → 1.0`，`.easeInOut(duration: 0.12)`）。

⚠️ **为什么必须整层不渲染**（#262 终审 C2）：初版只把位移归零——结果 12–22 个粒子
**全堆在内容中心**并继续缩放淡出，一坨符号盖住内容，**比原动效更糟**。
缩放同样属于 FR-11 的"缩放"。

`Spray.swift` 在守卫 `MicroInteractionReduceMotionGuard.approvedEarlyExit` 的**集中
豁免名单**上（双向差集，名单与实际不一致即判红）。

## a11y 分工（FR-13）

粒子层是**纯装饰**，已 `accessibilityHidden(true)`、`allowsHitTesting(false)`。

⚠️ **「点赞成功」这个语义由调用方通告**（源码逐字）——本 modifier 不知道被修饰的是
什么。调用方应自行 `AccessibilityNotification.Announcement`，或更新相关元素的
`accessibilityLabel` / `accessibilityValue`。

## 使用示例 / Usage

⚠️ 本节示例**没有任何机器校验**（同 [`confetti.md`](confetti.md) 记的限度）。

```swift
import CoreDesignEffects
import SwiftUI

struct LikeButton: View {
    @State private var likes = 0

    var body: some View {
        Button {
            likes += 1
        } label: {
            Image(systemName: "heart.fill").font(.system(size: 32))
        }
        .buttonStyle(.plain)
        .spray(trigger: likes, symbol: "heart.fill", strength: .pronounced)
        .tint(.pink)
        // 装饰层是隐藏的 —— 语义由这里通告。
        .accessibilityLabel("点赞")
        .accessibilityValue("\(likes)")
    }
}
```

## 相关

- [`confetti.md`](confetti.md) —— 规模更大的一次性庆祝层，**共用同一对取色函数**
- [`ping.md`](ping.md) / [`shine.md`](shine.md) —— 同批的另外两个早退式装饰层效果
- [`rise.md`](rise.md) —— "+1" 上浮，同一时机的另一种表达
- [`shake.md`](shake.md) —— `MicroInteractionStrength` 与 `nonisolated` 的完整说明在那边
