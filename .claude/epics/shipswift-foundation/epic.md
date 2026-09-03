---
name: shipswift-foundation
status: backlog
created: 2026-09-02T23:42:57Z
updated: 2026-09-03T00:20:45Z
progress: 0%
prd: .claude/prds/shipswift-harvest.md
github: https://github.com/wxlpp/CoreDesign/issues/241
---

# Epic: shipswift-foundation（地基与两闸）

> `shipswift-harvest` PRD 拆出的**第 1 个** epic（共 3 个）。
> 姊妹 epic：`shipswift-effects`（效果与图表）、`shipswift-shaders`（Metal）。
> 命名沿用本仓先例 `coredesign-native-refresh` → `coredesign-native-foundation` /
> `coredesign-native-components`。
> **修订**：第 1 轮 structure 评审判 BLOCK（3 Critical + 8 Important + Copilot 2 Critical），
> 本版逐条处置，见文末台账。

## Overview

本 epic **不落任何一个组件**，只做三件事：

1. **决定新代码归哪套公约管**（公约裁决 AD-4）；
2. **把两个新 target 与配套的守卫、CI、probe 立起来**；
3. **跑完两道闸**，为 `shipswift-shaders` 是否启动给出结论。

⇒ 它是另外两个 epic 的共同前置。

## Architecture Decisions

### AD-A 三个 target，Shaders 不在本 epic 建

`CoreDesignEffects` / `CoreDesignCharts` 在本 epic 建；**`CoreDesignShaders` 归
`shipswift-shaders` 的 B-1**。若两闸任一不过，仓库里不会留下一个空 product 及其连带的
`App/project.yml` 条目、probe 调用点、README 索引小节。

⚠️ **A0-5 的 Metal spike 因此必须在仓外做**（评审 Suggestion）：spike 的 `.metal` +
wrapper 样本放 scratch package，**仓内只留结论文档 + 可复用脚本**，不留半个 target。

### AD-B 公约作用域按 target 分别裁决（AD-4）

公约 AD-2（`docs/component-contract.md:1254-1274`）裁定 public `View`/`ViewModifier` 类型
照常进 `component-registry.json`，且未按 target 划作用域。本 epic 第一个 task 提交
**AD-4**，**必须允许按 target 分别裁**：

| target | 推荐走向 | 理由 |
|---|---|---|
| `CoreDesignCharts` | **b：进登记表** | 4 个图表是有形态选择的常规组件，判定法步骤 2 对它们真有内容 |
| `CoreDesignEffects` | **a：轻公约** | 微交互/转场没有"该长什么样"的 API 形态问题 |
| `CoreDesignShaders` | **a：轻公约** | 同上，且其存在取决于两闸 |

⚠️ 三 target 一刀切是**被否决的方案**。

### AD-C ⚠️ AD-4 的裁决判据自带一个环，必须在 A0-1 内部打破

PRD 的裁决判据是「a 侧按既有守卫体量类比估固定成本，**b 侧实做 2 个样本外推**」。
但能产出 b 侧样本的是 `shipswift-effects` 的 A-6，而 effects 整个 epic **依赖 A0-1 完成**
⇒ **做裁决所需的样本，要等裁决做完才能立项**（Copilot structure 评审 Critical 2）。

**打破方式**：**2 个 b 侧样本作为 A0-1 内部的一个子步骤**，明确它
**不受 A0-2 骨架限制**——在 scratch / 临时分支上按登记表路线走完 2 个样本，只为产出
成本数字，**产物不进主线**。⇒ 环被打破：A0-1 自足，不依赖 A0-2 / Epic A。

⚠️ **样本必须取自 P 的定义域**（第 2 轮评审 I-2，初版选错了）：初版写"取 `RadarChart`
与 Effects 的一个 modifier"，但 ① `RadarChart` 属 Charts，而 **P 不算 Charts**；
② Effects 的 modifier 形态是 `internal struct + public extension View`，按 AD-2
**明文排除登记** ⇒ 拿一个在 b 路线下**零登记成本**的东西去测 b 的成本，外推出的
`P × 单价` 失真，而这个数字**同时喂 AD-4 与 A0-6 的 `N_B`**。
⇒ **两个样本改为**：Effects 的一个 **public View struct**（`Confetti` / `ScanningOverlay`
之一）+ 一个 **public ViewModifier struct**（模拟 AD-E 为 layerEffect 钉死的形态），
覆盖 P 里真实存在的两种类型形态。
⚠️ **AD-4 已裁 Charts 走 b**（该半不依赖成本模型，理由是定性的）⇒ `shipswift-effects` A-6 要为 4 个图表写判定法 notes；
样本产物虽不进主线，其 **notes 与步骤 2 的业界举证可被 A-6 复用**，省一次返工（评审 S-9）。

