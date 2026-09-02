---
name: coredesign-leftover-closeout
description: 清算 CoreDesign 三个 open 遗留 issue（#115 / #136 / #139），把仍成立的项修掉、已作废的项如实注销、悬空的 epic 指针关闭
status: backlog
created: 2026-09-02T13:19:16Z
---

# PRD: coredesign-leftover-closeout

> **修订记录**
> - **v4（2026-09-02，第 3 轮评审 BLOCK 后修订）**：v3 的推演表与 6/5/5 三个数**经 superpowers-reviewer 与 Copilot 两方独立重推、均确认成立**（三轮里第一次算对）。BLOCK 换了位置：两方**独立收敛到同一条**——macOS 的验收被写在「`Color.Resolved` 逐位不同」层，而 `SystemBackgroundColorsMacOSTests.swift:15-21` 明写该层在无 WindowServer 会话下会塌成同一 fallback、故该 suite 早已改为断言 **token 身份**。v4 把 macOS 组降到 token 层，并补入该 suite **当前完全不覆盖 fill**（`grep -c fill` = 0）这一缺口。另修 I-1（快照成对）、I-2（三段将被写假的旧论述）与 S-1~S-4。
> - **v3（2026-09-02，第 2 轮评审 BLOCK 后重写）**：C-1——v2 承诺「iOS 深色 7 档两两不同」，但 `.overlay` 与 `.panel` 走同一个 `surfacePanel` token（`SurfaceModifier.swift:64,67`）、且 border/radius 也完全相同，alias-only 下不可能拆开；这是**在同一份 PRD 里第二次写下未经推演的档位数**。v3 改口为诚实版并附完整推演表，同时按 HIG 语义重排 fill→kind 分配（I-3），修正调用点计数（I-1）、Resolved-vs-观感的断言边界（I-2）、豁免条数（I-4）。iOS runtime 已装好（26.4 + iPhone 17 Pro），FR-2/FR-9 解封。
> - **v2（2026-09-02，评审 BLOCK 后重写）**：superpowers-reviewer 在 brainstorming 节点判 BLOCK。v1 的 FR-1 承诺「iOS 下 3 → 6 个 distinct 背景、两两不同」，被本仓自己的实测记录证伪（详见 §FR-1 的「v1 为什么错」）。本版按用户重新拍板的「分类别取 token」路径重写 FR-1/FR-2/FR-3/US-2/Success#3，并处置评审的 I-1 ~ I-4 与全部 Suggestion。同时补入两条本轮新查明的事实：`.surface()` 的真实调用点分布、本机无 iOS 模拟器 runtime。

## Executive Summary

CoreDesign 仓库当前有三个 open issue，全部是历史 epic 收尾时留下的 follow-up 清单：#139（epic 悬空指针）、#136（视觉终审遗留三条）、#115（audit-remediation 遗留四类）。它们最近一次被写下分别在 2026-07 与更早，此后仓库经历了 #117（删 GitHub 系组件）、#118（删 Blossom 主题）、#41、#48、#67、#72 等多轮改造，版本从 `v0.2.0` 走到 `v0.9.0`。

**本 PRD 的第一交付物不是代码，而是「issue 说的」与「仓库现在实际是什么」之间的对账。** 三个 issue 合计 8 个子项里，**3 项已被后续工作作废**、**1 项是纯记账动作**、**4 项仍然成立且有具体落点**。

在此基础上交付：修掉仍成立的项，把作废的项在 issue 上如实注销（写明被哪个 PR/issue 作废，而不是静默关闭），关掉悬空的 epic 指针，最终三个 issue 全部 closed。

## Problem Statement

### 为什么现在做

这三个 issue 是**没有活归属人的技术债指针**。最尖锐的一处：`Sources/CoreDesign/Colors/SurfaceColors.swift:91` 的注释写着「9 个 `SurfaceKind` 收敛为 3 个 distinct 背景的完整数据与缓议见 issue #140」——而 **#140 已经 CLOSED**。代码里一条活的缓议指向一个死的 issue，任何人顺着注释去查都会落空。

同型的还有 #139：6 个 task（#140–#145）全部 CLOSED、`.claude/epics/archived/coredesign-native-components/` 已归档、`v0.4.0` 已打 tag，唯独 epic issue 本身还挂在 open 列表里，让「当前在做什么」这个问题永远多出一个假答案。

### 实测对账（本 PRD 的事实基础）

以下每条都在当前 `main`（`56adc26`）上实测过，行号为实测行号，不是 issue 原文行号（原文行号已全部过期）。**本节的每一条已由 superpowers-reviewer 独立复核为真**（唯一例外见下方「v1 为什么错」）。

**#139 — Epic coredesign-native-components：悬空指针**

`gh issue view` 确认 #140–#145 全部 `CLOSED`；`.claude/epics/archived/coredesign-native-components/github-mapping.md` 完整列出六条映射；`git tag` 含 `v0.4.0`、`v0.4.1` 及其后的 `v0.5.0`–`v0.9.0`。epic 实体工作已完成，只差关闭动作。

**#136 — 三条全部仍成立**

1. **`SurfaceKind` 表达力塌缩：仍成立，且计数比 issue 写的更差。** issue 写「9 个 case → 3 个背景」；实测现在是 **10 个 case → 3 个 distinct 背景**：

   | kind | 背景 token 链 | 终值 |
   |---|---|---|
   | `.canvas` | `surfaceCanvas` | `systemGroupedBackground` |
   | `.content` | `surfaceCard` → `surfaceRaised` | `secondarySystemGroupedBackground` |
   | `.card` | `surfaceCard` → `surfaceRaised` | `secondarySystemGroupedBackground` |
   | `.grouped` | `surfaceCard` → `surfaceRaised` | `secondarySystemGroupedBackground` |
   | `.canvasSubtle` | `surfaceCanvasSubtle` | `secondarySystemGroupedBackground` |
   | `.floating` | `surfaceOverlay` → `surfacePanel` → `surfaceCanvasSubtle` | `secondarySystemGroupedBackground` |
   | `.overlay` | `surfacePanel` → `surfaceCanvasSubtle` | `secondarySystemGroupedBackground` |
   | `.panel` | `surfacePanel` → `surfaceCanvasSubtle` | `secondarySystemGroupedBackground` |
   | `.sidebar` | `surfaceSidebar` → `surfaceCanvasSubtle` | `secondarySystemGroupedBackground` |
   | `.control` | `surfaceInteractive` → `surfaceCanvasInset` | `tertiaryFill` |

   **10 个 case 里 8 个解析到同一个 `secondarySystemGroupedBackground`。** #140 只修了「`.content`/`.card` 与画布同色」这一处，塌缩本体原封不动。

   > issue #136 原文对本条的**因果描述有一处已被其自身「更正」段落推翻**（「#125 去掉边框导致 `.content` 与 `.canvas` 无法区分」是反的）。本 PRD 只采信上表实测，不沿用原文因果。

