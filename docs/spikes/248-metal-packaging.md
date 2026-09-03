# Spike #248 — SwiftPM 分发 Metal shader 的打包结论

> `shipswift-foundation`（#241）闸①。本文件是 spike 的**结论**；实验包在仓外
> （scratchpad `metal-spike-248`），按 epic AD-A **不进仓**。

## TL;DR — 结论与 PRD/epic 的预设相反

**PRD 与 epic 把路径 β（预编译 metallib 作二进制资源）定为默认走向**，理由是
「所有已知消费路径都用原生 `swift build`，切不到 swiftbuild」。

**实测推翻了这个前提。** 本 spike 建议改判 **路径 α（`.metal` 源随 target 编译）**。

⚠️ **这不只是"前提被推翻"，而是一次 PRD 层的裁决变更，需要 PRD owner 拍板**
（#258 终审 I-4）：PRD FR-2 把 α 的可选条件写死为「**所有**已知消费路径都能切 swiftbuild」
并点名 StoryUI CI。本 spike 证明的是 **CoreDesign 自己的 CI 能切**；
**StoryUI 的包能否在 swiftbuild 下构建没有测**。
⇒ 本 spike 实际建议的是把该条件**从「全部可切」改为「Xcode 消费者不命中 + CLI 消费者
按文档自担并有响亮失败兜底」**。**请连同下方《α 的残余风险》一并裁决 FR-2 的改写。**

| | α（源码随 target 编译） | β（预编译 metallib） |
|---|---|---|
| CI SwiftPM 腿 | **保留 native**，另加一步只跑 shader 测试的 swiftbuild（⚠️ **不能整腿切**——会让 colorset 守卫静默失守，见问②） | 不用改 |
| 分平台产物 | **构建系统自动按 destination 产出**，零额外工作 | 手工提交 **3 份** + 运行时 `#if` 选择 |
| `.metal` 与产物同步 | **不可能失步**（同一次构建） | 需 sha256 manifest 守卫，否则改了 shader 忘重编 = 静默用旧效果 |
| 仓库体积 | 0 | 每次改 shader 最多提交 6MB 二进制 |
| 工具链耦合 | **不是「无」**：耦合从「我们编的 metallib 在旧运行时加载」换成「消费者的 Metal 编译器编我们的 MSL」——MSL 新版弃用/报错 ⇒ 下游**编译失败**。方向是 fail-loud，比 β 的静默好，但不是零 | 需钉 `-std=` / `-mios-version-min`，否则新 Xcode 编的在旧运行时**静默**加载失败 |
| Mac Catalyst | 构建系统自己处理 | `#if os(macOS)` 在 Catalyst 下为假 ⇒ 会误选 `iphoneos` 份 |
| 残余风险 | 见下方《α 的残余风险》 | 上面五行全是永久维护负担 |

⇒ **epic `shipswift-shaders` 的 AD-B / AD-C / AD-D 需按本结论回改。**

---

## 六问逐条

### ① 构建系统选型 → **α**

**处理矩阵**（实测，**Xcode 26.4 / Swift 6.3，本机 Apple Silicon**）：

⚠️ **可复现性声明**（#258 终审 I-6）：下方引用的 `CoreDesignEffects / Charts smoke passed`
只在 **`epic/shipswift-foundation` 的 `7384ccd`**（含 #257）上存在——本 spike 分支基于
更早的 commit，在其上复跑得到的是 **474 个通过的测试**而非 476（差的 2 个正是那两个新 target 的 smoke 测试）。
⚠️ **CI runner 用的是 Xcode 26.5**（`ci.yml`），**swiftbuild 在 26.5 上的行为本 spike 未验证**。

