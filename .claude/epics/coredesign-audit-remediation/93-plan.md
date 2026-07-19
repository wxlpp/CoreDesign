# Issue #93 色彩层重组 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use oh-my-superpowers:subagent-driven-development (recommended) or oh-my-superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把第 4 层色彩的职责收窄为「状态功能别名」，消灭与第 3 层重复的色阶、三处 A1 型遮蔽、以及 `StatusColors` 的新旧两套并行 scale。

**Architecture:** 三个性质不同的阶段。**发现**（毒丸 commit，让编译器穷举遮蔽符号的残留使用点）→ **准备**（补齐新体系缺的 `*Border` 档、修正五组 `emphasis`，这是迁移的前置）→ **机械改写**（四处 legacy 迁移 + 删除三组色别名 + 别名层级修正）。发现阶段的产出是权威清单，后两阶段照它执行。

**Tech Stack:** Swift 6.3 / SwiftPM Package Traits / SwiftUI Color assets

## Global Constraints

- 部署目标 iOS 26+ / macOS 26+，`swiftLanguageModes: [.v6]`，`defaultIsolation(MainActor.self)` 已由 #92 启用
- 代码风格：显式 `self.`、中英双语注释（见 `CLAUDE.md`）
- 验证标准：四条 SwiftPM 命令 + `scripts/downstream-probe` 构建。本任务不涉及布局断言，无需 `xcodebuild` Simulator（那是 #95）
- **「零 warning」= 不新增 warning**。基线 `swift test` 有 12 条 `EmptyState` deprecation（属 #97 范围）。判据按 message 来源过滤，**不用 `grep -c` 计数**（随编译粒度漂移），**不先跑 `swift build` 预热**（会把库诊断丢弃且不再重放）
- 日志目录 `${TMPDIR:-/tmp}/coredesign-93`，用前 `mkdir -p`，读前 `[ -s ]` 断言非空
- 四条命令**逐条跑、不串 `&&`**（管道会吞退出码）；需要串时先 `set -o pipefail`
- **增删 colorset 后必须 `swift package clean` 再验证**——macOS SPM 以目录而非 `.car` 分发 `.xcassets`，增量构建不会拷贝新目录，不 clean 会让验证假绿
- `ToastHostTests` 有 3 个 timing 用例会 flake（`进入 dismissing 状态` / `double-fire` / `advance 到下一条`）：先重跑一次，连续两次失败才算真红。**另两个 `dismiss(id:)` 开头的用例不是 flake**，失败即真红
- **不碰 #97 的删除名单**：`EmptyState.swift`、`Utils/View+SizeReader.swift`、`Utils/KeyboardHandling.swift` 及其两个测试
- `StatusColorsTests.swift` 本任务只负责让它**编译通过**；恒真断言的整体清理归 #98
- 该库当前无外部使用者，已删 API **不需要**迁移说明或过渡期

## 开工前已确立的事实（探针实测 + 用户决策，直接采信）

### 毒丸给出的权威残留清单

恰好 **3 处**，两种 trait 一致，与审计吻合，无隐藏点：

```
Components/CheckBox/CheckBox.swift:31:44    'primary'   is deprecated
Components/StatusRow/StatusRow.swift:80:32  'secondary' is deprecated
Colors/CoreGradient+Preview.swift:17:63     'secondary' is deprecated
```

> **毒丸必须贴全两个 trait 分支。** `FunctionalColor.swift` 的 secondary 组在 `#if Blossom`（violet）与 `#else`（lightBlue）中各声明一次，共 **16 处声明 / 12 个符号**。实测教训：只贴中 Blossom 分支时，默认构建诊断只报 1 处、看起来干净——那是**静默不完整**，正是毒丸本该防的失败模式。两种 trait 都要编译。

### 三条改判（已同步进 `audit-checklist.md` 与 PRD，commit `8c2f310`）

1. **`statusAccent*` 保留，不删**。删它与本任务自身的 legacy 迁移冲突——新体系只有 `statusAccent*` 一个蓝色家族，而它正是 Primer 的 info 语义（**注意与 `Color.accent` 区分**：后者 = `brand5`，Blossom 下是珊瑚粉；`statusAccent*` 是 `StatusColors` 里不分流的 Primer 蓝），`Banner`/`Toast`/`Badge` 的 legacy `info*` 只能迁到它。D19 原判据「库内零渲染消费点」在迁移完成后不再成立。
2. **五组 `emphasis` 的 light 值全错，不是 accent 单组笔误**。`accent`/`success`/`attention`/`danger`/`done` 的 `*-emphasis` light 值逐组等于同组 `*-muted`；Primer 语义里 emphasis 是饱和实色。本轮一并修正。
3. **迁移会改变 dark 观感**，已列入 NFR 视觉例外：legacy 用不透明原子色（`blue-1` dark `#0A4694`），新体系 dark 是 alpha 叠加（`#1F6FEB @13.3%`）。这是 Primer 的标准做法，能随底层 surface 自适应，比 legacy 写死实色更正确。

