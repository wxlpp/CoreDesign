# Plan — 设计系统配色/样式回灌

Spec：`.claude/epics/design-system-realign/1-spec.md`（v6，评审 5 轮跑满）
分支：`feat/design-system-realign`（base `main`@`dd72ff6`，spec 已提交于 `ee62111`）
**版本**：v2（v1 经 superpowers-reviewer 判 BLOCK 后重写：3 Critical + 8 Important 全部 CONFIRMED）

## 执行原则

- **顺序执行、不并发**（spec 高度裁决）：每一阶段都改 `Colors/` 或 `ButtonRoleStyleRole.swift`，
  并发 worktree 必然互踩。
- **每阶段自成一个可编译、可跑测试的提交**；判据先改红再改绿（TDD 方向）。
- ⚠️ **每处 `sed` / `replace` 后当场断言变异落地**（`assert t != before`），
  再跑判据——「改了没生效」与「判据无力」是两回事。
- ⚠️ **`Color.mix` / `.opacity` 的判据一律走结构相等或 iOS 腿**，
  不在 macOS 腿解析那 198 个资源色（spec NFR-1）。

---

## P0　先跑掉两个未知（不写产品代码）

阻塞后续形态选择，必须最先做。

- **P0-1　iOS 探针 —— 已完成 ✅，结论是「不撑满」，且**顺带否掉了 iOS 侧的判据机制**。
  一次性测试放进 `UIWindow` 后用 `UIGraphicsImageRenderer` + `layer.render(in:)` 量
  （iPhone 17 Pro，scale=3.0，探针已删除、不入库）：

  ```
  frame 200x28  intrinsic=28.0  非透明行=50（16…65）  带高=16.67pt
  frame 200x36  intrinsic=28.0  非透明行=50（28…77）  带高=16.67pt
  frame 200x44  intrinsic=28.0  非透明行=50（40…89）  带高=16.67pt
  ```

  **结论 1（决定形态）：`UISearchTextField` 不撑满。** 非透明带在 28/36/44 三档
  **完全相同且始终居中** ⇒ 与 `NSSearchField` 同形，塞进 44pt frame 只会产生空带。
  ⇒ **走退路分支**：视觉给控件自然高、44pt 由包装层承担命中区。

  **结论 2（否掉判据）：`layer.render(in:)` 量不到它的圆角底衬。**
  带高 16.67pt **小于** 控件自己的 `intrinsicContentSize.height = 28`
  ——渲染出来的只有图标+文字那一行，底衬由不被 `layer.render` 捕获的层绘制
  （与 glass 同族的问题）。⇒ 「非透明带 == 控件自然高」这条判据在 iOS 上会**恒假红**，
  **机制不可用**，不是阈值问题。

  ⇒ **FR-5a 的判据形态最终定案（覆盖 spec §5.1 与 plan P5 的两分支写法）**：
  - **iOS**：只保留现成的 `TouchTargetTests:70-74`（`renderedHeight` 量布局盒 ≥ 44）
    ——它守的正是**命中区**，是本条真正要保的东西。
    **不新增像素带判据**，并**如实登记「iOS 侧无法在进程内量到搜索框视觉带」**。
  - **macOS**：`cacheDisplay` 可用（spec §5.1 实测过 26/30/38 行），
    保留「非透明带 == 控件自然高」以抓空带回归。**先由 P0-3 证明装置能在 `swift test` 里跑。**

  **两端自然高度一致**：iOS `UISearchTextField.intrinsicContentSize.height = 28`、
  macOS `NSSearchField(.large).intrinsic = 28` ⇒ 视觉高度统一取 **28pt**。
- **P0-2　iOS 腿基线 —— 已完成 ✅**（iPhone 17 Pro `02F33AA8-…`，`** TEST SUCCEEDED **`）：

  ```
  result=Passed  totalTestCount=1011  passedTests=1000
  failedTests=0  skippedTests=5  expectedFailures=6
  ```
  ⚠️ 取的是**顶层** `passedTests=1000`；同一份 `.xcresult` 的
  `devicesAndConfigurations[0].passedTests` 是 **1038**，按后者读会误判成基线漂移。