| 构建系统 | `.metal` 声明方式 | 结果 |
|---|---|---|
| 原生 `swift build` | 不声明 | `warning: found 1 file(s) which are unhandled`；**且 `Bundle.module` 根本不被合成** —— 引用它是编译错误 |
| 原生 `swift build` | `.process("X.metal")` | `[0/3] Copying X.metal` —— **拷贝源码，不编译**；bundle 里躺着 `.metal` 源，**零 `.metallib`** |
| `swift build --build-system swiftbuild` | `.process("X.metal")` | 调 `metal -c -target air64-apple-macos26.0 … -o X.air`，**产出 `default.metallib`** |
| `xcodebuild` | 同上 | 同上，且按 destination 分平台 |

⚠️ **额外发现：只含 `.metal` 的 target 被 SwiftPM 判为 empty**
（`error: target 'X' referenced in product 'X' is empty`）——`.metal` 既不算源也不算资源。
target 里必须至少有一个 `.swift` 文件。

**α 的前提被实测证伪了「不成立」这一判断**：

```
$ cd <CoreDesign worktree> && swift test --build-system swiftbuild
… CoreDesignEffects 模块 smoke / CoreDesignCharts 模块 smoke 均 passed
```

⇒ CI 的 SwiftPM 腿**切得动**（⚠️ 但**不能整腿切**，见问②）。PRD C-1 与 epic AD-B 写的「α 等于把构建系统约束转嫁给下游」
**只对一类下游成立**，见《α 的残余风险》。

### ② CI 改法

⚠️ **初稿写「SwiftPM 腿只需加 `--build-system swiftbuild`，其它零改动」——实测为假，
且失效形态是静默的**（#258 终审 C-1）。

**实测**：整腿切到 swiftbuild 会让 `ColorAssetGuardTests` 的
`Colorset 资源存在性守卫` suite **静默跳过**（skipped，不是 failed，CI 照常绿）：

```
native:      Suite "Colorset 资源存在性守卫" passed      （17 色相×10 色阶 + status 全查）
swiftbuild:  该 suite 在输出里整个消失
```

**原因**：`Tests/CoreDesignTests/ColorAssetGuardTests.swift:70` 的
`.enabled(if: rawXcassetsAvailable)` 只在 `Resources.xcassets/` **以目录形式**存在时启用。
swiftbuild 调 `actool` 把它编成 `Assets.car` ⇒ 判据 false ⇒ 整个 suite 跳过。
而 xcodebuild iOS 腿本来就是 `.car` 形态、同样跳过 ⇒ **整腿切换后，
逐 colorset 的存在性守卫在四条腿上无一执行**。

⚠️ 该文件 `:42-51` 的 canary 注释**已预见**「SwiftPM 将来改为调用 actool」这一漂移，
但 canary 只守「xcassets 某种形态存在」，**不守逐 colorset**——所以它不会响。

**⇒ 采用的改法（不整腿切）**：

| 腿 | 改动 |
|---|---|
| **SwiftPM** | **保留 native** `swift build` / `swift test`（colorset 守卫继续生效）；**另加一步** `swift test --build-system swiftbuild --filter CoreDesignShadersTests`，只让 shader 加载测试走 swiftbuild。⚠️ **该 `--filter` 组合本 spike 未实跑**（②只实测了「整腿切会跳过 colorset suite」）⇒ **B-1 须先验它** |
| **iOS Simulator** | 已是 `xcodebuild`，天然编译 `.metal` ⇒ **零改动** |
| **downstream-probe** | build-only，且只依赖 `CoreDesign` product ⇒ **零改动** |
| **Bool 棘轮** | 不读 `Sources` ⇒ **零改动** |

⚠️ **被否决的改法**：整腿切 swiftbuild + 把 `ColorAssetGuardTests` 改成能读 `.car`
——CoreUI 的 `.car` 格式不公开，实际做不到；改为按 `#filePath` 直接断言源码树的
`Sources/CoreDesign/Resources.xcassets` 也可行，但那是一个独立的守卫重构，
不该塞进 Metal 这条线。

### ③ metallib 定位 + fail-closed 加载测试

