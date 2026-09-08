# Spec — 把 Claude Design "CoreDesign Design System" 的配色/样式决定回灌到 Swift 库

**来源**：Claude Design 项目 `c42e084a-52aa-41ec-8c70-7681e82612b2`（web edition，由本仓 `main` 派生）
**日期**：2026-09-08　**版本**：v6（评审 5 轮跑满：v1/v2/v4 BLOCK、v3/v5 REVISE。第 5 轮裁决「可进 writing-plans」）

## 高度裁决

内环单任务。⚠️ v1 的依据（「耦合面集中在 `Colors/**` 与 5 个组件」）**不成立**。
两轮评审核出的实际触面（跨 3 个 target）：

- **射程 A** 8 处 `tint:` 默认实参（7 处 + `ProgressBar`）
- **射程 B** 6 类视图级 accent 消费点（按钮三样式 / focusRing / Sidebar / TabBar / 选中态 / Ink 分段）
- 4 个图表（改 `dataAccent`，不进射程）
- 6 处 `contentOn*` 族消费点 + **3 处**改归属（Steps / BeforeAfterSlider / AnimatedMeshGradient）
- 5 个组件样式改动
- 至少 3 处把 `.accent` 当探针色的既有测试（NFR-6）

改后的依据：触面宽但**耦合极紧**——上述每一类都依赖 FR-1 对 `accent` 的重新定义，
拆成并发 Issue 会让多个 worktree 同时改 `Colors/InteractionColors.swift`、
`ContentColors.swift`、`ButtonRoleStyleRole.swift` 这三个文件。⇒ **顺序执行，不并发**。

## 用户已拍板（不再评审「该不该」，只评审「写对没有」）

1. accent 走「可主题化、墨色为默认」。
2. 设计系统标 "Conflict with upstream? = Yes" 的 4 条样式改动**全收**。
3. `SegmentedControl` **保持液态玻璃**，墨色形态改以第三个 style 提供。
4. `SearchField` **改用系统原生控件**，而非手工仿制设计系统的胶囊。

⚠️ **本文行号是 `main`@`dd72ff6` 的时点快照，可能偏一两行**（评审 S-2 已指出
`MaskRevealTransitions` / `ParticleTransition` / `Shine` 三处前景色行号各偏 1）。
引用时以**符号名**为准，不要按行号盲改。

---

## 1. 问题陈述

web edition 是本仓的下游镜像，在若干处**有意背离**上游并逐条标注了冲突。
用户要求把这些决定回灌成新基线。

回灌不是机械 diff：web edition 的一部分改动是**渲染基座受限的代偿**（浏览器没有
Liquid Glass、没有 SF Symbols、没有原生搜索框、CSS 不自带字距）。把代偿当升级抄回来
会让库退步。本 spec 的主要工作就是把「设计决定」与「web 侧代偿」分开。

---

## 2. FR-1　accent 可主题化，墨色为默认

### 2.1 取值

`accent` 是**不透明的主要墨色**：浅色下黑、深色下白。

⚠️ **必须桥到 `NSColor.textColor` 而非 `.primary` / `labelColor`**（本机实测，
Swift 6.3 / macOS 26）：

| | light | dark |
|---|---|---|
| `Color.primary` / `NSColor.labelColor` | `a=0.8471` | `a=0.8471` |
| `NSColor.textColor` | **`a=1.0000`** | **`a=1.0000`** |
| `primary.opacity(0.22)` | 实得 `a=0.1864` | 同 |
| `textColor.opacity(0.22)` | 实得 `a=0.2200` ✓ | 同 |

两者 RGB 完全相同（`0,0,0` / `1,1,1`），只差 α。用 `.primary` 会让 **FR-3 的每个设计
比例都落不准**（0.22 → 0.186、0.08 → 0.068），并让实心按钮在 macOS 上透底。

⇒ 新增第 2 层桥接 `Color.inkPrimary`：
`#if canImport(UIKit) Color(uiColor: .label) #else Color(nsColor: .textColor)`。
（iOS 侧 `UIColor.label` 实测 α = 1.0，见 `CLAUDE.md` 遮罩基色一节。）
`Color.accent` 的静态默认值 = `.inkPrimary`。

### 2.2 派生态

以 `surfaceBase`（= `.systemBackground`，macOS 桥 `windowBackgroundColor`）为混合目标：

```
accentHover            = accent.mix(with: .surfaceBase, by: 0.18)
accentPressed          = accent.mix(with: .surfaceBase, by: 0.30)
accentDisabled         = accent.opacity(0.22)
accentSubtleBackground = accent.opacity(0.08)
```

实测（macOS，`textColor` × `windowBackgroundColor`）：

| | light | dark |
|---|---|---|
| `mix(…, 0.18)` | `0.0687` ↑ | `0.8217` ↓ |
| `mix(…, 0.30)` | `0.1792` ↑ | `0.7066` ↓ |
| α | `1.0000` | `1.0000` |

### 2.3 主题化通路（⚠️ v1 的形态被否，改用评审给出的第三条路）

v1 写「静态默认值 + 组件内读环境」，并把「射程不完整」当作只能写进文档注释的缺口。
**评审核实该缺口可以直接关掉**，改用：

- 把射程 A 的 **8 处** `tint: Color = .accent` 默认实参改成 **`tint: Color? = nil`**，
  组件内 `tint ?? environment.coreAccent`。（⚠️ v2/v3 写「11 处」是把 4 个图表也算进来了；
  图表已定死不进射程，见下。）
- **源码兼容**：显式传 `Color` 的调用点走 optional 提升；
  `scripts/downstream-probe/…/PublicVisibility.swift:444-684` 全部显式传值，照常编译。
- `Color.accent` 仍是 `Color`，不改类型。

⚠️ **v1 那句「默认实参读不到环境」只对一半，必须改准**：默认实参在调用点求值，
但求出来的 `Color` 是**惰性描述**，绘制时仍按 SwiftUI 环境解析（实测 `Color.primary`
在明暗两档解析结果不同）。真正读不到的是**自定义环境键** `coreAccent`。

新增：`@Entry var coreAccent: Color = .inkPrimary` + `View.coreAccent(_:)`。
⚠️ 必须 **`public`**：`CoreDesignEffects` 的 `ping` / `rise` / `SpinningModifier` 要跨 target 读它。

⚠️ **`coreAccent(_:)` 不再顺带设 `.tint(_:)`**（v1 这么写，与既有文档注释打架）：
`SpinningModifier.swift:150-152` 与 `Ping.swift:62-63` 明写「外加 `.tint(_:)` 无效 /
有意不走 `.tint`」。两条通路各自独立、口径不混：
`coreAccent(_:)` 管 CoreDesign 自有 token；`.tint(_:)` 管 `.core` 系统控件 style（FR-12）。
调用方想同时改两者就写两个 modifier。

