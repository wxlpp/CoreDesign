---
name: semi-mobile-components
status: backlog
created: 2026-07-25T08:25:36Z
updated: 2026-07-25T08:34:08Z
progress: 0%
prd: .claude/prds/semi-mobile-components.md
github: (will be set on sync)
---

# Epic: semi-mobile-components

## Overview

以 Semi Design 能力集为参照，为 CoreDesign 补齐 **10 个移动端友好的通用组件 + 1 个增强包**，实现方式对齐 Apple HIG / SwiftUI 惯例（借鉴能力，非移植 Web 视觉）。所有交付物纯新增、彼此独立、大量复用现有地基（`StarShape` / `FlowLayout` / `Tag(removable:)` / `CircularGlassButtonStyle` / glass modifier / `InsetGroupedSection` / `ProgressIndicator` / `.redacted` / `LabeledContentStyle` / `StatusLevel` / 第 3-4 层色层与 token），因此可高度并行。整体分三阶段：**Phase 0 共享地基先行 → 10 组件并行 → Phase 3 收尾串行**。

**并行共享冲突面（全部收到 Phase 0 预置或 Phase 3 串行，并行 Issue 一律不碰）**：色层文件、`docs/README.md`、`App/Sources/Previews.swift`、`App/Sources/ComponentData.swift`（宿主画廊 registry）、`Sources/CoreDesign/Resources/en.lproj/Localizable.strings`(+`.stringsdict`)（单一共享字符串表，含 accessibility label）、共享测试 suite `Tests/CoreDesignTests/TouchTargetTests.swift`（Issue #123，全交互组件 ≥44pt）与 `DynamicTypeLayoutTests.swift`。并行阶段各 Issue 只写自己的 `Components/<Name>/` 与 `Tests/CoreDesignTests/<Name>Tests.swift`。

交付物：Skeleton · Steps · Timeline · Rating · PinCode · Radio · TagInput · Descriptions · FloatButton · Carousel · ProgressIndicator 增强(+`spinning(_:)` modifier)。

## Architecture Decisions

- **形态优先级（承 PRD FR-4）**：能复用系统 style 协议的走协议（Descriptions → `.core LabeledContentStyle` + `InsetGroupedSection` 分组）；能用原生 modifier 达成的做成 modifier（Skeleton = `.redacted(.placeholder)` + shimmer 叠加；Spin 能力 = `spinning(_:)` 遮罩 modifier）；否则才是独立 `Components/<Name>/` 组件。这条决定了每个交付物的文件落点与是否新造类型。
- **色彩单一来源**：仅取第 3-4 层语义 token；占位底色复用 `FillColors`（systemFill 家族），连线/分隔复用 `BorderColors`/separator。**shimmer 高亮优先从 `FillColors` 派生**（`Color.mix(with:by:)`/`.opacity()`，承 accent 衍生态先例），力求**不新增 colorset**——若能派生则免掉 `swift package clean`(NFR-5.2) 与 `ColorAssetGuardTests` 登记两环；确需新 colorset 时，这两环列入 Phase 0(001) 交付物。
- **节点状态语义复用 `StatusLevel`**：Steps/Timeline 的节点态（完成/当前/错误）优先复用既有 `Components/StatusLevel.swift`（该枚举正是当年合并 Toast/Banner 各自重复状态枚举而来，见其 doc-comment）；两组件不得各自发明 `StepState`/`TimelineNodeState`。若确需新增共享状态枚举，归 Phase 0 定案，不在并行 Issue 里各造。
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
- **TagInput**：`Binding<[String]>`；增删 token；折行复用 `FlowLayout`，**chip 单元复用 `Tag(removable: true, onRemove:)`**（现成 44pt 命中区删除按钮 + `"Remove tag"` 本地化键），除非需中性 token 配色才自绘并写明理由。
- **FloatButton**：**净新增仅 extended 形态（图标+文字）+ 定位文档**；icon-only 情形直接封装/引导到既有 `CircularGlassButtonStyle`（其 doc 已声明服务「任何漂浮于内容之上的圆形 icon 按钮」），不重造 icon-only FAB；文档给 `.safeAreaBar`/`BottomInputBar` 取舍边界。
- **Carousel**：跨端 paging（见 Architecture）；自动轮播(可关，`.task`/异步序列驱动)+页点指示+手势。

**B. style 协议扩展**
- **Descriptions**：`.core LabeledContentStyle` + `InsetGroupedSection` 分组；1/2 列（大字号下塌 1 列）；分隔密度。

**C. 增强 + modifier**
- **ProgressIndicator 增强**：新增带可选文案参数的 init/重载（FR-3a 例外）。
- **`spinning(_:)`**：`Modifier/SpinningModifier.swift`，`View.spinning(_ isActive:text:)` 加载遮罩。