### AD-D 测试拓扑与 CI scheme 是同一个 commit 的事

新 target 各建独立测试 target，CI iOS 腿改 `-scheme CoreDesign-Package`。
⚠️ 本仓当前 `xcodebuild -list` 只有一个 scheme `CoreDesign`；新增 product 后
`xcodebuild test -scheme CoreDesign` 会**硬红**（`not currently configured for the test
action`）⇒ 改 manifest 与切 scheme 必须同 commit。
⚠️ **新测试 target 必须各带至少一条 smoke 测试**（评审 Suggestion）——空 target 下
`xcodebuild test` 跑的仍只是 `CoreDesignTests`，证明不了新 target 被纳入。

### AD-E 守卫根 fail-closed，且新守卫不得在空目录上空真

守卫的扫描根列表**只含当下已存在的 target**，每个根断言目录存在。
⚠️ **仅断言"目录存在"挡不住假绿**（评审 I-7）：A0-3 落地时两个新根是**空目录**，
`EffectsColorLiteralGuard` / `ChromeTextLiteralGuard` 在 0 个文件上必绿。
⇒ **每条新守卫必须附带一个会触发红的 fixture**（或临时植入违规文件实跑一次并留证）。

### AD-F A0-4 在本 epic 只能做接线，实质调用点归 Epic A / B

`downstream-probe` 的价值是 **nonisolated 上下文的调用点**，但 A0-2 交付的是**空骨架
target**，没有任何公开值类型可调用（评审 I-1）。
⇒ **A0-4 交付 = probe manifest 接线（依赖两个新 product）+ 每 target 一个 nonisolated
文件的结构**；**实质调用点由 `shipswift-effects` A-7 与 `shipswift-shaders` **B-4** 各自补齐**。
⚠️ **是 B-4 不是 B-1**（#260 终审）：B-1 只建 target 骨架，那时没有任何 shader 类型可调，
与本条批评 A0-4 的问题同构。`shipswift-shaders` epic 已把它记在 B-4。

## Technical Approach

### Package / 构建（A0-2）

- `Package.swift`：+2 target +2 product（Effects / Charts），`swiftSettings` 与
  `CoreDesign` 一致（`.defaultIsolation(MainActor.self)`、`swiftLanguageModes: [.v6]`）。
- `.github/workflows/ci.yml`：iOS 腿 `-scheme CoreDesign` → `-scheme CoreDesign-Package`。
- `App/project.yml`：`dependencies` 逐条补 `product:`（当前 `:34` 未指定，默认只链 `CoreDesign`）。
- **CLAUDE.md / AGENTS.md 同步**（评审 Suggestion）——两个新 target 进架构节是本 task
  那个 commit 的事，否则 `AgentGuideSyncGuard` 判红。
- **`ColorAssetGuardTests` 一句话定案**（Copilot 🟡6）：Effects / Charts 颜色全走 CoreDesign
  语义 token，**不带独立 `.xcassets` ⇒ 不纳入**；若实现期发现需要，则纳入并回改本条。
- ⚠️ **改 `App/project.yml` 后不要在 worktree 里跑 `xcodegen generate`**（PRD C-4 /
  本仓 CLAUDE.md 均点名，评审 S-5）：会把 local package 的 `name` 按当前目录名写死并
  清空 `xcshareddata/xcschemes/CoreDesignPreview.xcscheme`。`shipswift-shaders` B-1 同此。

### 守卫（A0-3）

