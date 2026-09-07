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

---

# Token 词汇

## `CoreSpacing`（11 档）

| token | 值 (pt) | 用途 |
|---|---|---|
| `CoreSpacing.none` | 0 | 无间距 (0pt)。 |
| `CoreSpacing.xxs` | 2 | 超紧凑 (2pt)。 |
| `CoreSpacing.xs` | 4 | 紧凑 (4pt)。 |
| `CoreSpacing.sm` | 8 | 默认 (8pt)。 |
| `CoreSpacing.md` | 12 | 舒适 (12pt)。 |
| `CoreSpacing.lg` | 16 | 宽松 (16pt)。 |
| `CoreSpacing.xl` | 24 | 充裕 (24pt)。 |
| `CoreSpacing.xxl` | 32 | 大 (32pt)。 |
| `CoreSpacing.xxxl` | 40 | 加大 (40pt)。 |
| `CoreSpacing.xxxxl` | 48 | 特大 (48pt)。 |
| `CoreSpacing.huge` | 64 | 巨大 (64pt)。 |

## `CoreRadius`（5 档）

| token | 值 (pt) | 用途 |
|---|---|---|
| `CoreRadius.none` | 0 | 直角 (0pt)。 |
| `CoreRadius.small` | 6 | 小圆角 (6pt)。 |
| `CoreRadius.medium` | 10 | 中圆角 (10pt)。 |
| `CoreRadius.large` | 16 | 大圆角 (16pt)。 |
| `CoreRadius.xLarge` | 22 | 特大圆角 (22pt)。 |

## `CoreBorderWidth`（5 档）

| token | 值 (pt) | 用途 |
|---|---|---|
| `CoreBorderWidth.none` | 0 | 无描边 (0pt)。 |
| `CoreBorderWidth.hairline` | 0.5 | 亚像素描边 (0.5pt)。 |
| `CoreBorderWidth.thin` | 1 | 标准描边 (1pt)。 |
| `CoreBorderWidth.thick` | 2 | 强调描边 (2pt)。 |
| `CoreBorderWidth.thicker` | 4 | 极厚描边 (4pt)。 |

## `CoreTypography.Token`（12 档，经 `.coreFont(_:)` 施加）

每档直接对应一个 Apple 系统文本样式，字号 / 行高 / 字重 / Dynamic Type 缩放由系统决定。

`.largeTitle`, `.title`, `.title2`, `.title3`, `.headline`, `.body`, `.callout`, `.subheadline`, `.footnote`, `.caption`, `.captionMono`, `.caption2`

## `CoreElevation.Level`（4 档，经 `.coreShadow(_:)`）

| 档位 | blur radius | y 偏移 |
|---|---|---|
| `.none` | 0 | 0 |
| `.small` | 1 | 0.5 |
| `.medium` | 4 | 2 |
| `.large` | 12 | 6 |

## `CoreControlMetrics`（按 SwiftUI `ControlSize`，5 档）

| ControlSize | height | h-padding | v-padding | font | icon |
|---|---|---|---|---|---|
| `.mini` | 28 | CoreSpacing.sm | CoreSpacing.xs | .footnote | 12 |
| `.small` | 32 | CoreSpacing.md | CoreSpacing.xs | .footnote | 14 |
| `.regular` | 44 | CoreSpacing.lg | CoreSpacing.md | .callout | 16 |
| `.large` | 50 | CoreSpacing.lg | CoreSpacing.lg | .body | 20 |
| `.extraLarge` | 56 | CoreSpacing.xl | CoreSpacing.lg | .title2 | 24 |


---

# 语义颜色（第 3 / 4 层）

⚠️ 第 1 层色阶（`ColorGrade` 的 17 色相 × 10 档）**有意不列入本摘要**——组件里不直接用。

## `BorderColors`（10）

| token | 说明 |
|---|---|
| `Color.borderSubtle` | — |
| `Color.borderDefault` | — |
| `Color.borderStrong` | — |
| `Color.dividerDefault` | — |
| `Color.dividerOpaque` | — |
| `Color.borderMuted` | 比 `borderDefault` 更弱的次要分隔线 / 卡片边框；语义接近 `borderSubtle`， 但取值略强（透明度更高，0.42）。 |
| `Color.borderHover` | 交互态边框的 hover 表现，取 `borderDefault` 的稍强表现作为高亮。 |
| `Color.borderFocus` | 键盘 focus / 强调描边专用。 |
| `Color.borderSelected` | 选中态描边。 |
| `Color.borderEmphasis` | 比 `borderDefault` / `borderStrong` 更具视觉重量，用于需强调的容器边框。 |

## `ContentColors`（13）

