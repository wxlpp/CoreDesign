---
name: shipswift-foundation
status: backlog
created: 2026-09-02T23:42:57Z
updated: 2026-09-02T23:42:57Z
progress: 0%
prd: .claude/prds/shipswift-harvest.md
github: (will be set on sync)
---

# Epic: shipswift-foundation（地基与两闸）

> `shipswift-harvest` PRD 拆出的**第 1 个** epic（共 3 个）。
> 姊妹 epic：`shipswift-effects`（效果与图表）、`shipswift-shaders`（Metal）。
> 命名沿用本仓先例 `coredesign-native-refresh` → `coredesign-native-foundation` /
> `coredesign-native-components`。

## Overview

本 epic **不落任何一个组件**，只做三件事：

1. **决定新代码归哪套公约管**（公约裁决 AD-4）；
2. **把两个新 target 与配套的守卫、CI、probe 立起来**；
3. **跑完两道闸**，为 `shipswift-shaders` 是否启动给出结论。

⇒ 它是另外两个 epic 的共同前置。抽出它的直接理由：初版方案把地基混在效果 epic 里，
导致该 epic 的 10 个 task 里有 4 个与交付物无关，密度超出本仓历史区间（5–13 task /
约 1 交付物每 task）。

## Architecture Decisions

### AD-A 三个 target，Shaders 不在本 epic 建

`CoreDesignEffects` / `CoreDesignCharts` 在本 epic 建；**`CoreDesignShaders` 归
`shipswift-shaders` 的 B-1**。若两闸任一不过，仓库里不会留下一个空 product 及其连带的
`App/project.yml` 条目、probe 调用点、README 索引小节。

### AD-B 公约作用域按 target 分别裁决（AD-4）

公约 AD-2（`docs/component-contract.md:1254-1274`）裁定 public `View`/`ViewModifier` 类型
照常进 `component-registry.json`，且未按 target 划作用域。本 epic 的第一个 task 是提交
**AD-4** 裁决，**必须允许按 target 分别裁**：

| target | 推荐走向 | 理由 |
|---|---|---|
| `CoreDesignCharts` | **b：进登记表** | 4 个图表是有形态选择的常规组件，判定法步骤 2 对它们真有内容 |
| `CoreDesignEffects` | **a：轻公约** | 微交互/转场没有"该长什么样"的 API 形态问题 |
| `CoreDesignShaders` | **a：轻公约** | 同上，且其存在取决于两闸 |

⚠️ 三 target 一刀切是**被否决的方案**——把雷达图和 `.shake(trigger:)` 划进同一套轻公约，
恰是在最需要判定法的地方绕开它。

### AD-C 测试拓扑与 CI scheme 是同一个 commit 的事

新 target 各建独立测试 target，CI iOS 腿改 `-scheme CoreDesign-Package`。
⚠️ **这不是可选优化**：本仓当前 `xcodebuild -list` 只有一个 scheme `CoreDesign`（单 product
时 Xcode 把包 scheme 合并进去）；新增 product 后 `xcodebuild test -scheme CoreDesign` 会
**硬红**（`Scheme CoreDesign is not currently configured for the test action`）。
⇒ 改 manifest 与切 scheme 必须同 commit。

### AD-D 守卫根 fail-closed

守卫的扫描根列表**只含当下已存在的 target**，且每个根断言目录存在。
`Sources/CoreDesignShaders/` 要到 B-1 才出现——对不存在的根静默跳过正是本仓反复堵的
「文件读不到 ⇒ 绿」病型。

## Technical Approach

### Package / 构建

- `Package.swift`：+2 target +2 product（Effects / Charts），`swiftSettings` 与
  `CoreDesign` 一致（`.defaultIsolation(MainActor.self)`、`swiftLanguageModes: [.v6]`）。
- `.github/workflows/ci.yml`：iOS 腿 `-scheme CoreDesign` → `-scheme CoreDesign-Package`
  （`-skip-testing:CoreDesignTests/ToastHostTests` 在包 scheme 下语法不变）。
- `App/project.yml`：`dependencies` 逐条补 `product:`（当前 `:34` 未指定 product，
  默认只链 `CoreDesign`）。

### 守卫

| 守卫 | 动作 |
|---|---|
| `BoolExemptionGuard` / `BoolParameterScanner` | 扫描根 `:43` 单根 → 多根列表；台账键加 target 前缀 |
| `AccessibilityStringLiteralGuard` | 扫描根 `:189` 同上；按 target 分辨各自的 `.module` |
| `EffectsColorLiteralGuard`（新建） | 禁色相字面量（`.cyan` / `Color(red:…)` / `.white.opacity(…)`）；射程仅新 target |
| `ChromeTextLiteralGuard`（新建） | 扫 `Text("…")` / `Label("…"` 裸字面量（公约 A 类）；射程仅新 target，**不回溯 CoreDesign** |
| 差集守卫（AD-4 选 a 时） | ⚠️ **须有明确 task 归属**，否则 Epic 成本少算一条 |

⚠️ `ComponentTextParamGuard` **只能守 B 类**（public init 的裸文本参数），且其定义域是
登记表条目。它**守不到** PRD FR-7 要求的 A 类 chrome 文案——公约 G-4（`:1017`）明载
A 类连 CoreDesign 自己都无机器判据。`ChromeTextLiteralGuard` 就是为此新建的。

⚠️ `TouchTargetTests` **结构上不适用**（手写交互组件清单 + 整 suite `#if os(iOS)`），
不列为本 epic 的验收项。

### probe