2. **`BottomInputBar` 无可视路径：仍成立。** `Sources/CoreDesign/Components/BottomInputBar/BottomInputBar.swift:19` 仍是 `struct BottomInputBar: View`（internal）；`App/Sources/Previews.swift:165-166` 与 `App/Sources/ComponentData.swift:219-221` 仍是同一句占位文本。
   **但 issue 原文漏了一个关键事实**：`.bottomInputBar(...)` modifier 本身在 `BottomInputBar.swift:458` 的 `public extension View` 里，**已经是 public**——接进 demo 不需要任何可见性改动。

3. **`SidebarNavigationRow` 选中态：仍成立。** `Sources/CoreDesign/Components/Sidebar/Sidebar.swift:452` 的 `SidebarSelectedBackgroundModifier` 仍是 `floatingGlass(isInteractive: true)` + `strokeBorder(Color.borderSelected)` + `coreShadow(.medium)`。

**#115 — 四类里两类大半作废**

1. **L10n sweep：8 处中只剩 3 处。** 全仓扫描非 `#if DEBUG` 区域的 `accessibilityLabel/Value/Hint` 字面量，未走 `bundle: .module` 的实际只有：
   - `SearchField.swift:94`（`"Search"`）
   - `SearchField.swift:116`（`Text("Clear \(...)")`，含插值，且**插值内层还有一个硬编码 `"search"` fallback**）
   - `ProgressBar.swift:65`（`"\(Int(...))% complete"`，含插值）

   issue 列的 `CommentCard.swift:89/90/102` 与 `StatusRow.swift:97` **对应组件已整个不存在**（`grep -rn "CommentCard\|StatusRow" Sources/` 零命中，由 `issue-117-remove-github-components` 移除）。`"Toggle Inspector"` 在 `SearchField.swift:236`，位于 `#if DEBUG`（145）–`#endif`（246）之间，非产品代码路径。

2. **视觉复核：一项作废，三项仍在。** 「Blossom 主题整体观感」作废（`issue-118-remove-blossom` 已移除该主题）。仍在的三项：#102 的三个 `#Preview`（`Sidebar.swift` / `FloatingGlassModifier.swift` / `TelegramGlassButtonModifier.swift`）渲染、#101 `SegmentedControl` thumb 滑动动画是否退化成 snap、#99 VoiceOver 冒烟（`BottomInputBar` / `UnderlinedTabBar` / `Form`）。

3. **`AGENTS.md` 同步义务：live，且已经欠了一笔具体的债。** `diff CLAUDE.md AGENTS.md` 的唯一实质分歧（其余是 banner 与「Codex/Claude Code」定位差异）是：AGENTS.md:42 仍写着「重度使用 iOS 26 的 `.glassEffect()`；`LightButtonStyle` 会按 `colorScheme` 分支……」，且缺 CLAUDE.md:42 的更正段与 :44 的「真实调用面」段。这句 **CLAUDE.md 已在 #41 收尾时标注「后半句实测为假」并删除**。即：同步义务已经被违反了一次，且违反物是一句已知为假的断言。

4. **测试覆盖：两处仍成立。** `SegmentedControlTests.swift:35-45` 的 `plainStyleOptsOutOfGlass` 函数体末尾是 `_ = styled`，确为纯编译检查、无运行时断言。`StateLabelTests.swift:38-42` 的 `customLabelPreservesStyle` 只断言 `label.style`，**没有任何断言触及 label payload**。

### `.surface(...)` 的调用点分布（v3 修正计数）

排除注释后，`.surface(...)` 在全仓共 **4 个**调用点——**产品代码路径 3 个 + 库内 `#Preview` 1 个**：

```
产品代码路径：
  Sources/CoreDesign/Components/InsetGroupedSection/InsetGroupedSection.swift:139   .surface(.grouped)
  Sources/CoreDesign/Components/ListRow/ListRow.swift:101                           .surface(.canvas)
  Sources/CoreDesign/Components/Card/Card.swift:107                                 .surface(self.kind.surfaceKind)   // → .content / .grouped

库内 #Preview：
  Sources/CoreDesign/Modifier/SurfaceModifier.swift:214                             .surface(sample.kind)   // 遍历全部 10 档
```

> **v2 曾写「真实调用点只有 3 个」「六个 kind 调用点数为零」——按字面为假**，漏了 `SurfaceModifier.swift:214` 的 `SurfacePreviewGallery`，它通过 `.surface(sample.kind)` 遍历全部 10 个 kind。按 NFR-1「精确数字视同断言」，此处已改正。

**产品代码路径**上，`.floating` / `.overlay` / `.panel` / `.sidebar` / `.canvasSubtle` / `.control` 六个 kind 的调用点确为零；库内直接消费 `Color.surfacePanel` / `Color.surfaceSidebar` / `Color.surfaceOverlay` 的地方也为零（`Sources/` 里只有 `Color.surfaceCanvasSubtle` 两处：`SegmentedControl.swift:182`、`ListRow.swift:98`，均不在本轮改动面内）。

**据此定位 FR-1**（结论加限定词后成立）：FR-1 修的**不是产品代码路径上当前可见的渲染缺陷**——没有任何组件在消费那些塌缩的档位。它修的是**公开 API 对未来调用方的承诺**。真实观感改动落在两处：demo app 的 6 个直接 token 消费点（见 FR-1 爆破半径），以及 `SurfacePreviewGallery` 这个库内预览。

**`SurfacePreviewGallery` 是 FR-9「SurfaceKind 全档对照」的现成载体**，FR-9 须点名用它（注意：它是库内 `#Preview`，只在 `KEEP_LIBRARY_SNAPSHOTS=1` 的 keep 模式下出图，默认模式会被 `find -delete`）。

### 已作出的产品决策

（brainstorming 收敛，用户 2026-09-02 拍板；第 1 条经评审 BLOCK 后**重新拍板**）

- **#136-1** → **走「分类别取 token」**：充当底层的用背景色族，叠在别人之上的（`.floating`/`.overlay`/`.panel`）改用 `FillColors`。保持 10 档不删 case，不做破坏性 API 收敛。
  （*v1 曾选「给档位真正不同的取值、全部留在背景色族」，被证伪后作废——见 FR-1。*）
- **#136-2** → 接 demo **并且**把 `BottomInputBar` 提为 public。
- **#136-3** → **保持现状**，把「这是本库刻意的玻璃风格、不追随 iOS 原生着色填充」这一判断写进文档，据此注销该条。
- **#115-2** → 视觉复核**这轮跑**（模拟器截图 + `ios-visual-reviewer`）。本机原本零 iOS runtime，已于 2026-09-02 执行 `xcodebuild -downloadPlatform iOS` **装好：iOS 26.4 + `iPhone 17 Pro`**（正是 `run-snapshots.sh:6` 的默认机型），FR-2 / FR-9 均已解封。

## User Stories

### US-1 · 维护者顺着代码注释能查到活的归属

**作为** CoreDesign 的维护者，**我希望** 代码里任何指向 issue 的缓议注释都指向一个 open 的 issue，**以便** 我不会顺着注释落空。