### 迁移映射表（NFR 视觉零回归的判定基础）

legacy 三档 → 新体系。`info` → `accent` 家族（Primer 里 accent 即 info 蓝）：

| legacy | 原子色 | 新体系 | 依据 |
|---|---|---|---|
| `*Foreground` | ramp 7（`blue7` 等） | `status*Foreground` | 同为前景文本色，语义直接对应 |
| `*Background` | ramp 1（`blue1` `#CBE7FE`） | `status*Muted` | Primer `muted` = 有色背景块的标准档；`subtle` 更淡（faint highlight），用于选区高亮而非 Banner/Badge 底色 |
| `*Border` | ramp 3（`blue3` `#65B2FC`） | `status*Border`（**本任务新增**） | 见下 |

**新增 4 个 `status-*-border.colorset` 的取值**（`accent`/`success`/`attention`/`danger`，**不建 `done` 组**——它无 legacy 先例、本任务零消费者，属加法，留到有需求时再补）：

取各组 `*-emphasis` 修正后的值 @ 40% alpha，light / dark 同法。理由：

- Primer **确有** `borderColor.{accent,success,attention,danger}.{muted,emphasis}` 这一族（`BorderColors.swift:43` 的注释就引用了 `Primer borderColor.accent.emphasis`），所以不存在「Primer 无 border 档」这回事——本任务对齐它
- 用同组 emphasis 派生，边框与背景自动同色系协调；而新体系 dark 背景是 alpha 叠加，若边框沿用 legacy 的不透明原子色 3 档，会在半透明背景上过分抢眼，产出一块混色板
- **不沿用 legacy 原子色 3 档**：迁移的 fg / bg 两档 light 值本就全变（见下方视觉变化说明），「保持 light 零回归」这个理由不成立，不能只在 border 档上假装成立

**四组 legacy → 新体系的组名对应**：`info`→`accent`、`success`→`success`、`warning`→`attention`、`danger`→`danger`。`done` 组本任务不涉及，border 档也不补。

**迁移的视觉变化（已列入 NFR 例外第 8、9 条，不是回归）**：两套 scale 取自不同来源，light 值 8 处全变，其中 **`warning` 前景从 `#A84A00`（橙）变为 `#9A6700`（橄榄黄）是色相改变**，在 `Banner`/`Toast`/`Badge` 三处可见；dark 侧则从不透明实色变为 alpha 叠加。

---

### Task 1: 毒丸 commit —— 让编译器穷举遮蔽符号的残留使用点

**Files:**
- Modify: `Sources/CoreDesign/Colors/FunctionalColor.swift`（临时加 16 处 `@available`）

**Interfaces:**
- Consumes: 无
- Produces: 残留使用点的权威清单，Task 2 照它逐处改写。本 commit 保留在历史中作为该清单的证据（93.md 验收标准要求）。

- [ ] **Step 1: 确认基线绿**

```bash
cd /Users/evan/Repositories/work-spec/CoreDesign/.worktrees/issue-93-color-layer
swift build 2>&1 | tail -1
```

Expected: `Build complete!`

- [ ] **Step 2: 给 12 个遮蔽符号加毒丸（16 处声明）**

`Sources/CoreDesign/Colors/FunctionalColor.swift`，给 `primary`/`secondary`/`tertiary` 三组的每一处 `static let` 声明加上一行：

```swift
@available(*, deprecated, message: "A1 probe: shadows SwiftUI builtin")
```

**注意 secondary 组在 `#if Blossom` / `#else` 中各声明一次，两处都要贴**。可用脚本确保不漏：

```bash
python3 - <<'PY'
import io,re
p='Sources/CoreDesign/Colors/FunctionalColor.swift'
s=io.open(p,encoding='utf-8').read()
names=['primary','primaryActive','primaryDisable','primaryHover',
       'secondary','secondaryActive','secondaryDisable','secondaryHover',
       'tertiary','tertiaryActive','tertiaryDisable','tertiaryHover']
n=0
for nm in names:
    pat=re.compile(rf'^(\s*)((?:public )?static let {nm}\b)', re.M)
    def rep(m):
        global n; n+=1
        return f'{m.group(1)}@available(*, deprecated, message: "A1 probe: shadows SwiftUI builtin")\n{m.group(1)}{m.group(2)}'
    s=pat.sub(rep,s)   # 不设 count,两个 trait 分支都贴
io.open(p,'w',encoding='utf-8').write(s)
print(f"毒丸已加: {n} 处声明")
PY
```

Expected: `毒丸已加: 16 处声明`

若不是 16，说明 `FunctionalColor.swift` 的声明形态与预期不符，**停下来核对**，不要继续——贴漏会给出静默不完整的假清单。

- [ ] **Step 3: 两种 trait 各编译一次，取残留清单**

