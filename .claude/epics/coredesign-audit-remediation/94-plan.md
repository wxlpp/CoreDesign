# 公开 API 修复与改名 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use oh-my-superpowers:subagent-driven-development (recommended) or oh-my-superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 CoreDesign 真正被下游用到的公开面可达，并消灭两个与 SwiftUI 同名、会静默解析到系统类型的符号。

**Architecture:** 纯符号级改动，无行为变更。分两类：(1) 补 `public` 关键字——`CheckBoxToggleStyle`、`ButtonRoleStyleRole` 的三个调色板属性、`CoreBorderlessButtonStyle` 的 `role` 与显式 `init`；(2) 改名 + 文件重命名——`BorderlessButtonStyle` → `CoreBorderlessButtonStyle`、`MenuButton` 家族 → `CoreMenuButton` 家族。附带 B9e：把 `CheckBox` 演示视图内联进 `#Preview`。

**Tech Stack:** SwiftPM / Swift 6 / SwiftUI，验证靠四条 SwiftPM 命令 + `scripts/downstream-probe`。

## Global Constraints

- 该库目前无下游用户，**breaking change 直接改，不留兼容层、不写迁移说明**。
- 四条命令都要绿且不新增 warning：`swift build` / `swift test` / 两者的 `--traits Blossom` 版本。
- 本任务**不新增/删除 colorset**，因此不需要 `swift package clean`（若意外触及则必须 clean 后重验）。
- warning 判据：按 message 来源过滤，**不用 `grep -c` 计数**；**不先跑 `swift build` 预热**（会把库诊断丢弃且不再重放）。日志落 `${TMPDIR:-/tmp}/coredesign-94`，用前 `mkdir -p`，读前 `[ -s ]` 断言非空。
- 四条命令逐条跑、不串 `&&`；需要串时先 `set -o pipefail`。
- `ToastHostTests` 有 3 个 timing 用例会 flake（`进入 dismissing 状态` / `double-fire` / `advance 到下一条`）：先重跑一次，连续两次失败才算真红。另两个 `dismiss(id:)` 开头的用例**不是** flake。
- 代码风格（CLAUDE.md）：显式 `self.`、中英双语注释、`// MARK: -` 分节。
- **范围边界**：`Utils/View+SizeReader.swift` 的 `getSize` **不补 public**（#97 整文件删除）；`CheckBoxToggleStyle.makeBody` 上冗余的 `@MainActor @preconcurrency` **不动**（B9f 归 #97）。

## 已实测的前置事实（不要重新推导）

| 事实 | 影响 |
|---|---|
| 基线绿：`swift build` EXIT=0、`swift test` 95 tests / 32 suites passed | 起点干净 |
| `App/` 只通过访问器 `.borderless(role:)` 消费，**不出现类型名** | 改名**不需要**改 `App/`；AC「App 同步适配」的正确结论是「实测无需改动」，不要为凑 AC 编造改动 |
| `MenuButton` / `MenuButtonStyle` / `MenuButtonStyleModifier` 全部是 internal | 改名是模块内可读性 + 未来公开的前置，不影响下游；`MenuButtonStyle` 同样与 SwiftUI（macOS deprecated）的 `MenuButtonStyle` 协议同名，一并改 |
| `MenuButton` 的唯一生产调用点是 `BottomInputBar.swift:121`，另有同文件两处 `#Preview` | 改名波及面已穷举 |
| `FunctionalColor.swift` 已是 `public extension Color`，四个状态别名及变体均 public（#93 完成） | AC 该项是**复核**，probe 里已有 `useFunctionalColors()` 覆盖，无需新增代码 |
| `CheckBox` 类型全库唯一出现点就是 `CheckBox.swift` 自身（`Tests/`、`App/`、`docs/`、`scripts/`、`README.md` 均 0 命中） | Task 1 可整类型删除；测试数量应保持 95 不变 |
| `docs/superpowers/` 下的 spec/plan 是历史归档 | **不改**；只改 `docs/components/button.md` |

### 工具语义（评审实测，务必照做）

- **BSD `sed` 不支持 `\b`**——`sed -i '' 's/\bFoo\b/Bar/g'` 在 macOS 上把 `\b` 当未定义转义，结果是**静默不替换**。词边界必须写 `[[:<:]]` / `[[:>:]]`。
- **BSD `grep` 支持 `\b`**——所以校验用的 `grep '\bFoo\b'` 是可靠的，能捕获上面的 sed 空转（不会两边一起瞎）。两个工具语义不同，不要互相类推。
- `grep '\bBorderlessButtonStyle\b'` **不会**命中 `CoreBorderlessButtonStyle`（前导字符 `e` 不构成词边界）——已实测 0 命中。`CoreMenuButton` / `showMenuButton` 同理。

