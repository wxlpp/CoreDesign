# 转场簇 B：3D 与弹性（flip / rotate3D / swoosh / boing / skid / move）

`CoreDesignEffects` 的六条转场，Issue #267（拆自 #251 的 16 种转场）。

```swift
import CoreDesign
import CoreDesignEffects
```

⚠️ **两个 import 一个都不能少**：全仓 `@_exported` 为 0。

⚠️ **`Transition` 形态**——不是容器视图，也不是 `View` 上的 modifier。六条都以
`Transition` 协议实现 + `extension Transition where Self == …` 的静态成员暴露，
支持 `.transition(.flip)` 点语法。

> 逐条转场的 API、几何与判据见同目录下的六份分册：
> [`flip`](flip-transition.md) · [`rotate3D`](rotate3d-transition.md) ·
> [`swoosh`](swoosh-transition.md) · [`boing`](boing-transition.md) ·
> [`skid`](skid-transition.md) · [`move`](move-transition.md)。
> 本文只写**六条共用**的那部分。

## 选哪一条

| | 形态 | 进出方向 | 曲线 | 附带 |
|---|---|---|---|---|
| `.flip` | 卡片翻面（3D 旋转 ±90°，带透视） | 异向 | 线性 | — |
| `.rotate3D` | 空间翻滚（任意轴 / 任意角，默认 75° 斜轴） | 异向 | 线性 | 向纵深缩小 |
| `.swoosh` | 穿行（从一侧来、往对侧去） | **异向** | 线性 | 动态模糊 + 拉伸 |
| `.boing` | 弹性缩放（越过原尺寸再回落） | 无方向 | **阻尼余弦** | — |
| `.skid` | 刹车打滑（冲过头再刹住） | **同侧** | **阻尼余弦** | 甩尾旋转 |
| `.move` | 任意极角平移 | **同侧** | 线性 | — |

「异向 / 同侧」是承重的语义分界，不是实现细节：

- **异向（穿行）**读作"一样东西被推走、另一样顶上来"（同 SwiftUI 自带的 `.push`）；
- **同侧**读作"这块内容出现 / 收起"（同 SwiftUI 自带的 `.move(edge:)`）。

⚠️ **不要把两种语义合并成一个带 Bool 开关的转场**（J-1）。
判据：`TransitionClusterTests.directionSemanticsMatchTheDocumentedTable`（纯函数）
+ `directionSemanticsReachThePixels`（位图，两端的帧必须相同 / 必须不同）。

## 形态：三层

| 层 | 类型 | 可见性 | 职责 |
|---|---|---|---|
| 1 | `XTransition: Transition` | `public` | 只存参数 |
| 2 | `XChrome: ViewModifier` | internal | **只**读 `@Environment(\.accessibilityReduceMotion)` 并原样往下递 |
| 3 | `XMotion: ViewModifier, Animatable` | internal | 绘制。纯输入：`phaseValue` + 参数 + `isReduced` |

层 1 → 层 2 是因为 **`Transition.body(content:phase:)` 拿不到 `@Environment`**（它不是 `View`）。

⚠️ **层 2 / 层 3 分开不是"多一层"，是本簇 Reduce Motion 判据能不能存在的前提**：
`\.accessibilityReduceMotion` 在 `EnvironmentValues` 上**只读**，测试里注不进去。
层 3 把它降成一个普通 `Bool` 实参之后，判据才能把**同一个相位**分别用
`isReduced: true` / `false` 渲两遍逐字节比较——「降级真的去掉了运动」与
「降级不是 no-op」这两句话才有位图证据，而不是只剩源码扫描。

判据：`chromeOnlyRelaysReduceMotion`（层 2 读到的 `reduceMotion` 次数必须恰好等于
递给层 3 的次数）+ `chromeDoesNothingButForward`（层 2 的类型体里不许出现任何绘制调用）。

⚠️ **两跳的接线本身另有一条判据**：`transitionBodyWiresEveryStoredPropertyDownOneLayer`
从源码里**现取**每一层的存储属性（`let` / `var` 一视同仁），要求每个 `self.<属性>`
都出现在下一层的构造里——位图判据全部**直接构造层 3**，看不见这两跳，
整层被绕过时它们照样绿（`#267` 终审 C-1 / C-2 的两枚变异实证）。

> **射程边界**（明知而接受）：它是**子串检查**，三条路径能满足它而实际仍然断线——
> 丢弃式使用（`_ = self.travel` 配写死的实参）、同名替身 `struct XChrome`、
> 在层 1 与层 2 之间插一层。三者都要**刻意为之**，且位图那一半能抓住有意义的子集。
> 反过来，把同一层里两个**同类型**实参对调是源码判据抓不到、
> 只有 `realTransitionEntryPointRendersTheWholeChain` 判红的 —— 两半互补。

