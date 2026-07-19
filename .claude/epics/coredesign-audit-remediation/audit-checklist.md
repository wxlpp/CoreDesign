# 审计清单 — coredesign-audit-remediation

四路并行 agent 审计（token 层 / 公开 API / 重复代码 / 构建测试基建）产出的完整缺陷清单，共 **83 项**（簇 A 7 / 簇 B 36 / 簇 C 17 / 簇 D 23）。本文件是 PRD Success Criteria SC-7 的判定依据：每项须标记为「已修复」或「记录不修 + 理由」。

计数口径：**按本文件簇 A–D 四张表的数据行计**（每行一项），而非按顶层 ID 计（顶层 ID 有 40 个，多项带 a/b/c 后缀细分）。SC-7 引用的数字须与本行一致。

核对命令（末尾统计段的「不修理由」表也以 `| C3 |` 形态开头，须减去其 4 行）：

```bash
echo $(( $(grep -c '^| [A-D][0-9]' audit-checklist.md) - 4 ))   # => 83
grep -oE '\| #[0-9]+ \|$' audit-checklist.md | sort -V | uniq -c  # 各 Issue 承载数，求和 => 79
```

> **给 #7 的约束**：SC-5 要求 #7 把「逐文件测试处置清单」作为 C2 附录落盘到本文件。该附录的表格**首列须用测试文件名**（如 `| ProgressIndicatorTests.swift |`），**不得**用 `| C2a |` 这类 `^| [A-D][0-9]` 形态——否则上面的核对命令会再次漂移，重蹈第 2 轮 N-C1 的覆辙。

基线（审计时）：`swift build`、`swift test`（96 tests / 32 suites）、`swift build --traits Blossom` 全绿、零 warning。

`Issue` 列对应 PRD Dependencies 中的 Issue 编号。

---

## 簇 A · 真 bug

| ID | 缺陷 | 证据 | FR | Issue |
|---|---|---|---|---|
| A1 | `Color.primary/secondary/tertiary` 遮蔽 SwiftUI 同名成员，模块内本地定义静默胜出。**已确认两处产品代码受害**：(1) `CheckBox.swift:31` 渲染品牌色而非系统 label 色，注释与行为矛盾；(2) `StatusRow.swift:80` 的 `case .skipped: return .secondary` 在返回 `Color` 的上下文中解析到 `FunctionalColor.secondary`（默认 `lightBlue5`、**Blossom 下 `violet5`**），使 skipped 行图标渲染成浅蓝/紫罗兰而非作者意图的系统灰——第 4 轮评审新发现 | `FunctionalColor.swift:11-12`、`CheckBox.swift:21-23,31`、`StatusRow.swift:75-82` | FR-1 | #2 |
| A2a | `CheckBoxToggleStyle` / `CheckBox` internal，但文档明说业务侧直接使用（实测 `cannot find in scope`） | `CheckBox.swift:24,52,53` | FR-2 | #3 |
| A2b | `BorderlessButtonStyle` 的 `role` internal 致 memberwise init 不可达（实测 `initializer is inaccessible`） | `BorderlessButtonStyle.swift:40,52` | FR-2 | #3 |
| A2c | `ButtonRoleStyleRole` 的 `color`/`activeColor`/`disabledColor` internal，而 CLAUDE.md 称其为三色「唯一来源」 | `ButtonRoleStyleRole.swift:18,33,48` | FR-2 | #3 |
| A2d | `FunctionalColor` extension 整层非 public，CLAUDE.md 却称第 4 层是「最高层 API 表面」 | `FunctionalColor.swift:11,35` | FR-1 | #2 |
| A3a | `BorderlessButtonStyle` 与 SwiftUI 同名，下游写该名**能编译**但静默解析到 SwiftUI 版本 | 下游消费包实测 | FR-2 | #3 |
| A3b | `MenuButton` 与 macOS 上 deprecated 的 SwiftUI `MenuButton` 同名，实测报错信息具误导性 | `MenuButton.swift:128` | FR-2 | #3 |

## 簇 B · 结构性冗余