验收标准：
- `SurfaceColors.swift` 中指向 #140 的缓议注释被改写——要么因为塌缩已修而删除，要么改指本轮 issue。
- 本 PRD 只保证 `SurfaceColors.swift:91` 这一处；全仓悬空指针审计另开 issue（见 Out of Scope）。

### US-2 · 调用方用 `SurfaceKind` 能得到它名字承诺的层级

**作为** 使用 CoreDesign 的 App 开发者，**我希望** `.surface(.floating)` 真的浮在 `.surface(.content)` 之上、`.surface(.panel)` 与 `.surface(.canvas)` 分得开，**以便** 「表面角色」这层抽象值得我去学。

**注意本 story 的性质**：库内目前没有任何组件消费这些档位（见上文「真实调用点分布」），所以这不是修一个能看见的 bug，而是让一个**已经写在公开 API 里的承诺**变成真的。

验收标准（**按外观分别陈述，禁止合并成一句**；数字取自 FR-1 的推演表）：

- **iOS 深色**：解析值 distinct 数 = **6**。`.canvas` / `.content` / `.sidebar` / `.control` / `.floating` / `{.overlay, .panel}` 六组两两不同。
- **iOS 浅色**：distinct 数 = **5**。已知相等：`.canvas == .sidebar`（浅色 `systemGroupedBackground` 与 `tertiarySystemGroupedBackground` 同为 `#F2F2F7`）。
- **macOS**：distinct 数 = **5**。已知相等是一处 **5 路碰撞**——`.content` / `.card` / `.grouped` / `.canvasSubtle` / `.sidebar` **五者全部**落 `controlBackgroundColor`（AppKit 无 grouped 三级族）。**本组断言在 token 身份层，不在 Resolved 层**（理由见下）。
- **全平台恒等**：`{.content, .card, .grouped, .canvasSubtle}` 四者同值（文档化别名）；`{.overlay, .panel}` 同值（`.panel` 的 doc comment 本就写着「兼容别名：面板容器」，且二者 border 与 cornerRadius 也完全相同）。

**所有已知相等项一律钉成显式「相等」断言**，不是留作隐性回归。

> **断言层级的边界（三层，务必区分）**：
>
> 1. **iOS 两组 = `Color.Resolved` 逐位不同**（在 iOS Simulator 上取值）。
> 2. **macOS 组 = token 身份不同**，**不是 Resolved**。依据 `SystemBackgroundColorsMacOSTests.swift:15-21` 的成文取舍：「本想解析成具体 RGBA 再比明度，但在无 WindowServer 会话的沙箱里两者会塌缩成同一 fallback RGBA——那是解析环境的产物，不是真实的设计塌缩。故改为断言**本库 token 本身**互不相等」。照 Resolved 层写 macOS 断言，按本仓自己的记录要么恒红、要么给出误导性的「全部同色」结论。
> 3. **以上两层都不是「肉眼可辨」**。fill 族三档主要靠 alpha 区分，Resolved 层的 distinct 会**平凡通过**。观感判断只由 FR-9 的截图评审给出——**测试与文档里一律只说「解析值/​token 不同」，「可辨」二字只许出现在 FR-9 的判据里**。

### US-3 · demo app 里能看到并操作 BottomInputBar

**作为** 评估 CoreDesign 的开发者，**我希望** 在 demo app 里能真的敲字、看 suggestions、点发送，**以便** 判断这个组件是否合用。

验收标准：
- demo app 的 BottomInputBar 条目从占位文本变为可交互示例（可输入、可提交、可看到 suggestions 显隐）。
- 该示例注册进 `App/Sources/Previews.swift`，经 FR-9 规定的路径在 `docs/snapshots/` 产出**一个**非占位内容的快照 PNG。
- `BottomInputBar` 提升为 `public`，并处置 FR-4 列出的三样具体产物。

### US-4 · 库内所有产品路径的 a11y 串都可本地化

**作为** 做多语言 App 的开发者，**我希望** CoreDesign 组件读给 VoiceOver 的每一句都**进了 String Catalog**，**以便** 我接手翻译时不必先去库里挖硬编码英文。

> 限定：本轮交付的是**「可本地化」而非「已翻译」**——`Sources/CoreDesign/Resources/` 目前只有 `en.lproj`，实际多语言翻译在 Out of Scope。

验收标准：
- `SearchField.swift:94`、`:116`（含其插值内层的 `"search"` fallback）、`ProgressBar.swift:65` 全部走 `bundle: .module`。
- 含插值的两处按 `.strings` / `.stringsdict` 位置键实现（本仓已有 `"%@ of %@"` 先例）。
- 存在守卫（FR-6）锁住该状态。

### US-5 · `AGENTS.md` 不携带已知为假的断言

**作为** 用 Codex 在本仓工作的人，**我希望** `AGENTS.md` 与 `CLAUDE.md` 内容一致，**以便** 我读到的不是一句 #41 已经证伪的话。

验收标准：
- 规范化 diff（消除 banner 与「Codex ↔ Claude Code」定位替换后）的残余差异为空。
- 存在自动守卫能在二者再次分歧时红，而不是继续依赖人的「同步义务」。

### US-6 · 三个遗留 issue 被如实关闭

**作为** 仓库负责人，**我希望** open issue 列表反映真实待办，**以便** 「现在还欠什么」有唯一答案。

验收标准：
- #139 关闭，说明写明 6 个 task 全 closed + 本地已归档 + `v0.4.0` 已发。
- #136 关闭，逐条说明：1 已修（附新映射表 + 平台/外观限定）、2 已修（附 demo 截图）、3 **按决策不改并说明理由**。
- #115 关闭，逐条说明：作废项写明**被哪个 issue/PR 作废**（#117 / #118），仍成立项写明处置。
- **不得出现「已全部处理」这类笼统全称句**；每条子项各有各的结论。

## Functional Requirements

### FR-1 · `SurfaceKind` 分类别取 token（背景族 vs 填充族）

#### v1 为什么错（保留此段，防止后人重走）

v1 的方案是「保持全部档位在背景色族内、只改三个 token 别名的指向」，并承诺 iOS 下 6 档两两不同。**这个承诺物理上不可能成立**：

- `Tests/CoreDesignTests/SurfaceContrastTests.swift:7-9`（iOS 模拟器实测记录，Badge bug 根因）：`secondarySystemGroupedBackground` 在**浅色**下与 `systemBackground` 同为 `#FFFFFF`。
- `Sources/CoreDesign/Components/Badge/Badge.swift:139`（同一处实测的对照分支）：`systemGroupedBackground` 在**深色**下与 `systemBackground` 同为纯黑。

即 iOS 背景色族在单一外观下只有 **2（浅色）/ 3（深色）** 个取值，任何别名重排都凑不出更多。而 `Badge.swift:143` 早已把结论写死：

> 根因是选错了 token **种类**……**任何单一 surface token 都修不好这个问题——问题出在种类选错，不是某个具体 token 的取值。**