产物路径（swiftbuild，macOS）：
```
.build/out/Products/Debug/<Target>_<Target>.bundle/Contents/Resources/default.metallib
```
运行时用 `device.makeDefaultLibrary(bundle: .module)` 取到。

⚠️ **不要用 `ShaderLibrary` 做验证**——它是 SwiftUI 的惰性入口，查不到时**不报错、只是不渲染**
（这正是 α 失败形态"静默无渲染"的来源）。验证必须走 Metal API：

```swift
guard let device = MTLCreateSystemDefaultDevice() else { throw .noMetalDevice }
let lib = try device.makeDefaultLibrary(bundle: .module)   // 找不到即 throw
for f in functions where lib.makeFunction(name: f) == nil { throw .functionMissing(f) }
```

⚠️ **本 spike 证明的是「能编、能加载」，不是「能画」**（#258 终审 C-2）：
`ShaderLibrary.bundle(.module)` 这个入口**一次都没被调用过**，而它正是 B-2 / B-3
全部 wrapper 要用的那个入口；实验包里也**没有任何 `.colorEffect` / `.layerEffect` 调用**
⇒ `.color` ↔ `half4`、`SwiftUI::Layer` 的参数位次这些**签名匹配从未被 SwiftUI 校验过**，
而签名不匹配的失败形态恰恰就是本文档反复警告的「静默无渲染」。
**⇒ B-1 的第一件事必须是：真的画一次**（真实 wrapper + 预览宿主或
`xcodebuild test` 跑一遍 + 像素采样留证；⚠️ `ImageRenderer` 未必执行 shader，
不能拿它当证据）。在那之前，④⑤ 的「可行」只到编译与加载为止。

**fail-closed 已实证双向**：
- 原生 `swift build`（无 metallib）⇒ 测试**判红** ✅（不是静默跳过）
- `--build-system swiftbuild` ⇒ 测试**通过**，`spikeSwirl` / `spikeFoil` 两个 stitchable 函数都解析出来

⚠️ **未解项：GitHub Actions `macos-26` runner 有没有可用 Metal device？**
本机（Apple Silicon）有。CI runner 是虚拟化环境，**本 spike 无法在本地回答**。
⚠️ **本条未按 task AC 完成**（#258 终审 I-3）：`248.md` 要求「**已确认**」，
而本 spike 只给了两个分支的处置。⚠️ **可以更早解决**：在本 PR 的 swiftpm job 里临时加
一行打印 `MTLCreateSystemDefaultDevice() != nil` 即可拿到答案，成本几分钟
——**建议 B-1 的第一个 commit 就做，不要真拖到 shader 落地时**。

⇒ **B-1 落地时先加一条一次性 CI 探针**（`MTLCreateSystemDefaultDevice() != nil` 打印结果）：
- **有** ⇒ 加载测试进 SwiftPM 腿，缺 device 即判红；
- **无** ⇒ 加载测试**仅在 iOS Simulator 腿作数**，macOS 腿以**显式 skip + 留痕**处理
  （**不得**静默 `return`），并回改 epic 的验证路径表。

### ④ 多色参数化（`colorEffect`）→ **可行**

`.metal` 侧零硬编码色，调色板全部走参数：

```metal
[[stitchable]] half4 spikeSwirl(float2 pos, half4 col, float2 size, float t,
                                half4 c0, half4 c1, half4 c2) { … }
```

编译通过、加载通过。⇒ FR-8「颜色 100% 由调用方传入」在 `.metal` 侧**技术上可达**
（⚠️ 限于"能编能加载"，未验渲染，见 ③ 的证据边界说明）。

### ⑤ layer 输入（`layerEffect`）→ **可行，但有一个必踩的坑**

```metal
[[stitchable]] half4 spikeFoil(float2 pos, SwiftUI::Layer layer,
                               float2 size, float t, half4 tint) { … }
```

