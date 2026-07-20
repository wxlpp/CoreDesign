# Issue #97 死代码清理与现代化 — 完成记录

分支 `issue-97-dead-code`（base `epic/coredesign-audit-remediation`）。承载 **17 项实施 + 1 项撤销**（原列 18 项）。

## 做了什么

| 项 | 改动 |
|---|---|
| B9g | `EmptyState.swift` 整文件删除（237 行）+ 自证测试 + `docs/README.md` 索引行 + `docs/components/empty-state.md` |
| B4a | `BottomInputBar` 的 `textFieldSize` 声明与 `.getSize` 写入两行删除（实测确为只写不读） |
| B4b | `View+SizeReader.swift` 整文件删除（51 行） |
| B4c/B4d | `KeyboardHandling.swift` 整文件删除（167 行）+ 其测试，未保留「只为测试而活」的 `KeyboardHeightPublisherFactory` |
| B7a | `CommentCard` 最小化态的 "Show" 按钮改用 `CoreGradient.brand` —— 渐变 token 层的首个生产消费点 |
| B7b | 三个 `static var` → `static let`（闭包 + `()`） |
| B7c | `CoreGradient.swift` 与 `CoreGradient+Preview.swift` **两个文件**移入 `Tokens/` |
| B8c | `CommentCard` 三件套 → `.surface(.card)` |
| B8h | `BottomInputBarModifier.body` **78 → 24 行**，拆出 `suggestionsBar` / `inputBar`，chip 收敛为 `bottomInputBarChip()` |
| B9a | `BookCover` 解码改为 `BookCoverImageCache`（`NSCache` + 同步查表）——见下方 checkpoint 评审第 1 条 |
| B9b | `TimelineItem` 的手写 `EnvironmentKey` → `@Entry`（10 行 → 3 行），测试同步 |
| B9c | 删 `bordered(color:)` 死重载 |
| D8 | `BorderModifier` 改 `strokeBorder` + 形状泛型化为 `InsettableShape` |
| B9d | 删两处恒真 `@available(iOS 26.0, *)`（`:222` 的 `unavailable` 保留） |
| B9f | 删 `CheckBox` 冗余的 `@MainActor @preconcurrency` |
| D10 | 删 `CoreRadius.full` + 同步 **7 处** doc/文档引用 |
| **D16b（顺带）** | CLAUDE.md 的 `.focusedExternally` 描述——见下 |

## B8d：撤销，不是推迟

97.md 说 `RefPill` 与 `CommentCard`「同型手写 surface 三件套」可一并收敛。**这个前提是假的**：

| | background | border | 圆角半径 | 圆角曲线 |
|---|---|---|---|---|
| `CommentCard` 手写 | `surfaceCard` | `borderMuted` | `.medium` | `.circular` |
| **`.surface(.card)`** | `surfaceCard` | `borderMuted` | `.medium` | **`.continuous`** |
| `RefPill` 手写 | **`surfaceCanvasInset`** | `borderMuted` | **`.small`** | `.circular` |
| `.surface(.control)` | `surfaceInteractive` | `borderSubtle` | `.small` | `.continuous` |
| `.surface(.canvasSubtle)` | `surfaceCanvasSubtle` | `borderMuted` | `.medium` | `.continuous` |

**没有任何 `SurfaceKind` 的 background 是 `surfaceCanvasInset`。** 换任何现有 kind 都会同时改变背景色、圆角半径、圆角曲线三项——视觉回归而非重复消除。`surfaceCanvasInset` 与 pill「嵌在正文中的引用标记」的定位相符，判定为有意而非疏忽。

**措辞上写「撤销」而非「推迟给 #101」是有意的**——若标成推迟，#101 接手时会继承同一个错误前提再判断一次。97.md 的 AC/DoD/Description 三处已同步为 17 项实施 + 1 项撤销（经用户确认）。

## B8h：两个 `onChange` 未合并——「同构」前提同样被证伪

97.md 要求把两个 handler 合并为 `syncSuggestionsVisibility(shouldShow:)`。实测 **show 条件相同但 hide 条件不同**，且两者都有隐含的「什么都不做」第三分支：

