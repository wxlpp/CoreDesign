---
name: NFR-7 通用能耗策略表下沉到 CoreDesign
issue: 271
created: 2026-09-06
裁决: 用户 2026-09-06 逐字「下沉」
---

# 裁决与本计划自己做的三个取舍

用户裁决第 1 条：**通用策略表下沉到 `CoreDesign`**。第 3 条（不下沉时的判据）作废。
第 2 条（三个类型怎么切）由本计划定，含三个工程取舍：

## 取舍 A（**用户 2026-09-06 裁决：a，删掉空壳**）：边界用 `Bool`，`EffectsPowerMode` **删除**

⚠️ 2026-09-04 已有裁决（`EnergySignalEnvironment.swift:53-58`）：「让通用底座去定义一个
『档位枚举』，等于把动效层的语义分级摊派给所有消费者（shader 那 17 个背景没有『档位』，
只有『要不要省电』）。需要更细分级的模块**自己**在上面包一层」。

⇒ 直接把 `EffectsPowerMode` 搬进 `CoreDesign` **会推翻它**。而基座那两个键本来就是
`Bool?` / `ScenePhase?` ⇒ 下沉的映射只需 `Bool`：

```swift
// CoreDesign
public nonisolated struct EnergyState: Sendable, Equatable {
    public let scenePhase: ScenePhase
    public let isLowPower: Bool
    public var policy: RenderPolicy { … }
}
```

⚠️ **`EffectsPowerMode` 删除，不是「原地保留」**（用户裁决）。理由是实测：
它在整个 Effects 里**只有一个语义消费点**（`OrbitingLogos.swift:291`），
取舍 A 之后那个点也改用 `Bool` ⇒ **没有任何代码读 `.lowPower` / `.standard`**，
留着只是为了不改一段注释。本次已是破坏性变更、模块外消费者为零 ⇒ 一并删。
`lifted(from:)` 与它的测试 `liftsGenericLowPowerKeyIntoPowerMode` 同去。

⚠️ **我原来在守的那条「基座不该定义档位枚举」不是用户裁决**：09-04 的裁决逐字是
「**键用 `Bool`**」（`EnergySignalEnvironment.swift:48`），而 `:53-58` 那段「档位枚举」
是 agent 写的推理散文。上一版计划把散文当裁决在守。
⚠️ 代价是 **3 条**（不是 2 条）`CoreDesign` 永久 Bool 豁免，各自抬
`docs/bool-exemptions-baseline.json` 的 `CoreDesign` 分账（现 32/35）：
`EnergyState.init#isLowPower`、`presentation(reduceMotion:)#reduceMotion`、
以及 `resolve(...)#lowPowerModeOverride`（`Bool?` 归 `.plainBool`）。
⚠️ **本仓惯例是「每轮把棘轮压小」**（`bool-exemptions-baseline.json` 的 rationale 逐字），
这是反向抬 3 ⇒ 取舍 A 是否划算**需用户裁**，见文末《待裁》。
⚠️ 顺带：`BoolParameterScanner.swift:100` 那句「当前 public 的 `Bool?` 参数为 0 条」会失真，同轮改。

## 取舍 B：两道闸的**顺序**一起下沉

`EffectsPresentation` + `presentation(reduceMotion:)` **也下沉**（更名 `MotionPresentation` /
`presentation(reduceMotion:)`），只把 `frozenIfPeriodIsDegenerate`（自转专有）留 Effects 做 extension。

理由：`#282` 的 AC 逐字要「Reduce Motion ⇒ 冻结在某一帧」（= `.resting`）与
「NFR-7 后台/低电量」（= `.none`），三档一档不少；而 `EffectsEnergy.swift:215-233`
记的正是「顺序承重、两个调用点各写一遍就写反了」的事故。
⇒ 留在 Effects = B-2 必须自己再写一遍那条顺序 = **原样复制该事故到 17 个背景上**，
而那正是 `#271` 要堵的东西。同样付一条 Bool 豁免。

## 取舍 C：`.inactive ⇒ paused` 原样下沉，**但把限度改记为对所有消费者成立**

`EffectsEnergy.swift:317-335` 记着它的真实成本（macOS 失焦、窗口完全可见时效果当场消失），
现按「对小装饰可接受、对整块背景是已知限度」记账。下沉后 B-2 的 **17 个整块背景**默认继承它。

**本轮不加第四档**（「停摆但保留静止帧」）：给非 frozen enum 加 case 是源码破坏
（`EffectsEnergy.swift:36-42` 已写明会打断下游 exhaustive switch），且那是独立裁决。
⇒ 处置是**把限度写进 `CoreDesign` 侧类型文档，声明它对所有消费者成立**，并在 `#271`
关闭说明里点名「整块背景要不要第四档」为后续裁决项。

# 切面

