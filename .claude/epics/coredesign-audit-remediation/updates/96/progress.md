# Issue #96 按钮体系 + Sidebar 收敛 — 完成记录

分支 `issue-96-buttons-sidebar`（base `epic/coredesign-audit-remediation`）。承载 8 个审计项：B2b、B3a–e、B5、B8a。

## 做了什么

| 审计项 | 改动 |
|---|---|
| B3a | 三态取色收敛为 `ButtonRoleStyleRole.resolvedColor(isEnabled:isPressed:)`，三个 style 的私有实现删除 |
| B3d | font / padding / contentShape 提为 `Modifier/ButtonChromeModifier.swift`，以 `buttonChrome(shape:controlSize:)` 暴露（**有意 internal**） |
| B3c | 两个 background modifier 合并为 `Modifier/ButtonBackgroundModifier.swift`，以 `buttonBackground(...)` 暴露 |
| B3b | Solid / Light 的共同结构提为 `let base`，两支各剩尾部背景层差异 |
| B3e | `CircularGlassButtonStyle` 改用显式 `size: ControlSize = .large` + `diameter: CGFloat?`，直径 38→40 |
| B5 | `Sidebar` 四 row 收敛为 `SidebarRow` 共享骨架 + 薄封装，public 签名逐字不变 |
| B2b | 四处 `frame(height:)` → `minHeight`，随骨架收敛一并落地 |
| B8a | `TelegramGlassButtonModifier` 参数化（`border` / `pressFeedback`），`CoreMenuButtonStyleModifier` 两分支改为复用它 |

## 两个硬指标：实测与预测精确吻合

```
SidebarRow 31 / Navigation 13 / Utility 20 / Document 17 / Tag 18
TOTAL = 99          (基线 118，上限 100)
CoreTypography row body 内 = 8   (基线 11，上限 8)   范围外 = 5
```

**这两个指标在计划阶段被改过两次**，值得后续 Issue 引以为戒：

- **SC-8 原写「四种 row ≤60 行」不可达。** 第一轮以为是口径拼错——96.md 把测量边界扩成「含骨架与 init」却沿用 body-only 推导的 60（光四个 `public init` + 14 个 `private let` + 结构声明就约 79 行）。改回 body-only 后实测仍是 99 vs 60。真相：PRD 的「约 120 → 约 50」里，**118 是实测、50 是拍的**，从未对照真实设计验算。穷尽退路（删光注释空行 85 / 排除骨架 68 / 两者都做 63）全部超标，唯一能压进 60 的做法是折行凑数。经用户确认按实测重定为 **≤100**。
- **`CoreTypography` 原写「16 → 约 6」同样不可达。** 16 处里有 **5 处在本任务范围外**（`SidebarSection` 的 `:49 :54 :64`、`SidebarStatusFooter` 的 `:330 :334`，B5 不碰这两个类型），且 6 在结构上就到不了——四 row 的 leading/trailing 字号本就各不相同。重述为「row body 内 11 → ≤8」。

**教训**：epic 分解阶段写下的量化验收指标，若没人对着真实结构验算过，执行期一定会撞上。后续 Issue 的数字型 AC 应在计划阶段就实测一次。

## 三处受控变化（观感/交互非零回归）

1. **`CircularGlassButtonStyle` 直径 38 → 40**，`BottomInputBar` 的 send / stop / shuffle 三处同步。意外佐证：`CoreMenuButton.swift` 的 `controlSize` 注释本就写着「与输入栏 trailing 圆形按钮保持视觉等高」并取 40——**两者本来就是错位的**，改成 40 恰好修好。
2. **`CoreBorderlessButtonStyle` 字号**从「继承环境字体」变为「随 `controlSize`」。
3. **`CoreBorderlessButtonStyle` 命中区**从「带 padding 的矩形」变为「胶囊」——`buttonChrome` 给它加了原本没有的 `contentShape`。**这是交互变化不是视觉变化**，冒烟须实点边角。

第 2、3 条的根因：**B3d 的前提陈述对 `CoreBorderlessButtonStyle` 不成立**。96.md 写「font/padding/contentShape 四行……共出现 5 次」且逐字相同，但该类型的 `makeBody` 实际**只有两行 padding**，既无 `font` 也无 `contentShape`（96.md 引的 `:43-46` 坐标还落在 doc 注释里）。本任务按 B3d 的**意图**（统一 chrome）执行，故产生这两处变化。已在类型 doc 注释与 `audit-checklist.md` 的 B3d 行写明，避免后续审计对账误判为实现越界。

## B3e 为何不接 `@Environment(\.controlSize)`

B3e 字面要求「接入 `@Environment(\.controlSize)`」，本任务实施为**显式 `size` 档位**，满足其意图而非字面。三个方案的取舍：