| handler | show | hide | 否则 |
|---|---|---|---|
| `onChange(of: suggestions)` | `autoShow && !new.isEmpty` | `new.isEmpty && isShowing` | 不动 |
| `onChange(of: autoShowSuggestions)` | `new && !suggestions.isEmpty` | `!new && isShowing` | 不动 |

按原签名合并等价于 `shouldShow = autoShow && !suggestions.isEmpty`、hide 变成 `!shouldShow`。**反例**：`autoShow == false` + suggestions 非空 + 用户已手动展开时，suggestions 数组一更新，原代码保持展开（落进「不动」分支），合并后会**强制收起**。

处置：只收敛动画包装（`setSuggestionsVisible(_:)`），条件逻辑原样保留。body 仍从 78 降到 24 行，B8h 的其余两项（拆子视图、收敛 chip）足额完成。

## 三处受控变化（已截图确认）

1. **`CommentCard` 的 `clipShape`**——`.surface(.card)` 比手写三件套多一步裁切，子视图会被裁到圆角内。
2. **`CommentCard` 的圆角曲线**——手写默认 `.circular`，`SurfaceModifier` 用 `.continuous`。

两个 `#Preview` 均已截图：内容未被裁、圆角形状自然。

> **但冒烟不能证否裁切风险**：两个 Preview 的 content 都是单行 `Text`，不可能溢出。冒烟绿只证明「本仓库自带用例不被裁」，不证明下游调用方安全。真正的判定依据是 **API 语义决策**——裁切是 `.surface(_:)` 的既定语义，对 card 形态合理。

3. **D8 的 `stroke` → `strokeBorder`**（描边向内收 `width/2`）——在唯一生产消费点 `Banner.swift:223` 已截图确认，边框清晰无半像素问题。

## D16b 是顺带修的，原属 #102

Task 1 删 `.getSize` 时要改 CLAUDE.md 的《Modifier 约定》，而那**同一句话**里还写着「`.focusedExternally` 放在 `Utils/`」——实测它在 `BottomInputBar.swift`，不在 `Utils/`。这正是 D16b 记录的缺陷。整句重写为：跨组件复用的纯辅助扩展放 `Utils/`（目前仅 `ColorExtension.swift`）；只服务单个组件的辅助扩展与组件同文件。

`audit-checklist.md` 的 D16b 与 `102.md` 的对应项都已标注「已由 #97 顺带完成」。

## 给下游 Issue 的交接

- **#98**：`KeyboardHandlingTests.swift` 与 `EmptyStateDeprecationTests.swift` 已随本任务删除，**不在保留名单之列**。测试数 101 → **98**（净删 3 个用例）。
- **#95**：`EmptyState.swift` 已删，不必再迁移它的 typography 调用。`CoreGradient` 现在位于 `Tokens/`。
- **#101（B8g）** 与 **#102（D12）**：`SegmentedControl.swift` 删了两处 `@available`、`BottomInputBar.swift` 删了两行，相关坐标已重算。
- **坐标清扫**：本任务造成的漂移已更新——`audit-checklist.md` 的 D1a（`:150,160,172` → `:148,158,170`）与 D12、`102.md`、`99.md` 的 `BottomInputBar.swift:221` → `:219`。
- **⚠️ 一批坐标在本任务之前就已陈旧**，非本次造成、也不在本任务范围：`102.md:37` 的 `TimelineItem.swift:74` 的 `VStack(spacing: 0)` **实测 0 命中**、`101.md:30` 与 `audit-checklist.md:65`（B8g）的 `SegmentedControl.swift:121-147,379-409` 与实测的 `:132,:142,:395,:403` 对不上。各自 Issue 接手时须先重量。

## 降级前的 checkpoint 评审抓到的四条

### 1. B9a 的第一版改法是一次真回归

我原本用 `@State` + `.task(id: data)`。评审指出 **`.task` 在首帧之后才执行**，于是：

- **必然的占位闪烁**：任何 `BookCover` 首帧 `decodedImage == nil` → 渲染按书名哈希取色的彩块，下一个 runloop 才换真图。书架滚动时**每个 cell 都闪一下**——比「反复解码」更刺眼，而且正是 B9a 想改善的同一场景。
- **陈旧图窗口**：`data` 从 A 变 B 时 `.task` 取消重启是异步的，state 仍持有 A，这一个 runloop 内会渲染**上一本书的封面**配新书的 a11y label。