```bash
LOGDIR="${TMPDIR:-/tmp}/coredesign-93"; mkdir -p "$LOGDIR"
swift build 2>&1 | grep -aE "\.swift:[0-9]+:[0-9]+: warning:.*A1 probe" \
  | sed 's|.*/CoreDesign/||' | sort -u | tee "$LOGDIR/a1-default.txt"
swift build --traits Blossom 2>&1 | grep -aE "\.swift:[0-9]+:[0-9]+: warning:.*A1 probe" \
  | sed 's|.*/CoreDesign/||' | sort -u | tee "$LOGDIR/a1-blossom.txt"
diff "$LOGDIR/a1-default.txt" "$LOGDIR/a1-blossom.txt" && echo "两种 trait 清单一致 ✓"

# 库 target 之外:Tests/ 与 App/ 是独立编译单元,毒丸的 swift build 覆盖不到。
# 补跑 test target,并 grep App/(它不进 SwiftPM 构建)。
swift test 2>&1 | grep -aE "\.swift:[0-9]+:[0-9]+: warning:.*A1 probe" | sed 's|.*/CoreDesign/||' | sort -u
grep -rnE '(Color\.|: Color = \.)(primary|secondary|tertiary)\b' App/Sources/ || echo "App/ 无 Color.primary/secondary/tertiary 引用"
```

Expected: 两个文件内容相同，各 3 行：

```
Colors/CoreGradient+Preview.swift:17:63: warning: 'secondary' is deprecated: A1 probe: shadows SwiftUI builtin
Components/CheckBox/CheckBox.swift:31:44: warning: 'primary' is deprecated: A1 probe: shadows SwiftUI builtin
Components/StatusRow/StatusRow.swift:80:32: warning: 'secondary' is deprecated: A1 probe: shadows SwiftUI builtin
```

Expected（补跑部分）：`swift test` 侧无额外条目；`App/` 侧无输出。

> 注意 `Sources/` 里另有 20 多处 `.foregroundStyle(.secondary)` / `.tertiary` **不会**被毒丸报出，也不受删除影响——它们在泛型 `ShapeStyle` 位置解析为 `HierarchicalShapeStyle`，走的是另一条重载。只有显式写 `Color.primary` 或处于 `-> Color` 上下文的裸 `.secondary` 才会命中被遮蔽的符号。

**若出现第 4 处**，说明审计有遗漏——把它一并纳入 Task 2 的改写清单，不要忽略。

- [ ] **Step 4: Commit（保留毒丸在历史中）**

```bash
git add Sources/CoreDesign/Colors/FunctionalColor.swift
git commit -m "Issue #93: A1 poison-pill probe to enumerate shadowed-symbol uses

Deleting Color.primary/secondary/tertiary does not fail to compile -- the
references silently re-resolve to SwiftUI's built-ins. Marking them
deprecated makes the compiler name every remaining use instead. Must be
deprecated, not unavailable: overload resolution drops unavailable
candidates entirely and the probe reports nothing.

Both trait branches are marked (secondary is declared twice, under #if
Blossom and #else), and both trait modes were compiled -- marking only one
branch reports a single use and looks clean.

Result, identical in both modes: CheckBox.swift:31, StatusRow.swift:80,
CoreGradient+Preview.swift:17."
```

---

### Task 2: 按毒丸清单逐处改写，然后删除三组色别名

**Files:**
- Modify: `Sources/CoreDesign/Components/CheckBox/CheckBox.swift:21-23,31`
- Modify: `Sources/CoreDesign/Components/StatusRow/StatusRow.swift:80`
- Modify: `Sources/CoreDesign/Colors/CoreGradient+Preview.swift:17`
- Modify: `Sources/CoreDesign/Colors/FunctionalColor.swift`（删三组 + 删毒丸 + 补 `public` + `danger` 基准）

**Interfaces:**
- Consumes: Task 1 的残留清单
- Produces: `Color.primary/secondary/tertiary` 及其 9 个变体不复存在；`FunctionalColor` extension 为 `public`，只余 `success`/`info`/`warning`/`danger` 及其现有变体。后续任何 Issue 若需交互色，走第 3 层 `InteractionColors` 的 `accent*` / `secondaryAccent*` / `neutralAccent*`。

- [ ] **Step 1: 改写 `CheckBox.swift:31`**

把

```swift
                    .foregroundStyle(Color.primary)
```

改为

```swift
                    .foregroundStyle(Color.contentPrimary)
```

并修正 21–23 行与行为矛盾的注释——原注释称「`Color.primary` / `Color.gray` 自动适配系统外观」，但遮蔽使它实际渲染成品牌色。改为：

```swift
/// - 选中态 `checkmark.square.fill` 用 `Color.contentPrimary`、未选中 `square` 用 `Color.gray`——
///   前者是语义层的主文本色，light / dark 自动适配系统外观。
```

- [ ] **Step 2: 改写 `StatusRow.swift:80`**

`resultColor` 的 `case .skipped` 从

```swift
        case .skipped: return .secondary
```

改为

```swift
        case .skipped: return .contentSecondary
```

> 这一处的行为**会变**：原先因遮蔽而渲染成 `lightBlue5`（Blossom 下 `violet5`），改后是语义层的次要文本灰——即作者本意。已列入 NFR 视觉例外第 7 条。