v1 正是拿「改取值」去解一个「选错种类」的问题，重蹈 #122 已付过学费的坑。

#### v2 为什么也错（第二次留痕）

v2 把 `.floating`/`.overlay`/`.panel` 移到 fill 族后，承诺「iOS 深色 7 档两两不同」。**这个数字同样没推演过**：

```
$ sed -n '64p;67p' Sources/CoreDesign/Modifier/SurfaceModifier.swift
        case .overlay: .surfacePanel
        case .panel: .surfacePanel
```

`.overlay` 与 `.panel` 走**同一个** token，且 border（均 `borderDefault`）与 cornerRadius（均 `.medium`）也完全相同——**它们今天就是全等的两个 case**，`.panel` 的 doc comment 本就写着「兼容别名：面板容器」。在 FR-1 声明的 alias-only 约束下，它们不可能被拆开。按 v2 的验收写出的守卫测试**要么恒红、要么造假**。

教训与 NFR-2 同源：**任何档位数在写进验收之前，必须用「kind → token → 终值」全表推演一遍**。v3 的表见下。

#### v3 方案

在 #140 先例（改 token 别名、不改 switch）与 #122 裁决（叠加层用 `FillColors`、底层用 `SurfaceColors`）之上，**fill → kind 的分配按 HIG 语义 + z 序确定**（补齐评审 I-3 指出的「分配无理据」）：

| fill token | HIG 官方语义（见 `FillColors.swift` doc） | 分配给 | 理由 |
|---|---|---|---|
| `secondaryFill` | 中等大小形状（开关背景） | `.floating` | **理由不是 HIG 对号**（HIG 这一档指开关背景，与浮动工具栏并非精确对应），而是两条更硬的依据：① **z 序最高的浮件需要最强的存在感**；② `Badge.swift:146` 已实测 `secondaryFill`（浅 α=0.16 / 深 α=0.32）在 `surfaceBase` / `surfaceCanvas` / `surfaceRaised` 三种父容器、两种外观下**均可辨** |
| `tertiaryFill` | 大型形状（输入字段、搜索栏、按钮） | `.control`（**不变**） | 与 HIG 语义精确对应，本仓已在用 |
| `quaternaryFill` | 大区域复杂内容（展开的表格单元格） | `.overlay` / `.panel` | 菜单 / popover / 面板是**承载复杂内容的大区域容器**，宜克制 |

> v2 的分配是反的（`.floating`→`quaternaryFill`、`.panel`→`secondaryFill`），把最淡的给了 z 序最顶的。v3 已倒置。这同时缓解了评审 I-2 举的浅色近撞例子：v2 下 `.floating` 是 α≈0.08、合成在 `#FFFFFF` 上≈`#F4F4F5`，与 `.canvas` 的 `#F2F2F7` 肉眼几乎不可辨；v3 下 `.floating` 是 `secondaryFill`，恰是 Badge 实测过可辨的那一档。

据此，**只改三个 token 别名**：

| token | 现指向 | 改为 | 服务的 kind |
|---|---|---|---|
| `surfaceSidebar` | `.surfaceCanvasSubtle` | `.surfaceElevated`（= `tertiarySystemGroupedBackground`） | `.sidebar` |
| `surfaceOverlay` | `.surfacePanel` | `.secondaryFill` | `.floating` |
| `surfacePanel` | `.surfaceCanvasSubtle` | `.quaternaryFill` | `.overlay`、`.panel` |

#### 推演表（**任何档位数必须出自本表**）

| kind | 改后 token 链 | 终值 |
|---|---|---|
| `.canvas` | `surfaceCanvas` | `systemGroupedBackground` |
| `.content` / `.card` / `.grouped` | `surfaceCard` → `surfaceRaised` | `secondarySystemGroupedBackground` |
| `.canvasSubtle` | `surfaceCanvasSubtle` | `secondarySystemGroupedBackground` |
| `.sidebar` | `surfaceSidebar` → `surfaceElevated` | `tertiarySystemGroupedBackground` |
| `.control` | `surfaceInteractive` → `surfaceCanvasInset` → `tertiaryFill` | `tertiarySystemFill` |
| `.floating` | `surfaceOverlay` → `secondaryFill` | `secondarySystemFill` |
| `.overlay` / `.panel` | `surfacePanel` → `quaternaryFill` | `quaternarySystemFill` |

**逐平台/外观 distinct 数**（fill 的 α 值除 `secondaryFill` 有 `Badge.swift:146` 实测外，其余为 UIKit 标准值，**FR-2 须在模拟器上实测钉死**）：

| 情形 | distinct | 分组 |
|---|---|---|
| **iOS 深色** | **6** | `#000000`{canvas} / `#1C1C1E`{content,card,grouped,canvasSubtle} / `#2C2C2E`{sidebar} / tertiaryFill{control} / secondaryFill{floating} / quaternaryFill{overlay,panel} |
| **iOS 浅色** | **5** | `#F2F2F7`{canvas,**sidebar**} / `#FFFFFF`{content,card,grouped,canvasSubtle} / 三个 fill 各一组 |
| **macOS** | **5** | windowBg{canvas} / controlBg{content,card,grouped,canvasSubtle,**sidebar**} / 三个 NSColor fill 各一组 |

改后从 **3 个 distinct 背景**（当前）提升到 **iOS 深色 6 / iOS 浅色 5 / macOS 5**。

不删任何 case，不改任何 case 的 `border` / `cornerRadius`，不改 `surfaceCanvas` / `surfaceCard` / `surfaceRaised` / `surfaceCanvasSubtle` / `surfaceInteractive` / `surfaceCanvasInset`。

#### 同 commit 清洗被写假的旧论述（评审 I-2，本仓有病史）

三个别名一改，`SurfaceColors.swift` 里至少**三段成文论述当场变假**，必须**与别名改动同一个 commit** 改写：

| 位置 | 变假的内容 |
|---|---|
| `:21-26`（文件头） | 「`surfaceSidebar` 走 `surfaceCanvasSubtle`……`surfaceCanvasSubtle` 落 `controlBackgroundColor`」——改指 `surfaceElevated` 后前半句假 |
| `:85-91`（`surfacePanel` doc） | 「与其别名目标 `surfaceCanvasSubtle` 同值」+「`.surface(.panel)` 的背景与 `.surface(.card)` 同值……层级差异改由**边框**表达」——改指 `quaternaryFill` 后两句全假 |
| `:96-99`（`surfaceSidebar` doc） | 「走 `surfaceCanvasSubtle`……在 macOS 降级后能与画布本体形成可辨识的次级背景层级」 |

**清洗范围以实测为准，已扫过的两处不必再找**：

- `SurfaceModifier.swift` **无旧链成文表述**——`grep -n surfaceCanvasSubtle Sources/CoreDesign/Modifier/SurfaceModifier.swift` 仅命中 `:66` 的合法映射行（`case .canvasSubtle: .surfaceCanvasSubtle`），无需清洗。
  > v4 曾在此写「如 `:88-91` 提到 `.floating`/`.overlay` 走 `surfaceCanvasSubtle` 的表述」——**该引用是编造的**，`:88-91` 实为 `cornerRadius` 的 doc comment 与 switch。留痕于此：本 PRD 在论证「重写后留下旧引用」这一病症的段落里，自己写了一条假引用。