- **P0-3　`cacheDisplay` 判据装置 spike（评审 S-3，新增）**：
  `Tests/` 下 grep `cacheDisplay` / `bitmapImageRepForCachingDisplay` **零命中**
  ——spec 的量法是独立 `swiftc` 二进制做的，**在 `swift test` 进程里能不能跑没验过**。
  ⇒ P4-1 依赖它之前，先用一条一次性测试证明装置可用；不可用则 FR-5a 的 macOS 判据
  降级为预览宿主人工核对并如实登记。

---

## P1　第 2 层桥接 + accent 取值与派生（`Colors/`）

1. **新增 `Color.inkPrimary`**（放 `SystemLabelColors.swift`，第 2 层）：
   `#if canImport(UIKit) Color(uiColor: .label) #else Color(nsColor: .textColor)`。
   ⚠️ 文档注释必须写明**两端桥的是不同系统色**（`label` vs `textColor`），
   以及 macOS 选 `textColor` 的理由（α=1.0 vs `labelColor` 的 0.8471，实测数写进注释一行）。
2. **新增 `Color.dataAccent` / `dataAccentSubtle`**（`InteractionColors.swift`）：
   `#if canImport(UIKit) Color(uiColor: .systemBlue) #else Color(nsColor: .systemBlue)`，
   subtle = `.opacity(0.12)`。⚠️ **不要写 `Color.blue`**（与 systemBlue 不等）。
3. **派生公式收成单一来源**（spec §2.3 I-4）：
   ```swift
   static func accentHover(from base: Color) -> Color { base.mix(with: .surfaceBase, by: 0.18) }
   static func accentPressed(from base: Color) -> Color { base.mix(with: .surfaceBase, by: 0.30) }
   static func accentDisabled(from base: Color) -> Color { base.opacity(0.22) }
   static func accentSubtleBackground(from base: Color) -> Color { base.opacity(0.08) }
   ```
   静态 token `accentHover` 等改为 `accentHover(from: .accent)`。
   ⚠️ **位置与可见性定死**（评审 S-4）：放 `extension Color`、标 **`internal`**。
   放本包自有类型上并标 `public static` 会进 MainActor 棘轮射程；
   标 `public` 会让 design-digest 的 API 面计数增长——两个都是无谓代价。
4. **`Color.accent` = `.inkPrimary`**（原 `Color.accentColor`）。
5. **`secondaryAccent` 族 → `grey7/8/9/2`**。
   ⚠️ 同步改 `docs/DESIGN-FOUNDATION.md:174` 的旧理由（与 `neutralAccent` 重叠已被接受）。

**本阶段会判红的既有判据（预期，逐条处置）**
- `AccentDerivationTests.pressedMovesAwayFromBackground` → **反转**为
  `pressedMovesTowardBackground`（浅变亮 / 深变暗）。
- 其余 3 条（`hoverAndPressedShareDirection` / `derivationPreservesOpacity` /
  `derivationIsAppearanceAdaptive`）**原样保留、必须仍绿**。
  ⚠️ `derivationPreservesOpacity`（α > 0.95）是 `inkPrimary` 选 `textColor` 的机器验证点
  ——它若红说明第 1 步写成了 `.primary`。
- **新增**判据：默认值同源 `EnvironmentValues().coreAccent == Color.accent`；
  公式同源 `role.resolvedColor(accent: .accent, isEnabled: true, isPressed: true) == Color.accentPressed`。
  ⚠️ 同源判据依赖 `inkPrimary` **两次求值结构相等**（评审 S-5）。若判红，
  把 `inkPrimary` 从 `static var` 改成 `static let`——**不要**改成解析型断言。

⚠️⚠️ **NFR-6 探针色替换必须在本阶段一起做，不能拖到 P5**（评审 I-1）：
`Color.accent = .inkPrimary` 一落地，iOS 腿上 `accent == contentPrimary`
⇒ `TextAndDisplayTests:824-826` / `MaskRevealTests:479-486` / `CrossPlatformTests:464`
这类「拿 `.accent` 与 `.contentPrimary` 当两个可区分探针色」的位图判据**逐字节相同 ⇒ 红**。
而 macOS 腿因 `textColor`(α 1.0) vs `labelColor`(α 0.847) 仍差几字节 ⇒ **绿**。
⇒ 若拖到 P5，P1–P4 的每个中间提交都是「macOS 绿 / iOS 红」的假绿态，
违反本 plan「每阶段可跑测试」的原则。**因果在 P1，修就在 P1。**

---

## P2　`coreAccent` 环境 + 射程 A/B