| 守卫 | 动作 |
|---|---|
| `BoolExemptionGuard` / `BoolParameterScanner` | 扫描根 `:43` 单根 → 多根列表；台账键加 target 前缀 |
| `AccessibilityStringLiteralGuard` | `:189` 同上；按 target 分辨各自的 `.module` |
| `EffectsColorLiteralGuard`（新建） | 禁色相字面量；射程仅新 target；**带触发红的 fixture** |
| `ChromeTextLiteralGuard`（新建） | 扫 `Text("…")` / `Label("…"` 裸字面量（公约 A 类）；射程仅新 target，**不回溯 CoreDesign**；**带 fixture** |
| ~~**差集守卫**~~ | ⚠️ **不交付**——AD-4 第 6 轮收敛为「AD-2 原样适用」，无轻公约 ⇒ 无差集守卫。（原文：AD-4 对 Effects/Shaders 暂定 a ⇒ 本 task 交付它（⚠️ 是**暂定**不是已裁定：AD-4 自陈其成本模型有四条缺口，任意两条叠加即翻到 b，故同时立了**复判闸**——本 task 须交付 `bSideNotesChars` 字段与「前两条非空」断言，见 AD-4《复判闸》）——形态**已裁定为独立 `docs/effects-registry.json` 双向差集**；射程 = public `View`/`ViewModifier`；`transition`/`modifier` 走**扩展成员扫描器**、登记进同一份 `effects-registry.json` 的 `entryPoints` 数组（⚠️ **AD-4 已裁：形态取 JSON 双向差集，且否决"手工维护 + 盲区台账"**，随 #244 回改）。不交付它 ⇒ Effects 的登记面就是 PRD 说的"无守卫空白地带"，且 Epic 成本少算一条 |
| `NFR-4` grep 断言 | 零 `@unchecked Sendable`。⚠️ **根列表与上面四条守卫同源，只含已存在的 target**（第 2 轮评审 I-1）——初版写"三个新 target"，但 A0-3 落地时只存在两个；对不存在的 `Sources/CoreDesignShaders/` 做 grep 无命中即绿，正是 AD-E 自己反对的 fail-open |

⚠️ `ComponentTextParamGuard` **只能守 B 类**，且定义域是登记表条目。它**守不到** FR-7 的
A 类 chrome 文案——公约 G-4（`:1017`）明载 A 类连 CoreDesign 自己都无机器判据。
⚠️ 它的**扩展与 FR-7 边界编码归 `shipswift-effects` A-6**（评审 I-8），不在本 task。

⚠️ `TouchTargetTests` **结构上不适用**（`:3` `@testable import CoreDesign`、`:57` 整 suite
`#if os(iOS)`）。往里加 `BeforeAfterSlider` 会让 `CoreDesignTests` 依赖图含新 target，
**违反 NFR-5②**（评审 I-4）⇒ 本 epic 不动它；两个真交互件的触控目标测试由 Epic A / B
在**各自的独立测试 target** 里同形态实现。

### 两闸

**A0-5 — D-1 Metal 打包 spike（六问）**：构建系统选型（α/β）/ CI 改法 / metallib 定位 /
多色参数化 / layer 输入（须取 7 个"颜色写死"件之一）/ 分平台 metallib。
⚠️ 已知：**原生 `swift build` 不编译 `.metal`**；只有 `--build-system swiftbuild` 与
`xcodebuild` 会。而 CI SwiftPM 腿、`downstream-probe`、下游 StoryUI CI 用的都是原生构建
⇒ **路径 β 是默认走向**。

**A0-6 — C-6 许可核验**：落 `docs/shader-provenance.md` 正向裁定表
（`shader | 原始出处 | 许可 | 证据链接 | 裁定`，裁定仅三种）。
⚠️ 上游只标注 7/28 个来源，且那 7 个的**传递来源**上游没说，**不得当作预先通过**。

## Implementation Strategy

- **A0-1 自足**（AD-C 打破了自举环），阻塞 A0-3。
- **A0-2 无依赖**（评审 I-2：初版写"A0-1 阻塞 A0-2 的一部分"，但 A0-2 的内容
  ——manifest / CI scheme / project.yml——没有任何一项取决于 AD-4，该句已删）。
- **A0-5 / A0-6 的实验与填表可与 A0-1/A0-2 并行**；⚠️ **A0-6 的闸判定（≥ N_B）依赖
  A0-1（每 shader 边际成本口径）与 A0-5（固定成本）的结论** —— 表可并行填，判定必须等。
- 风险最高的是 A0-2：**唯一一个会让 CI 变红的 commit**（manifest + scheme 必须同步）。

## Task Breakdown Preview