更糟的是**现有验证在设计上就抓不到**：静态截图是 settle 之后拍的。

改为 `BookCoverImageCache`（`NSCache` + 同步查表）：首帧即命中、重复解码同样被消除，两个缺陷都不存在。计划禁的是「`init` 内解码」，从未禁止缓存查表。

### 2. 「零引用」原本只是仓内证据——已补真实下游验证

`KeyboardHandling` 删掉的是 6 个 **public** 符号。对一个以 Swift Package 对外分发的库，「仓内零引用」不等于「无消费者」；而 `becomeFirstResponder` 里那个 `"io.platform.inputView.becomeFirstResponder"` 通知名恰恰暗示宿主 app 有对端实现。

已在真实下游仓 `~/Repositories/any-writer` 实测：

- 排除 `Local Packages/CoreDesign/`（那是 **vendored 副本**，是库自身源码不是消费者）后，6 个符号 + `EmptyState` + `CoreRadius.full` + `bordered(color:)` + `getSize` **全部 0 命中**。
- `MarkdownKit` 里的 `becomeFirstResponder` / `resignFirstResponder` 是 `UIResponder` 的 `override`，与 CoreDesign 无关。

**结论：删除安全，且「零引用」的口径已从「仓内」升级为「含真实下游」。**

### 3. 删掉兼容承诺时，不该连记录承诺的文件一起删

被删的 `docs/components/empty-state.md` 末尾明写：源码「仍保留为兼容包装层，**当前大版本期间**不会被删除」、「彻底移除推迟到下一个明确规划的破坏性变更周期」。

本次改动在同一个 commit 里**既违反了这条承诺、又删掉了记录它的文件**——日后无从判断承诺是被履行了还是被遗忘了。而且它是全仓唯一指向 `ContentUnavailableView` 的迁移指引，仓内也无 CHANGELOG 承接。

已恢复该文件为**墓碑文档**：写明「已于 #97 移除」、保留完整迁移示例、并显式声明「epic `coredesign-audit-remediation` 就是上文所称的那个破坏性变更周期」及其依据。

### 4. `docs/README.md` 的组件计数由本次改动变陈旧

删掉 EmptyState 索引行后，表里实际是 24 个组件，而 `:3` 仍写 25——正是本 epic D16 系列在追的「文档漂移」缺陷类型，由本次改动新引入。已改。

## 降级 PR 评审（第 2 轮）抓到的——一条真 bug

### C1：`BookCoverImageCache` 用 `data.hashValue` 作 key 会永久串味

我的缓存把 checkpoint 刚修掉的「陈旧图」缺陷用另一种形式带了回来，而且这次**永久**。评审实测 + 我复现：`Foundation.Data.hash(into:)` **只哈希 `count` 加前 80 字节**，不遍历全部。两张字节数相同、前 80 字节相同的封面（同一编码管线的 JPEG/PNG 头部往往逐字节相同）命中同一 key，`NSCache` 无 TTL，于是 B 书的封面永久配 A 书的 a11y label。

```
count 相等: true   Data 相等: false   hashValue 相等: true   ← 4096 字节、差异在前 80 之外
```

修法：命中后**用完整 `Data` 复核**（`entry.data == data`，`Data.==` 先比 count 再 memcmp，只对同尺寸候选跑）。顺带修的：
- **I2**：解码失败（`nil`）也缓存，否则坏数据每帧重解码——正是 B9a 要修的场景。
- **I3**：加 `totalCostLimit`（`countLimit` 只限个数不限字节，64 张大图能到几百 MB）。
- **I7**：缓存改 `internal`（原 `private` 连 `@testable` 都够不到）+ 加**回归测试**。测试用 `decodeCount` 探针而非比 `Image`（不可比）或看 `nil`（macOS 的 `NSImage` 对损坏 PNG 太容错，观测不到）——直接量化「命中不重解码」（B9a）与「碰撞各自解码」（C1）。反证过通电：去掉复核那行，碰撞测试精确失败。

