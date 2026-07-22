# Issue #122 迁移映射表（核心交付物）

本表是 Task #122 的**核心产出**，也是 Task #126 撰写 `docs/BREAKING-CHANGES.md`「同名换值」一节的输入。

## 为什么需要这份表

#121 完成后代码是绿的、deprecation warning 是干净的——**而最大的一类风险恰恰在这时完全不可见**。

`CoreRadius.small` 从 3 变 6、`medium` 6→10、`large` 12→16、`CoreControlMetrics.height(.regular)` 32→44、语义色改指系统色：这些都是**同名换值**。编译器不报错、不产生 warning、grep 找不到、测试不变红，调用点静默继承新值。尤其**新 `small`(6) 恰好等于旧 `medium`(6)**——所有按旧语义选 `small = 3` 的调用点圆角直接翻倍。

这可能正是想要的效果，但必须是**逐点确认后的结论**，而不是换值的副产品。

## 调用点计数（实测，2026-07-22）

| | 代码调用点 |
|---|---|
| `CoreRadius`（全档合计） | **20** |
| `CoreControlMetrics.height` | **7** |

> ⚠️ 编排派单时给出的「圆角 28 处 / 高度 13 处」是**虚高的**——那次 grep 把文档注释行也计了进去。本表以 `grep -vE ":\s*//|///"` 过滤后的真实代码调用点为准。
>
> 这是本 epic 第五次计数漂移。结论已反复验证：**计数只用来估规模，判据永远是逐点看完**。

---

## CoreRadius.small（3pt → 6pt）—— 风险最集中的一组

新值恰好等于旧 `medium`。6 处调用点：

| 文件:行 | 旧值 | 新值 | 结论 | 理由 |
|---|---|---|---|---|
| `Modifier/SurfaceModifier.swift:79`（`.control`） | 3 | 6 | **保持** | 当前无任何生产调用点消费 `.surface(.control)`（仅其自身 `#Preview`），零风险。若将来有消费者，档位是否合适需届时判断 |
| `Components/ProgressBar/ProgressBar.swift:49` | 3 | 6 | **保持（实测无视觉变化）** | 轨道高度是 `CoreSpacing.xs` = 4pt，SwiftUI 在 radius > `min(w,h)/2` 时会 clamp 到 2pt，3 与 6 渲染结果完全一致。评审用 `ImageRenderer` 在 100×4pt 画布上逐像素比对验证：`.continuous` 与 `.circular` 两种角样式下 3 vs 6 **像素完全相同** |
| `Components/ProgressBar/ProgressBar.swift:51` | 3 | 6 | **保持** | 同上（轨道与填充两层，几何相同） |
| `Components/Tag/Tag.swift:118` | 3 | 6 | **保持** | chip 高度约 24–26pt（footnote + `xs` padding），6pt ≈ 高度的 23–25%，仍是明确的圆角矩形，与 Badge 的 `Capsule()` 形态清晰可分。已同步修正文档注释里残留的「3pt」 |
| `Components/SearchField/SearchField.swift:86` | 3 | 6 | **保持** | 44pt 高的输入框上 6pt 仍读作「克制的圆角」，非药丸形 |
| `Components/SearchField/SearchField.swift:138` | 3 | 6 | **保持** | focus ring 与外框同档，二者不会错配 |

## CoreRadius.medium（6pt → 10pt）—— 10 处

| 文件:行 | 结论 | 理由 |
|---|---|---|
| `Modifier/SurfaceModifier.swift:77`（`.canvas`） | **保持** | 等比上调，未发现与调用点尺寸错配 |
| `Modifier/SurfaceModifier.swift:78`（`.content`） | **保持** | 同上 |
| `Modifier/SurfaceModifier.swift:81`（`.overlay`） | **保持** | 同上 |
| `Modifier/SurfaceModifier.swift:82`（`.canvasSubtle`） | **保持** | 同上 |
| `Modifier/SurfaceModifier.swift:83`（`.panel`） | **保持** | 同上 |
| `Modifier/SurfaceModifier.swift:85`（`.card`） | **保持** | 10pt 对卡片容器是合理的 iOS 尺度 |
| `Modifier/FocusRingModifier.swift:112`（默认参数） | **保持** | 唯一真实消费者（`SearchField`）显式传 `.small` 覆盖它，该默认值当前不生效，无害 |
| `Components/Sidebar/Sidebar.swift:157` | **保持** | `.contentShape` 命中区域，与视觉圆角同档即可 |
| `Components/Sidebar/Sidebar.swift:411` | **保持** | 同上 |
| `Tokens/CoreElevation.swift:174` | **保持** | 仅 `#Preview` 内的演示卡片 |