- `docs/` 下 live 文档对三个被改别名无链路论述（`docs/components/sidebar.md` 只是代码示例用了 `Color.surfaceSidebar`，`docs/DESIGN-FOUNDATION.md` 未引用被改链路）。

**验收判据**：grep **被否定命题的关键词**（「层级差异改由」、「收敛为 3 个」、「`surfaceCanvasSubtle` 同值」）在 `Sources/` `Tests/` `docs/components/` `docs/component-contract.md` 范围内清零。实测当前命中恰为 `SurfaceColors.swift:89` 与 `:91` 两处。

#### 半透明化的代价与它当前的现实性

`.floating` / `.overlay` / `.panel` 改为半透明后，其下内容会透出。**这三档在产品代码路径上的 `.surface()` 调用点为零**（唯一消费者是 `SurfacePreviewGallery` 这个库内预览），所以该代价目前**没有产品侧受害者**；它是给未来调用方的语义正确性买单。

doc comment 须写明两条：

1. 「这三档是**半透明叠加色**，需要不透明浮层请用 `floatingGlass` 或 `.surface(.content)`」。
2. **「半透明档位不宜再叠 `.coreShadow(_:)`」**（评审 S-1）——`SurfaceModifier.swift:115-116` 明文引导调用方追加 `.coreShadow(_:)`，但阴影会从半透明背景**透上来把表面压脏**。

> 结构层面已核：`fill → strokeBorder → clipShape` 的次序对半透明无新裁剪隐患（`clipShape` 只裁自身内容）；仅描边（`borderMuted` / `borderDefault` 本身也半透明）改为叠在「fill + 底衬」之上，观感微移，由 FR-9 截图覆盖。

#### 爆破半径（评审 I-3）

`SurfaceKind` 路径之外，被改的 token 还有 **6 处 App 宿主直接消费**，它们的观感**会真实改变**：

```
App/Sources/ComponentDetail.swift:45,68,77   .background(Color.surfacePanel)     → 变半透明
App/Sources/Previews.swift:110               .background(Color.surfaceSidebar)   → 换一档背景
App/Sources/ComponentData.swift:310          .background(Color.surfaceSidebar)   → 换一档背景
App/Sources/ContentView.swift:49             .background(Color.surfaceSidebar)   → 换一档背景
```

`App/` **不被 `swift build` / `swift test` / CI 覆盖**（CLAUDE.md 的验证边界），所以这 6 处只能靠 FR-9 的截图发现问题。FR-9 的截图范围**必须包含它们**。特别注意 `ComponentDetail.swift` 的三处 `surfacePanel` 变半透明后，若其父背景本身就是 `surfaceCanvas`，可能反而更难辨——这是 FR-9 要重点看的。

### FR-2 · `SurfaceKind` 分化的守卫测试

扩展 `Tests/CoreDesignTests/SurfaceContrastTests.swift`：

- **断言按平台/外观分别写**，与 FR-1 推演表及 US-2 的验收一一对应；**禁止**写成一条不带限定的「N 档两两不同」。
- **本 suite（iOS-only）内的已知相等项钉成显式「相等」断言**：`{.content,.card,.grouped,.canvasSubtle}` 恒等、`{.overlay,.panel}` 恒等、iOS 浅色 `.canvas == .sidebar`。**macOS 侧的相等断言归 FR-3**，不要往这个 `#if os(iOS)` suite 里塞。
- **实测钉死 fill 的 α 值**：推演表里除 `secondaryFill`（`Badge.swift:146` 有实测）外的 α 为 UIKit 标准值，须在模拟器上取到真实 `Color.Resolved` 后写进测试与文档，**不得沿用本 PRD 的预期值**。
  **若实测与表值不符**：按 NFR-2 第 1 条**重新推演 distinct 数**并回改 PRD、US-2、Success#3 与测试——**不得反过来削弱断言去迁就已写好的数字**。
- 比较在解析后的 `Color.Resolved` 分量上做（该 suite 已有此模式），不是 `Color` 引用相等；比较双方须为同一数值类型（本仓有 `#expect` 跨 `CGFloat`/`Double` 恒假的教训）。

**必须同步改写该 suite 的边界注释（评审 I-2，易漏）**：`SurfaceContrastTests.swift:19-27` 现写着「不上感知色差阈值，因为**当前代码库里没有任何近似撞色的真实案例**……现有 token 两两之间都差着几十个色阶」。**FR-1 恰好制造了首批 alpha-only 的近撞案例**（三个 fill 的 RGB 几乎相同、只靠 α 区分），这段前提被写假了。须改写为如实描述：本 suite 只担保逐位不同；fill 族之间的差异主要在 α，Resolved 层的 distinct 会平凡通过；观感判断交由 FR-9。

**本组守卫的射程边界（如实写明，防「护栏结构性失明」）**：FR-2/FR-3 的断言全部打在 **public token 层**（`Color.surfacePanel` 等）。而 `SurfaceKind.background` 的 switch 位于 `private extension`（`SurfaceModifier.swift:56`），`@testable` 也够不到——**把 `case .floating: .surfaceOverlay` 改成 `.surfacePanel` 这类 kind→token 映射的变异，本组测试全绿**。本 FR 不承诺护住该映射；映射的正确性只由 FR-9 的截图覆盖。（FR-1 明写不改 switch，故本轮不构成缺陷；若未来要护，需把该 extension 提为 internal。）

**执行载体（评审 I-4）**：`SurfaceContrastTests.swift:28` 整个 suite 是 `#if os(iOS)`，macOS 上 `swift test` 对它**空跑假绿**。因此：

- 本 suite 必须经 `xcodebuild test -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` 执行（runtime 与机型均已就位）。
- 每次跑完**必须核对实际执行的测试数**。
- macOS 侧断言（FR-3）另置于 `SystemBackgroundColorsMacOSTests.swift`，走 `swift test`。

**变异自证（评审 S-2）**：靶点须随 v3 最终映射重选——**打在 `surfaceOverlay`（`.floating` 的唯一来源）上**：改回 `.surfacePanel` 后 `.floating` 会与 `.overlay`/`.panel` 同值，iOS 深色的 distinct 从 6 掉到 5，断言必须红。**不得**把靶点打在 `{.overlay,.panel}` 这种「本来就该相等」的档位上——那样的变异不会红，会造成守住了的假象。

### FR-3 · macOS 行为的如实记录与守卫

`SystemBackgroundColors.swift` 的 AppKit 分支只有两个背景取值（`windowBackgroundColor` ← `systemBackground`/`systemGroupedBackground`；`controlBackgroundColor` ← 其余四个）。`FillColors` 四档在 AppKit 侧均有对应 `NSColor`，正确桥接。

FR-1 之后 macOS 上（distinct = **5**，见推演表）：

