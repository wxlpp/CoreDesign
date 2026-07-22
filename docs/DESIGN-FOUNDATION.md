# Design Foundation — Apple HIG

| Field | Value |
|---|---|
| Reference | [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines) |
| Adopted at | `0.3.0`（epic `coredesign-native-foundation`，Issue #116） |
| Previously | `docs/PRIMER_VERSION.md`（GitHub Primer Primitives `v11.8.0`）—— 已删除，本文件是其替代物 |

## Why this exists

CoreDesign `0.2.0` 及之前以 GitHub 的 [Primer Primitives](https://github.com/primer/primitives) 为视觉北极星，`docs/PRIMER_VERSION.md` 锁定具体 tag 作为 token 取值的单一依据。`0.3.0` 把这套地基整体换成 **Apple Human Interface Guidelines**：字号交还系统文本样式、圆角与控件尺寸对齐 HIG 的触控与容器标度、语义色尽量改指系统色 API，而不是维护一套自有色板。

与 Primer 版本锁定不同，Apple HIG 不是一个可钉版本号的 git tag——它是一套持续演进的设计原则 + 一批稳定的系统 API（`Font.TextStyle`、`UIColor`/`NSColor` 语义色族、`ControlSize`）。本文件因此不记录"锁定到哪个版本"，而是记录**每个 token 与哪条 HIG 原则 / 哪个系统 API 对应，以及取值背后的理由**——这是下游评估升级影响、以及未来维护者理解"这个数字为什么是这个数字"的依据。

## Token 源映射表

| CoreDesign token | Apple HIG / 系统 API 依据 |
|---|---|
| `CoreTypography` | 直接取 `Font.TextStyle`（`largeTitle` … `caption2`），字号 / 行高 / 字重 / Dynamic Type 缩放全部交给系统，不再手写字号表 |
| `CoreRadius` | HIG 圆角标度惯例（squircle / continuous corner），4 档 + `CoreShape` 统一 `.continuous` 出口 |
| `CoreControlMetrics.height` | HIG 触控目标建议：常规交互控件最小可点击区域 ≈44pt，密集 chrome 收紧到 28–32pt，CTA 类放宽到 50–56pt |
| `CoreControlMetrics.{horizontal,vertical}Padding` | 贴近系统按钮的视觉密度，全部落在 `CoreSpacing.*` 命名档位上 |
| `CoreElevation` | HIG 的分层原则——层级优先靠 material（毛玻璃）与 separator 表达，阴影只用于真正悬浮的内容（popover / 菜单） |
| `SurfaceColors` / `ContentColors` / `BorderColors` / `FillColors` | 直接改指系统语义色 API（`systemGroupedBackground` 族、`label` 族、`separator` 族、`systemFill` 族），随系统外观与对比度设置自动更新 |
| `InteractionColors.accent` 及衍生族 | 改指宿主 App 的 `Color.accentColor`，衍生态用 `Color.mix(with:by:in:)` / `.opacity()` 对 `accent` 本身做调制，见下节 |
| `StatusColors` / `secondaryAccent` / `neutralAccent` | **显式定案：不改指系统色**——Apple HIG 没有"5 态状态色板"或"第二强调色"的系统概念，继续由 `ColorGrade`（第 1 层资源调色板）供色 |

## 各 token 家族的取值理由

### 字体（`CoreTypography`）

12 档直接对应 `Font.TextStyle`：`largeTitle` / `title` / `title2` / `title3` / `headline` / `body` / `callout` / `subheadline` / `footnote` / `caption` / `captionMono`（`.caption` + 等宽 design）/ `caption2`。字号、行高、字重、Dynamic Type 缩放全部由系统决定，本文件不再维护任何手写字号表——这是与 Primer 版本最核心的差异：Primer 时代 `CoreTypography` 携带 `size` / `lineSpacing` / `tracking` 三件套并用 `@ScaledMetric` 模拟缩放；现在这一整套机制（`Spec` 结构体、`*LineSpacing` / `*Tracking` 常量、`Token.fixedFont`）已删除，`.coreFont(_:)` 的调用形态保留但内部直取系统文本样式。

### 圆角（`CoreRadius` + `CoreShape`）

`none 0 / small 6 / medium 10 / large 16 / xLarge 22`。HIG 没有 `.none` 档（直角通常靠省略圆角实现），`.none` 是 CoreDesign 扩展，方便在统一类型签名下表达"无圆角"。`xLarge`(22) 当前零消费，是为 Dialog / Modal / Sheet 类容器预留的标度，不是缺陷——库内目前没有这类容器，也没有发现现有场景本该用 22pt 却被迫停在 16pt。

**`.continuous` 角样式必须经 `CoreShape.rounded(_:)` 统一出口**：只改半径数值拿不到 Apple 的 squircle 观感，角样式要在每个 `RoundedRectangle` 构造点显式指定，漏一处就是一处风格不一致的元素。`Sources` 内裸 `RoundedRectangle(` 调用已收敛为 0（唯一例外是 `CoreShape.rounded` 自身的实现）。`ConcentricRectangle`（iOS 26+）为嵌套于已知容器的元素预留，容器侧配合 `.containerShape(_:)` 声明——当前零采纳，同样是"标度先于需求"而非遗漏。

### 控件尺寸（`CoreControlMetrics`）

高度 `mini 28 / small 32 / regular 44 / large 50 / extraLarge 56`。核心判断是把 `regular` 抬到 HIG 的 **44pt 最小触控目标**——这不是某个调用点选错档，而是整个 token 族的设计意图：把全部主要交互控件（`ListRow`、`SearchField`、`SegmentedControl` 容器）统一到 44pt 下限，`SegmentedControl` 因此会把原生 `UISegmentedControl` 包装成高于其固有高度的外框，这是有意的。

横向 padding `mini=8 / small=12 / regular=16 / large=16 / extraLarge=24`：`regular` 起给出更舒展的横向留白，贴近 Apple 系统按钮的视觉密度。纵向 padding `mini=4 / small=4 / regular=12 / large=16 / extraLarge=16`：具体哪些档位由 `frame(minHeight:)` 地板决定、哪些由 padding 撑高决定，取决于平台与 Dynamic Type 档位——iOS 默认档下 `mini`/`small` 由地板决定，`regular` 及以上由 padding 决定；macOS 因系统文本样式明显更小，五档全部由地板决定。详细算式见 `Sources/CoreDesign/Tokens/CoreControlMetrics.swift` 的文档注释。

### 阴影（`CoreElevation`）

4 档语义不变（`none` / `small` / `medium` / `large`），文档注释里的 Primer 考据已替换为 HIG 依据：resting 档（`small` / `medium`）刻意调低 blur 与 y-offset，日常静止内容（Badge、卡片、列表行）不应"浮起"，层级交给 material + separator 表达；`large` 保留给真正的浮层（popover、菜单）。深色模式阴影不透明度 ≥ 浅色的 2 倍是常见工程实践，用于补偿深色背景下低对比阴影"消失"的问题。

### 语义色（`SurfaceColors` / `ContentColors` / `BorderColors` / `FillColors`）

绝大多数 token 直接改指系统语义色 API，随系统外观、对比度设置自动更新，不再由 CoreDesign 自建 colorset 供色：

- `SurfaceColors`：`surfaceCanvas` / `surfaceRaised` / `surfaceElevated` 三档统一走 `systemGroupedBackground` 族（`systemGroupedBackground` / `secondarySystemGroupedBackground` / `tertiarySystemGroupedBackground`），`surfaceCanvasInset` 改指 `FillColors.tertiaryFill`——其官方 HIG 语义（输入字段/搜索栏/按钮）与实际消费点（头像环、进度条轨道）精确对应。
- `ContentColors`：全部指向系统 `label` 族（`label` / `secondaryLabel` / `tertiaryLabel` / `quaternaryLabel` / `placeholderText` / `link`）；`contentInverse` / `contentOnAccent` / `contentOnDanger` / `contentOnEmphasis` 固定为 `.white`——Apple 没有"保证与当前外观相反"的系统色 API，且这些 token 的消费点均为固定饱和色背景，白字对比度可靠。
- `BorderColors`：`separator` / `opaqueSeparator` 两族。`borderFocus` / `borderSelected` **在 `0.2.0` 就已指向 `accent`**（各自独立的固定蓝 colorset 是更早的 Issue #93 删的，不是本次改造）；本次它们的指向不变，但因 `accent` 改指宿主 `AccentColor`，实际取值随之变化。 `borderSubtle` 取 `separator.opacity(0.28)` 而非直接等于 `opaqueSeparator`，是为了保持 `subtle(0.28) < muted(0.42) < default(1.0) < strong` 的既有强弱梯度，避免与字面顺序倒挂。
- `FillColors`：`systemFill` 族四档（`systemFill` / `secondarySystemFill` / `tertiarySystemFill` / `quaternarySystemFill`），本就是系统色，未改动。

**macOS 降级**：AppKit 没有 grouped background 系列。`systemGroupedBackground` 现降级到 `windowBackgroundColor`（此前误降级到与 `secondarySystemGroupedBackground` 相同的 `controlBackgroundColor`，导致 macOS 上画布与 raised 层同色、raised 层完全隐形——已在本次修正，`SystemBackgroundColorsMacOSTests` 守卫二者在浅色/深色下均可辨）。`secondarySystemGroupedBackground` / `tertiarySystemGroupedBackground` 保持 `controlBackgroundColor`。

### accent 衍生族（Task #120 交接，本节是承诺落盘的取值理由）

`accent` 从固定的 CoreDesign 品牌蓝（`Color.brand5`）改为 `Color.accentColor`——库跟随宿主 App 在 Asset Catalog 里设置的 `AccentColor`，而不是自带一套固定品牌色。衍生态（`accentHover` / `accentPressed` / `accentDisabled` / `accentSubtleBackground`）因此不能再各取固定色阶（宿主可以把 `AccentColor` 设成任意色相，一个固定色阶不再是"它更亮一档的样子"），改为对 `accent` 本身做明度 / 不透明度调制：

- **`accentHover` = `accent.mix(with: .primary, by: 0.15)`，`accentPressed` = `accent.mix(with: .primary, by: 0.25)`**——混合基色取 `.primary`（浅色模式≈黑、深色模式≈白）而非固定的黑或白，是为了复现旧 `brand` 色阶**外观自适应反转**的双向行为：实测旧 `brand6`（hover）浅色 `#0062D6` 比 `brand5` 深、深色 `#65B2FC` 比 `brand5` 浅——也就是"朝远离背景的方向走一档"，而不是恒定变亮或恒定变暗。用固定的白/黑混合会在其中一个外观模式下把 accent 推向背景色、收窄对比度；`.primary` 一个基色即可复现这一双向行为。`pressed` 比 `hover` 混合比例更高（0.25 vs 0.15），复现"按下态离背景更远一档"。
- **`accentDisabled` = `accent.opacity(0.35)`**——对 accent 本身降低不透明度，与 Apple 系统控件的禁用惯例一致：保持色相、只降低存在感，而不像 pressed 那样改变明度方向。
- **`accentSubtleBackground` = `accent.opacity(0.12)`**——同样走不透明度调制而非明度混合：不透明度会让底层背景透出来，在浅色与深色画布上都能读出"淡淡的强调色调"；若改用与 `accentHover` 一致的白混合调制，会在深色背景上变成一块突兀的发亮浅色色块。
- **`selectionBackgroundEmphasis` 改指实心 `accent`**（此前借道 `accentDisabled`）——"强调选中"与"禁用"是两种不同语义，借道禁用色的淡出效果会造成语义倒挂。

**显式定案：`secondaryAccent` / `neutralAccent` 两族保留品牌色阶，不随 accent 动态化。** Apple HIG 没有"第二强调色"或独立的中性强调色系统概念——只有单一的 `AccentColor`。`secondaryAccent` 服务于 `ButtonRoleStyleRole.secondary`（次要按钮角色），是 CoreDesign 自有的一套品牌色阶，语义上独立于宿主 App 的强调色：即使宿主把 `AccentColor` 换成任意颜色，"次要按钮"仍应保持库自身统一的视觉身份。`neutralAccent` 同理保留 `ColorGrade.grey` 一系而非改指系统灰，是为了避免库内出现两套灰阶互不对应。`light-blue-5` / `grey-5` 等 colorset 本身已带 light/dark 双值，明暗自适应链路与系统色等价，只是取值来自 CoreDesign 自己的调色板。

### 状态色（`StatusColors`）

5 组状态色（accent / success / attention / danger / done）× 4–5 个变体（fg / emphasis / muted / subtle[/border]）在 Apple HIG 里没有系统对应物——不存在"系统级的成功色/警示色语义色板"这类桥接目标，24 个 token 全部保持自有 colorset 取值，不改指系统色。

**深色模式 subtle 变体 alpha 修复（视觉终审 #125）**：四个 `status-*-subtle`（accent / success / attention / danger）加 `status-done-subtle`，共 5 个 colorset 的深色 alpha 此前统一为 `0.067`——6.7% 的色叠在纯黑画布上（深色下 `surfaceCanvas` = `systemGroupedBackground` = 纯黑）几乎不可见，四个语义档位无法区分。对照组是 Badge 的 neutral 档用 `secondaryFill`（深色 α=0.32），早已验证在三种父容器两种外观下均可辨——五个 status subtle 统一改深色 alpha 为 **0.280**，同一量级，并加 `statusSubtleFillsAreDistinguishableInDark` 守卫（断言深色 α > 0.15、与画布不同色、四档两两可分）。

## 决策记录

- **2026-07-21 ~ 2026-07-23**（epic `coredesign-native-foundation`，Issue #116）——把地基从 Primer 换成 Apple HIG：删除 6 个 GitHub 专用组件与 Blossom trait / `CoreGradient`（Issue #117 / #118），重铸字体 / 圆角 / 控件尺寸 / 阴影 token（Issue #119），重铸语义色层与 accent 衍生族（Issue #120），组件调用点机械迁移（Issue #121），token 换值逐点复核（Issue #122），可访问性收尾（Issue #123），代码注释清理（Issue #124），视觉终审与修复（Issue #125），文档 / CI / 版本收尾（本文件，Issue #126）。发布 `0.3.0`。

## 后续再锁定的注意事项

与 Primer 版本锁定不同，Apple HIG 本身没有版本号可钉——但**系统 API 的具体渲染结果**会随 iOS / macOS 系统版本演进（字号、行高、系统色的实际 RGBA 值历史上发生过变化）。本仓库的部署目标固定为 iOS 26 / macOS 26，token 文件里的取值理由建立在这一代系统行为之上；未来若部署目标上调，应重新核对本文件记录的取值理由是否仍然成立，而不是假定系统 API 名称不变就等价于视觉效果不变。