#### 射程 A：`tint:` 参数通路（`Color? = nil`）—— **7 处 + `ProgressBar`**

`SpinningModifier:38`、`ProgressIndicator:12/19/26`、`SpinningModifier:159 spinning`、
`Ping:67 ping`、`Rise:58 rise`（⚠️ 后两者形参名是 `color:` 不是 `tint:`），外加 `ProgressBar:35`（已是 `Color?` 形态、回落静态值，v2 清单漏了它）。

⚠️ **四个图表不在此列**（v2 的 C-4′ 矛盾）：`RadarChart:20` / `NetworkGraph:28` /
`ActivityHeatmap:18` / `RingChart:22` 改为 `tint: Color = .dataAccent`，**保持非可选、
不读 `coreAccent`**。理由见 §4.1：数据色跟着墨色 accent 走会读成禁用。

#### 射程 B：视图级消费点读 `@Environment(\.coreAccent)`

⚠️ **v2 声称「R-1 已关闭」是错的**（评审 C-3′，CONFIRMED）：今天 `Color.accent = Color.accentColor`
**跟随宿主 asset catalog**，下列静态消费点全都是可主题的；FR-1 改成 `.inkPrimary` 之后，
它们既不读 `coreAccent`、也不再跟随宿主 ⇒ **主题化能力净减少**，与用户「可主题化」的裁决相反。

⇒ 这些点必须改为读环境（都是 View / ViewModifier，本就有环境访问；
`SolidButtonStyle` 已在读 `\.isEnabled` / `\.controlSize`）：

| 消费点 | 现状 |
|---|---|
| `ButtonRoleStyleRole:15/31/47`（primary 三态）⇒ Solid / Light / Borderless 三个样式 | `.accent` / `.accentPressed` / `.accentDisabled` |
| `FocusRingModifier:37`（默认 `.borderFocus`） | `BorderColors:42` |
| `Sidebar` 选中态（§5.2 改用 `accentSubtleBackground`） | `BorderColors:48` `borderSelected` |
| `UnderlinedTabBar:116` | `Color.accent` |
| §5.5 `InkSegmentedControlStyle` | 新增 |

⚠️ `ButtonRoleStyleRole.color` 等三个属性**没有环境访问**（`nonisolated enum` 的计算属性）。

⚠️⚠️ **是新增重载，不是改签名**（评审 I-1）：v3 写「改签名」有二义，按「替换」读会让
`scripts/downstream-probe/…/PublicVisibility.swift:116-117`（`consumeResolvedColor`）
与 `Tests/CoreDesignTests/ButtonStyleDefaultTests.swift:52-68`（3 条判据）**编译失败**。

⇒ 定死形态：
- **新增** `resolvedColor(accent:isEnabled:isPressed:)`，按钮样式把 `@Environment(\.coreAccent)` 传进来；
- **旧** `resolvedColor(isEnabled:isPressed:)` **保留**，实现改为委托 `resolvedColor(accent: .accent, …)`；
- 三个无参属性（`color` / `activeColor` / `disabledColor`）**保留**为静态回退
  ⇒ `everyRoleHasThreeDistinctTones` 与 `readRolePalette` 不受影响（评审已核）。

⚠️ `InteractionColors:42` 的 `selectionBackgroundEmphasis` **不在射程 B**（第 5 轮更正）：
它是静态 token、不是视图，读不到环境；且 `Sources/` / `App/` / `Tests/` 里**零消费**
（grep 只命中定义）⇒ 按下面的静态回退规则原样保留，**不要去找它的消费点**。

**静态 token（`Color.accent` 等）保留为「环境不可达时的回退值」**，文档注释必须写明
它不随 `coreAccent(_:)` 变——这是 §4.1 `dataAccent` 之外唯一的射程边界。

⚠️ **加两条同源判据**（评审 S-5 + 第 4 轮 I-4）：

1. **默认值同源**：`@Entry var coreAccent` 的默认值与 `Color.accent` 的静态默认值
   ——**一个改了另一个没改是最容易漂的地方**，且不会有任何东西报错。
   判据 `EnvironmentValues().coreAccent == Color.accent`（结构相等，不解析，两腿可跑）。
2. ⚠️ **派生公式同源**（v4 漏）：`resolvedColor(accent:…)` 要从**传入的** accent 派生
   hover/pressed/disabled，而 §2.2 的静态 `accentHover/Pressed/Disabled` 也各写一遍公式
   ⇒ **两处公式必然漂**，而第 1 条只钉默认值、钉不住公式。
   ⇒ 派生以**单一 `static func`（接 base 参数）为唯一来源**，静态 token 与 role 都调它；
   判据 `role.resolvedColor(accent: .accent, isEnabled: true, isPressed: true) == Color.accentPressed`
   （结构相等可判——评审已探针证 `mix == mix` 为 `true`）。

---

## 3. FR-2　派生态不变式：**反转**，不是删除

⚠️ **v1 写「必须删掉方向判据」是错的**（评审驳回，实测支持）。
「朝向背景」对墨色**和任意彩色 accent 都成立**——彩色不会比白更亮、比黑更暗。
删掉等于主动丢一条比替代品都强的不变式。

`Tests/CoreDesignTests/AccentDerivationTests.swift` 现有 **4 条**（v1 只重述了 3 条）：

| 现有判据 | 处置 |
|---|---|
| `pressedMovesAwayFromBackground`（浅变暗 / 深变亮） | **反转**成 `pressedMovesTowardBackground`（浅变亮 / 深变暗） |
| `hoverAndPressedShareDirection` | 保留 |
| `derivationPreservesOpacity`（α > 0.95） | **保留且必须仍绿**——这正是 §2.1 选 `textColor` 的机器验证点。用 `.primary` 会实得 0.8746 / 0.8929 当场判红 |
| `derivationIsAppearanceAdaptive`（两外观取值不同） | **原样保留** |

⚠️ **v2 写「第 4 条并入第 1 条、4 条 → 3 条」是错的**（评审 I-1 用变异表驳回，CONFIRMED）：
两条判据**互补，不是包含关系**。评审构造 6 个变异体实测：

| 变异 | 反转后的方向判据 | `derivationIsAppearanceAdaptive` |
|---|---|---|
| 基色提前解析成 `.white` / `.black` / light-bg | **FAIL（抓住）** | PASS（空转） |
| **整个 hover 在 light 下提前解析成定值** | **PASS（漏）** | **FAIL（抓住）** |
| 基色用 `.primary`（v1 老写法 + 墨色 accent） | FAIL（ΔL = 0，方向消失） | PASS |

