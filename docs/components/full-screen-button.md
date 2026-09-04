# FullScreenButton

卡片放大成整屏的按钮 / A card that expands into a full-screen destination.

`FullScreenButton`（`CoreDesignEffects/FullScreenButton.swift`，Issue #254）。

```swift
import CoreDesign
import CoreDesignEffects
```

⚠️ **两个 import 一个都不能少**：全仓 `@_exported` 为 0。

## API

```swift
public struct FullScreenButton<Label: View, Destination: View>: View {
    public init(@ViewBuilder destination: @escaping () -> Destination,
                @ViewBuilder label: () -> Label)
}
```

```swift
NavigationStack {
    FullScreenButton {
        ArticleDetail(article)          // 目的地
    } label: {
        ArticleCard(article)            // collapsed 状态的卡片
    }
}
```

⚠️ **必须包在 `NavigationStack` 里**：它本体是一个 `NavigationLink`。不在导航容器里
时点击无效（SwiftUI 的既有行为，本件不另加断言——库代码对宿主结构抛断言就是让宿主
App crash）。

## 平台支持

⚠️⚠️ **AD-E 的四件里，这是唯一走「`#if` 隔离 + 文档标注」的一件**，
另外三件（`DotSphere` / `CharSphere` / `OrbitingLogos`）都是真跨平台重写。

| 平台 | 转场 | 其余行为 |
|---|---|---|
| iOS 26+ | `.navigationTransition(.zoom(sourceID:in:))` —— 几何匹配放大 | 完整 |
| macOS 26+ | **系统默认推入转场**（`.zoom` 在 macOS 上不可用） | 完整 |

`.zoom(sourceID:in:)` 在 macOS 上**编译不过**，不是"没效果"。实测错误逐字：

```
error: 'zoom(sourceID:in:)' is unavailable in macOS
note: 'zoom(sourceID:in:)' has been explicitly marked unavailable here
```

⇒ `#if os(iOS)` **只包住 `.navigationTransition(.zoom(...))` 那一行**。其余
（`NavigationLink`、`matchedTransitionSource(id:in:)`、按钮样式、a11y）两端完全一致——
`matchedTransitionSource` 本身在 macOS 上编译得过（实测），留着它是为了将来 Apple
补上 macOS 的 zoom 时只需删掉那道 `#if`。

⇒ **macOS 上本件仍然可用**：卡片照常可点、目的地照常推入，差别只在"放大"这一层观感。

判据：
- `PlatformSupportGuard.zoomIsFencedToIOS` —— `.zoom(` 只许出现在 `#if os(iOS)` 里，
  且 `public struct FullScreenButton` **不许**被条件编译整个吞掉
  （那样库照样编译得过，而 macOS 上这个公开类型整个消失，只有下游会红）；
- `PlatformSupportGuard.everyPlatformFenceHasAnElse` —— 每道平台围栏两端都要有代码；
- `PlatformSupportGuard.sourceIDHasASingleSource` —— `sourceID` 只许有一个来源。

### `sourceID` 不许跨泛型特化去取（Copilot #3930970767）

目的地侧此前写的是 `FullScreenButton<EmptyView, EmptyView>.sourceID`，它依赖
「泛型类型的静态成员是与泛型实参无关的常量计算属性」这个**隐含前提**。
Swift 的泛型静态成员是**按具体特化分开**的：一旦 `sourceID` 变成存储属性、或它的值
开始依赖 `Label` / `Destination`，label 侧与 destination 侧会拿到两个不同的 id
⇒ zoom 静默退化成普通 push，**编译不报错、测试不变红、无人发现**。
⇒ 改成 `FullScreenButtonDestination` 持有一个 `let sourceID: String`，由
`FullScreenButton` 传入；判据钉的是 `>.sourceID` 这个形态（任何特化后的静态访问）。

### ⚠️⚠️ 已知限度：zoom 转场**零运行期证据**

本仓在 macOS 上开发，`.zoom` 那条分支在 macOS 单测里**结构上不可达**：
`FullScreenTransitionPlanTests` 钉的是纯函数真值表、`zoomIsFencedToIOS` 钉的是围栏形态、
`CrossPlatformRenderTests.fullScreenButtonRenders` 只断言折叠态卡片非空白。
⇒ **"iOS 上 zoom 真的触发了"这件事目前只由"它能编译"背书**（PR #274 终审 S-6）。

需要人工在 iOS 模拟器上确认一次，并把结论写回本节：

1. 点开卡片是否**真的**几何放大成整屏（而不是普通 push）；
2. `.matchedTransitionSource(id:in:)` 施加在 `NavigationLink` **label 构建器内部**的
   `self.label` 上是否生效。
   ⚠️ **这一条已按 Apple 文档核对过**：官方示例的形态逐字就是
   `NavigationLink { Detail().navigationTransition(.zoom(sourceID:in:)) } label: { Image(...).matchedTransitionSource(id:in:) }`
   ——修饰符加在 **label 内容上**，与本件一致。所以它不是偏离，但仍缺一次运行期确认。

若 (1) 不成立，本件在 iOS 上会静默退化成普通 push，而**全套判据仍然绿**。

## Reduce Motion

`.zoom` 是一次几何放大（卡片长到整屏），正是 FR-11 要去掉的那类运动
⇒ 开启"减弱动态效果"时**两端都退到系统默认转场**。

⚠️ **不是 no-op**：目的地照常推入，用户仍然知道"换页了"。

唯一的裁决点是纯函数
`FullScreenTransitionPlan.resolve(reduceMotion:platformSupportsZoom:)`：

| `platformSupportsZoom` | `reduceMotion` | 结果 |
|---|---|---|
| `true` | `false` | `.zoom` |
| `true` | `true` | `.plain` |
| `false` | 任意 | `.plain` |

判据：`FullScreenTransitionPlanTests`（四种输入组合的真值表 + 平台常量与编译目标
一致）+ `PlatformSupportGuard.reduceMotionIsOnlyConsumedByTheTransitionPlan`
（调用点逐次计数：`reduceMotion` 只许喂给那个函数一次，且不许裸写）。

⚠️ 把裁决提成**两端都编译、两端都可求值**的纯函数不是风格问题：若把平台分支与
Reduce Motion 分支混在 `body` 的 `#if` 里，macOS 上那半段代码根本不参与编译
⇒ 判据在 macOS 单测里对 iOS 的行为无话可说。现在 macOS 上的测试能对
`platformSupportsZoom: true` 那条分支求值。

## 能耗闸（NFR-7）：**有意不接**

本件是**一次性的导航转场**（点一下才发生），没有任何常驻调度器
⇒ 不进 `MicroInteractionReduceMotionGuard.energyGatedFiles`。
另外三件都是常驻渲染件，各自接闸。

## a11y（FR-13）

本件是**交互控件**，不是装饰层 ⇒ **不** `accessibilityHidden`。

⚠️ **它对外的可访问性完全由调用方的 `label` 提供**（`NavigationLink` 会把 label
的语义原样带上）：需要 VoiceOver 读出"打开某某"的，请在自己的 label 上写
`.accessibilityLabel(_:)`。**本件不代劳、也不猜文案**（FR-7：组件不自带 UI 文案）。

## ⚠️ 登记

同另外三件：不进 `components`（`ComponentRegistryGuard.coreDesignSources` 仍是单根
`Sources/CoreDesign`，塞进去会被判成幽灵条目；该口子由 issue #270 收口），
也没有 `public extension View` / `Transition` 成员 ⇒ `entryPoints` 零改动。