### 统一的旧名扫描口径（带参数）

全计划的「无旧名残留」检查共用同一个函数，但**pattern 逐 Task 传入**——Task 3 结束时 Task 4 还没跑，若一上来就扫全集会打印满屏 MenuButton 残留、把关卡变成必然假红：

```bash
scan_old_names() {   # $1 = grep pattern
  grep -rn --exclude-dir=superpowers "$1" Sources Tests App docs README.md 2>/dev/null || true
}
```

- `--exclude-dir=superpowers` 排除 `docs/superpowers/` 历史归档。
- 含 `Tests`：当前对三个旧名 0 命中，纳入后「无旧名残留」这条 DoD 才名副其实。
- 末尾 `|| true`：grep 无命中时退出码为 1，不加会在 `set -e` 下把成功变成中断。判据看**输出是否为空**，不看退出码。
- `showMenuButton` 因词边界不命中，这是**有意的**（见 Task 4 非目标）。

各 Task 传入的 pattern：

| 位置 | pattern |
|---|---|
| Task 3 Step 5 | `'\bBorderlessButtonStyle\b'` |
| Task 4 Step 4 | `'\bMenuButton\b\|\bMenuButtonStyle\b\|\bMenuButtonStyleModifier\b'` |
| Task 5 Step 5（全集） | `'\bBorderlessButtonStyle\b\|\bMenuButton\b\|\bMenuButtonStyle\b\|\bMenuButtonStyleModifier\b'` |

---

### Task 1: `CheckBoxToggleStyle` 补 public + 演示视图内联（A2a、B9e）

**Files:**
- Modify: `Sources/CoreDesign/Components/CheckBox/CheckBox.swift`

**Interfaces:**
- Produces: `public struct CheckBoxToggleStyle: ToggleStyle`，`public init()`，`public func makeBody(configuration:) -> some View`
- 删除：`struct CheckBox`（整个类型，含 `#Preview` 的引用）

- [ ] **Step 1: 改 `CheckBoxToggleStyle` 为 public 并补显式 init**

把 `CheckBox.swift:27-47` 改成：

```swift
public struct CheckBoxToggleStyle: ToggleStyle {
    /// 无参构造 / Memberwise-free init：显式声明才能让下游可达
    /// （Swift 默认合成的 memberwise init 是 internal）。
    public init() {}

    @MainActor @preconcurrency
    public func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .top, spacing: CoreSpacing.sm) {
            if configuration.isOn {
                Image(systemName: "checkmark.square.fill")
                    .font(.system(size: CoreControlMetrics.iconSize(for: .regular)))
                    .foregroundStyle(Color.contentPrimary)
            } else {
                Image(systemName: "square")
                    .font(.system(size: CoreControlMetrics.iconSize(for: .regular)))
                    .foregroundStyle(Color.gray)
            }
            configuration.label
        }
        .animation(.easeOut(duration: 0.25), value: configuration.isOn)
        .onTapGesture {
            configuration.isOn.toggle()
        }
    }
}
```

- [ ] **Step 2: 删除 `CheckBox` 类型，把演示内联进 `#Preview`**

把 `// MARK: - CheckBox` 到文件末尾整段替换为（原 `:49-66`，**行号为 Step 1 之前的编号**——Step 1 插入了 init 与注释，实际范围下移几行；以锚点文本为准）：

```swift
// MARK: - Preview

/// 演示用法 / Demo usage：业务侧直接用
/// `Toggle(...).toggleStyle(CheckBoxToggleStyle())` 自行控制 binding 与 label，
/// 本包不再导出便利封装（原 `CheckBox` 视图硬编码 label 且用 `@State` 而非
/// `@Binding`，唯一使用者就是本 Preview，已于 Issue #94 内联）。
#Preview {
    @Previewable @State var isOn = false

    Toggle("同意用户协议 / Accept terms", isOn: $isOn)
        .toggleStyle(CheckBoxToggleStyle())
        .padding()
}
```

- [ ] **Step 3: 验证编译（含测试 target）**

