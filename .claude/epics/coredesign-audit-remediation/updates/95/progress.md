# Issue #95 Dynamic Type 改造 — 完成记录

分支 `issue-95-dynamic-type`（base `epic/coredesign-audit-remediation`）。承载 B2a、D3。全 epic 改动面最大的单项。

## 做了什么

| 项 | 改动 |
|---|---|
| B2a | `CoreTypography.Token` 枚举（11 case）+ `.coreFont(_:)` modifier；`@ScaledMetric` 缩放 size 与 lineSpacing，`relativeTo:` 从 0 → 2 |
| B2a | `CoreControlMetrics.font(for:)` → `fontToken(for:) -> Token`（SC-3，不再暴露 `Font`）；两个消费点改 `.coreFont` |
| B2a | 全部 CoreTypography 消费点（46 处 `.font(...)`）迁到 `.coreFont`；旧 `*Font`/`*LineSpacing`/`*Tracking` 常量改从 `Token.spec` 派生 |
| D3 | 7 处文本字号迁到 coreFont，新增 `captionMono`（12pt 等宽）覆盖 RefPill ×3 + ListRow |
| B2a | 布局断言层 `DynamicTypeLayoutTests`（`#if os(iOS)`，4 个 `@Test`），在第 5 条 xcodebuild iOS Simulator 命令下真正执行 |

## 核心 API 设计

`CoreTypography` 从「一堆 `Font` 常量」升级为 `Token` 枚举 + `.coreFont(_:)` modifier。为何是 modifier 而非 Font 常量：**缩放靠 `@ScaledMetric`，它需要 View 上下文**。旧的 `.system(size:)` 固定值不缩放——那正是 B2a 要修的（`relativeTo:` 全库 0 次）。

`CoreFontModifier` 用 `@ScaledMetric(wrappedValue: spec.size, relativeTo: spec.textStyle)` 缩放 CGFloat size，再喂 `.system(size:weight:)`——保住 Primer 精确基准 pt（40/32/…），只借 TextStyle 的缩放**斜率**。lineSpacing 同法缩放，tracking 固定。

**textStyle 基准映射**：选标准尺寸最接近该 pt 的 TextStyle（`.body`≈17、`.callout`≈16、`.caption`≈12、`.title2`≈22 等）。iOS Simulator 下断言实测缩放生效。

## captionSmall：9 缩放 + 1 固定（经用户确认改 AC）

AC 原写「10 个 token 全部缩放」，但 `captionSmall`（9pt）有既有的明确设计约束「故意不缩放」（`CoreTypography.swift:172`）——9pt 用于 tab 角标计数、status bar 指示器等紧凑 chrome，随 accessibility scale 放大会撑爆布局。这不是疏忽。

处置：`coreFont` **支持** captionSmall（统一入口），但走固定路径（`spec.scales == false`，body 里 `spec.scales ? scaledSize : spec.size` 绕过缩放）。AC 改为「9 缩放 + captionSmall 固定」。布局断言 `captionSmallDoesNotScale` 实测确认它 ax5 不放大。

**措辞写「固定」而非「暂不缩放」**——这是有据的设计决策，不是待办。

## 旧 `*Font` 常量：保留 + 从 Token.spec 派生（不删）

计划原本要「删零引用常量」。实测：9 组常量零代码引用（`titleLarge` 例外——`Avatar` 的 Canvas 绘制用它），下游 `any-writer` 也零引用。但**没删**，理由是删除会造成 API 不一致：

- `Avatar.swift:52` 在 `GraphicsContext.draw(Text)` 里——**命令式绘制套不了 `.coreFont` modifier**，必须用 `Font` 值。头像首字母是按 avatar 尺寸的图标级字号，本就不纳入 Dynamic Type。所以 `titleLargeFont` 必须留。
- 只删部分 → 「为什么只有 titleLarge 有 Font 常量」的不一致。

处置：**保留全部 `*Font`/`*LineSpacing`/`*Tracking` 常量，但改为从 `Token.spec` 派生**（`static var xxxFont: Font { Token.xxx.fixedFont }`）。这样：
- 单一真值源（`spec`）——防 size/lineSpacing/tracking 双份漂移（`Font` 不暴露 size，双份值的 size 漂移无法用测试锁，必须靠派生）
- 保留 public API（无破坏、下游零风险）
- Canvas 用途保留（`Token.fixedFont` 是固定不缩放的出口）

给 `Token` 新增 `public var fixedFont: Font`（命令式绘制出口）。这是执行期实测推翻计划前提（前提「零引用=死代码=删」被 Avatar 的 Canvas 用途 + API 一致性推翻）。

## 布局断言层：命脉是「第 5 条命令 + 非空转」

计划评审 4 轮全部围绕这一条打转（BLOCK×3 → PASS）。教训沉淀：