- [ ] **Step 3: 改写 `CoreGradient+Preview.swift:17`**

把 `Color.secondary` 改为 `Color.secondaryAccent`——该 Preview 的意图是展示品牌次要色（Blossom 下为 violet），走第 3 层别名后语义明确且仍随 trait 分流：

```swift
                RoundedRectangle(cornerRadius: 12).fill(Color.secondaryAccent).frame(height: 56)
```

- [ ] **Step 4: 确认毒丸诊断已归零**

```bash
LOGDIR="${TMPDIR:-/tmp}/coredesign-93"; mkdir -p "$LOGDIR"
# 不用 `grep -c`——本步只改了另外三个文件,若 FunctionalColor.swift 未被重编译,
# 诊断不会重放,计数返回 0 而门禁空过,正是毒丸要防的静默失败。
# 复用 Task 1 Step 3 已验证的形态,并断言日志非空以证明确实编译过。
swift package clean
swift build 2>&1 | tee "$LOGDIR/gate-default.log" | tail -1
swift build --traits Blossom 2>&1 | tee "$LOGDIR/gate-blossom.log" | tail -1
for f in "$LOGDIR/gate-default.log" "$LOGDIR/gate-blossom.log"; do
  [ -s "$f" ] || { echo "日志为空,门禁无效"; exit 1; }
  grep -aE "\.swift:[0-9]+:[0-9]+: warning:.*A1 probe" "$f" | sed 's|.*/CoreDesign/||' | sort -u
done
echo "--- 以上为空即通过 ---"
```

Expected: 两个日志都非空（证明真的编译了），且残留清单**无输出**。**有任何输出则不许进入 Step 5** —— 删符号前必须零诊断。

- [ ] **Step 5: 删除三组色别名与毒丸，补 `public`，修 `danger` 基准**

`Sources/CoreDesign/Colors/FunctionalColor.swift`：

1. 删除 `primary`/`secondary`/`tertiary` 三组共 16 处声明（含刚加的毒丸注解、含 `#if Blossom` / `#else` 两个分支）。若该 `#if Blossom` 块删空，整块一并删除——这是 SC-2 要求的分流点净减
2. **注意 `FunctionalColor.swift` 有两个 `extension Color`**（`:11` 与 `:35`）：`:11-33` 那个的全部内容就是要删的三组，**整块删除**；`public` 加在 `:35` 那个上（A2d：第 4 层此前整层 internal，与 CLAUDE.md 称它是「最高层 API 表面」矛盾）。
   只对第一个匹配做替换会让 `:35` 那块仍是 internal，且**照样编译通过**——静默失败。验证：
   ```bash
   grep -c '^public extension Color' Sources/CoreDesign/Colors/FunctionalColor.swift   # 期望 1
   grep -c '^extension Color' Sources/CoreDesign/Colors/FunctionalColor.swift          # 期望 0
   ```
3. `danger` 基准从 `.red4` 改为 `.red5`（D11）：

```swift
    static let danger: Color = .red5
```

> `dangerActive = .red7` / `dangerHover = .red6` / `dangerDisable = .red2` 本就按 5 档基准配，改后 hover 反差（5→6）与 `warning` 一致。已列入 NFR 视觉例外第 1 条。

- [ ] **Step 6: 验证分流点数与四条命令**

```bash
grep -rn "#if Blossom" Sources/ | wc -l
```

Expected: `8`（原 9，删掉 `FunctionalColor` 那份）

```bash
set -o pipefail
swift build; swift test; swift build --traits Blossom; swift test --traits Blossom
```

Expected: 四条各自 EXIT=0，两次 `Test run with 96 tests in 32 suites passed`（此时 legacy 组尚未删除，仍是 96；Task 4 删除后变 95）

- [ ] **Step 7: 给 probe 补一个公开色彩面的消费点，再验证**

`scripts/downstream-probe` 当前**零个颜色 token 引用**（全是 `ToastItem`/`CoreSpacing`/`BadgeVariant` 等隔离面），因此对本任务的公开面变化完全不敏感——漏加 `public` 它照样绿。补一个消费点，让 A2d 有命令级证据：

在 `scripts/downstream-probe/Sources/DownstreamProbe/NonisolatedUsage.swift` 末尾加：

```swift
// 第 4 层「状态功能别名」的公开面。若 FunctionalColor 的 extension 漏加 public，
// 这里会编译失败（Issue #93 的 A2d）。
nonisolated func useFunctionalColors() -> [Color] {
    [.success, .info, .warning, .danger]
}
```

```bash
cd scripts/downstream-probe && swift build && cd ../..
```

Expected: `Build complete!`

- [ ] **Step 8: Commit**

```bash
git add Sources/CoreDesign/Colors/FunctionalColor.swift \
        Sources/CoreDesign/Components/CheckBox/CheckBox.swift \
        Sources/CoreDesign/Components/StatusRow/StatusRow.swift \
        Sources/CoreDesign/Colors/CoreGradient+Preview.swift
git commit -m "Issue #93: remove the shadowing colour aliases (A1, B1a-c, A2d, D11)"
```