```
A0-1  公约裁决 AD-4（含 2 个 b 侧样本 spike，仓外/临时分支，AD-C）   ← 无依赖
A0-2  两 target 骨架 + CI scheme 切换 + project.yml + AGENTS 同步      ← 无依赖
A0-3  守卫扩展与新建（含条件项：差集守卫）+ fixture + NFR-4 grep       ← 依赖 A0-1 + A0-2
A0-4  downstream-probe 接线与结构（实质调用点归 A/B，AD-F）            ← 依赖 A0-2
A0-5  D-1 Metal 打包 spike（六问，仓外做）        ← 无依赖  【Shaders 启动闸①】
A0-6  C-6 逐 shader 许可裁定表                    ← 填表无依赖；判定依赖 A0-1+A0-5【闸②】
```

6 个 task，落在本仓历史区间（5–13）内。A0-1 / A0-2 / A0-5 / A0-6 可四路并行起步。

## Dependencies

### 上游
- `shipswift-harvest` PRD（`f39e233`，4 轮评审 PASS）
- ShipSwift 本地 clone 快照（MIT）— A0-6 的核验对象之一

### 下游（本 epic 阻塞谁）
- `shipswift-effects`：依赖 A0-1 ~ A0-4
- `shipswift-shaders`：依赖 A0-2 ~ A0-6 **全部**（两闸只是启动条件）

### 连带影响（改 `Package.swift` 会打到的地方，均已挂 task）
`AgentGuideSyncGuard`（→ A0-2）· `App/project.yml:34`（→ A0-2）· `ColorAssetGuardTests`
（→ A0-2 定案不纳入）· `App/Sources/ComponentData.swift`（→ Epic A 的 A-7 串行）·
`scripts/run-snapshots.sh`（→ A-7 / B-4 排除策略）· `ComponentRegistryGuard.swift:449-451`
（→ Epic A 的 A-6，仅 Charts 走 b 时）· `docs/bool-exemptions-baseline.json` 32/35
（→ A0-3 多根化，基线值不变）· `docs/README.md` 索引（→ A0-1 定落点、A-7 / B-4 执行）·
`ReachableTypeRegistryGuard`（→ A-7 与 B-4）

## Success Criteria (Technical)

### A0-1
- [ ] AD-4 裁决落盘，**按 target** 给出结论
- [ ] 成本估算：a 侧按既有守卫体量类比（`AccessibilityStringLiteralGuard` 16KB /
      `BoolParameterScanner` 68KB），b 侧**实做 2 个样本外推**（AD-C：仓外做，产物不进主线），
      P 只算 Effects + Shaders
- [ ] AD-4 一并拍板**四件**下游要用的事（第四件是扫描根作用域，随 #244 追加）（评审 Suggestion）：① 独立 JSON vs 锚文档；
      ② `transition`/`modifier` 的处置（⚠️ **AD-4 拍板二已裁：走扩展成员扫描器，
      否决"手工维护 + 盲区台账"**——本行原只列了被否决的那一个选项，随 #244 回改）；
      ③ **FR-17 的 README 索引落点**（AD-4 拍板三已裁：按 target 分叉）
      （主索引 vs `## 生成预览图` 之后另起小节）——A-7 / B-4 写文档时要依据它

### A0-2
- [ ] CI 四条腿全绿，且**实测确认 iOS 腿的新 scheme 真的在跑新测试 target**
      （`xcodebuild -list` 输出 + `xcodebuild test` 实跑 + **每个新测试 target 至少一条
      smoke 测试**，三者留证）
- [ ] `swift build --target CoreDesign` 独立绿
- [ ] `swift package describe --type json | jq '.targets[] | select(.name=="CoreDesignTests") | .target_dependencies'`
      恰为 `["CoreDesign"]`（NFR-5②）
- [ ] `swift package describe --type json | jq '.targets[] | select(.name=="CoreDesign") | .target_dependencies'`
      恰为 `[]`（FR-1 反向依赖禁令的机器判据，评审 Suggestion）
- [ ] `CoreDesign` 公开 API 表面 diff 为空 —— ⚠️ **须钉一个工具**（评审 S-7）：
      `swift-api-digester` 或 symbol dump diff；`downstream-probe` 只能证"还能编"，
      证不了"没多没少"
- [ ] CLAUDE.md / AGENTS.md 已同步，`AgentGuideSyncGuard` 绿
- [ ] `ColorAssetGuardTests` 的纳入与否已定案并写进 epic

