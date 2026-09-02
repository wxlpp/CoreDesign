---
issue: 220
started: 2026-09-03
completion: 100%
---

# Issue #220 进度

## 已完成

1. **三个 token 别名改写**（`SurfaceColors.swift`）
   - `surfaceSidebar`: `surfaceCanvasSubtle` → `surfaceElevated`
   - `surfaceOverlay`: `surfacePanel` → `secondaryFill`
   - `surfacePanel`: `surfaceCanvasSubtle` → `quaternaryFill`
2. **5 段旧论述 + 1 段边界前提清洗**，10 个关键词逐条单跑确认清零
3. **macOS 守卫**（token 身份层）：五路碰撞钉死、canvas 独立、三 fill 两两不同且与背景不同
   —— 该 suite 此前完全不覆盖 fill，本次为新增覆盖
4. **iOS 守卫**（`Color.Resolved` 逐位）：深色 6 / 浅色 5 distinct + 已知相等项钉死
5. **`BREAKING-CHANGES.md`** 未发布章节条目

## 实测数据

**改动前**（红态输出实测，确认 PRD 的「当前 3 个 distinct」）：

| | 浅色 | 深色 |
|---|---|---|
| canvas | `#F2F2F7FF` | `#000000FF` |
| content/card/grouped | `#FFFFFFFF` | `#1C1C1EFF` |
| canvasSubtle | `#FFFFFFFF` | `#1C1C1EFF` |
| sidebar | `#FFFFFFFF` | `#1C1C1EFF` |
| control (tertiaryFill) | `#7676801F` (α≈0.122) | `#7676803D` (α≈0.239) |
| floating | `#FFFFFFFF` | `#1C1C1EFF` |
| overlay/panel | `#FFFFFFFF` | `#1C1C1EFF` |
| **distinct** | **3** | **3** |

`tertiaryFill` 的 α 与 PRD 推演表预期（0.12 / 0.24）一致，未触发 NFR-2 回改流程。
**三档填充 α 全部实测**（iPhone 17 Pro / iOS 26.4），与推演表逐项吻合：

| 填充档 | 浅色 | α | 深色 | α | PRD 预期 |
|---|---|---|---|---|---|
| `secondaryFill`（floating） | `#78788029` | 0.161 | `#78788052` | 0.322 | 0.16 / 0.32 ✓ |
| `tertiaryFill`（control） | `#7676801F` | 0.122 | `#7676803D` | 0.239 | 0.12 / 0.24 ✓ |
| `quaternaryFill`（overlay/panel） | `#74748014` | 0.078 | `#7676802E` | 0.180 | 0.08 / 0.18 ✓ |

⚠️ 三档 RGB 几乎相同（`#787880`/`#767680`/`#747480`），**区分几乎全靠 α**——
逐位判据会平凡通过，观感由 #225 回答。测试里断言的是 α 的**序**而非具体值。

**变异自证**（靶点 `surfaceOverlay` → 改回 `.surfacePanel`）：
```
✘ iOS 深色 distinct 应为 6，实际 5：… floating=#7676802E / overlay/panel=#7676802E
✘ iOS 浅色 distinct 应为 5，实际 4：… floating=#74748014 / overlay/panel=#74748014
✘ .light/.dark：floating 与 overlay/panel 同值
✔ 「已知相等项钉死」仍通过 —— 变异未误伤本该相等的档位
** TEST FAILED **
```

**macOS 腿**：`swift test` → **457 tests / 68 suites 全绿，2 known issues**
（基线 454，+3 = 本次新增的三个 macOS 断言）。

## 验证结果

- **macOS 腿**：`swift test` → **457 tests / 68 suites 全绿**（基线 454，+3）
- **iOS 腿**：`xcodebuild` → **499 tests / 73 suites，`** TEST SUCCEEDED **`**（基线 495，+4）
- **变异自证**：见上，守卫精确判红

## 本 task 之外的发现（不在范围内，收尾列给用户）

**`docs/BREAKING-CHANGES.md` 的 tag 清单已失真**：头部「已发布的 git tag」列到 `v0.8.0` 为止，
文档也没有 `0.9.0` 章节——但 `git tag` 实测 **`v0.9.0` 已存在**。这是本次改动**之前**就有的
文档失真，且补它需要知道 v0.9.0 实际含什么，故未在本 task 内静默修复。

## 过程中踩到的假绿形态（三个，均已避开）

1. **`grep -rn "..." $VAR` 静默返回空**——文件与内容都在，变量展开导致零命中。
   「静默为空」与「已清洗干净」输出完全一致。⇒ 验收 grep **逐条单跑 + 显式路径**，
   且清洗前须先确认它**能命中**。
2. **build failed 与 test failed 都打印 `** TEST FAILED **`**——首次写测试时
   `#expect` 第二参是 `Comment?`、`String + String` 拼接不能隐式转换，编译失败；
   若把它当成「守卫判红」，就会拿一个从未跑起来的测试当有效证据。
3. **`xcodebuild ... | tail` 的退出码来自 `tail`**——`** TEST FAILED **` 会伴随 `exit 0`。
   ⇒ `set -o pipefail` + `${PIPESTATUS[0]}`，且判绿一律读输出。