---

### Task 3: 修正五组 `emphasis`，补齐 `*Border` 档

**Files:**
- Modify: `Sources/CoreDesign/Resources/Resources.xcassets/status/status-{accent,success,attention,danger,done}-emphasis.colorset/Contents.json`（5 个）
- Create: `Sources/CoreDesign/Resources/Resources.xcassets/status/status-{accent,success,attention,danger,done}-border.colorset/Contents.json`（5 个）
- Modify: `Sources/CoreDesign/Colors/StatusColors.swift`（新增 5 个 `status*Border` 符号）

**Interfaces:**
- Consumes: 无
- Produces: `Color.statusAccentBorder` / `statusSuccessBorder` / `statusAttentionBorder` / `statusDangerBorder` / `statusDoneBorder`，供 Task 4 的 `Badge`/`Banner` 迁移使用。五组 `emphasis` 变为可用的饱和实色。

- [ ] **Step 1: 修正五组 `emphasis` 的 light 值**

各组 `emphasis` 的 light 值现在等于同组 `muted`，应改为该组 `fg` 的同色（Primer 的 emphasis 是饱和实色）：

| 组 | 现 light（错） | 改为 |
|---|---|---|
| accent | `#DDF4FF` | `#0969DA` |
| success | `#AFF5B5` | `#1F883D` |
| attention | `#F8E3A1` | `#9A6700` |
| danger | `#FFC1BA` | `#CF222E` |
| done | `#DACDFB` | `#8250DF` |

dark 值保持不变（accent `#1F6FEB`、success `#238636`、attention `#9E6A03`、danger `#DA3633` 均已是正确的饱和实色）。改法：编辑各 `status-<组>-emphasis.colorset/Contents.json` 中**无 `appearances` 键**的那个 color 条目的 `components`。

> **`done` 组的 dark 侧有既有漂移，本任务不修**：`status-done-emphasis` dark = `#8250DF`（照抄了 light 值，Primer 应为 `#8957E5`），`status-done-fg` dark = `#AB7DF8`（Primer 为 `#A371F7`）。不在本任务的 12 个承载项内，Task 6 会把它记进 `audit-checklist.md` 作为后续项，不在此扩大范围。

- [ ] **Step 2: 新建 5 个 border colorset**

取值沿用 legacy 的原子色 3 档，light / dark 双值、均不透明。以 `status-accent-border` 为例（`blue-3`）：

`Sources/CoreDesign/Resources/Resources.xcassets/status/status-accent-border.colorset/Contents.json`：

```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : { "alpha" : "1.000", "blue" : "0xFC", "green" : "0xB2", "red" : "0x65" }
      },
      "idiom" : "universal"
    },
    {
      "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ],
      "color" : {
        "color-space" : "srgb",
        "components" : { "alpha" : "1.000", "blue" : "0xDB", "green" : "0x75", "red" : "0x1D" }
      },
      "idiom" : "universal"
    }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

其余四组同结构，取值：

| colorset | light | dark | 来源原子色 |
|---|---|---|---|
| `status-accent-border` | `#65B2FC` | `#1D75DB` | `blue-3` |
| `status-success-border` | `#7DD182` | `#32953D` | `green-3` |
| `status-attention-border` | `#FDC165` | `#D56F0F` | `orange-3` |
| `status-danger-border` | `#FB9078` | `#D73324` | `red-3` |
| `status-done-border` | 取 `purple-3` 的 light | 取 `purple-3` 的 dark | `purple-3` |

`purple-3` 的实际取值用命令读，不要猜：

```bash
python3 -c "
import json
d=json.load(open('Sources/CoreDesign/Resources/Resources.xcassets/purple/purple-3.colorset/Contents.json'))
for c in d['colors']:
    comp=c['color'].get('components')
    if not comp: continue
    print(('dark ' if c.get('appearances') else 'light'), {k:comp[k] for k in ('red','green','blue')})
"
```

- [ ] **Step 3: 在 `StatusColors.swift` 声明 5 个新符号**

在各组现有四档之后加一行，紧跟该组的 `subtle`：

```swift
    /// 边框色。**CoreDesign 扩展**，Primer 无独立 `*.border` 档（它用 `*.muted` 兼作边框）；
    /// 本仓库保留独立档以免边框与背景同色而失去描边。取值沿用原 legacy 组的原子色 3 档。
    static let statusAccentBorder: Color = Color("status-accent-border", bundle: .module)
```

其余四组同形态（`statusSuccessBorder` / `statusAttentionBorder` / `statusDangerBorder` / `statusDoneBorder`）。

- [ ] **Step 4: clean 后验证（新增了 colorset，必须 clean）**

```bash
swift package clean
set -o pipefail
swift build; swift test; swift build --traits Blossom; swift test --traits Blossom
```

Expected: 四条各自 EXIT=0，两次 96 tests passed（legacy 组仍在，Task 4 删除后变 95）