### A0-3
- [ ] 四条守卫的根列表覆盖两个已存在的新 target，每根断言目录存在（fail-closed）
- [ ] **每条新守卫附带会触发红的 fixture**，或临时植入违规文件实跑一次并留证
      （防空目录空真，AD-E）
- [ ] **既有 CoreDesign 判据字面不变**（FR-10）：`bool-exemptions-baseline.json` 的
      32 / 35、`ComponentTextParamGuard` 的 `== 31`、`ComponentRegistryGuard` 的 47 / 25
      逐字不变，重构未放松任何现有断言
- [ ] **已存在的**新 target 零 `@unchecked Sendable`（grep 断言；根列表与守卫同源，
      Shaders 根由 B-1 加入）
- [ ] ~~差集守卫~~ **不交付**（AD-4 第 6 轮：AD-2 原样适用，无轻公约）；复判闸随成本模型一并撤回

### A0-4
- [ ] probe manifest 接上两个新 product，每 target 一个 nonisolated 文件的结构已建
- [ ] `cd scripts/downstream-probe && swift build` 绿
- [ ] epic 内明写：实质调用点归 **A-7**（Effects/Charts）与 **B-4**（Shaders）
      ⚠️ **不是 B-1** —— B-1 那时还没有 shader 类型可调

### A0-5【闸①】
- [ ] D-1 **六问**全部有书面结论，α/β 已选定
- [ ] **四个可预见失败模式**各有结论（评审 I-3）：工具链耦合（`-std=` / `-mios-version-min`）、
      Mac Catalyst 误选、仓库体积、构建产物冗余
- [ ] **shader 加载测试的 fail-closed 形态已验证**，且已确认 macOS CI runner 是否有
      可用 Metal device。⚠️ **两个分支都要有结论**（第 2 轮评审 I-6，初版只要求"确认是否有"）：
      · **有** ⇒ 加载测试进 SwiftPM 腿，缺 device 即判红；
      · **无** ⇒ 加载测试**仅在 iOS Simulator 腿作数**，macOS 腿以**显式 skip + 留痕**
        处理（**不得**静默 `return`），并回改 `shipswift-shaders` AD-D 的 β 验证路径表
- [ ] **B-1 + B-4 的固定成本估算**已产出（`N_B` 的**分子**）
- [ ] **每 shader 的边际成本估算**已产出（`N_B` 的**分母**，评审 S-3）——spike 恰好做了
      1 个 `colorEffect` + 1 个 `layerEffect`，顺手记下两者的实际耗时
- [ ] spike 在仓外完成，仓内只留结论文档 + 可复用脚本（AD-A）

### A0-6【闸②】
- [ ] `docs/shader-provenance.md` 覆盖全部 28 个 shader，无空裁定
      （⚠️ 本条**归属 A0-6**；`shipswift-shaders` 的同名验收项是**启动前核验**，不是重复交付）
- [ ] `N_B` 已按经济性方法（B 固定成本 ÷ 每 shader 边际成本）反推出具体数字，**不取 7**
- [ ] **闸②的通过判定本身**（评审 S-10，此前只散落在别处）：可落地数 **≥ `N_B`** ⇒ 闸过，
      `shipswift-shaders` 可启动；**< `N_B`** ⇒ 闸不过，该 epic 整体不启动
- [ ] **`ACKNOWLEDGEMENTS.md` 的骨架由本 task 建**（评审 I-4）：本仓此前无此文件。
      ⚠️ **骨架 = 表头 + 说明 + 上游许可全文转载**；**逐 shader / 逐组件的条目由各自
      落地的 task 追加**（第 3 轮评审 Suggestion 5）——闸②若不过，ACK 不得署名仓内
      并不存在的 shader。与 `shipswift-shaders` SC「覆盖每一个**落地的** shader」对齐
- [ ] 那 7 个已知 MIT 件的**传递来源**已核（ShaderKit 是否又移植自 Shadertoy）
- [ ] **go/no-go 结论有 GitHub 侧落点**：在 A0-6 的 issue 关闭评论里固定记录
      "B 启动 / 不启动 + `N_B` 值 + 可落地 shader 名单"

## Estimated Effort

中等偏大。绝大部分工作量在 A0-1（公约裁决 + 2 个样本 spike，本仓从无"另立一份公约"先例）
与 A0-5（跨三种构建系统的 Metal spike）。A0-2 ~ A0-4 机械但高风险。