## ⚠️ 与 `ParticleTransition`（#253）**有意**不同的两处

### 1. 没有 `AnyView`，也没有 `if` / `guard` 早退

`ParticleTransitionChrome` 的 `body` 有两个 `AnyView` 出口。`AnyView` **擦掉视图身份**，
SwiftUI 的 attribute graph 在两个出口之间对不上号 ⇒ 动画退化成端点跳变而不是连续插值。
它在那里无害，只是因为 `\.accessibilityReduceMotion` 是系统设置里手动切换的偏好、
一次转场期间不会翻转。

本簇六条的 `body` 都是**单一视图结构**，Reduce Motion 走**逐表达式三元门控**
（`self.isReduced ? 恒等值 : 运动值`）。三个好处：

- 结构上不可能出现"出口翻转导致子树换身份"；
- `MicroInteractionReduceMotionGuard.everyMotionCallIsGated` 逐个实参检查门控与**极性**，
  本簇每一处运动都落在它射程里（早退形态是整段豁免，射程反而更窄）；
- 六个文件因此在 `approvedFormTwo` 名单上、**不在** `approvedEarlyExit` 名单上。
  判据：`transitionFilesTakeTheTernaryGateNotAnEarlyExit`。

### 2. `Animatable` 绑在**有符号**的 `phaseValue` 上

`TransitionPhase` 是 **3 case frozen enum**（`.willAppear` / `.identity` /
`.didDisappear`，`value` 分别是 `-1` / `0` / `1`）⇒ `body(content:phase:)` 只可能拿到
这三个值，**中间帧全部来自 SwiftUI 对 `animatableData` 的插值**。

- 用**有符号**值而不是 `abs()` 后的进度：后者把进出两侧塌成同一个数，`flip` / `swoosh`
  这类异向转场分不出两端；而且 `-1 → 0 → +1` 插出来是连续单调的，`abs` 之后是 `1 → 0 → 1`
  的 V 形折点。
- **必须自己 conform `Animatable`**，不能只靠内层 `.rotation3DEffect` 等 modifier 自带的
  可动画属性：`boing` / `skid` 的取值是相位的**非线性函数**（阻尼余弦），
  让 SwiftUI 直接插值最终的 scale / offset 只会得到两端之间的**直线**——
  过冲整个消失，"弹"这件事从未发生。

判据：`motionModifiersAnimateOnThePhaseValue`（`animatableData` 就是相位值）
+ `interpolationIsContinuousNotAnEndpointJump`（三个插值点彼此可辨、都不等于端点，
且与"直接用中间相位值构造"的那一帧逐字节相同）
+ `boingOvershootSurvivesInterpolation`（**渲染出来的**中间帧内容面积大于恒等帧）。

## 相位契约

| 相位 | `phase.value` | 几何量 | 内容不透明度 |
|---|---|---|---|
| `.willAppear` | `-1` | 满行程（方向按各转场语义） | 0 |
| `.identity` | `0` | **精确**恒等值 | 1 |
| `.didDisappear` | `+1` | 满行程 | 0 |

⚠️ **恒等相位必须精确归零**——它是转场停住之后**长期停留**的那一帧，留下任何残余
（半度旋转、0.98 倍缩放、1pt 位移、一点点模糊）都是**永久**的，而且静态截图上
几乎看不出来。

- 纯函数那一半：`identityPhaseIsExactlyNeutral`（`==` 而不是"约等于"——用容差会把
  「阻尼窗从 `(1-u)²` 换成 `exp(-ku)`」这类退化放过去，实测该变异会让恒等处不再为 0）；
- 位图那一半：`identityFrameIsIndistinguishableFromPlainContent`（恒等帧与
  「一层 modifier 都不套」的裸内容**逐字节相同**）。
  ⚠️ 这一条抓的是纯函数看不见的东西——实测往层 3 加一句无条件的 `.blur(radius: 0.5)`，
  纯函数判据与 `MicroInteractionReduceMotionGuard` **全绿**，只有它判红。