| ID | 缺陷 | 证据 | FR | Issue |
|---|---|---|---|---|
| B1a | `FunctionalColor` 与 `InteractionColors` 是同一套色阶两次声明（逐值相同） | `FunctionalColor.swift:12-32` vs `InteractionColors.swift:4-25` | FR-1 | #2 |
| B1b | 上述重复带来**两份** `#if Blossom` violet 分流，违反「分流点压到最低」 | `FunctionalColor.swift:17-27`、`InteractionColors.swift:10-20` | FR-1 | #2 |
| B1c | `FunctionalColor` 的 primary/secondary/tertiary 组共 **3 处**显式引用，全部是 A1 型遮蔽：`CheckBox.swift:31`、`StatusRow.swift:80`（两处产品代码）、`CoreGradient+Preview.swift:17`（Preview）。三处在删除后都**不报错**而是静默改解析到 SwiftUI 内建成员。该组共 12 个符号（3 基础名 + 9 个 Active/Disable/Hover 变体），其中 10 个（`tertiary` + 全部 9 个变体）除定义外零引用 | `CheckBox.swift:31`、`StatusRow.swift:80`、`CoreGradient+Preview.swift:17` | FR-1 | #2 |
| B2a | 全部 10 个 typography token 用 `.system(size:)`，`relativeTo:` 出现 0 次 | `CoreTypography.swift:53-183` | FR-3 | #4 |
| B2b | `Sidebar` 四种 row 写死 `frame(height:)`，大字号裁切（`ListRow`/`SearchField` 用的是 `minHeight`） | `Sidebar.swift:121,183,238,287` | FR-3 | #5 |
| B3a | 三个 ButtonStyle 的 role 三态取色逻辑逐字重复 | `SolidButtonStyle.swift:71-76`、`LightButtonStyle.swift:57-62`、`BorderlessButtonStyle.swift:65-70` | FR-4 | #5 |
| B3b | Solid / Light 的 glass 与非 glass 分支整段复制，仅尾部 modifier 不同 | `SolidButtonStyle.swift:38-65`、`LightButtonStyle.swift:27-51` | FR-4 | #5 |
| B3c | 两个 BackgroundModifier 实质是同一类型 | `SolidButtonStyle.swift:81-99`、`LightButtonStyle.swift:67-83` | FR-4 | #5 |
| B3d | font/padding/contentShape 四行在 4 个 style 里共出现 5 次 | 同上 + `BorderlessButtonStyle.swift:43-46` | FR-4 | #5 |
| B3e | `CircularGlassButtonStyle` 写死 diameter 38 且不读 `controlSize`（另三个都读），38 不在 metrics 序列内 | `CircularGlassButtonStyle.swift:16,18` | FR-4 | #5 |
| B4a | `textFieldSize` 写入后从不读取，每次布局白跑 GeometryReader + PreferenceKey 往返 | `BottomInputBar.swift:87,138` | FR-5 | #6 |
| B4b | `View+SizeReader.swift` 整文件是 B4a 的唯一支撑，删后可整体移除 | `View+SizeReader.swift`（51 行） | FR-5 | #6 |
| B4c | `KeyboardHandling.swift` 中 `KeyboardReadable`、`dismissKeyboardOnTap`、`resignFirstResponder`、`becomeFirstResponder` 全仓零引用；`becomeFirstResponder` 泄漏宿主 app 私有通知名且未标 `@MainActor` | `KeyboardHandling.swift:18-76,112-167` | FR-5 | #6 |
| B4d | `KeyboardHeightPublisherFactory` 仅被自身文件内零引用的 `KeyboardReadable` 默认实现（`:60`）与测试消费，无生产调用点 | `KeyboardHandling.swift:60,78-110` | FR-5 | #6 |
| B5 | `Sidebar` 四个 row 是同一 row 的四份拷贝（约 120 行可降至 50） | `Sidebar.swift:104-130,157-188,215-243,263-292` | FR-4 | #5 |
| B6a | `StatusColors` 新旧两套并行 scale，组件随机选边。**#93 执行时发现与 D19 原处置冲突**：新体系只有 `accent` 一个蓝色家族，而它正是 Primer 的 info 语义；Banner/Toast/Badge 用的 legacy `info*` 只能迁到它。故 `statusAccent*` **保留**（原 D19 判「库内零消费点」在迁移后不再成立） | `StatusColors.swift:13-59` vs `:63-77` | FR-1 | #2 |
| B6b | legacy 组属层级违规（语义层直接引用第 1 层原子色 `blue7`/`blue1`/`blue3`） | `StatusColors.swift:63-77` | FR-1 | #2 |
| B6c | 新体系缺 `*Border` 档，这是 `Badge` 仍留在 legacy 的直接原因 | `Badge.swift:142-143,156-157` | FR-1 | #2 |
| B7a | `CoreGradient` 全仓零采用（仅自身 Preview + 一个空测试） | 全仓 grep | FR-5 | #6 |
| B7b | 三个 `static var` 每次求值新建 `AnyShapeStyle` box，放 body 里每帧重新装箱 | `CoreGradient.swift:21,37,53` | FR-5 | #6 |
| B7c | 文件位于 `Colors/` 而非 `Tokens/`，与 CLAUDE.md「渐变 token 层」定位不符 | 同上 | FR-5 | #6 |
| B8a | `MenuButtonStyleModifier` 两分支重复且重写了 `TelegramGlassButtonModifier` 的同一结构 | `MenuButton.swift:87-118` vs `TelegramGlassButtonModifier.swift:47-63` | FR-4 | #5 |
| B8b | 两个 `BannerStyle.makeBody` 11 行里只有最后一行不同 | `Banner.swift:177-192,210-225` | FR-4 | #10 |
| B8c | `CommentCard` 手写了 `.surface(.card)` 已提供的三件套（逐 token 一致） | `CommentCard.swift:93-101` | FR-5 | #6 |
| B8d | `RefPill` 同型手写 surface 三件套 | `RefPill.swift:51-56` | FR-5 | #6 |
| B8e | `ToastLevel` 与 `MessageLevel` case 集合完全相同却是两个类型 | `Toast.swift:24-29`、`Banner.swift:32-37` | FR-4 | #10 |
| B8f | 各组件带 2–4 个平行 switch（`StateLabel` 4 个、`StatusRow` 3 个） | `StateLabel.swift:65-109`、`StatusRow.swift:66-91` | FR-4 | #10 |
| B8g | `SegmentedControl` 两处 glass 分支各自复制 overlay | `SegmentedControl.swift:121-147,379-409` | FR-4 | #10 |
| B8h | `BottomInputBarModifier.body` 78 行（唯一超 50 行）；两个 `onChange` 逻辑同构；chip 样式重复 | `BottomInputBar.swift:361-438,416-437,297-308,374-381` | FR-4 | #6 |
| B9a | `BookCover` 在 body 里做 `UIImage`/`NSImage` 解码，列表滚动反复解码 | `BookCover.swift:74,95-106` | FR-5 | #6 |
| B9b | `TimelineItem` 手写旧式 `EnvironmentKey`（10 行）而同仓已用 `@Entry`（3 行） | `TimelineItem.swift:10-19` | FR-5 | #6 |
| B9c | `bordered(color:)` 是死重载；两重载全默认参数导致裸写 `.bordered()` 构成歧义 | `BorderModifier.swift:26-33` | FR-5 | #6 |
| B9d | `@available(iOS 26.0, *)` 恒真无效（部署目标已 iOS 26+） | `SegmentedControl.swift:205,301` | FR-5 | #6 |
| B9e | `CheckBox` 是硬编码 `Toggle("哈哈哈哈哈")` 的演示视图，用 `@State` 而非 `@Binding`，唯一使用者是同文件 Preview | `CheckBox.swift:53-59` | FR-2 | #3 |
| B9f | `CheckBox.makeBody` 的 `@MainActor @preconcurrency` 冗余（协议声明已携带隔离） | `CheckBox.swift:25` | FR-5 | #6 |
| B9g | `EmptyState.swift` 237 行全文件已废弃，同一 deprecated message 重复 6 次 | `EmptyState.swift:54,141,153,182,203,216` | FR-5 | #6 |