- **老实读环境**：5 个调用点（`AsyncButton:223`、`BottomInputBar:153,165,177`、`Previews:312`）**全都没设 `controlSize`**，读到默认的 `.regular` → 32pt，即 38→32 的明显回归。补 `.controlSize(.large)` 需改 `BottomInputBar.swift`——#97 的自有文件，破坏 005 ∩ 006 = ∅。
- **忽略 `.regular` 按 `.large` 解释**：`.controlSize(.regular)` 不只是「未设置的默认值」，也是**合法的显式取值**。下游刻意写它期待 32pt 却静默得 40pt，且无诊断——**永久的公开 API 陷阱**。
- **采纳：档位存在 style 自身**。默认 40 落在 metrics 序列内、5 个调用点一行不改、无特例、无 API 意外。

若日后要跟随环境，那是一次干净的独立改动（连同调用点补 `.controlSize(.large)`），届时 `BottomInputBar.swift` 的归属也已释放。

## 给 #95 的交接（本任务存在的主要理由）

- **`CoreControlMetrics.font(for:)` 在按钮体系内的调用点从 4 处降到 0**，唯一调用点在 `Modifier/ButtonChromeModifier.swift:25`。#95 把它换成 `fontToken(for:)` + `.coreFont()` 时只需改**一行**。
- **但全库不止一处**：`Components/SearchField/SearchField.swift:98` 是按钮体系之外的独立调用点，#95 需单独处理；`Tokens/CoreControlMetrics.swift:25` 是 doc 注释里的用法示例。**验证时务必限定 `Components/Button/` 口径，否则会得 3 行而误以为收敛失败**——本任务的计划评审在这一点上摔过两次。
- **`Sidebar.swift` 的 `CoreTypography` 引用从 16 降到 13**（row body 内 11→8，另 5 处在 `SidebarSection` / `SidebarStatusFooter` 未动）。#95 的 Sidebar 改动面按 8 处算，不是 16。
- **`Sidebar` 的四处固定高度已改 `minHeight`（B2b）**，#95 的布局断言层可以直接假定不裁切。

## 给其它 Issue 的交接

- **#97**：`git diff --name-only | xargs -n1 basename | grep -Fx -f <清单>` 自查通过（`rc=1`），005 ∩ 006 = ∅ 保持。注意**不能用子串 grep**——`EmptyState` / `BottomInputBar` / `CommentCard` / `RefPill` / `SegmentedControl` / `TimelineItem` / `BookCover` 同时是**目录名**，子串匹配会把本任务合法修改的 `Components/BottomInputBar/CoreMenuButton.swift` 判成违规，形成必然假红。
- **#101（D4）**：`CoreBorderlessButtonStyle.swift:74` 的 `public let role` 是 #94 按 A2b 的 AC 新增的样本，已补进 D4 证据列。
- **坐标清扫**：本任务改动了 `CoreMenuButton.swift` 与 `Sidebar.swift` 的行号，已更新 `audit-checklist.md` 的 D2 / D4 / D12 三行、`102.md:35,36`、`99.md:37,87`。

## 工具/环境坑（实测）

- **probe 包的增量构建不拾取新增文件。** 本任务新增 `Modifier/ButtonChromeModifier.swift` 后，`scripts/downstream-probe` 的增量构建报 4 条 `has no member 'buttonChrome'`，而主包 `swift build` 同时是绿的；`swift package clean` 后立即通过。这次是**假红**，但同一机制（增量构建的源文件清单陈旧）同样能产生**假绿**——删掉一个 probe 依赖的公开符号而 `.build` 未更新时它会照常通过。与 CLAUDE.md 记的「新增 colorset 后必须 clean」同类。**probe 验证一律先 clean。**
- **`ButtonStyle.circularGlass(diameter:)` 编译不过**：静态成员定义在 `extension ButtonStyle where Self == CircularGlassButtonStyle` 上，经协议元类型访问报 `static member 'circularGlass' cannot be used on protocol metatype`。probe 里必须走 `.buttonStyle(.circularGlass(...))` 的前导点推断。
- **`grep -c 'Foo('` 会被代理到 ripgrep**，`(` 按正则解析报 unclosed group 并返回 0 匹配。计数含括号的模式要用 `grep -cF`。

## 验证证据

四条 SwiftPM 命令（`swift package clean` 后冷跑）：

```
build          EXIT=0
test           EXIT=0      Test run with 95 tests in 32 suites passed
build-blossom  EXIT=0
test-blossom   EXIT=0      Test run with 95 tests in 32 suites passed
probe(clean)   EXIT=0
```

warning：四份日志各 0 / 12 / 0 / 12 条，**非 EmptyState 者为 0**（那 12 条全是既有的 `EmptyState` deprecation，归 #97）。

SC-3 前置：`grep -rn 'CoreControlMetrics.font(for:' Sources/CoreDesign/Components/Button/` → 0 行。

`audit-checklist.md` 计数 83，八项已标 ✅。
