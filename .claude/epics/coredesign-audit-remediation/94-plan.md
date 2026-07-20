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
| `docs/superpowers/` 下的 spec/plan 是历史归档 | **不改**；只改 `docs/components/button.md` |

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

把 `CheckBox.swift:49-66`（`// MARK: - CheckBox` 到文件末尾）整段替换为：

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

- [ ] **Step 3: 验证编译**

Run: `swift build`
Expected: EXIT=0，无 `cannot find 'CheckBox' in scope`（全库无其它引用点，见前置事实表）

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

Run: `swift build`
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

在 `CoreBorderlessButtonStyle.swift` 中把所有 `BorderlessButtonStyle` 替换为 `CoreBorderlessButtonStyle`（共 6 处：文件头注释 `:2`、MARK `:11`、类型声明 `:40`、静态扩展的 `where Self ==` `:75`、doc 注释 `:79`、返回类型与构造 `:80-81`）：

```bash
sed -i '' 's/\bBorderlessButtonStyle\b/CoreBorderlessButtonStyle/g' \
  Sources/CoreDesign/Components/Button/styles/CoreBorderlessButtonStyle.swift
```

替换后人工 Read 全文复核一遍，确认没有出现 `CoreCoreBorderlessButtonStyle`（`\b` 边界已排除，但要看一眼）。

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
grep -rn '\bBorderlessButtonStyle\b' Sources App docs/components docs/*.md 2>/dev/null
```
Expected: 无输出（`CoreBorderlessButtonStyle` 因 `\b` 前是 `e` 不匹配裸词；若有输出即为遗留）

Run: `swift build`
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

- [ ] **Step 1: 用 git mv 重命名文件**

```bash
git mv Sources/CoreDesign/Components/BottomInputBar/MenuButton.swift \
       Sources/CoreDesign/Components/BottomInputBar/CoreMenuButton.swift
```

- [ ] **Step 2: 文件内全量替换**

顺序很重要——先替长名再替短名，否则 `MenuButtonStyleModifier` 会被短名规则先啃掉：

```bash
F=Sources/CoreDesign/Components/BottomInputBar/CoreMenuButton.swift
sed -i '' \
  -e 's/\bMenuButtonStyleModifier\b/CoreMenuButtonStyleModifier/g' \
  -e 's/\bMenuButtonStyle\b/CoreMenuButtonStyle/g' \
  -e 's/\bMenuButton\b/CoreMenuButton/g' \
  "$F"
```

替换后 Read 全文复核，重点看 `:2` 文件头、`:63` 的长注释、`:74`/`:82`/`:126` 三个 MARK、`:179` 的设计说明段、`:194`/`:198` 两处 Preview——注释里的散文引用也要跟着改名，否则文档与代码脱节。

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
grep -rn '\bMenuButton\b\|\bMenuButtonStyle\b\|\bMenuButtonStyleModifier\b' Sources App 2>/dev/null
```
Expected: 无输出

Run: `swift build`
Expected: EXIT=0

- [ ] **Step 5: 提交**

```bash
git add Sources/CoreDesign/Components/BottomInputBar/
git commit -m "refactor: MenuButton 家族改名 CoreMenuButton，避开 SwiftUI 同名类型"
```

---

### Task 5: 下游 probe 覆盖 + 全量验证 + 审计清单

**Files:**
- Modify: `scripts/downstream-probe/Sources/DownstreamProbe/NonisolatedUsage.swift`（追加一节）
- Modify: `.claude/epics/coredesign-audit-remediation/audit-checklist.md`

**Interfaces:**
- Consumes: Task 1–4 产出的全部公开符号

**为什么 probe 是唯一有效关卡：** 所有 SwiftPM 测试都跑在 CoreDesign target **内部**，internal 符号一样可见——补 `public` 是否真的生效，只有从外部包才看得见。这是 #92 建立 probe 的原因。

- [ ] **Step 1: 先做反向验证（红）——在没加 public 之前 probe 应报错**

跳过。改动已在 Task 1–4 落地，红态无法重现。改为 Step 2 的**正向 + 定点反证**：先跑通，再手工去掉 `CheckBoxToggleStyle` 的 `public` 复现 `cannot find in scope`，确认 probe 真的看得见这条契约，然后还原。

- [ ] **Step 2: 给 probe 追加公开面用例**

在 `NonisolatedUsage.swift` 末尾追加（注意这些是 MainActor 相关类型，用 `@MainActor` 函数而非 `nonisolated`——本节验证的是**可见性**，不是隔离）：

```swift
// MARK: - 公开可见性契约（Issue #94）
//
// 以下符号此前漏写 `public`，下游实测报 `cannot find in scope` /
// `initializer is inaccessible`。库内测试看不见这个问题——它们跑在 target
// 内部，internal 符号一样可达。只有从外部包才能守住这条契约。

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

nonisolated func readRolePalette(_ role: ButtonRoleStyleRole) -> [Color] {
    [role.color, role.activeColor, role.disabledColor]
}
```

- [ ] **Step 3: 构建 probe**

```bash
set -o pipefail
(cd scripts/downstream-probe && swift build 2>&1 | tail -20); echo "probe EXIT=$?"
```
Expected: `probe EXIT=0`，且输出中 0 个 `inaccessible` / `cannot find`

- [ ] **Step 4: 定点反证 probe 有效**

临时把 `CheckBoxToggleStyle` 的 `public struct` 改回 `struct`，重跑 Step 3。

Expected: 构建失败，报 `cannot find 'CheckBoxToggleStyle' in scope`（证明这条关卡真的通电）。

然后 `git checkout -- Sources/CoreDesign/Components/CheckBox/CheckBox.swift` 还原，重跑 Step 3 确认回到 EXIT=0。

- [ ] **Step 5: 四条 SwiftPM 命令 + warning 判据**

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
Expected: 四条 EXIT=0；warning 段全为 `(无)`；两条测试各 `95 tests in 32 suites passed`（Task 1 删的是视图类型不是测试，数量应不变——若变了要查清原因再往下走）

- [ ] **Step 6: DoD 的旧名扫描**

```bash
grep -rn '\bBorderlessButtonStyle\b\|\bMenuButton\b\|\bMenuButtonStyle\b' Sources App docs/components README.md 2>/dev/null
```
Expected: 无输出（`docs/superpowers/` 是历史归档，按 Global Constraints 排除）

- [ ] **Step 7: 更新审计清单**

把 `audit-checklist.md` 中 A2a、A2b、A2c、A3a、A3b、B9e 六项状态改为「✅ 已修复」，并核对计数不变：

```bash
echo $(( $(grep -c '^| [A-D][0-9]' .claude/epics/coredesign-audit-remediation/audit-checklist.md) - 4 ))
```
Expected: `83`

- [ ] **Step 8: 提交**

```bash
git add scripts/downstream-probe/Sources/DownstreamProbe/NonisolatedUsage.swift
git add .claude/epics/coredesign-audit-remediation/audit-checklist.md
git add .claude/epics/coredesign-audit-remediation/94-plan.md
git commit -m "test: probe 覆盖 #94 公开可见性契约并更新审计清单"
```

---

## 收尾

全部 Task 完成后：`oh-my-superpowers:verification-before-completion` → `finishing-a-development-branch` 走 Option 2 开 PR（**base = `epic/coredesign-audit-remediation`，禁止直合 main**）→ Copilot 不可用（`COPILOT_UNAVAILABLE_UNTIL=2026-08-01`），按 auto-fix skill §3.6 降级为 `superpowers-reviewer` 一轮，并在 PR 上留一条顶层评论记录降级。