| token | 说明 |
|---|---|
| `Color.contentPrimary` | — |
| `Color.contentSecondary` | — |
| `Color.contentTertiary` | — |
| `Color.contentQuaternary` | — |
| `Color.contentPlaceholder` | — |
| `Color.contentInverse` | — |
| `Color.contentOnAccent` | — |
| `Color.contentOnDanger` | — |
| `Color.contentLink` | — |
| `Color.contentDisabled` | — |
| `Color.contentMuted` | 次要文本，如时间戳 / 元数据 / helper text。 |
| `Color.contentSubtle` | 弱化辅助文本（弱于 `contentMuted`），用于占位 / 装饰文本。 |
| `Color.contentOnEmphasis` | 在 emphasis 强调背景上的白色文本，用于通用 emphasis 背景（含中性 emphasis）。 |

## `FillColors`（7）

| token | 说明 |
|---|---|
| `Color.fill` | 为细小形状的叠加填充颜色。 |
| `Color.secondaryFill` | 中等大小形状的叠加填充颜色。 |
| `Color.tertiaryFill` | 大型形状的叠加填充颜色。 |
| `Color.quaternaryFill` | 大区域复杂内容的覆盖填充颜色。 |
| `Color.skeletonBase` | 骨架屏占位底色。 |
| `Color.skeletonHighlight` | 骨架屏 shimmer 扫光高光色。 |
| `Color.specularHighlight` | 扫光高光色（`.shine()` 这类掠过内容的高光带）。 |

## `FunctionalColor`（10）

| token | 说明 |
|---|---|
| `Color.success` | — |
| `Color.info` | — |
| `Color.warning` | — |
| `Color.warningActive` | — |
| `Color.warningDisable` | — |
| `Color.warningHover` | — |
| `Color.danger` | — |
| `Color.dangerActive` | — |
| `Color.dangerDisable` | — |
| `Color.dangerHover` | — |

## `InteractionColors`（19）

| token | 说明 |
|---|---|
| `Color.accent` | 交互强调色，跟随宿主 App 的 AccentColor 资源。 |
| `Color.accentHover` | Hover 态：离背景更远一档，用于指针悬停 / 高亮。 |
| `Color.accentPressed` | 按下态：比 hover 再远离背景一档；混合基色取 `.primary` 以在深浅双模式都成立。 |
| `Color.accentDisabled` | 禁用态：对 accent 降低不透明度，保持色相、只削存在感。 |
| `Color.accentSubtleBackground` | accent 的极淡背景色，用于选中态等大面积低对比场景；走降不透明度而非白混合。 |
| `Color.secondaryAccent` | — |
| `Color.secondaryAccentHover` | — |
| `Color.secondaryAccentPressed` | — |
| `Color.secondaryAccentDisabled` | — |
| `Color.neutralAccent` | — |
| `Color.neutralAccentHover` | — |
| `Color.neutralAccentPressed` | — |
| `Color.neutralAccentDisabled` | — |
| `Color.selectionBackground` | 常规选中态背景：低调的强调色淡染。 |
| `Color.selectionBackgroundEmphasis` | 强调选中态背景：实心 `accent`，与 `contentOnAccent` 白字前景配对。 |
| `Color.hoverBackground` | 中性 hover 底色。 |
| `Color.pressedBackground` | 中性按下底色。 |
| `Color.disabledBackground` | 禁用态底色。 |
| `Color.disabledForeground` | 禁用态前景色。 |

## `MaskColors`（1）

| token | 说明 |
|---|---|
| `Color.maskOpaque` | 纯 alpha 遮罩的**不透明**基色（`α = 1`）。 |

## `StatusColors`（24）

| token | 说明 |
|---|---|
| `Color.statusAccentForeground` | 强调前景色：链接 / focus / 选中态文字。 |
| `Color.statusAccentEmphasis` | 强调实色背景：选中行、激活开关等需要强对比的场景。 |
| `Color.statusAccentMuted` | 强调弱化背景：hover 态。 |
| `Color.statusAccentSubtle` | 强调淡背景：选中高亮。 |
| `Color.statusAccentBorder` | 边框色。 |
| `Color.statusSuccessForeground` | 成功前景色：成功 / 已合并 / CI 通过文字。 |
| `Color.statusSuccessEmphasis` | 成功实色背景。 |
| `Color.statusSuccessMuted` | 成功弱化背景。 |
| `Color.statusSuccessSubtle` | 成功淡背景。 |
| `Color.statusSuccessBorder` | 边框色。 |
| `Color.statusAttentionForeground` | 警示前景色：警告 / 待处理 / 待审阅文字。 |
| `Color.statusAttentionEmphasis` | 警示实色背景。 |
| `Color.statusAttentionMuted` | 警示弱化背景。 |
| `Color.statusAttentionSubtle` | 警示淡背景。 |
| `Color.statusAttentionBorder` | 边框色。 |
| `Color.statusDangerForeground` | 危险前景色：错误 / 删除 / 已拒绝文字。 |
| `Color.statusDangerEmphasis` | 危险实色背景。 |
| `Color.statusDangerMuted` | 危险弱化背景。 |
| `Color.statusDangerSubtle` | 危险淡背景。 |
| `Color.statusDangerBorder` | 边框色。 |
| `Color.statusDoneForeground` | 完成前景色：已完成 / 已关闭 / 已解决文字。 |
| `Color.statusDoneEmphasis` | 完成实色背景。 |
| `Color.statusDoneMuted` | 完成弱化背景。 |
| `Color.statusDoneSubtle` | 完成淡背景。 |

