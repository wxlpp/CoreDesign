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

### ⚠️⚠️ 已知限度：本组件**不跟随 `\.locale` 环境**

（#253 PR #273 终审 I-4。上一版只用"性能"解释急切解析，**这个后果没有任何地方记**。）

文本在 `init` 里就用 `String(localized:)` 解析完，而 `String(localized:)` 按 **resource
自己的 locale**（默认进程 locale）查表，**不看 SwiftUI 的 `\.locale` 环境**：

```swift
TypewriterText("Welcome").environment(\.locale, .init(identifier: "fr"))  // ⚠️ 无效
Text("Welcome").rise().environment(\.locale, .init(identifier: "fr"))     // ✅ 有效（LSK）
```

换 locale 要**重建视图**（例如 `.id(locale)`）。⇒ 同一份 B 类文案，LSK 与 LSR 两条路的
locale 行为**不同**，这是上面那条"只有一种做得到"的例外附带的代价。

**为什么记而不改**：改成"存 LSR + 在 `body` 里按 `\.locale` 重解析"要每帧走一次查表
（急切解析的既有理由），且 `init(verbatim:)` 那条 C 类路径根本没有可重解析的 resource
⇒ 两条 init 会分岔成两种生命周期。本轮**登记为已知限度**；真要跟随环境 locale
属独立改动，届时两条 init 一起重设计。

## 速度

三档语义值（**不暴露"每字多少毫秒"这类裸数值**，与 `MicroInteractionStrength` 同一条调参纪律）：

| 档 | 每字间隔 | 约合 |
|---|---|---|
| `.slow` | 0.075 s | 13 字 / 秒 |
| `.regular`（默认） | 0.040 s | 25 字 / 秒 |
| `.fast` | 0.018 s | 55 字 / 秒 |

## 布局不跳字

全文以 `.opacity(0)` 作**尺寸底稿**，可见前缀叠在 `overlay` 上 ⇒ 打字过程中行宽 / 行数
不变，也不会把下方布局推来推去。

判据：`TypewriterTextTests.ghostSizingKeepsLayoutStable`——量 `ImageRenderer` 在
revealed=1 与 revealed=全文时的**布局尺寸**并断言相等，配一条"裸 `Text` 前缀与全文
尺寸必须不同"的互锁。

⚠️ **上一版这里引的是 `revealedCountReachesRendering` 的「两张位图字节数必须相同」，
那条结构性恒真**（#253 PR #273 终审 I-2）：位图是 `w*h*4` 的裸缓冲，而被测视图被
`.frame(220×40)` 钉死 ⇒ 字节数**永远**相等。终审实证：把整个尺寸底稿机制换成裸
`Text(verbatim: shown)`，那条判据 7/7 仍绿。⇒ 判据已换成量尺寸、且被测视图不套 `frame`。

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
