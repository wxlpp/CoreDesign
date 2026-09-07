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
⇒ label 侧与 destination 侧的 id 对不上，**编译不报错、测试不变红、无人发现**。
⚠️ **失效形态不是"退化成普通 push"**（本节此前如此写，`#277` 推翻）：源找不到时
SwiftUI 照样跑 zoom，只是**没有锚点**——起点与被点的那张卡无关。逐帧数据见下方
《zoom 转场的运行期证据》结论 2；那里实测的是「整行删掉 `.matchedTransitionSource`」，
「id 两端对不上」按同一机理推断、未单独实测。
⇒ 改成 `FullScreenButtonDestination` 持有一个 `let sourceID: String`，由
`FullScreenButton` 传入；判据钉的是 `>.sourceID` 这个形态（任何特化后的静态访问）。

### zoom 转场的运行期证据（`#277`，2026-09-07 实测）

本仓在 macOS 上开发，`.zoom` 那条分支在 macOS 单测里**结构上不可达**：
`FullScreenTransitionPlanTests` 钉的是纯函数真值表、`zoomIsFencedToIOS` 钉的是围栏形态、
`CrossPlatformRenderTests.fullScreenButtonRenders` 只断言折叠态卡片非空白。
`#277` 之前，「iOS 上 zoom 真的触发了」只由「它能编译」背书（PR #274 终审 S-6）。
**现已有一次运行期确认。**

**器材**：iPhone 17 Pro / iOS 26.4 模拟器，预览宿主（`scripts/run-preview.sh`），
`xcrun simctl io … recordVideo` 录屏，`scripts/motion-proof/extract-frames.swift`
（`AVAssetReader` **逐样本解码**，不抽样、不去重，文件名带真实 PTS）+
`scripts/motion-proof/measure-zoom-icon.py` 逐帧测量。

⚠️⚠️ **不要用按时刻取帧的方式量这个**：本节的第一版用 `AVAssetImageGenerator` +
固定步长网格，**漏掉了其中一段的真首帧**，2×2 表里承重的那一格因此差了 132 px。
机理**不是**「零容差下请求落空就失败」——实测零容差请求落在两帧之间时**不报错，
返回前一帧**（`req 2.1400 → actual 2.1350`、`req 2.1500 → 同样是 2.1350`）；
真实机理是**网格比帧间隔粗时，某些帧在任何网格点上都不是「当前帧」**，于是整帧不出现。
⇒ 减小步长只能减少概率、不能消除：模拟器录屏是**变帧率**的，六段实测帧间隔中位
`zoom.mov` **15.0 ms**（9/600 s）、其余五段 **16.67 ms**（10/600 s），而最短样本只有
**1.667 ms**（1/600 s）
——显示时长小于步长的帧照样会被跳过。**逐样本解码是唯一无损的做法**，本仓落盘的就是这一版。

**判据**：目的地里唯一的饱和蓝——`Image(systemName: "photo.fill").foregroundStyle(.tint)`
——的像素质心与包围盒（掩码 `b > 150 && b - r > 70 && b - g > 50`，忽略前 140 行状态栏）。
画面 1206×2622，屏幕中线 x = 602.5 / 中心 y = 1311；该图标终态 221×173、cy = 1371、
掩码密度 0.70。
**「首个可见帧」定义为掩码命中 `n >= 5000` 的第一帧**（约终态 26709 的 19%）——
低于它的是淡入中的鬼影帧（实测有过 `n = 102` 的），包围盒不稳，不作数。
门槛写死在 `measure-zoom-icon.py` 里，不然下表按文档复现不出来。

#### 结论 1 ✅ 是几何放大，不是普通 push

| | 首个可见帧 cx | cx 轨迹 | cy 轨迹 | 尺寸 |
|---|---|---|---|---|
| **本件（zoom，浅色卡）** | **604** | 604 → 稳态 602，**从第一帧就在屏幕中线** | 1895 → 1372 | 图标 201×58 → 221×173 |
| **对照：普通 push** | **1156** | 1156 → 1156 → 1072 → 969 → 885 → 819 → 767 → 727 → 697 → … → 605 → 稳态 602（右→中横扫） | 1376 → 1374（**不动**） | **高 968 恒定**；宽 118（首两帧被右屏缘裁）→ 227 / 226 |