⇒ **净结果 4 条 → 4 条**：第 1 条反转，第 4 条原样保留。
第 3 行同时是 §2.2 必须以 `surfaceBase` 而非 `.primary` 作混合目标的机器证据
——用 `.primary` 时明度**零位移**，只剩 α 衰减。

---

## 4. FR-3　其余 token 对齐

### 4.1 有渲染效果的

| token | 现状 | 目标 |
|---|---|---|
| `secondaryAccent` 族 | `lightBlue5/6/7/2` | `grey7/8/9/2` |
| `dataAccent` / `dataAccentSubtle` | **不存在** | 系统蓝 / 其 12% |

**`dataAccent` 是 FR-1 的必要配套**：靠色相携带含义的东西（图表环、tag）跟着墨色 accent
走会读成**禁用**。⇒ `CoreDesignCharts` 四个图表的 `tint` 默认从 `.accent` 改为 `.dataAccent`，
**保持 `Color` 非可选、不进 §2.3 射程 A**。

⚠️ 取值必须钉死（评审 S-2）：`Color.blue` 与 `Color(nsColor: .systemBlue)` **不是同一个值**
（⚠️ 具体数**两次探针不一致**：本机 `resolve(in:)` 得 `(0, 0.533, 1)`，评审 sRGB 读数
`(0, 0.478, 1)` —— 差异来自色彩空间，**该数不可复现，不作判据输入**；
「两者不等」这条不等式本身仍成立且是设计输入）。本次取
`#if canImport(UIKit) Color(uiColor: .systemBlue) #else Color(nsColor: .systemBlue)`，
与第 2 层桥接口径一致。

⚠️ **`secondaryAccent` 改灰后与 `neutralAccent` 重叠**（评审 I-2，v1 遗漏）：
`secondaryAccent`(grey7) == `neutralAccentPressed`(grey7)、
`secondaryAccentDisabled`(grey2) == `neutralAccentDisabled`(grey2)。
设计系统自己就是这个取值（`--secondary-accent: grey-7` / `--neutral-accent: grey-5`），
⇒ **接受重叠**，但必须改写 `docs/DESIGN-FOUNDATION.md:174` 登记的旧理由
（「`neutralAccent` 留灰阶是为避免库内两套灰阶互不对应」——重叠后该理由失真）。
附带：`DotSphere.swift:52` / `CharSphere.swift:56` 预览的第二色从「蓝+浅蓝」变「墨+灰」，登记。

### 4.2 `contentOn*` 族——⚠️ **按消费点拆，不得一刀切**（评审 C-1）

v1 把三个 token 全改成 `systemBackground`，会让至少 4 处在深色下**反色**。
理由「白字在浅色下不可读」只在**背景是墨色 accent** 时成立；
仓库登记的原理由（`docs/DESIGN-FOUNDATION.md:58`：消费点均为**固定饱和色背景**）
在其余点上仍然成立。

| token | 目标 | 消费点 |
|---|---|---|
| `contentOnAccent` | **改** `.systemBackground` | 仅坐在 `Color.accent` 上的：`SolidButtonStyle:30`（⚠️ **只有 primary role**，见下）、`MaskRevealTransitions:133`、`ParticleTransition:191`、`Shine:118/132`。⚠️ **后三者全在 `#Preview` 块内**（评审 S-3 逐个核过）⇒ 只做视觉核对，**不要给它们配判据** |
| `contentOnEmphasis` | **保持** `.white` | `StateLabel:62-68` 压在 `statusSuccessEmphasis` / `statusDangerEmphasis` 等**固定**状态色上 |
| `contentInverse` | **保持** `.white` | `Form.swift:41` 压在**调用方传入**的 tile 底色上 |

⚠️⚠️ **`SolidButtonStyle` 必须按 role 分流——v2 把它整条记成「坐在 accent 上」是错的**
（评审 C-1′，我已独立坐实）：`SolidButtonStyle.swift:29-31` 的 `foregroundColor` 对
**五个 role 一律**返回 `.contentOnAccent`，而背景是 `role.resolvedColor(...)`。
照 v2 改完，深色下 `.solid(role: .danger)` 是**黑字压 `red5`**、`.warning` 黑字压 `orange5`、
`.secondary` 黑字压 `grey7` —— 正是 C-1 要修的那个 bug 换了个地方。

⇒ 前景色并进 `ButtonRoleStyleRole`（与 `color` / `activeColor` / `disabledColor` **同源**，
避免第二处 role → 颜色的映射漂移）：新增 `onColor`，`.primary` → `contentOnAccent`，
其余四个 role → `contentOnEmphasis`（白）。

另有**三处消费点要改归属**（它们不在 accent 之上，却在用 `contentOnAccent`）：
- `Steps.swift:362-372`——`Circle().fill(.tint)` 配 `contentOnAccent`。
  `.tint` 默认是系统蓝、非本库墨色 ⇒ 改用 `contentOnEmphasis`（保持白），
  这样对任意饱和 tint 都正确，也保住了 `.tint` 尊重。
- `BeforeAfterSlider.swift:136-139`——`contentOnAccent` 被当**滑柄填充**用，
  根本不在 accent 之上 ⇒ 改用 `contentOnEmphasis`。
  ⚠️ 顺带（评审 S-6）：把手上的图标是 `contentPrimary`（`:143`），深色下**白图标压白把手**
  ——既有问题，但既然要动这一行，一并修或明确登记。
- `AnimatedMeshGradient.swift:202`（预览）——`contentOnAccent` 压在 `.tint(.accent)`
  驱动的网格渐变上；FR-1 后渐变变灰度、字变 `systemBackground`，可读性需截图确认（评审 I-7）。

⚠️ 表里补一行「**保持**」：`contentOnDanger`（`Steps.swift:353`，压 `statusDangerEmphasis`）
—— `docs/DESIGN-FOUNDATION.md:58` 列的是四个 token，v2 只写了三个。

⚠️ NFR-5 漏的落点：`InteractionColors.swift:40` 的文档注释写「与 `contentOnAccent` **白字**
前景配对」，改完即失真。

### 4.3 functional 族——⚠️ **v2 的「无渲染面」是假的**（评审 C-2′，CONFIRMED）

v2 把 `success` / `info` / `warning` / `danger` 四行并列写成「零消费、仅 token 对齐、
无视觉 diff」，并叫执行者「不要去找不存在的渲染变化」。**后两个是错的**：
`ButtonRoleStyleRole.swift:21,23` 就是 `case .warning: .warning` / `case .danger: .danger`
——被 Solid / Light / Borderless 三个按钮样式消费；另有 `Form.swift:113` 预览。

