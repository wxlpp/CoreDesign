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
| A1 | ✅ **已修复**（GitHub #93）——毒丸 commit 穷举出恰好 3 处残留（两种 trait 一致），逐处改写为语义 token 后才删符号。原缺陷：`Color.primary/secondary/tertiary` 遮蔽 SwiftUI 同名成员，模块内本地定义静默胜出。**已确认两处产品代码受害**：(1) `CheckBox.swift:31` 渲染品牌色而非系统 label 色，注释与行为矛盾；(2) `StatusRow.swift:80` 的 `case .skipped: return .secondary` 在返回 `Color` 的上下文中解析到 `FunctionalColor.secondary`（默认 `lightBlue5`、**Blossom 下 `violet5`**），使 skipped 行图标渲染成浅蓝/紫罗兰而非作者意图的系统灰——第 4 轮评审新发现 | `FunctionalColor.swift:11-12`、`CheckBox.swift:21-23,31`、`StatusRow.swift:75-82` | FR-1 | #2 |
| A2a | ✅ **已修复**（GitHub #94）——`CheckBoxToggleStyle` 补 `public`（含显式 `init()` 与 `makeBody`），下游 probe 实测可构造；`CheckBox` 便利视图整类型删除、演示内联进 `#Preview`（B9e 同处理）。原缺陷：`CheckBoxToggleStyle` / `CheckBox` internal，但文档明说业务侧直接使用（实测 `cannot find in scope`） （`CheckBox` 类型已删除，现文件内只余 `CheckBoxToggleStyle`） | `CheckBox.swift:24,52,53` | FR-2 | #3 |
| A2b | ✅ **已修复**（GitHub #94）——`role` 补 `public` 并加显式 `public init(role:)`。下游 probe 反证确认过：去掉 `public` 即复现 `initializer is inaccessible due to 'internal' protection level`。原缺陷：`BorderlessButtonStyle` 的 `role` internal 致 memberwise init 不可达（实测 `initializer is inaccessible`） （现文件 `CoreBorderlessButtonStyle.swift`；`public let role` 是 D4 的新样本，是否收回由 #10 判定） | `BorderlessButtonStyle.swift:40,52` | FR-2 | #3 |
| A2c | ✅ **已修复**（GitHub #94）——三个调色板属性补 `public`。反证确认：去掉即报 `'color' is inaccessible due to 'internal' protection level`。原缺陷：`ButtonRoleStyleRole` 的 `color`/`activeColor`/`disabledColor` internal，而 CLAUDE.md 称其为三色「唯一来源」 | `ButtonRoleStyleRole.swift:18,33,48` | FR-2 | #3 |
| A2d | ✅ **已修复**（GitHub #93）——第 4 层已补 `public`，并由 downstream-probe 的公开色彩面消费点守护（反向验证：去掉 `public` 即编译失败）。原缺陷：`FunctionalColor` extension 整层非 public，CLAUDE.md 却称第 4 层是「最高层 API 表面」 | `FunctionalColor.swift:11,35` | FR-1 | #2 |
| A3a | ✅ **已修复**（GitHub #94）——改名为 `CoreBorderlessButtonStyle`（文件同步改名），访问器 `.borderless(role:)` 名称不变故 `App/` 与 docs 示例无需改动。原缺陷：`BorderlessButtonStyle` 与 SwiftUI 同名，下游写该名**能编译**但静默解析到 SwiftUI 版本 **残留**：访问器名 `borderless` 仍与 SwiftUI 的 `PrimitiveButtonStyle.borderless` 重合，`.buttonStyle(.borderless)`（不带括号）仍静默拿 SwiftUI 的——已实测编译通过、零诊断。保留该访问器名是让 `App/`/docs 零改动的有意取舍，已在类型 doc 与 `docs/components/button.md` 写明警告。 | 下游消费包实测 | FR-2 | #3 |
| A3b | ✅ **已修复**（GitHub #94）——`MenuButton` / `MenuButtonStyle` / `MenuButtonStyleModifier` 整族改名为 `CoreMenuButton*`。三者均 internal，改名是模块内可读性与未来公开的前置。原缺陷：`MenuButton` 与 macOS 上 deprecated 的 SwiftUI `MenuButton` 同名，实测报错信息具误导性 （现文件 `CoreMenuButton.swift`） | `MenuButton.swift:128` | FR-2 | #3 |