### I6：`BorderModifier` 的 `AnyShapeStyle` 擦除是白付的代价

类型已经泛型化过 shape，`style` 再擦成 `AnyShapeStyle` 每次 body 求值都装箱、且破坏 SwiftUI 的值比较。加第二个泛型参数 `Style: ShapeStyle` 即可，调用点签名不变。顺带把默认形状从 `RoundedRectangle(cornerRadius: .none)` 改成 `Rectangle()`（doc 自己吐槽过前者「误导」）。

### I4/I5/I8/Q5：删除的账要让下游看得见

- **I4**：`docs/README.md` 删掉了指向墓碑文档的**唯一链接**，墓碑变成只能猜路径才能到——恢复一行墓碑索引。
- **I5**：`audit-checklist.md` 的 B9g 行原写「empty-state.md 一并清理」，与「改写为墓碑保留」矛盾，已改。
- **I8**：新建 `docs/BREAKING-CHANGES.md` 列出 #97 的全部 public 删除与替代（仓内无 CHANGELOG）。特别标注 `anyWriterFirstResponderNotification` 是**字符串键契约**——下游若用字面量 observe，符号 grep 查不到，any-writer 的零引用扫描覆盖不到它。
- **Q5**：墓碑里「epic 就是那个破坏性变更周期」原写成既定事实，改为显式标为「**工程判断而非治理决策**」并列出依据，供日后重新审视。

## 验证证据

四条 SwiftPM 命令（`swift package clean` 后冷跑）：

```
build          EXIT=0    warning=0
test           EXIT=0    warning=0    98 tests in 31 suites passed
build-blossom  EXIT=0    warning=0
test-blossom   EXIT=0    warning=0    98 tests in 31 suites passed
probe(clean)   EXIT=0
```

**warning 12 → 0。** 但要注意口径：那 12 条**全部来自测试文件** `EmptyStateDeprecationTests.swift:10`，库编译本来就是 0。所以

- `swift build` 的日志（`b.log` / `bb.log`）承载**库**诊断——基线就是 0，这一格不构成新信息；
- `swift test` 的日志（`t.log` / `tb.log`）承载**测试 target** 诊断（`swift build` 不编测试，`swift test` 才首次编它）——12 条在这里出现、也在这里归零，**这才是有信号的一格**。

计划第一版把这个口径写反了，评审实测纠正。

并行硬约束 005 ∩ 006 = ∅ 保持：`git diff --name-only | xargs -n1 basename | grep -Fx -f <清单>` → `rc=1`。**必须 basename 精确匹配**——`EmptyState` / `CommentCard` / `RefPill` / `BookCover` 等同时是目录名，子串 grep 会误判。

`audit-checklist.md` 计数 83（回归护栏，基线即 83），17 项标 ✅ + B8d 标 🚫 撤销 + D16b 顺带标 ✅。

## 工具坑（实测）

- **BSD `sed` 的 `\|` 交替是静默 no-op**。原计划用 `sed -i '' 's/...\(brand\|cta\|canvas\)...'` 做 `static var` → `static let`：BRE 不支持 `\|`（GNU 扩展），**0 处替换、退出码 0、无任何提示**，后续 build 全绿而 B7b 悄悄没做。改为逐个手改 + 计数判据（`static let` = 3 / `static var` = 0）。这个失败模式比「产出不能编译的代码」危险得多，因为它不响。
- **`static var x: T { ... }` → `static let x: T = { ... }` 必须带 `()`**，否则报 `function produces expected type 'AnyShapeStyle'; did you mean to call it with '()'?`。
- **opaque type 不能作存储属性**：`var shape: some InsettableShape` 编译不过，必须把类型泛型化 `struct BorderModifier<S: InsettableShape>`。`View` 扩展的参数位可以用 `some`（隐式泛型），只有存储属性不行。
- **按内容定位而非 `s.index()` 找第一处**：`BottomInputBar.swift` 有两个 `func body(content: Content)`（`BottomInputBarGlassModifier` 与 `BottomInputBarModifier`），我第一次用 `s.index()` 改错了地方，回退重做时改用行号切片。