⚠️ **对照组是真跑出来的**：同一台模拟器、同一套抽帧与判据下的一次真实 `NavigationLink`
push（画廊列表 → `Button` 详情页）。
⚠️ **对照组量到的蓝不是同一个图标**——`Button` 详情页没有 `photo.fill`，过阈值的是
Light + Dark 两块预览里 Solid 按钮 + Borderless 文字的**联合包围盒**（y 988–1955）。
表里可比的是**运动学**（cx 是否横扫、cy 是否移动、尺寸是否恒定），不是尺寸本身。

#### 结论 2 ✅ `.matchedTransitionSource` 承的是「从哪儿开始」，**不是**「zoom 会不会发生」

**2×2 四次录制**——两个版本（带 / 不带该修饰符）× 两个源卡片
（详情页里 Light 与 Dark 两块预览各有一张，中心相距 **740 px**）：

| | 源卡片中心 y | 首个可见帧 cy | 图标包围盒 | 掩码密度 |
|---|---|---|---|---|
| 带 `.matchedTransitionSource` · **浅色卡** | 1288 | **1895** | 201×58 | **0.92** |
| 带 `.matchedTransitionSource` · **深色卡** | 2028 | **2315** | 201×65 | **0.91** |
| 删掉之后 · 浅色卡 | 1288 | **1528** | 143×111 | 0.67 |
| 删掉之后 · 深色卡 | 2028 | **1536** | 131×101 | 0.67 |

> **带锚点**：两张卡相距 740 px ⇒ 起点相差 **420 px**（起点跟着被点的那张卡走）。
> **无锚点**：两张卡相距 740 px ⇒ 起点相差 **8 px**（与点了哪张卡无关）。

**两条独立于「首个可见帧」这个口径的佐证**：

1. **纯几何量**：带锚点的两帧里，图标正被**揭示矩形的下边缘**切断，那条边缘的位置
   （x = 602 列上**蓝色的最后一行**；再往下隔一行抗锯齿就换成矩形外的背景色）
   浅色是 **y = 1924**（`(80,158,233)` → `y1925 (73,113,151)` → `y1926 (24,24,26)`）、
   深色是 **y = 2348**（`(97,179,252)` → `y2349 (164,207,244)` → `y2350 (203,205,209)`）
   ⇒ **Δ = 424 px**，与质心口径的 420 一致。这个数不依赖质心、也不依赖两次录制的相位。
2. **两个版本的首帧形态是两类，不只是位置不同**：带锚点两帧的密度都是 **0.91–0.92**
   （图标被揭示矩形裁掉大半、宽已到 201/221 = 0.91）；删掉之后两帧密度都是 **0.67 ≈ 终态
   0.70**（图标**完整可见**、只是整体缩到约 0.6 倍）。
   ⇒ 带锚点是「从一个又宽又扁的矩形里**揭示**出来」，无锚点是「**等比缩放 + 淡入**」。
3. **首帧之后的轨迹继续分叉**（不是只有一帧承重）：带锚点第 2 / 3 帧 cy 浅色
   `1840 / 1758`、深色 `2183 / 2036`；无锚点浅色 `1514 / 1495`、深色 `1525 / 1508`。

⚠️ **两张卡的对照是必需的，不是冗余**：只用浅色卡时，卡片中心 1288 与屏幕中心 1311
只差 23 px，**任何锚点都会给出同一组数**，分不开「锚在卡片」与「锚在屏幕中心」。

⚠️ **两次的 cx 都在 602–605** ⇒ **两个版本都是 zoom**，删掉修饰符**没有**退化成 push。