## 簇 B · 结构性冗余

| ID | 缺陷 | 证据 | FR | Issue |
|---|---|---|---|---|
| B1a | ✅ **已修复**（GitHub #93）——三组色别名整体删除，交互色统一走第 3 层。原缺陷：`FunctionalColor` 与 `InteractionColors` 是同一套色阶两次声明（逐值相同） | `FunctionalColor.swift:12-32` vs `InteractionColors.swift:4-25` | FR-1 | #2 |
| B1b | ✅ **已修复**（GitHub #93）——`#if Blossom` 9 → 8。原缺陷：上述重复带来**两份** `#if Blossom` violet 分流，违反「分流点压到最低」 | `FunctionalColor.swift:17-27`、`InteractionColors.swift:10-20` | FR-1 | #2 |
| B1c | ✅ **已修复**（GitHub #93）——毒丸确认恰好 3 处引用，全部显式改写。原缺陷：`FunctionalColor` 的 primary/secondary/tertiary 组共 **3 处**显式引用，全部是 A1 型遮蔽：`CheckBox.swift:31`、`StatusRow.swift:80`（两处产品代码）、`CoreGradient+Preview.swift:17`（Preview）。三处在删除后都**不报错**而是静默改解析到 SwiftUI 内建成员。该组共 12 个符号（3 基础名 + 9 个 Active/Disable/Hover 变体），其中 10 个（`tertiary` + 全部 9 个变体）除定义外零引用 | `CheckBox.swift:31`、`StatusRow.swift:80`、`CoreGradient+Preview.swift:17` | FR-1 | #2 |
| B2a | 全部 10 个 typography token 用 `.system(size:)`，`relativeTo:` 出现 0 次 | `CoreTypography.swift:53-183` | FR-3 | #4 |
| B2b | ✅ **已修复**（GitHub #96）——随 B5 骨架收敛一并改为 `minHeight`，Sidebar 内四处固定高度已清零。**注意实际收益**：`CoreTypography` 当前全是 `.system(size:)`（`relativeTo:` 0 次），字号不缩放，故「大字号下不裁切」要等 #95 才兑现；今天的真实变化是**长标题换行不再被压出框**。原缺陷：`Sidebar` 四种 row 写死 `frame(height:)`，大字号裁切（`ListRow`/`SearchField` 用的是 `minHeight`） | `Sidebar.swift:121,183,238,287` | FR-3 | #5 |
| B3a | ✅ **已修复**（GitHub #96）——收敛为 `ButtonRoleStyleRole.resolvedColor(isEnabled:isPressed:)`，三个 style 的私有实现删除。原缺陷：三个 ButtonStyle 的 role 三态取色逻辑逐字重复 | `SolidButtonStyle.swift:71-76`、`LightButtonStyle.swift:57-62`、`CoreBorderlessButtonStyle.swift:73-78` | FR-4 | #5 |
| B3b | ✅ **已修复**（GitHub #96）——共同结构提为 `let base`，两支各只剩尾部背景层差异；Light 的按压变暗提到 `Group` 上只写一次。原缺陷：Solid / Light 的 glass 与非 glass 分支整段复制，仅尾部 modifier 不同 | `SolidButtonStyle.swift:38-65`、`LightButtonStyle.swift:27-51` | FR-4 | #5 |
| B3c | ✅ **已修复**（GitHub #96）——合并为 `Modifier/ButtonBackgroundModifier.swift`，以 `buttonBackground(fill:border:isPressed:pressedOpacity:)` 扩展暴露。原缺陷：两个 BackgroundModifier 实质是同一类型 | `SolidButtonStyle.swift:81-99`、`LightButtonStyle.swift:67-83` | FR-4 | #5 |
| B3d | ✅ **已修复**（GitHub #96）——提为 `Modifier/ButtonChromeModifier.swift`（`buttonChrome(shape:controlSize:)`，有意保持 internal）。**注意**：B3d 的「5 次逐字相同」对 `CoreBorderlessButtonStyle` 本不成立（它只有两行 padding，无 font 无 contentShape），按统一 chrome 的意图执行，代价是该样式字号改随 `controlSize`——**仅此一处**受控变化。（曾误记「命中区变胶囊」：实测改造前 `makeBody` 就有 `.clipShape(Capsule(style: .continuous))`，而 `clipShape` 本身即限定命中测试，故命中区本来就是胶囊，`buttonChrome` 补的 `contentShape` 未改变实际行为。）原缺陷：font/padding/contentShape 四行在 4 个 style 里共出现 5 次 | 同上 + `CoreBorderlessButtonStyle.swift:43-46` | FR-4 | #5 |
| B3e | ✅ **已修复**（GitHub #96）——改为显式 `size: ControlSize = .large` 档位 + `diameter: CGFloat?` 覆写，直径 38→40 落入 metrics 序列。**未**接环境 `controlSize`：5 个调用点均未设该值，直接采信会缩到 32；而「忽略 `.regular` 按 `.large` 解释」会让下游刻意写 `.controlSize(.regular)` 时静默得 40，是永久 API 陷阱。原缺陷：`CircularGlassButtonStyle` 写死 diameter 38 且不读 `controlSize`（另三个都读），38 不在 metrics 序列内 | `CircularGlassButtonStyle.swift:16,18` | FR-4 | #5 |
| B4a | ✅ **已修复**（GitHub #97）——`textFieldSize` 声明与 `.getSize` 写入两行删除，实测确为只写不读。原缺陷：`textFieldSize` 写入后从不读取，每次布局白跑 GeometryReader + PreferenceKey 往返 | `BottomInputBar.swift:87,138` | FR-5 | #6 |
| B4b | ✅ **已修复**（GitHub #97）——整文件删除（51 行），唯一消费点即 B4a。原缺陷：`View+SizeReader.swift` 整文件是 B4a 的唯一支撑，删后可整体移除 | `View+SizeReader.swift`（51 行） | FR-5 | #6 |
| B4c | ✅ **已修复**（GitHub #97）——整文件删除（167 行）。原缺陷：`KeyboardHandling.swift` 中 `KeyboardReadable`、`dismissKeyboardOnTap`、`resignFirstResponder`、`becomeFirstResponder` 全仓零引用；`becomeFirstResponder` 泄漏宿主 app 私有通知名且未标 `@MainActor` | `KeyboardHandling.swift:18-76,112-167` | FR-5 | #6 |
| B4d | ✅ **已修复**（GitHub #97）——随 B4c 一并删除，未保留「只为测试而活」的工厂。原缺陷：`KeyboardHeightPublisherFactory` 仅被自身文件内零引用的 `KeyboardReadable` 默认实现（`:60`）与测试消费，无生产调用点 | `KeyboardHandling.swift:60,78-110` | FR-5 | #6 |
| B5 | ✅ **已修复**（GitHub #96）——抽出 `SidebarRow` 共享骨架，四个 public row 退化为薄封装（public init 与成员签名逐字不变）。实测 body 合计 118→**99**（SC-8 上限经实测重定为 100，详见 96.md）。原缺陷：`Sidebar` 四个 row 是同一 row 的四份拷贝（约 120 行可降至 50） | `Sidebar.swift:104-130,157-188,215-243,263-292` | FR-4 | #5 |
| B6a | ✅ **已修复**（GitHub #93）——Banner/Badge/Toast/Form 四处全量迁移，legacy 组删除。原缺陷：`StatusColors` 新旧两套并行 scale，组件随机选边。**#93 执行时发现与 D19 原处置冲突**：新体系只有 `accent` 一个蓝色家族，而它正是 Primer 的 info 语义；Banner/Toast/Badge 用的 legacy `info*` 只能迁到它。故 `statusAccent*` **保留**（原 D19 判「库内零消费点」在迁移后不再成立） | `StatusColors.swift:13-59` vs `:63-77` | FR-1 | #2 |
| B6b | ✅ **已修复**（GitHub #93）——legacy 组删除，层级违规消除。原缺陷：legacy 组属层级违规（语义层直接引用第 1 层原子色 `blue7`/`blue1`/`blue3`） | `StatusColors.swift:63-77` | FR-1 | #2 |
| B6c | ✅ **已修复**（GitHub #93）——新增 4 个 `status-*-border` colorset（沿用 legacy ramp-3 取值），Badge 得以迁移。原缺陷：新体系缺 `*Border` 档，这是 `Badge` 仍留在 legacy 的直接原因 | `Badge.swift:142-143,156-157` | FR-1 | #2 |
| B7a | ✅ **已修复**（GitHub #97）——消费点落在 `CommentCard` 的最小化态 "Show" 按钮（`.foregroundStyle(CoreGradient.brand)`）。**未选 `BookCover`**：其占位背景是 `Color(text: 书名)` 哈希取色，doc 明确记为「同一书名总是同一颜色」的设计约定，换成 brand 渐变会让所有占位封面塌成同一色。默认主题下 `CoreGradient.brand` 即 `AnyShapeStyle(Color.accent)`，逐像素零变化；Blossom 下为真渐变（已截图确认）。原缺陷：`CoreGradient` 全仓零采用（仅自身 Preview + 一个空测试） | 全仓 grep | FR-5 | #6 |
| B7b | ✅ **已修复**（GitHub #97）——三个 `static var` 改 `static let`（闭包 + `()` 形式）。原缺陷：三个 `static var` 每次求值新建 `AnyShapeStyle` box，放 body 里每帧重新装箱 | `CoreGradient.swift:21,37,53` | FR-5 | #6 |
| B7c | ✅ **已修复**（GitHub #97）——`CoreGradient.swift` 与 `CoreGradient+Preview.swift` **两个文件**一并移入 `Tokens/`，CLAUDE.md 路径同步。原缺陷：文件位于 `Colors/` 而非 `Tokens/`，与 CLAUDE.md「渐变 token 层」定位不符 | 同上 | FR-5 | #6 |
| B8a | ✅ **已修复**（GitHub #96）——`TelegramGlassButtonModifier` 参数化（`border` / `pressFeedback`，默认值 = 原行为），两分支改为复用它。`glassInset` 与 `CoreSpacing.xxs` 均为 2，内缩等值故观感不变。原缺陷：`CoreMenuButtonStyleModifier` 两分支重复且重写了 `TelegramGlassButtonModifier` 的同一结构 | `CoreMenuButton.swift:87-118` vs `TelegramGlassButtonModifier.swift:47-63` | FR-4 | #5 |
| B8b | 两个 `BannerStyle.makeBody` 11 行里只有最后一行不同 | `Banner.swift:177-192,210-225` | FR-4 | #10 |
| B8c | ✅ **已修复**（GitHub #97）——改为 `.surface(.card)`。**两处受控变化**：该 modifier 额外施加 `clipShape`（子视图裁到圆角内）、且用 `.continuous` 圆角而非手写默认的 `.circular`。两个 `#Preview` 已截图确认内容未被裁、圆角形状自然。原缺陷：`CommentCard` 手写了 `.surface(.card)` 已提供的三件套（逐 token 一致） | `CommentCard.swift:93-101` | FR-5 | #6 |
| B8d | 🚫 **撤销**（GitHub #97，经用户确认）——**前提不成立**。97.md 称本项与 B8c「同型」，实测 `RefPill` 用 `surfaceCanvasInset` + `borderMuted` + `CoreRadius.small` + 默认 `.circular` 圆角，而**没有任何 `SurfaceKind` 的 background 是 `surfaceCanvasInset`**（`.card` = `surfaceCard`/`.medium`、`.control` = `surfaceInteractive`/`borderSubtle`、`.canvasSubtle` = `surfaceCanvasSubtle`/`.medium`），且 `SurfaceModifier` 一律用 `.continuous`。换任何现有 kind 都会同时改变背景色 + 圆角半径 + 圆角曲线三项，是视觉回归而非重复消除。`surfaceCanvasInset` 与 pill「嵌在正文中的引用标记」定位相符，判定为有意。若日后仍要收敛，需先给 `SurfaceKind` 加 `.inset` case（属加法，本 epic Out of Scope）。原缺陷描述：`RefPill` 同型手写 surface 三件套 | `RefPill.swift:51-56` | FR-5 | #6 |
| B8e | `ToastLevel` 与 `MessageLevel` case 集合完全相同却是两个类型 | `Toast.swift:24-29`、`Banner.swift:32-37` | FR-4 | #10 |
| B8f | 各组件带 2–4 个平行 switch（`StateLabel` 4 个、`StatusRow` 3 个） | `StateLabel.swift:65-109`、`StatusRow.swift:66-91` | FR-4 | #10 |
| B8g | `SegmentedControl` 两处 glass 分支各自复制 overlay | `SegmentedControl.swift:121-147,379-409` | FR-4 | #10 |
| B8h | ✅ **已修复**（GitHub #97）——`body` 78 → **24 行**，拆出 `suggestionsBar` / `inputBar` 两个计算属性；chip 样式收敛为文件级 `bottomInputBarChip()`。**两个 `onChange` 未合并**——97.md 称其「同构」，实测 show 条件相同但 **hide 条件不同**且都含隐含的「不做」第三分支；按原签名合并会让「autoShow 关闭 + suggestions 非空 + 用户已手动展开」时数组更新被强制收起。只收敛了动画包装（`setSuggestionsVisible`）。原缺陷：`BottomInputBarModifier.body` 78 行（唯一超 50 行）；两个 `onChange` 逻辑同构；chip 样式重复 | `BottomInputBar.swift:361-438,416-437,297-308,374-381` | FR-4 | #6 |
| B9a | ✅ **已修复**（GitHub #97）——改为 `BookCoverImageCache`（`NSCache` + **同步**查表）。**不用** `@State` + `.task(id:)`：`.task` 在首帧之后才执行，会让每个 cell 先闪一下占位彩块、且 `data` 切换时有一个 runloop 渲染上一本书的封面——用「优化滚动」的名义换来滚动时闪烁，方向反了。同步查表首帧即命中，重复解码同样被消除。原缺陷：`BookCover` 在 body 里做 `UIImage`/`NSImage` 解码，列表滚动反复解码 | `BookCover.swift:74,95-106` | FR-5 | #6 |
| B9b | ✅ **已修复**（GitHub #97）——10 行手写 `EnvironmentKey` 改为 3 行 `@Entry`；`TimelineItemTests.swift:32` 同步改为断言 `EnvironmentValues().timelineDepth == 0`。原缺陷：`TimelineItem` 手写旧式 `EnvironmentKey`（10 行）而同仓已用 `@Entry`（3 行） | `TimelineItem.swift:10-19` | FR-5 | #6 |
| B9c | ✅ **已修复**（GitHub #97）——删除 `bordered(color:)` 死重载，`bordered` 现只剩一个。原缺陷：`bordered(color:)` 是死重载；两重载全默认参数导致裸写 `.bordered()` 构成歧义 | `BorderModifier.swift:26-33` | FR-5 | #6 |
| B9d | ✅ **已修复**（GitHub #97）——删除两处恒真的 `@available(iOS 26.0, *)`；`:222` 的 `@available(*, unavailable)` 是有意的不可用标记，**保留**。原缺陷：`@available(iOS 26.0, *)` 恒真无效（部署目标已 iOS 26+） | `SegmentedControl.swift:205,301` | FR-5 | #6 |
| B9e | ✅ **已修复**（GitHub #94）——随 A2a 一并处理：`CheckBox` 类型删除，演示改为 `#Preview` 内 `@Previewable @State` + `Toggle(...).toggleStyle(CheckBoxToggleStyle())`。原缺陷：`CheckBox` 是硬编码 `Toggle("哈哈哈哈哈")` 的演示视图，用 `@State` 而非 `@Binding`，唯一使用者是同文件 Preview | `CheckBox.swift:53-59` | FR-2 | #3 |
| B9f | ✅ **已修复**（GitHub #97）——删除冗余的 `@MainActor @preconcurrency`。原缺陷：`CheckBox.makeBody` 的 `@MainActor @preconcurrency` 冗余（协议声明已携带隔离） | `CheckBox.swift:32` | FR-5 | #6 |
| B9g | ✅ **已修复**（GitHub #97）——整文件删除（237 行）及其自证测试；`docs/README.md` 索引行改为墓碑指引；`docs/components/empty-state.md` 改写为墓碑文档（保留迁移指引，非删除——见 progress.md 第 3 条）。基线的 12 条 warning 随之归零。原缺陷：`EmptyState.swift` 237 行全文件已废弃，同一 deprecated message 重复 6 次 | `EmptyState.swift:54,141,153,182,203,216` | FR-5 | #6 |

