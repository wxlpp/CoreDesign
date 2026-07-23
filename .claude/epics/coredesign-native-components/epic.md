---
name: coredesign-native-components
status: backlog
created: 2026-07-23T04:33:46Z
updated: 2026-07-23T04:33:46Z
progress: 0%
prd: .claude/prds/coredesign-native-refresh.md
github: (will be set on sync)
---

# Epic: coredesign-native-components

> `coredesign-native-refresh` PRD 的 **Phase 2（新组件）**，覆盖 FR-10 ~ FR-12 与 FR-13 的 `0.4.0` 部分，交付 `0.4.0`。
> Phase 1（`coredesign-native-foundation`，`0.3.0`）已合入 main 并通过视觉终审——本 epic 在它之上补齐组件。

## Overview

在 Phase 1 换好的 Apple HIG 地基上,补齐三类 iOS 应用高频需要、而 SwiftUI 未直接提供的东西:分组设置行体系、基础容器与分隔件、以及给系统控件配套的 `.core` style。原则不变——**系统给好的不重造**(`Toggle` / `Slider` / `List` / `Form` 一律用系统的),只补系统没给好、每个项目都要手搓的那部分。

本 epic 的第一个任务不是新组件,而是**修 Phase 1 遗留的一处表面色塌缩**——它是后面所有容器类组件的地基,不修则 `Card` 与 `InsetGroupedSection` 全部隐形。详见 ADR-1。

## Architecture Decisions

### ADR-1 · 先修 `SurfaceKind` 表面色塌缩,再建容器(偏离 PRD FR-11 字面,符合其意图)

