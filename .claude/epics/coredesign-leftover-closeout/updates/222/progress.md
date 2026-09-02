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