## 簇 C · 质量保障基建

| ID | 缺陷 | 证据 | FR | Issue |
|---|---|---|---|---|
| C1 | ✅ **已修复**（GitHub #92）——`.github/workflows/ci.yml` 落地，3 job（SwiftPM ×2 trait 模式 / iOS Simulator / 下游 API probe）在 `macos-26` 上全绿。runner 具备 Xcode 26.5 + iOS 26 runtime，无需降级。原缺陷：`.github/workflows/` 是空目录，无任何 CI | `ls .github/workflows/` | FR-6 | #1 |
| C2 | 约 3/4 测试是恒真断言（编译通过即必过） | `ProgressIndicatorTests`、`FloatingGlassModifierTests`、`StatusColorsTests`、`SurfaceKindTests`、`AvatarTests` | FR-6 | #7 |
| C3 | `SnapshotTests.swift` 是空 subclass；脚本每次 `rm -rf` 全量重生成；PNG 是插图非 baseline | `App/Tests/SnapshotTests.swift`、`scripts/run-snapshots.sh` | — | 记录不修（Out of Scope：视觉回归走 agent 审美） |
| C4a | Blossom trait 核心行为无测试：`--traits Blossom` 与默认跑同样断言 | `swift test --traits Blossom` 输出 | FR-6 | #7 |
| C4b | 现有 Blossom asset guard 未覆盖分流同样依赖的 `violet-0…9` 与 `cyan-1` | `CoreDesignTests.swift:21-37` | FR-6 | #7 |
| C5 | 零测试文件：`CheckBox`、`Form`、`MenuButton`、四个 ButtonStyle、`ButtonRoleStyleRole`、全部 token 层（仅 `CoreButtonMetrics` 有）、全部 modifier、`StarShape`、`ColorExtension` | `ls Tests/CoreDesignTests/` | FR-6 | #7 |
| C6a | 无版本 tag，README 让下游 `branch: "main"`。**tag 部分已完成**：`v0.1.0` 已打在 `43b71e2`（修复前基线，四种模式验证绿、零 warning）；剩余工作是 README 改为 pin tag | `git tag -l` 曾为空；现有 `v0.1.0` | FR-7 | #11 |
| C6b | README 称「15 documented components」但实际 24 个组件目录 / 26 个 Preview | `README.md` | FR-6 | #11 |
| C7a | ✅ **已修复**（GitHub #92）——两个 target 均启用 `.defaultIsolation(MainActor.self)`；fallout 用 `nonisolated` 处理，共 14 个类型：2 处库内编译 fallout（`CoreSpacing`/`CoreRadius`）+ 9 个公开类型（7 个显式 `Sendable` + `ToastDefaults`/`CoreBorderWidth` 两个常量命名空间，由 checkpoint 评审发现的公开 API 契约破坏）+ 3 个 token 枚举（`CoreTypography`/`CoreControlMetrics`/`CoreButtonMetrics`，由 PR 评审发现）。**唯一无法标注的是 `CoreElevation`**——见下方边界说明。原缺陷：`Package.swift` 无 `swiftSettings`，未启用 `defaultIsolation` | `Package.swift` | FR-6 | #1 |
| C7b | ✅ **已修复**（GitHub #92）——改为 `.iOS(.v26)` / `.macOS(.v26)`，工具链接受，计划中的回退分支未触发。原缺陷：`.iOS("26.0")` 用字符串形式而非枚举 case | `Package.swift:9` | FR-6 | #1 |
| C8 | 无 lint/format 配置，而 CLAUDE.md 规定的「显式 `self.`」恰是 SwiftLint 可强制的规则 | 根目录 | — | 记录不修（本轮不引入新工具链，另开一轮） |
| C9a | ✅ **已修复**（GitHub #92）——`xcodeVersion` 改为 `"26.0"`，`.xcodeproj` 已随之重新生成。原缺陷：与 iOS 26.0 部署目标自相矛盾 | `App/project.yml` | FR-6 | #1 |
| C9b | ✅ **已修复**（GitHub #92）——`App/project.yml` 加 `traits: ["Blossom"]`，需 xcodegen ≥ 2.46.0（2.45.4 会静默忽略）。已验证 `-DBlossom` 真实传到编译器，非仅声明存在。取舍与还原路径见 `updates/92/ci-decision.md`。原缺陷：预览宿主未声明 `traits` | `App/project.yml` | FR-6 | #1 |
| C10a | 缺 LICENSE | 根目录 | FR-6 | #11 |
| C10b | 缺 CHANGELOG | 根目录 | — | 记录不修（无版本契约，CHANGELOG 无意义） |
| C10c | `.gitignore` 中 `.superpowers/` 重复两次 | `.gitignore` | FR-6 | #11 |
| C10d | `.claude/`、`.agents/`、`AGENTS.md` 状态悬空（既未 ignore 也未 tracked） | `git status` | FR-6 | #11 |