## `SurfaceColors`（15）

| token | 说明 |
|---|---|
| `Color.surfaceBase` | — |
| `Color.surfaceRaised` | — |
| `Color.surfaceElevated` | — |
| `Color.surfaceGrouped` | — |
| `Color.surfaceGroupedRaised` | — |
| `Color.surfaceGroupedElevated` | — |
| `Color.surfaceMuted` | — |
| `Color.surfaceInteractive` | — |
| `Color.surfaceOverlay` | 浮层表面背景（服务 `.surface(.floating)`：toast、浮动工具栏、底部栏）。 |
| `Color.surfaceCanvas` | 页面级最底层背景，指向 `systemGroupedBackground`。 |
| `Color.surfaceCanvasSubtle` | 次级内容区背景（侧栏 / 表格头）。 |
| `Color.surfaceCanvasInset` | 凹陷 well / 输入框内底色，指向 `FillColors.tertiaryFill`。 |
| `Color.surfacePanel` | 面板 / 覆盖层容器背景（服务 `.surface(.panel)` 与 `.surface(.overlay)`）。 |
| `Color.surfaceSidebar` | 侧栏 / 导航容器背景，走 `surfaceElevated`——**在 iOS 上**与画布、内容表面拉开三档； macOS 上三者同色（系统无分层背景 API）。 |
| `Color.surfaceCard` | 卡片容器背景，别名 `surfaceRaised`——**在 iOS 上**浮于画布之上、深色下不与画布塌缩同色； macOS 上与画布同色。 |

## `SystemBackgroundColors`（6）

| token | 说明 |
|---|---|
| `Color.systemBackground` | 界面主背景的颜色。 |
| `Color.secondarySystemBackground` | 主要背景上层内容的颜色。 |
| `Color.tertiarySystemBackground` | 次要背景上层内容的颜色。 |
| `Color.systemGroupedBackground` | 分组界面的主要背景颜色。 |
| `Color.secondarySystemGroupedBackground` | 分组界面主要背景上层内容的颜色。 |
| `Color.tertiarySystemGroupedBackground` | 内容层叠在分组界面次要背景之上的颜色。 |

## `SystemLabelColors`（10）

| token | 说明 |
|---|---|
| `Color.label` | 主要文本颜色，桥接 `UIColor.label` / `NSColor.labelColor`。 |
| `Color.secondaryLabel` | 次要文本颜色，桥接 `UIColor.secondaryLabel` / `NSColor.secondaryLabelColor`。 |
| `Color.tertiaryLabel` | 三级文本颜色，桥接 `UIColor.tertiaryLabel` / `NSColor.tertiaryLabelColor`。 |
| `Color.quaternaryLabel` | 四级文本颜色，桥接 `UIColor.quaternaryLabel` / `NSColor.quaternaryLabelColor`。 |
| `Color.darkText` | 浅色背景上文本的固定深色（`UIColor.darkText`）。 |
| `Color.lightText` | 暗色背景上文本的固定浅色（`UIColor.lightText`）。 |
| `Color.placeholderText` | 输入控件占位文本的颜色，桥接 `UIColor.placeholderText` / `NSColor.placeholderTextColor`。 |
| `Color.separator` | 分隔线颜色，允许下层内容透出，桥接 `UIColor.separator` / `NSColor.separatorColor`。 |
| `Color.opaqueSeparator` | 不透明的分隔线颜色，完全遮住下层内容（`UIColor.opaqueSeparator`）。 |
| `Color.link` | 可点击链接文本的颜色，桥接 `UIColor.link` / `NSColor.linkColor`。 |


---

# 组件与类型

## `CoreDesign`

### `Components/Avatar/Avatar.swift`

- **`Avatar`** *: View* — **表面角色**: 内容.

### `Components/AvatarGroup/AvatarGroup.swift`

- **`AvatarGroup`** *<Avatars: View>: View* — **表面角色**: 内容.
- *enum* **`AvatarGroupLayout`**: `.overlapped`, `.spaced`, `.grid`, `.countOnly`

### `Components/Badge/Badge.swift`

- **`Badge`** *<Label: View>: View* — **表面角色**: 控件.
- *enum* **`BadgeVariant`**: `.info`, `.success`, `.warning`, `.danger`, `.neutral`

### `Components/Banner/Banner.swift`

