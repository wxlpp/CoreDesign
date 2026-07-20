# Issue #94 公开 API 修复与改名 — 完成记录

分支 `issue-94-public-api`（base `epic/coredesign-audit-remediation`）。承载 6 个审计项：A2a、A2b、A2c、A3a、A3b、B9e。

## 做了什么

| 审计项 | 改动 |
|---|---|
| A2a | `CheckBoxToggleStyle` 补 `public`（类型 + 显式 `init()` + `makeBody`） |
| A2b | `CoreBorderlessButtonStyle.role` 补 `public`，新增显式 `public init(role: = .primary)` |
| A2c | `ButtonRoleStyleRole` 的 `color` / `activeColor` / `disabledColor` 补 `public` |
| A3a | `BorderlessButtonStyle` → `CoreBorderlessButtonStyle`（含文件改名，7 处） |
| A3b | `MenuButton` / `MenuButtonStyle` / `MenuButtonStyleModifier` → `CoreMenuButton*`（含文件改名，14 处 + `BottomInputBar.swift:121` 调用点） |
| B9e | `CheckBox` 演示视图整类型删除，内联进 `#Preview`（`@Previewable @State`） |

`FunctionalColor` 整层对下游可见（AC 的复核项）由 probe 既有的 `useFunctionalColors()` 守住，#93 已完成，本任务无代码改动。

## 验证证据

四条 SwiftPM 命令（`swift package clean` 后冷跑）：

```
build          EXIT=0
test           EXIT=0      Test run with 95 tests in 32 suites passed
build-blossom  EXIT=0
test-blossom   EXIT=0      Test run with 95 tests in 32 suites passed
```

warning：四份日志共 12 条，全部是既有的 `EmptyState` deprecation（归 #97）。其中 3 条是编译器诊断的**续行**，文本里不含 "EmptyState" 字样、会漏过朴素的 `grep -v 'EmptyState'` 过滤——已逐条核实内容同源。**warning 采集必须 `swift package clean` 后冷跑**：Task 1–4 的逐步编译已把 `.build` 焐热，热构建只打印 "Build complete" 不重放诊断，且只在默认 trait 侧失效（两条 `--traits Blossom` 是另一套产物会正常重放），这种不对称假绿极难发现。

旧名扫描 `Sources Tests App docs README.md`：`rc=1`，无匹配。

## 下游 probe 的四轮定点反证（本 Issue 的核心关卡）

库内测试全部跑在 CoreDesign target **内部**，internal 符号一样可达——补 `public` 是否真的生效，只有外部包看得见。每轮临时回退一处再构建，确认 probe 真的通电，然后还原：

| 回退 | 实测诊断 |
|---|---|
| `CheckBoxToggleStyle` 去 `public` | `cannot find type 'CheckBoxToggleStyle' in scope` |
| `CoreBorderlessButtonStyle.init` 去 `public` | `'CoreBorderlessButtonStyle' initializer is inaccessible due to 'internal' protection level` |
| `ButtonRoleStyleRole.color` 去 `public` | `'color' is inaccessible due to 'internal' protection level` |
| `PrimitiveButtonStyle where Self == ...` extension 去 `public` | `cannot call value of non-function type 'BorderlessButtonStyle'` |

**最后一条尤其值得留档**：去掉我们的访问器后，`.borderless(role:)` 静默解析到 **SwiftUI 自带的 `BorderlessButtonStyle`**——这正是 A3a 所描述的遮蔽机制被当场抓到。checkpoint 评审指出前三轮只覆盖了直接构造、没覆盖访问器，而 "App/ 与 docs 无需改动" 这一结论恰恰靠访问器成立；补上后才闭合。

## 留给下游 Issue 的输入