PRD FR-11 写「`Card` 是 `.surface(.content)` 的具名封装」。但 Phase 1 的视觉终审(#125)与 issue #136 查明:

```
.surface(.content) → surfaceCard → surfaceCanvas → systemGroupedBackground（页面画布）
```

即 `.content` 的背景**与页面画布完全同色**,深色纯黑下 `Card` 会彻底隐形。iOS 的卡片/分组容器本该是 `secondarySystemGroupedBackground`(浮在画布之上),库里 `surfaceRaised` 已经指对,只是 `.content` / `.card` 两个 `SurfaceKind` case 指错了目标(指向 `surfaceCard` = 画布色)。

PRD 写于 Phase 1 之前,不知道地基会塌缩。**Task 001 改 `surfaceCard` token 的别名(`surfaceCanvas` → `surfaceRaised`),`.content` / `.card` 两个 case 自动跟随**,`Card` 才封装得出一个真正可见的卡片。(评审定死走 token 别名而非改 case:可测 + 修掉公开 token 名实相悖的陷阱。)这是对 PRD 意图(Card 是能看见的容器)的忠实,而非对其字面(封装 `.content`)的机械执行。

顺带按 #136 审视:9 个 `SurfaceKind` 实际只映射到 3 个背景——修 `.content`/`.card` 的同时评估是否收敛档位,但收敛是可选项,不阻塞后续。

### ADR-2 · 自建容器只复刻「视觉」,不复刻 `List` 的能力

`InsetGroupedSection` 复刻 iOS 分组容器的**视觉**(圆角、分隔线 leading inset、页眉页脚),而非 `List` 的数据/滚动/编辑。理由(PRD FR-10):原生 `List` 只能整体作滚动容器,无法把单个分组嵌进已有的 `ScrollView` / `VStack`——而「自定义页面里放一两个设置分组」才是最常见用法。`SettingsRow` 设计为既能进 `InsetGroupedSection`、也能直接作原生 `List` 的行。

### ADR-3 · `.core` style 的强调色必须走 `.tint` 通路,不得写死静态 accent

FR-12 硬约束:`.core` style 的 `makeBody` 中强调色须经 `TintShapeStyle`(`.tint`)或 configuration 取,**不得写死 `Color.accent`**。否则调用方 `.tint(_:)` 对这些控件静默失效——那既违反 US-3「保留系统控件全部原生行为」,又废掉 Phase 1(FR-4)给出的「按视图 tint 走原生通路」这条逃生口。库里 `ProgressIndicator` / `ProgressBar` 已有 tint 先例可参考。

### ADR-4 · Phase 2 是纯新增,破坏面小,但视觉必须实机验

与 Phase 1 不同,本 epic 基本不删不改公开符号(唯一的 token 指向修改是 ADR-1 的 `.content`/`.card`,属同名换值,记入 BREAKING-CHANGES)。但**全部交付物是视觉组件**——机械判据(编译/测试/grep)证明不了它们好不好看。Phase 1 的教训:深色语义色缺陷、320×480 兼容模式、`.preferredColorScheme` 泄漏,全是只有实机截图才发现的。本 epic 的视觉终审(Task 005)是硬门,不是可选。

## Technical Approach

### 表面色地基(`Modifier/SurfaceModifier.swift`、`Colors/SurfaceColors.swift`)

Task 001:`.content` / `.card` 的 `SurfaceKind.background` 从 `surfaceCard`(= 画布色)改指 `surfaceRaised`(= `secondarySystemGroupedBackground`)。加守卫测试:`.content` 与 `.canvas` 在深色下不同色(复用 Phase 1 的 `SurfaceContrastTests` 模式)。

### 基础容器(`Components/Card/`、`Components/Separator/`、`Components/Section/`)

`Card`(`.surface(.content)` 具名封装 + 默认内边距)、`Separator(inset:)`、`SectionHeader` / `SectionFooter`。

### 分组设置行(`Components/InsetGroupedSection/`、`Components/SettingsRow/`)

`InsetGroupedSection`(圆角分组容器 + 可选页眉页脚 + 行间分隔线自动 leading inset)、`SettingsRow`(图标方块可着色 + 标题 + 可选副标题 + 尾部 accessory:value / chevron / `Toggle` / 任意视图)。

### 系统控件 style(`Components/Style/` 或各 style 同名文件)

`Toggle` / `TextField` / `ProgressView` / `Label` / `DisclosureGroup` 各一个 `.core` style,经对应 style 协议的静态成员暴露。强调色走 `.tint`。

## Implementation Strategy

四段:

1. **修地基**(001)——SurfaceKind 塌缩。后面所有容器的前提。
2. **建组件**(002 基础容器 ∥ 004 style 套件;003 分组设置行依赖 001+002)——002 与 004 无文件冲突可并行;003 复用 002 的 Separator/SectionHeader。
3. **看**(005)——视觉终审,实机复刻一屏 iOS 设置页(Success Criteria #10)。
4. **发**(006)——BREAKING-CHANGES 0.4.0、组件索引、快照、`0.4.0` tag。

## Task Breakdown Preview

| # | 任务 | 依赖 | 并行 |
|---|---|---|---|
| 001 | 修 `SurfaceKind` 表面色塌缩(`.content`/`.card` → raised) | — | ❌ |
| 002 | 基础容器:`Card` / `Separator` / `SectionHeader` / `SectionFooter` | 001 | ✅ 与 004 |
| 003 | 分组设置行:`InsetGroupedSection` / `SettingsRow` | 001, 002 | ❌ |
| 004 | 系统控件 `.core` style 套件(5 个,强调色走 `.tint`) | — | ✅ 从起点起 |
| 005 | 视觉终审:实机复刻一屏 iOS 设置页 + 深浅双模式 | 002, 003, 004 | ❌ |
| 006 | 文档与发版:BREAKING-CHANGES 0.4.0 / 组件索引 / 快照 / `0.4.0` tag | 005 | ❌ |

共 6 个任务。

## Dependencies

### 内部
- 002 依赖 001:容器需要 raised 背景与画布拉开。**004 不依赖 001**(评审 S-1:style 套件不消费 surface),可从 epic 起点即与 001 并行。
- 003 依赖 002:分组内的分隔线与页眉复用 `Separator` / `SectionHeader`。
- 005 依赖 002+003+004:要一屏内同时摆出这些组件才谈得上「复刻设置页」。
- 002 与 004、004 与 001 均无文件冲突,可并行。

### 外部
- SwiftUI iOS 26 / macOS 26:`Toggle`/`TextField`/`ProgressView`/`Label`/`DisclosureGroup` 的 style 协议、`TintShapeStyle`、`.glassEffect()`。
- `ios-visual-reviewer` agent:Task 005 判定方。
- Phase 1 的 `SurfaceContrastTests` / 预览宿主(已修好 402×874 全屏 + colorScheme 不泄漏)。

## Success Criteria (Technical)

对齐 PRD Success Criteria,本 epic 负责第 10 条(Phase 2 专属)及新增组件的可访问性/视觉:

1. `swift build` / `swift test` / iOS 腿 / downstream-probe / 预览宿主 全绿。
2. `.content` 与 `.canvas` 在**深色**下不同色(守卫测试,跑在 iOS 腿)。
3. 5 个 `.core` style 对 `.tint(_:)` 真实响应(测试或实机证明,不得写死 accent)。
4. 全部新交互组件在 `.regular` 下可点击高度 ≥ 44pt。
5. `InsetGroupedSection` + `SettingsRow` 能在**不写任何 CoreDesign 之外样式代码**的前提下复刻一屏 iOS 设置页(preview + 实机截图为证)——PRD Success Criteria #10。
6. 视觉终审(`ios-visual-reviewer`)通过,深浅双模式无「非原生 / 不可见」类阻断项。
7. `docs/BREAKING-CHANGES.md` 的 `0.4.0` 条目含 `.content`/`.card` 指向变更(同名换值),并把 Phase 1 里标注「将于 0.4.0 提供」的替代物落实。

## Estimated Effort

- 001:半天,改两个 case + 守卫测试,但它是全 epic 的地基。
- 002:1 天,四个容器组件。
- 003:1.5–2 天,`SettingsRow` 的 accessory 多态 + 分隔线 leading inset 对齐是本 epic 最细的活。
- 004:2 天,5 个 style 各自的 `.tint` 接入 + 深浅态验证。
- 005:1 天,含视觉评审的修复轮次。
- 006:1 天。

合计约 7–8 天。关键路径 001 → 002 → 003 → 005 → 006;004 搭 002 并行。

## Tasks Created

- [ ] 001.md - 修 SurfaceKind 表面色塌缩 (parallel: false)
- [ ] 002.md - 基础容器 Card / Separator / SectionHeader / SectionFooter (parallel: true, depends_on: 001)
- [ ] 003.md - 分组设置行 InsetGroupedSection / SettingsRow (parallel: false, depends_on: 002)
- [ ] 004.md - 系统控件 .core style 套件 (parallel: true, depends_on: none)
- [ ] 005.md - 视觉终审：实机复刻一屏 iOS 设置页 (parallel: false, depends_on: 002, 003, 004)
- [ ] 006.md - 文档与发版 0.4.0 (parallel: false, depends_on: 005)

Total tasks: 6
Parallel tasks: 004 从起点即可与 001 并行；002 ∥ 004 在 001 之后
Sequential tasks: 4（001 → …→ 005 → 006）
Estimated total effort: 58 hours