> **不 clean 会假绿**：macOS SPM 以目录而非 `.car` 分发 `.xcassets`，增量构建不拷贝新加的目录，新 colorset 在运行时不存在。

- [ ] **Step 5: Commit**

```bash
git add Sources/CoreDesign/Resources/Resources.xcassets/status/ Sources/CoreDesign/Colors/StatusColors.swift
git commit -m "Issue #93: fix emphasis tier across five groups; add the missing border tier (B6c, D19)"
```

---

### Task 4: 四处 legacy 迁移，删除 legacy 组

**Files:**
- Modify: `Sources/CoreDesign/Components/Banner.swift:152,154,156,158`（+ 注释 `:26,68,167,201`）
- Modify: `Sources/CoreDesign/Components/Badge/Badge.swift:142-145,156-159`（+ 注释 `:55`）
- Modify: `Sources/CoreDesign/Components/Toast/Toast.swift:468-471`（+ 注释 `:18`）
- Modify: `Sources/CoreDesign/Components/Form/Form.swift:101`（+ 注释 `:92,99`）
- Modify: `Sources/CoreDesign/Colors/StatusColors.swift:63-77`（删 legacy 组）
- Modify: `Tests/CoreDesignTests/StatusColorsTests.swift`（让它编译通过）

**Interfaces:**
- Consumes: Task 3 的 5 个 `status*Border`
- Produces: legacy 组不复存在，`StatusColors` 只余新体系一套 scale。

- [ ] **Step 1: 迁移 `Banner.swift`**

四行 `BannerPalette(...)` 按映射表改。以 info 行为例：

```swift
        BannerPalette(foreground: .statusAccentForeground, background: .statusAccentMuted, border: .statusAccentBorder)
```

其余三行：`warning` → `statusAttention*`、`danger` → `statusDanger*`、`success` → `statusSuccess*`。同步修正 `:26,68,167,201` 的注释中对 legacy token 名的引用。

- [ ] **Step 2: 迁移 `Badge.swift`**

`:142-145` 的 `*Background` → `*Muted`：

```swift
        case .info: .statusAccentMuted
        case .success: .statusSuccessMuted
        case .warning: .statusAttentionMuted
        case .danger: .statusDangerMuted
```

`:156-159` 的 `*Border` → 新的 `*Border`：

```swift
        case .info: .statusAccentBorder
        case .success: .statusSuccessBorder
        case .warning: .statusAttentionBorder
        case .danger: .statusDangerBorder
```

同步修正 `:55` 注释。

- [ ] **Step 3: 迁移 `Toast.swift`**

`:468-471` 的 `*Foreground`：

```swift
        case .info: .statusAccentForeground
        case .success: .statusSuccessForeground
        case .warning: .statusAttentionForeground
        case .danger: .statusDangerForeground
```

同步修正 `:18` 注释。

- [ ] **Step 4: 迁移 `Form.swift`（最易漏的一处）**

`:101`：

```swift
        Image(systemName: "exclamationmark.circle.fill").foregroundStyle(Color.statusDangerForeground)
```

同步修正 `:92,99` 的文档注释（两处都写着 `Color.dangerForeground`）。

> `Form` 不在直觉上的「status 组件」列表里，漏改会直接编译失败——这是本任务最容易忽略的一处。

- [ ] **Step 5: 删除 legacy 组**

`Sources/CoreDesign/Colors/StatusColors.swift:63-77` 整段 12 个 token 删除（连同它们所在的 `// MARK:` 与说明注释）。

- [ ] **Step 6: 让 `StatusColorsTests.swift` 编译通过**

**删除整个 `existingTokensPreserved` 测试**（`@Test("existing info/warning/danger/success foreground-background-border tokens preserved")` 连同其函数体）——它的 12 个断言对象全部随 legacy 组消失，只删行会留下一个名字与内容不符的空壳，既是死代码又与 #98 的恒真断言清理冲突。

> **测试数因此从 96 变 95**（suite 数不变，仍 32——被删的是 suite 内的一个 test）。本任务后续所有 `Expected` 都用 **95 tests in 32 suites**。
>
> 该文件其余的恒真断言（`let _: Color = ...` 无 `#expect`）整体清理**归 #98**，本任务不碰。

- [ ] **Step 7: 验证（含 clean，因 Task 3 增过 colorset）**

```bash
swift package clean
LOGDIR="${TMPDIR:-/tmp}/coredesign-93"; mkdir -p "$LOGDIR"
set -o pipefail
swift build
swift test 2>&1 | tee "$LOGDIR/t4.log" | tail -1
swift build --traits Blossom
swift test --traits Blossom 2>&1 | tee "$LOGDIR/t4b.log" | tail -1
```

Expected: 两次 `Test run with 95 tests in 32 suites passed`（`existingTokensPreserved` 已随 legacy 组删除）

warning 判据（两侧）：