`scripts/downstream-probe` 补 **nonisolated 上下文**的调用点覆盖两个新 target 的公开值
类型。该 probe 的存在理由是「库自身的四条验证命令全跑在被隔离的 target 内部，结构上
不可能发现下游 nonisolated 代码用不了这些类型」（`downstream-probe/Package.swift:2-8`），
只加 import 不加调用点等于白加。

### 两闸

- **D-1 Metal 打包 spike（六问）**：构建系统选型（α/β）/ CI 改法 / metallib 定位 /
  多色参数化 / layer 输入（须取 7 个"颜色写死"件之一）/ 分平台 metallib。
  ⚠️ 已知事实：**原生 `swift build` 不编译 `.metal`**（报 unhandled file，不产 metallib）；
  只有 `--build-system swiftbuild` 与 `xcodebuild` 会。而 CI SwiftPM 腿、`downstream-probe`、
  下游 StoryUI CI 用的都是原生构建 ⇒ **路径 β（预编译 metallib 作二进制资源）是默认走向**。
- **C-6 许可核验**：落 `docs/shader-provenance.md` 正向裁定表（`shader | 原始出处 |
  许可 | 证据链接 | 裁定`，裁定仅三种：已追到兼容许可 / clean-room 重写 / 不落地）。
  ⚠️ 上游只标注了 7/28 个来源，且那 7 个的**传递来源**（ShaderKit 是否又移植自 Shadertoy）
  上游没说，**不得当作预先通过**。

## Implementation Strategy

- **A0-1（AD-4）阻塞 A0-3 与 A0-2 的一部分**（守卫形态、登记表侧是否要动都由它定），
  但 **A0-5 / A0-6 的实验与填表部分可与之并行**（不依赖 target 骨架）。
- ⚠️ **A0-6 的闸判定（≥ N_B）依赖 A0-1 与 A0-5 的结论** —— 表可并行填，判定必须等这两个。
- 风险最高的是 A0-2：它是**唯一一个会让 CI 变红的 commit**（manifest + scheme 必须同步）。

## Task Breakdown Preview

```
A0-1  公约裁决 AD-4                    ← 无依赖
A0-2  两 target 骨架 + CI scheme 切换   ← 无依赖（但与 A0-1 的结论有信息依赖）
A0-3  守卫扩展与新建                    ← 依赖 A0-1（形态）+ A0-2（根存在）
A0-4  downstream-probe nonisolated 扩展 ← 依赖 A0-2
A0-5  D-1 Metal 打包 spike（六问）      ← 无依赖  【Shaders 启动闸①】
A0-6  C-6 逐 shader 许可裁定表          ← 填表无依赖；判定依赖 A0-1 + A0-5  【闸②】
```

6 个 task，落在本仓历史区间（5–13）内。A0-1 / A0-2 / A0-5 / A0-6 可四路并行起步。

## Dependencies

### 上游
- `shipswift-harvest` PRD（`f39e233`，经 4 轮评审 PASS）
- ShipSwift 本地 clone 快照（MIT）— A0-6 的核验对象之一

### 下游（本 epic 阻塞谁）
- `shipswift-effects`：依赖 A0-1 ~ A0-4
- `shipswift-shaders`：依赖 A0-2 ~ A0-6 **全部**（两闸只是启动条件，B-1 另有对 target
  骨架 / 守卫根 / probe 的隐式依赖）

### 连带影响（改 `Package.swift` 会打到的地方）
`AgentGuideSyncGuard`（CLAUDE.md ⇄ AGENTS.md）· `App/project.yml:34` ·
`App/Sources/ComponentData.swift`（画廊，并行冲突面）· `scripts/run-snapshots.sh` +
`App/Tests/SnapshotTests.swift`（默认模式 `rm -rf docs/snapshots`）·
`ComponentRegistryGuard.swift:449-451`（`coredesign == 47` / `storyui == 25` 硬断言）·
`docs/bool-exemptions-baseline.json`（32 / 35）+ `scripts/bool-exemptions-ratchet.sh` ·
`ColorAssetGuardTests` · `docs/README.md` 索引（受 `readmeIndexReconcilesWithRegistry` 约束）·
`ReachableTypeRegistryGuard` / `docs/reachable-type-registry.json`

## Success Criteria (Technical)

- [ ] AD-4 裁决落盘，按 target 给出结论 + a/b 两侧的成本估算（a 按既有守卫体量类比，
      b 实做 2 样本外推，P 只算 Effects + Shaders）
- [ ] `swift build` / `swift test` / CI 四条腿全绿，且**实测确认 iOS 腿的新 scheme 真的在跑测试**
      （`xcodebuild -list` 输出 + `xcodebuild test` 实跑双留证）
- [ ] `swift build --target CoreDesign` 独立绿
- [ ] `swift package describe --type json | jq '.targets[] | select(.name=="CoreDesignTests") | .target_dependencies'`
      恰为 `["CoreDesign"]`
- [ ] `CoreDesign` 公开 API 表面 diff 为空
- [ ] 四条守卫的根列表覆盖两个已存在的新 target，且每根断言目录存在（fail-closed）
- [ ] `docs/shader-provenance.md` 覆盖全部 28 个 shader，无空裁定
- [ ] D-1 六问全部有书面结论，且 α/β 已选定

## Estimated Effort

中等偏大。绝大部分工作量在 A0-1（公约裁决，本仓从无"另立一份公约"先例）与
A0-5（跨三种构建系统的 Metal spike）。A0-2 ~ A0-4 是机械但高风险（一处漏改 CI 就红）。
