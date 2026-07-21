# Issue #98 测试质量重建 + Blossom 断言 — 完成记录

分支 `issue-98-test-quality`（base `epic/coredesign-audit-remediation`）。承载审计项 **C2 / C4a / C4b / C5** 共 4 项。**只碰 `Tests/` 与 `audit-checklist.md`，零 `Sources/` 改动**（`conflicts_with: []` 的保证，已由 Step 2 自查确认）。

## 做了什么

| 项 | 改动 |
|---|---|
| C4a | 新增 `BlossomColorDivergenceTests.swift`：断言 accent 的**真颜色值**随 trait 分流 |
| C2 | 五个恒真文件按「改写优先于删除，改写必反证」处置（详见下表） |
| C4b | `BlossomAssetTests` 扩展 `gradientDepColorsetsPresent`：覆盖 `violet-0…9` + `cyan-1` |
| C5 | 逐文件测试处置清单作为 C2 附录落盘到 `audit-checklist.md` |
| **顺带** | `CoreGradientTests` 的 `#expect(Bool(true))` 恒真占位改写为 CoreGradient trait 分流断言 |

## C2 五文件处置

| 文件 | 处置 | 关键 |
|---|---|---|
| `StatusColorsTests` | 改写为真断言 | 5 个 `let _: Color`（0 `#expect`）→ **24 条** asset 名断言（4 家族×5 含 border + done 4 无 border）；反证：篡改某 token asset 名即红 |
| `FloatingGlassModifierTests` | 改写为真断言 | `type(of:).isEmpty` 恒真 → `isInteractive` 默认值 + 透传契约；反证：改 init 默认/透传即红 |
| `SurfaceKindTests` | 断言瘦身（0 test） | 删三个恒真 `.count`；保留非-`@Test` 的 `static apiGuard`（误删 public case 即编译失败）。token 映射 private，Tests/ 不可断言 |
| `AvatarTests` | 删除 | `name==` 是 memberwise init 恒真；首字母/哈希色派生 body 内联不可断言 |
| `ProgressIndicatorTests` | 删除 | `_ = ProgressIndicator()` 0-expect；init 空、无暴露状态 |

## C4a 机制（swift test 下 asset 无法解析的绕行）

SwiftPM 不调 `actool`，`Color.accent.resolve()` 返回 `(0,0,0,0)`。故走：

1. `String(describing: Color.accent)` = `NamedColor(name: "brand-5", …)` → 正则取 asset 名。
2. 解析 `<group>/<name>.colorset/Contents.json` 第一个无 `appearances` 的 color（= universal/light）的 sRGB 分量（`"0xNN"`）。
3. `#if Blossom` 分流断言：默认 `brand-5`/`#0077FA`，Blossom `blossom-brand-5`/`#FF6F8E`。

**两 trait 都跑、都绿、断言值不同**。反证（`swift package clean` 后把 `brand-5` light red 改 `0x11`）确认断言真读了 Contents.json、非恒真——`.xcassets` 改动必须 clean 才生效（macOS SPM 以目录分发，增量不拷贝改动）。

## 顺带清理的第 6 个恒真断言（计划外，属 C2 精神）

`CoreGradientTests.tokensConstructible` 原为 `_ = CoreGradient.brand; …; #expect(Bool(true))`——恒真占位，就在 Task 3 的目标文件 `CoreDesignTests.swift` 内。改写为 **CoreGradient 的 trait 分流断言**：`String(describing:)` 内省 `AnyShapeStyle` 的底层 box —— 默认主题 `ColorBox<NamedColor>`（纯色退化）、Blossom `ShapeStyleBox<LinearGradient>`（真渐变）。断言粗类别（纯色 vs 渐变），比精确 asset 名更稳。反证通过。这把 SC-5「恒真归零」清得更彻底，并额外守护了渐变层的 trait 分流。

## 测试数变化