Run: `swift build --build-tests`
Expected: EXIT=0，无 `cannot find 'CheckBox' in scope`

用 `--build-tests` 而非裸 `swift build`——后者不编译测试 target，若 `Tests/` 里有 `CheckBox` 引用会漏到 Task 5 才炸。（前置事实表已实测 `Tests/` 0 命中，此处是把断言变成关卡。）

- [ ] **Step 4: 提交**

```bash
git add Sources/CoreDesign/Components/CheckBox/CheckBox.swift
git commit -m "feat: 公开 CheckBoxToggleStyle 并把演示视图内联进 Preview"
```

---

### Task 2: `ButtonRoleStyleRole` 三个调色板属性补 public（A2c）

**Files:**
- Modify: `Sources/CoreDesign/Components/Button/ButtonRoleStyleRole.swift:18,33,48`

**Interfaces:**
- Produces: `public var color: Color`、`public var activeColor: Color`、`public var disabledColor: Color`

- [ ] **Step 1: 三处 `var` 前加 `public`**

`ButtonRoleStyleRole.swift` 的三个计算属性声明行，逐一改为：

```swift
    public var color: Color {
```
```swift
    public var activeColor: Color {
```
```swift
    public var disabledColor: Color {
```

（枚举本身 `public enum ButtonRoleStyleRole` 已是 public，只补属性。）

- [ ] **Step 2: 确认三处都改到**

Run: `grep -n 'public var color\|public var activeColor\|public var disabledColor' Sources/CoreDesign/Components/Button/ButtonRoleStyleRole.swift`
Expected: 恰好 3 行输出

- [ ] **Step 3: 验证编译**

Run: `swift build --build-tests`
Expected: EXIT=0

- [ ] **Step 4: 提交**

```bash
git add Sources/CoreDesign/Components/Button/ButtonRoleStyleRole.swift
git commit -m "feat: 公开 ButtonRoleStyleRole 的三个调色板属性"
```

---

### Task 3: `BorderlessButtonStyle` → `CoreBorderlessButtonStyle`（A2b、A3a）

**Files:**
- Rename: `Sources/CoreDesign/Components/Button/styles/BorderlessButtonStyle.swift` → `CoreBorderlessButtonStyle.swift`
- Modify: 同文件内容（类型名、文件头注释、MARK、`role` 可见性、显式 init、静态扩展）
- Modify: `docs/components/button.md:11`

**Interfaces:**
- Produces: `public struct CoreBorderlessButtonStyle: PrimitiveButtonStyle`，`public let role: ButtonRoleStyleRole`，`public init(role: ButtonRoleStyleRole = .primary)`
- 访问器 `static func borderless(role:)` **名称不变**，只是返回类型改名 —— 这是 `App/` 与 docs 示例无需改动的原因

- [ ] **Step 1: 用 git mv 重命名文件**

```bash
git mv Sources/CoreDesign/Components/Button/styles/BorderlessButtonStyle.swift \
       Sources/CoreDesign/Components/Button/styles/CoreBorderlessButtonStyle.swift
```

- [ ] **Step 2: 文件内全量替换类型名**

在 `CoreBorderlessButtonStyle.swift` 中把所有 `BorderlessButtonStyle` 替换为 `CoreBorderlessButtonStyle`。**实测共 7 处**（行号为改名前）：文件头注释 `:2`、MARK `:11`、类型声明 `:40`、静态扩展的 `where Self ==` `:75`、doc 注释 `:79`、返回类型 `:80`、构造调用 `:81`。

```bash
sed -i '' 's/[[:<:]]BorderlessButtonStyle[[:>:]]/CoreBorderlessButtonStyle/g' \
  Sources/CoreDesign/Components/Button/styles/CoreBorderlessButtonStyle.swift
```

**必须用 `[[:<:]]` / `[[:>:]]`，不能用 `\b`**——BSD sed 会把 `\b` 当未定义转义，整条命令静默不替换（见前言《工具语义》）。

替换后复核：

```bash
grep -c '\bCoreBorderlessButtonStyle\b' Sources/CoreDesign/Components/Button/styles/CoreBorderlessButtonStyle.swift
grep -c 'CoreCoreBorderless' Sources/CoreDesign/Components/Button/styles/CoreBorderlessButtonStyle.swift
```
Expected: 第一条 `7`、第二条 `0`。再 Read 全文看一眼注释语义是否通顺。

- [ ] **Step 3: `role` 补 public 并加显式 init**

