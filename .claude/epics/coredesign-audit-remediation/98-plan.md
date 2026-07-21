# 测试质量重建 + Blossom 断言 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use oh-my-superpowers:subagent-driven-development (recommended) or oh-my-superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把「104 tests passed」这个失真信号修正为可信信号——删/改恒真断言、补 Blossom 分流的真颜色断言、为零测试目标产出逐文件处置清单。

**Architecture:** 纯测试改动。**只碰 `Tests/` 与 `audit-checklist.md`，不碰任何 `Sources/`**（`conflicts_with: []` 的根据）。风险不在编译（改测试编译器会报），而在**把恒真断言改写成另一个恒真断言**（换个写法仍必过）。

**Tech Stack:** SwiftPM / Swift 6 / Swift Testing。不引入 XCTest、不引入外部测试依赖（Out of Scope）。

## Global Constraints

- 四条 SwiftPM 命令绿。**warning 采集前 `swift package clean`**。
- **改动全部落在 `Tests/` 与 `audit-checklist.md`**——收尾 `git diff --name-only` 自查未触碰 `Sources/`。
- **改写恒真断言时，新断言必须能被真实缺陷证伪**——反证：临时改坏被测代码，新断言应红。换个写法仍恒真等于没做（这是本任务最容易自欺的点）。
- **不得改 CI 的 `-skip-testing` 列表**：`DynamicTypeLayoutTests`（#95 落地）必须继续跑；本任务新增/改写的测试也不能被 skip。
- 代码风格：`import Testing` / `@Test` / `#expect`，显式 `self.`，中英双语注释。

## 已实测的前置事实（不要重新推导）

| 事实 | 影响 |
|---|---|
| 基线绿：104 tests / 32 suites passed | 起点 |
| **两个 0-`#expect` 文件**：`ProgressIndicatorTests`（`_ = ProgressIndicator()`）、`StatusColorsTests`（5 个 `let _: Color = ...`） | C2 |
| 三个恒真 `#expect`：`FloatingGlassModifierTests`（`type(of:).isEmpty == false`）、`SurfaceKindTests`（断言自写数组 `.count`）、`AvatarTests`（memberwise init 赋值） | C2 |
| **保留**（真行为测试）：`ToastHostTests`、`AsyncButtonTests`、`ProgressBarTests`、`ListRowTests` | C2 |
| `KeyboardHandlingTests` 已随 #97 删除 | C5 清单记「已由 #97 删除」 |
| **C4a spike 已验证**：`String(describing: Color.accent)` = `NamedColor(name: "brand-5", bundle: ...)`——正则 `name: "([^"]+)"` 可取 asset 名 | C4a 机制成立 |
| `brand/brand-5.colorset/Contents.json` light 分量 = red `0x00`/green `0x77`/blue `0xFA` = `#0077FA`；Contents.json 第一个 `color`（无 `appearances`）是 universal/light | C4a 解析 |
| asset guard（`CoreDesignTests.swift` 的 `BlossomAssetTests`）用 `FileManager` 查 `.colorset` 目录（macOS 不编译 `.car`） | C4b 沿用同法 |

## C2 五个恒真文件的处置（改写 > 删除，但改写必须证伪）

原则：**能改写成真行为断言的就改写**（覆盖更有价值），改不出真断言的才删。逐个：

| 文件 | 被测对象有无可断言的真行为 | 处置 |
|---|---|---|
| `SurfaceKindTests` | **有**：每个 `SurfaceKind` 的 `background`/`border`/`cornerRadius` token 映射（`SurfaceModifier.swift`，#96/#97 动过） | 改写成断言真映射 |
| `StatusColorsTests` | **有**：5 组 status 色的 asset 名（与 C4a 同法，`String(describing:)` 取名） | 改写成 asset 名断言 |
| `AvatarTests` | 部分：memberwise init 是编译器保证的，但可断言 `Avatar` 的**派生行为**（如首字母提取、尺寸） | 改写成派生行为断言，改不出则删 |
| `FloatingGlassModifierTests` | 弱：modifier 无值可断言，`type(of:)` 恒真 | 改写成 concrete-type 断言（能捕获泛型 slot 回退，如 `ListRowTests` 的做法），或删 |
| `ProgressIndicatorTests` | 需看 `ProgressIndicator` 实现有无可断言状态 | 有则改写，无则删 |

**每个改写后必须反证**：临时改坏被测映射/asset，新断言应红。

---

### Task 1: C4a Blossom 分流断言（核心，机制已 spike）

**Files:**
- Create: `Tests/CoreDesignTests/BlossomColorDivergenceTests.swift`

