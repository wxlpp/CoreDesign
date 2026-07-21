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
| **前置 #93/#95 已合入**（基线 104 绿、`StatusColorsTests` 已引用 live `.statusAccentForeground`——两个前置都落地了） | 可开工 |
| **C4a spike 已验证**：`String(describing: Color.accent)` = `NamedColor(name: "brand-5", bundle: ...)`——正则 `name: "([^"]+)"` 可取 asset 名 | C4a 机制成立 |
| `brand/brand-5.colorset/Contents.json` light 分量 = red `0x00`/green `0x77`/blue `0xFA` = `#0077FA`；Contents.json 第一个 `color`（无 `appearances`）是 universal/light | C4a 解析 |
| asset guard（`CoreDesignTests.swift` 的 `BlossomAssetTests`）用 `FileManager` 查 `.colorset` 目录（macOS 不编译 `.car`） | C4b 沿用同法 |

## C2 五个恒真文件的处置（改写 > 删除，但改写必须证伪）

原则：**能改写成真行为断言的就改写**（覆盖更有价值），改不出真断言的才删。逐个：

| 文件 | 被测对象有无可断言的真行为 | 处置 |
|---|---|---|
| `SurfaceKindTests` | **测不了**：`SurfaceKind.background`/`border`/`cornerRadius` 是 `private extension`（`SurfaceModifier.swift:43`），`@testable` 只提升 internal、够不到 private；改 Sources 加可见性会破坏「只碰 Tests/」硬约束（`conflicts_with: []`）。ViewInspector 又是 Out of Scope | **断言瘦身**：删三个恒真 `.count` 断言，保留一个非-`@Test` 的编译期 case 守卫（`SurfaceKind` 是 public，误删 case 应编译失败） |
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

临时把 `brand/brand-5.colorset/Contents.json` 的 light red 改成 `0x11`——**`swift package clean` 后**再重跑默认档（macOS SPM 以目录分发 `.xcassets`，增量构建不拷贝改动，不 clean 会反证不出红，误判断言恒真）。`lightHex == "#0077FA"` 应红。还原后再 clean 重跑确认回绿。**这证明断言真的读了 Contents.json。**

- [ ] **Step 4: 提交**

```bash
git add Tests/CoreDesignTests/BlossomColorDivergenceTests.swift
git commit -m "test: Blossom trait 的真颜色值分流断言（C4a）"
```

---

### Task 2: C2 五个恒真文件改写/删除

**Files:** `SurfaceKindTests.swift`、`StatusColorsTests.swift`、`AvatarTests.swift`、`FloatingGlassModifierTests.swift`、`ProgressIndicatorTests.swift`

- [ ] **Step 1: `SurfaceKindTests` —— 断言瘦身（删恒真 `.count`，留非-`@Test` case 守卫）**

`SurfaceKind` 的 `background`/`border`/`cornerRadius` 是 `private extension`（`SurfaceModifier.swift:43`）——`@testable` 只提升 internal 到测试可见，**够不到 private**。而 `SurfaceKindTests` 现有的断言（`roles.count == 5` / `== 4`）断的是测试自己写的数组字面量长度，恒真、与被测代码无关。

`SurfaceKindTests` 现有 3 个 `@Test`，断的都是测试自己写的数组 `.count == N`——恒真、与被测代码无关。映射（`.card → surfaceCard/borderMuted/CoreRadius.medium`）是 private，从 Tests/ 无法断言（改 Sources 违约、ViewInspector Out of Scope）。

**但不整文件删除。** `SurfaceKind` 是 `public` API，那份 case 清单**本身是编译期引用**——误删某个 public case（尤其 `.canvasSubtle`/`.panel`/`.sidebar` 这类若无组件消费的 alias）会让它编译失败，拦住破坏性 API 变更。整删会连这层守卫一起丢。

**处置**：
1. **删三个恒真 `@Test`**（`roles.count == 5/4/9`）。
2. **保留一个非-`@Test` 的编译期 case 守卫**——`private static let`（类型级属性，`_` 通配绑定不能作类型级属性，必须命名）：
   ```swift
   import Testing
   @testable import CoreDesign

   @Suite("SurfaceKind")
   struct SurfaceKindTests {
       // 编译期 public API 守卫：误删任一 public case 会让本引用编译失败，
       // 拦住破坏性变更。**故意非 @Test**——它无运行时断言，避免触发
       // Step 5 Step 3 的 0-`#expect` 自检；恒真的 `.count` 断言已删。
       // token 映射是 private，Tests/ 内无法断言（改 Sources 违约 / ViewInspector Out of Scope）。
       private static let apiGuard: [SurfaceKind] = [
           .canvas, .content, .control, .floating, .overlay,
           .canvasSubtle, .panel, .sidebar, .card,
       ]
   }
   ```
   `apiGuard` 是 `static let`（类型作用域合法、无 unused warning、编译期检查全部 9 个 public case）。文件因此**不含 `@Test`**，逃过 0-`#expect` 自检；恒真 `.count` 也去掉了。

**C5 清单如实记**：`SurfaceKindTests.swift` | 恒真 `.count` 断言已删，保留非-`@Test` 编译期 case 守卫；**token 映射仍无运行时测试守护**（private，Tests/ 内不可断言，非「间接覆盖」）。文件从 3 test 降为 0 test。

