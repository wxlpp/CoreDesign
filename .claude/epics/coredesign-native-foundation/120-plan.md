---
name: Task #120 实施计划
task: 120
created: 2026-07-22T00:00:00Z
---

# Task #120 实施计划：重铸语义色层与 accent 衍生族

## 范围（本任务负责的文件）

- `Sources/CoreDesign/Colors/*.swift`（`SurfaceColors` / `ContentColors` / `BorderColors` / `FillColors` /
  `InteractionColors` / `StatusColors` / `SystemBackgroundColors` 全量映射定案）
- `Sources/CoreDesign/Components/Button/ButtonRoleStyleRole.swift`（三态调色板随 `InteractionColors`
  改动自动生效；逐 role 校验四态可辨，必要时补测试而非改代码）
- 新增 `Tests/CoreDesignTests/ColorAssetGuardTests.swift`——前置任务：colorset 存在性守卫，
  复用 Issue #118 删除 `BlossomAssetTests` 前的 `FileManager` 模式并泛化到全部 colorset 组
- 新增一个 macOS 降级可见性验证测试（`windowBackgroundColor` vs `controlBackgroundColor` 在
  浅色/深色下确有可见差异）
- `Tests/CoreDesignTests/StatusColorsTests.swift`：仅在孤儿符号定案为「删除」时才改动；
  当前定案为「保留」，故预期不改

不触碰 `Sources/CoreDesign/Tokens/`（Issue #119 的范围）、不触碰 `docs/DESIGN-FOUNDATION.md`
（未创建——该文件按 epic 分工由 Task #126 建立，本任务只把取值理由写进
`InteractionColors.swift` 的文档注释 + 最终报告，供 #126 落盘时采用）。

## 步骤

1. **colorset 守卫测试先行**（AC 硬前置）。参考 `git show 5aa6998^:Tests/CoreDesignTests/CoreDesignTests.swift`
   的 `xcassetsURL()` / `colorsetExists()` 模式，泛化为扫描：`ColorGrade` 17 色相 × 10 阶、
   `canvas` 组（若改动后仍有残留 colorset）、`status` 组 24 个、`shadow` 组 4 个。
2. **SurfaceColors**：`surfaceCanvas` / `surfaceCanvasSubtle` / `surfaceCanvasInset` 由自定义
   `canvas-*` colorset 改指系统色（`systemGroupedBackground` / `secondarySystemGroupedBackground` /
   `tertiaryFill`）；`surfaceRaised` / `surfaceElevated` 由 plain 系统背景族切到 grouped 族，
   与新 `surfaceCanvas` 同族一致；其余 token 显式标注保持现值。随改动删除变孤儿的
   `Resources.xcassets/canvas/*` 三个 colorset。
3. **SystemBackgroundColors**：修 macOS 降级——`systemGroupedBackground` → `windowBackgroundColor`，
   `secondarySystemGroupedBackground` → `controlBackgroundColor`；`tertiarySystemGroupedBackground`
   保持 `controlBackgroundColor`（AC 只要求 canvas/raised 两档可辨，第三档无消费者、不强求）。
4. **ContentColors / BorderColors / FillColors**：逐项过一遍定案，多数已是系统色故标注保持现值；
   `borderSubtle` 的语义排列在 AC 原文里有歧义，记入最终报告供人工确认，不擅自套用可能导致
   语义倒挂的字面读法。
5. **InteractionColors**：`accent` → `Color.accentColor`；`accentHover/Pressed/Disabled/
   SubtleBackground` 改用 `Color.mix(with:by:in:)` / `.opacity()` 调制而非固定色阶；
   `secondaryAccent` / `neutralAccent` 族显式定案「保留」品牌色阶并写明理由；
   `selectionBackgroundEmphasis` 改指实心 `accent`（不再借道语义已变的 `accentDisabled`）。
6. **StatusColors**：`statusAccentEmphasis` + 6 个孤儿 `*Muted` / `statusDone*` 定案为「保留」
   （公开 API 面，理由记入报告），不改代码、不改测试。
7. **验证**：`swift build`、`swift test`（基线 75 tests / 21 suites 全绿 + 新增测试）、
   `cd scripts/downstream-probe && swift build`。改动 colorset 后先 `swift package clean`。

## 风险 / 待人工裁决

- AC 原文「`borderDefault` / `borderSubtle` → `separator` / `opaqueSeparator`」的字面顺序会让
  `borderSubtle` 比 `borderDefault` 更「重」，与现有 `borderStrong = .opaqueSeparator` 冲突、
  也与「subtle 应比 default 更弱」的直觉相悖。按语义而非字面顺序实现，最终报告中标出。
- `docs/DESIGN-FOUNDATION.md` 尚不存在，按 epic 分工由 #126 建立；本任务提供内容但不越权建文件。