⚠️ **必须 `#include <SwiftUI/SwiftUI_Metal.h>`**，否则 `error: use of undeclared
identifier 'SwiftUI'`。上游 34 个 `.metal` 里 30 个都带这行——**改造那 7 个"颜色写死"件时
不要在重排 include 时把它弄丢**。

⚠️ **本条未按 task AC 取样**（#258 终审 I-1）：`248.md:35-37` 明写 layerEffect 样本
**须取自** ChromaticGlass / Foil / Glitter / IntenseBling / PolishedAluminum / GlassLogo /
LiquidMetal 之一；实验包里的 `spikeFoil` 是 6 行的条纹 mix，与上游 Foil
（硬编码调色板 + 多层反射）无关。⇒ **下方交付 B 里那 7 个的「2–3 小时/个」是估算，
无实测支撑**，而它们恰是已知 MIT 来源的主体，直接影响闸② ⇒ **`N_B` 取值偏保守**（见下方推导；⚠️「保守」= **取更小的 `N_B`**，即**更宽松的闸**——边际成本无实测支撑时，不该用一个没根据的高门槛去卡掉可落地的 shader）。

### ⑥ 分平台 metallib → **α 下不是问题**

`xcodebuild` 按 destination 自动产出：

| destination | 产物 | 大小 |
|---|---|---|
| `generic/platform=iOS Simulator` | `Debug-iphonesimulator/default.metallib` | 16820 B |
| `generic/platform=iOS` | `Debug-iphoneos/default.metallib` | 16772 B |
| macOS（swiftbuild） | `…bundle/Contents/Resources/default.metallib` | 16788 B |

⇒ **epic AD-C 规定的「3 份 metallib + 运行时 `#if` 选择 + `exclude:` + sha256 manifest 守卫」
整套复杂度是 β 独有的，α 下全部消失。**

**下游消费者实验**（#258 终审 I-7 补做，结论支持上表）：建一个 `.package(path:)` 依赖本实验包
的下游包，分别构建——

| 下游构建方式 | 结果 |
|---|---|
| native `swift test` | **判红**（无 metallib）—— fail-closed 生效 |
| `swift test --build-system swiftbuild` | 通过，metallib 由**下游构建**产出 |
| `xcodebuild -destination 'generic/platform=iOS Simulator'` | 产出 `Debug-iphonesimulator/…/default.metallib` |

⇒ **「下游按自己的 destination 编我们的 `.metal`」成立**，不是把我们本地的产物分发下去。
⚠️ 初稿的 ⑥ 只有**自建**产物的证据，把这个消费者实验补进来才闭环。

⚠️ **`.process("X.metal")` 在 α 下是强制项，不是可选项**：swiftbuild 不声明也会编，
但 **native 不声明 ⇒ `Bundle.module` 不合成 ⇒ `downstream-probe` 与 StoryUI 直接编译失败**。
⚠️ 副作用：native + `.process` 会把 `.metal` 源码随 bundle 分发，B-1 需有意识。

⚠️ 顺带纠正 AD-C ③：swiftbuild 下 bundle 里**只有 `default.metallib`**，`.metal` 源
**没有**被同时拷进去（即使声明为 `.process` 资源）⇒ AD-C 说的「产物冗余、必须 `exclude:`」
在 α 下**不成立**。

---

## α 的残余风险（必须写进 `CoreDesignShaders` 的 README 与 CLAUDE.md）

α 的失败形态是**运行时静默无渲染**，触发条件收窄为**同时满足**：

1. 下游 import 了 `CoreDesignShaders`（不是 `CoreDesign`）；**且**
2. 下游用**原生 `swift build` / `swift test`** 构建（不是 Xcode、不是 `--build-system swiftbuild`）。

真实消费者（Xcode 里的 App）**不命中** ——Xcode 用的就是编译 `.metal` 的那套构建系统。
命中的是「用 SwiftPM 命令行跑测试、且测试触到 shader」的下游，例如 StoryUI 的 CI。