把类型体内 `let role: ButtonRoleStyleRole` 那行改为：

```swift
    public let role: ButtonRoleStyleRole

    /// 以指定 role 构造 / Init with role。
    ///
    /// 显式声明才能让下游可达——Swift 合成的 memberwise init 取决于成员可见性，
    /// 此前 `role` 是 internal，下游实测报 `initializer is inaccessible`。
    public init(role: ButtonRoleStyleRole = .primary) {
        self.role = role
    }
```

注意 `role` 声明位于 `makeBody` 之后（原 `:52` 附近），保持原位置不动，把 init 紧跟其后。

- [ ] **Step 4: 更新 docs**

`docs/components/button.md:11`，把表格里的 `` `BorderlessButtonStyle` `` 改为 `` `CoreBorderlessButtonStyle` ``。第 31 行的 `.buttonStyle(.borderless(role: .danger))` 与第 42 行的 “BorderlessButton 仅 label 染色” 是散文/访问器，前者不动；第 42 行改为 “CoreBorderlessButtonStyle 仅 label 染色，无 chrome”。

- [ ] **Step 5: 验证无旧名残留 + 编译**

```bash
scan_old_names '\bBorderlessButtonStyle\b'
```
Expected: 无输出。若 Step 2 的 sed 空转过，这里会把 7 处旧名全打印出来——这是捕获 sed 失效的关卡。

**本步只扫 Borderless 一个名字**：Task 4 尚未执行，MenuButton 家族此刻理应还是旧名，扫全集会必然假红。

Run: `swift build --build-tests`
Expected: EXIT=0

- [ ] **Step 6: 提交**

```bash
git add Sources/CoreDesign/Components/Button/styles/ docs/components/button.md
git commit -m "refactor!: BorderlessButtonStyle 改名 CoreBorderlessButtonStyle 并公开 role/init"
```

---

### Task 4: `MenuButton` 家族 → `CoreMenuButton` 家族（A3b）

**Files:**
- Rename: `Sources/CoreDesign/Components/BottomInputBar/MenuButton.swift` → `CoreMenuButton.swift`
- Modify: 同文件内容（`MenuButton`、`MenuButtonStyle`、`MenuButtonStyleModifier` 三个符号 + 注释 + 两处 `#Preview`）
- Modify: `Sources/CoreDesign/Components/BottomInputBar/BottomInputBar.swift:121`

**Interfaces:**
- Produces: `struct CoreMenuButton: View`（仍 internal）、`enum CoreMenuButtonStyle`、`private struct CoreMenuButtonStyleModifier`
- Consumes: `BottomInputBar.menuButton` 调用 `CoreMenuButton(isExpanded:style:)`

**为什么连 `MenuButtonStyle` 一起改：** 它同样与 SwiftUI（macOS 上 deprecated）的 `MenuButtonStyle` 协议同名。只改 `MenuButton` 会留下一半的同名遮蔽，且 `CoreMenuButton` 的 `style:` 参数类型仍叫 `MenuButtonStyle` 读起来割裂。

**非目标（明确不改）：**
- `BottomInputBar` 的 **`showMenuButton`**（10 处：`:27,39,53,99,320,337,352,407,450,468`，另 `docs/components/bottom-input-bar.md:14`）。它是 `BottomInputBar` 公开 init 的参数标签，外加同文件内部类型的存储属性与透传。改它是本 Issue 范围外的破坏性 API 变更。词边界保证 sed 与 grep 都不会碰它。
- `BottomInputBar.menuButton` 私有计算属性——实现细节，不构成同名冲突。

- [ ] **Step 1: 用 git mv 重命名文件**

```bash
git mv Sources/CoreDesign/Components/BottomInputBar/MenuButton.swift \
       Sources/CoreDesign/Components/BottomInputBar/CoreMenuButton.swift
```

- [ ] **Step 2: 文件内全量替换**

```bash
F=Sources/CoreDesign/Components/BottomInputBar/CoreMenuButton.swift
sed -i '' \
  -e 's/[[:<:]]MenuButtonStyleModifier[[:>:]]/CoreMenuButtonStyleModifier/g' \
  -e 's/[[:<:]]MenuButtonStyle[[:>:]]/CoreMenuButtonStyle/g' \
  -e 's/[[:<:]]MenuButton[[:>:]]/CoreMenuButton/g' \
  "$F"
```