## CoreRadius.large（12pt → 16pt）—— 3 处

| 文件:行 | 结论 | 理由 |
|---|---|---|
| `Modifier/SurfaceModifier.swift:80`（`.floating`） | **保持** | 当前无生产消费者 |
| `Modifier/FloatingGlassModifier.swift:55` | **保持** | 浮层玻璃容器，16pt 与 iOS 浮动面板尺度相符 |
| `Components/BottomInputBar/BottomInputBar.swift:231` | **保持** | 多行输入条增高后的形状；单行时走 `height/2` 药丸分支不受影响。16pt 读作柔和圆角矩形，与 iMessage 类输入条同族 |

## CoreRadius.none（0，未换值）—— 1 处

`Modifier/SurfaceModifier.swift:84`（`.sidebar`）—— 值未变，无需判断。

## CoreRadius.xLarge（22pt，新增档位）—— **0 处消费**

**结论：不是缺陷，是标度先于需求。**

`xLarge` 是为 Dialog / Modal / Sheet 类容器设计的，而库内目前没有这类组件（`Sources/CoreDesign/Components/` 下无对应目录，App 演示工程也无 `.sheet(` / `.fullScreenCover(` 调用）。也没有发现哪个现有场景本该用 22pt 却停在 `large`(16)——现有最大容器是 `.floating` 与 BottomInputBar，16pt 对它们是合适的。

与 `ConcentricRectangle` 的处境相同：同样零采纳，因为当前没有任何调用点嵌套在声明了 `.containerShape(_:)` 的父容器里。二者都是为后续组件预留的能力。

---

## CoreControlMetrics.height（24/28/32/40/48 → 28/32/44/50/56）—— 7 处

| 文件:行 | 档位 | 旧 | 新 | 结论 | 理由 |
|---|---|---|---|---|---|
| `Components/Sidebar/Sidebar.swift:154` | `.large` | 40 | 50 | **保持** | 既有注释已说明这是刻意的加高行，换值方向不影响该意图 |
| `Components/Button/styles/CircularGlassButtonStyle.swift:43` | `.large`（默认） | 40 | 50 | **保持，但标注** | 已重写其陈旧注释：旧标度 `.regular` 32 vs `.large` 40（差 8pt / 25%），新标度 44 vs 50（差 6pt / 约 13.6%）。方向仍成立，但**「显著」这个词已站不住**——留给 #125 判断两个相邻圆形按钮是否还读得出层级 |
| `Components/BottomInputBar/CoreMenuButton.swift:121` | `.large` | 40 | 50 | **保持** | 与输入条 trailing 圆形按钮保持视觉等高，该关系不受换值影响 |
| `Components/SegmentedControl/SegmentedControl.swift:149` | `.regular` | 32 | 44 | **保持** | 见下方说明 |
| `Components/SegmentedControl/SegmentedControl.swift:209` | `.regular` | 32 | 44 | **保持** | 同上 |
| `Components/SearchField/SearchField.swift:127` | `.regular` | 32 | 44 | **保持** | 44pt 是 HIG 触控下限，输入框理应满足 |
| `Components/ListRow/ListRow.swift:94` | `.regular` | 32 | 44 | **保持** | 同上，列表行是主要交互目标 |

**关于 `.regular` 32→44 的统一判断**：这不是某个调用点选错档，而是整个 token 族的设计意图——把全部主要交互控件统一到 HIG 的 44pt 最小触控目标。`SegmentedControl` 因此会把原生 `UISegmentedControl` 包装成高于其固有高度的外框，这是**有意的**，不是错配。#119 的 token 文档已记录该理由。

---

## 实际改值的两处

本任务的处置原则是：**档位已在 #119 定案，个别调用点不合适说明该点选错档，不是标度错**。只有当某档位对大量调用点都不合适时，才回头动 token。以下两处是「选错档」的改档，未触碰任何 token 数值。

### 1. `CoreMenuButton` 图标档位：`.regular`(16pt) → `.large`(20pt)

选型是在 #119 换值**之前**做的：当时容器 `.large` 是 40pt，`16/40 ≈ 0.4` 恰好命中 SF Symbol 在圆形容器内的 ~40% 经验值，而 `.large` iconSize (20pt) 会过冲到 50%。

换值后容器变 50pt：`16/50 = 0.32` **欠冲**，反而 `20/50 = 0.4` 精确命中。原结论方向翻转，故改档。

> **连带效应（评审指出，记录在此）**：`lineWidth = size / 12`，图标改档后描边宽度从 16/12 ≈ 1.33pt 变为 20/12 ≈ 1.67pt，汉堡 / X 线条本身也粗了约 25%。#125 视觉复核时须一并看线宽是否协调，不只是图标整体尺寸。