---

## structure 评审响应台账（第 1 轮）

| 评审项 | 处置 |
|---|---|
| **superpowers C-1（差集守卫无 task 归属）** | **接受**。初版把 PRD 的警告原样搬进来当成处置了——这正是评审说的"复述不是处置"。现挂 A0-3 为**条件项**，写明交付形态与射程，并进 A0-3 的 SC |
| **Copilot C-2（AD-4 裁决判据自举成环）** | **接受**，本轮最有价值的一条。b 侧要"实做 2 样本"，而能产样本的 Effects 又依赖 AD-4 完成。新增 AD-C：2 个样本作为 A0-1 内部子步骤，**仓外/临时分支做、产物不进主线** ⇒ A0-1 自足，环打破 |
| **superpowers C-2 / Copilot C-1（NFR-1 性能回归闸是孤儿）** | **接受**。三份 epic grep「性能/掉帧/frame-time」零命中属实。基准脚本归 `shipswift-effects` A-7（一次性基建），Effects / Shaders 的 SC 各加对应项 |
| **superpowers C-3（shaders 漏了对 effects 的真实依赖）** | **接受**。NFR-7 的可注入 environment 键落 `CoreDesignEffects`（正是 FR-1 允许 Shaders→Effects 单向依赖的用途），B-2 依赖 A-3；`ComponentData.swift` 的跨 epic 串行窗口依赖 A-7。已写进 shaders 的 Dependencies |
| I-1（A0-4 在 foundation 阶段是空的） | **接受**。新增 AD-F：A0-4 只做接线 + 结构，实质调用点归 A-7 与 B-1，两处 SC 都加（⚠️ **Shaders 侧后于 #260 改为 B-4**——B-1 那时只有 target 骨架、无 shader 类型可调；正文 AD-F 已更新，本行为历史记录） |
| I-2（A0-2 依赖描述自相矛盾） | **接受**。删掉"A0-1 阻塞 A0-2 的一部分"——A0-2 的三项内容确实无一取决于 AD-4 |
| I-3（A0-5 验收窄于下游期待） | **接受**。A0-5 的 SC 补三项：四个失败模式、fail-closed + macOS runner 有无 Metal device、B-1+B-4 固定成本估算 |
| I-4（TouchTarget 处置撞 NFR-5②） | **接受**，且评审说得对：往 `TouchTargetTests` 加 `BeforeAfterSlider` 会让 `CoreDesignTests` 依赖新 target，把 A0-2 那条 `jq` 判据判红。改为两件交互件在**各自独立测试 target** 里同形态实现 |
| I-5（ACKNOWLEDGEMENTS 新建归属不清） | **接受**。Effects 借的是 ShipSwift 的算法，MIT 本身要求署名，与 B 是否启动无关 ⇒ **A-7 新建**，B-4 改为**追加逐 shader 条目** |
| I-6（FR-13 装饰层 a11y 分工无人接） | **接受**，落 effects epic |
| I-7（FR-10 判据不变无验收 + 新守卫空目录空真） | **接受**，两条都进 A0-3 的 SC；空真那条正是本仓反复堵的假绿病型，加 fixture 要求 |
| I-8（`ComponentTextParamGuard` 扩展 + FR-7 边界无人负责） | **接受**，归 `shipswift-effects` A-6（与 `47→51` 同一处） |
| Copilot 🟡3（Bool 纪律在 shaders 缺席） | **接受**，落 shaders epic + 预算分配 |
| Copilot 🟡4（reachable-type 登记 Effects 未认领） | **接受**，A-7 与 B-4 各认领 |
| Copilot 🟡5（README 索引落点只覆盖 b 分支） | **接受**。落点由 **A0-1 拍板**，A-7 / B-4 执行 |
| Copilot 🟡6（`ColorAssetGuardTests` 无人回应） | **接受**，A0-2 一句话定案"不纳入"，附回改条件 |
| Suggestion（A0-1 交付物 / AGENTS 同步 / smoke 测试 / Bool 预算 / FR-1 机器判据 / NFR-5② 下游沿用 / US-1·US-4 验收 / NFR-4 grep / spike 落点 / shaders decompose 触发条件） | **全部接受**，分别落各 epic |
| Preference（两闸 go/no-go 的 GitHub 落点） | **接受**，A0-6 的 SC 末条 |
