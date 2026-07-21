# Issue #100 本地化 String Catalog — 完成记录

分支 `issue-100-l10n`（base `epic/coredesign-audit-remediation`）。承载审计项 **D2** 1 项（Size XS）。

## 做了什么

- 新增 `Sources/CoreDesign/Resources/en.lproj/Localizable.strings`（+`Localizable.stringsdict` 承载 `%lld more avatars` 复数；sourceLanguage=en，11 唯一 key，`Menu` 两处复用 → 13 调用点）。
- `Package.swift` 加 `defaultLocalization: "en"`（SPM 对含本地化资源的 target 硬性要求；未碰 #92 的 `swiftSettings`/`platforms`/`swiftLanguageModes`）。
- 4 处硬编码中文改英文：`BookCover` "未命名"→"Untitled"、`Toast` "点击关闭"→"Tap to dismiss"、`CoreMenuButton` "菜单"→"Menu"（可见 + a11y 复用同 key）。
- 4 处已英文串纳入 catalog（口径统一）：`ProgressIndicator` "Loading"、`ProgressBar` "Progress"（仅默认值；用户 label 保持 verbatim）、`Tag` "Remove tag"、`AvatarGroup` "%lld more avatars"（插值）。
- #99 扩入的 4 处英文 a11y 串纳入 catalog（兑现 D2 行 #99 指针）：`BottomInputBar` "Suggestions"/"Send"/"Stop"、`Form.DangerIcon` "Alert"（en 下仍念 "Alert"，#99 spoken-label 预期不变）。
- `AsyncButton` 的 `accessibilityValue(Text("Loading"))` 补 `bundle: .module`（复用 `Loading` key，消除与 `ProgressIndicator` 一文件之隔的口径不一致，评审 Suggestion 2）。共 **11 唯一 key / 13 调用点**。
- 各调用点按形态传 `bundle: .module`（`Text(key,bundle:)` / `accessibilityLabel(Text(...,bundle:))` / `accessibilityHint(...)` / `accessibilityValue(Text(...,bundle:))` / `String(localized:bundle:)`）。

## 关键：`.strings`/`.stringsdict` 而非 `.xcstrings`（wiring spike 裁决）

- 计划首选 `.xcstrings`（现代 String Catalog）。Task 1 的 throwaway wiring spike（探针 key≠值 `l10n.spike.probe`→`WIRED`，跑在 CoreDesign 模块内）**实证 `.xcstrings` 在 SwiftPM CLI 下不生效**：`swift build`/`swift test`（非 Xcode）不运行 String Catalog 编译器，`.xcstrings` 被逐字拷入 `CoreDesign_CoreDesign.bundle`，运行期 `String(localized:bundle:.module)` 找不到编译后的 `.strings` 而回落成 key（探针返回 "l10n.spike.probe"）。这是 CLAUDE.md 记录的 #98 `.xcassets` 不编译成 `.car` 的同类坑。
- 按计划 Task 1 Step 4 的 fallback 改用传统 `Resources/en.lproj/Localizable.strings`（+`.stringsdict` 承载复数），重跑 spike **PASS**（探针 → "WIRED"，插值 → "2 more avatars"）。CLI 工具链把 `.lproj/.strings` 作为运行期格式直接解析。已删除探针源 + spike 测试。
- 组件侧调用代码（`String(localized:bundle:)` / `Text(key,bundle:)`）与 catalog 格式无关，两种格式写法一致，故 Task 2/3 未受影响。

## 验证

- 四条命令冷跑（clean 后）全绿零 warning：`swift build`（EXIT 0，warnings 0）/ `swift test`（95 tests PASS）/ `swift build --traits Blossom`（EXIT 0，warnings 0）/ `swift test --traits Blossom`（95 tests PASS）。
- 中文判据 A（`"未命名"|"点击关闭"|"菜单"` 引号形式）清零（rc=1）；判据 B 残余中文全为 `#Preview` 演示数据 / 行尾注释（Tag:166,192、Toast:251、BookCover:215,219,284）；判据 C（9 处已英文串裸字面量 a11y label 及 value）清零（rc=1）。
- AvatarGroupTests 3 测试全绿（`overflowLabel(for:2)=="2 more avatars"` 未破）。
- 越界：反向自查 rc=1，改动仅限白名单文件；`Package.swift` 只多 `defaultLocalization: "en"` 一行。

## #99 指针兑现

- #99 曾在 D2 行加指针「L10n sweep 须一并纳入」并新增 4 处英文 a11y 串（`BottomInputBar` Suggestions/Send/Stop、`Form.DangerIcon` Alert）。主编排裁决扩范围，本任务已一并纳入 catalog——D2 标「已修复」名副其实，全库组件内部 UI 串口径一致。