### 2. Badge neutral 背景：`surfaceCanvasSubtle` → `secondaryFill`

这是本任务挖出的**静默缺陷**，iOS Simulator 实测：

| | badge 背景 | `surfaceBase` | |
|---|---|---|---|
| light | `#FFFFFF` | `#FFFFFF` | **同色，完全不可见** |
| dark | `#1C1C1E` | `#000000` | 可辨 |

#120 把 `surfaceCanvasSubtle` 改指 `secondarySystemGroupedBackground` 后，它在浅色模式下与 `surfaceBase`（`systemBackground`）逐位相同。无描边的 neutral badge 放在普通页面背景上就消失了。

**根因是选错了 token 种类，不是选错了值。** badge 背景是叠在别人之上的一小块色，该用**填充色**（`FillColors`，半透明、专为叠加设计），而不是**背景色**（`SurfaceColors`，专为充当底层）。在 surface 族内换不出解——`surfaceCanvas` 会在深色模式与 `surfaceBase` 同为纯黑，`surfaceElevated` 会在浅色模式与 `surfaceCanvas` 同为 `#F2F2F7`。

改用 `secondaryFill`（浅色 α=0.16 / 深色 α=0.32），实测在 `surfaceBase` / `surfaceCanvas` / `surfaceRaised` 三种父容器、两种外观下均可辨。已加 `SurfaceContrastTests` 守卫。

---

## 语义色指向变更（#120 交接，本任务复核结论）

| 项 | 结论 |
|---|---|
| `ListRow` hover 背景 | **改善，非回归**。实测浅色 canvas `#F2F2F7` vs hover 白、深色 canvas 黑 vs hover `#1C1C1E`——两个模式下 hover 都比画布**更亮**，这正是 iOS 分组列表的标准形态（设置 app 的 cell 就比分组画布亮）。无需视觉复核 |
| `SegmentedControl` thumb 变白 | **改善**。thumb 填 `surfaceCanvasSubtle`（浅色为白）叠在半透明轨道上，与原生 `UISegmentedControl` 的选中段渲染几乎一致 |
| `Badge` neutral | **已定案并修复**（见上） |
| `surfaceCanvasInset` → `tertiaryFill` | **语义正确，但需目视**。由不透明变半透明后，可见密度确实随底色变化。留给 #125 重点看 ProgressBar 轨道在 card / canvas / sidebar 三种父容器下的表现 |
| `accentDisabled`（α=0.35）在纯黑深色画布上 | **低置信度，留给 #125**。深色下 `surfaceCanvas` 与 `surfaceBase` 均为纯黑，Apple 自家禁用控件也是同样的淡出方式——「暗但仍在」是预期的禁用观感，但不看渲染图无法确认够不够 |

---

## 明确留给 #125 视觉终审的五项

有些事不看渲染图就是判断不了，这里不硬下结论：

1. `CircularGlassButtonStyle` 的 `.regular`(44) 与 `.large`(50) 只差 6pt（约 13.6%）——两个相邻圆形按钮还读得出层级吗？
2. `CoreMenuButton` 图标 16pt → 20pt——在 50pt 按钮里会不会显大？**连带看线宽 1.33pt → 1.67pt 是否协调**
3. `accentDisabled`（α=0.35）在纯黑深色画布上够不够看得见
4. `ProgressBar` 轨道（`tertiaryFill` 半透明后）在三种父容器上的表现
5. Badge 修复后的实际观感确认

## 圆角出口收敛（AC 硬指标）

`grep -rn "RoundedRectangle(" Sources` 现在只剩 **1 处**：`Tokens/CoreRadius.swift:71`，即 `CoreShape.rounded(_:)` 自身的实现——包装器总得在某处调用原语，这是必要的唯一例外。10 个真实调用点 + 6 处文档示例全部迁移。

> **范围说明**：AC 的字面范围是 `Sources`（即 `Sources/CoreDesign`），**不含演示宿主 `App/`**。
> `App/Sources/ComponentDetail.swift:8` 仍有一处裸 `RoundedRectangle(cornerRadius:style:)`。
> 那不是本任务的缺陷（宿主不属于库的公开表面），但记录在此，免得后来者误以为全仓已 100% 收敛。

**副产品**：`FocusRingModifier` 此前用的是**隐式 `.circular`** 角样式，从未带过 `.continuous`——一个先于本 epic 存在的不一致，借这次收敛顺手修掉了。已用 `git log -p` 确认这确实是既有问题，不是本次引入。
