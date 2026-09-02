---
issue: 223
started: 2026-09-03
completion: 100%
---

# Issue #223 进度

## 已完成

1. **删掉 `AGENTS.md` 里已被 #41 证伪的断言**——「重度使用 iOS 26 的 `.glassEffect()`；
   `LightButtonStyle` 会按 `colorScheme` 分支……」，并补上 `CLAUDE.md` 对应的两段
   （更正段 + 「`.glassEffect` 的真实调用面在组件与 modifier 层」）。
2. **新增守卫** `Tests/CoreDesignTests/AgentGuideSyncGuard.swift`，两个 `@Test`：
   - 规范化后两份指引逐行一致（先比行数，再逐行比对，分歧打印两侧原文）
   - **白名单本身有效**——检查三条白名单对应的文本确实还在文件里

## 白名单为什么是显式枚举

只允许三处已知定位差异：AGENTS.md 顶部镜像 banner、标题行、首段定位句。
**没有用宽松正则去吃掉任意差异**——那会让守卫退化成永真断言，正是它要防的东西。

第二个 `@Test` 是防「白名单腐烂」：若某条白名单对应的文本已不在文件里，它就成了
一条死规则，会静默掩护未来真正的分歧。

## 验证

- **规范化 diff 残余分歧：0**（同步前为 1 处实质分歧）
- **`swift test`：456 tests / 69 suites 全绿**（基线 454，+2 断言 +1 suite）
- **变异自证**（往 AGENTS.md 插一行 CLAUDE.md 没有的内容）：
  ```
  ✘ Expectation failed: (claude.count → 77) == (agents.count → 78)
    行数不一致：CLAUDE.md 77 行 vs AGENTS.md 78 行——有内容只加到了其中一边
  ✘ 第 42 / 43 / 44 行（规范化后）分歧
  ```
  还原后恢复全绿。

## 备注

守卫只跑 `swift test`（纯文件比对，无平台依赖），不需要 iOS 腿。
