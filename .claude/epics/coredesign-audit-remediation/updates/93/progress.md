---
issue: 93
started: 2026-07-19T16:00:00Z
last_sync: 2026-07-19T19:08:22Z
completion: 100%
---

# Issue #93 完成记录

承载 12 个审计项：A1、A2d、B1a、B1b、B1c、B6a、B6b、B6c、D11、D13、D14、D19，全部标记为已修复。

## 毒丸阶段的产出（commit `3bf4b3d`）

给 `FunctionalColor` 的 12 个遮蔽符号加 `@available(*, deprecated)`，编译器精确报出全部残留使用点：

```
Colors/CoreGradient+Preview.swift:17:63    'secondary' is deprecated
Components/CheckBox/CheckBox.swift:31:44   'primary'   is deprecated
Components/StatusRow/StatusRow.swift:80:32 'secondary' is deprecated
```

恰好 3 处，两种 trait 一致，与审计吻合，无隐藏点。`swift test` 侧无额外条目，`App/` 零引用。

**执行期的教训**：首次贴毒丸用了 `count=1`，只贴中 `#if Blossom` 分支的 `secondary`，默认构建（走 `#else`）诊断只报 1 处、看起来干净——那是**静默不完整**，正是这机制本该防的失败模式。必须 16 处声明全贴、两种 trait 都编译。

## 三处遮蔽点的行为变化（都是修复，不是回归）

| 位置 | 改前（遮蔽导致） | 改后 |
|---|---|---|
| `CheckBox.swift:31` | 品牌蓝（而注释声称"自动适配系统外观"） | `contentPrimary` 系统 label 色 |
| `StatusRow.swift:80` | 浅蓝 / Blossom 下紫罗兰 | `contentSecondary` 中性次要色 |
| `CoreGradient+Preview.swift:17` | 经遮蔽符号取到 violet | `secondaryAccent`，语义明确且仍随 trait |

## 执行期的三条改判（已同步进 93.md / audit-checklist / PRD / epic.md）

1. **`statusAccent*` 保留**（原判整组删除）——删它与本任务自身的 legacy 迁移互斥：新体系只有 `statusAccent*` 一个蓝色家族，而它正是 Primer 的 info 语义，Banner/Toast/Badge 的 legacy `info*` 只能迁到它。原判据「库内零渲染消费点」恰恰因为 info 当时走 legacy
2. **五组 emphasis 全错**（原判 accent 单组笔误）——横向比对发现 accent/success/attention/danger/done 的 `*-emphasis` light 值逐组等于同组 `*-muted`，是系统性错误
3. **迁移改变 light + dark 观感**——两套 scale 取自不同来源，light 值 8 处全变（含 warning 前景橙→橄榄黄的色相改变），dark 从不透明实色变 alpha 叠加。已列 NFR 例外第 8、9 条

## 迁移映射表

| legacy | 新体系 | 依据 |
|---|---|---|
| `*Foreground` | `status*Foreground` | 同为前景文本色 |
| `*Background` | `status*Muted` | Primer `muted` = 有色背景块的标准档；`subtle` 是更淡的选区高亮 |
| `*Border` | `status*Border`（新增 4 个） | 沿用 legacy 的 ramp-3 取值——既有视觉决定，非推导最优解 |

组名对应：`info`→`accent`、`success`→`success`、`warning`→`attention`、`danger`→`danger`。**不建 `done` border**：legacy 无 done 组，零消费者。

## 遗留给下游 Issue

| 给谁 | 内容 |
|---|---|
| #98 | `StatusColorsTests` 已编译通过（删了 `existingTokensPreserved`，96→95 tests）；其余恒真断言待清理 |
| #95 / #101 | 第 4 层不再有交互色，需要时走 `InteractionColors` |
| 后续 | `status-done-emphasis` dark `#8250DF`（应为 Primer `#8957E5`）、`status-done-fg` dark `#AB7DF8`（应为 `#A371F7`）有既有漂移，不在本任务承载项内 |