- **改名波及的证据坐标已统一修正**：`audit-checklist.md` 7 行（`:43 :46 :59 :72 :84 :104 :107 :115`）、`96.md`、`102.md`、`97.md`、`98.md`、`95.md`、`101.md`。这些文件不在任何自动扫描口径内，靠人工枚举——**后续凡改名/删类型的 Issue 都要做这一步**。
- **行号漂移是独立于改名的第二维 stale**：Task 3 在 `:52` 插入 8 行，`textColor`（B3a 的证据）从 `:65-70` 移到 `:73-78`；Task 1 插入 4 行，B9f 的 `CheckBox.swift` 坐标从 `:25`（本就已被 #93 推到 `:28`）移到 `:32`，#95 的 `iconSize` 坐标从 `:30,34` 移到 `:37,41`。只改路径不改行号会让下游指向**错误的代码**，且无任何关卡能发现。
- **#5**：`CoreBorderlessButtonStyle.swift:52` 新增了一个 `public let role`，是 D4「`public let` 存储属性冻结内部布局」的新样本。它由本 Issue 的 AC 明确要求（严格说只补 `public init(role:)` 也能消除 A2b 症状），是否收回由 #10 判定。
- **#5 / #11**：`MenuButton.swift` 全部行号**未变**（Task 4 是纯 sed 替换，不增删行），只需换文件名。
- **`audit-checklist.md:46`（B3d）的坐标 `:43-46` 与描述对不上**——该区间实际是 padding×2 + foregroundStyle + clipShape，没有 `.font` / `.contentShape`。这是审计期就存在的不准，与本次改名无关，未扩大范围处理。

## A3a 的残留：改名没能消灭全部歧义

改名把 `BorderlessButtonStyle` 这个**类型名**的遮蔽消掉了，但**访问器名**的歧义还在——已实测：

```swift
.buttonStyle(.borderless)              // ← SwiftUI 自带的，静默解析，零诊断
.buttonStyle(.borderless())            // ← CoreDesign 的（role 默认 .primary）
.buttonStyle(.borderless(role: .danger))
```

`xcrun swiftc -typecheck` 对只 `import SwiftUI` 的最小样例返回 EXIT=0——即 SwiftUI 的 `PrimitiveButtonStyle.borderless` 静态属性不受我们改名影响，两种写法只差一对括号且都能编译。

保留 `borderless` 这个访问器名是**有意取舍**：正因为它名字没变，`App/` 与 docs 示例在改名后才零改动（这是本 PR 的一项声称）。代价就是这处残留。probe 也守不住它——probe 只能证明我们的访问器可达，无法阻止下游写出 SwiftUI 的那个。故处置是**记录而非消除**：类型 doc block 与 `docs/components/button.md` 各加一处警告，`audit-checklist.md` 的 A3a 行注明残留。

若日后判定不可接受，唯一彻底的解法是把访问器改名为 `.coreBorderless(role:)`，代价是 `App/` 与 docs 需同步——那是一次独立的 breaking change，不在 #94 范围。

## 已知盲区与后续路由

- **probe 只跑默认 trait**。`scripts/downstream-probe/Package.swift` 的 `.package(name:path:)` 未带 `traits:`，所以 Blossom 分支的公开求值路径没有下游可见性守卫。本次新公开的 `ButtonRoleStyleRole.color` 在 `case .secondary` 下会走到 `secondaryAccent*`——那正是八个 `#if Blossom` 分流点之一。今天没坏，但值得一个后续任务（先验证 `.package(name:path:traits:)` 是否按预期传播）。
- **`CheckBoxToggleStyle` 新成公开面但 `docs/components/` 无对应页**。属 C6b / #11 的文档范围，此处显式路由而非默默遗漏。
- **`CoreMenuButtonStyle` 是形状变体而非 style 协议实现**，改名后落进 `Core*ButtonStyle` 命名空间反而更容易被误读为与 `CoreBorderlessButtonStyle` 同类。已修正其 doc 注释（原注释「通过测量同环境下 Text 的渲染高度来传递字体尺寸」与实际行为完全不符，是改名前就存在的 stale）。进一步改名为 `CoreMenuButtonShape` 会再次搅动 D5 刚指向的 `:77` 坐标，建议搭 #10 的 D5 一起做。

## 工具语义（macOS，实测）

- **BSD `sed` 不支持 `\b`**——`s/\bFoo\b/Bar/g` 把 `\b` 当未定义转义，**静默不替换**。词边界必须写 `[[:<:]]` / `[[:>:]]`。
- **BSD `grep` 支持 `\b`**——所以校验侧可靠，能捕获 sed 空转，两边不会一起瞎。
- 词边界保证 `CoreBorderlessButtonStyle`、`showMenuButton`（`BottomInputBar` 的公开 init 参数标签，10 处）都不被误伤。
- **不要把扫描命令抽成 shell 函数**：每个 Step 可能是独立的 Bash 调用，函数定义不跨调用存活，会让关卡以 `command not found`（rc=127、stdout 为空）通过「Expected: 无输出」——静默假绿。判据要写成 `rc=1 且无匹配行`。