- **`Banner`** *<Label: View>: View* — 页内信息表面，按状态语义配描边或填充；浮层反馈请改用 `ToastHost`。
- **`PlainBannerStyle`** *: BannerStyle* — 默认的 Banner 外观：纯色背景 + 同色系前景，无描边。
- **`BorderedBannerStyle`** *: BannerStyle* — 带同色系描边的 Banner 外观：背景 + `CoreBorderWidth.thin` 描边。
- *protocol* **`BannerStyle`** — `Banner` 视觉外观的扩展点，形态对齐 Apple `ButtonStyle` / `ToggleStyle`。

### `Components/BottomInputBar/BottomInputBar.swift`

- **`BottomInputBar`** *: View* — 浮层输入条。

### `Components/Button/AsyncButton.swift`

- **`AsyncButton`** *<Label: View>: View* — 把 async 闭包封装成按钮的视图组件。

### `Components/Button/ButtonRoleStyleRole.swift`

- *enum* **`ButtonRoleStyleRole`**: `.primary`, `.secondary`, `.tertiary`, `.warning`, `.danger`

### `Components/Button/styles/CircularGlassButtonStyle.swift`

- **`CircularGlassButtonStyle`** *: ButtonStyle* — 圆形玻璃浮按钮样式。

### `Components/Button/styles/CoreBorderlessButtonStyle.swift`

- **`CoreBorderlessButtonStyle`** *: PrimitiveButtonStyle* — 无边框 / 无背景按钮样式。

### `Components/Button/styles/ExtendedFloatButtonStyle.swift`

- **`ExtendedFloatButtonStyle`** *: ButtonStyle* — 胶囊形悬浮按钮样式（icon + 文字的 extended FAB 形态）。

### `Components/Button/styles/LightButtonStyle.swift`

- **`LightButtonStyle`** *: ButtonStyle* — 次要操作按钮样式（"light button"）。

### `Components/Button/styles/SolidButtonStyle.swift`

- **`SolidButtonStyle`** *: ButtonStyle* — 主操作按钮样式（"solid button"）。

### `Components/Card/Card.swift`

- **`Card`** *<Content: View>: View* — `.surface(.content)` 的**具名封装** + 默认内边距——iOS 分组卡片/内容容器的最薄外壳。
- *enum* **`CardKind`**: `.content`, `.grouped`

### `Components/Carousel/Carousel.swift`

- **`Carousel`** *<Data: RandomAccessCollection, ID: Hashable, Content: View>: View where Data.Element: Identifiable, Data.Element.ID == ID* — **表面角色**: 内容.

### `Components/CheckBox/CheckBox.swift`

- **`CheckBoxToggleStyle`** *: ToggleStyle* — 复选框样式 / CheckBox toggle style：把 SwiftUI `Toggle` 渲染为左侧方框 + 右侧 label 的复选框形态。

### `Components/Form/Form.swift`

- **`LabelIcon`** *: View* — 表单 / 列表行 leading 位置使用的方形 app-tile 风格图标。
- **`ChevronRightIcon`** *: View* — 列表行 trailing 的「可进入下一级」指示符，用 `chevron.forward` 以在 RTL 下自动镜像。
- **`DangerIcon`** *: View* — 列表行 trailing 位置的危险 / 错误状态指示符（实心感叹号圆形）。

### `Components/InsetGroupedSection/InsetGroupedSection.swift`

- **`InsetGroupedSection`** *<Content: View>: View* — iOS `.insetGrouped` 分组容器的视觉复刻——只复刻观感，不复刻 `List` 的数据 / 滚动 / 编辑能力。
- *enum* **`SettingsDividerInset`**: `.iconAligned`, `.textAligned`, `.custom`, `.let`

### `Components/ListRow/ListRow.swift`

- **`ListRow`** *<Leading: View, Trailing: View, Label: View>: View* — 内容层列表行：无默认玻璃、无默认卡片化、不提供选中态，背景落在 `View.surface(.canvas)`。

### `Components/PinCode/PinCode.swift`

- **`PinCode`** *: View* — **表面角色**: 控件.

### `Components/ProgressBar/ProgressBar.swift`

- **`ProgressBar`** *: View* — —

### `Components/ProgressIndicator/ProgressIndicator.swift`

- **`ProgressIndicator`** *: View* — **表面角色**: 内容.

### `Components/Radio/Radio.swift`

- **`RadioGroup`** *<SelectionValue: Hashable & Sendable>: View* — `Binding<SelectionValue>` 驱动的互斥选择组，与 `CheckBoxToggleStyle` 同套 token、方框换圆点。

### `Components/Rating/Rating.swift`

