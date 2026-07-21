# Issue #99 可访问性 — 完成记录

分支 `issue-99-a11y`（base `epic/coredesign-audit-remediation`）。承载审计项 **D1a / D1b / D1c** 共 3 项。与 #101 真正并发（owner 矩阵 `#8∩#10=∅`，触及文件无交集）。

## 三处按语义区分处理（不一律照抄）

| 图标 | 处理 | 说明 |
|---|---|---|
| BottomInputBar `suggestionButton` | `accessibilityLabel("Suggestions")` + `.isSelected` trait | icon-only toggle；trait 播报面板展开态 |
| BottomInputBar `sendButton` | `accessibilityLabel("Send")` | 一次性动作 |
| BottomInputBar `stopButton` | `accessibilityLabel("Stop")` | 一次性动作 |
| `UnderlinedTabItem` | `.accessibilityAddTraits(self.isSelected ? .isSelected : [])` | 与 SegmentedControl:118 / Sidebar:162 同形 |
| Form `LabelIcon` | `accessibilityHidden(true)` | Label 主用法下 SwiftUI 已合并 icon+text，hidden 是冗余保险 |
| Form `ChevronRightIcon` | `accessibilityHidden(true)` | 永远是 disclosure 指示符，无歧义装饰 |
| Form `DangerIcon` | `accessibilityLabel("Alert")` | **承载语义**，补 label 而非隐藏 |

## 两处评审沉淀的设计取舍

- **LabelIcon 不承诺 opt-out**（评审 Finding 1/I-2）：`LabelIcon` 是 public leaf，但注释**不承诺** `.accessibilityHidden(false)` 能从外层恢复——SwiftUI 内层 `accessibilityHidden(true)` 剪掉子树后外层 unhide 不可靠（仓库无先例）。在 `Label { Text } icon: { LabelIcon }` 主用法下 SwiftUI 已把 icon+text 合成单一元素由 Text 播报，故 hidden 冗余无害；standalone 需播报时调用方应组合自带 label 的图标视图。
- **DangerIcon 用 "Alert" 而非 "Warning"**（评审 Finding 2）：`DangerIcon` 渲染 `statusDangerForeground`（红，danger 语义）。`FunctionalColor` 的 `warning`（橙）与 `danger`（红）是两个不同状态语义——念「Warning」会混淆屏读用户本该能区分的状态。用 "Alert"（与 danger 对齐、不撞 token）。

## 验证

- 四条 SwiftPM 命令 clean 冷跑全 **EXIT=0**，两侧 **96 tests / 30 suites passed**（a11y 无单元测试，测试数不变），**warning 全 0**。
- 越界自查 `rc=1`：改动只在 `BottomInputBar`/`TabBar`/`Form` 三组件目录 + `.claude/`。
- 逐处精确核对（Step 2b）：每个 label 值挂对元素（suggestion=Suggestions+trait / send=Send / stop=Stop，各对应正确 SF Symbol）；Form 两 hidden + DangerIcon="Alert"、零 "Warning"。
- audit-checklist D1a/b/c 标 ✅，计数 **83 / 79** 未漂移。

## VoiceOver 运行时冒烟——deferred（诚实记录，未用 grep 冒充）

DoD 末项要求运行时 VoiceOver 冒烟（开 VoiceOver 听 spoken output）。**本任务不自动执行**——ViewInspector 属 Out of Scope，swift test 断言不了 a11y 运行时行为。代码层已逐处核对，运行时预期的 spoken output：

- suggestion 按钮：「Suggestions, button」，面板展开时「Suggestions, selected, button」
- send / stop 按钮：「Send, button」/「Stop, button」
- tab 选中项：播报 `.isSelected`（「…, selected」）
- Form `LabelIcon` / `ChevronRightIcon`：不被 VoiceOver 聚焦（装饰隐藏）
- Form `DangerIcon`：念「Alert」

**建议用户在 iOS Simulator 开 VoiceOver / Accessibility Inspector 走一遍 BottomInputBar / UnderlinedTabBar / Form 复核。** 该 DoD 项标 `deferred（运行时，待用户复核）`，不因代码修复自动满足。

## 给下游的交接

- 本任务新增的英文 a11y 字符串（Suggestions/Send/Stop/Alert）是字面量；#100（本地化）纳入 String Catalog 时可一并收（#100 与本任务文件无交集，届时按符号定位）。
- 与 #101 并发无冲突：唯一共享文件是 `audit-checklist.md`（各标各行，D1a/b/c vs B8*/D4-7，不同 hunk）。
