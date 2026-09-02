---
issue: 222
started: 2026-09-03
completion: 100%
---

# Issue #222 进度

## 1 · 四个字面量入 catalog

| 位置 | 字面量 | 处置 |
|---|---|---|
| `SearchField` TextField | `"Search"` | 只本地化 **fallback 分支**——`placeholder` 是调用方传入值，库不翻译 |
| `SearchField` 清除按钮 | `"Clear %@"` | 外层位置键 |
| `SearchField` 清除按钮 | `"search"` | ⚠️ **插值内层**的 fallback，按行粗扫看不见它 |
| `ProgressBar` | `"%@ complete"` | 见下方百分号处置 |

新增 catalog 键：`"%@ complete"` / `"Clear %@"` / `"Search"` / `"search"`。

### 百分号：绕开转义而非转义它

PRD 建议 `"%lld%% complete"` 或 `"%@%% complete"`，都要在 `.strings` 里转义百分号。
**我改为把 `50%` 整体作为一个 `%@` 参数传入**，格式串只剩 `"%@ complete"`——
`%` 留在 Swift 侧拼接，格式串里根本不出现需转义的字符。

理由：转义写错的失败形态是**渲染出字面量 `%%`**，肉眼不易察觉、编译也不红。
绕开比正确转义更难写错。已加断言显式钉住 `!v.contains("%%")`。

## 2 · 守卫（`AccessibilityStringLiteralGuard`）

扫 `Sources/CoreDesign/**/*.swift`，跳过 `#if DEBUG` 与注释行，找
`accessibilityLabel/Value/Hint` 中含字面量且不含 `bundle: .module` 的行。

**核心能力：看得见插值内层。** 扫描器逐字符走状态机，遇 `\(` 递归进插值，
插值里的 `"` 也算字面量——`Text("Clear \(x ? "search" : y)")` 产出
`["Clear ", "search"]` 而非只看到外层。

配了一个**守卫自身的能力自证** `scannerSeesNestedLiterals`：若它红了，
说明扫描器对本组最易漏的形态失明，那么主测试的「零命中」就不可信。

豁免台账落**新文件** `docs/a11y-exemptions.json`（不写进 `bool-exemptions.json`
——那个文件由 #221 同期改动）。锚定首例：`TagInput.swift` 的
`.accessibilityLabel(Text(self.placeholder))`，理由是入参由调用方传入。

### ⚠️ 扫描器踩过的坑：插值收尾状态机

首版变异自证时，报错里出现了一个伪片段 `"))"`——插值结束后我漏了「回到**外层
字面量内部**」这一步，于是把插值之后的普通代码当字面量收集了。

不影响判红（有真 offender 就该红），但会污染报错信息、并可能在别处**误报**。
已修，并加断言 `found.allSatisfy { $0 == "Clear " || $0 == "search" }` 钉住
不再产出伪片段。行尾仍在字面量态（跨行表达式）时丢弃 `current` 而非上报——
宁可漏报也不制造伪 offender。

## 验证

- **`swift test`：460 tests / 71 suites 全绿**（基线 454，+6 断言 +3 suite）
- **变异自证**（把清除按钮还原成插值内层硬编码）：
  ```
  ✘ Sources/.../SearchField.swift:123 → ["Clear ", "search"]
      | .accessibilityLabel(Text("Clear \(self.placeholder.isEmpty ? "search" : self.placeholder)"))
  ```
  **靶点打在插值内层**（task 规定），修复扫描器后报错片段干净、无伪片段。
  还原后恢复全绿。
- 本 task 无 iOS-only 断言，`swift test` 即为完整覆盖。


## 评审 checkpoint 的处置（REVISE → 已修）

### I-3（要害）· 守卫对跨行形态结构性失明

评审把我的 `stringLiterals` + 行循环复刻成独立 harness 实测，报出 7 种形态漏报/误报。
**最要害的是 Case I**：`SearchField.swift` 本轮的修复**本身就是折行三元**——
`.accessibilityLabel(` 在一行、`String(localized:...)` 在续行。按物理行扫描时
前者无字面量、后者无 modifier 名，**两边都不命中**。有人把它 revert 成裸字面量，
首版守卫会**恒绿**。同 MEMORY 的「跨行折断击穿单行 grep」。

**修法**：新增 `accessibilityCallSpans(in:)`，从含 a11y modifier 的行起
**按括号配平累积成逻辑调用段**，再对整段提字面量。同轮修掉：
- `#if DEBUG` 的 **`#else` 分支**（产品路径）被当 DEBUG 跳过 → 显式处理
- 三引号多行字面量整体不可见 → 整段收集
- 行尾注释里的引号误报 → `strippingTrailingComment` 按字符串态截断
- 插值内**嵌套括号**仍产伪片段 → 收尾按 paren 深度归零定位

**新增 3 条扫描器自证**（跨行三种形态 / `#else` 分支 / 行尾注释），把评审实测出的
失明形态逐个钉死；伪片段断言加了嵌套括号样本。

**变异靶点改打跨行形态**（首版对它恒绿）：把折行三元里的 catalog 调用 revert 成
裸 `"Search"` → 判红，且报错把折行拼成一条可读逻辑行。

### I-4 · 豁免粒度由整文件收窄为「文件:行号」

首版 `exemptedFiles()` 按文件路径整文件跳过，而台账记的是 `symbol: TagInput.body`
这个**单一调用点**——射程比声称的宽得多，该文件将来新增的任何裸 a11y 字面量都会
不可见。这是「登记了 ≠ 守住了」。已改为 `exemptedSites()`，台账 location 精确到
`TagInput.swift:105`。

### I-5 · 「断言取到 catalog 值」实际分不清 catalog 与 key 回退

我的期望值（`"50% complete"` / `"Clear search"`）与 **key 本身的回退渲染逐字相同**
（en 值 == key）——把四条新 key 全删或 bundle 接错走回退，那些断言**照样全绿**。
新增键存在性断言：用 sentinel value 取键，取到 sentinel 即判红。

⚠️ **这条新断言当场抓到一个真问题**：我首版把 `"iMessage"` 也列进了键清单，
而那是 **#221 分支**新增的键（BottomInputBar 的 B 类兜底），本分支没有 ⇒ 立刻判红。
是我把两个分支的键混在了一起。已移除。

### I-6 · 百分号处置：合理偏离，但代价此前未上账

评审认定这是**已声明的刻意偏离**、不算回避。但有一笔未认领的代价：
**百分号相对数字的位置被写死在 Swift 侧**——土耳其语写 `%50`、法语写 `50 %`，
`%lld%%` 方案里译者能经格式串控制这层，本写法不能。

已在 `percentValue` 的 doc 里上账，并写明取舍理由（转义方案的失败形态是渲染出
字面量 `%%`，肉眼不易察觉且不红；两害相权取「位置不可译」）与正解方向
（`value.formatted(.percent)`，属独立行为变更，归属下一轮 a11y 文案改造）。

## 最终验证

`swift test`：**464 tests / 71 suites 全绿**（基线 454）。


## 本地 Copilot CLI 评审的处置（外部第二声）

PR 版 Copilot 在本仓不可用（未装 reviewer 应用），按 skill §3.5.1 改跑本地 CLI。
它给出 ISSUES，其中针对 #222 的一条**扎在要害上**：

### 死豁免 —— 我给「登记了 ≠ 守住了」配的锚定首例，本身就是这个病

 是 ，
**不含任何字符串字面量**。我的守卫是「提字面量 → 非空则报」，对这一行本就提不出东西、
**从不会标记它**。于是那条豁免：

1. 当前**什么都没守住**——登记了一个空靶；
2. 更糟：若将来有人把该行改成裸字面量（ 这个键**历史上真实存在过**，
   见该行上方注释），豁免会**继续生效、静默放行**这个真实回归。

⚠️ **#222 整个 PR 的主题就是「登记了 ≠ 守住了」，而我给它配的锚定首例是个空靶。**

**处置**：移除该条（台账现为空， 写明原委）；新增自检
——每条豁免必须对应至少一处真实命中，否则判红。
变异自证：把死豁免加回去 → 精确判红并点名该站点；还原后恢复绿。

## 最终验证

Test Suite 'All tests' started at 2026-09-03 02:18:44.286.
Test Suite 'All tests' passed at 2026-09-03 02:18:44.305.
	 Executed 0 tests, with 0 failures (0 unexpected) in 0.000 (0.019) seconds