- [ ] **Step 1: 建分流断言**

```swift
import SwiftUI
import Testing
import Foundation
@testable import CoreDesign

// Blossom trait 分流的**真颜色值**断言（C4a）。
//
// swift test 下 asset 颜色无法解析（SPM 不调 actool，Color.accent.resolve()
// 返回 (0,0,0,0)）。故走：String(describing: Color) 取 asset 名 → 解析对应
// colorset/Contents.json 的 light sRGB 分量 → 按 #if Blossom 断言期望值。
@Suite("Blossom 颜色分流")
struct BlossomColorDivergenceTests {

    /// 从 `String(describing: Color)` 提取 asset 名（spike 实证格式：
    /// `NamedColor(name: "brand-5", bundle: ...)`）。
    private func assetName(of color: Color) -> String? {
        let desc = String(describing: color)
        guard let r = desc.range(of: #"name: "([^"]+)""#, options: .regularExpression) else { return nil }
        return String(desc[r]).replacingOccurrences(of: #"name: ""#, with: "").dropLast().description
    }

    /// 读 `<group>/<name>.colorset/Contents.json` 的 **light**（无 appearances 的第一个 color）
    /// sRGB 分量，返回 `#RRGGBB` 大写。
    private func lightHex(group: String, name: String) -> String? {
        guard let base = Bundle.module.resourceURL?.appendingPathComponent("Resources.xcassets"),
              let data = try? Data(contentsOf: base.appendingPathComponent("\(group)/\(name).colorset/Contents.json")),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let colors = json["colors"] as? [[String: Any]] else { return nil }
        // 第一个没有 appearances 的 color = universal/light
        guard let light = colors.first(where: { $0["appearances"] == nil }),
              let c = light["color"] as? [String: Any],
              let comp = c["components"] as? [String: String],
              let r = comp["red"], let g = comp["green"], let b = comp["blue"] else { return nil }
        func hex(_ s: String) -> String {
            // 值形如 "0xFA"；也兼容 "1.000" 之类的十进制（此处 colorset 用 0xNN）
            if s.hasPrefix("0x") { return String(s.dropFirst(2)).uppercased().leftPad(2) }
            let v = Int((Double(s) ?? 0) * 255)
            return String(format: "%02X", v)
        }
        return "#\(hex(r))\(hex(g))\(hex(b))"
    }

    @Test("accent 的实际颜色值随 trait 分流")
    func accentDivergesByTrait() {
        let name = self.assetName(of: Color.accent)
        #expect(name != nil, "无法从 Color.accent 取 asset 名")

        #if Blossom
        #expect(name == "blossom-brand-5", "Blossom 下 accent 应指向 blossom-brand-5，实为 \(name ?? "nil")")
        #expect(self.lightHex(group: "blossom-brand", name: "blossom-brand-5") == "#FF6F8E")
        #else
        #expect(name == "brand-5", "默认下 accent 应指向 brand-5，实为 \(name ?? "nil")")
        #expect(self.lightHex(group: "brand", name: "brand-5") == "#0077FA")
        #endif
    }
}

private extension String {
    func leftPad(_ n: Int) -> String { count >= n ? self : String(repeating: "0", count: n - count) + self }
}
```

> ⚠️ **实施前先跑一次确认 `String(describing: Color.accent)` 在 Blossom 下确实变成 `blossom-brand-5`**（spike 只验证了默认档）。若 Blossom 下 asset 名不变（说明 accent 的 `#if Blossom` 分流没走 asset 名而是别的机制），此断言的分流前提不成立，停下核对 `InteractionColors` 的 accent 定义。

- [ ] **Step 2: 两种 trait 都跑**

```bash
swift test --filter BlossomColorDivergence > /tmp/c4a.log 2>&1; echo "default EXIT=$?"
grep -o 'accent 应指向[^"]*\|#0077FA\|passed' /tmp/c4a.log | head -2
swift test --traits Blossom --filter BlossomColorDivergence > /tmp/c4ab.log 2>&1; echo "blossom EXIT=$?"
```
Expected: 两种模式**都绿**，且断言的期望值不同（默认 `brand-5`/`#0077FA`，Blossom `blossom-brand-5`/`#FF6F8E`）。

- [ ] **Step 3: 反证机制通电**

临时把 `brand/brand-5.colorset/Contents.json` 的 light red 改成 `0x11`，重跑默认档——`lightHex == "#0077FA"` 应红。还原。**这证明断言真的读了 Contents.json，不是恒真。**

- [ ] **Step 4: 提交**

