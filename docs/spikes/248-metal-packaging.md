# Spike #248 — SwiftPM 分发 Metal shader 的打包结论

> `shipswift-foundation`（#241）闸①。本文件是 spike 的**结论**；实验包在仓外
> （scratchpad `metal-spike-248`），按 epic AD-A **不进仓**。

## TL;DR — 结论与 PRD/epic 的预设相反

**PRD 与 epic 把路径 β（预编译 metallib 作二进制资源）定为默认走向**，理由是
「所有已知消费路径都用原生 `swift build`，切不到 swiftbuild」。

**实测推翻了这个前提。** 本 spike 建议改判 **路径 α（`.metal` 源随 target 编译）**：

| | α（源码随 target 编译） | β（预编译 metallib） |
|---|---|---|
| CI SwiftPM 腿 | 加 `--build-system swiftbuild`，**已实测在真实 CoreDesign 包上跑通** | 不用改 |
| 分平台产物 | **构建系统自动按 destination 产出**，零额外工作 | 手工提交 **3 份** + 运行时 `#if` 选择 |
| `.metal` 与产物同步 | **不可能失步**（同一次构建） | 需 sha256 manifest 守卫，否则改了 shader 忘重编 = 静默用旧效果 |
| 仓库体积 | 0 | 每次改 shader 最多提交 6MB 二进制 |
| 工具链耦合 | 跟随构建时的 Xcode | 需钉 `-std=` / `-mios-version-min`，否则新 Xcode 编的在旧运行时加载失败 |
| Mac Catalyst | 构建系统自己处理 | `#if os(macOS)` 在 Catalyst 下为假 ⇒ 会误选 `iphoneos` 份 |
| 残余风险 | 见下方《α 的残余风险》 | 上面五行全是永久维护负担 |

⇒ **epic `shipswift-shaders` 的 AD-B / AD-C / AD-D 需按本结论回改。**

---

## 六问逐条

### ① 构建系统选型 → **α**

**处理矩阵**（实测，Swift 6.3 / Xcode 26.4）：

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

⇒ CI 的 SwiftPM 腿**切得动**。PRD C-1 与 epic AD-B 写的「α 等于把构建系统约束转嫁给下游」
**只对一类下游成立**，见《α 的残余风险》。

### ② CI 改法

- **SwiftPM 腿**：`swift build` / `swift test` → 加 `--build-system swiftbuild`。
  ⚠️ 该腿是**唯一**需要改的；下面两条腿不需要动。
- **iOS Simulator 腿**：已经是 `xcodebuild`，天然编译 `.metal`，**零改动**。
- **downstream-probe 腿**：build-only，且 probe 只依赖 `CoreDesign` product。
  即便将来接 `CoreDesignShaders`，probe 验的是「nonisolated 能不能用这些类型」，
  **不需要 metallib 在运行时存在** ⇒ **零改动**。
- **Bool 棘轮腿**：不读 `Sources` ⇒ 零改动。

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

**fail-closed 已实证双向**：
- 原生 `swift build`（无 metallib）⇒ 测试**判红** ✅（不是静默跳过）
- `--build-system swiftbuild` ⇒ 测试**通过**，`spikeSwirl` / `spikeFoil` 两个 stitchable 函数都解析出来

⚠️ **未解项：GitHub Actions `macos-26` runner 有没有可用 Metal device？**
本机（Apple Silicon）有。CI runner 是虚拟化环境，**本 spike 无法在本地回答**。
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

编译通过、加载通过。⇒ FR-8「颜色 100% 由调用方传入」在 `.metal` 侧**技术上可达**。

### ⑤ layer 输入（`layerEffect`）→ **可行，但有一个必踩的坑**

```metal
[[stitchable]] half4 spikeFoil(float2 pos, SwiftUI::Layer layer,
                               float2 size, float t, half4 tint) { … }
```

⚠️ **必须 `#include <SwiftUI/SwiftUI_Metal.h>`**，否则 `error: use of undeclared
identifier 'SwiftUI'`。上游 34 个 `.metal` 里 30 个都带这行——**改造那 7 个"颜色写死"件时
不要在重排 include 时把它弄丢**。

### ⑥ 分平台 metallib → **α 下不是问题**

`xcodebuild` 按 destination 自动产出：

| destination | 产物 | 大小 |
|---|---|---|
| `generic/platform=iOS Simulator` | `Debug-iphonesimulator/default.metallib` | 16820 B |
| `generic/platform=iOS` | `Debug-iphoneos/default.metallib` | 16772 B |
| macOS（swiftbuild） | `…bundle/Contents/Resources/default.metallib` | 16788 B |

⇒ **epic AD-C 规定的「3 份 metallib + 运行时 `#if` 选择 + `exclude:` + sha256 manifest 守卫」
整套复杂度是 β 独有的，α 下全部消失。**

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
| CI 改动 | 无 | **1 处**（SwiftPM 腿加 flag） |
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

固定成本（α）≈ **10–16 小时** ÷ 边际成本 ≈ **1.5 小时/shader（加权均值）** ⇒ **`N_B` ≈ 7–11**。

⚠️ **取 `N_B` = 10**：低于 10 个 shader 可落地时，Epic B 的固定基建（新 target + product +
CI flag + 文档/署名/画廊/快照排除）摊到每个 shader 上超过其自身成本，不划算——
那种情况下更该把少数几个 shader 直接放进 `CoreDesignEffects`，不另立 target。

⚠️ **这个数字取决于 #249 的许可裁定结果，两者相乘才是 go/no-go**：
`N_B = 10` 意味着 28 个里至少要有 10 个能落地。上游已标注来源的只有 7 个
（且那 7 个的**传递来源**尚未核）⇒ **闸②大概率成为真正的瓶颈，而不是本闸。**

---

## 对既有文档的回改清单

- `.claude/epics/shipswift-shaders/epic.md`
  - **AD-B**「β 是默认走向」→ 改判 **α**，理由见本文件
  - **AD-C**「3 份 metallib」整节 → α 下不适用，改为记录 β 作为**被否决的备选**
  - **AD-D** 验证路径表 → α 下是 `swiftbuild` + `xcodebuild`
  - 新增：α 的残余风险与三条缓解（首次使用响亮失败 / README / 逐组件文档）
  - `N_B` 填 **10**
- `.claude/prds/shipswift-harvest.md` **FR-2** → α/β 判据的结论侧回填
- `.claude/epics/shipswift-foundation/epic.md` A0-5 的 SC → 勾选，并记「macOS runner 的
  Metal device 未解，转 B-1 的一次性 CI 探针」