### 每个交付物统一收尾（承 FR-1/5/6/7/8/9）
public 导出 → `bundle:.module` 资源 → 同文件 `#Preview`（Light/Dark 或状态画廊）→ 各自 `Tests/CoreDesignTests/<Name>Tests.swift` 覆盖受控/格式化逻辑 → `docs/components/<name>.md`。**注意**：touch-target(≥44pt)/dynamic-type 断言归属共享 suite（`TouchTargetTests`/`DynamicTypeLayoutTests`），并行阶段**不**改这两个共享文件，汇入动作列为 Phase 3 收尾清单项。

## Implementation Strategy

- **Phase 0（先行，阻塞后续）**：落地共享地基——
  1. 占位/连线取色定案；shimmer 高亮**优先从 `FillColors` 派生**（免 colorset），确需 colorset 才补 `swift package clean` + `ColorAssetGuardTests` 登记；
  2. 若各组件 accessibility label/复数需入 `Localizable.strings`(+`.stringsdict`)：**在此预登记全部已枚举的键**（append-only），消除并行阶段抢改单一字符串表的冲突；
  3. 给 `scripts/run-snapshots.sh` 加 `KEEP_LIBRARY_SNAPSHOTS=1` 保留开关，并让保留模式把库内 `CoreDesign_*` 产物**导出到 scratch 目录而非 `docs/snapshots`**（该脚本开头 `rm -rf docs/snapshots`，避免并行 worktree 跑评审后误提交已提交的宿主 snapshot）；
  4. 建 `epic/semi-mobile-components` 分支。
  此 Issue 合入 `epic/` 后其余才启动。
- **Phase 1（并行）**：10 个组件各一 Issue，各自私有 worktree，只写自己的 `Components/<Name>/` 与 `<Name>Tests.swift`，不碰上述共享冲突面；各 Issue 内走 TDD（红→绿）；视觉评审用库内 `#Preview` snapshot 副产物（Phase 0 开关保留、导出到 scratch）逐 Issue 送 ios-visual-reviewer。
- **Phase 3（串行收尾，独立任务 013，depends_on 002–012）**：统一注册 `App/Sources/Previews.swift` **与 `App/Sources/ComponentData.swift`（`ComponentMeta.all` + `ComponentCategory` 归类，宿主画廊/detail 导航；两者均编辑既有已提交文件、不新增 App 源文件，不触发 xcodegen 盲区）**、把各组件 touch-target/dynamic-type 断言汇入共享 suite、更新 `docs/README.md` 索引、宿主内 `run-preview.sh` 批量视觉复查（SC-6 整体判定）、Typography 墓碑文档、版本/BREAKING-CHANGES 收尾（纯新增，非破坏）。
- 每个 Issue PR base = `epic/`，走 auto-fix-pr 闭环；全 auto 流转，仅 epic→main 停下确认。

## Task Breakdown Preview

> 共 **13 个任务**（1 前置 + 11 并行组件/增强 + 1 收尾），刻意超出 ccpm「≤10」软约束：10 组件 + 1 增强包是 PRD 明确的独立并行单元，捆绑会牺牲并行度并制造 worktree/共享文件冲突，与 PRD 的并行设计相悖；故只在首尾各加 1 个阶段性任务，中间保持 1 交付物 = 1 任务。

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
- **[Phase 3 串行] 013 收尾**（独立任务，depends_on 002–012；**不可并入 001**——001 是 Phase 1 的阻塞前置，同一任务不能既解锁 Phase 1 又在 Phase 1 全部完成后收尾，会成依赖环）：`Previews.swift` + `ComponentData.swift` 注册 + touch-target/dynamic-type 断言汇入共享 suite + `docs/README.md` 索引 + 宿主 `run-preview.sh` 视觉复查 + Typography 墓碑 + 发版/BREAKING-CHANGES 收尾。

## Dependencies

- **代码资产**：`StarShape`、`FlowLayout`、`Tag`（TagInput chip 复用 `removable:onRemove:`）、`CircularGlassButtonStyle`（FloatButton icon-only 复用）、`FloatingGlassModifier` 及各 glass modifier、`ProgressIndicator`、`StatusLevel`（Steps/Timeline 节点态复用）、`InsetGroupedSection`、`Form.swift`（LabeledContent 参照）、`CheckBox`（Radio 对偶）、`Colors/*`（含 `FillColors`/`BorderColors`）、`Tokens/*`、`Components/Style/*`。
- **共享文件（Phase 0 预置 / Phase 3 串行，并行不碰）**：`Resources/en.lproj/Localizable.strings`(+`.stringsdict`)、`Tests/CoreDesignTests/TouchTargetTests.swift`、`DynamicTypeLayoutTests.swift`、`App/Sources/Previews.swift`、`App/Sources/ComponentData.swift`、`docs/README.md`、`scripts/run-snapshots.sh`。
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