```bash
git add Tests/CoreDesignTests/BlossomColorDivergenceTests.swift
git commit -m "test: Blossom trait 的真颜色值分流断言（C4a）"
```

---

### Task 2: C2 五个恒真文件改写/删除

**Files:** `SurfaceKindTests.swift`、`StatusColorsTests.swift`、`AvatarTests.swift`、`FloatingGlassModifierTests.swift`、`ProgressIndicatorTests.swift`

- [ ] **Step 1: `SurfaceKindTests` 改写成真映射断言**

删掉 `roles.count == N` 那类自证断言，改为断言每个 `SurfaceKind` 的 `background`/`border`/`cornerRadius` token（Read `SurfaceModifier.swift` 取真值）。例如：

```swift
@Test("card surface 的 token 映射")
func cardMapping() {
    #expect(SurfaceKind.card.background == .surfaceCard)
    #expect(SurfaceKind.card.border == .borderMuted)
    #expect(SurfaceKind.card.cornerRadius == CoreRadius.medium)
}
```
**注意**：`SurfaceKind.background/border/cornerRadius` 若非 public/internal 可见，用 `@testable` 已导入。Read 确认属性可见性。

- [ ] **Step 2: `StatusColorsTests` 改写成 asset 名断言**

复用 Task 1 的 `assetName` 思路，断言 5 组 status 色指向正确的 colorset（`String(describing:)` 取名）。这比「符号编译通过」有信息量——能捕获 status 色被误指向别的 asset。

- [ ] **Step 3: `AvatarTests` / `FloatingGlassModifierTests` / `ProgressIndicatorTests`**

Read 三个被测类型，判断有无可断言的**派生行为**：
- `Avatar`：断言首字母提取 / 尺寸派生（若有），否则删 memberwise init 断言。
- `FloatingGlassModifier` / `ProgressIndicator`：若无值可断言，用 concrete-type 断言（`#expect(view is 具体类型)`，能捕获泛型 slot 回退）或删。

**改不出真断言就删**——留恒真断言比删除更糟（它是 SC-5「恒真断言归零」要清的对象）。

- [ ] **Step 4: 每个改写反证**

对改写的（非删除的）文件，临时改坏被测映射，确认新断言红。删除的不需要。

- [ ] **Step 5: 编译 + 测试**

```bash
swift build --build-tests > /tmp/t2.log 2>&1; echo "build EXIT=$?"
swift test > /tmp/t2t.log 2>&1; echo "test EXIT=$?"
```
**记下新测试数**（删除会降、改写不变）。

- [ ] **Step 6: 提交**

```bash
git add Tests/CoreDesignTests/
git commit -m "test: 五个恒真断言文件改写为真行为断言 / 删除（C2）"
```

---

### Task 3: C4b asset guard 扩展

**Files:** `Tests/CoreDesignTests/CoreDesignTests.swift`

- [ ] **Step 1: 扩展 `BlossomAssetTests`**

现有 guard 覆盖 `blossom-brand-*`、`blossom-canvas-*`。Blossom 分流的 `canvas` 还依赖 `violet-0…9` 与 `cyan-1`（`CoreGradient.canvas` 的 Blossom 分支）。加：

```swift
@Test("blossom canvas 渐变依赖的 violet / cyan colorsets 存在")
func gradientDepColorsetsPresent() {
    for i in 0...9 {
        #expect(colorsetExists("violet", "violet-\(i)"), "missing violet-\(i)")
    }
    #expect(colorsetExists("cyan", "cyan-1"), "missing cyan-1")
}
```

> ⚠️ **先 grep 确认 `violet` / `cyan` 的真实 group 目录名**（可能是 `violet` 或别的）：
> ```bash
> find Sources/CoreDesign/Resources -type d -name 'violet-*' -o -type d -name 'cyan-*' | head
> ```
> 用实测的 group/name，别照抄。

- [ ] **Step 2: 验证**

```bash
swift test --filter BlossomAsset > /tmp/t3.log 2>&1; echo "EXIT=$?"
```
反证：临时把断言里某个 index 改成不存在的（如 `violet-99`），应红。还原。

- [ ] **Step 3: 提交**

```bash
git add Tests/CoreDesignTests/CoreDesignTests.swift
git commit -m "test: asset guard 扩展到 violet/cyan（Blossom 渐变依赖，C4b）"
```

---

### Task 4: C5 逐文件处置清单 + 审计清单

**Files:** `.claude/epics/coredesign-audit-remediation/audit-checklist.md`

- [ ] **Step 1: 产出逐文件处置清单（C2 + C5 两份名单）**