## 簇 D · 一致性与可访问性

| ID | 缺陷 | 证据 | FR | Issue |
|---|---|---|---|---|
| D1a | `BottomInputBar` 三个 icon-only 按钮零可访问性标签 | `BottomInputBar.swift:150,160,172`（全文件 accessibility 出现 0 次） | FR-7 | #8 |
| D1b | `UnderlinedTabItem` 未暴露选中态（同仓 `SegmentedControl`/`Sidebar` 都正确加了） | `UnderlinedTabBar.swift:143` | FR-7 | #8 |
| D1c | `Form` 装饰性图标未 `accessibilityHidden`；`DangerIcon` 承载语义却无 label | `Form.swift:27,78,95` | FR-7 | #8 |
| D2 | 硬编码中文 UI 字符串，与别处英文不一致；全库无 String Catalog | `Toast.swift:441`、`MenuButton.swift:139,169`、`BookCover.swift:23` | FR-7 | #9 |
| D3 | 7 处绕过 `CoreTypography` 直接用系统字号（**「处」按调用簇计**，非按行：`RefPill` 的 5 行同类调用计为 1 处，`BottomInputBar` 的 2 行分属两个上下文计为 2 处；按行数则为 11 行 / 6 文件） | `AvatarGroup.swift:59`、`StatusRow.swift:46`、`StateLabel.swift:50`、`CommentCard.swift:56`、`RefPill.swift:34,37,40,42,45`、`BottomInputBar.swift:302,376` | FR-3 | #4 |
| D4 | `public let` 存储属性冻结内部布局（而 `Tag`/`SearchField`/`Sidebar*`/`ListRow`/`Badge` 都保持 private） | `ProgressBar.swift:22-24`、`StatusRow.swift:32-34`、`StateLabel.swift:39-40`、`CommentCard.swift:27-31`、`EventRow.swift:23-26`、`TimelineItem.swift:39-40`、`AvatarGroup.swift:23` | FR-7 | #10 |
| D5 | 语义枚举协议不一致（部分 `Sendable, Equatable`，部分不是） | `Banner.swift:32`、`ButtonRoleStyleRole.swift:11`、`MenuButton.swift:77`、`SurfaceKind` | FR-7 | #10 |
| D6a | 三个同类 pill 组件三种 init 形态 | `StateLabel.swift:42`、`Badge.swift:83`、`Tag.swift:80` | FR-7 | #10 |
| D6b | 部分组件只收 `String`，无法插图标或富文本 | `StateLabel`、`StatusRow`、`EventRow`、`SidebarNavigationRow` | FR-7 | #10 |
| D7 | `SegmentedControl` 的 `glass: Bool` 是布尔 hack，有真实多外观需求应升级为 style 协议 | `SegmentedControl.swift:27,33` | FR-4 | #10 |
| D8 | `BorderModifier` 用 `stroke` 而非全仓约定的 `strokeBorder`；`cornerRadius: 0` 写成 `RoundedRectangle` 误导；写死矩形无法用于 Capsule | `BorderModifier.swift:20` | FR-5 | #6 |
| D9 | `Banner.swift` 直接放 `Components/` 根目录，其余组件都是 `Components/<Name>/<Name>.swift` | — | FR-7 | #11 |
| D10 | `CoreRadius.full = 9999` 是死 token，所有 pill 场景都用 `Capsule()` | `CoreRadius.swift:59` | FR-5 | #6 |
| D11 | `danger = .red4` 而同组全用 5 档，但其 Active/Hover 又按 5 档基准配，致 hover 反差大一档（`ButtonRoleStyleRole.danger` 走此值，是真实渲染差异） | `FunctionalColor.swift:44` | FR-1 | #2 |
| D12 | 硬编码数值本应引用 token | `MenuButton.swift:136,146`、`TimelineItem.swift:74,99-104`、`CommentCard.swift:59`、`BottomInputBar.swift:221`、`AvatarGroup.swift:33-40,76-85` | FR-7 | #11 |
| D13 | 层级违规：语义层直接引用第 1 层原子色而非同层别名 | `BorderColors.swift:53`、`InteractionColors.swift:32` | FR-1 | #2 |
| D14 | Blossom 下 accent 语义漂移：侧栏选中粉、focus ring 蓝、accent 状态色蓝；注释与代码不符 | `BorderColors.swift:46-54`（含 `:50` 注释）、`StatusColors.swift:13-19` | FR-1 | #2 |
| D15 | `FillColors` 平台分支缺 `#else`，与同层两个桥接文件写法不一致；两条件皆不成立时无 return | `FillColors.swift:16-23,30-37,44-51,58-65` | FR-7 | #11 |
| D16a | `StateLabel` 文档只列 4 个 style 而枚举实际 6 个 | `StateLabel.swift:28` vs `:14-21` | FR-7 | #11 |
| D16b | CLAUDE.md 称 `.focusedExternally` 是 `Utils/` 通用辅助，实际是 `BottomInputBar` 内的 private extension | `BottomInputBar.swift:200-212` | FR-7 | #11 |
| D17 | `StarShape` public 但除自身 Preview 外零引用 | `StarShape.swift:10` | — | 记录不修（可能为下游预留，本轮仅记录） |
| D18 | `Sidebar`（391 行 / 6 个 public 组件）与两个 public modifier 无 `#Preview` | `Sidebar.swift`、`FloatingGlassModifier.swift`、`TelegramGlassButtonModifier.swift` | FR-7 | #11 |
| D19 | **已改判（#93 执行时横向比对发现）**：不是 accent 单组笔误，而是**五组全部如此**——`accent`/`success`/`attention`/`danger`/`done` 的 `*-emphasis` light 值逐组等于同组 `*-muted`，而 Primer 语义里 emphasis 应是饱和实色（各组 `fg` 同色系）。原判「随 `statusAccent*` 整组删除而消解」也不成立：删 accent 与 B6a 冲突（见 B6a 行）。处置改为**修正五组 emphasis 的 light 值**并保留 accent | 五组 `status-*-emphasis` vs `status-*-muted` 的 Contents.json | FR-1 | #2 |

---

## 统计

- 总计 **83 项**（数据行计）
- 计划修复 **79 项**
- 记录不修 **4 项**：

| ID | 不修理由 | 对应 PRD 依据 |
|---|---|---|
| C3 | 视觉回归策略已定为「只生成 + agent 审美」 | Out of Scope 第 1 条 |
| ~~C6a~~ | ~~不管下游，不建立版本契约~~ —— **已改为处理**，见上表（`v0.1.0` 已打，README pin tag 归 #11） | — |
| C8 | 本轮不引入新工具链 | Out of Scope 第 8 条 |
| C10b | 无版本契约，CHANGELOG 无意义 | Out of Scope 第 3 条 |
| D17 | `StarShape` 可能为下游预留，仅记录 | Out of Scope 第 5 条 |

各 Issue 承载项数：#1=5、#2=12、#3=6、#4=2、#5=8、#6=18、#7=4、#8=3、#9=1、#10=9、#11=**11**，不修 4。合计 **83**。

> C6a 原记「不修」，因 `v0.1.0` 已实际打出而改判为「修」，故 #11 由 10 增至 11、不修由 5 减至 4。