若照 v2 把基色换成系统色、而 `warningActive/Hover/Disable` 又「保持 orange7/6/2 不动」，
同一个按钮就会 **rest 态系统橙、按下态品牌橙 7 阶**，两套色相族混用。

⇒ **裁决：`warning` / `danger` 两族（各 4 个 token）整族保持 ColorGrade 不动。**

| token | 处置 |
|---|---|
| `success` → 系统 `.green` | **改**。⚠️ v3 写「零消费」不实（评审 I-3）：`App/Sources/ComponentData.swift:1188` `.foregroundStyle(Color.success)`（预览宿主 `ConfettiDemo`）⇒ **1 处预览宿主消费**，green5 → 系统绿，NFR-4 的预览验证要覆盖它 |
| `info` → `.label` | **改**。同上，零消费 |
| `warning` / `warningHover` / `warningActive` / `warningDisable` | **不动**（保持 `orange5/6/7/2`） |
| `danger` / `dangerHover` / `dangerActive` / `dangerDisable` | **不动**（保持 `red5/6/7/2`） |
| `contentLink` → `.label` | **改**。零消费 |

⚠️ **代价如实登记**（评审第 4 轮 I-2）：这么切之后 functional 层**自身**是混的
——`success` / `info` 走系统色，`warning` / `danger` 留品牌色阶
（`#FC8800` 与系统橙 `#FF9500` 会同屏可见）。
这与本节否决 v2 时用的理由（「不要两套色相族混用」）**在层级上同形**。
⇒ **有意接受**，理由是切分线不在「色相族」而在「有无渲染面」：
零/近零消费的改，有真实渲染面的冻结。这条必须写进 docs，否则终审会拿同一条理由再打回来。

#### 被考虑并**否决**的替代方案：整族按 §2.2 机制派生（评审 I-3 提出）

评审建议 `warning = systemOrange` + `warningHover/Active = mix(…, .surfaceBase)`
+ `warningDisable = opacity(0.22)`，称「不需要新机制」。

⚠️⚠️ **v4 在这里写过两条假理由，已更正**（评审第 4 轮逐条读 colorset + 源码驳回）。
本仓最高频的缺陷族就是「结论对、理由假」，故把错的原样登记再改正：

| v4 原话 | 实际 |
|---|---|
| 「`orange5→6→7` = **逐级加深**」 | **深色档是反的**。色阶明暗镜像 ⇒ 深色下 `#FFAE43 → #FFC772 → #FFDDA1`，逐级**变浅**。两档的共同语义是「**逐级远离背景**」（浅色加深 / 深色变浅） |
| 「整族派生**需要引入第二条派生方向**，是独立设计决定」 | **假**。该机制**今天就在库里**：`InteractionColors.swift:10,13` 的 `accent.mix(with: .primary, by: 0.15/0.25)`，`docs/DESIGN-FOUNDATION.md:172` 明写它就是为复现 `brand5→6→7` 的「朝远离背景走一档」而设。FR-2 只是把它**从 accent 上退役**。整族派生是**沿用**它，不是发明 |

**仍然成立的那半**：评审 I-3 建议的 `mix(with: .surfaceBase)` 确实是**反方向**（朝向背景），
照它做 pressed 会更淡更弱 ⇒ 整族派生要用的是 `mix(with: .inkPrimary)`，不是 §2.2 的公式。

⇒ **改后的裁决理由（范围，不是可行性）**：整族派生一行可写
（`warning = systemOrange`、`warningHover/Active = warning.mix(with: .inkPrimary, by: 0.15/0.25)`、
`warningDisable = warning.opacity(0.22)`），**技术上完全可行**。不做的理由是**范围与判据成本**：
它会让同一个文件里并存两条**方向相反**的派生（accent 朝向背景 / 彩色 role 远离背景），
且要为后者补一套反向不变式判据（§3 那 4 条是按「朝向背景」写的）。
一次配色对齐不顺带承担这个。

⇒ **本次维持「两族不动」**。
**此项须在收尾汇报里如实列给用户**：替代方案**可行且成本不高**，是范围决定，不是技术障碍。

⚠️ `contentLink → .label` 的理由要改准：设计系统写「带下划线的墨字」，
但**本仓没有任何链接样式施加下划线** ⇒ 改色后链接与正文不可区分。
本次**只改 token 值、不定下划线约定**，把这条缺口登记进 docs。

---

## 5. FR-4　样式对齐

### 5.1 SearchField 改用系统原生控件（用户裁决 4）

⚠️ **设计系统在这一处自相矛盾，且它的值破触控下限**：
- `tokens/controls.css` 注释：「`.regular` 钉在 44pt HIG 最小触控目标：
  每个主要交互控件（行、**搜索框**、分段控件）都坐在它上面」
- `components/forms/SearchField.jsx`：实际 `minHeight: 36` + `borderRadius: 999`
  + `background: var(--fills-tertiary)` + `border: 0`

且 readme 自陈这个胶囊 "**is what the platform search field is**"——即 web edition 在
**手工仿制**平台搜索框。Swift 侧能用真货，就不仿。

⚠️⚠️ **不新建 `SearchFieldStyle` 协议**（评审 I-3，我已独立坐实）：
`docs/component-registry.json` 的 `SearchField` 条目是 `kind: prescriptive` /
`decidedBy: tiebreaker` / `customStyleProtocol: null` / `needsExtensionPoint: false`，
notes 明写「规定性组件不给扩展点」。加公开协议会**推翻这条裁决**，并让
`ComponentExtensionPointGuard.swift:33` 的 `inspected.count == 16` 变 17。

⇒ **直接把 `SearchField` 内部换成原生控件**，组件保持规定性、无扩展点：
iOS `UISearchTextField`（`UIViewRepresentable`）/ macOS `NSSearchField`（`NSViewRepresentable`）。
登记表不重判、guard 计数不动、公开 API 面零新增。

- **不用 `.searchable(text:)`**：它是 navigation 作用域的，由系统决定放进导航栏 / 工具栏，
  不是可内联摆放的独立控件。⚠️ 这一点**登记表已评估并否决过**（同条 notes：
  「系统 `.searchable()` 提升到 toolbar 的形态因交互位置/生命周期不同不算同含义替代」）
  ——本裁决与登记表一致，不是新决定。
- 公开 API `SearchField(text:placeholder:onSubmit:)` **保持源码兼容**。
  `clearLabel(for:)` 是 internal，不构成 API 面。

#### ⚠️ FR-5a　搜索框高度**分平台**定，判据不得走 `ImageRenderer`