1. **`public @Entry var coreAccent: Color = .inkPrimary`** + `public func coreAccent(_:)`。
   ⚠️ 必须 `public`（`CoreDesignEffects` 跨 target 读）。
   ⚠️ **不设 `.tint(_:)`**（spec §2.3：与 `SpinningModifier` / `Ping` 现有注释冲突）。
2. **射程 A（8 处 `Color? = nil`）**：`SpinningModifier:38` + `:159 spinning`、
   `ProgressIndicator:12/19/26`、`Ping:67`（形参 `color:`）、`Rise:58`（形参 `color:`）、
   `ProgressBar:35`（已是 `Color?`，改回落到环境）。
   ⚠️ `SpinningModifier.swift:26` 的 `public let tint: Color` 是**公开存储属性**，一并改类型。
   ⚠️⚠️ **改它会当场打断 `downstream-probe`**（评审 C-2，已坐实）：
   `scripts/downstream-probe/Sources/DownstreamProbe/PublicVisibility.swift:443-445` 的
   `consumeSpinningModifierTint() -> Color` **直接读**这个属性、返回类型是 `Color`。
   ⇒ **本阶段必须同步把它改成 `-> Color?`**。
   spec §2.3 那句「源码兼容」只覆盖**调用点**的 optional 提升，**覆盖不了属性读取方**
   ——P7-4 不是「验证兼容」，而是「验证我改到位了」。
   ⚠️ **四个图表：改默认值、不改类型**（评审 I-6 更正 v1 那句自相矛盾的「不动」——
   它们今天是 `.accent`）：`RadarChart:20` / `RingChart:22` / `ActivityHeatmap:18` /
   `NetworkGraph:28` 的 `tint: Color = .accent` → **`tint: Color = .dataAccent`**，
   保持**非可选**、不进射程 A、不读环境。
3. **射程 B（视图级读环境）**：
   - `ButtonRoleStyleRole`：**新增重载** `resolvedColor(accent:isEnabled:isPressed:)`
     + 新增 **`var onColor: Color`（无参，评审 I-4）**——spec §4.2 定义的就是无参形态
     （`.primary → contentOnAccent`，其余四 role → `contentOnEmphasis`），
     **不要发明 `onColor(accent:)`**：按亮度派生前景色是 spec R-5 **明确推迟**的事；**旧 `resolvedColor(isEnabled:isPressed:)` 与三个无参属性保留**
     （委托 `accent: .accent`）——否则 `downstream-probe:116-117` 与
     `ButtonStyleDefaultTests:52-68` 编译失败。
   - 三个按钮样式读 `@Environment(\.coreAccent)` 传入。
   - `UnderlinedTabBar`、Sidebar 选中态（P4）、`InkSegmentedControlStyle`（P4）。
   - **R-6 决定**：`FocusRingModifier` 归**射程 A**（`color: Color? = nil`），
     与它的默认实参形态一致；射程 A 计数 8 → 9，BREAKING +1。

**预期判红**：`SpinningTintPassthroughGuard:9`（`ProgressIndicator().tint == Color.accent`）
→ 改断 `tint == nil` + 新增一条「无显式 tint 时读 `coreAccent`」。

---

## P3　`contentOn*` 族拆分

1. `contentOnAccent` → `.systemBackground`。
2. `contentOnEmphasis` / `contentInverse` / `contentOnDanger` → **保持 `.white`**。
3. **改归属**：`Steps`（`.tint` 圆底）、`BeforeAfterSlider`（滑柄填充）、
   `AnimatedMeshGradient:202`（预览）→ `contentOnEmphasis`。
   ⚠️ `BeforeAfterSlider:143` 把手图标是 `contentPrimary`（深色白压白）——顺手修或登记。
4. `SolidButtonStyle.foregroundColor` → `role.onColor(accent:)`
   （primary → `contentOnAccent`，其余四 role → `contentOnEmphasis`）。
5. `success` → 系统 `.green`、`info` → `.label`、`contentLink` → `.label`。
   ⚠️ **`warning` / `danger` 两族 8 个 token 不动**。
6. 改 `InteractionColors.swift:40` 的「白字」注释。

**新增判据**：`contentOnAccent` 明暗两档取值不同。

---

## P4　组件样式