⚠️⚠️ **这推翻了本文件上一版与 `#277` 正文共有的一句**：
「若 `.matchedTransitionSource` 没生效 / sourceID 对不上，就会**静默退化成普通 push**」。
**实测的失效形态不是 push，是没有锚点的 zoom** ⇒ **比退化成 push 难察觉得多**；
结论 1 那张 push 对照表**抓不住它**，能抓住它的是「换一张源卡片，起点跟不跟着变」。

⚠️ **实测的是「整行删掉 `.matchedTransitionSource`」**。`sourceID` 两端**对不上**
（`sourceIDHasASingleSource` 防的那一族）会走同一条路，是**按机理推断**，未单独实测。
⚠️ **锚点是「源视图 frame」还是「触点」，本次分不开**——两张卡上点的都是卡片中心，
两者共变。两种读法都满足「起点跟着被点的那张卡走」，不影响结论；要分开需在同一张卡上
点两个不同位置再录一次。

#### 仍然没有的东西

**这次确认没有变成判据**：人工录屏 + 逐帧测量，**不在任何 CI 腿上**。
对**不改源码形态**的运行期退化，四条既有判据（`FullScreenTransitionPlanTests`
的真值表、`PlatformSupportGuard.zoomIsFencedToIOS`、
`CrossPlatformRenderTests.fullScreenButtonRenders`、`sourceIDHasASingleSource`）全绿。
⚠️ 但本次用的那个变异（整行删掉修饰符）**会被 `sourceIDHasASingleSource` 当场判红**
——它断言源码里存在 `matchedTransitionSource(id: Self.sourceID`。那是**结构判定**，
抓得住删行、抓不住运行期退化，两者别混。
要装成运行期判据需要「iOS 模拟器录屏 → 抽帧 → 逐帧几何断言」的链路，本仓今天没有；
`#233`（SegmentedControl thumb 滑动）是同一族缺口——它已用同一套工具拿到运行期证据，
但同样**没有变成 CI 判据**，见 `docs/components/segmented-control.md`。

<details>
<summary>复现步骤</summary>

```bash
SIMULATOR_ID=<udid> ./scripts/run-preview.sh
# 画廊滚到 Effect 段，点开 FullScreenButton；详情页有 Light / Dark 两张源卡片
xcrun simctl io <udid> recordVideo --codec h264 --force /tmp/zoom.mov &
#  ↑ 录制期间点一次卡片，2–3 s 后 kill -INT。两张卡各录一次。

swiftc -O scripts/motion-proof/extract-frames.swift -o /tmp/xf
/tmp/xf /tmp/zoom.mov /tmp/frames 2.0 2.5    # 逐样本解码，可选起止秒
python3 scripts/motion-proof/measure-zoom-icon.py '/tmp/frames/*.png'   # 需要 numpy + Pillow
# 看「首个可见帧的 cy」是否跟着被点的那张卡变。
```

⚠️ 源卡片尺寸 346×120 pt 是**从录屏首帧量的**（Light 卡 1038×359 px、Dark 卡 1037×360 px，
@3x），与 `App/Sources/ComponentData.swift` 的 `.frame(height: 120)` 对得上。
⚠️ **原始录像没有留存**（六段共约 5.1 MB：2×2 那四段 + `Button` 页的 push 对照
`push2.mov` + 弃用的 RadarChart 那段）。进仓库的只有上面两个脚本与本节的步骤。
⇒ **重录一次不会复现出同样的绝对数字**（转场起点与帧相位都不一样），但会复现
**判别量**：换一张源卡片，带锚点时首个可见帧的 `cy` 跟着变几百像素，无锚点时基本不变。
结论 2 靠的就是这个量，不是那四个具体的 `cy`。

</details>

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

⚠️ **`#270` 已收口，本节整段改写**（上句原写「不进 `components`（扫描根仍是单根）」）：
扫描根已扩成三个 target，`public struct FullScreenButton` **已按判定法登记进**
`docs/component-registry.json` 的 `components`（`prescriptive` / `tiebreaker` /
不给扩展点），判定理由见该条目 `notes`。
本件仍没有 `public extension View` / `Transition` 成员 ⇒ `entryPoints` 零改动。