v3 写「视觉 36 / 命中区 44」、v4 改「原生控件自身撑满 44pt」——**两版都不成立**。
本机实测（`swiftc` 独立二进制，macOS 26 / Xcode 26.4，与评审第 4 轮数一致）：

```
ImageRenderer(NSViewRepresentable, 200x44) → 非透明行 24，范围 10…33
NSSearchField .regular     intrinsic=24  cacheDisplay 非透明行 26（ 9…34）
NSSearchField .large       intrinsic=28  cacheDisplay 非透明行 30（ 7…36）
NSSearchField .extraLarge  intrinsic=36  cacheDisplay 非透明行 38（ 3…40）
```

两条结论：

1. **`NSSearchField` 是固定高度、垂直居中，不会撑满。** 塞进 44pt frame 上下各留 9pt
   **空带**；连 `.extraLarge` 也只有 38。⇒ v4 那句「命中区 == 视觉区、不留空带」对 macOS **是假的**，
   空带只是从包装层搬进了 NSView 自己的 bounds。
2. **`ImageRenderer` 不画 `NSViewRepresentable` / `UIViewRepresentable`**——它画一块按
   **布局尺寸**的占位图（Apple 文档有明文）。⇒ v4 §8.3 那条「非透明像素带 ≥ 44」量的还是
   **布局高度**，正是本节自己说会空转的那个量，而且**向绿失效**：
   `sizeThatFits` 返回 44 ⇒ 占位块 44 行全非透明 ⇒ 判据绿，真实 bezel 仍是 26 行居中。
   ⚠️ 连带更正：评审第 2 轮那句「非透明像素只有 200×24」量的也是**占位块**——
   结论（有空带）碰巧对，理由是假的。

⇒ **裁决：分平台（评审方案 A）。**

| 平台 | 高度 | 依据 |
|---|---|---|
| **iOS** | `UISearchTextField` 拉到 `CoreControlMetrics.height(for: .regular)` = **44pt** | 44 是**触控**下限；`TouchTargetTests` 本就整个在 `#if os(iOS)` 里 |
| **macOS** | `NSSearchField` 用 `.large`（intrinsic 28pt），**不套 `minHeight: 44`**，包装层高度 = 控件 fitting 高度 | macOS 是指针驱动、无触控下限；这样**没有空带**。Apple 自家 toolbar 搜索框也是这个量级 |

⇒ **判据形态（§8）**：
- **不得用 `ImageRenderer`**（画的是占位块）。
- macOS：`bitmapImageRepForCachingDisplay` + `cacheDisplay` 直接量真实 `NSSearchField`，
  断言**非透明带高度 == 包装层高度**（即「无空带」），而不是「≥ 44」。
- iOS：`UIGraphicsImageRenderer` + `layer.render(in:)`，断言非透明带 ≥ 44。
  ⚠️ **PLAUSIBLE，未实测**：`UISearchTextField` 是 `UITextField` 子类、背景按 bounds 拉伸，
  44pt **大概率**撑满，但本机没有 iOS 腿探针 ⇒ **实现阶段必须先测这一条**。

  ⚠️⚠️ **退路（v5 写错，已更正）**：v5 写「退回控件自然高，登记『低于 44pt 触控下限』」——
  **不可行**，两个理由：(a) `Tests/CoreDesignTests/TouchTargetTests.swift:70-74` 已有一条
  iOS 判据 `SearchField 命中高度 ≥ 44pt`，退路一触发它**必红**，而 v5 没写它的去向；
  (b) 本节上文刚说「44 是**触控**下限」，退路却主动放弃它，自相矛盾。

  ⇒ **正确退路**：**保留 44pt 包装层作命中区**（`contentShape` 撑满），
  只把**视觉带**留在控件自然高。登记的缺口从「触控 < 44」改为「**视觉带** < 44」。
  iOS 判据相应改成两半：「包装层 ≥ 44」（`TouchTargetTests:70` 照绿）
  ＋「非透明带 == 控件自然高」（无额外空带，与 macOS 同口径的第二半）。

- ⚠️ 走原生后**撤掉** `.focusRing`（系统自绘焦点态，叠一层会重）。
- ⚠️ **a11y 判据的处置在此定死，不下放 plan**：⚠️ 文件名更正——是
  `Tests/CoreDesignTests/SearchFieldTests.swift:24-38` 里的 `@Suite SearchFieldL10nTests`
  （**没有** `SearchFieldL10nTests.swift` 这个文件；同文件另有 2 条构造判据要**保留**，别删整文件）。其中
  两条判据直接调 internal 的 `SearchField.clearLabel(for:)`，配的是手搓版的清除按钮。
  走原生后清除按钮与 a11y 名**由系统提供** ⇒ 留着 helper 就是死代码、
  `Resources/en.lproj/Localizable.strings:4 "Clear %@"` 变孤儿串（无判据会红，但属 YAGNI）。
  ⇒ **删** `clearLabel(for:)` + 那 2 条判据 + 那条串，并在
  `docs/components/search-field.md` 登记「`#222` 的 a11y 行为改由系统提供」。
  ⚠️ 这会让 §8.2 的条数 **−2**，「≥ 基线」那条要按此调整口径（评审 S-7）。
- ⚠️ **两处待验**：`UISearchTextField` 的双向绑定 + `@FocusState` 桥接；
  `NSSearchField` 的 target-action 桥接。以编译 + 模拟器截图坐实。

### 5.2 Sidebar 选中行扁平化——⚠️ **这是对 `#226` 的改判，必须登记**（评审 I-5）

`accentSubtleBackground` 填充 + `label` 文字；去掉 `Sidebar.swift:335-338` 的
`floatingGlass` + `borderSelected` 描边 + `coreShadow(.medium)`。

⚠️ v3 没提这件事：`docs/components/sidebar.md:114-131` 有一条**在案裁决**
——「选中态：刻意不追随原生（`#136` / `#226` 定案）」，`#226` 明写「**保持现状**」。

⇒ 本次是**改判**，不是新决定。改判有据——`#226` 自己写下了重议条件：

> 「若出现第三次同类反馈、**或本库整体向原生收敛**，应当**重议**而不是再次援引本条。」

**两个条件同时成立**：
1. **第三次同类反馈**——`#136`（「读起来像聚焦的输入框」）、`#225` 视觉终审
   （「读作键盘 focus ring 而非选中态」）之后，本设计系统是第三次，
   且措辞同族（readme "Blended influences" 表：「Apple 自己的侧栏值读起来更安静」）。
2. **本库整体向原生收敛**——本次同一批改动里 `SearchField` 改用原生控件（§5.1）、
   functional 层改指系统色（§4.3），是成建制的收敛。