**安全性来自词边界，不来自顺序。** `[[:<:]]MenuButton[[:>:]]` 不会命中 `MenuButtonStyleModifier` 内部（尾边界撞上 `S` 失配），所以三条规则的先后其实无关。反过来说：**若有人为了绕开 sed 报错而去掉边界，长→短的顺序也救不了**——规则 1 产出 `CoreMenuButtonStyleModifier`，规则 2 的裸 `MenuButtonStyle` 会在其内部再次命中，得到 `CoreCoreMenuButtonStyleModifier`。长→短顺序保留（无害），但不要把它当作安全依据。

sed 只作用于本文件，`BottomInputBar.swift` 的 `showMenuButton` 不受影响。

替换后复核（行号为改名前，**实测共 14 处**：`:2 :63 :74 :77 :82 :84 :85 :126 :128 :131 :144 :179 :194 :198`）：

```bash
grep -c '\bCoreMenuButton\b\|\bCoreMenuButtonStyle\b\|\bCoreMenuButtonStyleModifier\b' \
  Sources/CoreDesign/Components/BottomInputBar/CoreMenuButton.swift
grep -c 'CoreCoreMenu' Sources/CoreDesign/Components/BottomInputBar/CoreMenuButton.swift
```
Expected: 第一条 `14`、第二条 `0`。

再 Read 全文，重点看 `:2` 文件头、`:63` 的长注释、`:179` 的设计说明段——注释里的散文引用也要跟着改名，否则文档与代码脱节。

- [ ] **Step 3: 更新唯一生产调用点**

`BottomInputBar.swift:121`，`MenuButton(` → `CoreMenuButton(`：

```swift
    private var menuButton: some View {
        CoreMenuButton(
            isExpanded: self.$isExpanded,
            style: self.isInputFocused ? .circular : .labeled
        )
        .backgroundStyle(.green)
    }
```

（局部计算属性名 `menuButton` 不改——它是 `BottomInputBar` 的私有实现细节，不构成同名冲突。）

- [ ] **Step 4: 验证无旧名残留 + 编译**

```bash
scan_old_names '\bMenuButton\b\|\bMenuButtonStyle\b\|\bMenuButtonStyleModifier\b'
```
Expected: 无输出。若 sed 空转，这里会打印出 `CoreMenuButton.swift` 的 14 行 + `BottomInputBar.swift:121`。

Run: `swift build --build-tests`
Expected: EXIT=0

- [ ] **Step 5: 提交**

```bash
git add Sources/CoreDesign/Components/BottomInputBar/
git commit -m "refactor: MenuButton 家族改名 CoreMenuButton，避开 SwiftUI 同名类型"
```

---

### Task 5: 下游 probe 覆盖 + 全量验证 + 审计清单

**Files:**
- Create: `scripts/downstream-probe/Sources/DownstreamProbe/PublicVisibility.swift`
- Modify: `.claude/epics/coredesign-audit-remediation/audit-checklist.md`

**Interfaces:**
- Consumes: Task 1–4 产出的全部公开符号

**为什么 probe 是唯一有效关卡：** 所有 SwiftPM 测试都跑在 CoreDesign target **内部**，internal 符号一样可见——补 `public` 是否真的生效，只有从外部包才看得见。这是 #92 建立 probe 的原因。

**为什么新开文件而不是追加进 `NonisolatedUsage.swift`：** 那个文件守的是**隔离**契约，文件头 `:5` 明写「每个函数都显式 `nonisolated`」。本节守的是**可见性**契约，且下面这些函数必须是 `@MainActor`（见 Step 2 说明）——混进去会让那句文件头注释变成假的，两种契约也纠缠不清。

- [ ] **Step 1: 新建 `PublicVisibility.swift`**

```swift
import CoreDesign
import Foundation
import SwiftUI

// MARK: - 公开可见性契约（Issue #94）
//
// 以下符号此前漏写 `public`，下游实测报 `cannot find in scope` /
// `initializer is inaccessible`。库内测试看不见这个问题——它们跑在 target
// 内部，internal 符号一样可达。只有从外部包才能守住这条契约。
//
// 注意本文件与同目录 `NonisolatedUsage.swift` 的分工：那边守**隔离**契约
// （函数全部 `nonisolated`），这边守**可见性**契约。CoreDesign 开了
// `.defaultIsolation(MainActor.self)`，所以这里的函数都得是 `@MainActor`
// ——包括读 `ButtonRoleStyleRole` 的调色板属性。换言之：这三个属性对下游
// **可见但不是 nonisolated 可达的**；若日后需要 nonisolated 可达，那是另一个
// 范围内的改动（给属性标 `nonisolated`），不要在本文件里顺手夹带。

@MainActor
func constructCheckBoxToggleStyle() -> CheckBoxToggleStyle {
    CheckBoxToggleStyle()
}

@MainActor
func constructBorderlessStyle() -> CoreBorderlessButtonStyle {
    let style = CoreBorderlessButtonStyle(role: .danger)
    _ = style.role
    return style
}

@MainActor
func readRolePalette(_ role: ButtonRoleStyleRole) -> [Color] {
    [role.color, role.activeColor, role.disabledColor]
}
```