- [ ] **Step 2: `StatusColorsTests` 改写成 asset 名断言**

复用 Task 1 的 `assetName` 思路，断言 5 组 status 色指向正确的 colorset（`String(describing:)` 取名）。这比「符号编译通过」有信息量——能捕获 status 色被误指向别的 asset。

- [ ] **Step 3: `AvatarTests` / `FloatingGlassModifierTests` / `ProgressIndicatorTests`**

Read 三个被测类型，判断有无可断言的**派生行为**。**先查可见性陷阱**（同 SurfaceKind——private/fileprivate 的 `@testable` 也够不到）：
- `Avatar`：断言首字母提取 / 尺寸派生（若这些是 internal+）；memberwise init 断言是编译器保证的，删。
- `FloatingGlassModifier` / `ProgressIndicator`：`body` 输出类型可能不可见（private），concrete-type 断言未必可行——查了再定。**改不出真断言就删**，不留恒真。

**改不出真断言就删**——留恒真断言比删除更糟（它是 SC-5「恒真断言归零」要清的对象）。

- [ ] **Step 4: 每个改写反证**

对改写的（非删除的）文件，临时改坏被测映射，确认新断言红。删除的不需要。

- [ ] **Step 5: 编译 + 测试**

```bash
swift build --build-tests > /tmp/t2.log 2>&1; echo "build EXIT=$?"
swift test > /tmp/t2t.log 2>&1; echo "test EXIT=$?"
```
**记下新测试数**（删除/瘦身会降、改写不变；`SurfaceKindTests` 由 3 test 降为 0——仅保留编译引用）。

- [ ] **Step 6: 提交**

```bash
git add Tests/CoreDesignTests/
git commit -m "test: 五个恒真断言文件改写为真行为断言 / 删除（C2）"
```

---

### Task 3: C4b asset guard 扩展

**Files:** `Tests/CoreDesignTests/CoreDesignTests.swift`

- [ ] **Step 1: 扩展 `BlossomAssetTests`**

现有 guard 覆盖 `blossom-brand-*`、`blossom-canvas-*`。**AC C4b 要求覆盖 `violet-0…9` 与 `cyan-1`**。加（group 名实测为 `violet` / `cyan`）：

```swift
@Test("Blossom 分流依赖的 violet / cyan colorsets 存在")
func gradientDepColorsetsPresent() {
    // AC C4b 指定 violet-0…9 全覆盖。实测真实消费点更窄：
    // CoreGradient.canvas 的 Blossom 分支用 violet-2 + cyan-1（CoreGradient.swift:57）；
    // InteractionColors.secondaryAccent 用 violet-5/6/7。全 0…9 覆盖是 AC 指定的过度守卫。
    for i in 0...9 {
        #expect(colorsetExists("violet", "violet-\(i)"), "missing violet-\(i)")
    }
    #expect(colorsetExists("cyan", "cyan-1"), "missing cyan-1")
}
```

> **注意**：这类 asset guard 读的是文件系统 bundle，**两种 trait 下都跑、都验文件在盘**（不验 trait 接线）——与现有 `BlossomAssetTests` 同性质，弱于「守护分流」但符合 AC。group 名已实测 `violet` / `cyan`，实施前再 `find Sources/CoreDesign/Resources -type d -name 'violet' -o -type d -name 'cyan'` 复核一次。

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

四项标 `✅ 已修复（GitHub #98）`。计数核对用 **`- 4`**（实测 `grep -c '^| [A-D][0-9]'` = 87，减去文末「不修理由」表的 4 行 = 83）：

```bash
echo $(( $(grep -c '^| [A-D][0-9]' audit-checklist.md) - 4 ))   # => 83
```
Expected: `83`。

> **98.md:59 写的 `- 5` 是陈旧的**（会得 82）——以 `audit-checklist.md` 顶部实际的 `- 4` 为准。附录的文件名行（`| ProgressIndicatorTests.swift |`、`| CheckBoxToggleStyle |` 等）不匹配 `^| [A-D][0-9]`，不影响计数，已确认安全。
>
> 另：`audit-checklist.md` 顶部与 `98.md:16` 的基线仍写「96 tests」，实际是 **104**（前序 Issue 增加）——本任务的 PR 文案用 104，不要传播旧数字。

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
# type(of:).isEmpty 是恒真模式；.count == N 只有断言**自写数组字面量**长度才恒真——
# ToastHostTests/AsyncButtonTests 的 host.queue.count == N 是**真行为断言**（队列长度），
# 必须排除，否则这条 SC-5 验收命令永远达不成。
grep -rn 'type(of:.*isEmpty' Tests/CoreDesignTests/ | cat
grep -rn '\.count == [0-9]' Tests/CoreDesignTests/ \
  | grep -vE 'DynamicTypeLayout|queue\.count' | cat
grep -rln '@Test' Tests/CoreDesignTests/ | while read f; do
  [ "$(grep -c '#expect\|#require' "$f")" = 0 ] && echo "0-expect: $f"
done
```
Expected: 无 `type(of:).isEmpty` 恒真；无「断言自写数组长度」的 `.count`（`queue.count == N` 是真断言，已排除）；无 0-`#expect` 文件。

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
