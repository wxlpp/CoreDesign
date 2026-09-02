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
