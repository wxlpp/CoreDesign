---
issue: 92
started: 2026-07-19T07:16:54Z
last_sync: 2026-07-19T15:04:53Z
completion: 100%
---

# Issue #92 完成记录

承载 5 个审计项：C1、C7a、C7b、C9a、C9b，全部标记为已修复。

## defaultIsolation fallout 修复清单

### 库内编译 fallout（计划预期的 2 处）

| 文件 | 改动 | 在 #6 删除名单？ |
|---|---|---|
| `Tokens/CoreSpacing.swift` | 加 `nonisolated` | 否 |
| `Tokens/CoreRadius.swift` | 加 `nonisolated` | 否 |

两处均为 `Layout` / `InsettableShape` 的 nonisolated 协议要求引用 token 常量所致。

### 公开 API 契约 fallout（计划**未预期**，checkpoint 评审发现）

计划的 fallout 分析只测了库内编译错误。但 `defaultIsolation` 是**声明签名的一部分**，它同时改变了下游消费者的契约——从 nonisolated 上下文使用公开值类型会编译失败（实测 10 个 error）。

| 文件 | 类型 | 理由 |
|---|---|---|
| `Tokens/CoreBorderWidth.swift` | `CoreBorderWidth` | 纯 CGFloat 常量 |
| `Modifier/SurfaceModifier.swift` | `SurfaceKind` | 无 payload 枚举 |
| `Components/StatusRow/StatusRow.swift` | `StatusResult` | 无 payload 枚举 |
| `Components/StateLabel/StateLabel.swift` | `StateLabelStyle` | 无 payload 枚举 |
| `Components/Badge/Badge.swift` | `BadgeVariant` | 无 payload 枚举 |
| `Components/Toast/Toast.swift` | `ToastLevel` | 无 payload 枚举 |
| `Components/Toast/Toast.swift` | `ToastItem` | UUID / String / ToastLevel / TimeInterval |
| `Components/Toast/Toast.swift` | `ToastDefaults` | `ToastItem.init` 默认参数的级联要求 |
| `Tokens/CoreElevation.swift` | `CoreElevation.Level` | 无 payload 枚举 |

**判定边界**：显式声明 `Sendable` 的公开类型 = 作者有意让它跨 actor 使用，必须 nonisolated。

`ToastItem` 是最能说明问题的一例——它的文档注释写着「可在跨 actor 边界传递（譬如 `await MainActor.run { host.show(item) }`）」，而那正是下游当时编译不过的用法；`Sendable` 声明形同虚设。

### 保持隔离的类型

`CoreElevation`（含 `Spec`）、`CoreTypography`、`CoreButtonMetrics`、`CoreControlMetrics` 未标 `nonisolated`——它们持有 `Color` / `Font`，SwiftUI 类型本身是 MainActor 隔离的，强标会产生 17 个 error。边界是技术性的，不是「改多少算克制」。

## 新增回归防线：`scripts/downstream-probe/`

上述公开 API 回归之所以能溜进来，根因是**结构性**的：四条 SwiftPM 命令、`xcodebuild test`、warning 判据全都跑在被隔离的 target *内部*，没有任何一处能看见下游视角。

新增的 probe 包从 `nonisolated` 函数使用全部公开值类型，已纳入 CI。反向验证过它有效：故意把 `BadgeVariant` 退回去 → probe 立刻报错；还原 → 转绿。

后续任何涉及隔离标注的改动（`#4` 改 `CoreTypography`、`#10` 改 `CoreControlMetrics`）都应保持它绿。

## CI 结论

**级别 1，无降级**。详见 `ci-decision.md`。

- runner `macos-26`：macOS 26.4 / Xcode 26.5 / iOS 26 runtime（26.2、26.4、26.5）/ iPhone 17 Pro 全部具备
- 4 个 job 全绿：SwiftPM ×2 trait 模式、iOS Simulator、下游 API probe
- **`#4` 的布局断言层有自动化守护** ✅

## 遗留给下游 Issue 的输入

| 给谁 | 内容 |
|---|---|
| `#4` | 布局断言层有 CI 守护；simulator job 的 skip 列表勿误伤新增的 `#if os(iOS)` 测试 |
| `#7` | `ToastHostTests` 三个 timing 用例在 CI 上**稳定失败**（非偶发），已在 simulator job 跳过；加大 buffer 或注入 `Clock` 归 #7 |
| `#7` | Blossom 断言的「asset 名 → Contents.json」路径只在 `swift test` 下成立；xcodebuild 下资源被编译成 `Assets.car`，原始目录不存在（但 `Color.resolve` 在那边可用） |
| 全体 | 本仓库现在要求 **xcodegen ≥ 2.46.0**；任何 `xcodegen generate` 之后须 `git checkout -- App/CoreDesignPreview.xcodeproj/xcshareddata/` 恢复 shared scheme |

## 未达成项

无。5 个审计项全部达成，计划中的降级路径（C7b 保持字符串形式、C9b 记录不修、CI 降级为 pre-push）均未触发。