- `.canvas` → `windowBackgroundColor`
- `.content`/`.card`/`.grouped`/`.canvasSubtle` → `controlBackgroundColor`
- **`.sidebar` → `controlBackgroundColor`，与 `.content` 同值**（AppKit 无 grouped 三级族）
- `.control` / `.floating` / `.overlay`+`.panel` → 三个 `NSColor` fill，各自不同

> **v1 的 macOS 风险已消失**：v1 把 `.floating` 指向 `systemBackground` 会使它与 `.canvas` 在 macOS 同值；v2/v3 把 `.floating` 移到 fill 族，该风险不复存在。取而代之的是 `.sidebar == .content`。

要求：

- 扩展 `SystemBackgroundColorsMacOSTests.swift`，**在 token 身份层**断言（沿用该文件 `:15-21` 的既有手法，**不解析 RGBA**）：
  - `.content` / `.card` / `.grouped` / `.canvasSubtle` / `.sidebar` **五者同值**（5 路碰撞，显式钉住，不留隐性回归）；
  - `.canvas` 与上述五者不同值；
  - **三个 fill token 两两不同、且与两个背景 token 不同**。
- **该 suite 当前完全不覆盖 fill**（`grep -c "fill" Tests/CoreDesignTests/SystemBackgroundColorsMacOSTests.swift` → `0`）。FR-1 首次把 fill 引入 `SurfaceKind` 的背景通路，**这块覆盖是本 FR 新增的，不是扩写既有断言**。
- **两种手法的分工**：本 FR **新增**的断言一律用「显式相等」钉住（塌缩解除时会红，提醒更新）；该文件 `:64-66` 既有的 `withKnownIssue`（secondary vs tertiary）**保持原样不动**。两者效果等价、形态相反，不要混用或改写既有那条。
- 在 `SurfaceColors.swift` 与 `docs/` 写明按平台/外观的实际 distinct 数（6 / 5 / 5），并注明 macOS 组是 token 层结论。
- **禁止**在任何文档、注释、commit message、issue 回复里出现不带平台**与外观**限定的「`SurfaceKind` 已分化为 N 档」。
- 本 FR 的措辞一律用「token 不同 / 同值」，**不得用「可辨」**——观感结论只由 FR-9 给出。

### FR-4 · demo app 接通 BottomInputBar + 提升为 public

- `App/Sources/ComponentData.swift` 的 `BottomInputBarPreview` 从占位 `Text` 改为真实可交互宿主：`@State` 文本、非空 suggestions、可触发 `onSubmit`、能看到 suggestions 显隐。
- `App/Sources/Previews.swift` 的 `#Preview("BottomInputBar")` 同步改为同一宿主（默认快照模式只保留 `Previews.swift` 驱动的 `CoreDesignPreview_*`，库内 `#Preview` 会被 `find -delete`）。
- `struct BottomInputBar` 提升为 `public`，其 `public init` 及公开成员按本仓规范补齐中英双语 doc comment。

**FR-4 的真实工作量在下面三样，不是「守卫报错后顺手改绿」（评审 I-2）**：

1. **推翻一条成文裁决**：`docs/component-contract.md:1278-1291` 的终审 C1 裁决明确把 BottomInputBar「按 AD-2 排除出登记表」，并把 `placeholder` 归为「落在 FR-4 定义域之外」（由 `ComponentTextParamGuard.knownFunctionSideBareText` 的固定集合断言盯着）。该裁决同时给出两条出路，**提 public 正是其中之一**（「给它一个可登记的 public 类型表面」）——方向合法，但**裁决文本、判定法走查（kind / nativeProtocol / needsExtensionPoint）、`placeholder` 的正式分类**都必须一并改写。
2. **`docs/bool-exemptions.json:27-68` 的 7 条 `bottomInputBar` Bool 豁免**（`autoShowSuggestions` / `wandEnabled` / `sendEnabled` / `showMenuButton` / `isRunning` / `showShuffleButton` / `autoFocus`）：
   - 其中 **1 条**（`:28` `autoShowSuggestions`）的 reason 直接引用「BottomInputBar 按公约 AD-2 排除出登记表（**struct 无 public 修饰符**）」这一前提——提 public 后该句**失真，必须改写**；
   - 其余 6 条 reason 不依赖该前提，但 struct 提 public 后这 7 个 Bool 会形成**第二张 public 参数面**（modifier 侧已有一张），需评估是否新增豁免条目。
   > v2 曾写「共 9 条」，实测为 **7 条**、行号 27-68——又一处违反 NFR-1 的精确数字，已改正。
3. **跨仓移交联动**：`component-contract.md:1290-1291` 指明该事项已移交 `oh-my-story` 仓（close-out.md 移交清单，issue #50 承接）。FR-4 落地后需在那边收口——**本 PRD 只负责在 CoreDesign 侧完成并在 issue 里点名通知，不承诺替 oh-my-story 改代码**。

其余守卫（`ComponentRegistryGuard` / `ComponentContractStructureGuard` / `ComponentExtensionPointGuard` / `ReachableTypeRegistryGuard` / `BoolParameterScanner`）均为固定集合断言，会逐个把要改的点报出来，工作量可控。

**FR-4 独立成 task/PR**，上述三样列进其验收标准。

### FR-5 · 三处 a11y 串本地化

- `SearchField.swift:94`：`placeholder.isEmpty ? "Search" : placeholder` 的三元中，**只有 fallback 分支 `"Search"` 需要本地化**（`placeholder` 是调用方传入值，库不该翻译）。
- `SearchField.swift:116`：`Text("Clear \(placeholder.isEmpty ? "search" : placeholder)")`。走位置键（如 `"Clear %@"`）+ `.strings`。**注意插值内层的 `"search"` 也是硬编码英文**，同样入 catalog——它藏在插值里，按行扫的守卫看不见它（评审 Suggestion）。
- `ProgressBar.swift:65`：`"\(Int(value * 100))% complete"`。走位置键（如 `"%lld%% complete"`）。**百分号在 `.strings` 里需转义**，须验证渲染结果不是字面量 `%%`。
- 三处均须有测试断言取到的是 catalog 值而非硬编码英文（`.xcstrings` 在 SwiftPM CLI 下不编译，须用 `.strings` / `.stringsdict`）。

### FR-6 · a11y 字面量守卫

新增测试：扫描 `Sources/CoreDesign/**/*.swift`，跳过 `#if DEBUG` 区块，找出 `accessibilityLabel` / `accessibilityValue` / `accessibilityHint` 调用中含**字符串字面量且不含 `bundle: .module`** 的行，非空即红。

- **豁免机制的锚定用例**（评审 Suggestion）：`Sources/CoreDesign/Components/TagInput/TagInput.swift:105` 的 `.accessibilityLabel(Text(self.placeholder))` 是调用方传入值，应作为豁免的首个真实条目写进实现，避免守卫实现时现场发明判据。豁免格式参照 `docs/bool-exemptions.json` 的先例。
- 扫描器须能看见**插值内层的字面量**（FR-5 第二条），否则它对自己该防的东西结构性失明。
- 变异自证：把 FR-5 修好的任一处改回硬编码，守卫必须红；**变异要打在插值内层那一处**，因为那是最容易漏的形态。