| 顺序 | 改动 | 要点 |
|---|---|---|
| P4-1 | `SearchField` 换原生控件 | iOS `UISearchTextField` / macOS `NSSearchField(.large)`。**不建 style 协议**（登记表 `prescriptive`）。高度按 P0-1 结果定。撤 `.focusRing`。删 `clearLabel(for:)` + `SearchFieldTests.swift` 里 `@Suite SearchFieldL10nTests` 那 2 条 + `Localizable.strings:4 "Clear %@"`；**保留**同文件另 2 条构造判据。<br>⚠️⚠️ **删那条串会让 `ProgressBarTests.swift:50-56` 判红**——`newKeysExistInCatalog` 的 key 列表里就有 `"Clear %@"`（spec 与 plan v1 都声称「无判据会红」，**是假的**）。⇒ 同步从该列表移除，并改测试标题「四个新 key」→「三个新 key」 |
| P4-2 | Sidebar 选中态扁平化 | ⚠️ **走射程 B**（评审 I-7）：填充用 `Color.accentSubtleBackground(from: coreAccent)`，**不是**静态 token（静态的不跟环境走）。label 文字；去 `floatingGlass` / `borderSelected` / `coreShadow(.medium)`。**改写 `sidebar.md:114-131` 为「已重议」，保留 #136/#225/#226 历史记账** |
| P4-3 | `ListRow` 竖向 padding 12 → 8 | ⚠️⚠️ **「12」不是字面量**：`ListRow.swift:41` 是 `CoreControlMetrics.verticalPadding(for: .regular)`，而 `CoreControlMetrics.swift:52-56` 的**同一个函数还喂着 `ButtonChromeModifier.swift:13`（所有按钮样式）**。⇒ **只把 `ListRow` 那一处调用换成 `CoreSpacing.sm`，绝不动 `CoreControlMetrics.verticalPadding`**——改 metric 会改掉全库按钮高度并踩 `TouchTargetTests`。<br>⚠️ 单行被 `minHeight 44` 钉回，**只有多行/带副标题的行真的收紧** ⇒ 验收判据必须建立在多行行上 |
| P4-4 | `Card(elevation: CoreElevation.Level = .small)` | **不用 Bool**（`BoolExemptionGuard:381-401`）。`.none` 一行退回。文档注释写明背离 surface 分层规则。**不动 `SurfaceModifier`** |
| P4-5 | `InkSegmentedControlStyle` + 三个静态入口 | ⚠️ **走射程 B**（评审 I-7）：选中段实心填 `@Environment(\.coreAccent)`、文字用与 `onColor` 同源的 `contentOnAccent`。走 SwiftUI 回退路径，**不走** `NativeGlassSegmentedControl`。三个 `static var glass/plain/ink` 加 `nonisolated`，**且三个 style struct 的 `public init()` 也要加 `nonisolated`**（只加 static 编译不过） |

**默认不变**：`GlassSegmentedControlStyle` 仍是默认。

---

## P5　判据与假绿面清理

- **NFR-6**：grep 全部把 `.accent` 当探针色的测试（**9 文件 / 37 处**）。
  `EffectsColorLiteralGuard:157`（字符串 fixture）与 `MicroInteractionTests:278`（源码扫描）
  **不受影响**，其余 7 个文件逐个核。
  ⚠️ 重点：`TextAndDisplayTests:824-826`、`MaskRevealTests:479-486`、`CrossPlatformTests:464`
  ——FR-1 后 iOS 腿上 `accent == contentPrimary`，位图逐字节相同 ⇒ **macOS 绿、iOS 红**。
- **FR-5a 判据**：**不得用 `ImageRenderer` 量控件像素**（它画的是占位块）。
  **P0-1 已定案为「不撑满」分支**，且 iOS 侧的像素判据被实测否掉（见 P0-1 结论 2）：
  - **iOS**：只保留现成的 `TouchTargetTests:70-74`（布局盒 ≥ 44 = 命中区）。
    **不新增像素带判据**——`layer.render(in:)` 捕获不到底衬，写了会恒假红。
    如实登记这个覆盖缺口。
  - **macOS**：新增 `cacheDisplay` 判据「非透明带 == 控件自然高」抓空带回归
    （先过 P0-3 装置 spike）。
- **图表位图判据**：有/无 `.coreAccent(.red)` 下位图相等。**如实登记它今天天然绿**。

⚠️ **补齐 P7 抓不住的改动（评审 I-8，v1 有 5 处改完没有任何判据能抓）**：