1. **第 5 条命令必须 `-scheme CoreDesign`**（SwiftPM 包 scheme，跑 `CoreDesignTests` target，默认 trait），与 CI `ci.yml:110` 逐字一致。**不是** `App/CoreDesignPreview.xcodeproj`——那跑 `SnapshotTests` target + Blossom trait，且 `@testable import CoreDesign` 在把 CoreDesign 当外部包的 target 下**编译不过**。CI 注释早写明「本 job 目前跑不到任何 `#if os(iOS)` 布局断言（由 #4 引入），#4 落地后才开始真正守护」——本 Task 就是那个 #4。
2. **macOS 无 Dynamic Type**：`@ScaledMetric` 在 macOS `swift test` 宿主下恒返回 wrappedValue。故断言 `#if os(iOS)`——**四条 SwiftPM 命令下它是空转的**，SwiftPM 全绿不代表布局断言过。凡改本文件覆盖的组件都须跑第 5 条命令。
3. **非空转判据用显示名子串 + 尾引号锚定**：Swift Testing 打印 `Test "<显示名>" passed`（显示名，不是函数名）。且子串要加尾引号——`captionSmall 明确不缩放"` 与 Task 1 token 测试的 `captionSmall 明确不缩放，其余缩放"` 只差尾字符，裸子串会碰撞假绿。
4. **ImageRenderer 尊重注入的 dynamicTypeSize**——整层押注于此，Task 1 先跑一个 spike 证实（`ImageRenderer(content: view.environment(\.dynamicTypeSize, s))` 的渲染高度随注入档变化），再铺三个断言。实测通电。

## NFR 视觉例外（实测，已记入 PRD 第 5 条 + 冒烟确认）

| 变化 | 组件 |
|---|---|
| `.subheadline`（15）→ `.bodyLarge`（16），+1pt | BottomInputBar chip |
| `.caption2`（≈11）→ `.caption`（12），+1pt | AvatarGroup / StateLabel / CommentCard / RefPill |
| `.caption`（12）→ `.caption`（12），无变化 | StatusRow |
| `.caption.monospaced()` → `.captionMono`（等宽保留） | RefPill ×3 / ListRow |
| captionSmall 固定（不缩放） | — |

视觉冒烟已看 RefPill（mono 等宽保住）、StatusRow（时间戳无回归）等，NFR 例外的 +1pt 观感自然。

## 降级 PR 评审补记的两处有意变化（视觉已确认）

评审实测 base 分支 `lineSpacing(CoreTypography` **零命中**——即所有迁移点原本都**没有** lineSpacing，只有 `.font(...)`。`coreFont` 的三件套现在无条件加 `.lineSpacing(spec.lineSpacing)`。

1. **多行文本在默认档多了行距。** 单行容器无影响（SwiftUI 预期）；但多行组件（`Banner` 换行消息、`Sidebar` 的 `titleLineLimit: nil` 换行 title）在**默认** Dynamic Type 档就获得了 Primer 行距。这是三件套设计的题中之义、且更 Primer-correct，但属 AC（Dynamic Type）之外的默认档变化——**已视觉确认**：多行 Banner（"This version of the document is going to / expire after 4 days."）行距舒适无回归。**记为有意变化。**

2. **横向截断在 accessibility 档可接受。** `SidebarDocumentRow` 的 trailing `detail`（`.coreFont(.bodyMedium).lineLimit(1)`）在 AX5 下，换行的 title 与固定单行 detail 争夺 320pt 宽度，detail 可能截断成 "3 d…"。布局断言只测**纵向**不裁切（高度增长），不覆盖横向截断。**AC「四种 row 不裁切」限定为纵向**——trailing metadata 在极大字号下的横向截断是可接受的（截断优于挤爆），此处显式声明。

3. **`.caption2`（11）→ `.caption`（12）的 +1pt** 同时把 SwiftUI 原生缩放换成了相对 `.caption` 的 `@ScaledMetric` 缩放——已在 NFR 例外 5 记录，是有意接受的变化。

## 给下游 Issue 的交接

- **凡触及 `DynamicTypeLayoutTests` 覆盖文件的 Issue（至少 `Sidebar.swift`——#101 D6b、#102 D18）必须跑第 5 条命令**（`xcodebuild -scheme CoreDesign ...`），否则弄破布局断言无人发现（四条 SwiftPM 命令下它空转）。**`DynamicTypeLayoutTests` 绝不能加进 CI 的 `-skip-testing` 列表**。
- **新增文本用 `.coreFont(token)` 而非 `.font(.caption)` 等系统档**——后者绕过 Dynamic Type，是 D3 刚清理的。
- `CoreControlMetrics` 不再有返回 `Font` 的 API（SC-3）；控件字号用 `.coreFont(CoreControlMetrics.fontToken(for:))`。
- 旧 `*Font` 常量仍在（public，从 Token 派生），命令式绘制（Canvas）场景用 `Token.fixedFont` 或这些常量。
- **`Sidebar` 的 leading 图标现在随 Dynamic Type 缩放**：`Image(systemName:).coreFont(.bodyLarge)` 是原 `CoreTypography` 消费者的一对一迁移（图标字号跟随其 title 缩放，符合视觉等重），**不是意外的图标缩放**——范围边界排除的是 `CheckBox` / `CoreMenuButton` 那类用 `iconSize` 的独立图标尺寸。
- 坐标漂移可忽略：组件文件都是等行 `.font`→`.coreFont` 替换，仅 Badge 删 tracking -1 行（`:97` 之后，无下游引用受影响）。

## 验证证据

四条 SwiftPM 命令（clean 后冷跑）：

```
build          EXIT=0    warning=0
test           EXIT=0    warning=0    104 tests in 32 suites passed
build-blossom  EXIT=0    warning=0
test-blossom   EXIT=0    warning=0    104 tests in 32 suites passed
probe(clean)   EXIT=0
```

**第 5 条命令**（与 CI `ci.yml:110` 逐字一致）：`TEST SUCCEEDED`，布局断言非空转（三个显示名子串各出现 2 次 = started + passed）。

SC-3：`grep '-> Font' CoreControlMetrics.swift` 无输出。`relativeTo:` 从 0 → 2（size + lineSpacing）。`audit-checklist.md` 计数 83，B2a/D3 标 ✅。