- [ ] **Step 2: 构建 probe**

```bash
LOGDIR="${TMPDIR:-/tmp}/coredesign-94"; mkdir -p "$LOGDIR"
(set -o pipefail; cd scripts/downstream-probe && swift build 2>&1 | tee "$LOGDIR/probe.log" | tail -20)
echo "probe EXIT=$?"
[ -s "$LOGDIR/probe.log" ] || echo "probe.log 为空——采集失败"
grep -c 'inaccessible\|cannot find' "$LOGDIR/probe.log"
```
Expected: `probe EXIT=0`，最后一条 grep 计数为 `0`。

两个细节别省：`set -o pipefail` 必须在**子 shell 内**（若拆成两次工具调用，外层的 pipefail 会丢，`$?` 变成 `tail` 的 0，失败被静默吞掉——那会让 Step 3 的三轮反证全部假绿）；全量日志落 `probe.log` 而非只看 `tail -20`，因为 Step 3 要断言的具体诊断串未必落在最后 20 行。同时这一步顺带守住 AC「`FunctionalColor` 整层对下游可见」——`NonisolatedUsage.swift` 里已有的 `useFunctionalColors()` 引用 `.success/.info/.warning/.danger`，它们在 SwiftUI 中无同名对应物，编译过即证明本层 public 有效。

- [ ] **Step 3: 定点反证 probe 有效（三处，逐一还原）**

红态在 Task 1–4 落地后无法自然重现，改用**逐契约反证**——每次只回退一处，确认 probe 真的报错，再还原。只反证一处不够：本 Issue 有三条独立契约，`CheckBoxToggleStyle` 通电不代表另两条也通电。

| # | 临时回退 | 预期错误 | 还原命令 |
|---|---|---|---|
| 1 | `CheckBoxToggleStyle` 的 `public struct` → `struct` | `cannot find 'CheckBoxToggleStyle' in scope` | `git checkout -- Sources/CoreDesign/Components/CheckBox/CheckBox.swift` |
| 2 | `CoreBorderlessButtonStyle` 的 `public init(role:)` → `init(role:)` | `initializer is inaccessible`（A2b 审计项原始症状） | `git checkout -- Sources/CoreDesign/Components/Button/styles/CoreBorderlessButtonStyle.swift` |
| 3 | `ButtonRoleStyleRole` 的 `public var color` → `var color` | `'color' is inaccessible due to 'internal' protection level` | `git checkout -- Sources/CoreDesign/Components/Button/ButtonRoleStyleRole.swift` |

每次回退后重跑 Step 2，用 `grep 'inaccessible\|cannot find' "$LOGDIR/probe.log"` 确认**出现表中那条诊断**（不要只看 EXIT≠0——别的原因也能让构建失败）；还原后重跑 Step 2，确认回到 EXIT=0 且 grep 计数为 0。三轮都做完再往下走。

- [ ] **Step 4: 四条 SwiftPM 命令 + warning 判据**

```bash
LOGDIR="${TMPDIR:-/tmp}/coredesign-94"; mkdir -p "$LOGDIR"
swift build            > "$LOGDIR/b.log"  2>&1; echo "build          EXIT=$?"
swift test             > "$LOGDIR/t.log"  2>&1; echo "test           EXIT=$?"
swift build --traits Blossom > "$LOGDIR/bb.log" 2>&1; echo "build-blossom  EXIT=$?"
swift test  --traits Blossom > "$LOGDIR/tb.log" 2>&1; echo "test-blossom   EXIT=$?"
for f in b t bb tb; do
  [ -s "$LOGDIR/$f.log" ] || { echo "$f.log 为空——采集失败"; exit 1; }
  echo "--- $f 新增 warning ---"
  grep 'warning:' "$LOGDIR/$f.log" | grep -v 'EmptyState' || echo "(无)"
done
grep -aoE 'Test run with [0-9]+ tests in [0-9]+ suites (passed|failed)' "$LOGDIR/t.log" | tail -1
grep -aoE 'Test run with [0-9]+ tests in [0-9]+ suites (passed|failed)' "$LOGDIR/tb.log" | tail -1
```
Expected: 四条 EXIT=0；warning 段全为 `(无)`；两条测试各 `95 tests in 32 suites passed`（Task 1 删的是视图类型不是测试，且 `Tests/` 对 `CheckBox` 0 命中——数量应不变；若变了要查清原因再往下走）

