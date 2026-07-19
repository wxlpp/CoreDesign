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

1. **`statusAccent*` 保留，不删**。删它与本任务自身的 legacy 迁移冲突——新体系只有 `accent` 一个蓝色家族，而它正是 Primer 的 info 语义，`Banner`/`Toast`/`Badge` 的 legacy `info*` 只能迁到它。D19 原判据「库内零渲染消费点」在迁移完成后不再成立。
2. **五组 `emphasis` 的 light 值全错，不是 accent 单组笔误**。`accent`/`success`/`attention`/`danger`/`done` 的 `*-emphasis` light 值逐组等于同组 `*-muted`；Primer 语义里 emphasis 是饱和实色。本轮一并修正。
3. **迁移会改变 dark 观感**，已列入 NFR 视觉例外：legacy 用不透明原子色（`blue-1` dark `#0A4694`），新体系 dark 是 alpha 叠加（`#1F6FEB @13.3%`）。这是 Primer 的标准做法，能随底层 surface 自适应，比 legacy 写死实色更正确。

### 迁移映射表（NFR 视觉零回归的判定基础）

legacy 三档 → 新体系。`info` → `accent` 家族（Primer 里 accent 即 info 蓝）：

| legacy | 原子色 | 新体系 | 依据 |
|---|---|---|---|
| `*Foreground` | ramp 7（`blue7` 等） | `status*Foreground` | 同为前景文本色，语义直接对应 |
| `*Background` | ramp 1（`blue1` `#CBE7FE`） | `status*Muted` | Primer `muted` = 有色背景块的标准档；`subtle` 更淡（faint highlight），用于选区高亮而非 Banner/Badge 底色 |
| `*Border` | ramp 3（`blue3` `#65B2FC`） | `status*Border`（**本任务新增**） | 见下 |

**新增 5 个 `status-*-border.colorset` 的取值**：沿用 legacy 的原子色 3 档（`blue3`/`green3`/`orange3`/`red3`，`done` 组用 `purple3`）。理由——(a) 保持 light 模式观感零回归，这是迁移的默认要求；(b) Primer 本身没有独立的 `*.border` 档（它用 `*.muted` 兼作边框），若强行对齐会让边框与背景同色而失去描边；(c) legacy 的 3 档取值本就是本仓库为边框选定的，有既定视觉依据。dark 值同样沿用原子色 3 档的 dark 值（不透明），**不用 alpha 叠加**——边框需要清晰轮廓，半透明会糊。

**四组 legacy → 新体系的组名对应**：`info`→`accent`、`success`→`success`、`warning`→`attention`、`danger`→`danger`。（`done` 组本任务不涉及，但 border 档一并补齐以保持体系完整。）

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
```

Expected: 两个文件内容相同，各 3 行：

```
Colors/CoreGradient+Preview.swift:17:63: warning: 'secondary' is deprecated: A1 probe: shadows SwiftUI builtin
Components/CheckBox/CheckBox.swift:31:44: warning: 'primary' is deprecated: A1 probe: shadows SwiftUI builtin
Components/StatusRow/StatusRow.swift:80:32: warning: 'secondary' is deprecated: A1 probe: shadows SwiftUI builtin
```

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
swift build 2>&1 | grep -c "A1 probe" | xargs echo "默认 trait 残留:"
swift build --traits Blossom 2>&1 | grep -c "A1 probe" | xargs echo "Blossom 残留:"
```

Expected: 两者均为 `0`。**非零则不许进入 Step 5** —— 删符号前必须零诊断。

- [ ] **Step 5: 删除三组色别名与毒丸，补 `public`，修 `danger` 基准**

`Sources/CoreDesign/Colors/FunctionalColor.swift`：

1. 删除 `primary`/`secondary`/`tertiary` 三组共 16 处声明（含刚加的毒丸注解、含 `#if Blossom` / `#else` 两个分支）。若该 `#if Blossom` 块删空，整块一并删除——这是 SC-2 要求的分流点净减
2. `extension Color {` 改为 `public extension Color {`（A2d：第 4 层此前整层 internal，与 CLAUDE.md 称它是「最高层 API 表面」矛盾）
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