⇒ NFR-5 落点加 `docs/components/sidebar.md:112`（token 行）与 `:114-131`
（整段改写为「已重议 / 已改判」，**保留 `#136`/`#225`/`#226` 的历史记账，不删**）。

### 5.3 ListRow 行距 12 → 8

⚠️ **可观测效果比 v1 写的小得多**（评审 I-3）：`ListRow.swift:41-42` 的 padding 之后
紧跟 `.frame(minHeight: 44)`。单行 body 文本约 20pt ⇒ 现在 20+24=44，改后 20+16=36，
**被 44 钉回**。⇒ **只有多行 / 带副标题的行真的收紧**。
验收判据必须建立在多行行上，否则这条改动无从判定。44pt 触控下限不动。

### 5.4 Card 默认加微投影

⚠️ **不能用 `lifted: Bool = true`**（评审 I-4，CONFIRMED）：
`Tests/CoreDesignTests/BoolExemptionGuard.swift:381-401` —— public 声明含未豁免 Bool 参数
**直接判红**；豁免要同轮抬 `docs/bool-exemptions-baseline.json` 的 `maxEntries` 并写 rationale，
guard 自陈「扩张豁免面是破例」。

⇒ 改**非 Bool 形态**：`Card(elevation: CoreElevation.Level = .small)`，
`.none` 即一行退回无投影。既满足 Bool 纪律，也比布尔更能表达「浮多高」。
⚠️ 明确违反本仓规则——原文是 `docs/DESIGN-FOUNDATION.md:51`「层级交给 **material + separator**」
（v1 引成「surface + separator」，已改准）。设计系统自陈是「唯一一处刻意越界」。按用户决定收下，但：
- `Card` 文档注释写明它背离 surface 分层规则，**`elevation: .none` 是一行退回**（v4 此处残留「`lifted: false`」，而 Bool 形态已在上一段被否决）；
- **不动 `.surface(.content)` 本身**——越界只在 `Card` 这一层，不污染 `SurfaceModifier`。

### 5.5 SegmentedControl 墨色形态以第三个 style 提供，默认不变

- 新增 `InkSegmentedControlStyle`：选中段 = 实心 `accent` 胶囊 + `contentOnAccent` 文字。
- ⚠️ **今天没有 `.glass` / `.plain` 静态入口**（`SegmentedControl.swift:207` 只收
  `some SegmentedControlStyle`）⇒ 要么三个一起加 `where Self ==` 入口，
  要么只提供 `InkSegmentedControlStyle()` 形态。**本次选前者**（三个一起加，避免只有 `.ink` 有点语法的畸形 API）。
- ⚠️ **这三个静态入口必须写 `nonisolated`**：它们是本包自有协议上的公开 static 成员，
  会被 `.defaultIsolation(MainActor.self)` 卷进 MainActor ⇒
  `scripts/mainactor-static-ratchet.sh` 必红（见 NFR-2）。
  ⚠️⚠️ **只加在 static 上编译不过**（评审 I-7，独立探针 CONFIRMED）：
  报 `call to main actor-isolated initializer 'init()' in a synchronous nonisolated context`。
  ⇒ **三个 style struct 的 `public init()` 也要加 `nonisolated`**
  （无存储属性，可直接加）。`GlassSegmentedControlStyle` / `PlainSegmentedControlStyle`
  今天的 `init()` 都没有。**不得走豁免表**——这一格修得掉，与 `SidebarTextStyle` 那种「修不掉」不同。
- **默认仍是 `GlassSegmentedControlStyle`**。理由：web 的墨色胶囊是**渲染基座代偿**
  （浏览器画不出 Liquid Glass），不是升级；iOS 原生腿已是 `.label` 8%/15% 淡染 + label 文字，
  本就落在单色体系内。
- ⚠️ `InkSegmentedControlStyle` 走 SwiftUI 回退路径，**不走** `NativeGlassSegmentedControl`：
  后者选中态只有 `selectedSegmentTintColor` 一个入口，塞不进「实心 + 反色文字」。

---

## 6. 明确不移植（**4 条**）

| 不移植项 | 理由 |
|---|---|
| 字距 `--type-*-tracking` | ⚠️ **沿 `#119` 定案，未实测**（评审 I-5 更正 v1 把它当既定事实写）。`docs/BREAKING-CHANGES.md:710`（#119）定案「行高与字距由系统决定」；`Sources/` 里无任何 `.tracking(` / `.kerning(`。web 的 tracking 值取自 Apple iOS 27 Figma 库（即 HIG 表本身，非自定设计值）⇒ 叠加风险成立。**但「SwiftUI 已自带」这一步没有测量**，如需坐实要单独做 |
| Lucide 图标 / `Icon` 组件 | SF Symbols 不可分发到 web 的替代品；本仓继续 `Image(systemName:)` |
| `Surface` 组件形态 | web 为让裸 `<div>` 吃 surface kind 而加；Swift 已有 `.surface(_:)` modifier |
| `MessageBubble` / `DocumentTree` / `CommandMenu` 等 | 新组件，不属于「配色与样式」范围 |

---

## 7. NFR

- **NFR-1 判据腿**：新增/改动的颜色断言不得在 macOS `swift test` 腿解析 ColorGrade 资源色
  （198 个常量在该腿恒全透明）。射程覆盖：`secondaryAccent`（改 grey 族后**仍是资源色**）
  **以及 `Card` 的 `CoreElevation` 投影色**（评审 I-4，v1 遗漏——4 个 shadow token 同属那 198 个）。
  ⚠️ `ButtonRoleStyleRoleTests.everyRoleHasThreeDistinctTones` 比的是**结构相等**，
  评审已核 primary 三态改后仍互异（`primary != mix(...)`、`!= opacity(0.22)`），不会塌。
- **NFR-2 MainActor static 棘轮**——⚠️ **v2 点名的成员反了**（评审 I-5，CONFIRMED）：
  写在 `extension Color`（**SwiftUI 类型**）上的 `inkPrimary` / `dataAccent` / `dataAccentSubtle`
  **不在脚本射程内**，按 CLAUDE.md 它们根本不会带 `@MainActor`
  （`defaultIsolation` 不作用于外来模块类型的扩展）。
  真正在射程内的是 **§5.5 的三个静态入口**：`SegmentedControlStyle` 是本包自有协议，
  `public extension SegmentedControlStyle where Self == …` 上的 `static var glass/plain/ink`
  会被卷进 MainActor，**不加 `nonisolated` 脚本必红**。
  改完手动跑 `scripts/mainactor-static-ratchet.sh`（本机热 `.build` 上约 4s）。
- **NFR-3 下游探针**：`cd scripts/downstream-probe && swift build`。
  重点验 §2.3 的 `Color? = nil` 签名改动是否真的源码兼容。