作为 **C2 附录**落到 `audit-checklist.md`。**首列必须是测试文件名**（`| ProgressIndicatorTests.swift |`），**不得**用 `| C2a |` 形态——否则破坏顶部计数命令。表格覆盖：

- C2 的 5 个恒真文件：每个标「已改写为真断言」/「已删除」+ 一句做法
- C5 的约 15 个零测试目标（`CheckBoxToggleStyle`、`Form`、`CoreMenuButton`、四个 ButtonStyle、`ButtonRoleStyleRole`、token 层、modifier、`StarShape`、`ColorExtension`）：每个标「本轮补测」/「记录不补 + 理由」
- `KeyboardHandlingTests`：标「已由 #97 删除」

**大多数 C5 目标标「记录不补 + 理由」**（AC 明确不要求全补）——理由如「纯声明无行为」「已由 X 的测试间接覆盖」。少数值得补的（若有）标「本轮补测」。

- [ ] **Step 2: 标记 C2/C4a/C4b/C5 四项 + 计数核对**

四项标 `✅ 已修复（GitHub #98）`。计数核对（**注意 98.md 说 `- 5`，因附录会加一批文件名行，但那些不是 `^| [A-D][0-9]` 形态，所以计数仍是 83**）：

```bash
echo $(( $(grep -c '^| [A-D][0-9]' audit-checklist.md) - 4 ))
```
Expected: `83`（附录的文件名行不匹配 `^| [A-D][0-9]`，不影响计数）。

> 若 98.md 顶部写的是 `- 5`，以 `audit-checklist.md` 顶部实际的核对命令为准——本任务不改那条命令，只确认附录不破坏它。

- [ ] **Step 3: 提交**

```bash
git add .claude/epics/coredesign-audit-remediation/audit-checklist.md
git commit -m "docs(ccpm): C5 逐文件测试处置清单 + 标记 C2/C4a/C4b/C5（附录首列为文件名）"
```

---

### Task 5: 全量验证 + 交接

- [ ] **Step 1: 四条 SwiftPM 命令（clean 后冷跑）**

```bash
LOGDIR="${TMPDIR:-/tmp}/coredesign-98"; mkdir -p "$LOGDIR"
swift package clean
swift build                  > "$LOGDIR/b.log"  2>&1; echo "build          EXIT=$?"
swift test                   > "$LOGDIR/t.log"  2>&1; echo "test           EXIT=$?"
swift build --traits Blossom > "$LOGDIR/bb.log" 2>&1; echo "build-blossom  EXIT=$?"
swift test  --traits Blossom > "$LOGDIR/tb.log" 2>&1; echo "test-blossom   EXIT=$?"
```
warning 全 0。两侧测试数记下（C4a 分流断言在两侧断言值不同，但都绿）。

- [ ] **Step 2: 只碰 Tests/ 自查**

```bash
git diff --name-only epic/coredesign-audit-remediation..HEAD | grep -vE '^(Tests/|\.claude/)' ; echo "rc=$?"
```
Expected: `rc=1`，无输出——改动全在 `Tests/` 与 `.claude/`，未触碰 `Sources/`（`conflicts_with: []` 的保证）。

- [ ] **Step 3: 恒真断言归零自查**

```bash
grep -rn 'type(of:.*isEmpty\|\.count == [0-9]' Tests/CoreDesignTests/ | grep -v 'DynamicTypeLayout' | cat
grep -rln '@Test' Tests/CoreDesignTests/ | while read f; do
  [ "$(grep -c '#expect\|#require' "$f")" = 0 ] && echo "0-expect: $f"
done
```
Expected: 无恒真模式残留；无 0-`#expect` 文件。

- [ ] **Step 4: 写 `updates/98/progress.md`**

C2 五文件的逐个处置、C4a 机制（String(describing:) + Contents.json）、C4b 扩展、C5 清单摘要、测试数变化、给下游的交接（测试地基已可信）。

- [ ] **Step 5: 提交**

```bash
git add .claude/epics/coredesign-audit-remediation/
git commit -m "docs(ccpm): #98 完成记录"
```

---

## 收尾

`verification-before-completion` → `finishing-a-development-branch` Option 2 开 PR（**base = `epic/coredesign-audit-remediation`**）→ Copilot 不可用，按 §3.6 降级为 `superpowers-reviewer` 并在 PR 留顶层评论。

PR 描述必须包含：C4a 分流断言在两种 trait 下的期望值差异、C2 五文件的处置、C5 清单摘要、恒真断言归零的证据。
