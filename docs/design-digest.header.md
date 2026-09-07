# CoreDesign 设计系统摘要

> **这份文件是给设计 agent 读的**，不是给人读的参考手册。用途：让 agent 在出原型 /
> 界面草图时，用 CoreDesign 的**真实名字**标注每一个元素，使产出能被逐条翻译回
> SwiftUI，而不是翻译成一套它自己发明的词汇。
>
> ⚠️ **正文的每一个条目由 `scripts/design-digest.py` 从 `Sources/` 派生**，但**各节段首的
> 说明文字是手写的**（住在那个脚本里），与本节一样没有机器判据兜底、同属人工评审项。
> 不要手改产物——改了会在下次生成时被覆盖。要改约定，改 `docs/design-digest.header.md`。

## 与 `docs/component-registry.json` 的口径差

两份台账射程不同，**名字对不上是正常的**：registry 里 `repo=coredesign` 的 62 条（全表 87 条，另 25 条属别的仓）是「组件**契约**」射程，
本文件的 90 条是「所有 `View` / `Shape` / `*Style` / `Transition` / `Layout` 遵从者」。
⚠️ 具体地，registry 里那条 `Toast` 是**契约名不是类型名**——`Sources/` 里没有名叫
`Toast` 的类型（真名 `ToastItem` / `ToastHost`）。**以本文件为准**：它由源码派生。

## 平台与单位

- SwiftUI，iOS 26+ / macOS 26+，Swift 6 严格并发。
- 长度单位一律 **pt**。间距标度见下方 `CoreSpacing` 表，**不是纯 8 的倍数**：`xxs` / `xs` / `md` 三档（2 / 4 / 12pt）不是。
- 字号**不写数字**：走 Apple 系统文本样式，随 Dynamic Type 缩放。

## 三个 target（依赖单向）

| target | 内容 | 依赖 |
|---|---|---|
| `CoreDesign` | 系统原生观感的组件、四层色彩、token、modifier | 无（恒为空） |
| `CoreDesignEffects` | 微交互 / 转场 / 常驻动效 | → `CoreDesign` |
| `CoreDesignCharts` | Swift Charts 画不出来的四类图表 | → `CoreDesign` |

标注元素时**写明它来自哪个 target**——只要系统原生观感的消费者不会引入后两个。

## 硬规则（违反即为误标）

1. **颜色只写第 3 / 4 层语义名**（`surfaceRaised` / `contentSecondary` / `statusDangerForeground`…）。
   **不写色相名、不写 hex、不写 `brand-5` 这类色阶**——色阶是第 1 层，组件里不直接用。
2. **间距 / 圆角 / 描边一律写 token 名**（`CoreSpacing.md`、`CoreRadius.medium`、
   `CoreBorderWidth.thin`），不写裸数字。字号写 `CoreTypography.Token` 的档位名。
3. **容器背景走 `.surface(_:)`**，从这 10 个 `SurfaceKind` 里选，不要自己拼背景色 + 圆角 + 描边：
   `.canvas` `.content` `.control` `.floating` `.overlay` `.grouped` `.canvasSubtle` `.panel`
   `.sidebar` `.card`。
4. **分组设置页 = `InsetGroupedSection` + `SettingsRow`**（尾部指示符用 `SettingsRowChevron`）。
   它只复刻 `.insetGrouped` 的**观感**，没有 `List` 的数据 / 滚动 / 编辑能力——需要那些能力时
   写明「用原生 `List`，行用 `SettingsRow`」。
5. **按钮 = SwiftUI `Button` + 样式 + role**：`.solid(role:)` / `.light(role:)` /
   `.borderless(role:)`，role 从 `ButtonRoleStyleRole` 五档里选。悬浮按钮用
   `.circularGlass` / `.extendedFloat`。**不要为按钮描述自定义配色**——role 是配色的唯一来源。
6. **`Toggle` / `TextField` 没有 `.core` 入口点**，有意为之：设置行里的开关直接用系统
   `Toggle` + `.tint(_:)`。⚠️ 但 `Toggle` **另有** `CheckBoxToggleStyle`（复选框形态，方框 + label）。
   `ProgressView` / `Label` / `LabeledContent` / `DisclosureGroup` 有 `.core` 样式，其中
   **`ProgressView` / `Label` / `DisclosureGroup` 三者的强调色走 `.tint(_:)`**；
   ⚠️ `CoreLabeledContentStyle` **没有强调色**，label / content 固定走
   `contentSecondary` / `contentPrimary`，对它施加 `.tint(_:)` 静默无效。
7. **反馈四件套分工**：页内信息条 → `Banner`；浮层瞬时反馈 → `ToastItem`（经 `.toastHost` 呈现，队列由 `ToastHost` 管；**没有名叫 `Toast` 的类型**）；
   实体的状态标记 → `StateLabel`（生命周期态）/ `Badge`（语义等级）；进行中 → `ProgressIndicator`
   / `.spinning`。
   ⚠️ **`ProgressBar` 已弃用**（全仓唯一一个 `@available(*, deprecated)` 的公开符号），
   改用 `ProgressView(value:).progressViewStyle(.core)`——就是上一条说的 `.core` 通路。**不要用 `Banner` 做浮层，也不要用 `ToastItem` 做常驻信息。**
8. **Liquid Glass 只出现在 5 处**：`BottomInputBar`、`Carousel`、`SegmentedControl`、
   `.floatingGlass`、`TelegramGlassButtonModifier`。⚠️ 两个悬浮按钮样式**走的不是同一条**：
   `.circularGlass` 经 `TelegramGlassButtonModifier`，`.extendedFloat` 经 `.floatingGlass`。
   别处不要描述玻璃材质。
9. **动效不在原型里定案**：`CoreDesignEffects` 的微交互与转场手感只能在真机上判。
   原型里最多标注「此处用 `.confetti` / `.iris` 转场」，不要据此下视觉结论。
10. **标不出名字的地方，明写「缺组件」**，不要用近似的名字凑。那一处就是设计系统的缺口，
    是有价值的产出，不是失败。

## 已知不可移植到 web 原型的部分

- `.glassEffect` 的实时折射 / 高光；web 侧的 `backdrop-filter` 不是同一个东西。
- 第 3 层大多数 token 直接指系统语义色（`label` / `separator` / `systemFill` /
  `systemGroupedBackground` 族），取值随**外观、增强对比度、平台**在运行期变；
  `accent` 取宿主 App 的 `AccentColor`。原型里只能快照某一档。
- `SystemBackgroundColors` 那 6 个 token 在 **macOS 上全部同值**——分层背景只在 iOS 成立。