􀟈  Test run started.
􀄵  Testing Library Version: 1743
􀄵  Target Platform: arm64e-apple-macos14.0
􀟈  Suite "自有样式协议的消费判据" started.
􀟈  Suite "SkeletonLine" started.
􀟈  Suite "FloatingGlassModifier" started.
􀟈  Suite "accent 衍生族方向性" started.
􀟈  Suite "SkeletonRect" started.
􀟈  Suite "ExtendedFloatButtonStyle 档位默认值与静态工厂" started.
􀟈  Suite "AvatarGroup" started.
􀟈  Suite "别名表自洽：五条断言" started.
􀟈  Suite "组件判据规则层" started.
􀟈  Suite "Rating" started.
􀟈  Suite "FR-4 文本参数分类覆盖" started.
􀟈  Suite "CoreTypography.Token" started.
􀟈  Suite "BottomInputBar" started.
􀟈  Suite "#72 G-8 续 —— 可达类型登记表" started.
􀟈  Suite "分组分隔线 inset 推导" started.
􀟈  Suite "SkeletonCircle" started.
􀟈  Suite "StatusColors" started.
􀟈  Suite "Bool 豁免基线与棘轮" started.
􀟈  Suite "Shared Foundation — semi-mobile-components Phase 0" started.
􀟈  Suite "macOS 分组背景降级" started.
􀟈  Suite "组件登记表" started.
􀟈  Suite "系统控件 .core style 静态成员" started.
􀟈  Suite "Banner" started.
􀟈  Suite "AsyncButton" started.
􀟈  Suite "RatingStyle 扩展点" started.
􀟈  Suite "ProgressIndicator 文案存储" started.
􀟈  Suite "公约文档结构守卫" started.
􀟈  Suite "Button style defaults" started.
􀟈  Suite "ListRow" started.
􀟈  Suite "ToastHost queue state machine" started.
􀟈  Suite "组件判据扫描层" started.
􀟈  Suite "Descriptions" started.
􀟈  Suite "Colorset 资源存在性守卫" started.
􀟈  Suite "Radio" started.
􀟈  Suite "CardKind 取值域" started.
􀟈  Suite "SegmentedControl" started.
􀟈  Suite "ButtonRoleStyleRole 三态取色" started.
􀟈  Suite "TagInput" started.
􀟈  Suite "StateLabel" started.
􀟈  Suite "组件判据端到端变异" started.
􀟈  Suite "SearchField" started.
􀟈  Suite "登记表↔扫描器 差集纯函数" started.
􀟈  Suite "Steps" started.
􀟈  Suite "RatingDisplay" started.
􀟈  Suite "基础容器 Separator.Inset 逻辑" started.
􀟈  Suite "J-3 原生协议纯度" started.
􀟈  Suite "a11y 字面量必须走 String Catalog" started.
􀟈  Suite "Carousel" started.
􀟈  Suite "`.tint` 真实响应（像素级）" started.
􀟈  Suite "J-2 样式扩展点" started.
􀟈  Suite "SkeletonShimmerMath" started.
􀟈  Suite "Tag" started.
􀟈  Suite "Skeleton" started.
􀟈  Suite "ProgressBar（弃用守卫）" started.
􀟈  Suite "资源 bundle canary" started.
􀟈  Suite "FlowLayout" started.
􀟈  Suite "Timeline" started.
􀟈  Suite ToastPresentationRenderTests started.
􀟈  Suite "SpinningModifier 存储契约" started.
􀟈  Suite "Sidebar components" started.
􀟈  Suite "CoreButtonMetrics" started.
􀟈  Suite "Bool 分类器残余形态回归" started.
􀟈  Suite "UnderlinedTabBar" started.
􀟈  Suite "PinCode" started.
􀟈  Suite "Toast 公开入口的参数转发" started.
􀟈  Suite "D2 接线通路二：extension View modifier 的三条收窄条件" started.
􀟈  Suite "SidebarUtilityRow leading 槽渲染护栏（#64）" started.
􀟈  Suite "Badge" started.
􀟈  Suite "ProgressBar a11y 本地化" started.
􀟈  Suite "Bool 参数扫描层" started.
􀟈  Suite "SearchField a11y 本地化" started.
􀟈  Test "默认初始化落在 .large 档" started.
􀟈  Test "overflow accessibility label includes avatar context" started.
􀟈  Test "init with max parameter stores value" started.
􀟈  Test "静态工厂 .extendedFloat(size:) 透传档位" started.
􀟈  Test "静态成员 .extendedFloat 默认落在 .large 档" started.
􀟈  Test "AvatarGroup：.countOnly 下 max 仍被原样保留（不生效 ≠ 被改写）" started.
􀟈  Test "default max is 3" started.
􀟈  Test "AvatarGroup：四种排布都能构造且 body 可求值（不 crash）" started.
􀟈  Test "AvatarGroupAccessibility：totalLabel 走 %lld avatars 复数键，不自造字面键" started.
􀟈  Test "AvatarGroupAccessibility：totalLabel 与 overflowLabel 语义不同、文案不同" started.
􀟈  Test "显式档位被保留" started.
􀟈  Test "AvatarGroup：layout 原样保留" started.
􀟈  Test "AvatarGroup：layout 默认 .overlapped —— 现有调用方零影响" started.
􀟈  Test "承重：填了 customStyleProtocol 的组件，body 里真的调用了 style.makeBody(configuration:)" started.
􀟈  Test "fillFraction：value 为 0 时全部星为空" started.
􀟈  Test "step: .infinity clamp 回 1.0——挡住 steppedValue 产出 NaN（#41 收尾修复）" started.
􀟈  Test "steppedValue：step=0.5 按 ceiling——星 k 左半 → k−0.5、右半 → k" started.
􀟈  Test "AvatarGroupLayout：四个 case 互不相等（Equatable 不是恒真）" started.
􀟈  Test "steppedValue：step=1.0 按 ceiling——点第 k 颗星得 k 分" started.
􀟈  Test "FR-4 附条：owner 翻译表每一条都必须真的被用到（不许有过期条目）" started.
􀟈  Test "value 通过 Binding 双向绑定，构造时原样保留（不额外 clamp）" started.
􀟈  Test "② 表里每个 value 都是源码里存在的公开 modifier 方法名" started.
􀟈  Test "散文 ⟂ 数据判据必须抓得住 #67 真实发生过的三条矛盾" started.
􀟈  Test "fillFraction：整星为 1，未达到的星为 0" started.
􀟈  Test "措辞表与撤回标记表不得静默增删" started.
􀟈  Test "fillFraction：半星在过渡星上给出 0.5" started.
􀟈  Test "steppedValue：relativeX 为负数 clamp 到 0 分" started.
􀟈  Test "仅 captionMono 是等宽" started.
􀟈  Test "J-2 形态 D2 变异：enum 声明了但没接进任何公开 init ⇒ 必须判红" started.
􀟈  Test "FR-4 附条：by-type 分类必须真的没有孪生裸串重载（公约 §4 的实际筛子）" started.
􀟈  Test "12 档一一对应系统文本样式" started.
􀟈  Test "step 非正值 clamp 回 1.0——挡住「静默恒 0」，不是挡除零" started.
􀟈  Test "④ 每个 value 必须真的携带该条目登记的 styleEnum 作为参数" started.
􀟈  Test "bottom input bar constructs with defaults" started.
􀟈  Test "accessibilityValueText：按 Phase 0 位置键 "%@ of %@" 组装，两端为 formatted() 结果" started.
􀟈  Test "FR-4：public init 的裸文本参数必须在登记表 textParams 里有分类条目" started.
􀟈  Test "totalHeight for a single line has no spacing contribution" started.
􀟈  Test "steppedValue：totalWidth / count / step 非法输入归零，不崩溃" started.
􀟈  Test "bottom input bar constructs with placeholder and run state" started.
􀟈  Test "恰好 12 档，无隐藏 case" started.
􀟈  Test "count 默认 5，step 默认 1.0（整星）" started.
􀟈  Test "J-3 探针：采纳 Apple 原生协议不算命中（自有协议集合里没有它）" started.
􀟈  Test "J-3 变异：给 nativeProtocol 组件的作用域塞进自有样式协议 ⇒ 判红（违规集合精确）" started.
􀟈  Test "J-2 形态 D2 变异：enum 接在别的组件上 ⇒ 本条目必须判红（不许跨组件借线）" started.
􀟈  Test "step 不设上界——count == 0 是合法入参，任何 step ≤ count 的上界都会恒不可满足" started.
􀟈  Test "isLastLine is true only for the final row of a multi-line block" started.
􀟈  Test "count / step 原样保留" started.
􀟈  Test "J-2 变异：协议已声明但零实现 ⇒ 判红（AC 原文『定义 + 使用』）" started.
􀟈  Test "J-3：作用域解析不出来必须报告，不能算绿（零输出不是绿）" started.
􀟈  Test "J-3 探针：作用域文件里声明的自有样式协议算命中（通道 i）" started.
􀟈  Test "steppedValue：relativeX 超出总宽 clamp 到最大星数" started.
􀟈  Test "SettingsDividerInset.value 三档映射（顶层类型，非泛型嵌套）" started.
􀟈  Test "Rating(count:) 拒绝负数星数，落到 0" started.
􀟈  Test "accessibilityValueText：半星精确播报，不取整（与整星取整后的文案不同）" started.
􀟈  Test "J-3 结构约束：主判据的违规集合就是探针的命中集合（判据不得内联重写探针）" started.
􀟈  Test "J-2 形态 D1 变异：私有 body 里的 @ViewBuilder 不算扩展点（调用方够不着）" started.
􀟈  Test "width(forLineAt:containerWidth:) narrows only the last line of a multi-line block" started.
􀟈  Test "textAligned = 横向 padding（无图标列）" started.
􀟈  Test "J1：schema 合法 —— type 唯一、repo 与 category 在允许域、notes 非占位" started.
􀟈  Test "J8：全部条目的 category 都是 C（并集规则的机器触发点）" started.
􀟈  Test "J-2 变异：协议声明被移走 ⇒ 判红（且违规集合精确）" started.
􀟈  Test "J-3 探针：组件（或其 extension）采纳自有样式协议算命中（通道 ii）" started.
􀟈  Test "③ 表里每个 key 都确实不等于任何单个公开类型名" started.
􀟈  Test "default diameter is 40" started.
􀟈  Test "FR-4：owner 别名 + 限定参数名两条解析路径" started.
􀟈  Test "FR-4：category 为空串的条目不算覆盖（AC 原文『且分类非空』）" started.
􀟈  Test "J3：同一 type 内的参数名唯一" started.
􀟈  Test "J2：本表的 type 与组件登记表的 component 不相交" started.
􀟈  Test "J-2：四个扩展点字段全为 null ⇒ 判红（Rating / Toast 的形态）" started.
􀟈  Test "J-2 形态 D1 变异：styleSlot 源码里不存在 ⇒ 判红（不是填了就算）" started.
􀟈  Test "⑤ 每个 styleEnum 只能被一个条目认领（别名表打破了原来的隐式约束）" started.
􀟈  Test "J-2：自有协议已声明且有实现 ⇒ 满足" started.
􀟈  Test "J-2：nativeProtocol 走 conformance 通路，不要求本仓声明该协议" started.
􀟈  Test "totalHeight sums line heights plus inter-line spacing" started.
􀟈  Test "① 表里每个 key 都在登记表里存在" started.
􀟈  Test "FR-4：宿主不对应登记表条目 ⇒ 进 unmappedOwners，不判红也不静默" started.
􀟈  Test "lastLineWidthFraction below 0 clamps to 0" started.
􀟈  Test "custom metrics are stored" started.
􀟈  Test "FR-4：kind == excluded 的组件整体豁免（弃用条款「不分类」）" started.
􀟈  Test "运行期字符串经 StringProtocol 重载可构造（编译级守卫）" started.
􀟈  Test "iconAligned = 横向 padding + 图标方块宽 + 间距（非硬编码）" started.
􀟈  Test "FR-4：同一个键被多个 init 重载命中时，各桶按键去重（计数单位是键不是命中）" started.
􀟈  Test "explicit width is preserved" started.
􀟈  Test "J-2 定义域：非 semantic / 不要扩展点 / 非本仓的条目都不进 inspected" started.
􀟈  Test "J-3：只在 nativeProtocol != nil 时触发（SegmentedControl 不得被自己的协议判红）" started.
􀟈  Test "isLastLine is always false for a single line" started.
􀟈  Test "混合只动明度、不显著降 alpha" started.
􀟈  Test "width(forLineAt:containerWidth:) never narrows a single line" started.
􀟈  Test "J-2 形态 D2 的限度：接线判据核不了『枚举承载的是不是形态候选』" started.
􀟈  Test "混合基色未被提前解析——四档在浅色与深色下取值不同" started.
􀟈  Test "J-2 形态 D1：styleSlot 在源码里真实存在 ⇒ 满足" started.
􀟈  Test "FR-4 反向：登记表有条目、源码扫不到 ⇒ 幽灵条目" started.
􀟈  Test "default init has nil width and CoreRadius.medium corner radius" started.
􀟈  Test "J-3 变异：conformance 通道同样判红" started.
􀟈  Test "J-2 形态 D 变异：两个扩展点字段同时非空 ⇒ 靠后那条通路被静默略过" started.
􀟈  Test "FR-4：登记表 notes 点名了参数名 ⇒ 豁免；没点名 ⇒ 判红" started.
􀟈  Test "explicit diameter is preserved" started.
􀟈  Test "status token 各指向正确的 colorset asset" started.
􀟈  Test "J-2 形态 D2 变异：internal enum 不算（不是公开 API 面）" started.
􀟈  Test "J-2 形态 D2：styleEnum 真实存在 ⇒ 满足；不存在 ⇒ 判红" started.
􀟈  Test "lineCount below 1 clamps to 1" started.
􀟈  Test "FR-4：LSK/LSR 由类型判定，不要求登记表条目，但必须被识别" started.
􀟈  Test "豁免清单的每个键都是扫描器能产出的形状" started.
􀟈  Test "棘轮：豁免清单条目数与基线 maxEntries 严格相等、源码位置数与 sourceSites 严格相等，且基线自身字段齐全" started.
􀟈  Test "FR-4：裸文本参数在 textParams 里有条目 ⇒ covered" started.
􀟈  Test "explicit lineCount is preserved" started.
􀟈  Test "default init uses a single line" started.
􀟈  Test "扫描器真的扫到了 public Bool 参数，且覆盖公约点名的每一条" started.
􀟈  Test "J-1：public 声明不得含未豁免的 Bool 参数" started.
􀟈  Test "Phase 0 预登记的 accessibility 字符串键已注册进资源 bundle" started.
􀟈  Test "Rating 星数复数键：one/other 形态正确" started.
􀟈  Test "J-4：豁免基线存在、可解析、每条四字段齐全且理由不是空话" started.
􀟈  Test "isInteractive 透传到 modifier" started.
􀟈  Test "FR-4 变异：新增未登记的裸文本参数 ⇒ 判红；补登记 ⇒ 转绿" started.
􀟈  Test "init 默认非交互" started.
􀟈  Test "未豁免违规集合与 pendingViolationKeys（现为空集）恰好相等（这条是**绿**的，专抓新违规）" started.
􀟈  Test "pressed 在浅色下变暗、在深色下变亮——即始终远离背景" started.
􀟈  Test "三档分组背景：canvas 独立，secondary 与 tertiary 已知塌缩" started.
􀟈  Test "豁免宿主要么在登记表里，要么在 AD 台账里且该分类真的成立" started.
􀟈  Test "hover 与 pressed 同向，且 pressed 走得更远" started.
􀟈  Test "语义层 surfaceCanvas 与 surfaceRaised 不同色" started.
􀟈  Test "canvas 与 raised 的底层 token 不同色" started.
􀟈  Test "登记表每条含全部必需字段，且取值在允许域内" started.
􀟈  Test "AvatarGroup 总数复数键：one/other 形态正确" started.
􀟈  Test "Steps 步数复数键：one/other 形态正确" started.
􀟈  Test "反向：每个非 excluded 的 coredesign 条目都被 README 索引覆盖" started.
􀟈  Test "FR-4：func 侧裸文本参数进留痕桶，不进主判据" started.
􀟈  Test ".disclosureGroupStyle(.core) 产出 CoreDisclosureGroupStyle" started.
􀟈  Test ".labelStyle(.core) 产出 CoreLabelStyle" started.
􀟈  Test "banner constructs with info level" started.
􀟈  Test "_runThrowing:CancellationError 静默 — 不调 onError、不弹 toast" started.
􀟈  Test "banner constructs with danger level" started.
􀟈  Test "Skeleton 取色 token 可引用且编译可用" started.
􀟈  Test "`readmeRowCoverage` 自洽：key 真在 README、value 真是条目、理由不是空话" started.
􀟈  Test "README 索引引用的快照 PNG 必须真的存在" started.
􀟈  Test "非抛错 init 能正常构造" started.
􀟈  Test "_runThrowing:onError nil + toastHost nil → 静默,不崩" started.
􀟈  Test "_runThrowing:业务错误透传给 onError(不弹 toast)" started.
􀟈  Test ".progressViewStyle(.core) 产出 CoreProgressViewStyle" started.
􀟈  Test "覆盖事实的单一来源：prefix / alias 表能推出的覆盖，coverage 表必须已经包含" started.
􀟈  Test "lastLineWidthFraction above 1 clamps to 1" started.
􀟈  Test "重载解析:抛错文本 init 编译" started.
􀟈  Test "_runThrowing:onError nil + toastHost 存在 → 自动弹 .danger toast" started.
􀟈  Test "扫描器真的扫到了 CoreDesign 的类型" started.
􀟈  Test "重载解析:非抛错文本 init 编译" started.
􀟈  Test "explicit diameter overrides the tier" started.
􀟈  Test "init(text: LocalizedStringKey) 存入本地化文案" started.
􀟈  Test "环境值默认实现是 StarRatingStyle" started.
􀟈  Test "RatingStyleConfiguration 只携带外观所需状态（value / count），不带行为" started.
􀟈  Test "solid / light 只按 role 参数化，直接构造与工厂两条路给出同一个 role" started.
􀟈  Test "公约的 markdown 表格没有被裸换行劈开的行" started.
􀟈  Test "init() 无破坏：不带文案（NFR-6）" started.
􀟈  Test "init(text: StringProtocol) 存入 verbatim 文案" started.
􀟈  Test "View.ratingStyle(_:) 把 style 写进环境值，换得掉默认实现" started.
􀟈  Test "circular glass defaults to the large tier, not an explicit diameter" started.
􀟈  Test "list row constructs with label only" started.
􀟈  Test "list row constructs with leading and trailing" started.
􀟈  Test "conformance 采集：容忍限定名与泛型形参（SwiftUI.View / Foo<T>）" started.
􀟈  Test "README 组件索引每个候选名都有归宿：登记表 / styleImpls（须真的扫到）/ 墓碑 / 排除 / **聚合映射** / 辅助类型 / 别名与容器前缀（守卫绿态下不可达）" started.
􀟈  Test "Rating.body 真的经 style.makeBody 渲染——不是声明协议但绕过它硬编码星形" started.
􀟈  Test "双向 / 容器形态判 .textCarrying（清点、不进判据）" started.
􀟈  Test "非可访问性档位：effectiveColumns 原样返回调用方偏好" started.
􀟈  Test "baseTypeName：已知限度 —— 泛型包装会在 `<` 处截断，接线记录随之丢失" started.
􀟈  Test "公约文档含全部 5 个必需节" started.
􀟈  Test ".two 列：切分覆盖每个索引恰好一次，且保持原始顺序" started.
􀟈  Test "shadow 四档 colorset 存在（CoreElevation 消费）" started.
􀟈  Test "circular glass tier accessor keeps the requested tier" started.
􀟈  Test "采集器：Binding / 回调进 carrying，不进 bareText" started.
􀟈  Test "返回位是文本的函数类型判为文本（登记表把 `(Item) -> String` 记成 textParams）" started.
􀟈  Test "采集器：init 与 func 分桶（FR-4 主判据只吃 init）" started.
􀟈  Test ".labeledContentStyle(.core) 产出 CoreLabeledContentStyle" started.
􀟈  Test "status 语义色 colorset 全部存在（StatusColors 消费）" started.
􀟈  Test "非 String 的 StringProtocol（Substring）同样可构造，@_disfavoredOverload 不影响非字面量调用" started.
􀟈  Test "RatingDisplay.body 真的经 style.makeBody 渲染——不是声明协议但绕过它硬编码星形" started.
􀟈  Test "采集器：public init 的裸文本参数进 bareTextKeys" started.
􀟈  Test "17 色相 × 10 色阶 colorset 全部存在" started.
􀟈  Test "CoreDesign 侧：登记表覆盖全部组件类型，且无幽灵条目" started.
􀟈  Test "类型→文件索引：类型声明与 extension 都记进宿主文件" started.
􀟈  Test "采集器：public extension 给成员与嵌套具名类型发默认 public（裁决 g）" started.
􀟈  Test "公约文本提及守卫允许域里的每一个取值（终审 I1(b)：给通则装上牙）" started.
􀟈  Test "StringProtocol 泛型形参名判 .bareText（`init<S: StringProtocol>(title: S)`）" started.
􀟈  Test "采集器：`init<S: StringProtocol>` 的泛型形参判裸文本（含 where 子句写法）" started.
􀟈  Test "样式协议识别：信号是 makeBody(configuration:) requirement，不是名字里有 Style" started.
􀟈  Test ".two 列 + 奇数行数：最后一组只含 1 个索引（占满整行）" started.
􀟈  Test ".two 列 + 偶数行数：全部两两配对，无落单组" started.
􀟈  Test "采集器：非 public 与 private 容器整体不可见" started.
􀟈  Test ".one 列：每行单独成组，组数恒等于行数" started.
􀟈  Test "isSelected across multiple option/selection pairs" started.
􀟈  Test "真实源码扫描：文本参数三个桶的实测规模" started.
􀟈  Test "采集器：`#if` 两支都走、`#Preview` 整块跳过" started.
􀟈  Test "rowCount 为 0 时不产出任何组（.one / .two 均同）" started.
􀟈  Test "RadioGroup constructs with horizontal axis" started.
􀟈  Test "conformance 采集：类型声明与 extension 两条路径都要认" started.
􀟈  Test "DescriptionsColumns 两个枚举值互不相等" started.
􀟈  Test "RadioOption.id equals value for Int-backed selection" started.
􀟈  Test "RadioGroup constructs with vertical axis (default)" started.
􀟈  Test ".two 列 + 单行：唯一一组只含 1 个索引" started.
􀟈  Test "CardKind 到 SurfaceKind 的映射逐一正确" started.
􀟈  Test "可访问性档位：effectiveColumns 无论调用方传入什么都强制单列" started.
􀟈  Test "some/any StringProtocol 判 .bareText —— 与 `<S: StringProtocol>(title: S)` 是同一声明的语法糖、调用点逐字相同（#40 Task 2 评审 Important-1）" started.
􀟈  Test "非文本判 .notText" started.
􀟈  Test "isSelected works with an enum-backed SelectionValue" started.
􀟈  Test "每个 role 的三态都取自本 role 的调色板" started.
􀟈  Test "RadioOption.id equals value (Identifiable contract)" started.
􀟈  Test "both built-in styles produce a body from a configuration" started.
􀟈  Test "segmented control constructs with two items" started.
􀟈  Test "isSelected returns false when option does not match current selection" started.
􀟈  Test "样式协议识别：makeBody 的参数标签必须是 configuration" started.
􀟈  Test "isSelected returns true when option matches current selection" started.
􀟈  Test "enabled 时按 pressed 分流" started.
􀟈  Test "裸文本：String 的各种等价拼法都判 .bareText" started.
􀟈  Test "tagToCommit returns normalized tag when not a duplicate" started.
􀟈  Test "空队列 show(...) 立即开始显示" started.
􀟈  Test "segmented control constructs with three items" started.
􀟈  Test "disabled 优先于 pressed" started.
􀟈  Test "splitDraftOnSeparator keeps the trailing partial segment as remainder" started.
􀟈  Test "CardKind 恰好只有 .content / .grouped 两个 case" started.
􀟈  Test "removingTag deletes the correct element among duplicates by offset" started.
􀟈  Test "plain style opts out of glass via the style modifier" started.
􀟈  Test "每个 role 的 color / activeColor / disabledColor 三态互不相同" started.
􀟈  Test "splitDraftOnSeparator returns no segments when draft has no comma" started.
􀟈  Test "removingTag with a negative index is a no-op" started.
􀟈  Test "tag input constructs with default parameters" started.
􀟈  Test "normalizedTag trims surrounding whitespace" started.
􀟈  Test "removingTag with an out-of-range index is a no-op" started.
􀟈  Test "tagToCommit returns nil for blank input regardless of dedupe policy" started.
􀟈  Test "normalizedTag trims surrounding newlines" started.
􀟈  Test "tagToCommit allows duplicate when allowDuplicates is true" started.
􀟈  Test "normalizedTag is case sensitive (no normalization)" started.
􀟈  Test "tagToCommit rejects duplicate when allowDuplicates is false" started.
􀟈  Test "normalizedTag returns nil for empty string" started.
􀟈  Test "normalizedTag preserves internal whitespace" started.
􀟈  Test "splitDraftOnSeparator splits multiple comma-separated segments" started.
􀟈  Test "可本地化文本：LSK / LSR 及其可选形态判 .localizedText" started.
􀟈  Test "normalizedTag returns nil for whitespace-only string" started.
􀟈  Test "tagToCommit dedupe check is case sensitive" started.
􀟈  Test "端到端 FR-4 反向变异：把已登记参数改名 ⇒ 登记表条目变成幽灵" started.
􀟈  Test "convenience init accepts a custom label and preserves style" started.
􀟈  Test "default labels come from the style spec" started.
􀟈  Test "端到端：副本未变异时，三条判据的结果与真实源码一致（基线）" started.
􀟈  Test "端到端 FR-4 变异：给 Avatar 加一个未登记的裸 String 参数 ⇒ 判红；补登记 ⇒ 转绿" started.
􀟈  Test "端到端 J-2 变异：删掉 BannerStyle 的全部实现 ⇒ Banner 判缺扩展点（『定义 + 使用』的使用侧）" started.
􀟈  Test "端到端 J-3 变异（通道 ii）：让 ProgressIndicator 采纳 BannerStyle ⇒ 判红" started.
􀟈  Test "all styles construct and expose a spec" started.
􀟈  Test "tag input constructs with all parameters" started.
􀟈  Test "双方完全一致 ⇒ 两个方向都空" started.
􀟈  Test "search field constructs with default placeholder" started.
􀟈  Test "accessibilityLabelText：非空 description 时拼接为 "title: description"" started.
􀟈  Test "search field constructs with submit handler" started.
􀟈  Test "progress：首索引（0）在 currentIndex 为 0 时为 current，为负数时为 pending" started.
􀟈  Test "登记表有源码里找不到的条目 ⇒ ghosts 非空、missing 仍为空" started.
􀟈  Test "端到端 J-2 变异：把 BannerStyle 协议声明改名 ⇒ Banner 判缺扩展点" started.
􀟈  Test "源码新增组件但登记表没有 ⇒ missing 非空、ghosts 仍为空" started.
􀟈  Test "accessibilityValueText：当前步骤按 Phase 0 位置键 "%@ of %@" 组装（1-based）" started.
􀟈  Test "accessibilityValue 文案与 Rating 共用同一个位置键，不另起一套" started.
􀟈  Test "accessibilityLabelText：空字符串 description 视同缺省，不拼接" started.
􀟈  Test "active maps to success status color" started.
􀟈  Test "Steps：.segmentedBar 的每段对应它自己那一步，不跟着前一步走" started.
􀟈  Test "两个方向可以同时非空——漏登记与幽灵条目互不掩盖" started.
􀟈  Test "completed maps to done status color" started.
􀟈  Test "count 负数 clamp 到 0（与 Rating 同一条仓内惯例）" started.
􀟈  Test "progress：index 等于 currentIndex → current" started.
􀟈  Test "端到端 J-3 变异（通道 i）：往 ProgressIndicator.swift 塞一个自有样式协议 ⇒ 判红" started.
􀟈  Test "Steps.progressSummary：越界 currentIndex 被夹进 1...total，且不溢出" started.
􀟈  Test "progress：index 小于 currentIndex → done" started.
􀟈  Test "progress：index 大于 currentIndex → pending" started.
􀟈  Test "accessibilityValueText：当前步骤同时是错误态——位置 + Error 以 ", " 拼接" started.
􀟈  Test "StepItem：title 必填，description / isError 默认值" started.
􀟈  Test "Steps：indicatorStyle 与 presentation 正交 —— 两者独立保留，互不改写" started.
􀟈  Test "Steps：axis 默认 .horizontal，indicatorStyle 默认 .dot" started.
􀟈  Test "positionText：两端为 Int.formatted() 结果" started.
􀟈  Test "value / count 原样保留，count 默认 5" started.
􀟈  Test "StepItem：显式传入 id 时原样保留，不覆盖为新 UUID" started.
􀟈  Test "StepItem：description / isError 原样保留" started.
􀟈  Test "Steps：四种呈现都能构造且 body 可求值（不 crash）" started.
􀟈  Test "accessibilityValueText：非当前步骤且非错误态返回 nil" started.
􀟈  Test "accessibilityLabelText：无 description 时只用 title" started.
􀟈  Test "Steps：presentation 默认 .steps —— 现有调用方零影响" started.
􀟈  Test "Steps：items / currentIndex / axis / indicatorStyle 原样保留" started.
􀟈  Test "accessibilityValueText：错误态非当前步骤只播报 "Error"" started.
􀟈  Test "removingTag at the second duplicate leaves the first untouched" started.
􀟈  Test "Inset Equatable：leading(0) 与 edgeToEdge 是不同的 case" started.
􀟈  Test "leadingAmount: edgeToEdge→0, leading(x)→x" started.
􀟈  Test "CoreLabelStyle 的 icon 随 .tint 变色，而非恒取 accent" started.
􀟈  Test "每条豁免都必须对应一处真实命中——不许有死豁免" started.
􀟈  Test "Sources/ 下非 DEBUG 路径的 a11y 字面量全部走 bundle: .module" started.
􀟈  Test "#if DEBUG 的 #else 分支是产品路径，不得被跳过" started.
􀟈  Test "扫描器能看见插值内层的字面量" started.
􀟈  Test "Steps：.segmentedBar / .text 塌成单 element 后，错误态仍经 accessibilityValue 播报" started.
􀟈  Test "offset starts at -width when progress is 0" started.
􀟈  Test "行尾注释不产生误报" started.
􀟈  Test "推进到集合中间的下一个元素" started.
􀟈  Test "progress：尾索引在 currentIndex 越界到 items.count 时为 done（全部完成场景）" started.
􀟈  Test "J-3：标注 nativeProtocol 的组件，作用域内不得出现自有样式协议" started.
􀟈  Test "current 不在集合中时回落到首个元素（防御式处理数据源变化）" started.
􀟈  Test "CoreProgressViewStyle 的填充条随 .tint 变色，而非恒取 accent" started.
􀟈  Test "单页边界：1 of 1" started.
􀟈  Test "末尾元素之后回绕到首个元素" started.
􀟈  Test "offset stays within [-width, width] across the full period" started.
􀟈  Test "扫描器能看见跨行调用——评审实测的失明形态" started.
􀟈  Test "placeholder and content builders are preserved without erasure" started.
􀟈  Test "isLoading true stores the loading flag" started.
􀟈  Test "composed placeholder tree (circle + line) type-checks without erasure" started.
􀟈  Test "isLoading false stores the loading flag" started.
􀟈  Test "tag constructs with text and color" started.
􀟈  Test "非空数据源可安全构造并生成 body" started.
􀟈  Test "空数据源可安全构造" started.
􀟈  Test "init with value stores clamped value" started.
􀟈  Test "offset is periodic with the configured duration" started.
􀟈  Test "单元素集合恒返回自身" started.
􀟈  Test "StepsPresentation：四个 case 互不相等（Equatable 不是恒真）" started.
􀟈  Test "non-finite value sanitized to 0" started.
􀟈  Test "bundle 里必须能找到 xcassets——目录形式或编译后的 Assets.car" started.
􀟈  Test "init with default spacing uses CoreSpacing.xs" started.
􀟈  Test "offset with zero or negative width returns zero" started.
􀟈  Test "removable tag constructs without crash" started.
􀟈  Test "Steps：presentation 原样保留" started.
􀟈  Test "CoreDisclosureGroupStyle 的 chevron 随 .tint 变色，而非恒取 accent" started.
􀟈  Test "Steps：.text 呈现只消费 items.count 与 currentIndex —— 逐条内容不参与" started.
􀟈  Test "init with custom spacing stores value" started.
􀟈  Test "value clamped to 0...1" started.
􀟈  Test "isLastItem：数组末条返回 true" started.
􀟈  Test "accessibilityLabelKey：StatusLevel 各档映射到 Phase 0 预登记键" started.
􀟈  Test "TimelineItem(content:)：status 缺省为 .info" started.
􀟈  Test "progress：currentIndex 为 0 且只有一步时该步为 current" started.
􀟈  Test "空集合恒返回 nil" started.
􀟈  Test "optional tint and label stored" started.
􀟈  Test "Timeline：四种布局都能构造且 body 可求值（不 crash）" started.
􀟈  Test "Timeline：layout 原样保留" started.
􀟈  Test "Timeline：layout 默认 .vertical —— 现有调用方零影响" started.
􀟈  Test "TimelineLayout：四个 case 互不相等（Equatable 不是恒真）" started.
􀟈  Test "Timeline(items:)：空数组不崩溃" started.
􀟈  Test "TimelineItem(status:node:content:)：node 非 nil（自定义节点覆盖默认圆点）" started.
􀟈  Test "isLastItem：单条数组，唯一元素即末条" started.
􀟈  Test "Timeline(items:)：items 数量与顺序原样保留" started.
􀟈  Test "J-2：语义组件必须有样式扩展点（原生协议采纳 或 自有协议定义+使用）" started.
􀟈  Test "isLastItem：item 不在 items 中（不同 id）返回 false，不崩溃" started.
􀟈  Test "A9 承重：注入的 host 真的驱动了产线挂载路径" started.
􀟈  Test "isLastItem：非末条返回 false" started.
􀟈  Test "Timeline：.grouped 下 node: 槽仍被原样保留（不生效 ≠ 被改写）" started.
􀟈  Test "Timeline：.grouped 删掉节点列后，默认节点项的状态语义经 accessibilityValue 补回" started.
􀟈  Test "Timeline.alternateSlotWidth：三列几何的槽宽，且节点中心恰落在行中心" started.
􀟈  Test "isActive / text 透传存储" started.
􀟈  Test "TimelineItem：显式传入的 id 原样保留（不被 UUID() 缺省值覆盖）" started.
􀟈  Test "accessibilityLabelKey：danger 映射到 "Error"（非字面 "Danger"，对 VoiceOver 更清晰）" started.
􀟈  Test "sidebar section constructs with text content" started.
􀟈  Test "TimelineItem(status:content:)：node 为 nil，status 原样保留" started.
􀟈  Test "SpinningModifier：presentation 默认 .overlay —— 现有调用方零影响" started.
􀟈  Test "A5b 承重：容器形状真的不同（banner 是矩形，capsule 有圆角）" started.
􀟈  Test "TopBarIndicator：轨道常驻 ⇒ 任意相位下顶条都占据可见高度" started.
􀟈  Test "A7 兜底：全部形态都能渲染出非空内容" started.
􀟈  Test "sidebar footer constructs" started.
􀟈  Test "位置文案格式化为「index of count」（本地化 %@ of %@ 键，两端 formatted()）" started.
􀟈  Test "sidebar navigation row constructs selected" started.
􀟈  Test "A10 承重：.centeredHUD 下 edge 不影响渲染（逐字节相等）" started.
􀟈  Test "SpinningModifier：presentation 原样保留" started.
􀟈  Test "nodeColor：StatusLevel 各档映射到对应 StatusColors emphasis token" started.
􀟈  Test "SpinningPresentation：三个 case 互不相等（Equatable 不是恒真）" started.
􀟈  Test "TopBarIndicator.offset：相位覆盖整条轨道，首尾衔接不跳变" started.
􀟈  Test "sidebar tag row constructs" started.
􀟈  Test "SidebarUtilityRow：presentation 默认 .iconLeading（行为兼容）" started.
􀟈  Test "sidebar document row constructs" started.
􀟈  Test "SidebarUtilityRow：两种 presentation 的 body 均可求值" started.
􀟈  Test "glassBorderOpacity is 0.2" started.
􀟈  Test "A10b 承重：A10 的非退化前置 —— 换 edge 在本平台确实能产生位图差异" started.
􀟈  Test "glassInset is 2pt" started.
􀟈  Test "current 为 nil 时回落到首个元素" started.
􀟈  Test "SpinningModifier：.topBar 下 text 仍被原样保留（不生效 ≠ 被改写）" started.
􀟈  Test "残余组 1：autoclosure 组合糖——返回位递归覆盖 Bool? / Optional<Bool> / (Bool)?" started.
􀟈  Test "A11b 承重：.centeredHUD 真的 content-hugging（ink 不随容器宽变化）" started.
􀟈  Test "A6 承重：.centeredHUD 不因挂载增高，另两个形态会" started.
􀟈  Test "SidebarUtilityRowPresentation：两个 case 可区分（Equatable 非退化）" started.
􀟈  Test "SidebarUtilityRow：.textOnly 下 systemImage 仍原样保留（不生效 ≠ 被改写）" started.
􀟈  Test "tab bar constructs with three items" started.
􀟈  Test "sidebar utility row constructs with trailing image" started.
􀟈  Test "pressedScale is 0.94" started.
􀟈  Test "A5 承重：fullWidthBanner 与 floatingCapsule 渲染不同" started.
􀟈  Test "tab bar constructs with two items" started.
􀟈  Test "A11 承重：三形态的实际占宽符合各自定义" started.
􀟈  Test "onComplete：未填满不触发" started.
􀟈  Test "isComplete：字符数等于 length 时为真" started.
􀟈  Test "sanitizedValue：空字符串保持为空" started.
􀟈  Test "character(at:in:)：负数下标返回 nil，不崩溃" started.
􀟈  Test "CBool 折入 plainBool——stdlib typealias CBool = Bool 是同一类型的另一拼法" started.
􀟈  Test "SpinningModifier：三种形态 × isActive 都能构造" started.
􀟈  Test "onComplete：删一位再补回最后一位应再次触发（转变沿复位）" started.
􀟈  Test "character(at:in:)：下标在范围内返回对应字符" started.
􀟈  Test "残余组 4：标点周围空白——Swift . Bool / Optional <Bool> / 泛型实参位复现" started.
􀟈  Test "sanitizedValue：粘贴场景——非数字与超长同时出现" started.
􀟈  Test "displayText：isSecure 为 true 时以圆点替代实际字符" started.
􀟈  Test "accessibilityValueText：非掩码且已填时把数字附在位置后" started.
􀟈  Test "承重：别名表里每个 modifier 入口都把签名参数**逐名转发**下去" started.
􀟈  Test "onComplete：满态自动填充替换成新的完整码时触发（.oneTimeCode 场景）" started.
􀟈  Test "正例：public extension View 上返回 some View 的方法，参数被采进接线" started.
􀟈  Test "length 非正数 clamp 到 1，不产生 0 或负数格数" started.
􀟈  Test "残余组 3：attribute 后无空格——@autoclosure() -> Bool" started.
􀟈  Test "处理流水线：粘贴超长噪声输入后仍能正确判定填满" started.
􀟈  Test "all values are positive and non-zero" started.
􀟈  Test "负例（收窄 1）：不在 extension View 上 ⇒ 不采" started.
􀟈  Test "负例（收窄 3）：返回类型不是 some View ⇒ 不采" started.
􀟈  Test "onComplete：为 nil 时填满也不崩溃" started.
􀟈  Test "残余组 2：specifier 后无空格——consuming(Bool) / borrowing(Bool)" started.
􀟈  Test "负例（收窄 2）：非公开方法 ⇒ 不采" started.
􀟈  Test "onComplete：正常补满最后一位触发一次，参数为最终值（主路径回归守卫）" started.
􀟈  Test "character(at:in:)：下标超出当前长度返回 nil（空格）" started.
􀟈  Test "displayText：字符为 nil（空格）时始终返回空字符串，不论 isSecure" started.
􀟈  Test "onComplete：满态多敲一位——两轮 onChange 均不重复触发" started.
􀟈  Test "sanitizedValue：超出 length 的多余数字被截断" started.
􀟈  Test "onComplete：onAppear 已满初值不触发（firesOnComplete:false，防 NavigationStack 重放循环）" started.
􀟈  Test "处理流水线：未填满时不触发 onComplete 语义" started.
􀟈  Test "focusedIndex：未填满时指向下一个空格" started.
􀟈  Test "现状钉：全部呈现组合的高度互等且为 50（≠ a11y 契约，改 token 时须回来改这个数）" started.
􀟈  Test "既有 init 通路不受影响：宿主仍记类型名" started.
􀟈  Test "sanitizedValue：过滤非数字字符（字母 / 符号 / 空格）" started.
􀟈  Test "displayText：isSecure 为 false 时明文展示字符本身" started.
􀟈  Test "承重：.textOnly 不渲染 leading 槽、也不占位" started.
􀟈  Test "focusedIndex：填满时 clamp 在最后一格，不越界" started.
􀟈  Test "accessibilityValueText：掩码态 / 空格只播位置，不泄露不臆造" started.
􀟈  Test "兜底：SidebarUtilityRow 与 SidebarNavigationRow 同 title 时宽度逐点相等" started.
􀟈  Test "处理流水线：填满 length 格时 isComplete 为真，可驱动 onComplete 触发" started.
􀟈  Test "全部呈现组合的命中高度均 ≥ 44pt" started.
􀟈  Test "承重：.textOnly 完全忽略 systemImage —— 故写 "" 的约定不承重" started.
􀟈  Test "isSecure 默认关闭（明文展示）" started.
􀟈  Test "承重：leading 字形真的由 systemImage 决定（组件不得忽略该入参）" started.
􀟈  Test "positionText：按 Phase 0 位置键组装，两端为 formatted() 结果" started.
􀟈  Test "isComplete：字符数不足 length 时为假" started.
􀟈  Test "shouldFireComplete：新值满 且『规整旧值 ≠ 新值』才为真（含写回第二轮 / 满态替换）" started.
􀟈  Test "候选 2 的组合：行尾字形真的占了位，且不影响 leading 侧差值" started.
􀟈  Test "designated init stores variant + outlined + label without erasure" started.
􀟈  Test "convenience text init forwards variant + outlined" started.
􀟈  Test "value 通过 Binding 双向绑定，构造时原样保留" started.
􀟈  Test "百分比值走 catalog，且渲染结果不含字面量 %%" started.
􀟈  Test "processInput：粘贴超长噪声输入被截断且清洗后写回 Binding" started.
􀟈  Test "BadgeVariant covers the 5 status indicator levels" started.
􀟈  Test "四个新 key 确实注册进 catalog——而不是靠 key 回退看起来对" started.
􀟈  Test "length 通过 init 原样保留（合法正数）" started.
􀟈  Test "边界值：0% 与 100%" started.
􀟈  Test "public typealias 洗 Bool 会被清点——参数侧确实看不见，所以声明侧必须看得见" started.
􀟈  Test "Binding<Bool> / FocusState<Bool>.Binding 归 .boolCarrying，不进 hits" started.
􀟈  Test "convenience text init defaults variant to neutral and outlined to false" started.
􀟈  Test "源码新增未豁免 Bool ⇒ violations 非空、stale 仍空" started.
􀟈  Test "public extension 的两种写法都算 public" started.
􀟈  Test "同时有 Bool 参数与 Bool 返回值 ⇒ 只命中参数，且命中数等于参数数" started.
􀟈  Test "subscript 上的 Bool 参数同样命中——不给它留逃逸口" started.
􀟈  Test "清单与命中完全一致 ⇒ 两个方向都空" started.
􀟈  Test "`-> Bool` 但无 Bool 参数 ⇒ 零命中" started.
􀟈  Test "`#if` 两个分支都扫；`#Preview` 里的声明不扫（顶层 expr 位 + 成员 decl 位）" started.
􀟈  Test "public Bool 属性只进 publicBoolProperties，不进 hits" started.
􀟈  Test "placeholder 为空时，清除按钮的可访问名内外层都走 catalog" started.
􀟈  Test "清单有源码里已不存在的条目 ⇒ stale 非空、violations 仍空" started.
􀟈  Test "嵌套类型的 owner 是点分全名；无标签参数取内部名" started.
􀟈  Test "两个方向可以同时非空——违规与过期条目互不掩盖" started.
􀟈  Test "placeholder 非空时用调用方传入值，库不翻译它" started.
􀟈  Test "裁决 (g)：public extension 里的嵌套具名类型默认就是 public——不建模会整支漏采" started.
􀟈  Test "public protocol 的 requirement 上的 Bool 参数是命中；非 public protocol 不是" started.
􀟈  Test "分类器逐类型断言：显式处理，不靠「恰好没匹配上」" started.
􀟈  Test "非 public 宿主与非 public extension 的 Bool 参数一律不算" started.
􀟈  Test "public enum case 的 Bool 关联值是命中（含无标签的位置兜底）" started.
􀟈  Test case passing 1 argument size → .xSmall to "非可访问性档位：effectiveColumns 原样返回调用方偏好" started.
􀟈  Test case passing 1 argument size → .medium to "非可访问性档位：effectiveColumns 原样返回调用方偏好" started.
􀟈  Test case passing 1 argument size → .small to "非可访问性档位：effectiveColumns 原样返回调用方偏好" started.
􀟈  Test case passing 1 argument size → .xLarge to "非可访问性档位：effectiveColumns 原样返回调用方偏好" started.
􀟈  Test case passing 1 argument size → .large to "非可访问性档位：effectiveColumns 原样返回调用方偏好" started.
􀟈  Test case passing 1 argument size → .xxLarge to "非可访问性档位：effectiveColumns 原样返回调用方偏好" started.
􀟈  Test case passing 1 argument size → .xxxLarge to "非可访问性档位：effectiveColumns 原样返回调用方偏好" started.
􀟈  Test case passing 1 argument rowCount → 1 to ".one 列：每行单独成组，组数恒等于行数" started.
􀟈  Test case passing 1 argument rowCount → 3 to ".one 列：每行单独成组，组数恒等于行数" started.
􀟈  Test case passing 1 argument rowCount → 4 to ".one 列：每行单独成组，组数恒等于行数" started.
􀟈  Test case passing 1 argument rowCount → 2 to ".one 列：每行单独成组，组数恒等于行数" started.
􀟈  Test case passing 1 argument rowCount → 5 to ".one 列：每行单独成组，组数恒等于行数" started.
􀟈  Test case passing 1 argument size → .accessibility1 to "可访问性档位：effectiveColumns 无论调用方传入什么都强制单列" started.
􀟈  Test case passing 1 argument size → .accessibility4 to "可访问性档位：effectiveColumns 无论调用方传入什么都强制单列" started.
􀟈  Test case passing 1 argument size → .accessibility5 to "可访问性档位：effectiveColumns 无论调用方传入什么都强制单列" started.
􀟈  Test case passing 1 argument size → .accessibility3 to "可访问性档位：effectiveColumns 无论调用方传入什么都强制单列" started.
􀟈  Test case passing 1 argument size → .accessibility2 to "可访问性档位：effectiveColumns 无论调用方传入什么都强制单列" started.
􀟈  Test case passing 3 arguments option → 3, selection → 1, expected → false to "isSelected across multiple option/selection pairs" started.
􀟈  Test case passing 3 arguments option → 1, selection → 1, expected → true to "isSelected across multiple option/selection pairs" started.
􀟈  Test case passing 3 arguments option → 2, selection → 2, expected → true to "isSelected across multiple option/selection pairs" started.
􀟈  Test case passing 3 arguments option → 1, selection → 2, expected → false to "isSelected across multiple option/selection pairs" started.
􀟈  Test case passing 1 argument pair → (CoreDesign.StatusLevel.info, "Info") to "accessibilityLabelKey：StatusLevel 各档映射到 Phase 0 预登记键" started.
􀟈  Test case passing 1 argument pair → (CoreDesign.StatusLevel.success, "Success") to "accessibilityLabelKey：StatusLevel 各档映射到 Phase 0 预登记键" started.
􀟈  Test case passing 1 argument pair → (CoreDesign.StatusLevel.info, "status-accent-emphasis") to "nodeColor：StatusLevel 各档映射到对应 StatusColors emphasis token" started.
􀟈  Test case passing 1 argument pair → (CoreDesign.StatusLevel.success, "status-success-emphasis") to "nodeColor：StatusLevel 各档映射到对应 StatusColors emphasis token" started.
􀟈  Test case passing 1 argument pair → (CoreDesign.StatusLevel.warning, "status-attention-emphasis") to "nodeColor：StatusLevel 各档映射到对应 StatusColors emphasis token" started.
􀟈  Test case passing 1 argument pair → (CoreDesign.StatusLevel.danger, "status-danger-emphasis") to "nodeColor：StatusLevel 各档映射到对应 StatusColors emphasis token" started.
􀟈  Test case passing 1 argument pair → (CoreDesign.StatusLevel.warning, "Warning") to "accessibilityLabelKey：StatusLevel 各档映射到 Phase 0 预登记键" started.
􀟈  Test case passing 1 argument variant → .success to "BadgeVariant covers the 5 status indicator levels" started.
􀟈  Test case passing 1 argument variant → .danger to "BadgeVariant covers the 5 status indicator levels" started.
􀟈  Test case passing 1 argument variant → .neutral to "BadgeVariant covers the 5 status indicator levels" started.
􀟈  Test case passing 1 argument variant → .warning to "BadgeVariant covers the 5 status indicator levels" started.
􀟈  Test case passing 1 argument variant → .info to "BadgeVariant covers the 5 status indicator levels" started.
􁁛  Test "运行期字符串经 StringProtocol 重载可构造（编译级守卫）" passed after 0.016 seconds.
􁁛  Test "bottom input bar constructs with defaults" passed after 0.016 seconds.
􁁛  Test "bottom input bar constructs with placeholder and run state" passed after 0.016 seconds.
􁁛  Suite "BottomInputBar" passed after 0.019 seconds.
􁁛  Test "banner constructs with info level" passed after 0.015 seconds.
􁁛  Test "banner constructs with danger level" passed after 0.015 seconds.
􁁛  Test "_runThrowing:CancellationError 静默 — 不调 onError、不弹 toast" passed after 0.015 seconds.
􁁛  Suite "Banner" passed after 0.021 seconds.
􁁛  Test "_runThrowing:onError nil + toastHost 存在 → 自动弹 .danger toast" passed after 0.020 seconds.
􁁛  Test "_runThrowing:onError nil + toastHost nil → 静默,不崩" passed after 0.020 seconds.
􁁛  Test "_runThrowing:业务错误透传给 onError(不弹 toast)" passed after 0.020 seconds.
􁁛  Test "list row constructs with label only" passed after 0.020 seconds.
􁁛  Test "list row constructs with leading and trailing" passed after 0.021 seconds.
􁁛  Suite "ListRow" passed after 0.026 seconds.
􁁛  Test "Skeleton 取色 token 可引用且编译可用" passed after 0.112 seconds.
􁁛  Test "RadioGroup constructs with horizontal axis" passed after 0.111 seconds.
􁁛  Test "RadioGroup constructs with vertical axis (default)" passed after 0.111 seconds.
􁁛  Test "segmented control constructs with three items" passed after 0.111 seconds.
􁁛  Test "空队列 show(...) 立即开始显示" passed after 0.111 seconds.
􁁛  Test "segmented control constructs with two items" passed after 0.111 seconds.
􀟈  Test "显示中 show(...) append 到队尾，不打断当前" started.
􁁛  Test "plain style opts out of glass via the style modifier" passed after 0.111 seconds.
􁁛  Test "tag input constructs with default parameters" passed after 0.111 seconds.
􁁛  Test "both built-in styles produce a body from a configuration" passed after 0.111 seconds.
􁁛  Test "tag input constructs with all parameters" passed after 0.111 seconds.
􁁛  Suite "SegmentedControl" passed after 0.118 seconds.
􁁛  Test "search field constructs with submit handler" passed after 0.110 seconds.
􁁛  Test "search field constructs with default placeholder" passed after 0.110 seconds.
􁁛  Suite "SearchField" passed after 0.118 seconds.
􁁛  Test "tag constructs with text and color" passed after 0.109 seconds.
􁁛  Test "removable tag constructs without crash" passed after 0.109 seconds.
􁁛  Suite "Tag" passed after 0.117 seconds.
􁁛  Test "Timeline：.grouped 删掉节点列后，默认节点项的状态语义经 accessibilityValue 补回" passed after 0.109 seconds.
􁁛  Test "tab bar constructs with three items" passed after 0.108 seconds.
􁁛  Test "SidebarUtilityRow：两种 presentation 的 body 均可求值" passed after 0.111 seconds.
􁁛  Test "tab bar constructs with two items" passed after 0.114 seconds.
􁁛  Suite "UnderlinedTabBar" passed after 0.124 seconds.
FR-4 by-type 核对：2 条 by-type 均无裸串孪生重载；28 条 B/C 均有裸串入口
􀢂  Test "FR-4：public init 的裸文本参数必须在登记表 textParams 里有分类条目" recorded a known issue at ComponentTextParamGuard.swift:278:13: Expectation failed: (result.violations → ["SidebarDocumentRow.init#systemImage", "SidebarNavigationRow.init#systemImage", "SidebarUtilityRow.init#systemImage", "SidebarUtilityRow.init#trailingSystemImage"]).isEmpty → false
􀄵  这些裸文本参数没有分类条目：
   SidebarDocumentRow.init#systemImage（Sidebar.swift:327）：裸文本参数，登记表条目 SidebarDocumentRow 的 textParams 里没有 ["systemImage", "SidebarDocumentRow.systemImage"] 中任何一个，notes 也没点名它
   SidebarNavigationRow.init#systemImage（Sidebar.swift:206）：裸文本参数，登记表条目 SidebarNavigationRow 的 textParams 里没有 ["systemImage", "SidebarNavigationRow.systemImage"] 中任何一个，notes 也没点名它
   SidebarUtilityRow.init#systemImage（Sidebar.swift:266）：裸文本参数，登记表条目 SidebarUtilityRow 的 textParams 里没有 ["systemImage", "SidebarUtilityRow.systemImage"] 中任何一个，notes 也没点名它
   SidebarUtilityRow.init#trailingSystemImage（Sidebar.swift:266）：裸文本参数，登记表条目 SidebarUtilityRow 的 textParams 里没有 ["trailingSystemImage", "SidebarUtilityRow.trailingSystemImage"] 中任何一个，notes 也没点名它