## 簇 C · 质量保障基建

| ID | 缺陷 | 证据 | FR | Issue |
|---|---|---|---|---|
| C1 | ✅ **已修复**（GitHub #92）——`.github/workflows/ci.yml` 落地，3 job（SwiftPM ×2 trait 模式 / iOS Simulator / 下游 API probe）在 `macos-26` 上全绿。runner 具备 Xcode 26.5 + iOS 26 runtime，无需降级。原缺陷：`.github/workflows/` 是空目录，无任何 CI | `ls .github/workflows/` | FR-6 | #1 |
| C2 | 约 3/4 测试是恒真断言（编译通过即必过） | `ProgressIndicatorTests`、`FloatingGlassModifierTests`、`StatusColorsTests`、`SurfaceKindTests`、`AvatarTests` | FR-6 | #7 |
| C3 | `SnapshotTests.swift` 是空 subclass；脚本每次 `rm -rf` 全量重生成；PNG 是插图非 baseline | `App/Tests/SnapshotTests.swift`、`scripts/run-snapshots.sh` | — | 记录不修（Out of Scope：视觉回归走 agent 审美） |
| C4a | Blossom trait 核心行为无测试：`--traits Blossom` 与默认跑同样断言 | `swift test --traits Blossom` 输出 | FR-6 | #7 |
| C4b | 现有 Blossom asset guard 未覆盖分流同样依赖的 `violet-0…9` 与 `cyan-1` | `CoreDesignTests.swift:21-37` | FR-6 | #7 |
| C5 | 零测试文件：`CheckBoxToggleStyle`、`Form`、`CoreMenuButton`、四个 ButtonStyle、`ButtonRoleStyleRole`、全部 token 层（仅 `CoreButtonMetrics` 有）、全部 modifier、`StarShape`、`ColorExtension` | `ls Tests/CoreDesignTests/` | FR-6 | #7 |
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
| D1a | `BottomInputBar` 三个 icon-only 按钮零可访问性标签 | `BottomInputBar.swift:148,158,170`（全文件 accessibility 出现 0 次） | FR-7 | #8 |
| D1b | `UnderlinedTabItem` 未暴露选中态（同仓 `SegmentedControl`/`Sidebar` 都正确加了） | `UnderlinedTabBar.swift:143` | FR-7 | #8 |
| D1c | `Form` 装饰性图标未 `accessibilityHidden`；`DangerIcon` 承载语义却无 label | `Form.swift:27,78,95` | FR-7 | #8 |
| D2 | 硬编码中文 UI 字符串，与别处英文不一致；全库无 String Catalog | `Toast.swift:441`、`CoreMenuButton.swift:131,161`、`BookCover.swift:23` | FR-7 | #9 |
| D3 | 7 处绕过 `CoreTypography` 直接用系统字号（**「处」按调用簇计**，非按行：`RefPill` 的 5 行同类调用计为 1 处，`BottomInputBar` 的 2 行分属两个上下文计为 2 处；按行数则为 11 行 / 6 文件） | `AvatarGroup.swift:59`、`StatusRow.swift:46`、`StateLabel.swift:50`、`CommentCard.swift:56`、`RefPill.swift:34,37,40,42,45`、`BottomInputBar.swift:302,376` | FR-3 | #4 |
| D4 | `public let` 存储属性冻结内部布局（而 `Tag`/`SearchField`/`Sidebar*`/`ListRow`/`Badge` 都保持 private） | `ProgressBar.swift:22-24`、`StatusRow.swift:32-34`、`StateLabel.swift:39-40`、`CommentCard.swift:27-31`、`EventRow.swift:23-26`、`TimelineItem.swift:39-40`、`AvatarGroup.swift:23` 、`CoreBorderlessButtonStyle.swift:74`（#94 按 A2b 的 AC 新增，是否收回由 #10 判定） | FR-7 | #10 |
| D5 | 语义枚举协议不一致（部分 `Sendable, Equatable`，部分不是） | `Banner.swift:32`、`ButtonRoleStyleRole.swift:11`、`CoreMenuButton.swift:77`、`SurfaceKind` | FR-7 | #10 |
| D6a | 三个同类 pill 组件三种 init 形态 | `StateLabel.swift:42`、`Badge.swift:83`、`Tag.swift:80` | FR-7 | #10 |
| D6b | 部分组件只收 `String`，无法插图标或富文本 | `StateLabel`、`StatusRow`、`EventRow`、`SidebarNavigationRow` | FR-7 | #10 |
| D7 | `SegmentedControl` 的 `glass: Bool` 是布尔 hack，有真实多外观需求应升级为 style 协议 | `SegmentedControl.swift:27,33` | FR-4 | #10 |
| D8 | ✅ **已修复**（GitHub #97）——`stroke` → `strokeBorder`（描边改向内画，与全仓其余描边一致），并把形状泛型化为 `InsettableShape`（原写死 `RoundedRectangle(cornerRadius: .none)`，无法用于 `Capsule`）。唯一生产消费点 `Banner.swift:223` 已截图确认。原缺陷：`BorderModifier` 用 `stroke` 而非全仓约定的 `strokeBorder`；`cornerRadius: 0` 写成 `RoundedRectangle` 误导；写死矩形无法用于 Capsule | `BorderModifier.swift:20` | FR-5 | #6 |
| D9 | `Banner.swift` 直接放 `Components/` 根目录，其余组件都是 `Components/<Name>/<Name>.swift` | — | FR-7 | #11 |
| D10 | ✅ **已修复**（GitHub #97）——删除死 token，并同步 **7 处** doc/文档引用（`CoreRadius.swift`、`Avatar`、`Badge` ×2、`Tag`、`docs/components/button.md`、`badge.md`）改指 `Capsule()`。原缺陷：`CoreRadius.full = 9999` 是死 token，所有 pill 场景都用 `Capsule()` | `CoreRadius.swift:59` | FR-5 | #6 |
| D11 | ✅ **已修复**（GitHub #93）——`danger` 基准 `red4` → `red5`。原缺陷：`danger = .red4` 而同组全用 5 档，但其 Active/Hover 又按 5 档基准配，致 hover 反差大一档（`ButtonRoleStyleRole.danger` 走此值，是真实渲染差异） | `FunctionalColor.swift:44` | FR-1 | #2 |
| D12 | 硬编码数值本应引用 token | `CoreMenuButton.swift:128,138`、`TimelineItem.swift:74,99-104`、`CommentCard.swift:59`、`BottomInputBar.swift:219`、`AvatarGroup.swift:33-40,76-85` | FR-7 | #11 |
| D13 | ✅ **已修复**（GitHub #93）——`borderSelected` / `selectionBackgroundEmphasis` 改走同层别名。原缺陷：层级违规：语义层直接引用第 1 层原子色而非同层别名 | `BorderColors.swift:53`、`InteractionColors.swift:32` | FR-1 | #2 |
| D14 | ✅ **已修复**（GitHub #93）——`borderFocus` → `.accent`，与 `borderSelected` 真正同源；矛盾注释已重写。原缺陷：Blossom 下 accent 语义漂移：侧栏选中粉、focus ring 蓝、accent 状态色蓝；注释与代码不符 | `BorderColors.swift:46-54`（含 `:50` 注释）、`StatusColors.swift:13-19` | FR-1 | #2 |
| D15 | `FillColors` 平台分支缺 `#else`，与同层两个桥接文件写法不一致；两条件皆不成立时无 return | `FillColors.swift:16-23,30-37,44-51,58-65` | FR-7 | #11 |
| D16a | `StateLabel` 文档只列 4 个 style 而枚举实际 6 个 | `StateLabel.swift:28` vs `:14-21` | FR-7 | #11 |
| D16b | ✅ **已修复**（GitHub #97 顺带）——Task 1 删除 `.getSize` 后重写了 CLAUDE.md《Modifier 约定》整句，现准确区分「跨组件复用的纯辅助扩展放 `Utils/`（目前仅 `ColorExtension.swift`）」与「只服务单个组件的辅助扩展与组件同文件（如 `.focusedExternally` 在 `BottomInputBar.swift`）」。**本项原属 #102**，因与 B4b 的文档连带义务落在同一句话上而一并处理。原缺陷：CLAUDE.md 称 `.focusedExternally` 是 `Utils/` 通用辅助，实际是 `BottomInputBar` 内的 private extension | `BottomInputBar.swift:200-212` | FR-7 | #11 |
| D17 | `StarShape` public 但除自身 Preview 外零引用 | `StarShape.swift:10` | — | 记录不修（可能为下游预留，本轮仅记录） |
| D18 | `Sidebar`（391 行 / 6 个 public 组件）与两个 public modifier 无 `#Preview` | `Sidebar.swift`、`FloatingGlassModifier.swift`、`TelegramGlassButtonModifier.swift` | FR-7 | #11 |
| D19 | ✅ **已修复**（GitHub #93）——五组 emphasis 的 light 值修正为各组 fg 同色，读回断言验证。原缺陷：**已改判（#93 执行时横向比对发现）**：不是 accent 单组笔误，而是**五组全部如此**——`accent`/`success`/`attention`/`danger`/`done` 的 `*-emphasis` light 值逐组等于同组 `*-muted`，而 Primer 语义里 emphasis 应是饱和实色（各组 `fg` 同色系）。原判「随 `statusAccent*` 整组删除而消解」也不成立：删 accent 与 B6a 冲突（见 B6a 行）。处置改为**修正五组 emphasis 的 light 值**并保留 accent | 五组 `status-*-emphasis` vs `status-*-muted` 的 Contents.json | FR-1 | #2 |

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