⚠️⚠️ **两个端点的符号也要绝对地钉**（`#267` 复审 B）：上表里的 `-1` / `+1` 是整簇
进出方向的源头。把 `TransitionCurve.value(of:)` 改成 `-phase.value` ⇒ 六条转场方向
**全反**（`.swoosh(edge: .trailing)` 变成从左边进），而在补上 ⓪ 之前全量测试 **754 全绿**——
`identityPhaseIsExactlyNeutral` 只查 `.identity ⇒ 0`（对符号不变）、位图探针都用
字面量 `phaseValue` 直接构造层 3、经 `Transition.apply` 的那条链在端点上不透明度恰为 0。
⇒ `absoluteDirectionsMatchTheDocumentedEdges` 的 ⓪ 钉「它在两个端点返回什么」，
`transitionBodyWiresEveryStoredPropertyDownOneLayer` 钉「层 1 确实经它路由 `phase`」，
两条合起来才闭环。

共享的曲线在 `TransitionSupport.swift` 的 `TransitionCurve`：

```swift
value(of:)   // 相位 → 有符号相位值
distance(_:) // |v| 钳在 0...1（带过冲的动画曲线会让 animatableData 越过端点）
opacity(_:)  // 1 - distance ⇒ 恒等恰为 1、两端恰为 0
elastic(_:amplitude:cycles:)
             // amplitude · (1-u)² · cos(2π·cycles·u)，u = 1 - distance
             // 两端恰为 amplitude、恒等**恰为 0**、中途换号形成过冲
direction(of:) // Edge → 单位方向向量（三条位移转场共用一份 switch）
```

## Reduce Motion

**位移 / 旋转 / 缩放 / 模糊 / 拉伸全部门控到恒等值，只剩 `TransitionCurve.opacity`
那条淡入淡出**（#251 给整簇定的降级形态）。走**降级形态 2**：保留呈现、去掉运动、
不叠透明度脉冲（`OpacityPulse` 吃的是 `TriggerRelay` 的计数，转场没有那个 trigger）。

⚠️ **不是 no-op**：转场承载的是"这块内容出现 / 消失了"这个信息，抹掉它会让开启该偏好的
用户看到界面瞬间跳变（`#250` 第 1 轮因此被打回）。

**承重判据 `reduceMotionLeavesExactlyTheCrossFade`** 一次断三句话，缺一条另两条都能被绕过：

1. 降级真的改变了什么（`reduced != full`）——否则门控是摆设；
2. 降级后剩下的**恰好**是那条淡入淡出（`reduced == 只加 .opacity 的对照组`，逐字节）；
3. 降级不是 no-op（降级后两个不同相位仍然彼此不同）。

⚠️ 第 2 条同时守住了 `blur(` / `scaleEffect(x:y:)` 这些
**`MicroInteractionReduceMotionGuard.motionCalls` 关键字表里没有**的东西：
实测把 `swoosh` 的动态模糊门控去掉，那份守卫**全绿**，只有这条相等断言判红。

### ⚠️ 系统还有一道同向的闸，别把它当成"本簇不必降级"的理由

`Transition.properties` 默认是 `TransitionProperties(hasMotion: true)`
（`swiftinterface` 逐字：`public init(hasMotion: Swift.Bool = true)`）。
`hasMotion` 的 SDK 文档**逐字**是这三句：

> Whether the transition includes motion.
> When this behavior is included in a transition, that transition will be
> replaced by opacity when Reduce Motion is enabled.
> Defaults to `true`.

> ⚠️ 这里原先引的是**转述**（"When true, the transition is replaced by opacity…"）
> 却写着"逐字"，已按 SDK 原文改（#267 终审 I-3）。

⇒ 系统**也**会替换掉整个转场。本簇六条**都显式声明 `hasMotion: true`**
（它们确实含运动；谎报 `false` 会把系统那道闸关掉）。

> ⚠️ 这里原先写的是「都保留该默认值」——那是一句关于**别人家默认实现**的断言：
> 当时全仓 `grep "TransitionProperties\|hasMotion"` **零命中声明**，本仓既证不了它、
> 也拦不住有人写下 `false`（姊妹 PR #289 终审带出）。现在六条各有一行
> `public static var properties: TransitionProperties { .init(hasMotion: true) }`，
> 由 `TransitionClusterTests.everyTransitionKeepsTheSystemGateOpen` 逐条钉住。

⇒ 同一件事有两道闸：系统那道在外、本仓的三元门控在内。**两道都要**——
系统那道是 SwiftUI 的实现细节（替换发生在哪一层、对 `.combined(with:)` /
`AnyTransition` 包装是否仍成立，都不在契约里），而本仓守卫量的是**本仓代码里**
每一处运动有没有门控。内层门控是**冗余**的、不是**多余**的。

| 闸 | 谁 | 何时生效 |
|---|---|---|
| **第一道（文档语义上先触发的那道）** | SwiftUI，看 `properties.hasMotion` | 六条都声明 `hasMotion == true` ⇒ 按文档语义 **RM 打开时框架把整条转场换成 `.opacity`**，于是**预期**各类型的 `body` 不被求值（**未实测**，见下） |
| 第二道（兜底） | 各转场层 3 的三元门控 | 只在框架**没有**替换时才轮得到 |