􀄵  FR-4 已知缺口：四条 Sidebar row 的 systemImage / trailingSystemImage 是 SF Symbol 标识符，与 LabelIcon.systemName 同类，但 #38 只在 LabelIcon 的 notes 里写了裁决、Sidebar 侧没写。处置：补 notes（见 40 的缺陷报告），不是改判据、不是塞进 textParams。⚠️ 承接 **wxlpp/oh-my-story#51** —— 原写作「回 #38 补」，但 **#38 已 CLOSED**，指向已关闭的 issue 等于移交蒸发（#51 正是为此新开的，其标题即「原『#38 本位』，但 #38 已关闭」）。
FR-4 covered 映射（登记条目 ← 扫描键）：
  AsyncButton.title  ←  AsyncButton.init#title
  Avatar.name  ←  Avatar.init#name
  Badge.text  ←  Badge.init#text
  InsetGroupedSection.footer  ←  InsetGroupedSection.init#footer
  InsetGroupedSection.header  ←  InsetGroupedSection.init#header
  ProgressIndicator.text  ←  ProgressIndicator.init#text
  RadioGroup.RadioOption.title  ←  RadioOption.init#title
  SearchField.placeholder  ←  SearchField.init#placeholder
  SectionFooter.text  ←  SectionFooter.init#text
  SectionHeader.title  ←  SectionHeader.init#title
  SegmentedControl.title  ←  SegmentedControl.init#title , SegmentedControlStyleConfiguration.Segment.init#title
  SettingsRow.subtitle  ←  SettingsRow.init#subtitle
  SettingsRow.title  ←  SettingsRow.init#title
  SidebarDocumentRow.detail  ←  SidebarDocumentRow.init#detail
  SidebarDocumentRow.title  ←  SidebarDocumentRow.init#title
  SidebarNavigationRow.title  ←  SidebarNavigationRow.init#title
  SidebarSection.title  ←  SidebarSection.init#title
  SidebarStatusFooter.detail  ←  SidebarStatusFooter.init#detail
  SidebarStatusFooter.title  ←  SidebarStatusFooter.init#title
  SidebarTagRow.title  ←  SidebarTagRow.init#title
  SidebarUtilityRow.title  ←  SidebarUtilityRow.init#title
  StateLabel.label  ←  StateLabel.init#label
  Steps.StepItem.description  ←  StepItem.init#description
  Steps.StepItem.title  ←  StepItem.init#title
  Tag.text  ←  Tag.init#text
  TagInput.placeholder  ←  TagInput.init#placeholder
  Toast.message  ←  ToastItem.init#message
  UnderlinedTabBar.title  ←  UnderlinedTabBar.init#title
