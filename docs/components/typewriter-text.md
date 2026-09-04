# TypewriterText

逐字揭示的打字机文本 / Text revealed one grapheme at a time.

`TypewriterText`（`CoreDesignEffects/TypewriterText.swift`，Issue #253）。**容器视图形态**
（一个独立的 `View`，不是 modifier）。

```swift
import CoreDesign        // 下面示例里的 token 来自 `CoreDesign`
import CoreDesignEffects
```

⚠️ **两个 import 一个都不能少**：全仓 `@_exported` 为 0，`CoreDesignEffects` 不会把
`CoreDesign` 的符号带出来。只写一个，下面的示例照抄进项目**编译不过**。

## API

```swift
public struct TypewriterText: View {
    public init(_ text: LocalizedStringResource, speed: TypewriterSpeed = .regular)
    public init(verbatim text: String, speed: TypewriterSpeed = .regular)
}

public nonisolated enum TypewriterSpeed: Sendable, CaseIterable {
    case slow, regular, fast
    public var secondsPerCharacter: Double { get }
}
```

## 两个 init 的分工（公约 §4 文案三分法）

| init | 公约类别 | 用于 |
|---|---|---|
| `init(_:speed:)`（`LocalizedStringResource`） | **B 类**：调用方传入的界面文案 | 标题、引导语 |
| `init(verbatim:speed:)`（`String`） | **C 类**：运行期动态内容，不存在编译期本地化键 | AI 流式输出、用户输入回显 |

⚠️ **B 类这一条用 `LocalizedStringResource` 而不是公约第 4 节裁决的 `LocalizedStringKey`**
（`.rise(text:)` 正是按那条落的），这是一条**成文例外**，理由是结构性的：
打字机要按**字素簇**切前缀，而 SwiftUI **没有**把 `LocalizedStringKey` 解析成 `String`
的公开 API；`LocalizedStringResource` 有（`String(localized:)`）。
FR-7 自身写的是「`LocalizedStringResource` / `LocalizedStringKey`」**二选一**，两者都合规。

⚠️ 顺带一条**行为差异**：`LocalizedStringResource` 的字面量走 `init(stringLiteral:)`，
其 bundle 同样是 `Bundle.main`；但调用方**可以**显式写 `bundle:` 指向自己的 `.module`
——LSK 做不到。⇒ 对来自另一个 package 的调用方，本组件比 `.rise(text:)` 好用。

## 速度

三档语义值（**不暴露"每字多少毫秒"这类裸数值**，与 `MicroInteractionStrength` 同一条调参纪律）：

| 档 | 每字间隔 | 约合 |
|---|---|---|
| `.slow` | 0.075 s | 13 字 / 秒 |
| `.regular`（默认） | 0.040 s | 25 字 / 秒 |
| `.fast` | 0.018 s | 55 字 / 秒 |

## 布局不跳字

全文以 `.opacity(0)` 作**尺寸底稿**，可见前缀叠在 `overlay` 上 ⇒ 打字过程中行宽 / 行数
不变，也不会把下方布局推来推去。判据：
`TypewriterTextTests.revealedCountReachesRendering` 的「两张位图字节数必须相同」那一条。

## Reduce Motion

**直接显示完整文本**，且**不起打字计时器**。不是 no-op、也不是"打快一点"
——文本是内容，"打字"这个过程本身才是运动。

裁决点是纯函数 `TypewriterReveal.plan(total:typed:reduceMotion:)`，两条判据：
- `TypewriterTextTests.reduceMotionRevealsEverything`（函数体：给定 `true` 返回全文 + 不打字）；
- `TypewriterTextTests.reduceMotionIsOnlyConsumedByTheRevealGate`（调用点：`self.reduceMotion`
  的出现次数必须恰等于喂给闸的次数，且不得裸写）。

⚠️ **这两条缺一不可**：`\.accessibilityReduceMotion` 不可注入，位图路结构上不可达；
只有纯函数判据时，调用点把 `reduceMotion:` 换成字面量 `false` 仍然全绿。

## 后台 / 低电量（NFR-7）

⚠️ **本组件不接能耗闸，这是一条判定不是遗漏。** NFR-7 管的是**常驻渲染**的效果
（`Confetti` / `ScanningOverlay` / `AnimatedMeshGradient` 那一类持续调度的）。
打字机是**有限时长**的一次性揭示：打完就停，没有 `TimelineView`、没有常驻调度器。
另一半理由：能耗闸的 `.none` 语义是**一个像素都不画**，而本组件画的是**内容**。

## a11y

与装饰性效果（FR-13：`accessibilityHidden(true)`）**相反**：这里的文字是内容。
整块合成为一个元素、标签恒为**全文** ⇒ VoiceOver 一次读到全部，不会跟着动画读半句。

## 使用示例 / Usage

```swift
import CoreDesign
import CoreDesignEffects
import SwiftUI

struct OnboardingHeadline: View {
    let answer: String

    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.lg) {
            TypewriterText("Welcome aboard", speed: .slow)
                .font(.title.weight(.semibold))

            // AI 流式输出 —— 运行期内容，走 verbatim
            TypewriterText(verbatim: answer, speed: .fast)
                .font(.body)
                .foregroundStyle(Color.contentSecondary)
        }
    }
}
```

⚠️ **本文档的示例代码零机器覆盖**（与 `confetti.md` 同一条登记）：`import` 漏写、
API 改名、参数标签变更都不会让任何一条 CI 腿变红，只能人工发现。