| 成员 | 归属 |
|---|---|
| `full` / `reduced` / `paused` 三 case、`drawsAnything`、`minimumInterval` | **下沉** → `RenderPolicy` |
| `scenePhase` / `isLowPower` / `policy` 映射 | **下沉** → `EnergyState`（`Bool` 边界，取舍 A） |
| **`resolve(...)`（「注入优先、否则读系统」）+ `ProcessInfo.isLowPowerModeEnabled` 那次读** | **下沉** → `CoreDesign`。⚠️ 不下沉的话 B-2 只能自己写 `lowPowerModeOverride ?? ProcessInfo…`，而「`nil` 与 `false` 必须可区分」这条语义就此再写一遍 —— 正是 `#271` 要堵的 |
| `.hidden` / `.resting` / `.animated` 与 `presentation(reduceMotion:)` | **下沉** → `MotionPresentation`（取舍 B）。⚠️ **`.none` 改名 `.hidden`**（用户裁决）：`.none` 一旦公开，在 `MotionPresentation?` 语境下 `x == .none` 会被解析成 `Optional.none` 并**发警告**，而 probe 带 `-warnings-as-errors` ⇒ **硬红**。现在是零成本改名窗口 |
| `usesGlow` / `particleScale` | 留 Effects，`extension RenderPolicy` |
| `EffectsPowerMode` + `lifted(from:)` | **删除**（取舍 A，用户裁决；实测无人读其 case） |
| `frozenIfPeriodIsDegenerate` | 留 Effects，`extension MotionPresentation` |

⚠️ **不做 typealias 兼容层**。最硬的理由不是「0.x 先例」，而是**模块外实际消费者为零**
——唯一消费者是 `scripts/downstream-probe` 自己。

# 步骤

⚠️ **1–4 / 6 / 7 是一个原子提交，不是可分步验证的序列**：`BoolExemptionGuard` 是双向差集
——先加 Bool 参数（源码有、台账无）红，先加豁免（台账有、源码无）也红 ⇒ 两者之间
**不存在**能过 `swift test` 的中间态。同理第 2 步删旧名后，第 4 / 6 / 7 任何一条没跟上都红。
可真正后置的只有 **5**（probe，需新 API 已在）、**8**（重写注释）、**9**（BREAKING，
要等 `MODULE=CoreDesignEffects` 那条命令能在改后的树上跑）。
⇒ 顺序读作：**原子改动（1–4, 6, 7）→ 验证 → 5 → 8 → 9**。

1. 新建 `Sources/CoreDesign/Environment/EnergyPolicy.swift`：`RenderPolicy` / `EnergyState` /
   `MotionPresentation`。⚠️ 三者**必须显式 `nonisolated`**（三个 target 都开
   `.defaultIsolation(MainActor.self)`；漏标时库内全绿、只有 probe 的 `nonisolated func` 会红）。
2. Effects 侧：删下沉部分，补两个 extension；`EffectsPowerMode` 与 `lifted(from:)` 原地留。
3. **Bool 豁免**：给 `EnergyState.init` 与 `presentation(reduceMotion:)` 各加一条署名豁免，
   抬 `docs/bool-exemptions-baseline.json` 的 `CoreDesign` 分账。
4. **扫描根**（`#271` 正文点名的「扫描根跟着走」）：
   - 自陈这条的**只有一条**判据：`MicroInteractionReduceMotionGuard.reduceMotionIsOnlyConsumedByTheSharedGate`。
   - ⚠️ **不得扩 `sourceRoot`**：它被 `PlatformSupportGuard.effectsSources()`（其 `noPlatformOnlyImports`
     禁 `import UIKit/AppKit`，而 `CoreDesign` 的桥接层正靠这些 import 活着）与
     `TypewriterTextTests.source(_:)` 共享 ⇒ 只给那一条判据单开根。
   - **三处**标记串必改：`ReduceMotionGuard.swift:604` 的 `"EffectsEnergyState.resolve("`、
     `:612` 的 `"presentation(reduceMotion: self.reduceMotion)"`、
     以及 `CrossPlatformTests.swift:1236` 关键字表里的 `"EffectsEnergyState"`。
   - ⚠️ **最后那条会静默 fail-open**：它是 `#expect(!code.contains(keyword))`，改名后关键字
     永远匹配不到 ⇒ 「薄封装没自己接能耗闸」那一格变**空判据**，全套照绿。
     它**不在**第 6 步的文件清单里 —— 那次 grep 按类型名数，而这里是**字符串字面量**，
     `JudgementReferenceGuard` 也不管（它只核 `类型.成员` 形态）。
   - ⇒ 收口动作：`rtk proxy grep -rn '"Effects\(EnergyState\|RenderPolicy\|PowerMode\|Presentation\)' Tests/`
   - ⚠️ 取舍 B 把 `presentation` 也下沉了 ⇒ 扩根后 `CoreDesign` 侧文件**能**调到它，
     评审指出的「两条决定互相打架」因此消解。
5. **probe**（承重，见验证）：在 **`CoreDesignOnlyProbe`**（独立 target）新增文件，
   从 `nonisolated func` 消费 `EnergyState` / `RenderPolicy.drawsAnything` / `.minimumInterval` /
   `MotionPresentation`；`DownstreamProbe/EffectsNonisolatedUsage.swift:62-71` 改为消费
   `usesGlow` / `particleScale`。
   ⚠️ **绝不能加在 `DownstreamProbe` 里**——那个 target 的文件头记着变异实证：
   扩展成员查找**逐模块**，同 target 任一文件 import 了 Effects 就全可见，**文件级 import 隔离不成立**。