- **`Rating`** *: View* — **表面角色**: 内容.
- **`StarRatingStyle`** *: RatingStyle* — 默认评分外观：一排五角星，按 `value` 与星索引计算填充比例（整星 / 半星 / 空星三态）， 用 `.mask` 裁切实现半星视觉。
- *protocol* **`RatingStyle`** — `Rating` / `RatingDisplay` 视觉外观的扩展点，形态对齐 Apple `ButtonStyle` / `ToggleStyle` 与本仓既有的 `BannerStyle` / `SegmentedControlStyle`。

### `Components/Rating/RatingDisplay.swift`

- **`RatingDisplay`** *: View* — **表面角色**: 内容.

### `Components/SearchField/SearchField.swift`

- **`SearchField`** *: View* — 紧凑的搜索 / 筛选控件：leading 放大镜图标 + 可选清除动作 + 明确的焦点环， **无默认 Liquid Glass**。

### `Components/Section/SectionFooter.swift`

- **`SectionFooter`** *: View* — 分组页脚，即跟在分组下方的说明文字：`.footnote` 字号、`contentSecondary` 灰、不大写。

### `Components/Section/SectionHeader.swift`

- **`SectionHeader`** *: View* — 分组页眉，复刻 iOS `.insetGrouped` 的分组标题：大写、`contentSecondary` 灰、`.footnote` 字号。

### `Components/SegmentedControl/SegmentedControl.swift`

- **`SegmentedControl`** *<Item: Hashable>: View* — GitHub-like density on an Apple-native control surface. 外观由环境注入的 `SegmentedControlStyle` 决定，默认 `GlassSegmentedControlStyle`。
- **`GlassSegmentedControlStyle`** *: SegmentedControlStyle* — 默认外观：Liquid Glass 外壳。
- **`PlainSegmentedControlStyle`** *: SegmentedControlStyle* — 纯色外壳外观（此前 `glass: false`）。
- *protocol* **`SegmentedControlStyle`** — `SegmentedControl` 视觉外观的扩展点，形态对齐 `BannerStyle` / Apple `ButtonStyle`。

### `Components/Separator/Separator.swift`

- **`Separator`** *: View* — 可控 inset 的分隔线，默认 hairline 宽度、颜色走 `Color.dividerDefault`。
- *enum* **`Inset`**: `.edgeToEdge`, `.leading`, `.let`

### `Components/SettingsRow/SettingsRow.swift`

- **`SettingsRowChevron`** *: View* — 设置行尾部的 disclosure chevron（">"），供 accessory 组合。
- **`SettingsRow`** *<Accessory: View>: View* — iOS 设置页 / 偏好面板的行：可着色图标方块 + 标题 + 可选副标题 + 尾部 accessory。

### `Components/Sidebar/Sidebar.swift`

- **`SidebarSection`** *<Content: View>: View* — 带标题的侧栏分组容器。
- **`SidebarNavigationRow`** *<Leading: View>: View* — 带选中态的主导航行。
- **`SidebarUtilityRow`** *: View* — 次级工具行，可选尾部装饰。
- **`SidebarDocumentRow`** *: View* — 带尾部 detail 文本的文档行。
- **`SidebarTagRow`** *: View* — 以 `#` 字形开头的标签行。
- **`SidebarStatusFooter`** *: View* — 状态点 + 标题/详情文本的页脚。
- *enum* **`SidebarUtilityRowPresentation`**: `.iconLeading`, `.textOnly`

### `Components/Skeleton/Skeleton.swift`

- **`Skeleton`** *<Placeholder: View, Content: View>: View* — **表面角色**: 内容.
- **`SkeletonLine`** *: View* — 文本行占位形状：圆角矩形 + 固定高度，可指定条数模拟多行文本。
- **`SkeletonRect`** *: View* — 图片 / 卡片占位形状：矩形块，尺寸由调用方指定。
- **`SkeletonCircle`** *: View* — 头像占位形状：圆形，直径由调用方指定。

### `Components/StateLabel/StateLabel.swift`

- **`StateLabel`** *<Label: View>: View* — **表面角色**: 控件.
- *enum* **`StateLabelStyle`**: `.active`, `.draft`, `.completed`, `.cancelled`, `.inProgress`, `.error`

### `Components/StatusLevel.swift`

- *enum* **`StatusLevel`**: `.info`, `.success`, `.warning`, `.danger`

### `Components/Steps/Steps.swift`

- **`Steps`** *: View* — **表面角色**: 内容.
- *enum* **`StepsAxis`**: `.horizontal`, `.vertical`
- *enum* **`StepsIndicatorStyle`**: `.dot`, `.numbered`
- *enum* **`StepsPresentation`**: `.steps`, `.segmentedBar`, `.navigation`, `.text`

### `Components/Style/CoreDisclosureGroupStyle.swift`

- **`CoreDisclosureGroupStyle`** *: DisclosureGroupStyle* — 系统 `DisclosureGroup` 的 CoreDesign 视觉外观——只重排 `label` / `content`，展开状态仍由系统驱动。

### `Components/Style/CoreLabelStyle.swift`