关于 `grep -v 'EmptyState'`：DoD 写的是「零 warning」，但基线本就有若干 `EmptyState` deprecation warning，属 #97 的删除范围。该过滤是本 epic 既定口径（`92-plan.md` / `93-plan.md` 同样使用），不是本任务的临时抑制。

- [ ] **Step 5: DoD 的旧名扫描（全集）**

```bash
scan_old_names '\bBorderlessButtonStyle\b\|\bMenuButton\b\|\bMenuButtonStyle\b\|\bMenuButtonStyleModifier\b'
```
Expected: 无输出。

- [ ] **Step 6: 修正审计清单里被本次改名打断的旁及证据**

`audit-checklist.md` 里有 4 行属于**别的 Issue**，但引用了本次改名/删除的东西。统一扫描口径不覆盖 `.claude/`，没有任何关卡会发现它们；不改的话 #5 / #9 / #10 的执行者会照着找不存在的文件：

| 行 | 归属 Issue | 现状 → 改成 |
|---|---|---|
| `:43`（B3a） | #5 | `BorderlessButtonStyle.swift:65-70` → `CoreBorderlessButtonStyle.swift:65-70` |
| `:84`（C5） | 测试覆盖 | 「零测试文件：`CheckBox`、…、`MenuButton`、…」→ `CheckBoxToggleStyle`（`CheckBox` 类型本次删除）、`CoreMenuButton` |
| `:104`（D2） | #9 | `MenuButton.swift:139,169` → `CoreMenuButton.swift:139,169` |
| `:107`（D5） | #10 | `MenuButton.swift:77` → `CoreMenuButton.swift:77` |

行号本身不变（改名不增删行）。改完后再跑一次 Step 5 的扫描把 `.claude/epics/` 也带上，确认清零：

```bash
grep -rn '\bBorderlessButtonStyle\b\|\bMenuButton\b' .claude/epics/coredesign-audit-remediation/ 2>/dev/null || true
```
Expected: 只剩本计划与 `94.md` 里描述改名动作本身的历史叙述（它们**应当**保留旧名，那是在讲「从什么改成什么」）；`audit-checklist.md` 0 命中。

- [ ] **Step 7: 更新审计清单状态**

把 `audit-checklist.md` 中 A2a、A2b、A2c、A3a、A3b、B9e 六项状态改为「✅ 已修复」，并核对计数不变：

```bash
echo $(( $(grep -c '^| [A-D][0-9]' .claude/epics/coredesign-audit-remediation/audit-checklist.md) - 4 ))
```
Expected: `83`

（`- 4` 扣的是文末「won't-fix 理由表」里 C3 / C8 / C10b / D17 四行——这四项在主表已各出现一次，理由表是它们的**第二次**出现，直接 `grep -c` 会重复计数。原始 87 − 4 = 83 个唯一审计项，其中 79 要修、4 项 won't-fix。）

- [ ] **Step 8: 提交**

```bash
git add scripts/downstream-probe/Sources/DownstreamProbe/PublicVisibility.swift
git add .claude/epics/coredesign-audit-remediation/audit-checklist.md
git add .claude/epics/coredesign-audit-remediation/94-plan.md
git commit -m "test: probe 覆盖 #94 公开可见性契约并更新审计清单"
```

---

## 收尾

全部 Task 完成后：`oh-my-superpowers:verification-before-completion` → `finishing-a-development-branch` 走 Option 2 开 PR（**base = `epic/coredesign-audit-remediation`，禁止直合 main**）→ Copilot 不可用（`COPILOT_UNAVAILABLE_UNTIL=2026-08-01`），按 auto-fix skill §3.6 降级为 `superpowers-reviewer` 一轮，并在 PR 上留一条顶层评论记录降级。