Expected: 四条各自 EXIT=0，两次 `Test run with 96 tests in 32 suites passed`

- [ ] **Step 7: 下游 probe 保持绿**

```bash
cd scripts/downstream-probe && swift build && cd ../..
```

Expected: `Build complete!`（本步删了公开 API，probe 是 #92 建立的下游视角防线）

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

dark 值保持不变（已是正确的饱和实色）。改法：编辑各 `status-<组>-emphasis.colorset/Contents.json` 中**无 `appearances` 键**的那个 color 条目的 `components`。

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

Expected: 四条各自 EXIT=0，两次 96 tests passed

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

该文件 `:50-61` 引用 12 个 legacy token，全部失效。删掉这些引用行。

> 只做「让它编译通过」。该文件的恒真断言（`let _: Color = ...` 无 `#expect`）整体清理**归 #98**，本任务不碰。

- [ ] **Step 7: 验证（含 clean，因 Task 3 增过 colorset）**

```bash
swift package clean
LOGDIR="${TMPDIR:-/tmp}/coredesign-93"; mkdir -p "$LOGDIR"
set -o pipefail
swift build
swift test 2>&1 | tee "$LOGDIR/t4.log" | tail -1
swift build --traits Blossom
swift package clean
swift test --traits Blossom 2>&1 | tee "$LOGDIR/t4b.log" | tail -1
```

Expected: 两次 `Test run with 96 tests in 32 suites passed`

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
- Modify: `Sources/CoreDesign/Colors/BorderColors.swift:46-54`（含 `:50` 注释）
- Modify: `Sources/CoreDesign/Colors/InteractionColors.swift:32`

**Interfaces:**
- Consumes: 无
- Produces: `borderFocus` / `borderSelected` 指向 `.accent`，随 Blossom trait 自动继承，**不新增 `#if Blossom`**。

- [ ] **Step 1: `borderSelected` 与 `borderFocus` 改走别名**

`BorderColors.swift`：

```swift
    /// 选中态边框。指向 `accent` 别名，随 Blossom trait 自动继承，不单独分流。
    static let borderSelected: Color = .accent

    /// 焦点环边框。同样指向 `accent`——focus 与 selected 同源于品牌强调色。
    static let borderFocus: Color = .accent
```

并修正 `:50` 与代码矛盾的注释（原注释称 focus 与 selected 同源 accent，但 `borderFocus` 实际是独立的 Primer 蓝 colorset）。

> **默认主题下 focus ring 会从 Primer 蓝 `#0969DA` 变为品牌蓝 `#0077FA`**（dark `#1F6FEB` → `#3295FB`），影响 `FocusRingModifier.swift:106`（默认参数）与 `SearchField.swift:136`。已列入 NFR 视觉例外第 3 条。

- [ ] **Step 2: `selectionBackgroundEmphasis` 消除层级违规**

`InteractionColors.swift:32` 从直接引用第 1 层原子色 `.brand2` 改为同层别名：

```swift
    static let selectionBackgroundEmphasis: Color = .accentDisabled
```

并加注释说明为何与 `accentDisabled` 共值：

```swift
    /// 强调选区背景。与 `accentDisabled` 共值（同为 `brand2`）——两者语义不同但
    /// 视觉档位一致，走别名而非直接引用第 1 层原子色，以免 accent 重定向时漏改。
```

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

Expected: 四条 EXIT=0，两次 96 tests passed，`#if Blossom` 计数为 `8`

- [ ] **Step 5: Commit**

```bash
git add Sources/CoreDesign/Colors/BorderColors.swift Sources/CoreDesign/Colors/InteractionColors.swift
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

Expected: 四条 EXIT=0、两次 96 tests passed、probe `Build complete!`、`#if Blossom` 为 `8`

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