**缓解**（B-1 必须一并落地，缺一不可）：
- `CoreDesignShaders` 的公开入口在**首次使用时**跑一次 ③ 的 fail-closed 检查，
  查不到就 `assertionFailure` / 抛错，**把静默无渲染变成响亮失败**；
- README 与 CLAUDE.md 明写「用原生 `swift build` 消费本 product 时须加
  `--build-system swiftbuild`」；
- `docs/components/` 里每个 shader 的文档带同一句话。
⚠️ 用 `precondition` 或 throw，**不要用 `assertionFailure`**——它在 release 下是 no-op
（#258 终审 Suggestion）。
⚠️ ③ 的 fail-closed 检查会创建 Metal device，B-1 应用 `static let` 缓存一次，
不要每次使用都建。

⚠️ **task DoD 的一项作废声明**（#258 终审 I-5）：`248.md` 的 DoD 写「可复用脚本
（`build-metallib.sh` 雏形）留在仓内」——**α 下该脚本没有意义**（不需要预编译 metallib）
⇒ **本项随 α 改判一并作废**，不是遗漏。

---

## 交付 A：Epic B 固定成本（`N_B` 的分子）

α 下 B-1 + B-4 的固定成本**比 epic 假设的 β 低一档**：

| 项 | β 下 | α 下 |
|---|---|---|
| 3 份 metallib 生成脚本 + 提交 | 有 | **无** |
| 运行时平台选择 `#if` | 有 | **无** |
| sha256 manifest 同步守卫 + fixture | 有 | **无** |
| `.metal` `exclude:` 与产物冗余处理 | 有 | **无** |
| 工具链版本钉死（`-std=` / `-mios-version-min`） | 有 | **无** |
| CI 改动 | 无 | **1 处**（SwiftPM 腿**另加一步**只跑 shader 测试的 swiftbuild；⚠️ **不是**给整腿加 flag——那正是问②否决的读法） |
| target + product + project.yml + probe + AGENTS 同步 | 有 | 有 |
| fail-closed 加载检查 + 首次使用响亮失败 | 有 | 有 |
| Mac Catalyst 声明 | 有 | **无**（构建系统处理） |

⇒ **固定成本估算：α 下 B-1 ≈ 4–6 小时，B-4 ≈ 6–10 小时（文档/署名/画廊/快照排除）**；
β 下 B-1 要再加 8–14 小时（3 份产物 + 守卫 + fixture + 工具链钉版本）。

## 交付 B：每 shader 边际成本（`N_B` 的分母）

本 spike 实做了 1 个 `colorEffect` + 1 个 `layerEffect`：

| 维度 | 实测 |
|---|---|
| **体积** | 1 个 shader = 7616 B；2 个 = 16788 B ⇒ **边际 ≈ 9.2 KB/shader**；28 个外推 **≈ 250 KB**，远低于 NFR-2 的 2 MB/平台 ⚠️ 这两个是简单 shader，真实的分形/体积步进/噪声会更大，**此为下界** |
| **`colorEffect` 工时** | 参数化改造 + wrapper + Preview + 文档 ≈ **1–1.5 小时/个**（17 个 ≈ 17–26 小时） |
| **`layerEffect` 工时** | 同上，但 **7 个"颜色写死"件**（ChromaticGlass / Foil / Glitter / IntenseBling / PolishedAluminum / GlassLogo / LiquidMetal）要把 `.metal` 里的调色板全部提到 Swift 侧 ⇒ **2–3 小时/个**；其余 4 个 ≈ 1–1.5 小时 ⇒ 11 个 ≈ **18–27 小时** |

### `N_B` 的推导

⚠️ **`N_B` 的语义**（PRD `:523-527` 钉死，此处写明免得误读）：它是
**「摊销固定开销 ≤ 每 shader 直接成本」的盈亏平衡点**，**不是**「值不值得做」的阈值。