| 改动 | 判据 |
|---|---|
| **射程 B 主题化本身**（这是本次的核心特性，v1 竟无判据） | `expectBitmapsDiffer`：同一 `Button(.solid(role: .primary))` / `UnderlinedTabBar` 在有/无 `.coreAccent(.red)` 下位图**不同**。⚠️ 与图表那条正好互补（图表要**相等**） |
| `secondaryAccent → grey` | 走 `assetName` 断言（CLAUDE.md 免疫机制第 1 类），**两腿都可判**、不解析 |
| `Card(elevation:)` | 结构断言 `.none` 与 `.small` 产出不同；⚠️ 投影色属那 198 个 macOS 恒透明常量 ⇒ **位图差异断言只能放 iOS 腿** |
| `ListRow` 多行行收紧 | 渲染高度断言，**必须用多行/带副标题的行**（单行被 44 钉回） |
| `InkSegmentedControlStyle` | 构造 + 渲染断言（选中段填色 ≠ Glass 版），不能只靠棘轮脚本证明「能编译」 |

---

## P6　文档与门禁（⚠️ 最容易掉队的一段）

1. **`docs/design-digest.md` 是 CI 门禁**（`DesignDigestSyncGuard`）：
   重跑 `python3 scripts/design-digest.py` → 按报错更新 `scripts/design-digest.py:20-23` 的
   `FLOORS`（`colors` 115 → 新值，**精确相等比对**）→ 改
   `docs/design-digest.header.md:80` 与 `design-digest.py:485` 两处**手写散文** → 提交三者。
2. **`docs/BREAKING-CHANGES.md` 新增「未发布」章节**，10 项：
   `tint: Color → Color?`（9 面，含 `SpinningModifier.tint` 存储属性）、
   `Card.init` 新增 `elevation`、`Color.accent` 语义变墨色、`contentOnAccent` 取值翻转、
   `resolvedColor` 新重载、`accentDisabled` 0.35 → 0.22、
   `accentSubtleBackground` 0.12 → 0.08、撤 `.focusRing`、清除按钮改由系统提供、
   `focusRing(color:)` 改 `Color?`。
   ⚠️ **再补 4 类 token 取值变更**（评审 I-5；`BREAKING-CHANGES.md:788-803` 就是本仓
   登记 token 取值变更的先例，形态照抄）：
   (a) 四个图表 `tint` 默认实参 `.accent → .dataAccent`（**公开默认值改变取值**）；
   (b) `secondaryAccent` 族 `lightBlue5/6/7/2 → grey7/8/9/2`；
   (c) `success` / `info` / `contentLink` 取值变更；
   (d) `accentHover` / `accentPressed` **混合方向反转**（目标从 `.primary` 改为 `.surfaceBase`）。
   版本意图：相对 `v0.9.0` 的下一个 **minor**。
3. **会讲反话的具体行**：`CLAUDE.md:31` 与 `:156`、
   `DESIGN-FOUNDATION.md` 的 **`accent 衍生族` 整节**（评审 S-1：spec 说 `:167`、
   plan v1 漂成 `:169`，两边都可能偏 ⇒ **按节改，不按行号改**；该节含
   「accent = accentColor」「0.35」「0.12」三处失真，及 `selectionBackgroundEmphasis`
   一处**仍然正确、不要动**）、`:28`、`:58`、`:174`、`docs/components/` 下
   `search-field.md:27-37`（整段作废，且**今天已失真**）、`sidebar.md:112` 与 `:114-131`、
   `button.md:50`、`steps.md:140`、`pin-code.md:80`、`rating.md:108`、`shine.md:128`、
   `spray.md:67`、`card.md`、`list-row.md`、`segmented-control.md`。
   ⚠️ **`BareLineRefGate` 是「只出不进」门禁**（评审 S-2，`Tests/CoreDesignTests/BareLineRefGate.swift`
   扫 `docs/**`）：本步会重写 `sidebar.md` / `search-field.md` 等 ⇒
   **改动后的文档里不得新增或编辑 `X.swift:NN` 形态的裸行号引用**（删除既有的没问题）。
   本 plan 与 spec 住在 `.claude/`，不在该门禁射程内。
4. **登记表** `docs/component-registry.json`：`components[51]`（SearchField）的 notes
   改「清除按钮」措辞（`kind`/`decidedBy` **不动**）；`Card` / `SegmentedControl` 条目补记。
