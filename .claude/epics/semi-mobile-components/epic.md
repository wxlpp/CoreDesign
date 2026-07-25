---
name: semi-mobile-components
status: backlog
created: 2026-07-25T08:25:36Z
updated: 2026-07-25T08:25:36Z
progress: 0%
prd: .claude/prds/semi-mobile-components.md
github: (will be set on sync)
---

# Epic: semi-mobile-components

## Overview

以 Semi Design 能力集为参照，为 CoreDesign 补齐 **10 个移动端友好的通用组件 + 1 个增强包**，实现方式对齐 Apple HIG / SwiftUI 惯例（借鉴能力，非移植 Web 视觉）。所有交付物纯新增、彼此独立、大量复用现有地基（`StarShape` / `FlowLayout` / glass modifier / `InsetGroupedSection` / `.redacted` / `LabeledContentStyle` / 第 3-4 层色层与 token），因此可高度并行。整体分三阶段：**Phase 0 共享地基先行 → 10 组件并行 → Phase 3 收尾串行**，以规避并行 Issue 抢改共享文件（色层 / `docs/README.md` / `App/Sources/Previews.swift`）。

交付物：Skeleton · Steps · Timeline · Rating · PinCode · Radio · TagInput · Descriptions · FloatButton · Carousel · ProgressIndicator 增强(+`spinning(_:)` modifier)。

## Architecture Decisions

- **形态优先级（承 PRD FR-4）**：能复用系统 style 协议的走协议（Descriptions → `.core LabeledContentStyle` + `InsetGroupedSection` 分组）；能用原生 modifier 达成的做成 modifier（Skeleton = `.redacted(.placeholder)` + shimmer 叠加；Spin 能力 = `spinning(_:)` 遮罩 modifier）；否则才是独立 `Components/<Name>/` 组件。这条决定了每个交付物的文件落点与是否新造类型。
- **色彩单一来源**：仅取第 3-4 层语义 token；占位底色复用 `FillColors`（systemFill 家族），连线/分隔复用 `BorderColors`/separator；仅 shimmer 高亮预计需 1 个新增语义 token，在 Phase 0 定案。
- **强调色走 `.tint`**（FR-3），唯一例外 FR-3a：包装系统 `ProgressView` 的文件（ProgressIndicator 增强）必须显式 `.tint(Color.accent)`，SC-5 静态核对对该文件豁免。
- **双端单一实现**（NFR-2）：不留单端公开符号。Carousel 统一 `ScrollView(.horizontal)` + `.scrollTargetBehavior(.paging)` + `scrollPosition(_:)`（不用 iOS-only `TabView(.page)`）；PinCode 的 `keyboardType`/`.oneTimeCode` 以 `#if os(iOS)` 包裹、macOS 走等价 TextField。
- **无破坏性**（NFR-6）：ProgressIndicator 增强以新增带文案参数的 init/重载、保留现有 `init()` 实现，不改现有签名。
- **分支拓扑**：`epic/semi-mobile-components`（off main）为集成分支；每个 Issue 经 `using-git-worktrees` 在其上开私有 worktree+分支，PR base = `epic/semi-mobile-components`；epic→main 待所有 Issue PR 合入后单独做（唯一硬停点）。

## Technical Approach

### Frontend Components（本库为纯 SwiftUI UI 库，无 Backend / Infrastructure）

按形态分三类：

**A. 独立组件（`Sources/CoreDesign/Components/<Name>/<Name>.swift`）**
- **Skeleton**：`.redacted(.placeholder)` 基座 + shimmer 叠加 modifier；line/rect/circle 形状可组合；`isLoading` 切换真实内容。
- **Steps**：横/纵、点状/数字；完成+当前走 `.tint`，错误态走 `StatusColors`；可选标题+描述。
- **Timeline**：纵向节点+连线+节点状态色；自定义节点与右侧内容。
- **Rating**：`Binding<Double>`；星数可配、只读、半星(0.5 步进)；复用 `StarShape`；`.tint` 取色；accessibility adjustable。
- **PinCode**：`Binding<String>`；固定格数；`isSecure` 掩码可配(默认关)；iOS `.textContentType(.oneTimeCode)`+`.keyboardType(.numberPad)`（`#if os(iOS)`）；填满回调。
- **Radio**：单选组 `Binding<Selection>`；水平/垂直；与既有 `CheckBox` 视觉成对（既有非 HIG 先例延续）。
- **TagInput**：`Binding<[String]>`；增删 token；复用 `FlowLayout`。
- **FloatButton**：图标(+可选文字)；复用 glass 按钮形态；调用方自定位（文档给 `.safeAreaBar`/`BottomInputBar` 取舍边界）。
- **Carousel**：跨端 paging（见 Architecture）；自动轮播(可关，`.task`/异步序列驱动)+页点指示+手势。

**B. style 协议扩展**
- **Descriptions**：`.core LabeledContentStyle` + `InsetGroupedSection` 分组；1/2 列（大字号下塌 1 列）；分隔密度。

**C. 增强 + modifier**
- **ProgressIndicator 增强**：新增带可选文案参数的 init/重载（FR-3a 例外）。
- **`spinning(_:)`**：`Modifier/SpinningModifier.swift`，`View.spinning(_ isActive:text:)` 加载遮罩。

### 每个交付物统一收尾（承 FR-1/5/6/7/8/9）
public 导出 → `bundle:.module` 资源 → 同文件 `#Preview`（Light/Dark 或状态画廊）→ Swift Testing 覆盖受控/格式化逻辑 → `docs/components/<name>.md`。