- **NFR-4 预览宿主**：`xcodebuild -project App/CoreDesignPreview.xcodeproj` 手动确认。
- **NFR-5 三处落点同步**（`#287`）。⚠️ v1 只写了泛指，评审 I-5 补出**会讲反话的具体行**：
  - `CLAUDE.md:31`（「`accent` 改指宿主 App 的 `Color.accentColor`」）
  - `docs/DESIGN-FOUNDATION.md:28`（accent 理由）、`:58`（白字理由）、`:167`、`:174`（secondaryAccent 理由）
  - `docs/components/spray.md:67`（「`Color.accent` 就是 `Color.accentColor`」）
  - `docs/component-registry.json` 的 `components[].notes` / `entryPoints[].notes`
  - `Sources/CoreDesign/Colors/InteractionColors.swift:40` 文档注释（「与 `contentOnAccent`
    **白字**前景配对」——改完即失真）
  - ⚠️ **更多会讲反话的具体行**（评审 I-9）：`docs/components/search-field.md:27-37`
    （整段描述手搓版，**且今天已失真**——写 `surfaceCanvasInset` / `CoreRadius.medium`，
    代码是 `surfaceInteractive` / `CoreRadius.small`；走原生后整段作废）、
    `sidebar.md:112` 与 `:114-131`、`button.md:50`、`steps.md:140`、`pin-code.md:80`、
    `rating.md:108`、`shine.md:128`（都写着 `Color.accentColor` 或 `contentOnAccent`）、
    `CLAUDE.md:156`（「`FunctionalColor` 全部 10 个」——§4.3 后只剩 8 个仍是资源色别名）、
    登记表 `components[51].notes`（SearchField 的「清除按钮」措辞，`kind`/`decidedBy` 不动）
  - ⚠️ **`docs/BREAKING-CHANGES.md` 必须新增「未发布」章节**（评审 I-9，v3 全无）。
    本仓约定把「带默认值的新参数」也登记为破坏性变更（`:19-25` 的 `#312` 是同形先例）。
    至少 6 项：`tint: Color → Color?`（8 处）、`Card.init` 新增 `elevation`、
    `Color.accent` 语义从 `accentColor` 变墨色（`:788` 登记过上一次同类变更）、
    `contentOnAccent` 取值翻转、`resolvedColor` 新重载、`accentDisabled` 0.35 → 0.22。
    ⚠️ 补 4 项（评审第 4 轮 S-5）：`SpinningModifier.swift:26` 的 `public let tint: Color`
    是**公开存储属性**，射程 A 改类型后它是第 9 个面；
    `accentSubtleBackground` 0.12 → 0.08；§5.1 撤 `.focusRing`；
    §5.1 清除按钮改由系统提供（行为变更）。
    版本意图：相对 `v0.9.0` 的下一个 **minor**。
  - ⚠️ **`docs/design-digest.md` 是 CI 门禁，不是普通文档**（评审 S-1，CONFIRMED）：
    `Tests/CoreDesignTests/DesignDigestSyncGuard.swift:11-12` 跑
    `python3 scripts/design-digest.py && git diff --exit-code`。
    它逐 token 登记了 `contentOnAccent → .white`、`secondaryAccent → lightBlue5` 等
    （`:184,228-231,237`）。
    ⚠️ **门禁比「重跑生成器」更严**（评审 I-8）：`scripts/design-digest.py:20-23` 钉了
    `FLOORS = {"colors": 115, …}` 并在 `:566-582` 做**精确相等**比对 ⇒ 新增
    `inkPrimary` / `dataAccent` / `dataAccentSubtle` 后 `colors` 变 118，**生成器自身失败**；
    `styleext` / `viewext` / `protocols` 也会因 `InkSegmentedControlStyle`、三个静态入口、
    `View.coreAccent(_:)` 而动。另有两处**手写散文**会失真：
    `docs/design-digest.header.md:80`（「`accent` 取宿主 App 的 `AccentColor`」）与
    `scripts/design-digest.py:485`（「`FunctionalColor` 显式保留品牌色阶」——§4.3 后半真半假）。
    ⇒ 处置四步：重跑生成器 → 按报错更新 `FLOORS` → 改 header.md:80 与 .py:485 → 提交三者。

- **NFR-6 `.accent` 被当作「可区分的探针色」的测试**（评审 I-6，源码 CONFIRMED / 判红 PLAUSIBLE）：
  `Tests/CoreDesignEffectsTests/TextAndDisplayTests.swift:824-826` 用
  `halfA(after: .accent)` vs `halfB(after: .contentPrimary)` + `expectBitmapsDiffer`。
  FR-1 后在 **iOS 腿**上 `inkPrimary = .label = contentPrimary` ⇒ 位图逐字节相同 ⇒ **红**；
  macOS 上 `textColor`(α 1.0) 与 `labelColor`(α 0.8471) 仍差几字节 ⇒ **绿**。
  典型的「macOS 绿、iOS 红」假绿面。同型点：`MaskRevealTests.swift:479-486`、
  `CrossPlatformTests.swift:464`。
  ⇒ 实现阶段必须 grep **全部**把 `.accent` 当探针色的测试，换成与 `label` 族无关的颜色。
  ⚠️ **实测面比上面列的大得多**（评审第 4 轮 S-4）：**9 个文件 / 37 处**。
  其中 `EffectsColorLiteralGuard.swift:157`（字符串 fixture）与
  `MicroInteractionTests.swift:278`（源码扫描断言）**不受影响**，其余 7 个文件逐个核。
  把这个数写在这里，免得 plan 少估。
  ⚠️ **另有一族形态不同、v3 未覆盖**（评审 I-2）：`Tests/CoreDesignTests/SpinningTintPassthroughGuard.swift:9`
  断言 `ProgressIndicator().tint == Color.accent`——射程 A 改成 `Color? = nil` 后该值为 `nil`，**必红**。
  处置：改断言 `tint == nil`，另加一条「无显式 tint 时读 `coreAccent` 环境」的判据。

---

## 8. 成功判据