```bash
for f in "$LOGDIR/t4.log" "$LOGDIR/t4b.log"; do
  [ -s "$f" ] || { echo "日志为空,判据无效"; exit 1; }
  grep -a 'warning:' "$f" | grep -av "is deprecated: Use SwiftUI ContentUnavailableView"
done
```

Expected: 无输出

- [ ] **Step 8: 确认 legacy token 已零引用**

```bash
grep -rnE '\.(infoForeground|infoBackground|infoBorder|successForeground|successBackground|successBorder|warningForeground|warningBackground|warningBorder|dangerForeground|dangerBackground|dangerBorder)\b' Sources Tests App --include='*.swift'
```

Expected: 无输出

- [ ] **Step 9: Commit**

```bash
git add Sources/CoreDesign/Components/ Sources/CoreDesign/Colors/StatusColors.swift Tests/CoreDesignTests/StatusColorsTests.swift
git commit -m "Issue #93: migrate the four legacy status consumers; delete the legacy tier (B6a, B6b)"
```

---

### Task 5: 别名层级修正（D13、D14）

**Files:**
- Modify: `Sources/CoreDesign/Colors/BorderColors.swift:43-54`（含 `:45` 与 `:50` 两处注释）
- Modify: `Sources/CoreDesign/Colors/InteractionColors.swift:32`
- **Delete**: `Sources/CoreDesign/Resources/Resources.xcassets/border/border-focus.colorset/`（`borderFocus` 改走别名后成孤儿资产）

**Interfaces:**
- Consumes: 无
- Produces: `borderFocus` / `borderSelected` 指向 `.accent`，随 Blossom trait 自动继承，**不新增 `#if Blossom`**。

- [ ] **Step 1: `borderSelected` 与 `borderFocus` 改走别名**

`BorderColors.swift`：

```swift
    /// 选中态边框。指向 `accent` 别名，随 Blossom trait 自动继承，不单独分流。
    static var borderSelected: Color { .accent }

    /// 焦点环边框。同样指向 `accent`——focus 与 selected 同源于品牌强调色。
    static var borderFocus: Color { .accent }
```

并重写 `:43-48` 整段注释——`:50` 那句称「focus 与 selected 同源 accent」与原代码矛盾（`borderFocus` 实际是独立 colorset），而 `:45` 的「由 `border/border-focus.colorset` 提供 light/dark 双值」在该 colorset 删除后同样失效。两处一并改。

> **默认主题下 focus ring 会从 Primer 蓝 `#0969DA` 变为品牌蓝 `#0077FA`**（dark `#1F6FEB` → `#3295FB`），影响 `FocusRingModifier.swift:106`（默认参数）与 `SearchField.swift:136`。已列入 NFR 视觉例外第 3 条。

- [ ] **Step 2: `selectionBackgroundEmphasis` 消除层级违规**

`InteractionColors.swift:32` 从直接引用第 1 层原子色 `.brand2` 改为同层别名：

```swift
    static let selectionBackgroundEmphasis: Color = .accentDisabled   // 该文件通篇用 static let,保持一致
```

并加注释说明为何与 `accentDisabled` 共值：

```swift
    /// 强调选区背景。与 `accentDisabled` 共值（同为 `brand2`）——两者语义不同但
    /// 视觉档位一致，走别名而非直接引用第 1 层原子色，以免 accent 重定向时漏改。
```

> `BorderColors.swift` 通篇是 `static var { … }` 计算属性形态，故上面两个改动用 `static var`；`InteractionColors.swift` 通篇是 `static let`，故这里保持 `static let`。各随所在文件的既有风格。

- [ ] **Step 3: 确认 `border-focus` colorset 是否仍被引用**

```bash
grep -rn 'border-focus' Sources/
```

若已无引用，删除 `Resources.xcassets/border/border-focus.colorset/` 目录（孤儿资产），并在下一步 clean 后验证。

- [ ] **Step 4: 验证**

```bash
swift package clean
set -o pipefail
swift build; swift test; swift build --traits Blossom; swift test --traits Blossom
grep -rn "#if Blossom" Sources/ | wc -l
```

Expected: 四条 EXIT=0，两次 **95** tests passed，`#if Blossom` 计数为 `8`

- [ ] **Step 5: Commit**

```bash
# 用 -A 覆盖 colorset 目录的删除——`git add <file>` 不会 stage 目录删除,
# 漏掉会让孤儿资产留在仓库里而工作树看起来是干净的。
git add -A Sources/CoreDesign/Colors/ Sources/CoreDesign/Resources/Resources.xcassets/border/
git status --short          # 确认 border-focus.colorset 的删除已 staged
git commit -m "Issue #93: route focus/selected borders through the accent alias (D13, D14)"
```

---

### Task 6: 仓内触及清单收尾 + 审计清单更新

**Files:**
- Modify: `App/Sources/Previews.swift:233`
- Modify: `docs/components/timeline-item.md:24`、`form-icons.md:27,67`、`banner.md:34`、`toast.md:65`
- Modify: `CLAUDE.md`（分层描述）
- Modify: `.claude/epics/coredesign-audit-remediation/audit-checklist.md`
- Create: `.claude/epics/coredesign-audit-remediation/updates/93/progress.md`

