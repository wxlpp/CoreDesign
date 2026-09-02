---
issue: 226
started: 2026-09-03
completion: 100%
---

# Issue #226 · Sidebar 定案 + 三个 issue 关闭

## 1 · FR-10 · Sidebar 选中态：不改行为，写清楚

保持「浮层玻璃 + 全周选中色描边 + 阴影」，**刻意不追随原生的着色填充**。
定案写进 `Sidebar.swift` 的 `sidebarSelectedBackground(_:)` doc 与
`docs/components/sidebar.md`。**零行为改动。**

⚠️ **成本如实记账**：该差异被**两个独立评审**分别提出、措辞高度一致——
#136 说「读起来更像**聚焦的输入框**」，#225 视觉终审说「**读作键盘 focus ring
而非选中态**」。两次都读成「聚焦」，说明它与用户既有平台直觉冲突。
文档里明写：**这不是「他们看错了」，是本库选了一条需要用户重新学习的表达**；
若有第三次同类反馈或本库整体向原生收敛，**应当重议而不是再次援引本条**。

## 2 · FR-11 · 三个 issue 已关闭

| issue | 结论 |
|---|---|
| **#139** | 悬空指针——6 个 task 全 CLOSED、已归档、`v0.4.0` tag 实测存在 |
| **#136** | 三条**各有各的结论**：1 已修（#220+#225）、2 已修（#221）、3 **按决策不改** |
| **#115** | 四类逐条：**4 处 L10n 因 #117 删组件而作废**、Blossom 观感因 #118 作废、
「Toggle Inspector」在 `#if DEBUG` 内不成立；其余已修 |

⚠️ 两项**如实记为「未证实 / 未执行」而非「已复核」**：
`SegmentedControl` thumb 动画（光栅快照证不了动画在动）、VoiceOver 冒烟（本轮未执行）。

## 3 · 承诺的三个承接 issue 已真的开出来

#233（thumb 动画验证手段）、#234（VoiceOver 冒烟）、#235（百分号 locale 感知格式）。
关闭说明里写「建议单开」就要开出来，否则那句话是空头支票。

## 4 · 跨仓通知（#221 DoD 的最后一项）

已在 `oh-my-story#50` 留言：`BottomInputBar` 提 public 并登记、`placeholder` 判 B
（及其与 `SearchField`/`TagInput` 的 C 分类不一致 → D-44-4）。**只通知，不代改。**

## 5 · 处置本地 Copilot CLI 对 PR #232 的评审（3 条，全部成立）

### 🔴 macOS 撞车没解除，只是换了个更隐蔽的对象

#225 把 macOS 分支写成 `NSColor(name:dynamicProvider:)`、浅色返回
`controlBackgroundColor`。但 `secondarySystemGroupedBackground`（→`surfaceCard`）
与 `tertiarySystemGroupedBackground`（→`surfaceSidebar`）在 macOS 上**也都返回
`controlBackgroundColor`** ⇒ `.floating` 与 `.card`/`.canvasSubtle`/`.sidebar`
**像素级同色**。

⚠️ **而测试对此假绿**：`macOSFillTokensAreDistinct` 里的
`surfaceOverlay != surfaceCard` **通过了**——纯粹因为两者 `Color` 构造路径不同
（`dynamicProvider` vs 直接字面量），身份比较判不等。**身份不等 ≠ 颜色不同。**

**处置**：AppKit 的不透明背景族只有两个真实取值，**已被 `.canvas` 与 `.content` 族
占满**——浮层在 macOS 上没有第三个不透明位置可站。⇒ macOS **不分道**，两种外观都
保留 `secondaryFill`（半透明，与两个背景取值都不撞）。

**新增守卫** `macOSUnderlyingNSColorsAreDistinct`：把 `Color` 拆回底层 `NSColor` 再比
——catalog 常量按名字判等，能抓住「构造路径不同但底层同色」这类假绿。
变异自证：把 macOS 分支改回 `controlBackgroundColor` → 精确判红。

### 🟠 PRD 数字没回改，且 progress 自述失实

PRD 的 FR-2 明文规定「若实测与表值不符：重推 distinct 数并**回改 PRD、US-2、
Success#3 与测试**」。#225 把浅色 5 改成 4 时**只改了代码与测试**，PRD/epic 里
`浅色 5` 一处没动——**我执行了「不削弱断言」那半，漏了「回改 PRD」那半**。

而 `updates/225/progress.md` 写着「断言与文档同步更正」——**这句是失实的**。
已回改 PRD:252/457、epic:35/155，并在 225 的 progress 里更正该句。

### 🟡 测试名 stale

`surfaceKindTokensAreFiveDistinctInLight` 断言的是 `count == 4`。已改名为
`...AreFourDistinctInLight` 并更新标题（原标题只提「canvas 与 sidebar 同值」，
漏了新增的 `floating == content`）。

## 验证

- macOS `swift test`：**474 / 72**（开工基线 454 / 68）
- iOS `xcodebuild`：**516 / 77 `** TEST SUCCEEDED **`**（开工基线 495 / 73）
