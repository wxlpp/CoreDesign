---
issue: 225
started: 2026-09-03
completion: 90%
---

# Issue #225 · 视觉复核

## 本节点的意义

这是本 epic 唯一**机械判据完全无能为力**的环节。#220 的 `SurfaceContrastTests` 在
注释里明写「本 suite 只担保逐位不同，观感由 #225 回答」——本轮验证了那句话不是客套：
**它对下面这个 Critical 结构性失明，全程全绿。**

## 视觉终审判定：BLOCK（2 条 Critical，均已修）

### Critical 1 · `.floating` 在浅色下语义反向

`ios-visual-reviewer` 逐像素采样实测：底 `#F2F2F7` → 卡 `#DEDEE4`（Δ20 变暗）、
叠白底 `#FFFFFF` → `#E9E9E9`（Δ22 变暗）。无阴影、无模糊、仅 hairline 描边
——**这在 iOS 浅色语言里正是搜索框 / 输入井的凹陷配方**。

⚠️ **它找到的代码自证比观感直觉更硬**：本文件的 `surfaceCanvasInset` 把同族的
`tertiaryFill` 定义为「**凹陷 well** / 输入框内底色」——**fill 族在本库自己的词汇里
就是「凹」的视觉语言**。`.floating` 取 `secondaryFill` 只是同族更浓一档，凹得更狠。
语义（浮在内容之上）与观感（陷进去）方向相反。

**处置（用户拍板：按外观分道）**——`surfaceOverlay` 改为随外观变化的动态色：

| 外观 | 取值 | 为什么读作浮起 |
|---|---|---|
| 浅色 | `systemBackground`（`#FFFFFF`） | 浅色下「更亮的不透明面」= 抬起 |
| 深色 | `secondaryFill` | 深色下「叠加提亮」= 抬起 |

两侧都往**变亮**方向走，方向一致。不改 `SurfaceModifier` 的 switch、不改任何公开
API 签名——分道完全封装在 token 内部。

#### ⚠️ 实测推翻了我的第一次取值

初版分道取 `secondarySystemBackground`，**实测它浅色下就是 `#F2F2F7`、与
`surfaceCanvas` 同值**，根本不是「更亮」。改取 `systemBackground` 后暴露出一条
**结构性上限**：

- 叠在 `.canvas`（`#F2F2F7`）上 → 更亮，**读作抬起** ✅（重出图确认）
- 叠在 `.content`（`#FFFFFF`）上 → **同值，颜色上完全不可辨** ⚠️

**这不是调参没调好**：浅色下 `.content` 已是纯白，**不存在比它更亮的不透明色**。
iOS 浅色靠**阴影**表达抬起，而 `SurfaceKind.background` 只返回 `Color`、结构上
表达不了阴影。⇒ 浅色下 `.floating` 叠 `.content` 必须由调用方补 `.coreShadow` 或
改用 `floatingGlass`。已钉成**显式相等断言**（`floating == surfaceCard` in light），
不留作隐性回归。

iOS 浅色 distinct 因此由 5 改为 **4**。

⚠️ **本句初版写「断言与文档同步更正」——那是失实的**（本地 Copilot CLI 评审指出）：
当时只改了代码与测试，**PRD 与 epic 里所有写「iOS 浅色 5」的地方一处都没回改**，
而 PRD 的 FR-2 明文规定「若实测与表值不符：按 NFR-2 重推 distinct 数并回改 PRD、
US-2、Success#3 与测试——不得反过来削弱断言去迁就已写好的数字」。
我执行了「不削弱断言」那半，漏了「回改 PRD」那半。现已补齐（PRD:252/457、epic:35/155）。

#### ⚠️ AppKit 侧撞回了 PRD v1 的老塌缩

分道的 macOS 分支初版取不透明的 `surfaceBase`，**实测撞车**：macOS 上
`systemBackground` 与 `systemGroupedBackground` 双双降级到 `windowBackgroundColor`
⇒ `.floating` 与 `.canvas` 同值——**正是 PRD v1 那个「`.floating == .canvas` on
macOS」塌缩被重新引入**（FR-3 当时写「v1 的 macOS 风险已消失」）。

改用 `NSColor(name:dynamicProvider:)` 在 AppKit 侧做同样的分道（深色
`secondarySystemFill` / 浅色 `controlBackgroundColor`），撞车解除。

### Critical 2 · TelegramGlass 预览文字不可见

`.foregroundStyle(.white)` 叠在近白玻璃胶囊 `(251,251,255)` 上、底是浅色画布——
文字行最深像素 `(253,253,254)`，**对比度约 1.0:1**。这是 #102 复核项本身不过关。
改为深色底 + `Color.contentPrimary` 自适应前景（这类玻璃按钮的真实语境本就是深色底）。

## 出图

`KEEP_LIBRARY_SNAPSHOTS=1 scripts/run-snapshots.sh` → **135 张 PNG 落 scratch**，
`git status --porcelain docs/snapshots` **空**（keep 模式不污染仓库快照，已自证）。

新增合成对照 `#Preview`（FR-9 明写没有现成载体）——`SurfacePreviewGallery` 只把每档
平铺在单一底色上，产不出「`.floating` 叠 `.content`」这类图。

## 验证

- **macOS**：`swift test` **473/72 全绿**
- **iOS**：`xcodebuild` **516/77 `** TEST SUCCEEDED **`**
- 重出图目视确认浅色 `.floating` 方向已翻转（白卡浮于灰画布）

## 待完成

- [ ] 视觉评审的 Important/Minor 项（α 阶梯拉不开、`.overlay`/`.panel` 92% 透明无模糊、
      gallery 别名档标注、BottomInputBar chip 被硬切、Sidebar 选中态读作 focus ring）
      —— 攒到收尾一并列给用户
- [ ] 重派视觉评审复核 Critical 处置