1. `swift build` 三 target 全绿。
2. `swift test` 条数 **≥ 基线**（基线数字见 §10，落盘后填）。
3. 新增/改动判据：
   - FR-2 **四条**（§3：方向朝背景且符号随外观反转 / 同向且 pressed 更远 / α > 0.95 / 两外观取值不同）；（⚠️ v2 残留写「三条」，§3 已定 4 → 4）
   - `contentOnAccent` 在明暗两档取值**不同**；
   - **图表在有 / 无 `.coreAccent(.red)` 下位图相等**——`ImageRenderer` 逐像素比较
     （先例 `CelebrationAndProcessingTests.swift:248-255`）。
     ⚠️ v2 把这条写成「`dataAccent` 不跟随 `coreAccent`」是**恒真式**（`static let` 当然不随环境变），
     且与 §2.3 的图表归属互相矛盾（评审 C-4′）。§2.3 已定死图表**不进射程 A** ⇒
     本判据改成对**图表整体**的位图断言，这时它才有内容：谁把图表接进 `coreAccent` 就会红。
     **如实登记：这条今天天然绿，是防回归网、不是证明。**
   - **FR-5a**（形态见 §5.1，**不得用 `ImageRenderer`**）：
     macOS 走 `cacheDisplay`，断言真实 `NSSearchField` 的非透明带 **== 包装层高度**（无空带）；
     iOS 走 `layer.render(in:)`，断言非透明带 **≥ 44**。
4. `scripts/mainactor-static-ratchet.sh` 通过。
5. `cd scripts/downstream-probe && swift build` 通过。
6. iOS Simulator 腿：条数取 `.xcresult` **顶层** `passedTests`（不是 `devicesAndConfigurations[]`）。

---

## 9. 剩余风险

- **R-1**（v1 的「`coreAccent` 射程不完整」）——§2.3 采纳 `Color? = nil` 后**已关闭**。
- **R-2**（macOS α）——§2.1 已定死为 `inkPrimary` → `NSColor.textColor`，**不再留给 plan**。
- **R-3 对比度**——⚠️ v2 挑错了对子（评审 I-8，探针 CONFIRMED）。
  `textColor` vs `windowBackgroundColor` 实测 **light 21.0:1 / dark 16.7:1**
  ⇒ 「墨压 `surfaceBase`」这一对**没有风险，此项关闭**。
  真正未验的是另外两组，**升级为实现阶段必修**（预览截图坐实即可）：
  1. `contentOnEmphasis`（白）压**非 primary role** 的按钮底色（§4.2 分流后的四个 role）；
  2. `accentDisabled = ink.opacity(0.22)` 底 + `contentDisabled`（`quaternaryLabel`）字
     ——同一画布上两层低 α，禁用态虽不受 WCAG 约束，但可能接近不可见。
  3. §5.2 Sidebar 选中态 `ink.opacity(0.08)`——macOS 浅色下是 8% 黑压
     `windowBackgroundColor`，可见性并入本清单一起截图（评审 S-6）。
  4. ⚠️ **22% 墨作为禁用「文字」色**（评审 I-6，v3 漏）：`LightButtonStyle.swift:18` 与
     `CoreBorderlessButtonStyle.swift:14` 的前景色是 `role.resolvedColor(...)` 本身
     ⇒ `accentDisabled` 在这两个样式里是**文字色**、不是底色，压在
     `surfaceInteractive` / 透明底上。0.35 → 0.22 直接削它 37%。
     ⚠️ **预置回退（免得 plan 阶段被迫重新决策）**：若截图判为不可读，
     Light / Borderless 的**禁用前景**改用 `contentDisabled`
     ——`SolidButtonStyle.swift:30` 今天就是这么做的，有现成先例。
- **R-4 设计系统内部矛盾，一律以 token 文件为准**：`readme.md` "States" 段写
  `disabled 35%` / `selection 12%`（**上游旧值**，改 token 时没跟着改），
  而 `tokens/colors.css` 与 "Colour character" 段写 22% / 8%。
  凭据（`tokens/colors.css` 原文）：
  `--accent-disabled:color-mix(in srgb, var(--accent) 22%, transparent);`
  `--accent-subtle-background:color-mix(in srgb, var(--accent) 8%, transparent);`

- **R-5 主题色若是饱和色，深色下前景会反色**（第 5 轮 I-2，**下放 plan 登记，非本次修**）：
  §4.2 把 `contentOnAccent` 定为 `.systemBackground`，**只在 accent = 墨色时正确**。
  而 §2.3 的 `coreAccent(_:)` 允许宿主设**任意色**。配对消费点：
  `ButtonRoleStyleRole.onColor(.primary)`、`InkSegmentedControlStyle` 选中段。
  宿主 `.coreAccent(.blue)` 时浅色白字压蓝（对）、**深色黑字压蓝**（错）
  ——比今天「白字压 accentColor」是净退步，且正是 §4.2 修的那个 bug 在主题化通路上重现。
  ⇒ 本次处置：在 `coreAccent(_:)` 文档注释 + `DESIGN-FOUNDATION.md` + BREAKING 登记
  「**主题色应为近单色（黑/白极性）**；饱和主题色在深色下前景为 `systemBackground`，
  本次不提供 on-accent 环境钩子」，并开后续 issue。
  **须在收尾汇报里与 §4.3 的替代方案并列给用户**（真要修需加 `coreAccent(_:on:)`
  或按亮度派生 `onColor`，那是 spec 级改动）。
- **R-6 `focusRing` 的射程归属**（第 5 轮 I-3，**plan 自行处置**）：
  `FocusRingModifier.swift:35-40` 的公开入口是 `color: Color = .borderFocus` **默认实参**，
  与射程 A 同构，而 §2.3 把它列进了射程 B（读环境）——默认实参读不到 `coreAccent`。
  库内唯一调用方 `SearchField.swift:75` 正被 §5.1 撤掉。
  ⇒ plan 二选一（机制 spec 已定义，不需回 spec）：
  (a) 按射程 A 改 `Color? = nil`，射程 A 计数 8 → 9、BREAKING 再 +1；
  (b) 从射程 B 剔除，文档写明 `focusRing` 不随 `coreAccent` 变。

## 10. 基线数字

在 `feat/design-system-realign`（与 `main` 无代码差异，仅多出本 spec）上实测，
`rtk proxy swift test`，Swift 6.3 / macOS 26：

```
Test run with 972 tests in 138 suites passed after 264.798 seconds with 7 known issues.
EXIT=0
```

⇒ **macOS native 腿基线 = 972 条 / 138 suites / 7 known issues**。

⚠️ 三条读数纪律，写进来免得下一轮被误读：
1. **这是 macOS native 腿的数，不是全量**——`#if os(iOS)` 的 suite（`DynamicTypeLayoutTests`、
   `SurfaceContrastTests`）在这条腿上是**空 suite**，零条且不报错。
2. **console 逐条行不可用作条数**：同一份日志里 `passed after` 只有 **17** 行 vs 汇总 972 条
   （`#312` 登记的并行交错丢行）。⇒ 只取 `Test run with …` 那一行的总数。
3. **iOS 腿基线尚未跑**，plan 阶段补：`xcodebuild test -scheme CoreDesign-Package`
   + `-resultBundlePath`，取 `.xcresult` **顶层** `passedTests`。