- **`CoreLabelStyle`** *: LabelStyle* — 系统 `Label` 的 CoreDesign 视觉外观——只重排 `makeBody(configuration:)` 交出的 `icon` / `title`。

### `Components/Style/CoreLabeledContentStyle.swift`

- **`CoreLabeledContentStyle`** *: LabeledContentStyle* — 系统 `LabeledContent` 的 CoreDesign 视觉外观——只重排 `makeBody(configuration:)` 交出的 `label` / `content`。

### `Components/Style/CoreProgressViewStyle.swift`

- **`CoreProgressViewStyle`** *: ProgressViewStyle* — 系统 `ProgressView` 的 CoreDesign 视觉外观——只重绘 `makeBody(configuration:)` 交出的内容，强调色经 `ShapeStyle.tint` 取值，所以 `.tint(_:)` 对它生效。

### `Components/Style/Descriptions.swift`

- **`Descriptions`** *<Content: View>: View* — 描述列表：把传入的 `LabeledContent` 行按 1/2 列排布，再交给 `InsetGroupedSection` 渲染。
- *enum* **`DescriptionsColumns`**: `.one`, `.two`
- *enum* **`DescriptionsDividerDensity`**: `.none`, `.row`

### `Components/TabBar/UnderlinedTabBar.swift`

- **`UnderlinedTabBar`** *<Item: Hashable, Trailing: View>: View* — 主导航 chrome：选中项以一条 `Color.accent` 下划线加字重标记，背景由宿主 scene 提供。

### `Components/Tag/Tag.swift`

- **`Tag`** *<Label: View>: View* — 控件层的分类标签。

### `Components/TagInput/TagInput.swift`

- **`TagInput`** *: View* — `Binding<[String]>` 驱动的标签输入框：已有标签以 chip 形式展示，末尾内联一个 文本输入框，回车或逗号提交新标签，点击 chip 上的删除按钮移除标签。

### `Components/Timeline/Timeline.swift`

- **`Timeline`** *: View* — **表面角色**: 内容.
- *enum* **`TimelineLayout`**: `.vertical`, `.alternate`, `.horizontal`, `.grouped`

### `Components/Toast/Toast.swift`

- *enum* **`ToastPresentation`**: `.floatingCapsule`, `.fullWidthBanner`, `.centeredHUD`

### `Environment/EnergyPolicy.swift`

- *enum* **`RenderPolicy`**: `.full`, `.reduced`, `.paused`
- *enum* **`MotionPresentation`**: `.hidden`, `.resting`, `.animated`

### `Layout/FlowLayout.swift`

- **`FlowLayout`** *: Layout* — Tag 自动换行布局容器。

### `Modifier/FloatingGlassModifier.swift`

- **`FloatingGlassModifier`** *<S: InsettableShape>: ViewModifier* — —

### `Modifier/SpinningModifier.swift`

- **`SpinningModifier`** *: ViewModifier* — 为任意内容叠加加载指示（吸收 Semi Design `Spin` 能力，Issue #172）。
- *enum* **`SpinningPresentation`**: `.overlay`, `.topBar`, `.inline`

### `Modifier/SurfaceModifier.swift`

- *enum* **`SurfaceKind`**: `.canvas`, `.content`, `.control`, `.floating`, `.overlay`, `.grouped`, `.canvasSubtle`, `.panel`, `.sidebar`, `.card`

### `Modifier/TelegramGlassButtonModifier.swift`

- **`TelegramGlassButtonModifier`** *<S: InsettableShape>: ViewModifier* — Telegram 风格的玻璃按钮四层结构，抽取为可复用 modifier。

### `Tokens/CoreElevation.swift`

- *enum* **`CoreElevation`**: `.none`, `.small`, `.medium`, `.large`
- *enum* **`Level`**: `.none`, `.small`, `.medium`, `.large`

### `Tokens/CoreTypography.swift`

- *enum* **`CoreTypography`**: `.largeTitle`, `.title`, `.title2`, `.title3`, `.headline`, `.body`, `.callout`, `.subheadline`, `.footnote`, `.caption`, `.captionMono`, `.caption2`
- *enum* **`Token`**: `.largeTitle`, `.title`, `.title2`, `.title3`, `.headline`, `.body`, `.callout`, `.subheadline`, `.footnote`, `.caption`, `.captionMono`, `.caption2`

## `CoreDesignEffects`

### `AnimatedMeshGradient.swift`

- **`AnimatedMeshGradient`** *: View* — 一块**持续漂移**的 3 × 3 网格渐变，用作背景面。

### `BeforeAfterSlider.swift`

- **`BeforeAfterSlider`** *<Before: View, After: View>: View* — 拖动分隔线对比"之前 / 之后"两张图的滑块。
- *enum* **`BeforeAfterSliderLabels`**: `.hidden`, `.standard`, `.shown`