⚠️⚠️ **内层是否可达：按文档语义预期不可达**（#292 收口时逐条对齐的口径）。经
`.transition(.flip)` 这条正常路径，**预期**层 3 的 `isReduced` 读不到 `true`。
⚠️ **这是推论不是实测**：Apple 原文只承诺「that transition will be replaced by opacity」，
没有承诺被替换掉的转场的 `body` 不被求值，而本仓没有任何判据求值过它
——下面那条 `#267` 终审 I-3 的按语（「很可能根本不可达」）才是口径，`#292`
**不**把它升级成断言。保留内层门控的理由已写在上面
（`hasMotion` 一行就能改回 `false`、包装与平台版本没有文档承诺）；**代价照录**：
本簇的 RM 降级判据全绿**不等于**"我们亲手把这六条转场降级给用户看了"——
生产里处置它的是 SwiftUI。两道闸的结论一致（都是一次纯淡入淡出），
所以行为上没有分歧，分歧只在"谁做的"。

> ⚠️⚠️ **文档漏掉的那一面**（#267 终审 I-3）：既然系统那道闸在外，
> **Reduce Motion 开启时本簇的内层三元门控在生产中很可能根本不可达**
> ——整个转场已被换成 opacity，`XMotion.body` 不会被求值到。
> 两道闸的**结论一致**（都降级成一次纯淡入淡出），分歧只在"谁做的"。
> ⇒ 内层门控的价值是**契约与可测性**（让降级这件事有机器判据、且不依赖 SwiftUI
> 在哪一层做替换），不是"用户靠它才看到降级"。
> 别把本簇 Reduce Motion 判据全绿读成"我们亲手把这六条降级给用户看了"。

## a11y 分工（FR-13）

六条转场都**不加**任何 a11y 元素：它们只是给调用方的内容套一层几何变换，
不引入装饰层，也不知道被包裹的是什么。
⚠️ **"这块内容出现 / 消失了"由调用方通告**（`accessibilityValue` /
`AccessibilityNotification.Announcement`）。

## 后台 / 低电量（NFR-7）

⚠️ **六条都不接能耗闸**：NFR-7 管的是**常驻渲染件**，而转场由 SwiftUI 的动画驱动、
瞬态，没有自己的调度器（判据侧的对应事实是六个文件都不出现
`EffectsEnergyState.resolve(`，由 `MicroInteractionReduceMotionGuard` 的
`energyGatedFiles` 双向差集守着）。同 `ParticleTransition` 的处置。

## 登记

六条各是一个**公开入口点**：它们不是类型，`ComponentRegistryGuard` 的组件条目
结构上覆盖不到 ⇒ 已登记进 `docs/component-registry.json` 的 `entryPoints`
（`target` = `CoreDesignEffects`、`host` = `Transition`、`member` + `notes`），
由 `ExtensionEntryPointGuard` 做双向差集（漏登记与幽灵条目两个方向都判红）。

⚠️ **含参重载与无参形态按 `Host.member` 去重，算同一条**（口径同 #251：计数单位是
「一种 transition」不是「一个静态成员」）⇒ 六种转场 = 六条登记、十二个静态成员。

⚠️ `public struct *Transition` 本身**不**进 `components` 数组，但 `#270` 起**理由变了**：
`ComponentRegistryGuard` 的扫描根已由单根 `Sources/CoreDesign` 扩成
`GuardScanRoots.allRoots`（三个 target），**扫描根不再是理由**；
真正的理由是 `PublicTypeCollector` 只采 `public struct: View / ViewModifier`，
而它是 `public struct: Transition` ⇒ 结构上仍不进 `components`。
公开表面由上面那条 `entryPoints` 覆盖，不是漏登记。

## ⚠️ 已知限度

「SwiftUI 的转场机制**确实**会拾取这些 `animatableData` 并逐帧重求 `body`」是一个
**运行期动画事实**，`ImageRenderer` 拍静态帧、结构上观测不到。本簇判据钉到的是
「插值这一步的输入输出正确」+「插出来的帧与直接构造的同相位帧逐字节相同」，
两者合起来是必要条件，**不是充分条件**。真正的确认只能靠 `App/` 预览宿主肉眼看
（六个 `#Preview` 各自带一个切换按钮）。⇒ 与 `particle-transition.md` 同一条登记。

⚠️ **本目录七份文档的示例代码零机器覆盖**（与 `confetti.md` / `particle-transition.md`
同一条登记）。