⚠️ **初稿的推导有三处站不住，已修正**（#258 终审 I-2）：

1. **分子分母重叠**——初稿把 B-4 的「文档/署名/画廊/快照排除」整块算进固定成本，
   但其中**逐 shader 的条目**（`docs/components/*.md`、ACK 条目、画廊项）本质是**边际**。
   ⇒ 从分子移到分母。**修正后固定成本 ≈ 8–12 小时**。
2. **加权均值口径错**——1.5h 是按 28 个全落地加权；但**可能落地的集合**里有 7 个是
   `layerEffect` 难件（2–3h），加上移到分母的逐 shader 文档/画廊 ⇒
   **修正后边际 ≈ 2.0–2.5 小时/shader**。
3. **取值无理由**——初稿在区间里取偏上值且未说明。

**修正后**：8–12h ÷ 2.0–2.5h ⇒ **`N_B` ≈ 3–6 ⇒ 取 `N_B` = 5**（取区间中值；
⚠️ 由于 ⑤ 未按 AC 取样、边际成本是估算，**取值偏保守对闸②更安全**）。

⚠️ **被否决的兜底方案**：初稿写「低于 `N_B` 就把少数几个 shader 直接放进
`CoreDesignEffects`」——**与 PRD 冲突**（PRD `:34-38` 否决单 target 的理由之一正是
构建系统约束不该污染 Effects）。α 下这样做会把「native 构建静默无渲染」带进
**StoryUI CI 正在消费的 Effects** ⇒ 该兜底作废；低于 `N_B` 就是**不做**。

⚠️ **这个数字要与 #249 的许可裁定结果相乘才是 go/no-go**：
`N_B = 5` 意味着 28 个里至少要有 5 个能落地。
⚠️ **撰写本 spike 时的预判是「闸②大概率才是瓶颈」**（上游已标注来源的只有 7 个，
且那 7 个的传递来源当时未核）——**该预判已被 #249 推翻**：它裁定 **26 个可落地**
（2 个已追到兼容许可 + 24 个 clean-room），26 ≥ 5 ⇒ **闸②通过**。

---

## 对既有文档的回改清单

- `.claude/epics/shipswift-shaders/epic.md`
  - **AD-B**「β 是默认走向」→ 改判 **α**，理由见本文件
  - **AD-C**「3 份 metallib」整节 → α 下不适用，改为记录 β 作为**被否决的备选**
  - **AD-D** 验证路径表 → α 下是 `swiftbuild` + `xcodebuild`
  - 新增：α 的残余风险与三条缓解（首次使用响亮失败 / README / 逐组件文档）
  - `N_B` 填 **5**（⚠️ **不是 10** —— 10 是本 spike 初稿的值，已随 I-2 的推导修正作废）
- `.claude/prds/shipswift-harvest.md` **FR-2** → **可选条件改写（待 PRD owner 裁决）**——不是「填结论」，是把 α 的可选条件从「所有已知消费路径都能切 swiftbuild」改成「Xcode 消费者不命中 + CLI 消费者按文档自担 + 响亮失败兜底」
- `.claude/epics/shipswift-foundation/epic.md` A0-5 的 SC → 勾选，并记「macOS runner 的
  Metal device 未解，转 B-1 的一次性 CI 探针」
- **`docs/shader-provenance.md`（#249）** → 它引用的 `N_B = 10` 与
  「10–16h ÷ 1.5h」推导口径**已作废**，须同步改为 **5** 与 `8–12h ÷ 2.0–2.5h`
  ⚠️ 两个 PR 同时开着，不点名就没人负责改那边
- **B-2 / B-3 拆 task 时**：#249 裁定 24/26 走 **clean-room 重写**而非移植，
  而本 spike 的边际成本是从「难件 + 逐 shader 文档」推的、**不是**从 clean-room 推的
  ⇒ **边际成本须按 clean-room 再核一次**