6. **改名射程 26 个文件**（取舍 B 把 `EffectsPresentation` 也纳入后，从 22 涨到 26；
   新增的四个：`CharSphere.swift` / `FullScreenTransitionPlan.swift` / `TypewriterText.swift` /
   `TextAndDisplayTests.swift`）。⚠️ `JudgementReferenceGuard` 对 `Sources/` 里
   声明的类型**不核成员** ⇒ 这 12 个源码落点**无机器兜底**，逐个人工核。
7. **测试迁移（逐条写，不写「前四条」）**：`EffectsEnergyStateTests` 七条 ——
   `policyMapping` / `injectionWinsOverSystem` / `defaultPowerModeReadsSystem` / `policyKnobs`
   前半**迁进** `CoreDesignTests`；`policyKnobs` 后半（`usesGlow` / `particleScale`）留 Effects；
   ⚠️ `energyGateOutranksReduceMotion` **也必须动**——它用 `EffectsPowerMode.allCases` 循环，
   迁走后 `CoreDesignTests` 看不到该类型，改成 `[true, false]`。
   （否则「`CoreDesign` 的公开面由另一个 target 的测试来守」）。
   ⚠️ suite 名一动必红：`EffectsEnergyStateTests.energyGateOutranksReduceMotion` 被
   `JudgementReferenceGuard` 规则 A 核，引用在 `EffectsEnergy.swift:355`、
   `ReduceMotionGuard.swift:570`、`docs/components/confetti.md:129` 三处。
8. **整段重写（不是叠一层更正），六处**：
   - `EffectsEnergy.swift:87-176` 的「已裁决：本类型留在 Effects」与「未了结的残余」；
   - `EnergySignalEnvironment.swift:35-38`「`CoreDesign` 不长出渲染策略表面」—— 落地后整段为假；
   - 同文件 `:62-64`「更细分级的模块自己包一层——`EffectsPowerMode` 就是这样一层」；
   - `DownstreamProbe/EffectsNonisolatedUsage.swift:38-60`「本 probe 是模块外唯一消费者 / 未了结的残余」；
   - `ReduceMotionGuard.swift:520-532`「本轮只留痕，不改扫描根」—— 第 4 步改了根。
9. `docs/BREAKING-CHANGES.md` 新开一节「未发布——Issue #271」，用 `0.3.0` 节的
   `| 删除 | 来源 | 替代 |` 表；删除行逐条取自下面第 2 条命令的输出。

# 验证

| 判据 | 命令 / 预期 |
|---|---|
| 包编译 | `swift build` |
| 全量 | `swift test`，**逐字核对结论行**（不只看计数） |
| **公开面·删除侧** | `MODULE=CoreDesignEffects bash scripts/api-surface-diff.sh main` —— 预期 `- 删除` 恰为下沉的类型与成员、`+ 新增` 恰为两个 extension 成员 |
| **公开面·新增侧** | `bash scripts/api-surface-diff.sh main`（默认 `MODULE=CoreDesign`）—— 预期只有 `+ 新增` |
| **承重：下游隔离** | `cd scripts/downstream-probe && swift build -Xswiftc -warnings-as-errors`（CI 的 `ci.yml:206` 就是这条） |
| Bool 棘轮 | `scripts/bool-exemptions-ratchet.sh` |
| 预览宿主 | `xcodebuild -project App/CoreDesignPreview.xcodeproj …`（`CLAUDE.md` 要求改公开符号后手动确认） |

⚠️ **承重判据是 probe 那条，不是 `swift package describe`**。
上一版把「`CoreDesign` 的 `target_dependencies` 恒为 `null`」当承重——**那是空判据**：
本次任何一步都不碰 `Package.swift`，而 `CoreDesign → Effects → CoreDesign` 是环、
SwiftPM 在解析期就拒绝 ⇒ **没有一条路径能让它变绿地失败**。
真实失败形态是「下沉没到底」（`resolve` 留在 Effects、`drawsAnything` 漏搬、漏标 `nonisolated`），
只有 `CoreDesignOnlyProbe` 抓得住。
**变异**：把 `drawsAnything` 挪回 Effects ⇒ 只有 `CoreDesignOnlyProbe` 红。

# 本计划有意未做的

- **不加 `RenderPolicy` 第四档**（取舍 C）——源码破坏 + 独立裁决。
- `minimumInterval = 1/15` **没有任何上游口径来源**（PRD 的 NFR-7 只写「暂停渲染 / 降帧」，
  全仓 grep `1.0 / 15` 在 prds 与 epic 下 0 命中）⇒ 下沉后在类型文档里记一句
  「15 fps 是本仓自选的降帧档，无上游口径」，免得下一个人去找不存在的条款。

# 待裁项（已全部裁完）

- 取舍 A 的 (a)/(b)：用户裁 **(a) + 删掉空壳 `EffectsPowerMode`**（2026-09-06）。
- `.none` 的命名：用户裁 **`.hidden`**（2026-09-06）。