FR-4 记账：登记条目 30 条 = 产生 covered 键的 28 条 + 零 covered 键的 2 条
FR-4 零 covered 键的登记条目：["Descriptions.header", "SpinningModifier.text"]
FR-4 双命中登记条目 1 条：["SegmentedControl.title": ["SegmentedControl.init#title", "SegmentedControlStyleConfiguration.Segment.init#title"]]
FR-4 覆盖 29 条；LSK/LSR 由类型判定 11 条；carrying 8 条
FR-4 已知违规 ["SidebarDocumentRow.init#systemImage", "SidebarNavigationRow.init#systemImage", "SidebarUtilityRow.init#systemImage", "SidebarUtilityRow.init#trailingSystemImage"]（回 #38 补 notes）
FR-4 notes 授权豁免 ["LabelIcon.init#systemName"]；弃用豁免 ["ProgressBar.init#label"]
FR-4 定义域外 ["Color.init#text", "SettingsRowIcon.init#systemName"]；func 侧留痕 ["ToastHost.show#message", "View.bottomInputBar#placeholder"]
FR-4 跳过 storyui 25 条 / 6 个 textParams：本仓只核登记表内容（CI 只 checkout 本仓）；源码侧判据见 oh-my-story 的 TextParamGuard（#67）。
􀢂  Test "三档分组背景：canvas 独立，secondary 与 tertiary 已知塌缩" recorded a known issue at SystemBackgroundColorsMacOSTests.swift:65:13: Expectation failed: (Color.secondarySystemGroupedBackground → AppKitPlatformColorProvider(platformColor: Catalog color: System controlBackgroundColor)) != (Color.tertiarySystemGroupedBackground → AppKitPlatformColorProvider(platformColor: Catalog color: System controlBackgroundColor))
􀄵  AppKit 无第三级 grouped 背景，secondary 与 tertiary 同落 controlBackgroundColor
【J-1 命中】27 个豁免键 / 30 处源码位置：
  Badge.init#outlined  ←  Badge.swift:79
  Badge.init#outlined  ←  Badge.swift:121
  ButtonRoleStyleRole.resolvedColor#isEnabled  ←  ButtonRoleStyleRole.swift:75
  ButtonRoleStyleRole.resolvedColor#isPressed  ←  ButtonRoleStyleRole.swift:75
  Carousel.init#autoAdvance  ←  Carousel.swift:59
  FloatingGlassModifier.init#isInteractive  ←  FloatingGlassModifier.swift:14
  PinCode.init#isSecure  ←  PinCode.swift:95
  SegmentedControlStyleConfiguration.Segment.init#isSelected  ←  SegmentedControl.swift:42
  SidebarNavigationRow.init#isSelected  ←  Sidebar.swift:169
  SidebarNavigationRow.init#isSelected  ←  Sidebar.swift:206
  SidebarSection.init#showsChevron  ←  Sidebar.swift:34
  Skeleton.init#isLoading  ←  Skeleton.swift:56
  SpinningModifier.init#isActive  ←  SpinningModifier.swift:75
  StepItem.init#isError  ←  Steps.swift:29
  Tag.init#removable  ←  Tag.swift:85
  Tag.init#removable  ←  Tag.swift:186
  TagInput.init#allowDuplicates  ←  TagInput.swift:68
  TelegramGlassButtonModifier.init#isPressed  ←  TelegramGlassButtonModifier.swift:66
  TelegramGlassButtonModifier.init#pressFeedback  ←  TelegramGlassButtonModifier.swift:66
  View.bottomInputBar#autoFocus  ←  BottomInputBar.swift:459
  View.bottomInputBar#autoShowSuggestions  ←  BottomInputBar.swift:459
  View.bottomInputBar#isRunning  ←  BottomInputBar.swift:459
  View.bottomInputBar#sendEnabled  ←  BottomInputBar.swift:459
  View.bottomInputBar#showMenuButton  ←  BottomInputBar.swift:459
  View.bottomInputBar#showShuffleButton  ←  BottomInputBar.swift:459
  View.bottomInputBar#wandEnabled  ←  BottomInputBar.swift:459
  View.floatingGlass#isInteractive  ←  FloatingGlassModifier.swift:39
  View.focusRing#visible  ←  FocusRingModifier.swift:92
  View.sidebarSelectedBackground#isSelected  ←  Sidebar.swift:486
  View.spinning#isActive  ←  SpinningModifier.swift:266