### `BlurTransition.swift`

- **`BlurTransition`** *: Transition* — 视图进出时内容失焦并淡出（进入时反向合焦）。

### `BoingTransition.swift`

- **`BoingTransition`** *: Transition* — 视图弹进来：从很小放大、**越过原尺寸**再回落坐定；离开时反过来。

### `CharSphere.swift`

- **`CharSphere`** *: View* — 一颗**自转的字球**：调用方给一组字，它们按球面 Fibonacci 铺满球面并随球自转， 背面的字被剔除以免与正面糊在一起。

### `DotSphere.swift`

- **`DotSphere`** *: View* — 一颗**自转的点球**：N 个点按球面 Fibonacci（Vogel 螺旋）铺满球面， 单轴透视让近侧的点更大更实。

### `FilmExposureTransition.swift`

- **`FilmExposureTransition`** *: Transition* — 视图进出时像一格胶片被过度曝光：亮度先冲上去、饱和度与对比度一路洗白，然后消失。

### `FlickerTransition.swift`

- **`FlickerTransition`** *: Transition* — 视图像一支接触不良的灯管那样忽明忽暗地出现 / 消失。

### `FlipTransition.swift`

- **`FlipTransition`** *: Transition* — 视图进出时像一张卡片那样翻过去：带透视的 3D 旋转 + 淡入淡出。

### `FullScreenButton.swift`

- **`FullScreenButton`** *<Label: View, Destination: View>: View* — 一张可点的卡片，点开时**几何匹配地放大成整屏**——App Store / 照片 / 音乐里 那种"卡片自己长成一页"的效果，而不是从底部滑上来一个模态。

### `GlowSweep.swift`

- **`GlowSweep`** *<Content: View>: View* — `GlowSweep { }` —— 一段辉光**沿内容边框转圈**，表示"正在生成 / 正在思考"。

### `LightSweep.swift`

- **`LightSweep`** *<Content: View>: View* — `LightSweep { }` —— 一道斜向光带在内容**表面左右掠过**，表示"正在等待 / 正在传输"。

### `MaskRevealTransitions.swift`

- **`MaskRevealTransition`** *: Transition* — `iris` / `wipe` / `blinds` / `clock` / `glare` / `dissolve` 六种「揭示型」转场。

### `MicroInteractionSupport.swift`

- *enum* **`MicroInteractionStrength`**: `.subtle`

### `OrbitingLogos.swift`

- **`OrbitingLogos`** *<Data: RandomAccessCollection, Logo: View, Center: View>: View* — 四圈同心点环持续自转，调用方的 logo 均匀落在最外环上随之巡游， 每隔一小段时间轮到一个 logo **弹出放大**、把附近的点挤开，中心是调用方的视图。

### `ParticleTransition.swift`

- **`ParticleTransition`** *: Transition* — 视图进出时，内容轻微缩放淡出，同时一圈粒子向外飞散（进入时反向汇聚）。

### `PolarMoveTransition.swift`

- **`PolarMoveTransition`** *: Transition* — 视图沿**任意极角**平移进出（同侧：从哪来、回哪去）。

### `Rotate3DTransition.swift`

- **`Rotate3DTransition`** *: Transition* — 视图进出时绕任意轴翻滚，同时向纵深退一点。

### `ScanningOverlay.swift`

- **`ScanningOverlay`** *<Content: View>: View* — `ScanningOverlay { }` —— 一道横向光束在内容上**上下往复扫描**，表示"正在识别 / 正在处理"。

### `Shine.swift`

- **`Shine`** *<Content: View>: View* — `Shine { }` —— **容器视图形态**的一次性高光，包住内容即可用。

### `SkidTransition.swift`

- **`SkidTransition`** *: Transition* — 视图从一侧滑进来，**冲过头一点**再刹住，途中车身跟着甩一个小角度；离开时原路退出。

### `SnapshotTransition.swift`

- **`SnapshotTransition`** *: Transition* — 视图像一张即显相纸那样出现：先是一下快门白场，随后从洗白的低对比逐渐"显影"到常态。

### `Spin.swift`

- *enum* **`SpinDirection`**: `.clockwise`

### `SwooshTransition.swift`

- **`SwooshTransition`** *: Transition* — 视图**穿行而过**：从一侧飞进来、从另一侧飞出去，途中带一层随速度增强的动态模糊。

### `TransitionSupport.swift`

- *enum* **`TransitionTravel`**: `.short`, `.regular`, `.long`
- *enum* **`TransitionAxis3D`**: `.horizontal`, `.vertical`, `.depth`, `.tilted`

### `TypewriterText.swift`

- **`TypewriterText`** *: View* — 逐字揭示的打字机文本。
- *enum* **`TypewriterSpeed`**: `.slow`, `.regular`, `.fast`

## `CoreDesignCharts`

### `ActivityHeatmap.swift`

