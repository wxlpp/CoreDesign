# CoreDesign 设计系统摘要

> **这份文件是给设计 agent 读的**，不是给人读的参考手册。用途：让 agent 在出原型 /
> 界面草图时，用 CoreDesign 的**真实名字**标注每一个元素，使产出能被逐条翻译回
> SwiftUI，而不是翻译成一套它自己发明的词汇。
>
> ⚠️ **本文件除本节外全部由 `scripts/design-digest.py` 从 `Sources/` 派生**，不要手改
> 正文——改了会在下次生成时被覆盖。要改约定，改本节所在的 `docs/design-digest.header.md`。

## 平台与单位

- SwiftUI，iOS 26+ / macOS 26+，Swift 6 严格并发。
- 长度单位一律 **pt**。间距走 8pt 网格。
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
3. **容器背景走 `.surface(_:)`**，从下表 10 个 `SurfaceKind` 里选，不要自己拼背景色 + 圆角 + 描边。
4. **分组设置页 = `InsetGroupedSection` + `SettingsRow`**（尾部指示符用 `SettingsRowChevron`）。
   它只复刻 `.insetGrouped` 的**观感**，没有 `List` 的数据 / 滚动 / 编辑能力——需要那些能力时
   写明「用原生 `List`，行用 `SettingsRow`」。
5. **按钮 = SwiftUI `Button` + 样式 + role**：`.solid(role:)` / `.light(role:)` /
   `.borderless(role:)`，role 从 `ButtonRoleStyleRole` 五档里选。悬浮按钮用
   `.circularGlass` / `.extendedFloat`。**不要为按钮描述自定义配色**——role 是配色的唯一来源。
6. **`Toggle` / `TextField` 没有 CoreDesign 样式**，有意为之：直接用系统控件 + `.tint(_:)`。
   `ProgressView` / `Label` / `LabeledContent` / `DisclosureGroup` 有 `.core` 样式，强调色同样走 `.tint(_:)`。
7. **反馈四件套分工**：页内信息条 → `Banner`；浮层瞬时反馈 → `Toast`（经 `.toastHost`）；
   实体的状态标记 → `StateLabel`（生命周期态）/ `Badge`（语义等级）；进行中 → `ProgressIndicator`
   / `ProgressBar` / `.spinning`。**不要用 `Banner` 做浮层，也不要用 `Toast` 做常驻信息。**
8. **Liquid Glass 只出现在 5 处**：`BottomInputBar`、`Carousel`、`SegmentedControl`、
   `.floatingGlass`、`TelegramGlassButtonModifier`（`.circularGlass` / `.extendedFloat` 经它间接用）。
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