**Interfaces:**
- Consumes: 前五个 Task 的全部结论
- Produces: SC-7 的判定依据

- [ ] **Step 1: `App/Sources/Previews.swift:233`**

该行用 `Color.statusAccentEmphasis`。因 accent 组保留（D19 已改判），**该行无需改动**——但 Task 3 修正了 emphasis 的 light 值，色块会从淡蓝洗色变为饱和 Primer 蓝。确认这是期望结果即可，无需改代码。

- [ ] **Step 2: 4 个 docs 文件**

- `docs/components/timeline-item.md:24` —— `Color.statusAccentEmphasis` 仍有效，但取值已变（淡蓝 → 饱和蓝），若文中描述了颜色需同步
- `docs/components/form-icons.md:27,67` —— `Color.dangerForeground` → `Color.statusDangerForeground`
- `docs/components/banner.md:34` —— legacy token 名列表 → 新体系名
- `docs/components/toast.md:65` —— 同上

`docs/superpowers/plans/` 下是归档，**不改**。

- [ ] **Step 3: `CLAUDE.md` 分层描述**

第 4 层的描述从

> 4. **功能性别名**（`Colors/FunctionalColor.swift`）—— `Color.primary/secondary/tertiary`（含 `Active`/`Disable`/`Hover` 变体）、`success`、`info`、`warning`、`danger`。这是最高层的 API 表面。

改为

> 4. **状态功能别名**（`Colors/FunctionalColor.swift`）—— `success`、`info`、`warning`、`danger` 及其现有变体。**交互色不在此层**——`accent` / `secondaryAccent` / `neutralAccent` 等走第 3 层 `InteractionColors`。本层为 `public`。
>
> 该层曾有 `Color.primary/secondary/tertiary` 三组，因与 SwiftUI 内建成员同名而遮蔽它们（删除时编译器不报错，只静默改变解析目标），已于 Issue #93 移除。

同步更新「分流点压到最低」段落中对 `secondary` / `secondaryAccent` 的描述——现在只余 `InteractionColors` 一处。

- [ ] **Step 4: 更新 audit-checklist 的 12 项**

把 A1、A2d、B1a、B1b、B1c、B6a、B6b、B6c、D11、D13、D14、D19 十二行的缺陷列加上 `✅ **已修复**（GitHub #93）——<一句话>` 前缀。

**不要改列结构**——该文件头部的核对命令依赖行首形态 `^| [A-D][0-9]` 与行尾 `| #N |`。改完跑：

```bash
cd .claude/epics/coredesign-audit-remediation
echo $(( $(grep -c '^| [A-D][0-9]' audit-checklist.md) - 4 ))          # 期望 83
grep -oE '\| #[0-9]+ \|$' audit-checklist.md | sort -V | uniq -c | awk '{s+=$1} END {print s}'  # 期望 79
```

- [ ] **Step 5: 写 progress.md**

```markdown
---
issue: 93
started: <运行 date -u +"%Y-%m-%dT%H:%M:%SZ">
last_sync: <同上>
completion: 100%
---

# Issue #93 完成记录

## 毒丸阶段的产出

（粘贴 Task 1 Step 3 的真实诊断输出）

## 三条改判

1. `statusAccent*` 保留（原判整组删除，与 legacy 迁移冲突）
2. 五组 `emphasis` 全错（原判 accent 单组笔误）
3. 迁移改变 dark 观感（alpha 叠加 vs 不透明实色），已列 NFR 例外

## 迁移映射表

（粘贴计划中的映射表 + 新增 border colorset 的取值依据）

## 遗留给下游 Issue

- #98：`StatusColorsTests` 已编译通过，恒真断言待清理
- #95 / #101：第 4 层不再有交互色，需要时走 `InteractionColors`
```

- [ ] **Step 6: 最终验证**

```bash
swift package clean
set -o pipefail
swift build; swift test; swift build --traits Blossom; swift test --traits Blossom
cd scripts/downstream-probe && swift build && cd ../..
grep -rn "#if Blossom" Sources/ | wc -l
```

Expected: 四条 EXIT=0、两次 **95** tests passed、probe `Build complete!`、`#if Blossom` 为 `8`

- [ ] **Step 7: Commit**

```bash
git add App/ docs/ CLAUDE.md .claude/epics/coredesign-audit-remediation/
git commit -m "Issue #93: update docs, CLAUDE.md layering, and the audit checklist"
```

---

## 收尾

1. `oh-my-superpowers:verification-before-completion` —— 给「完成」结论前必须有命令输出为证
2. `oh-my-superpowers:finishing-a-development-branch` —— Option 2 开 PR，**base = `epic/coredesign-audit-remediation`**，禁止直接合 `main`
3. `oh-my-superpowers:auto-fix-pr-after-implementation` —— Copilot 在本仓库不可用（`COPILOT_UNAVAILABLE_UNTIL=2026-08-01`），按 §3.6 降级为 subagent review