5. **R-5 登记**（不修）：`coreAccent(_:)` 文档注释 + `DESIGN-FOUNDATION.md` + BREAKING
   写明「主题色应为近单色（黑/白极性）；饱和主题色在深色下前景为 `systemBackground`」，
   并开后续 issue。

---

## P7　验证（`verification-before-completion`）

按顺序，每条都要有命令输出为证：

1. `swift build`（三 target）
2. `rtk proxy swift test` → 取 `Test run with … tests` **汇总行**（逐条行会丢）。
   ⚠️ **口径不是「≥ 基线」**（评审 I-2，v1 写错）：本次**会删 1 个 suite / 2 条测试**
   （`SearchFieldL10nTests`）。逐项记账：

   | | tests | suites |
   |---|---|---|
   | macOS 基线 | 972 | 138 |
   | P4-1 删 `SearchFieldL10nTests` | −2 | −1 |
   | P1 同源 ×2 / P2 读环境 ×1 / P3 明暗 ×1 | +4 | |
   | P5 新增（FR-5a、图表、主题化、secondaryAccent、Card、ListRow、Ink） | +7 | +1~2 |
   | **macOS 期望** | **≈ 981** | **138~139** |

   iOS 腿同理从 `passedTests=1000` 起算（那 2 条 L10n 在 iOS 腿也跑）。
   ⚠️ **任何偏差都要逐条解释，不许用「≥」糊过去**。
   ⚠️ 权威条数可用 `swift test --xunit-output <path>`（`.xcresult` 是 xcodebuild 的产物，
   SwiftPM 腿取不到）。
3. `bash scripts/mainactor-static-ratchet.sh`（⚠️ 本地 `swift test` 全绿**不代表**这条过了）
4. `cd scripts/downstream-probe && swift build`（验 §2.3 的 `Color? = nil` 源码兼容）
5. `python3 scripts/design-digest.py && git diff --exit-code -- docs/design-digest.md`
   ⚠️ **必须带 `-- docs/design-digest.md` 路径**（CI `ci.yml:102` 就是这么写的）；不带路径时
   任何其他未提交文件都会让它假红。
6. iOS 腿：`xcodebuild test -scheme CoreDesign-Package -resultBundlePath …`
   → `.xcresult` **顶层** `passedTests`，与 P0-2 基线对比
7. 预览宿主：`xcodebuild -project App/CoreDesignPreview.xcodeproj`
   ⚠️ 覆盖 `ComponentData.swift:1188` 的 `Color.success`
8. **R-3 视觉验证（4 组截图）**：
   ① `contentOnEmphasis` 白字压非 primary role 底色；
   ② `accentDisabled` 底 + `contentDisabled` 字；
   ③ Sidebar 选中态 8% 墨压 `windowBackgroundColor`；
   ④ 22% 墨作 Light/Borderless **禁用文字**色。
   **预置回退**：④ 不可读则改用 `contentDisabled`（`SolidButtonStyle:30` 有先例）。

## P8　收尾

- **提交前声称自查**（`fable`）：commit 正文每句声称 × diff × 实测输出。
- 终审：`superpowers-reviewer`，节点 `finishing`，完整 diff。
- 开 PR（base `main`）→ `auto-fix-pr-after-implementation`。
- **收尾汇报必须列给用户的 3 项**（不是实现细节）：
  1. `warning` / `danger` 两族**未改**——替代方案技术可行（一行复用
     `mix(with: .inkPrimary)`），因范围与判据成本本次不做；
  2. functional 层因此**自身是混的**（`success`/`info` 系统色 vs `warning`/`danger` 品牌色阶），
     切分线是「有无渲染面」；
  3. **R-5**：主题色若设成饱和色，深色下前景会反色——本次只登记不修。
  4. `contentLink → .label` 但**不定下划线约定** ⇒ 链接与正文**不可区分**（spec §4.3 末）。
  5. `BeforeAfterSlider:143` 把手图标深色下白压白——**本次决定：顺手修**（改
     `contentOnEmphasis` 的反色），不进「只登记」清单。
  6. 若 P0-1 落到「不撑满」分支：iOS 搜索框**视觉带 < 44**（命中区仍 44），是登记在案的缺口。
  7. 字距未移植的依据是「沿 `#119` 定案、**未实测**」，不是测量结论（spec §6）。