### FR-7 · `AGENTS.md` 同步 + 自动守卫

- 删除 AGENTS.md:42 段末已证伪的 `.glassEffect` / `colorScheme` 句，补上 CLAUDE.md:42 的更正段与 :44 的「真实调用面」段。
- 新增守卫：对二者做规范化 diff（消除 banner 行与「Codex ↔ Claude Code」「AGENTS.md ↔ CLAUDE.md」的已知定位替换后），残余差异非空即红。
- 守卫须把「允许的差异」**显式列白名单**，不得用宽松正则把任意差异都吃掉。

### FR-8 · 补两处测试断言

- `SegmentedControlTests.plainStyleOptsOutOfGlass`：从 `_ = styled` 改为有运行时断言。若受 `Text` 类型擦除限制无法直接断言，则**如实改名并在注释里写明它只能做到什么**——不得让纯编译检查顶着一个承诺行为的名字。
- `StateLabelTests.customLabelPreservesStyle`（实际在 38-42 行）：补上对 label payload 的断言。同上，若类型擦除挡住，须如实降级命名并说明。

### FR-9 · 视觉复核（模拟器）

**前置：已解封。** 本机原本零 iOS runtime，执行 `xcodebuild -downloadPlatform iOS` 后已装好 **iOS 26.4 (23E244)** 与 **`iPhone 17 Pro`** 设备（正是 `run-snapshots.sh:6` 的默认机型）。

出图路径（**解决评审 I-1 指出的矛盾**）：

- `scripts/run-snapshots.sh` 的 keep 模式（`KEEP_LIBRARY_SNAPSHOTS=1`）导出到 scratch、**永不触碰 `docs/snapshots`**；默认模式则 `rm -rf docs/snapshots` 全量重渲染。二者都无法「只往 `docs/snapshots` 加一个文件」。
- 因此唯一可行路径是：**keep 模式出图 → 手工把 `CoreDesignPreview_BottomInputBar*.{png,json}` 拷进 `docs/snapshots/`**。
- **是一对文件，不是一个**：`docs/snapshots/` 现有 78 个文件 = **39 对 PNG + 同名 JSON sidecar**（`ls docs/snapshots | grep -c '\.png$'` → 39，`.json` 同样 39）。只拷 PNG 会打破目录的成对约定。
- 自证判据：`git status --porcelain docs/snapshots` 的输出**恰含这一对点名的新增文件**（而非 NFR-4 原本要求的「空输出」）。

截图并交 `ios-visual-reviewer` 的目标：

- **FR-1 改动后的 `SurfaceKind` 全档对照（浅色 + 深色各一套）**——用现成载体 `SurfaceModifier.swift:188-222` 的 `SurfacePreviewGallery`，它已遍历全部 10 档。**注意它是库内 `#Preview`，只在 `KEEP_LIBRARY_SNAPSHOTS=1` 下出图**，默认模式会被 `find -delete`。
- **半透明档位与底层档位的合成对照（评审 I-2 / S-3，浅色为重点）**：把 `.floating` / `.overlay` / `.panel` 分别叠在 `.canvas` 与 `.content` 之上并排截图。守卫测试只担保 Resolved 逐位不同，**「浮起来了没有」只能在这里回答**。
  ⚠️ **本项没有现成载体**：`SurfacePreviewGallery` 只把每档平铺在单一 `surfaceCanvas` 底上，产不出「`.floating` 叠 `.content`」这类合成图。**FR-9 须新增一个合成对照 `#Preview`**（同样是库内预览，只在 keep 模式出图），否则该判据无处执行。
- **FR-1 爆破半径的 6 处 App 宿主消费点**（`ComponentDetail` 的三处 `surfacePanel` 半透明化是重点：其父背景若本就是 `surfaceCanvas`，半透明后可能反而更难辨）
- FR-4 的 BottomInputBar demo 页
- #102 的三个 `#Preview`：`Sidebar.swift` / `FloatingGlassModifier.swift` / `TelegramGlassButtonModifier.swift`
- #101 `SegmentedControl` thumb 滑动——**光栅快照证不了动画在动**，须录屏或多帧截图，或以「无法用现有手段证实」如实结案

VoiceOver 冒烟（`BottomInputBar` / `UnderlinedTabBar` / `Form`）：能自动化的部分做，做不到的部分**如实写明做不到**。

### FR-10 · Sidebar 选中态：不改，写清楚

- 不修改 `SidebarSelectedBackgroundModifier` 的任何行为。
- 在 `Sidebar.swift` 的 `sidebarSelectedBackground` doc comment 与 `docs/` 写明：本库选中态刻意采用浮层玻璃 + 选中色描边 + 阴影，**不追随 iOS/macOS 原生的「着色填充、无独立轮廓」**，这是风格决策而非疏漏；记下 #136 提出的对照参考（Files / Reminders / Mail）供未来重议。

### FR-11 · 三个 issue 的关闭

按 US-6 的验收标准逐条写关闭说明并关闭 #139 / #136 / #115。

## Non-Functional Requirements

### NFR-1 · 断言纪律

本仓有反复出现的失真史。本 PRD 的全部交付物受以下硬约束：

- **任何「已修复 / 已通过 / 已覆盖 / 全部 / 无 X」这类断言，写下之前必须有对应命令的输出为证**，输出要贴进 PR 或 commit body。
- commit message 与 issue 回复**同样在射程内**——它们不受任何自动校验保护，是历史失真的高发地。
- 精确数字（档位数、字符串处数、测试数）视同断言，须逐个复核。
- 下「本仓没有 X」这类全称否定前，先跑 `ls scripts/ App/Tests/ docs/` 并查 `docs/components/*.md`。

### NFR-2 · 档位数必须先推演、且必须带平台与外观限定

**本 PRD 已在同一个 FR 上连错两次档位数**（v1 的「6」、v2 的「7」），故本条强制：

1. **先推演后落笔**：任何档位数写进验收之前，必须用「kind → token → 终值」全表推演一遍（表见 FR-1）。任何未出现在该表里的数字都是无效断言。
2. **必带平台与外观限定**：FR-1 的分化在 iOS 深色（6）/ iOS 浅色（5）/ macOS（5）下各不相同，任何提及档位数的文字都必须带这两个限定词。
3. **区分「解析值不同」与「可辨」**：测试与文档一律只说前者；「可辨」只许出现在 FR-9 的截图评审判据里。

### NFR-3 · 守卫必须能红，且要打在它声称防护的点上

FR-2 / FR-6 / FR-7 三处新增守卫，交付时**每一处都附变异自证**（改坏 → 跑 → 贴失败输出 → 改回）。本仓有「护栏结构性失明」的前例，仅「能判红」不等于「守住了目标命题」——变异要打在守卫**声称防护的那个点**上（FR-6 的变异因此规定打在插值内层）。

