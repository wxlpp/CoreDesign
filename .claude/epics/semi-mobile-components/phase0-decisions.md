# Phase 0 共享地基决策（semi-mobile-components / Issue #161）

Phase 1（002–012）各并行 Issue 的取色与 accessibility 字符串**一律遵循本文件**，不再各自推导、不再改共享文件（`Colors/*`、`Localizable.strings`/`.stringsdict`）。并行期发现缺口 → 记入对应 Issue、暂用字面量+TODO，由 013（Phase 3）统一补登。

## 1. 取色决策

| 用途 | Token | 说明 |
|---|---|---|
| 骨架屏占位底色 | `Color.skeletonBase`（= `.fill` / systemFill） | 双端桥接、随外观/对比度更新；见 `FillColors.swift` 决策注释 |
| 骨架屏 shimmer 高光 | `Color.skeletonHighlight`（= `Color.fill.opacity(0.35)`） | 由底色经 `.opacity()` 派生；**暗色观感留 #162 视觉评审裁决**，必要时改 `Color.mix` 派生（token 可动，见 `FillColors.swift` Note） |
| 连线 / 分隔（Steps 连接线、Timeline 连线、Descriptions 行分隔） | `Color.dividerDefault`（separator 系统色，hairline 宽度） | 与既有 `Separator(inset:)` 同源；**不新造连线色**。需要更强对比时用 `BorderColors` 的 separator 族，不硬编码 |
| Steps/Timeline 强调（完成/当前） | `.tint`（FR-3） | 不写死 `Color.accent` |
| Steps/Timeline 错误态 | `StatusColors`（经 `StatusLevel.danger` 映射） | 状态色层，非 `.tint` |

**结论：全程不新增 colorset**——shimmer 走 `.opacity()` 派生、连线复用 `dividerDefault`，故免掉 `swift package clean`（NFR-5.2）与 `ColorAssetGuardTests` 登记两环。若 #162 暗色裁决后确需新 colorset，届时该 Issue 自行补这两环。

## 2. Accessibility 字符串策略

Phase 0 已 append-only 预登记以下键（`en.lproj/Localizable.strings` / `.stringsdict`）。Phase 1 组件**只消费、不新增**。

### 静态标签（`.strings`）
- `"Rating"` — Rating 组件 accessibilityLabel
- `"Verification code"` — PinCode 组件 accessibilityLabel
- `"Add tag"` — TagInput 输入框 label（删除按钮复用 `Tag` 既有 `"Remove tag"`）
- `"Info"` / `"Success"` / `"Warning"` / `"Error"` — Timeline 节点状态 label

### 计数复数（`.stringsdict`，one/other）
- `"%lld stars"` — Rating 满分/整数星数摘要（如「5 stars」）
- `"%lld steps"` — Steps 总步数摘要（如「4 steps」）

### 位置 / 数值播报（`.strings`，通用位置键）
- `"%@ of %@"` — **唯一的位置键**，两参数均为已格式化字符串，覆盖：
  - **Rating.accessibilityValue**：`String(localized: "\(value.formatted()) of \(total.formatted())", bundle: .module)` → 「2.5 of 5」。**半星精确播报**（`Double` 格式化，不取整），故不用整数键 `"%lld stars"` 表达值。
  - **Steps 当前步**：`String(localized: "\(current.formatted()) of \(total.formatted())", bundle: .module)` → 「2 of 4」。
  - **PinCode 格位**：`String(localized: "\(index.formatted()) of \(count.formatted())", bundle: .module)` → 「3 of 6」。

> **铁律：所有 `String(localized:)` / `Text(...)` 消费必须传 `bundle: .module`**（CLAUDE.md《资源加载》）。漏传 → 键在包资源里查不到 → 静默 fallback 到 key 自身格式，英文输出恰好一样（「2.5 of 5」）而测试/视觉评审都抓不到，直到非英文本地化才暴露。与 `Tag.swift:144` 既有用法一致。
>
> 位置键用 `String(localized:bundle:)` 消费（非复数，macOS/iOS 两端解析一致）；复数键（`one` 形态）经 `String(localized:)` 消费时仅在 iOS 腿正确套用——macOS 上 `String(localized:)` 不对 SwiftPM 资源 bundle 的 `.stringsdict` 套 `one` 规则（既有 `AvatarGroup` 的 `%lld more avatars` 同此），故 Phase 0 的复数回归测试改用 `Bundle.localizedString(forKey:)`+`String(format:)` 直验 bundle 内容（见 `SharedFoundationTests`）。
>
> **macOS 运行时复数缺口（未认领，交 013 收口）**：因本库 macOS 26+ 也是目标平台，上述缺陷若是 macOS **运行时**层面（非仅 `swift test`），则 macOS 端 VoiceOver 会读 “1 stars”。当前仅 `%lld stars`/`%lld steps` 两个**摘要**键受影响（值播报走 `%@ of %@` 非复数，不受影响）。若 013 确认 macOS 运行时 broken，消费侧改用 `Bundle.localizedString(forKey:)+String(format:)`（测试已示范）或接受 macOS 端语法降级。

### Timeline 节点状态映射
`StatusLevel.info/success/warning/danger` → label `"Info"/"Success"/"Warning"/"Error"`（`danger` 播报为 "Error"，比 "Danger" 对 VoiceOver 更清晰）。

## 3. 快照脚本

`scripts/run-snapshots.sh` 已加 `KEEP_LIBRARY_SNAPSHOTS=1`：keep 模式把所有 `#Preview` 产物渲染进 scratch 目录，**完全不碰** `docs/snapshots`——`git diff docs/snapshots` 无条件为空。scratch 默认目录为 **per-worktree**（`$TMPDIR/coredesign-library-snapshots-<worktree 目录名>`，每次运行前整目录清空），因此 10 个并行 Issue worktree **照抄默认配方即互不覆盖**——各 Issue 私有 worktree 目录名不同，导出目录自然隔离。Phase 1 各 Issue 视觉评审：直接 `KEEP_LIBRARY_SNAPSHOTS=1 scripts/run-snapshots.sh`，再从脚本回显的 scratch 路径取本组件 `CoreDesign_*.png` 交 ios-visual-reviewer；无需自定义 `LIBRARY_SNAPSHOTS_EXPORT_DIR`（该开关只接受 `0`/`1`，其他值报错退出以防误落破坏性默认分支）。