- **`ActivityHeatmap`** *<Day: HeatmapDay>: View* — 贡献热力图（GitHub 那种按周排列的日格）。

### `ChartSupport.swift`

- *protocol* **`ChartValue`** — 图表数据点的最小契约。
- *protocol* **`HeatmapDay`** — 热力图的一天。
- *protocol* **`GraphNode`** — 网络图的一个节点。

### `NetworkGraph.swift`

- **`NetworkGraph`** *<Node: GraphNode>: View* — 力导向网络图。

### `RadarChart.swift`

- **`RadarChart`** *<Value: ChartValue>: View* — 雷达图（蛛网图）。

### `RingChart.swift`

- **`RingChart`** *<Value: ChartValue>: View* — 活动环。


---

# Modifier / Transition 入口点

共 31 个（按 `Host.member` 去重，含参重载算一条）。

| target | 入口 | 说明 |
|---|---|---|
| `CoreDesign` | `.bannerStyle` on `View` | 为子树中的所有 `Banner` 设置外观。 |
| `CoreDesign` | `.bottomInputBar` on `View` | — |
| `CoreDesign` | `.bottomInputBarChip` on `View` | — |
| `CoreDesign` | `.ratingStyle` on `View` | 为子树中的所有 `Rating` / `RatingDisplay` 设置外观。 |
| `CoreDesign` | `.segmentedControlStyle` on `View` | 为子树中的所有 `SegmentedControl` 设置外观（对齐 `View.bannerStyle(_:)`）。 |
| `CoreDesign` | `.makeUIView` on `View` | — |
| `CoreDesign` | `.updateUIView` on `View` | — |
| `CoreDesign` | `.configure` on `View` | — |
| `CoreDesign` | `.updateForCurrentTraits` on `View` | — |
| `CoreDesign` | `.sidebarSelectedBackground` on `View` | `isSelected` 为 true 时施加侧栏选中态背景。 |
| `CoreDesign` | `.skeletonShimmer` on `View` | 骨架屏 shimmer 扫光叠加。 |
| `CoreDesign` | `.toastHost` on `View` | 在当前 view 子树挂载一个 scene-scoped `ToastHost`，并在 `edge` 方向以 `safeAreaInset` 渲染当前队列的首条 toast。 |
| `CoreDesign` | `.bordered` on `View` | 叠加一圈描边 / Add a border.  - Parameters: - style: 描边样式，任意 `ShapeStyle`（含 `Color` 与渐变）。 |
| `CoreDesign` | `.buttonBackground` on `View` | — |
| `CoreDesign` | `.buttonChrome` on `View` | — |
| `CoreDesign` | `.coreFont` on `View` | 施加 CoreDesign 排版 token（直接取系统文本样式，随 Dynamic Type 缩放）。 |
| `CoreDesign` | `.floatingGlass` on `View` | — |
| `CoreDesign` | `.focusRing` on `View` | 给视图添加一个焦点环。 |
| `CoreDesign` | `.spinning` on `View` | 为内容整体叠加加载遮罩。 |
| `CoreDesign` | `.surface` on `View` | 一次性施加容器表面 token（背景 + 1pt 描边 + 圆角）。 |
| `CoreDesign` | `.coreShadow` on `View` | 应用 CoreDesign elevation 阴影。 |
| `CoreDesignEffects` | `.confetti` on `View` | `trigger` 变化时喷发一次彩纸。 |
| `CoreDesignEffects` | `.haptic` on `View` | `trigger` 变化时播一次触感反馈。 |
| `CoreDesignEffects` | `.jump` on `View` | `trigger` 变化时跳一次。 |
| `CoreDesignEffects` | `.reduceMotionFallback` on `View` | — |
| `CoreDesignEffects` | `.ping` on `View` | `trigger` 变化时，从视图背后扩散一组圆环。 |
| `CoreDesignEffects` | `.rise` on `View` | `trigger` 变化时，从视图上方浮起一段文字。 |
| `CoreDesignEffects` | `.shake` on `View` | `trigger` 的值每次变化时，横向抖动一次。 |
| `CoreDesignEffects` | `.shine` on `View` | `trigger` 变化时，让一道高光扫过本视图（遮罩到内容形状）。 |
| `CoreDesignEffects` | `.spin` on `View` | `trigger` 变化时旋转一整圈。 |
| `CoreDesignEffects` | `.spray` on `View` | `trigger` 变化时向上喷出一束符号粒子。 |


---

# 生成基数

| 节 | 计数 | 下界 |
|---|---|---|
| spacing | 11 | 11 |
| radius | 5 | 5 |
| border | 5 | 5 |
| typography | 12 | 12 |
| elevation | 4 | 4 |
| controlsize | 5 | 5 |
| colors | 115 | 115 |
| components | 89 | 89 |
| enums | 30 | 30 |
| viewext | 31 | 31 |