### NFR-4 · 快照污染

除 FR-9 点名的那**一对**新增 BottomInputBar 快照（`.png` + `.json`）外，任何 PR 不得包含 `docs/snapshots/` 的其他改动。自证判据见 FR-9（porcelain 输出仅含该点名文件）。

### NFR-5 · 不破坏公开 API

FR-1 是同名换值（记入 `BREAKING-CHANGES` 的视觉变更条目，非源码破坏；且因零库内消费点，实际影响面仅 demo app 与未来调用方）；FR-4 是纯扩大（internal → public）。**本 PRD 不删除、不重命名任何现有公开符号。**

## Success Criteria

1. `gh issue list --state open` 在 CoreDesign 上返回 **0 个** issue（当前 3 个）。
2. `SurfaceColors.swift` 中不再有指向已 closed issue 的待办式注释（以 grep 输出为证）。
3. `SurfaceKind` 的 distinct 解析值数从当前的 **3** 提升到 **iOS 深色 6 / iOS 浅色 5 / macOS 5**（数字出自 FR-1 推演表）；全部已知相等项（含 `{.overlay,.panel}` 恒等）各有显式相等断言钉住。iOS 两组断言在 **iOS Simulator** 上按 `Color.Resolved` 执行；**macOS 组走 `swift test` 且断言在 token 身份层**（Resolved 层在无 WindowServer 会话下不可用，见 US-2 边界注第 2 条）。变异自证记录已附（靶点为 `surfaceOverlay`）。**本条不主张任何观感结论**——「可辨」由 Success #9 承担。
4. `diff CLAUDE.md AGENTS.md` 的实质分歧数从 **1** 降到 **0**，由自动守卫锁住。
5. 非 `#if DEBUG` 路径下未走 `bundle: .module` 的 a11y 字面量（**含插值内层**）从 **4** 降到 **0**，由自动守卫锁住。
6. `docs/snapshots/` 新增**恰好一对** BottomInputBar 快照（`.png` + 同名 `.json`），且 `git status --porcelain docs/snapshots` 不含其他条目。
7. `swift test` 全绿 + `xcodebuild test` 的 iOS 腿全绿，测试数不低于改动前基线（基线在开工时实测记录，不引用任何历史数字）。
8. 三个 issue 的关闭说明中，每个子项各有独立结论；作废项均写明作废来源（#117 / #118）。
9. FR-9 的视觉评审对「半透明档位是否真的浮起来」给出明确结论（含浅色合成对照）；若某项无法用现有手段证实（如 `SegmentedControl` thumb 动画），**如实记为「无法证实」而非「已复核」**。

## Constraints & Assumptions

**约束**

- 工具链：Xcode 26.4 / Swift 6.3（已实测）；platform macOS 26 / iOS 26；测试用 Swift Testing，非 XCTest。
- iOS 模拟器 runtime **已装好**（iOS 26.4 / `iPhone 17 Pro`）——FR-2 与 FR-9 的执行载体就位。
- `.xcstrings` 在 SwiftPM CLI 下不编译（#100 实证）——本地化必须用 `.strings` / `.stringsdict`。
- `SurfaceContrastTests` 是 `#if os(iOS)`，`swift test` 对它空跑假绿——**必须走 xcodebuild iOS Simulator**。
- `swift test --filter` 只认真实函数名，不认 `@Test` 显示名；写错会「跑 0 个测试 + 退出 0」。**每次 filter 跑完必须核对实际执行的测试数。**
- `rtk` 代理的 `diff` 恒返回 0，不得用其退出码做判据。
- 快照流水线只出 PNG、**不做基线比对**，检测不了视觉回归。
- 光栅快照证不了 `allowsHitTesting` / `accessibilityHidden` / 动画是否在动。
- `App/` 不被 `swift build` / `swift test` / CI 覆盖——FR-1 爆破半径的 6 处只能靠截图验证。
- 中文文档按约 50 字硬折行，跨行折断会击穿单行 grep。

**假设**

- 三个 issue 无外部依赖方，关闭动作不需要第三方确认。
- `main` 上没有其他人的在途改动（当前工作区仅 `Package.resolved` 一处修改）。

## Out of Scope

- **删除或重命名任何 `SurfaceKind` case**。
- **修改 Sidebar 选中态的视觉行为**。
- **消除 iOS 浅色 / macOS 的已知塌缩**——那是系统色族的物理下限，FR-2/FR-3 只要求如实断言。
- **全仓的 closed-issue 悬空指针审计**——US-1 只承诺一处；假阳性高、需逐条判时态，另开 issue。
- **CommentCard / StatusRow 的任何工作**（#117 已删）；**Blossom 主题的任何工作**（#118 已删）。
- **`oh-my-story` 仓侧的收口**（FR-4 只负责 CoreDesign 侧 + 点名通知）。
- **`.xcstrings` 迁移**、多语言实际翻译（本轮只做「进 catalog」，源语言 en）。
- **`docs/snapshots/` 的基线比对能力**。
- **`docs/superpowers/` 下的历史归档**（plans / specs）不在 FR-1 的旧论述清洗范围——例如 `docs/superpowers/plans/2026-05-31-blossom-theme.md` 里有「`surfacePanel`/`surfaceSidebar` delegate 到 canvasSubtle」的英文表述，FR-1 后变假，但归档是历史记录、不改。实现者全量 grep `surfacePanel` 时不要误入。
- 任何新组件、新 token、新样式。

## Dependencies

**内部**

- `Tests/CoreDesignTests/SurfaceContrastTests.swift`（FR-2）、`SystemBackgroundColorsMacOSTests.swift`（FR-3）
- `docs/component-contract.md:1278-1291`（FR-4 必须改写的终审裁决）、`docs/bool-exemptions.json:27-68`（FR-4 的 7 条 `bottomInputBar` Bool 豁免，其中 1 条 reason 会失真）
- 守卫族：`ComponentRegistryGuard` / `ComponentContractStructureGuard` / `ComponentExtensionPointGuard` / `ReachableTypeRegistryGuard` / `ComponentTextParamGuard` / `BoolParameterScanner`
- `scripts/run-snapshots.sh` 与 `App/Sources/Previews.swift` 的注册机制（FR-4 / FR-9）
- `Sources/CoreDesign/Colors/FillColors.swift`（FR-1 的填充族目标）

**外部**

- iOS 模拟器 runtime（**已装好**：iOS 26.4 / `iPhone 17 Pro`）+ `xcodebuild`（FR-2 / FR-9）
- `ios-visual-reviewer` agent（FR-9）
- `gh` CLI（FR-11）
- `oh-my-story` 仓 issue #50（FR-4 的跨仓通知对象）

**任务间依赖**

- FR-3 依赖 FR-1；FR-2 依赖 FR-1 + runtime
- FR-9 依赖 FR-1 + FR-4 + runtime
- FR-11 依赖其余全部
- FR-5/FR-6、FR-7、FR-8 三组彼此独立，可与 FR-1 并发