【裁决 (b) 归类为 .boolCarrying，不判违规】1 处：
  View.bottomInputBar#externalFocus  ←  BottomInputBar.swift:459
【裁决 (d) public Bool 属性，只清点不判据】7 处：
  CoreTypography.Token.isMonospaced
  FloatingGlassModifier.isInteractive
  SegmentedControlStyleConfiguration.Segment.isSelected
  SpinningModifier.isActive
  StepItem.isError
  TelegramGlassButtonModifier.isPressed
  TelegramGlassButtonModifier.pressFeedback
【裁决 (f) 含 Bool 的 public typealias，必须为 0】0 处：
组件 45 个：["AsyncButton", "Avatar", "AvatarGroup", "Badge", "Banner", "Card", "Carousel", "ChevronRightIcon", "DangerIcon", "Descriptions", "FloatingGlassModifier", "InsetGroupedSection", "LabelIcon", "ListRow", "PinCode", "ProgressBar", "ProgressIndicator", "RadioGroup", "Rating", "RatingDisplay", "SearchField", "SectionFooter", "SectionHeader", "SegmentedControl", "Separator", "SettingsRow", "SettingsRowChevron", "SidebarDocumentRow", "SidebarNavigationRow", "SidebarSection", "SidebarStatusFooter", "SidebarTagRow", "SidebarUtilityRow", "Skeleton", "SkeletonCircle", "SkeletonLine", "SkeletonRect", "SpinningModifier", "StateLabel", "Steps", "Tag", "TagInput", "TelegramGlassButtonModifier", "Timeline", "UnderlinedTabBar"]
Style 实现 10 个：["CheckBoxToggleStyle", "CircularGlassButtonStyle", "CoreBorderlessButtonStyle", "CoreDisclosureGroupStyle", "CoreLabelStyle", "CoreLabeledContentStyle", "CoreProgressViewStyle", "ExtendedFloatButtonStyle", "LightButtonStyle", "SolidButtonStyle"]
⚠️ StoryUI 侧 25 条未做源码比对——CI 只 checkout 本仓；「源码新增组件而没登记」在 #43 落地前无机器拦截。
裸文本 39 个：["AsyncButton.init#title", "Avatar.init#name", "Badge.init#text", "Color.init#text", "InsetGroupedSection.init#footer", "InsetGroupedSection.init#header", "LabelIcon.init#systemName", "ProgressBar.init#label", "ProgressIndicator.init#text", "RadioOption.init#title", "SearchField.init#placeholder", "SectionFooter.init#text", "SectionHeader.init#title", "SegmentedControl.init#title", "SegmentedControlStyleConfiguration.Segment.init#title", "SettingsRow.init#subtitle", "SettingsRow.init#title", "SettingsRowIcon.init#systemName", "SidebarDocumentRow.init#detail", "SidebarDocumentRow.init#systemImage", "SidebarDocumentRow.init#title", "SidebarNavigationRow.init#systemImage", "SidebarNavigationRow.init#title", "SidebarSection.init#title", "SidebarStatusFooter.init#detail", "SidebarStatusFooter.init#title", "SidebarTagRow.init#title", "SidebarUtilityRow.init#systemImage", "SidebarUtilityRow.init#title", "SidebarUtilityRow.init#trailingSystemImage", "StateLabel.init#label", "StepItem.init#description", "StepItem.init#title", "Tag.init#text", "TagInput.init#placeholder", "ToastHost.show#message", "ToastItem.init#message", "UnderlinedTabBar.init#title", "View.bottomInputBar#placeholder"]
LSK/LSR 11 个：["AsyncButton.init#titleKey", "Descriptions.init#header", "InsetGroupedSection.init#footer", "InsetGroupedSection.init#header", "ProgressIndicator.init#text", "SectionFooter.init#textKey", "SectionHeader.init#titleKey", "SettingsRow.init#subtitle", "SettingsRow.init#title", "SpinningModifier.init#text", "View.spinning#text"]
carrying 8 个：["PinCode.init#onComplete", "PinCode.init#value", "SearchField.init#onSubmit", "SearchField.init#text", "TagInput.init#onCommit", "TagInput.init#tags", "View.bottomInputBar#onSubmit", "View.bottomInputBar#suggestions"]
自有样式协议：["BannerStyle@Banner.swift:77 styleSuffix=true", "RatingStyle@Rating.swift:253 styleSuffix=true", "SegmentedControlStyle@SegmentedControl.swift:66 styleSuffix=true"]
conformance 记录 172 条；ProgressViewStyle 实现：["CoreProgressViewStyle"]
BannerStyle 实现：["BorderedBannerStyle", "PlainBannerStyle"]；SegmentedControlStyle 实现：["GlassSegmentedControlStyle", "PlainSegmentedControlStyle"]
􁁛  Test "显示中 show(...) append 到队尾，不打断当前" passed after 12.408 seconds.
􀟈  Test "dismiss(id:) 排队中的 item 直接移除" started.
J-3 定义域 1 条：["ProgressIndicator": ["ProgressIndicator.swift"]]
J-3 正对照：Banner → ["BannerStyle(作用域内声明@Banner.swift)"]；SegmentedControl → ["SegmentedControlStyle(作用域内声明@SegmentedControl.swift)"]
⚠️ J-3 跳过 storyui 25 条：CI 只 checkout 本仓，跨仓核对移交 #43。
J-2 定义域 11 条：["AvatarGroup", "Banner", "ProgressIndicator", "Rating", "RatingDisplay", "SegmentedControl", "SidebarUtilityRow", "SpinningModifier", "Steps", "Timeline", "Toast"]
J-2 ✓ AvatarGroup：配置枚举 AvatarGroupLayout（形态 D2，接线于 AvatarGroup）
J-2 ✓ Banner：自有协议 BannerStyle（已声明；实现：BorderedBannerStyle, PlainBannerStyle）
J-2 ✓ ProgressIndicator：原生协议 ProgressViewStyle（实现：CoreProgressViewStyle）
J-2 ✓ Rating：自有协议 RatingStyle（已声明；实现：PreviewNumericRatingStyle, StarRatingStyle）
J-2 ✓ RatingDisplay：自有协议 RatingStyle（已声明；实现：PreviewNumericRatingStyle, StarRatingStyle）
J-2 ✓ SegmentedControl：自有协议 SegmentedControlStyle（已声明；实现：GlassSegmentedControlStyle, PlainSegmentedControlStyle）
J-2 ✓ SidebarUtilityRow：配置枚举 SidebarUtilityRowPresentation（形态 D2，接线于 SidebarUtilityRow）
J-2 ✓ SpinningModifier：配置枚举 SpinningPresentation（形态 D2，接线于 SpinningModifier, spinning）
J-2 ✓ Steps：配置枚举 StepsPresentation（形态 D2，接线于 Steps）
J-2 ✓ Timeline：配置枚举 TimelineLayout（形态 D2，接线于 Timeline）
J-2 ✓ Toast：配置枚举 ToastPresentation（形态 D2，接线于 toastHost）
J-2 已知缺口 []（**空集** —— 扩展点缺口已全部收口，`#65` 是最后一条）
⚠️ J-2 跳过 storyui 25 条：CI 只 checkout 本仓，跨仓核对移交 #43。
􁁛  Test "overflow accessibility label includes avatar context" passed after 25.463 seconds.
􁁛  Test "默认初始化落在 .large 档" passed after 25.463 seconds.
􁁛  Test "init with max parameter stores value" passed after 25.464 seconds.
􁁛  Test "静态成员 .extendedFloat 默认落在 .large 档" passed after 25.464 seconds.
􁁛  Test "静态工厂 .extendedFloat(size:) 透传档位" passed after 25.464 seconds.
􁁛  Test "default max is 3" passed after 25.476 seconds.
􁁛  Test "AvatarGroup：四种排布都能构造且 body 可求值（不 crash）" passed after 25.476 seconds.
􁁛  Test "AvatarGroup：.countOnly 下 max 仍被原样保留（不生效 ≠ 被改写）" passed after 25.476 seconds.
􁁛  Test "AvatarGroupAccessibility：totalLabel 与 overflowLabel 语义不同、文案不同" passed after 25.479 seconds.
􁁛  Test "AvatarGroupAccessibility：totalLabel 走 %lld avatars 复数键，不自造字面键" passed after 25.480 seconds.
􁁛  Test "AvatarGroup：layout 原样保留" passed after 25.480 seconds.
􁁛  Test "承重：填了 customStyleProtocol 的组件，body 里真的调用了 style.makeBody(configuration:)" passed after 25.480 seconds.
􁁛  Suite "自有样式协议的消费判据" passed after 25.483 seconds.
􁁛  Test "fillFraction：value 为 0 时全部星为空" passed after 25.512 seconds.
􁁛  Test "step: .infinity clamp 回 1.0——挡住 steppedValue 产出 NaN（#41 收尾修复）" passed after 25.513 seconds.
􁁛  Test "AvatarGroup：layout 默认 .overlapped —— 现有调用方零影响" passed after 25.593 seconds.
􁁛  Test "steppedValue：step=0.5 按 ceiling——星 k 左半 → k−0.5、右半 → k" passed after 25.626 seconds.
􁁛  Test "steppedValue：step=1.0 按 ceiling——点第 k 颗星得 k 分" passed after 25.626 seconds.
􁁛  Test "显式档位被保留" passed after 25.627 seconds.
􁁛  Test "AvatarGroupLayout：四个 case 互不相等（Equatable 不是恒真）" passed after 25.626 seconds.
􁁛  Suite "ExtendedFloatButtonStyle 档位默认值与静态工厂" passed after 25.629 seconds.
􁁛  Suite "AvatarGroup" passed after 25.629 seconds.
􁁛  Test "② 表里每个 value 都是源码里存在的公开 modifier 方法名" passed after 25.627 seconds.
􁁛  Test "fillFraction：整星为 1，未达到的星为 0" passed after 25.632 seconds.
􁁛  Test "措辞表与撤回标记表不得静默增删" passed after 25.632 seconds.
􁁛  Test "仅 captionMono 是等宽" passed after 25.632 seconds.
􁁛  Test "FR-4 附条：owner 翻译表每一条都必须真的被用到（不许有过期条目）" passed after 25.633 seconds.
􁁛  Test "FR-4 附条：by-type 分类必须真的没有孪生裸串重载（公约 §4 的实际筛子）" passed after 25.633 seconds.
􁁛  Test "散文 ⟂ 数据判据必须抓得住 #67 真实发生过的三条矛盾" passed after 25.633 seconds.
􁁛  Test "12 档一一对应系统文本样式" passed after 25.633 seconds.
􁁛  Test "step 非正值 clamp 回 1.0——挡住「静默恒 0」，不是挡除零" passed after 25.635 seconds.
􁁛  Test "fillFraction：半星在过渡星上给出 0.5" passed after 25.653 seconds.
􀢂  Test "FR-4：public init 的裸文本参数必须在登记表 textParams 里有分类条目" passed after 25.653 seconds with 1 known issue.
􁁛  Test "steppedValue：totalWidth / count / step 非法输入归零，不崩溃" passed after 25.653 seconds.
􀢂  Suite "FR-4 文本参数分类覆盖" passed after 25.656 seconds with 1 known issue.
􁁛  Test "J-2 形态 D2 变异：enum 声明了但没接进任何公开 init ⇒ 必须判红" passed after 25.654 seconds.
􁁛  Test "steppedValue：relativeX 为负数 clamp 到 0 分" passed after 25.654 seconds.
􁁛  Test "J-3 探针：采纳 Apple 原生协议不算命中（自有协议集合里没有它）" passed after 25.654 seconds.
􁁛  Test "count 默认 5，step 默认 1.0（整星）" passed after 25.654 seconds.
􁁛  Test "value 通过 Binding 双向绑定，构造时原样保留（不额外 clamp）" passed after 25.655 seconds.
􁁛  Test "totalHeight for a single line has no spacing contribution" passed after 25.655 seconds.
􁁛  Test "accessibilityValueText：按 Phase 0 位置键 "%@ of %@" 组装，两端为 formatted() 结果" passed after 25.655 seconds.
􁁛  Test "J-3 变异：给 nativeProtocol 组件的作用域塞进自有样式协议 ⇒ 判红（违规集合精确）" passed after 25.655 seconds.
􁁛  Test "isLastLine is true only for the final row of a multi-line block" passed after 25.655 seconds.
􁁛  Test "step 不设上界——count == 0 是合法入参，任何 step ≤ count 的上界都会恒不可满足" passed after 25.655 seconds.
􁁛  Test "J-2 变异：协议已声明但零实现 ⇒ 判红（AC 原文『定义 + 使用』）" passed after 25.655 seconds.
􁁛  Test "count / step 原样保留" passed after 25.655 seconds.
􁁛  Test "J-3 探针：作用域文件里声明的自有样式协议算命中（通道 i）" passed after 25.655 seconds.
􁁛  Test "④ 每个 value 必须真的携带该条目登记的 styleEnum 作为参数" passed after 25.655 seconds.
􁁛  Test "steppedValue：relativeX 超出总宽 clamp 到最大星数" passed after 25.655 seconds.
􁁛  Test "J-3：作用域解析不出来必须报告，不能算绿（零输出不是绿）" passed after 25.655 seconds.
􁁛  Test "J-3 结构约束：主判据的违规集合就是探针的命中集合（判据不得内联重写探针）" passed after 25.655 seconds.
􁁛  Test "恰好 12 档，无隐藏 case" passed after 25.655 seconds.
􁁛  Test "J-2 形态 D1 变异：私有 body 里的 @ViewBuilder 不算扩展点（调用方够不着）" passed after 25.655 seconds.
􁁛  Test "accessibilityValueText：半星精确播报，不取整（与整星取整后的文案不同）" passed after 25.655 seconds.
􁁛  Suite "CoreTypography.Token" passed after 25.658 seconds.
􁁛  Test "textAligned = 横向 padding（无图标列）" passed after 25.655 seconds.
􁁛  Test "width(forLineAt:containerWidth:) narrows only the last line of a multi-line block" passed after 25.655 seconds.
􁁛  Test "J1：schema 合法 —— type 唯一、repo 与 category 在允许域、notes 非占位" passed after 25.655 seconds.
􁁛  Test "J8：全部条目的 category 都是 C（并集规则的机器触发点）" passed after 25.655 seconds.
􁁛  Test "default diameter is 40" passed after 25.655 seconds.
􁁛  Test "③ 表里每个 key 都确实不等于任何单个公开类型名" passed after 25.655 seconds.
􁁛  Test "FR-4：owner 别名 + 限定参数名两条解析路径" passed after 25.655 seconds.
􁁛  Test "Rating(count:) 拒绝负数星数，落到 0" passed after 25.656 seconds.
􁁛  Test "J3：同一 type 内的参数名唯一" passed after 25.655 seconds.
􁁛  Test "J-3 探针：组件（或其 extension）采纳自有样式协议算命中（通道 ii）" passed after 25.655 seconds.
􁁛  Test "J2：本表的 type 与组件登记表的 component 不相交" passed after 25.655 seconds.
􁁛  Test "totalHeight sums line heights plus inter-line spacing" passed after 25.655 seconds.
􁁛  Test "⑤ 每个 styleEnum 只能被一个条目认领（别名表打破了原来的隐式约束）" passed after 25.655 seconds.
􁁛  Test "J-2：四个扩展点字段全为 null ⇒ 判红（Rating / Toast 的形态）" passed after 25.655 seconds.
􁁛  Test "J-2：nativeProtocol 走 conformance 通路，不要求本仓声明该协议" passed after 25.655 seconds.
􁁛  Test "J-2：自有协议已声明且有实现 ⇒ 满足" passed after 25.655 seconds.
􁁛  Suite "Rating" passed after 25.659 seconds.
􁁛  Test "lastLineWidthFraction below 0 clamps to 0" passed after 25.655 seconds.
􁁛  Test "FR-4：同一个键被多个 init 重载命中时，各桶按键去重（计数单位是键不是命中）" passed after 25.655 seconds.
􁁛  Test "custom metrics are stored" passed after 25.655 seconds.
􁁛  Test "FR-4：宿主不对应登记表条目 ⇒ 进 unmappedOwners，不判红也不静默" passed after 25.656 seconds.
􁁛  Test "① 表里每个 key 都在登记表里存在" passed after 25.655 seconds.
􁁛  Suite "#72 G-8 续 —— 可达类型登记表" passed after 25.659 seconds.
􁁛  Test "J-3：只在 nativeProtocol != nil 时触发（SegmentedControl 不得被自己的协议判红）" passed after 25.655 seconds.
􁁛  Test "iconAligned = 横向 padding + 图标方块宽 + 间距（非硬编码）" passed after 25.655 seconds.
􁁛  Test "isLastLine is always false for a single line" passed after 25.655 seconds.
􁁛  Test "J-2 变异：协议声明被移走 ⇒ 判红（且违规集合精确）" passed after 25.656 seconds.
􁁛  Test "J-2 定义域：非 semantic / 不要扩展点 / 非本仓的条目都不进 inspected" passed after 25.655 seconds.
􁁛  Test "J-2 形态 D2 变异：enum 接在别的组件上 ⇒ 本条目必须判红（不许跨组件借线）" passed after 25.656 seconds.
􁁛  Test "width(forLineAt:containerWidth:) never narrows a single line" passed after 25.655 seconds.
􁁛  Test "J-3 变异：conformance 通道同样判红" passed after 25.655 seconds.
􁁛  Test "SettingsDividerInset.value 三档映射（顶层类型，非泛型嵌套）" passed after 25.656 seconds.
􁁛  Test "J-2 形态 D1 变异：styleSlot 源码里不存在 ⇒ 判红（不是填了就算）" passed after 25.656 seconds.
􁁛  Test "explicit width is preserved" passed after 25.655 seconds.
􁁛  Test "混合基色未被提前解析——四档在浅色与深色下取值不同" passed after 25.655 seconds.
􁁛  Test "混合只动明度、不显著降 alpha" passed after 25.655 seconds.
􁁛  Test "default init has nil width and CoreRadius.medium corner radius" passed after 25.655 seconds.
􁁛  Test "J-2 形态 D1：styleSlot 在源码里真实存在 ⇒ 满足" passed after 25.655 seconds.
􁁛  Test "J-2 形态 D 变异：两个扩展点字段同时非空 ⇒ 靠后那条通路被静默略过" passed after 25.655 seconds.
􁁛  Test "FR-4：登记表 notes 点名了参数名 ⇒ 豁免；没点名 ⇒ 判红" passed after 25.655 seconds.
􁁛  Test "J-2 形态 D2 的限度：接线判据核不了『枚举承载的是不是形态候选』" passed after 25.655 seconds.
􁁛  Test "FR-4 反向：登记表有条目、源码扫不到 ⇒ 幽灵条目" passed after 25.655 seconds.
􁁛  Test "J-2 形态 D2：styleEnum 真实存在 ⇒ 满足；不存在 ⇒ 判红" passed after 25.655 seconds.
􁁛  Test "lineCount below 1 clamps to 1" passed after 25.656 seconds.
􁁛  Test "explicit diameter is preserved" passed after 25.655 seconds.
􁁛  Test "J-2 形态 D2 变异：internal enum 不算（不是公开 API 面）" passed after 25.655 seconds.
􁁛  Test "default init uses a single line" passed after 25.655 seconds.
􁁛  Suite "别名表自洽：五条断言" passed after 25.660 seconds.
􁁛  Suite "分组分隔线 inset 推导" passed after 25.659 seconds.
􁁛  Test "FR-4：LSK/LSR 由类型判定，不要求登记表条目，但必须被识别" passed after 25.655 seconds.
􁁛  Test "FR-4：裸文本参数在 textParams 里有条目 ⇒ covered" passed after 25.655 seconds.
􁁛  Test "豁免清单的每个键都是扫描器能产出的形状" passed after 25.655 seconds.
􁁛  Test "explicit lineCount is preserved" passed after 25.655 seconds.
􁁛  Suite "SkeletonRect" passed after 25.660 seconds.
􁁛  Test "status token 各指向正确的 colorset asset" passed after 25.655 seconds.
􁁛  Test "FR-4：category 为空串的条目不算覆盖（AC 原文『且分类非空』）" passed after 25.656 seconds.
􁁛  Suite "SkeletonCircle" passed after 25.660 seconds.
􁁛  Test "FR-4 变异：新增未登记的裸文本参数 ⇒ 判红；补登记 ⇒ 转绿" passed after 25.655 seconds.
􁁛  Suite "StatusColors" passed after 25.660 seconds.
􁁛  Test "未豁免违规集合与 pendingViolationKeys（现为空集）恰好相等（这条是**绿**的，专抓新违规）" passed after 25.655 seconds.
􁁛  Test "Phase 0 预登记的 accessibility 字符串键已注册进资源 bundle" passed after 25.655 seconds.
􁁛  Test "pressed 在浅色下变暗、在深色下变亮——即始终远离背景" passed after 25.655 seconds.
􁁛  Test "J-1：public 声明不得含未豁免的 Bool 参数" passed after 25.655 seconds.
􁁛  Test "init 默认非交互" passed after 25.655 seconds.
􀢂  Test "三档分组背景：canvas 独立，secondary 与 tertiary 已知塌缩" passed after 25.655 seconds with 1 known issue.
􁁛  Test "扫描器真的扫到了 public Bool 参数，且覆盖公约点名的每一条" passed after 25.655 seconds.
􁁛  Test "isInteractive 透传到 modifier" passed after 25.655 seconds.
􁁛  Test "豁免宿主要么在登记表里，要么在 AD 台账里且该分类真的成立" passed after 25.655 seconds.
􁁛  Test "AvatarGroup 总数复数键：one/other 形态正确" passed after 25.655 seconds.
􁁛  Test "hover 与 pressed 同向，且 pressed 走得更远" passed after 25.656 seconds.
􁁛  Test "FR-4：kind == excluded 的组件整体豁免（弃用条款「不分类」）" passed after 25.656 seconds.
􁁛  Suite "FloatingGlassModifier" passed after 25.660 seconds.
􁁛  Suite "accent 衍生族方向性" passed after 25.660 seconds.
􁁛  Test "棘轮：豁免清单条目数与基线 maxEntries 严格相等、源码位置数与 sourceSites 严格相等，且基线自身字段齐全" passed after 25.656 seconds.
􁁛  Test "FR-4：func 侧裸文本参数进留痕桶，不进主判据" passed after 25.656 seconds.
􁁛  Test "反向：每个非 excluded 的 coredesign 条目都被 README 索引覆盖" passed after 25.655 seconds.
􁁛  Suite "组件判据规则层" passed after 25.660 seconds.
􁁛  Test "语义层 surfaceCanvas 与 surfaceRaised 不同色" passed after 25.658 seconds.
􁁛  Test ".disclosureGroupStyle(.core) 产出 CoreDisclosureGroupStyle" passed after 25.658 seconds.
􁁛  Test "J-4：豁免基线存在、可解析、每条四字段齐全且理由不是空话" passed after 25.658 seconds.
􁁛  Test "Steps 步数复数键：one/other 形态正确" passed after 25.658 seconds.
􁁛  Test "canvas 与 raised 的底层 token 不同色" passed after 25.658 seconds.
􁁛  Test "登记表每条含全部必需字段，且取值在允许域内" passed after 25.658 seconds.
􁁛  Test "Rating 星数复数键：one/other 形态正确" passed after 25.658 seconds.
􀢂  Suite "macOS 分组背景降级" passed after 25.663 seconds with 1 known issue.
􁁛  Test ".progressViewStyle(.core) 产出 CoreProgressViewStyle" passed after 25.658 seconds.
􁁛  Test "重载解析:非抛错文本 init 编译" passed after 25.658 seconds.
􁁛  Test "非抛错 init 能正常构造" passed after 25.658 seconds.
􁁛  Test "lastLineWidthFraction above 1 clamps to 1" passed after 25.658 seconds.
􁁛  Suite "Bool 豁免基线与棘轮" passed after 25.663 seconds.
􁁛  Test "扫描器真的扫到了 CoreDesign 的类型" passed after 25.658 seconds.
􁁛  Test "重载解析:抛错文本 init 编译" passed after 25.658 seconds.
􁁛  Suite "Shared Foundation — semi-mobile-components Phase 0" passed after 25.663 seconds.
􁁛  Suite "SkeletonLine" passed after 25.663 seconds.
􁁛  Suite "AsyncButton" passed after 25.663 seconds.
􁁛  Test "explicit diameter overrides the tier" passed after 25.659 seconds.
􁁛  Test "init(text: LocalizedStringKey) 存入本地化文案" passed after 25.660 seconds.
􁁛  Test "环境值默认实现是 StarRatingStyle" passed after 25.660 seconds.
􁁛  Test "RatingStyleConfiguration 只携带外观所需状态（value / count），不带行为" passed after 25.660 seconds.
􁁛  Test "solid / light 只按 role 参数化，直接构造与工厂两条路给出同一个 role" passed after 25.660 seconds.
􁁛  Test "init() 无破坏：不带文案（NFR-6）" passed after 25.660 seconds.
􁁛  Test "覆盖事实的单一来源：prefix / alias 表能推出的覆盖，coverage 表必须已经包含" passed after 25.660 seconds.
􁁛  Test "README 组件索引每个候选名都有归宿：登记表 / styleImpls（须真的扫到）/ 墓碑 / 排除 / **聚合映射** / 辅助类型 / 别名与容器前缀（守卫绿态下不可达）" passed after 25.660 seconds.
􁁛  Test "conformance 采集：容忍限定名与泛型形参（SwiftUI.View / Foo<T>）" passed after 25.660 seconds.
􁁛  Test "Rating.body 真的经 style.makeBody 渲染——不是声明协议但绕过它硬编码星形" passed after 25.660 seconds.
􁁛  Test "双向 / 容器形态判 .textCarrying（清点、不进判据）" passed after 25.660 seconds.
􁁛  Test "baseTypeName：已知限度 —— 泛型包装会在 `<` 处截断，接线记录随之丢失" passed after 25.660 seconds.
􁁛  Test "公约文档含全部 5 个必需节" passed after 25.660 seconds.
􁁛  Test "View.ratingStyle(_:) 把 style 写进环境值，换得掉默认实现" passed after 25.660 seconds.
􁁛  Test "circular glass defaults to the large tier, not an explicit diameter" passed after 25.660 seconds.
􁁛  Test ".two 列：切分覆盖每个索引恰好一次，且保持原始顺序" passed after 25.660 seconds.
􁁛  Test "shadow 四档 colorset 存在（CoreElevation 消费）" passed after 25.660 seconds.
􁁛  Test "init(text: StringProtocol) 存入 verbatim 文案" passed after 25.661 seconds.
􁁛  Test "circular glass tier accessor keeps the requested tier" passed after 25.661 seconds.
􁁛  Test "公约的 markdown 表格没有被裸换行劈开的行" passed after 25.661 seconds.
􁁛  Suite "Button style defaults" passed after 25.666 seconds.
􁁛  Test ".labelStyle(.core) 产出 CoreLabelStyle" passed after 25.661 seconds.
􁁛  Suite "系统控件 .core style 静态成员" passed after 25.666 seconds.
􁁛  Test "返回位是文本的函数类型判为文本（登记表把 `(Item) -> String` 记成 textParams）" passed after 25.661 seconds.
􁁛  Test "非 String 的 StringProtocol（Substring）同样可构造，@_disfavoredOverload 不影响非字面量调用" passed after 25.661 seconds.
􁁛  Test "RatingDisplay.body 真的经 style.makeBody 渲染——不是声明协议但绕过它硬编码星形" passed after 25.661 seconds.
􁁛  Suite "ProgressIndicator 文案存储" passed after 25.666 seconds.
􁁛  Test "采集器：Binding / 回调进 carrying，不进 bareText" passed after 25.661 seconds.
􁁛  Suite "RatingStyle 扩展点" passed after 25.666 seconds.
􁁛  Test ".labeledContentStyle(.core) 产出 CoreLabeledContentStyle" passed after 25.661 seconds.
􁁛  Test "非可访问性档位：effectiveColumns 原样返回调用方偏好" with 7 test cases passed after 25.661 seconds.
􁁛  Test "status 语义色 colorset 全部存在（StatusColors 消费）" passed after 25.661 seconds.
􁁛  Test "采集器：init 与 func 分桶（FR-4 主判据只吃 init）" passed after 25.661 seconds.
􁁛  Test "CoreDesign 侧：登记表覆盖全部组件类型，且无幽灵条目" passed after 25.661 seconds.
􁁛  Test "样式协议识别：信号是 makeBody(configuration:) requirement，不是名字里有 Style" passed after 25.661 seconds.
􁁛  Test "采集器：`init<S: StringProtocol>` 的泛型形参判裸文本（含 where 子句写法）" passed after 25.661 seconds.
􁁛  Test "StringProtocol 泛型形参名判 .bareText（`init<S: StringProtocol>(title: S)`）" passed after 25.661 seconds.
􁁛  Test "采集器：非 public 与 private 容器整体不可见" passed after 25.661 seconds.
􁁛  Test "`readmeRowCoverage` 自洽：key 真在 README、value 真是条目、理由不是空话" passed after 25.662 seconds.
􁁛  Test ".two 列 + 偶数行数：全部两两配对，无落单组" passed after 25.661 seconds.
􁁛  Test ".one 列：每行单独成组，组数恒等于行数" with 5 test cases passed after 25.661 seconds.
􁁛  Test "真实源码扫描：文本参数三个桶的实测规模" passed after 25.661 seconds.
􁁛  Test "采集器：public extension 给成员与嵌套具名类型发默认 public（裁决 g）" passed after 25.661 seconds.
􁁛  Test "rowCount 为 0 时不产出任何组（.one / .two 均同）" passed after 25.661 seconds.
􁁛  Test "公约文本提及守卫允许域里的每一个取值（终审 I1(b)：给通则装上牙）" passed after 25.661 seconds.
􁁛  Test ".two 列 + 奇数行数：最后一组只含 1 个索引（占满整行）" passed after 25.661 seconds.
􁁛  Suite "公约文档结构守卫" passed after 25.667 seconds.
􁁛  Test "DescriptionsColumns 两个枚举值互不相等" passed after 25.661 seconds.
􁁛  Test "conformance 采集：类型声明与 extension 两条路径都要认" passed after 25.661 seconds.
􁁛  Test "类型→文件索引：类型声明与 extension 都记进宿主文件" passed after 25.661 seconds.
􁁛  Test "采集器：`#if` 两支都走、`#Preview` 整块跳过" passed after 25.661 seconds.
􁁛  Test "CardKind 到 SurfaceKind 的映射逐一正确" passed after 25.661 seconds.
􁁛  Test "README 索引引用的快照 PNG 必须真的存在" passed after 25.662 seconds.
􁁛  Test "RadioOption.id equals value for Int-backed selection" passed after 25.661 seconds.
􁁛  Test ".two 列 + 单行：唯一一组只含 1 个索引" passed after 25.661 seconds.
􁁛  Test "some/any StringProtocol 判 .bareText —— 与 `<S: StringProtocol>(title: S)` 是同一声明的语法糖、调用点逐字相同（#40 Task 2 评审 Important-1）" passed after 25.661 seconds.
􁁛  Test "可访问性档位：effectiveColumns 无论调用方传入什么都强制单列" with 5 test cases passed after 25.661 seconds.
􁁛  Suite "组件登记表" passed after 25.667 seconds.
􁁛  Test "每个 role 的三态都取自本 role 的调色板" passed after 25.661 seconds.
􁁛  Suite "Descriptions" passed after 25.667 seconds.
􁁛  Test "isSelected works with an enum-backed SelectionValue" passed after 25.661 seconds.
􁁛  Test "采集器：public init 的裸文本参数进 bareTextKeys" passed after 25.661 seconds.
􁁛  Test "样式协议识别：makeBody 的参数标签必须是 configuration" passed after 25.661 seconds.
􁁛  Test "RadioOption.id equals value (Identifiable contract)" passed after 25.661 seconds.
􁁛  Test "17 色相 × 10 色阶 colorset 全部存在" passed after 25.662 seconds.
􁁛  Test "非文本判 .notText" passed after 25.661 seconds.
􁁛  Test "isSelected across multiple option/selection pairs" with 4 test cases passed after 25.662 seconds.
􁁛  Test "tagToCommit returns normalized tag when not a duplicate" passed after 25.661 seconds.
􁁛  Test "isSelected returns false when option does not match current selection" passed after 25.661 seconds.
􁁛  Test "removingTag deletes the correct element among duplicates by offset" passed after 25.661 seconds.
􁁛  Test "disabled 优先于 pressed" passed after 25.661 seconds.
􁁛  Test "splitDraftOnSeparator keeps the trailing partial segment as remainder" passed after 25.661 seconds.
􁁛  Test "tagToCommit returns nil for blank input regardless of dedupe policy" passed after 25.661 seconds.
􁁛  Test "normalizedTag trims surrounding whitespace" passed after 25.661 seconds.
􁁛  Test "裸文本：String 的各种等价拼法都判 .bareText" passed after 25.661 seconds.
􁁛  Test "removingTag with a negative index is a no-op" passed after 25.661 seconds.
􁁛  Test "normalizedTag is case sensitive (no normalization)" passed after 25.661 seconds.
􁁛  Test "enabled 时按 pressed 分流" passed after 25.661 seconds.
􁁛  Test "tagToCommit rejects duplicate when allowDuplicates is false" passed after 25.661 seconds.
􁁛  Suite "Colorset 资源存在性守卫" passed after 25.668 seconds.
􁁛  Test "removingTag with an out-of-range index is a no-op" passed after 25.661 seconds.
􁁛  Test "isSelected returns true when option matches current selection" passed after 25.661 seconds.
􁁛  Suite "Radio" passed after 25.668 seconds.
􁁛  Test "normalizedTag returns nil for empty string" passed after 25.661 seconds.
􁁛  Test "splitDraftOnSeparator returns no segments when draft has no comma" passed after 25.661 seconds.
􁁛  Test "normalizedTag preserves internal whitespace" passed after 25.661 seconds.
􁁛  Test "splitDraftOnSeparator splits multiple comma-separated segments" passed after 25.661 seconds.
􁁛  Test "每个 role 的 color / activeColor / disabledColor 三态互不相同" passed after 25.661 seconds.
􁁛  Test "normalizedTag trims surrounding newlines" passed after 25.661 seconds.
􁁛  Test "端到端 FR-4 反向变异：把已登记参数改名 ⇒ 登记表条目变成幽灵" passed after 25.661 seconds.
􁁛  Test "tagToCommit allows duplicate when allowDuplicates is true" passed after 25.661 seconds.
􁁛  Test "tagToCommit dedupe check is case sensitive" passed after 25.661 seconds.
􁁛  Suite "ButtonRoleStyleRole 三态取色" passed after 25.668 seconds.
􁁛  Test "normalizedTag returns nil for whitespace-only string" passed after 25.661 seconds.
􁁛  Test "可本地化文本：LSK / LSR 及其可选形态判 .localizedText" passed after 25.661 seconds.
􁁛  Test "CardKind 恰好只有 .content / .grouped 两个 case" passed after 25.662 seconds.
􁁛  Test "端到端 J-3 变异（通道 ii）：让 ProgressIndicator 采纳 BannerStyle ⇒ 判红" passed after 25.661 seconds.
􁁛  Test "登记表有源码里找不到的条目 ⇒ ghosts 非空、missing 仍为空" passed after 25.661 seconds.
􁁛  Test "端到端 FR-4 变异：给 Avatar 加一个未登记的裸 String 参数 ⇒ 判红；补登记 ⇒ 转绿" passed after 25.661 seconds.
􁁛  Test "accessibilityLabelText：非空 description 时拼接为 "title: description"" passed after 25.661 seconds.
􁁛  Test "progress：首索引（0）在 currentIndex 为 0 时为 current，为负数时为 pending" passed after 25.661 seconds.
􁁛  Test "端到端 J-2 变异：把 BannerStyle 协议声明改名 ⇒ Banner 判缺扩展点" passed after 25.661 seconds.
􁁛  Test "源码新增组件但登记表没有 ⇒ missing 非空、ghosts 仍为空" passed after 25.661 seconds.
􁁛  Test "default labels come from the style spec" passed after 25.661 seconds.
􁁛  Test "端到端 J-2 变异：删掉 BannerStyle 的全部实现 ⇒ Banner 判缺扩展点（『定义 + 使用』的使用侧）" passed after 25.662 seconds.
􁁛  Test "两个方向可以同时非空——漏登记与幽灵条目互不掩盖" passed after 25.661 seconds.
􁁛  Test "completed maps to done status color" passed after 25.661 seconds.
􁁛  Test "accessibilityLabelText：空字符串 description 视同缺省，不拼接" passed after 25.661 seconds.
􁁛  Test "count 负数 clamp 到 0（与 Rating 同一条仓内惯例）" passed after 25.661 seconds.
􁁛  Test "accessibilityValueText：当前步骤按 Phase 0 位置键 "%@ of %@" 组装（1-based）" passed after 25.661 seconds.
􁁛  Test "Steps：.segmentedBar 的每段对应它自己那一步，不跟着前一步走" passed after 25.661 seconds.
􁁛  Test "active maps to success status color" passed after 25.661 seconds.
􁁛  Suite "CardKind 取值域" passed after 25.669 seconds.
􁁛  Test "accessibilityValue 文案与 Rating 共用同一个位置键，不另起一套" passed after 25.661 seconds.
􁁛  Test "convenience init accepts a custom label and preserves style" passed after 25.662 seconds.
􁁛  Test "dismiss(id:) 排队中的 item 直接移除" passed after 13.142 seconds.
􁁛  Test "端到端 J-3 变异（通道 i）：往 ProgressIndicator.swift 塞一个自有样式协议 ⇒ 判红" passed after 25.661 seconds.
􁁛  Test "progress：index 等于 currentIndex → current" passed after 25.661 seconds.
􁁛  Test "Steps：indicatorStyle 与 presentation 正交 —— 两者独立保留，互不改写" passed after 25.661 seconds.
􁁛  Test "StepItem：title 必填，description / isError 默认值" passed after 25.661 seconds.
􁁛  Suite "组件判据扫描层" passed after 25.669 seconds.
􁁛  Test "positionText：两端为 Int.formatted() 结果" passed after 25.661 seconds.
􁁛  Test "Steps.progressSummary：越界 currentIndex 被夹进 1...total，且不溢出" passed after 25.661 seconds.
􁁛  Test "Steps：axis 默认 .horizontal，indicatorStyle 默认 .dot" passed after 25.661 seconds.
􁁛  Test "accessibilityValueText：当前步骤同时是错误态——位置 + Error 以 ", " 拼接" passed after 25.661 seconds.
􁁛  Test "progress：index 大于 currentIndex → pending" passed after 25.661 seconds.
􁁛  Test "StepItem：显式传入 id 时原样保留，不覆盖为新 UUID" passed after 25.661 seconds.
􁁛  Test "progress：index 小于 currentIndex → done" passed after 25.661 seconds.
􁁛  Test "Steps：presentation 默认 .steps —— 现有调用方零影响" passed after 25.661 seconds.
􁁛  Test "Steps：items / currentIndex / axis / indicatorStyle 原样保留" passed after 25.661 seconds.
􁁛  Test "value / count 原样保留，count 默认 5" passed after 25.661 seconds.
􁁛  Test "端到端：副本未变异时，三条判据的结果与真实源码一致（基线）" passed after 25.662 seconds.
􁁛  Test "Inset Equatable：leading(0) 与 edgeToEdge 是不同的 case" passed after 25.661 seconds.
􁁛  Test "CoreLabelStyle 的 icon 随 .tint 变色，而非恒取 accent" passed after 25.661 seconds.
􁁛  Test "removingTag at the second duplicate leaves the first untouched" passed after 25.661 seconds.
􁁛  Test "Steps：.segmentedBar / .text 塌成单 element 后，错误态仍经 accessibilityValue 播报" passed after 25.661 seconds.
􁁛  Test "每条豁免都必须对应一处真实命中——不许有死豁免" passed after 25.661 seconds.
􁁛  Test "双方完全一致 ⇒ 两个方向都空" passed after 25.662 seconds.
􁁛  Test "all styles construct and expose a spec" passed after 25.662 seconds.
􁁛  Test "推进到集合中间的下一个元素" passed after 25.661 seconds.
􁁛  Test "accessibilityLabelText：无 description 时只用 title" passed after 25.661 seconds.
􁁛  Test "accessibilityValueText：错误态非当前步骤只播报 "Error"" passed after 25.661 seconds.
􁁛  Test "#if DEBUG 的 #else 分支是产品路径，不得被跳过" passed after 25.661 seconds.
􁁛  Test "leadingAmount: edgeToEdge→0, leading(x)→x" passed after 25.661 seconds.
􁁛  Test "Steps：四种呈现都能构造且 body 可求值（不 crash）" passed after 25.661 seconds.
􁁛  Test "StepItem：description / isError 原样保留" passed after 25.661 seconds.
􁁛  Test "offset starts at -width when progress is 0" passed after 25.661 seconds.
􁁛  Test "current 不在集合中时回落到首个元素（防御式处理数据源变化）" passed after 25.661 seconds.
􁁛  Test "行尾注释不产生误报" passed after 25.661 seconds.
􁁛  Test "CoreProgressViewStyle 的填充条随 .tint 变色，而非恒取 accent" passed after 25.661 seconds.
􁁛  Test "accessibilityValueText：非当前步骤且非错误态返回 nil" passed after 25.662 seconds.
􁁛  Test "composed placeholder tree (circle + line) type-checks without erasure" passed after 25.661 seconds.
􁁛  Test "isLoading true stores the loading flag" passed after 25.661 seconds.
􁁛  Test "非空数据源可安全构造并生成 body" passed after 25.661 seconds.
􁁛  Test "placeholder and content builders are preserved without erasure" passed after 25.661 seconds.
􁁛  Test "offset is periodic with the configured duration" passed after 25.661 seconds.
􁁛  Test "扫描器能看见跨行调用——评审实测的失明形态" passed after 25.661 seconds.
􁁛  Test "扫描器能看见插值内层的字面量" passed after 25.662 seconds.
􁁛  Test "bundle 里必须能找到 xcassets——目录形式或编译后的 Assets.car" passed after 25.661 seconds.
􁁛  Test "progress：尾索引在 currentIndex 越界到 items.count 时为 done（全部完成场景）" passed after 25.662 seconds.
􁁛  Test "offset with zero or negative width returns zero" passed after 25.661 seconds.
􁁛  Test "J-3：标注 nativeProtocol 的组件，作用域内不得出现自有样式协议" passed after 25.662 seconds.
􁁛  Test "Sources/ 下非 DEBUG 路径的 a11y 字面量全部走 bundle: .module" passed after 25.662 seconds.
􁁛  Test "Steps：.text 呈现只消费 items.count 与 currentIndex —— 逐条内容不参与" passed after 25.661 seconds.
􁁛  Test "Steps：presentation 原样保留" passed after 25.661 seconds.
􁁛  Test "单页边界：1 of 1" passed after 25.662 seconds.
􁁛  Test "isLoading false stores the loading flag" passed after 25.661 seconds.
􁁛  Test "TimelineItem(content:)：status 缺省为 .info" passed after 25.661 seconds.
􁁛  Test "CoreDisclosureGroupStyle 的 chevron 随 .tint 变色，而非恒取 accent" passed after 25.661 seconds.
􁁛  Test "init with custom spacing stores value" passed after 25.661 seconds.
􁁛  Test "init with value stores clamped value" passed after 25.661 seconds.
􁁛  Test "progress：currentIndex 为 0 且只有一步时该步为 current" passed after 25.662 seconds.
􁁛  Test "空集合恒返回 nil" passed after 25.662 seconds.
􁁛  Test "StepsPresentation：四个 case 互不相等（Equatable 不是恒真）" passed after 25.661 seconds.
􁁛  Test "accessibilityLabelKey：StatusLevel 各档映射到 Phase 0 预登记键" with 3 test cases passed after 25.661 seconds.
􁁛  Test "init with default spacing uses CoreSpacing.xs" passed after 25.661 seconds.
􁁛  Test "non-finite value sanitized to 0" passed after 25.662 seconds.
􁁛  Test "Timeline：四种布局都能构造且 body 可求值（不 crash）" passed after 25.661 seconds.
􁁛  Test "TimelineItem(status:node:content:)：node 非 nil（自定义节点覆盖默认圆点）" passed after 25.661 seconds.
􁁛  Test "Timeline(items:)：items 数量与顺序原样保留" passed after 25.661 seconds.
􁁛  Test "value clamped to 0...1" passed after 25.661 seconds.
􁁛  Test "Timeline(items:)：空数组不崩溃" passed after 25.661 seconds.
􁁛  Test "空数据源可安全构造" passed after 25.662 seconds.
􁁛  Test "Timeline：layout 默认 .vertical —— 现有调用方零影响" passed after 25.661 seconds.
􁁛  Test "A9 承重：注入的 host 真的驱动了产线挂载路径" passed after 25.661 seconds.
􁁛  Test "Timeline：.grouped 下 node: 槽仍被原样保留（不生效 ≠ 被改写）" passed after 25.661 seconds.
􁁛  Test "isLastItem：item 不在 items 中（不同 id）返回 false，不崩溃" passed after 25.661 seconds.
􁁛  Test "J-2：语义组件必须有样式扩展点（原生协议采纳 或 自有协议定义+使用）" passed after 25.661 seconds.
􁁛  Test "TimelineLayout：四个 case 互不相等（Equatable 不是恒真）" passed after 25.661 seconds.
􁁛  Test "末尾元素之后回绕到首个元素" passed after 25.662 seconds.
􁁛  Test "TimelineItem：显式传入的 id 原样保留（不被 UUID() 缺省值覆盖）" passed after 25.661 seconds.
􁁛  Test "Timeline.alternateSlotWidth：三列几何的槽宽，且节点中心恰落在行中心" passed after 25.661 seconds.
􁁛  Test "accessibilityLabelKey：danger 映射到 "Error"（非字面 "Danger"，对 VoiceOver 更清晰）" passed after 25.661 seconds.
􁁛  Test "SpinningModifier：presentation 默认 .overlay —— 现有调用方零影响" passed after 25.661 seconds.
􁁛  Test "A7 兜底：全部形态都能渲染出非空内容" passed after 25.661 seconds.
􁁛  Test "sidebar footer constructs" passed after 25.661 seconds.
􁁛  Test "位置文案格式化为「index of count」（本地化 %@ of %@ 键，两端 formatted()）" passed after 25.661 seconds.
􁁛  Test "TopBarIndicator：轨道常驻 ⇒ 任意相位下顶条都占据可见高度" passed after 25.661 seconds.
􁁛  Test "isLastItem：非末条返回 false" passed after 25.661 seconds.
􁁛  Test "TimelineItem(status:content:)：node 为 nil，status 原样保留" passed after 25.661 seconds.
􁁛  Test "sidebar navigation row constructs selected" passed after 25.661 seconds.
􁁛  Test "isActive / text 透传存储" passed after 25.661 seconds.
􁁛  Test "A10 承重：.centeredHUD 下 edge 不影响渲染（逐字节相等）" passed after 25.661 seconds.
􁁛  Test "SpinningModifier：presentation 原样保留" passed after 25.661 seconds.
􁁛  Test "SpinningPresentation：三个 case 互不相等（Equatable 不是恒真）" passed after 25.661 seconds.
􁁛  Test "A5b 承重：容器形状真的不同（banner 是矩形，capsule 有圆角）" passed after 25.661 seconds.
􁁛  Test "Timeline：layout 原样保留" passed after 25.662 seconds.
􁁛  Test "单元素集合恒返回自身" passed after 25.662 seconds.
􁁛  Test "isLastItem：单条数组，唯一元素即末条" passed after 25.662 seconds.
􁁛  Test "isLastItem：数组末条返回 true" passed after 25.662 seconds.
􁁛  Test "TopBarIndicator.offset：相位覆盖整条轨道，首尾衔接不跳变" passed after 25.661 seconds.
􁁛  Test "offset stays within [-width, width] across the full period" passed after 25.663 seconds.
􁁛  Test "glassBorderOpacity is 0.2" passed after 25.661 seconds.
􁁛  Test "A10b 承重：A10 的非退化前置 —— 换 edge 在本平台确实能产生位图差异" passed after 25.661 seconds.
􁁛  Test "SpinningModifier：.topBar 下 text 仍被原样保留（不生效 ≠ 被改写）" passed after 25.661 seconds.
􁁛  Test "sidebar document row constructs" passed after 25.661 seconds.
􁁛  Test "sidebar tag row constructs" passed after 25.661 seconds.
􁁛  Test "sidebar section constructs with text content" passed after 25.662 seconds.
􁁛  Test "A11b 承重：.centeredHUD 真的 content-hugging（ink 不随容器宽变化）" passed after 25.661 seconds.
􁁛  Test "SidebarUtilityRow：presentation 默认 .iconLeading（行为兼容）" passed after 25.661 seconds.
􁁛  Test "current 为 nil 时回落到首个元素" passed after 25.661 seconds.
􁁛  Test "A6 承重：.centeredHUD 不因挂载增高，另两个形态会" passed after 25.661 seconds.
􁁛  Test "残余组 1：autoclosure 组合糖——返回位递归覆盖 Bool? / Optional<Bool> / (Bool)?" passed after 25.661 seconds.
􁁛  Test "onComplete：未填满不触发" passed after 25.661 seconds.
􁁛  Test "optional tint and label stored" passed after 25.662 seconds.
􁁛  Test "SpinningModifier：三种形态 × isActive 都能构造" passed after 25.661 seconds.
􁁛  Test "A5 承重：fullWidthBanner 与 floatingCapsule 渲染不同" passed after 25.661 seconds.
􁁛  Test "sidebar utility row constructs with trailing image" passed after 25.661 seconds.
􁁛  Test "SidebarUtilityRow：.textOnly 下 systemImage 仍原样保留（不生效 ≠ 被改写）" passed after 25.661 seconds.
􁁛  Test "CBool 折入 plainBool——stdlib typealias CBool = Bool 是同一类型的另一拼法" passed after 25.661 seconds.
􁁛  Test "character(at:in:)：负数下标返回 nil，不崩溃" passed after 25.661 seconds.
􁁛  Test "sanitizedValue：粘贴场景——非数字与超长同时出现" passed after 25.661 seconds.
􁁛  Test "残余组 4：标点周围空白——Swift . Bool / Optional <Bool> / 泛型实参位复现" passed after 25.661 seconds.
􁁛  Test "character(at:in:)：下标在范围内返回对应字符" passed after 25.661 seconds.
􁁛  Test "glassInset is 2pt" passed after 25.661 seconds.
􁁛  Test "A11 承重：三形态的实际占宽符合各自定义" passed after 25.662 seconds.
􁁛  Test "nodeColor：StatusLevel 各档映射到对应 StatusColors emphasis token" with 4 test cases passed after 25.663 seconds.
􁁛  Test "SidebarUtilityRowPresentation：两个 case 可区分（Equatable 非退化）" passed after 25.663 seconds.
􁁛  Test "onComplete：为 nil 时填满也不崩溃" passed after 25.662 seconds.
􁁛  Test "负例（收窄 3）：返回类型不是 some View ⇒ 不采" passed after 25.662 seconds.
􁁛  Test "isComplete：字符数等于 length 时为真" passed after 25.662 seconds.
􁁛  Test "onComplete：正常补满最后一位触发一次，参数为最终值（主路径回归守卫）" passed after 25.662 seconds.
􁁛  Test "length 非正数 clamp 到 1，不产生 0 或负数格数" passed after 25.662 seconds.
􁁛  Test "处理流水线：粘贴超长噪声输入后仍能正确判定填满" passed after 25.662 seconds.
􁁛  Test "onComplete：满态自动填充替换成新的完整码时触发（.oneTimeCode 场景）" passed after 25.662 seconds.
􁁛  Test "onComplete：删一位再补回最后一位应再次触发（转变沿复位）" passed after 25.662 seconds.
􁁛  Test "accessibilityValueText：非掩码且已填时把数字附在位置后" passed after 25.662 seconds.
􁁛  Test "all values are positive and non-zero" passed after 25.663 seconds.
􁁛  Test "正例：public extension View 上返回 some View 的方法，参数被采进接线" passed after 25.662 seconds.
􁁛  Test "负例（收窄 1）：不在 extension View 上 ⇒ 不采" passed after 25.662 seconds.
􁁛  Test "sanitizedValue：超出 length 的多余数字被截断" passed after 25.662 seconds.
􁁛  Suite "组件判据端到端变异" passed after 25.673 seconds.
􁁛  Test "现状钉：全部呈现组合的高度互等且为 50（≠ a11y 契约，改 token 时须回来改这个数）" passed after 25.662 seconds.
􁁛  Test "accessibilityValueText：掩码态 / 空格只播位置，不泄露不臆造" passed after 25.662 seconds.
􁁛  Test "focusedIndex：填满时 clamp 在最后一格，不越界" passed after 25.662 seconds.
􁁛  Test "onComplete：满态多敲一位——两轮 onChange 均不重复触发" passed after 25.662 seconds.
􁁛  Test "既有 init 通路不受影响：宿主仍记类型名" passed after 25.662 seconds.
􁁛  Test "pressedScale is 0.94" passed after 25.663 seconds.
􁁛  Test "负例（收窄 2）：非公开方法 ⇒ 不采" passed after 25.662 seconds.
􁁛  Test "承重：别名表里每个 modifier 入口都把签名参数**逐名转发**下去" passed after 25.663 seconds.
􁁛  Test "isSecure 默认关闭（明文展示）" passed after 25.662 seconds.
􁁛  Test "focusedIndex：未填满时指向下一个空格" passed after 25.662 seconds.
􁁛  Test "sanitizedValue：过滤非数字字符（字母 / 符号 / 空格）" passed after 25.662 seconds.
􁁛  Test "承重：.textOnly 完全忽略 systemImage —— 故写 "" 的约定不承重" passed after 25.662 seconds.
􁁛  Test "shouldFireComplete：新值满 且『规整旧值 ≠ 新值』才为真（含写回第二轮 / 满态替换）" passed after 25.662 seconds.
􁁛  Test "isComplete：字符数不足 length 时为假" passed after 25.662 seconds.
􁁛  Test "全部呈现组合的命中高度均 ≥ 44pt" passed after 25.662 seconds.
􁁛  Test "承重：.textOnly 不渲染 leading 槽、也不占位" passed after 25.662 seconds.
􁁛  Test "onComplete：onAppear 已满初值不触发（firesOnComplete:false，防 NavigationStack 重放循环）" passed after 25.662 seconds.
􁁛  Test "承重：leading 字形真的由 systemImage 决定（组件不得忽略该入参）" passed after 25.662 seconds.
􁁛  Test "convenience text init forwards variant + outlined" passed after 25.662 seconds.
􁁛  Test "sanitizedValue：空字符串保持为空" passed after 25.663 seconds.
􁁛  Test "处理流水线：未填满时不触发 onComplete 语义" passed after 25.662 seconds.
􁁛  Test "候选 2 的组合：行尾字形真的占了位，且不影响 leading 侧差值" passed after 25.662 seconds.
􁁛  Test "BadgeVariant covers the 5 status indicator levels" with 5 test cases passed after 25.662 seconds.
􁁛  Test "处理流水线：填满 length 格时 isComplete 为真，可驱动 onComplete 触发" passed after 25.662 seconds.
􁁛  Test "displayText：isSecure 为 true 时以圆点替代实际字符" passed after 25.663 seconds.
􁁛  Test "兜底：SidebarUtilityRow 与 SidebarNavigationRow 同 title 时宽度逐点相等" passed after 25.662 seconds.
􁁛  Test "character(at:in:)：下标超出当前长度返回 nil（空格）" passed after 25.663 seconds.
􁁛  Test "public typealias 洗 Bool 会被清点——参数侧确实看不见，所以声明侧必须看得见" passed after 25.661 seconds.
􁁛  Test "designated init stores variant + outlined + label without erasure" passed after 25.662 seconds.
􁁛  Test "length 通过 init 原样保留（合法正数）" passed after 25.662 seconds.
􁁛  Test "残余组 2：specifier 后无空格——consuming(Bool) / borrowing(Bool)" passed after 25.663 seconds.
􁁛  Test "四个新 key 确实注册进 catalog——而不是靠 key 回退看起来对" passed after 25.662 seconds.
􁁛  Test "positionText：按 Phase 0 位置键组装，两端为 formatted() 结果" passed after 25.662 seconds.
􁁛  Test "边界值：0% 与 100%" passed after 25.662 seconds.
􁁛  Test "`-> Bool` 但无 Bool 参数 ⇒ 零命中" passed after 25.661 seconds.
􁁛  Test "displayText：isSecure 为 false 时明文展示字符本身" passed after 25.663 seconds.
􁁛  Test "残余组 3：attribute 后无空格——@autoclosure() -> Bool" passed after 25.662 seconds.
􁁛  Test "placeholder 为空时，清除按钮的可访问名内外层都走 catalog" passed after 25.661 seconds.
􁁛  Suite "登记表↔扫描器 差集纯函数" passed after 25.673 seconds.
􁁛  Test "displayText：字符为 nil（空格）时始终返回空字符串，不论 isSecure" passed after 25.662 seconds.
􁁛  Test "同时有 Bool 参数与 Bool 返回值 ⇒ 只命中参数，且命中数等于参数数" passed after 25.661 seconds.
􁁛  Test "convenience text init defaults variant to neutral and outlined to false" passed after 25.661 seconds.
􁁛  Test "`#if` 两个分支都扫；`#Preview` 里的声明不扫（顶层 expr 位 + 成员 decl 位）" passed after 25.661 seconds.
􁁛  Test "源码新增未豁免 Bool ⇒ violations 非空、stale 仍空" passed after 25.661 seconds.
􁁛  Test "清单与命中完全一致 ⇒ 两个方向都空" passed after 25.662 seconds.
􁁛  Test "public protocol 的 requirement 上的 Bool 参数是命中；非 public protocol 不是" passed after 25.660 seconds.
􁁛  Test "public extension 的两种写法都算 public" passed after 25.661 seconds.
􁁛  Test "非 public 宿主与非 public extension 的 Bool 参数一律不算" passed after 25.660 seconds.
􁁛  Test "subscript 上的 Bool 参数同样命中——不给它留逃逸口" passed after 25.661 seconds.
􁁛  Test "processInput：粘贴超长噪声输入被截断且清洗后写回 Binding" passed after 25.663 seconds.
􁁛  Test "两个方向可以同时非空——违规与过期条目互不掩盖" passed after 25.661 seconds.
􁁛  Test "placeholder 非空时用调用方传入值，库不翻译它" passed after 25.661 seconds.
􁁛  Test "嵌套类型的 owner 是点分全名；无标签参数取内部名" passed after 25.661 seconds.
􁁛  Test "清单有源码里已不存在的条目 ⇒ stale 非空、violations 仍空" passed after 25.661 seconds.
􁁛  Test "百分比值走 catalog，且渲染结果不含字面量 %%" passed after 25.662 seconds.
􁁛  Test "value 通过 Binding 双向绑定，构造时原样保留" passed after 25.662 seconds.
􁁛  Test "public enum case 的 Bool 关联值是命中（含无标签的位置兜底）" passed after 25.659 seconds.
􁁛  Test "裁决 (g)：public extension 里的嵌套具名类型默认就是 public——不建模会整支漏采" passed after 25.660 seconds.
􁁛  Test "分类器逐类型断言：显式处理，不靠「恰好没匹配上」" passed after 25.660 seconds.
􁁛  Suite "RatingDisplay" passed after 25.673 seconds.
􁁛  Test "public Bool 属性只进 publicBoolProperties，不进 hits" passed after 25.661 seconds.
􁁛  Test "Binding<Bool> / FocusState<Bool>.Binding 归 .boolCarrying，不进 hits" passed after 25.661 seconds.
􁁛  Suite "基础容器 Separator.Inset 逻辑" passed after 25.674 seconds.
􁁛  Suite "TagInput" passed after 25.674 seconds.
􁁛  Suite "Steps" passed after 25.674 seconds.
􁁛  Suite "StateLabel" passed after 25.674 seconds.
􁁛  Suite "a11y 字面量必须走 String Catalog" passed after 25.674 seconds.
􁁛  Suite "Skeleton" passed after 25.674 seconds.
􁁛  Suite "Carousel" passed after 25.674 seconds.
􁁛  Suite "J-3 原生协议纯度" passed after 25.674 seconds.
􁁛  Suite "资源 bundle canary" passed after 25.674 seconds.
􁁛  Suite "FlowLayout" passed after 25.674 seconds.
􁁛  Suite "SkeletonShimmerMath" passed after 25.674 seconds.
􁁛  Suite "`.tint` 真实响应（像素级）" passed after 25.674 seconds.
􁁛  Suite "J-2 样式扩展点" passed after 25.674 seconds.
􁁛  Suite "CoreButtonMetrics" passed after 25.674 seconds.
􁁛  Suite "ProgressBar（弃用守卫）" passed after 25.674 seconds.
􁁛  Suite "SpinningModifier 存储契约" passed after 25.674 seconds.
􁁛  Suite "SidebarUtilityRow leading 槽渲染护栏（#64）" passed after 25.674 seconds.
􁁛  Suite "Toast 公开入口的参数转发" passed after 25.674 seconds.
􁁛  Suite "Bool 分类器残余形态回归" passed after 25.674 seconds.
􁁛  Suite "ProgressBar a11y 本地化" passed after 25.674 seconds.
􁁛  Suite "Badge" passed after 25.674 seconds.
􁁛  Suite "SearchField a11y 本地化" passed after 25.674 seconds.
􁁛  Suite "Sidebar components" passed after 25.674 seconds.
􁁛  Suite ToastPresentationRenderTests passed after 25.675 seconds.
􁁛  Suite "Timeline" passed after 25.674 seconds.
􁁛  Suite "D2 接线通路二：extension View modifier 的三条收窄条件" passed after 25.674 seconds.
􁁛  Suite "Bool 参数扫描层" passed after 25.674 seconds.
􁁛  Suite "PinCode" passed after 25.674 seconds.
􀟈  Test "dismiss(id:) 不存在的 id 是 no-op，不崩溃" started.
􁁛  Test "dismiss(id:) 不存在的 id 是 no-op，不崩溃" passed after 0.001 seconds.
􀟈  Test "dismiss(id:) 正在显示的 item 进入 dismissing 状态" started.
􁁛  Test "dismiss(id:) 正在显示的 item 进入 dismissing 状态" passed after 1.384 seconds.
􀟈  Test "dismiss(id:) 重复触发不 double-fire" started.
􁁛  Test "dismiss(id:) 重复触发不 double-fire" passed after 1.382 seconds.
􀟈  Test "自动 dismiss 后 advance 到下一条" started.
􁁛  Test "自动 dismiss 后 advance 到下一条" passed after 1.578 seconds.
􀟈  Test "duration 从 start of display 起算（不是 enqueue）" started.
􁁛  Test "duration 从 start of display 起算（不是 enqueue）" passed after 4.185 seconds.
􁁛  Suite "ToastHost queue state machine" passed after 34.206 seconds.
􀢂  Test run with 465 tests in 71 suites passed after 34.211 seconds with 2 known issues.：**465 tests / 71 suites 全绿**（基线 454）。