## Implementation Strategy

- **Phase 0（先行，阻塞后续）**：落地共享 token/辅助——占位/连线取色定案、必要的 shimmer 高亮 token（若 assumption 不成立则补齐）、给 `scripts/run-snapshots.sh` 加 `KEEP_LIBRARY_SNAPSHOTS=1` 保留开关（否则并行阶段视觉评审拿不到截图）。此 Issue 合入 `epic/` 后其余才启动。
- **Phase 1（并行）**：10 个组件各一 Issue，各自私有 worktree，互不改共享文件；各 Issue 内走 TDD（红→绿）；视觉评审用库内 `#Preview` snapshot 副产物（Phase 0 开关保留）逐 Issue 送 ios-visual-reviewer。
- **Phase 3（串行收尾）**：统一注册 `App/Sources/Previews.swift`、更新 `docs/README.md` 索引、宿主内 `run-preview.sh` 批量视觉复查（SC-6 整体判定）、Typography 墓碑文档、版本/BREAKING-CHANGES 收尾（纯新增，非破坏）。
- 每个 Issue PR base = `epic/`，走 auto-fix-pr 闭环；全 auto 流转，仅 epic→main 停下确认。

## Task Breakdown Preview

> 共 **12 个任务**，刻意超出 ccpm「≤10」软约束：10 个组件是 PRD 明确的独立并行单元，捆绑会牺牲并行度并制造 worktree/文件冲突，与 PRD 的并行设计相悖；故只在首尾各加 1 个阶段性任务，中间保持 1 组件 = 1 任务。

- **[Phase 0] 001 共享地基**：占位/连线取色定案 + shimmer token（按需）+ `run-snapshots.sh` 保留开关 + 建 `epic/` 分支。（阻塞后续）
- **[Phase 1 并行] 002 Skeleton** — `.redacted`+shimmer modifier + 形状画廊
- **[Phase 1 并行] 003 Steps** — 横/纵、点/数字、tint+状态色
- **[Phase 1 并行] 004 Timeline** — 节点+连线+状态色
- **[Phase 1 并行] 005 Rating** — 复用 StarShape、半星、只读
- **[Phase 1 并行] 006 PinCode** — OTP 分格、oneTimeCode、isSecure
- **[Phase 1 并行] 007 Radio** — 单选组、与 CheckBox 成对
- **[Phase 1 并行] 008 TagInput** — 复用 FlowLayout
- **[Phase 1 并行] 009 Descriptions** — `.core LabeledContentStyle`+InsetGrouped
- **[Phase 1 并行] 010 FloatButton** — glass FAB
- **[Phase 1 并行] 011 Carousel** — 跨端 paging + 自动轮播
- **[Phase 1 并行] 012 ProgressIndicator 增强 + `spinning(_:)`** — 吸收 Spin 能力
- **[Phase 3 串行] 收尾**：并入 001 的后续或独立收尾步——`Previews.swift` 注册 + `docs/README.md` 索引 + 宿主视觉复查 + Typography 墓碑 + 发版收尾。（decompose 阶段定为 013 或并入 001 尾）

## Dependencies

- **代码资产**：`StarShape`、`FlowLayout`、`FloatingGlassModifier` 及各 glass modifier、`ProgressIndicator`、`InsetGroupedSection`、`Form.swift`（LabeledContent 参照）、`CheckBox`（Radio 对偶）、`Colors/*`（含 `FillColors`/`BorderColors`）、`Tokens/*`、`Components/Style/*`。
- **验证基础设施**：`scripts/run-preview.sh`、`run-snapshots.sh`（Phase 0 加开关）、`downstream-probe`、`App/CoreDesignPreview.xcodeproj`、CI iOS Simulator + downstream-probe job。
- **阶段依赖**：Phase 1 全部 depends_on Phase 0（001）；Phase 3 收尾 depends_on 全部 Phase 1。
- **外部**：Semi Design 组件清单（能力参照，不引入代码/资源）。

## Success Criteria (Technical)

- 10 组件 + 增强包全部实现并 public 导出；`swift build`/`swift test` 全绿；CI iOS Simulator 腿 + downstream-probe 通过。
- 每个交付物 ≥1 `#Preview` 且预览宿主可渲染；每个有可测逻辑者 ≥1 `@Test`。
- 每个交付物一份 `docs/components/<name>.md` + `docs/README.md` 索引登记（收尾串行）。
- 静态核对：无第 1 层色相硬编码、无字面 `Color.accent`（FR-3a 例外：包装 ProgressView 的文件）。
- ios-visual-reviewer 对新组件「无 BLOCK」。
- 无破坏性：现有公开符号未改动/移除；downstream-probe 与预览宿主均可构建。

## Estimated Effort

- **Phase 0**：0.5–1 天（取色定案 + 脚本开关 + 分支）。
- **Phase 1**：10 组件并行，单组件约 0.5–1.5 天（Rating/Radio/FloatButton 偏低，Carousel/Timeline/PinCode 偏高）；并行墙钟约 2–3 天。
- **Phase 3**：0.5–1 天（注册 + 索引 + 复查 + 墓碑 + 发版）。
- **关键路径**：Phase 0 → 最慢组件 → Phase 3；并行下总墙钟约 3–5 天。
- **关键假设**：色层足够（仅 1 个 shimmer token），Phase 0 验证。