- 基线 104 tests / 32 suites → **96 tests / 31 suites**（两 trait 一致）。
- 明细：删 SurfaceKind 3 + Status 5→1（省 4）+ Avatar 2 + ProgressIndicator 1；加 C4a 1 + C4b 的 `gradientDepColorsetsPresent` 1。CoreGradient/FloatingGlass 数量不变（改写）。净 −8。
- suites：删 Avatar/ProgressIndicator 两 suite，加 BlossomColorDivergence 一 suite；`SurfaceKind` 的空 `@Suite` 去掉（退化为 `enum SurfaceKindAPIGuard` 纯编译期守卫，消除「叫 SurfaceKind 却啥都不测」的幽灵 suite——PR 降级评审 Suggestion 2）。净 32 → **30 suites**。
- **注意「96」是巧合**：审计基线也是 96 tests（`audit-checklist.md:16`），但那之后 epic 中前序 Issue 把它涨到 104，本 PR 再删/瘦身回落到 96——数字相同，**内容已大幅改写**（恒真→真断言），不是「测试没变」。

## 验证（Task 5，clean 后冷跑）

- `swift build` / `swift test` / `--traits Blossom` ×2：四条全 **EXIT=0**，两侧 96 tests passed。
- **warning 全 0**（`EmptyState` 的 12 条既有 deprecation 已随 #97 删除）。
- Step 2 越界自查：改动全在 `Tests/` 与 `.claude/`，`rc=1` 无 `Sources/` 触碰。
- Step 3 恒真归零自查：`type(of:).isEmpty` / 自写数组 `.count == N` / 0-`#expect` 文件 / `#expect(Bool(true))` 四类均无命中（注释里引用旧代码的字面量已清理，避免自查误命中——沿用计划评审第 4 轮的教训）。

## Checkpoint 评审（REVISE）处置

终审 superpowers-reviewer 判 REVISE，处置：

- **98.md 计数口径 `83 / 78` 更正为 `83 / 79`**（起草时的笔误，非漂移——audit-checklist 顶部本就 `=> 79`）；98.md 的 AC/DoD checkbox 全部勾选（SC-7 对账）。
- **`StatusColorsTests` 补全 border 档**：20 → 24 条（漏了 accent/success/attention/danger 的 `*Border`；done 家族无 border）。
- **`assetName` 提取为共享 `TestSupport.swift`**，消除它在 StatusColors / BlossomColorDivergence 两处的重复（脆弱正则只留一份）。
- **`FloatingGlassModifierTests` 注释诚实化**：`interactiveFlagPassedThrough` 只锁 init 存储契约（较弱）；真正的 body 级 `.interactive()` glass 选择在 Tests/ 内不可断言，已明确标注不覆盖，不再夸大为「透传契约」。
- **更正 C5 假记录**：评审建议本轮补 `ButtonRoleStyleRole.resolvedColor`——核查发现它 **早在 #96/B3a 就有完整真测试**（`ButtonStyleDefaultTests.swift` 的「三态取色」suite，`Color ==` 直接比较、含 disabled>pressed 优先级 + 5 role 遍历）。故 C5 附录原记「记录不补」是审计快照错误，更正为「已有测试」；本轮误建的重复测试已删除。

## 给下游的交接

- **测试地基现在可信**：`96 tests passed` 不再是失真信号——恒真断言归零（SC-5），Blossom 分流有真颜色值守护（C4a），渐变层分流也有守护（顺带）。
- **仍无运行时守护的缺口**（诚实记录，非「间接覆盖」）：`SurfaceKind` 的 token 映射（`.card→surfaceCard/...`）是 private extension，Tests/ 内不可断言，只保留了编译期 case 守卫。C5 附录中标「记录不补 + 理由」的目标（`ButtonRoleStyleRole.resolvedColor`、`ColorExtension.Color(text:)` 等）是可后续补强项。
- **C4a/CoreGradient 的 `String(describing:)` 内省依赖 SwiftUI 内部描述格式**（`NamedColor(name:…)` / `ColorBox` / `LinearGradient`），未来 SDK 若改描述格式需同步调整——与既有 asset guard 同性质的已知脆弱点。
