import Foundation
import Testing

// MARK: - 公开 static 的 MainActor 隔离棘轮：树内看门人 / MainActor static ratchet gate (Issue #307)
//
// ## 被守的东西
//
// `scripts/mainactor-static-ratchet.sh` 从 `swift package dump-symbol-graph` 的产物里筛出
// 「公开 / open 的 static 型成员，且 `declarationFragments` 拼起来含 `@MainActor`」，
// 与 `docs/mainactor-static-exemptions.txt` 做**双向差集**。它替掉的是 `#290` 那份
// **一次性人工枚举**：`scripts/downstream-probe` 只钉住**它自己引用到的**符号，
// 新类型上新加的 `public static let` 它一个都看不见（`scripts/api-surface-diff.sh` 的
// 头注释自己就写了「它引用的符号是**手写清单**」）。
//
// ## 为什么判据不在 `swift test` 里，而本文件在
//
// `swift package dump-symbol-graph` 是一次完整的 SwiftPM 调用，热 `.build` 上**实测
// 约 4 s**（六次连测 6.2 / 4.2 / 4.5 / 4.1 / 4.2 / 4.3 s，第一次偏高是内层增量构建
// 还没完全热），写出约 265 MB JSON。
// ⚠️ 这里曾写「约 100s」——那是**失真的数**，PR #314 终审实测推翻，本轮复测确认。
// 差 25 倍会把权衡整个换掉，所以一并把结论改准：**「会给每一次本地 `swift test` 加
// 开销」不再是理由**（4 s 量级）。留下的理由只有一条，而它独立成立：**从 `swift test`
// 里 spawn 一次完整的 SwiftPM 调用有嵌套构建锁的风险。**
// ⇒ 判据落在脚本 + `ci.yml` 的 `swiftpm` job 一步（复用 `swift test` 之后的热
// `.build`），与 `downstream-probe` / `bool-ratchet` 同形。
//
// 而「判据在 CI」立刻带来 `#304` F-4 那个坑：**CI 配置无人看守**。本文件就是那道看守，
// 它**无条件**（没有任何 `.enabled(if:)`）随每次 `swift test` 跑，钉三样东西：
//
// 1. **豁免表逐条** —— `registeredExemptions` 与 `docs/mainactor-static-exemptions.txt`
//    做双向差集。往表里偷加一行、或把表清空，本文件当场红。
//    ⚠️ 这不是「重复一遍脚本做的事」：脚本比的是「symbol graph ↔ 表」，本文件比的是
//    「表 ↔ 树内常量」。两条链路串起来才是「新加的 MainActor static 一定会有人看见」。
// 2. **脚本的筛条件字面量** —— `requiredScriptLiterals` 逐条 `contains`。
//    把 `stale` 那一半差集删掉、把候选面归零的防空转网删掉、把 kind 名字打错，
//    这些改法都不会让脚本自己判红（它照样 exit 0），只有本文件会红。
// 3. **`ci.yml` 里那一步** —— 那条 `run:` 逐字；**那个 step 的直接子键走正面清单**
//    （`allowedStepKeys`，清单外的键一律判红）；**那个 job 的直接子键**里不许出现
//    `if` / `needs` / `continue-on-error`，且比对前先把键名**归一化**
//    （按第一个 `:` 切、剥引号、去空白）。
//    ⚠️ 那条 `run:` 还必须是**行内标量**（`run: bash …`），**不得**写成块标量
//    （`run: |` + 缩进正文）。这一条把「兄弟行不设防」那个缺口的**入口**堵上了：
//    要在那条命令旁边加一行 `exit 0` / `trap 'exit 0' ERR`，**必须先**把它改写成
//    块标量——而那一步现在当场判红。⚠️ 这不是宣称兄弟行整体已修（`run: |` 之外
//    的路子仍敞着，见下面「兄弟行不设防」那条），是把最便宜的那道门关上。
//    ⚠️ 正面清单 + 归一化都是 PR #314 终审逼出来的换纪律，不是打补丁：原实现按
//    `trimmed.hasPrefix("if:")` 比对，于是 `"if": false` / `'if': false` /
//    `if : false` / `continue-on-error : true` / job 级 `"if": false` /
//    `needs : simulator` 这**六种与被拦写法逐字节同义的合法 YAML**全部实测判绿。
//    负面清单按拼法追不完——这正是 `expectedRunCommand` 那里已经立过的纪律
//    （「按正则追不完 ⇒ 用正面清单」），当时只在 `run:` 上执行了，没贯彻到键上。
//
// ## ⚠️ 射程与已知缺口（不要读成比实际更强）
//
// · **只有「第三方类型的扩展块成员」不在射程内**（这是脚本《范围定案与代价》那一节
//   买单的那一侧，照录到这里，别只在一处登记）：`dump-symbol-graph` 把「声明在外来
//   类型上的成员」写进 `<Target>@<外来模块>.symbols.json`。脚本扫**主文件 + 本包内
//   跨 target 的那一类**（`<Target>@<本包另一个 target>.symbols.json`），
//   **不扫**第三方模块那一类（`@SwiftUI` / `@SwiftUICore`）。
//   本轮实测：那三个第三方 `@…` 文件里 `@MainActor` 命中共 46 条
//   （`CoreDesign@SwiftUI` 12 + `CoreDesignEffects@SwiftUICore` 34，
//   `CoreDesign@SwiftUICore` 的 285 个色彩 token 命中为 0），全部是转场 / style 工厂
//   ——它们的隔离来自 SwiftUI 协议本身，本来就该是 `@MainActor`。把它们收进射程
//   意味着每加一条转场就要改豁免表，棘轮会退化成橡皮图章。**这是有意的取舍，代价是
//   一块真实的盲区，且空间开放。**
//   ⚠️ **代价的形态要写准**：它**不是**「往 `public extension Color` 加一个纯数据常量
//   并忘了写 `nonisolated`」——那个形态**复现不出来**（PR #314 终审实测，本轮复现）：
//   `.defaultIsolation(MainActor.self)` 不作用于外来模块类型的扩展，新加的
//   `public extension Color { static var probeColorToken: Color { .red } }`
//   在 symbol graph 里**根本不带 `@MainActor`**；佐证是现存那 285 个色彩 token
//   **一个都没写 `nonisolated`**，却**一个都不是** MainActor 隔离的。
//   真实形态窄得多：**显式**写 `@MainActor`，或扩展一个自身就是 `@MainActor` 的第三方类型。
//   ⚠️ **包内跨 target 那一族已经收进射程**（PR #314 终审补的，零 churn）：
//   `CoreDesign` 的 109 个公开 nominal 类型里 62 个带 `@MainActor`（本轮实测），
//   `CoreDesignEffects` / `CoreDesignCharts` 往其中任一个加公开 static，成员会落进
//   `CoreDesignEffects@CoreDesign.symbols.json` —— 那一族今天**零个文件**，
//   所以收进来不改变判据在今天的任何行为，却把洞永久关上。实证见 PR 正文。
//
// · **本文件不验证「脚本跑出来是对的」** —— 它只验证脚本的**筛条件字面量**在场。
//   ⚠️ 例子要举准（PR #314 终审实测纠正了原来那个）：
//   · **能逃逸**：在 python 正文的**开头**插一行 `sys.exit(0)`、其余原样 ⇒ 脚本
//     exit 0，本文件**全绿**（字面量一条不少，只是不再被执行）。
//   · **能逃逸**：在 `set -euo pipefail` 之后加 `trap 'exit 0' ERR` ⇒ 脚本 exit 0，
//     本文件**全绿**；实测它能中和一次真实违规（豁免表多一行坏条目照样 exit 0）。
//   · **不能逃逸（原来举错的那个）**：把 python 段**整段**换成
//     `python3 -c 'import sys; sys.exit(0)'` ⇒ 脚本 exit 0，但 11 条 pin 里有 **9 条
//     （全部写在 python 段里的那些）当场缺席**，本文件判红（另 2 条
//     `--minimum-access-level public` 与豁免表路径写在 bash 段里，不受影响）。
//     照那句去复现的人会得到相反结果，误以为缺口已经堵上。
//   ⇒ 与 `DownstreamProbeGateGuard` 头注释「selftest 脚本自己的断言逻辑无人看守」是
//   **同一条缺口**，同样**未修、只登记**。兜住它的不是判据，是脚本在 CI 上每次真的
//   跑一遍：它判红过（见 PR #307 的变异实证）。
//
// · **兄弟行不设防（已收窄，未消除）** —— 与 `DownstreamProbeGateGuard` 第 6 类同款：
//   那条 `run:` 逐字保留、在它旁边加一行 `exit 0` / `trap 'exit 0' ERR`，
//   本文件全绿而这一步什么也没做。
//   ⚠️ **收窄的那一半**：`ci.yml` 里那条 `run:` 是**行内标量**，要加兄弟行**必须先**
//   把它改写成 `run: |` 块标量——而 `runLineIsInlineScalar` 那条正面判据现在当场判红。
//   这是**正面判据**（钉「值必须逐字等于 `expectedRunCommand`」），不是按拼法追
//   `^exit 0` / `trap .*ERR`；后者正是 `#304` 第 4 轮终审明确不建议的路线。
//   ⚠️ **没有消除的那一半，如实登记**：`run:` 之外的兄弟形态仍敞着——同一个 job 里
//   **另起一个 step** 抢先 `exit 0`、或在**别的 step** 里改坏环境，本文件都看不见。
//
// · **`swiftpm` job 上的 `if:` 只堵 job 级与本 step 级** —— 该 job 的
//   「Upload test logs」step 带着 `if: always()`（合法且必要），所以不能像
//   `DownstreamProbeGateGuard` 那样对整个 job 块做 `contains("if:")`。本文件改成
//   **按缩进定位**：job 的直接子键、以及**含那条 `run:` 的那个 step** 两处各查一遍。
//   ⇒ **别的 step 上的 `if:` 不判红**（也不该判红）。而 workflow 级 `on:` 收窄 /
//   `paths-ignore:` / 假的 `runs-on:` 与 `DownstreamProbeGateGuard` 登记的一样**仍敞着**。
//
// · **已知会假红的合法改写**（都 fail-closed，登记以免下次被当成 bug 追）：
//   ① 把 `steps:` 底下的 `- ` 缩到与 `steps:` **同列**（合法 YAML，但 `stepBlocks`
//      按「缩进大于 `steps:`」切块，会切不出 step）；
//   ② 给脚本路径加引号（`bash "scripts/mainactor-static-ratchet.sh"`）——
//      `expectedRunCommand` 是逐字正面清单；
//   ③ 在那条 `run:` 行尾加 ` # 注释`——YAML 语义上值没变，本文件按整行逐字比 ⇒ 判红。
//      **③ 最可能被无辜触发**，改那一行前先看 `expectedRunCommand`。
//   ④ 给那个 step 加一个**合法但不在 `allowedStepKeys` 里**的键（`id:` / `timeout-minutes:` …）
//      ——正面清单的必然代价，处置是把它加进 `allowedStepKeys` 并说明理由。
//
// ## 本文件的判据（限定名，供 `JudgementReferenceGuard` 规则 A 接住改名 / 删除）
//
// 删掉本文件里任何一条 `@Test` 本身**不会有别的东西判红**（没有 `Type.成员` 形式的
// 引用可供规则 A 接住）——这与 `ColorGradeResolutionGuard` 那边「写成限定名之后改名 /
// 删除至少会被规则 A 接住」的做法不一致。下面这张表就是补上的那一层：
//
// · `MainActorStaticRatchetGuard.exemptionTableMatchesRegisteredTable`
// · `MainActorStaticRatchetGuard.scriptPinsTheFilterPredicate`
// · `MainActorStaticRatchetGuard.scriptIsExecutable`
// · `MainActorStaticRatchetGuard.workflowRunsTheRatchet`
// · `MainActorStaticRatchetGuard.syntheticWorkflowWithoutTheStepIsRejected`
// · `MainActorStaticRatchetGuard.syntheticWorkflowWithNeutralizedExitCodeIsRejected`
// · `MainActorStaticRatchetGuard.syntheticWorkflowWithBenignSuffixIsRejected`
// · `MainActorStaticRatchetGuard.syntheticWorkflowWithProseIsRejected`
// · `MainActorStaticRatchetGuard.syntheticWorkflowWithStepConditionIsRejected`
// · `MainActorStaticRatchetGuard.syntheticWorkflowWithJobLevelConditionIsRejected`
// · `MainActorStaticRatchetGuard.syntheticWorkflowWithEquivalentKeySpellingsAreRejected`
// · `MainActorStaticRatchetGuard.syntheticWorkflowWithBlockScalarRunIsRejected`
// · `MainActorStaticRatchetGuard.syntheticWorkflowWithoutJobIsRejected`
// · `MainActorStaticRatchetGuard.syntheticScriptMissingAnyLiteralIsRejected`
//
// ⚠️ 加 / 删一条 `@Test` 时同步这张表，并同步下面那几条**基数断言**
// （`requiredScriptLiterals` / `registeredExemptions` / `blockedJobKeys` /
// `allowedStepKeys` 的 `count`）——基数断言是 PR #314 终审补的，理由见它们各自的注释。

@Suite("#307 公开 static 的 MainActor 隔离棘轮不得被静默拆掉")
struct MainActorStaticRatchetGuard {

    // MARK: - 被钉住的常量

    /// 判据脚本（仓库相对路径）。
    nonisolated static let scriptRelativePath = "scripts/mainactor-static-ratchet.sh"

    /// 豁免表（仓库相对路径）。脚本与本文件的**唯一**共同数据源。
    nonisolated static let exemptionsRelativePath = "docs/mainactor-static-exemptions.txt"

    /// 承载那一步的 job 名。
    ///
    /// ⚠️ 有意搭 `swiftpm` 而不是另起一个 job：那一步要复用 `swift test` 跑完之后的
    /// **热 `.build`**（`dump-symbol-graph` 仍要重跑一遍符号提取，热树上本机实测约 4 s；
    /// 冷树上还要先整包构建一次，那一段是构建本身的时间）。另起 job 会多起一台
    /// macOS runner，按 10× 计费——**这才是搭车的理由**，不是那 4 s。
    nonisolated static let jobName = "swiftpm"

    /// 那条 `run:` 的**整条**逐字文本。
    ///
    /// ⚠️ 与 `DownstreamProbeGateGuard.expectedProbeBuildCommand` 同一条纪律：这是**正面
    /// 清单**，不是「含某个关键词」。给它加**任何**尾巴都判红——` || true` / ` ; true` /
    /// ` | tee ratchet.log` / 甚至合法的 `--verbose`。理由：中和退出码的拼法按正则追不完
    /// （`#304` 第 3 轮 I-A 那一族的教训）。要改写这一行，同时改这里。
    nonisolated static let expectedRunCommand = "bash scripts/mainactor-static-ratchet.sh"

    /// 认出「这一行想跑那个脚本」的识别特征（不含 `bash ` 前缀）。
    ///
    /// 用它先把候选行捞出来，再拿 `expectedRunCommand` 逐字比——这样「标志还在但长了尾巴」
    /// 报的是「长出尾巴」而不是「找不到这一步」，两种失效形态的报错不会混。
    nonisolated static let scriptMarker = "scripts/mainactor-static-ratchet.sh"

    /// 已登记的豁免，**逐条**。
    ///
    /// ⚠️ 这不是「允许清单」而是「已知修不掉清单」：新加的公开 static 成员默认被
    /// `.defaultIsolation(MainActor.self)` 卷进 MainActor，处置是**给它加 `nonisolated`**，
    /// 不是往这里补一行。补一行之前先读 `docs/mainactor-static-exemptions.txt` 里
    /// 每条现有豁免下面写的「为什么修不掉」，并给新条目写一条同等分量的。
    nonisolated static let registeredExemptions: Set<String> = [
        "CoreDesign:SidebarTextStyle.primary",
        "CoreDesign:SidebarTextStyle.secondary",
        "CoreDesign:SidebarTextStyle.tertiary",
        "CoreDesign:BottomInputBarDefaults.placeholder",
        "CoreDesign:CoreElevation.spec(for:)",
    ]

    /// 脚本里必须**逐字**在场的片段，每条附「删掉它会怎样」。
    ///
    /// ⚠️ 选的都是**删掉之后脚本仍然 exit 0** 的东西——那才是本文件存在的理由。
    /// 语法错误、路径写错之类，脚本自己在 CI 上就会红，不需要在这里重复一遍。
    nonisolated static let requiredScriptLiterals: [(literal: String, reason: String)] = [
        (
            #"STATIC_KINDS = {"swift.type.property", "swift.type.method", "swift.type.subscript"}"#,
            "筛的三种 static 型成员 kind。少一种（或名字打错一个字母）⇒ 那一类成员静默漏筛，脚本照样 exit 0"
        ),
        (
            #"PUBLIC_LEVELS = {"public", "open"}"#,
            #"""
            可见性筛。⚠️ **整条今天都是空跑**，不只是 `open` 那一半：`dump-symbol-graph` 的
            `--minimum-access-level` 默认就是 `public`，本轮实测整张图 50432 个符号的
            `accessLevel` 全是 `public`。写在这里是为了将来加 open class、或有人把门槛
            调低时不静默漏掉
            """#
        ),
        (
            "--minimum-access-level public",
            #"""
            把 dump 的可见性门槛**显式**写死。删掉它 ⇒ 门槛退回 SwiftPM 的默认值，
            而 `PUBLIC_LEVELS` 那条筛的非空性完全建立在那个默认值上（今天默认恰好是
            `public`，脚本照样 exit 0）——那正是「一条判据的前提没被钉住」的形态
            """#
        ),
        (
            #"SYNTHESIZED_MARK = "::SYNTHESIZED::""#,
            #"""
            **范围定案的另一半**（不是「顺手剔噪音」）：symbol graph 把写在协议扩展上的成员
            **复制**一份到每个具体遵从类型上、挂 `::SYNTHESIZED::`。不剔的话 `CoreDesign`
            从 42 涨到 56、`CoreDesignEffects` 从 32 涨到 78，多出的 58 条里有 **46 条正是
            被文件筛选挡在门外的那 46 条转场 / style 工厂**（本轮逐条同名核对），
            另 12 条是 `Transition.properties` 默认实现。⚠️ 这条理由曾写「多出的 14 条不是
            本包写的声明」——**那是错的**：`CoreDesign` 那 14 条里 12 条恰恰是本包写的声明
            （`CircularGlassButtonStyle.circularGlass` / `CoreProgressViewStyle.core` / …），
            只是换了个键，且其中 12 条带 `@MainActor`
            """#
        ),
        (
            #"ISOLATION_MARK = "@MainActor""#,
            #"""
            隔离判定本身。⚠️ 两个方向都会红，**没有静默失效的方向**：改成匹配不上的串
            ⇒ 命中恒为空集，空集与豁免表不等 ⇒ 红；改成恒真的空串 ⇒ 本轮实测
            **exit 1，把 74 条 unregistered 全报出来**——恒真是最吵的失效形态，不是最危险的
            （这句原来写反了）。钉它是为了钉住「判的是 `@MainActor` 这件事」本身
            """#
        ),
        (
            "unregistered = sorted(actual - expected)",
            "差集的**一半**：新增的 MainActor static。删掉它 ⇒ 棘轮只剩「表里的条目还在不在」，对新增完全失明，而脚本照样 exit 0"
        ),
        (
            "stale = sorted(expected - actual)",
            "差集的**另一半**：表里已过期的条目。删掉它 ⇒ 表会慢慢变成一张没人核对过的旧账"
        ),
        (
            "empty = [t for t, n in population.items() if n == 0]",
            "防空转网：任一 target 候选面为 0 就判红。删掉它 ⇒ 一个把 kind 名字打错的 typo 会让整条判据永远绿"
        ),
        (
            "if not os.path.isfile(path):",
            "fail-closed：某个 target 的主 symbols 文件缺席时判红而不是「零命中 ⇒ 零违规」"
        ),
        (
            #"cross = os.path.join(symbolgraph_dir, "%s@%s.symbols.json" % (target, other))"#,
            #"""
            **包内跨 target** 的扩展块文件也要扫。删掉它 ⇒ `CoreDesignEffects` /
            `CoreDesignCharts` 往 `CoreDesign` 的公开类型（109 个里 62 个带 `@MainActor`）
            上加公开 static 时，成员落进 `<Target>@CoreDesign.symbols.json` 而无人看见。
            ⚠️ 这一族**今天零个文件** ⇒ 删掉它脚本照样 exit 0，正是本文件要接住的形态
            """#
        ),
        (
            "docs/mainactor-static-exemptions.txt",
            "脚本读的豁免表路径。改指别处 ⇒ 本文件钉的表与脚本比的表分了家"
        ),
    ]

    /// job 的**直接子键**上不许出现的键。
    ///
    /// ⚠️ **键名不带冒号**，比对走 `keyName(ofLine:)` 归一化后的**相等**，不是
    /// `hasPrefix("if:")`。原来那种写法被六种同义 YAML 拼法整个绕开
    /// （`"if": false` / `if : false` / `continue-on-error : true` /
    /// job 级 `"if": false` / `needs : simulator` …，PR #314 终审逐条实测判绿）。
    nonisolated static let blockedJobKeys: [(key: String, reason: String)] = [
        ("if", "这个 job 可能在某些事件上压根不跑"),
        ("needs", "上游 job 被跳过时这个 job 会跟着不跑（`bool-ratchet` 就带着 `if:`）"),
        ("continue-on-error", "这道闸判红也不会让 job 判红"),
    ]

    /// **含那条 `run:` 的那个 step** 的直接子键**允许清单**（正面清单，fail-closed）。
    ///
    /// ⚠️ 这里与 `expectedRunCommand` 是**同一条纪律**：中和这一步的拼法按负面清单
    /// 追不完，所以改成「清单外的键一律判红」。代价如实登记：这一步将来确实需要
    /// `id:` / `timeout-minutes:` 之类合法键时会**假红**，处置是把它加进本清单并
    /// 说明理由——那是一次有人看见的破例，正是想要的形态。
    ///
    /// ⚠️ 只查**这一个 step**：同 job 的「Upload test logs」step 带着 `if: always()`，
    /// 那是合法且必要的。
    nonisolated static let allowedStepKeys: Set<String> = [
        "name", "run", "env", "working-directory", "uses", "with",
    ]

    /// 清单外的键里，这几个是**已知的中和闸门**——命中时在报错里额外附上原因。
    ///
    /// ⚠️ 这是**报错文案**，不是判定依据：判定只看 `allowedStepKeys`。
    /// 往这里补一条不会让判据更严，删掉一条也不会让它更松。
    nonisolated static let stepKeyDangerNotes: [String: String] = [
        "if": "这一步可能压根不跑",
        "continue-on-error": "这一步判红也不会让 job 判红",
        "shell": "覆写掉默认的 `bash -e -o pipefail`，失败可能不再传导到 step 退出码",
    ]

    // MARK: - 路径

    nonisolated static var workflowURL: URL {
        GuardScanRoots.repoRoot.appendingPathComponent(".github/workflows/ci.yml")
    }

    nonisolated static var scriptURL: URL {
        GuardScanRoots.repoRoot.appendingPathComponent(Self.scriptRelativePath)
    }

    nonisolated static var exemptionsURL: URL {
        GuardScanRoots.repoRoot.appendingPathComponent(Self.exemptionsRelativePath)
    }

    // MARK: - 纯函数（合成输入可直接喂，AD-E 要求每条断言都有能触发红的 fixture）

    nonisolated static func indentation(of line: String) -> Int {
        line.prefix { $0 == " " }.count
    }

    nonisolated static func isSkippable(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty || trimmed.hasPrefix("#")
    }

    /// 豁免表文本 → 条目集合（`#` 注释与空行忽略）。
    ///
    /// ⚠️ 与脚本侧的解析规则**接近但不等价**，异同逐条登记（PR #314 终审实测，
    /// 原来那句「与脚本侧的解析规则一致」是假的）：
    ///
    /// · **CRLF**：曾经分叉，且比 PR #314 终审报的更糟——终审说「Swift 的 `.whitespaces`
    ///   不含 `\r`」，本轮实测发现 **`split` 根本就没切开**：Swift 里 `"\r\n"` 是**一个
    ///   Character**（grapheme cluster），`split(separator: "\n")` 一次都匹配不上
    ///   ⇒ 整张 CRLF 表被当成**一行**，而那一行以 `#` 起头 ⇒ 条目集合为**空**
    ///   ⇒ 「豁免表一条都没有」那条断言假红。已修：改按 `Character.isNewline` 切
    ///   （`\r\n` 是 newline ⇒ 正确切开），并保留 `.whitespacesAndNewlines` 兜住裸 `\r`。
    /// · **BOM**：曾经反向分叉（Foundation 吞掉 BOM ⇒ 树内绿；Python 的 `utf-8`
    ///   不吞 ⇒ 首行不再以 `#` 起头 ⇒ 脚本红）。已修：脚本改用 `utf-8-sig`。
    /// · **重复行**：**有意保留不同**——脚本把 `expected` 收成 `set`，重复行被静默
    ///   折叠；本文件在 `exemptionTableMatchesRegisteredTable` 里当场判红。
    ///   这是**分工**不是分歧：脚本管「表 ↔ symbol graph」，本文件管「表本身的形态」。
    nonisolated static func exemptionEntries(inTable text: String) -> [String] {
        text.split(omittingEmptySubsequences: false, whereSeparator: { $0.isNewline })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
    }

    /// 一行 YAML → 它的**键名**：按第一个 `:` 切、剥掉包裹的引号、去掉两侧空白。
    /// 行里没有 `:` ⇒ 不是键，返回 `nil`。
    ///
    /// ⚠️ 这一步是那六种逃逸拼法的解药：`"if": false` / `'if': false` / `if : false`
    /// 归一化之后都是 `if`，与被拦的写法**相等**。
    nonisolated static func keyName(ofLine line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let colon = trimmed.firstIndex(of: ":") else { return nil }
        var key = String(trimmed[trimmed.startIndex..<colon])
            .trimmingCharacters(in: .whitespaces)
        for quote in ["\"", "'"]
        where key.count >= 2 && key.hasPrefix(quote) && key.hasSuffix(quote) {
            key = String(key.dropFirst().dropLast())
        }
        return key.trimmingCharacters(in: .whitespaces)
    }

    /// 一行 `键: 值` 里**冒号右边**那一段（去掉两侧空白）。行里没有 `:` ⇒ `nil`。
    ///
    /// ⚠️ 用来钉「那条 `run:` 是**行内标量**」：块标量的 `run: |` 在这里取到的值是
    /// `"|"`，与 `expectedRunCommand` 不等 ⇒ 判红。
    nonisolated static func valuePart(ofLine line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let colon = trimmed.firstIndex(of: ":") else { return nil }
        return String(trimmed[trimmed.index(after: colon)...])
            .trimmingCharacters(in: .whitespaces)
    }

    /// 把一个 job 块切成一串 step 块（每块含 `- ` 那一行与它底下更深缩进的行）。
    ///
    /// ⚠️ 注释行**并入所属 step**（与 `jobBlock` 的边界规则一致），因此 step 里的
    /// 键查找必须自己跳过注释——本文件那段 `ci.yml` 注释里就逐字写着 `if:` 和
    /// `continue-on-error:`，不跳会假红。
    nonisolated static func stepBlocks(inJobBlock block: String) -> [String] {
        let lines = block.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let stepsIndex = lines.firstIndex(where: {
            $0.trimmingCharacters(in: .whitespaces) == "steps:"
        }) else { return [] }
        let stepsIndent = Self.indentation(of: lines[stepsIndex])

        var items: [[String]] = []
        var itemIndent: Int?
        var cursor = stepsIndex + 1
        while cursor < lines.count {
            let line = lines[cursor]
            if !Self.isSkippable(line) {
                let indent = Self.indentation(of: line)
                if indent <= stepsIndent { break } // 离开 `steps:` 这一节
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("- "), itemIndent == nil || indent == itemIndent {
                    itemIndent = indent
                    items.append([line])
                    cursor += 1
                    continue
                }
            }
            if !items.isEmpty { items[items.count - 1].append(line) }
            cursor += 1
        }
        return items.map { $0.joined(separator: "\n") }
    }

    /// 一个 step 块的**直接子键**（`- ` 那一行自带的键算第一个），逐个给出
    /// 「归一化后的键名（拿不到就是 `nil`）+ 原始文本」。
    ///
    /// ⚠️ 缩进按 YAML 的真规则算：`- ` 那个短横自己占一格缩进，因此直接子键的列
    /// = 短横的列 + 1 + 短横后面的空格数。**不写死 +2**——`-   name:` 也是合法 YAML。
    /// ⚠️ 只取**直接子键**，所以 `with:` 底下的子树、`run: |` 块标量的正文都不会
    /// 被当成 step 的键（它们缩得更深）。
    nonisolated static func directChildKeys(inStep step: String) -> [(key: String?, line: String)] {
        let lines = step.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let firstIndex = lines.firstIndex(where: { !Self.isSkippable($0) }) else { return [] }
        let first = lines[firstIndex]
        let dashIndent = Self.indentation(of: first)
        let afterIndent = first.dropFirst(dashIndent)
        guard afterIndent.hasPrefix("-") else { return [] }
        let gap = afterIndent.dropFirst().prefix { $0 == " " }.count
        let childIndent = dashIndent + 1 + gap

        let head = String(afterIndent.dropFirst(1 + gap))
        var out: [(key: String?, line: String)] = [(Self.keyName(ofLine: head), head)]
        for line in lines[(firstIndex + 1)...] where !Self.isSkippable(line) {
            guard Self.indentation(of: line) == childIndent else { continue }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            out.append((Self.keyName(ofLine: trimmed), trimmed))
        }
        return out
    }

    /// 一个 step 块里、**不在 `allowedStepKeys` 里**的直接子键（跳过注释行）。
    nonisolated static func disallowedStepKeys(inStep step: String) -> [String] {
        var hits: [String] = []
        for entry in Self.directChildKeys(inStep: step) {
            guard let key = entry.key else {
                hits.append(
                    """
                    直接子键那一层出现了一行不含 `:` 的内容：`\(entry.line)`
                    ——解析规则之外的形态，判红而不是当作零违规。
                    """
                )
                continue
            }
            if Self.allowedStepKeys.contains(key) { continue }
            let note = Self.stepKeyDangerNotes[key].map { "（\($0)）" } ?? ""
            hits.append(
                """
                不在允许清单里的直接子键 `\(key):`\(note)
                ⚠️ 这里是**正面清单**（`allowedStepKeys`），与 `expectedRunCommand` 同一条纪律：
                `if:` / `continue-on-error:` / `shell:` 的同义拼法（`"if": false` /
                `'if': false` / `if : false` …）按负面清单追不完。
                这一步确实需要一个新键时，把它加进 `allowedStepKeys` 并说明理由。
                """
            )
        }
        return hits
    }

    /// 那个 step 的 `run:` **必须是行内标量**，且值逐字等于 `expectedRunCommand`。
    ///
    /// ⚠️ 这一条不是「再比一遍命令」，它比的是**别的东西**：上面那条
    /// `expectedRunCommand` 比对走 `DownstreamProbeGateGuard.commandLines(inRunCommand:)`，
    /// 那个函数会把块标量拆成一行行再比，于是
    /// ```
    /// run: |
    ///   exit 0
    ///   bash scripts/mainactor-static-ratchet.sh
    /// ```
    /// **能整条走过去**（含 marker 的那一行逐字相等，`exit 0` 不含 marker 被滤掉）。
    /// 本条直接看 `run` 这个**键的值**：块标量下它是 `"|"`，与期望不等 ⇒ 判红。
    /// ⇒ 「要加兄弟行必须先改成块标量」这个前提，从此有东西钉着。
    nonisolated static func runLineIsInlineScalar(inStep step: String) -> [String] {
        let runValues = Self.directChildKeys(inStep: step)
            .filter { $0.key == "run" }
            .compactMap { Self.valuePart(ofLine: $0.line) }
        if runValues.isEmpty {
            return ["跑棘轮的那个 step 上找不到 `run:` 这个直接子键 —— 解析失效，判红而不是当作零违规"]
        }
        return runValues.filter { $0 != Self.expectedRunCommand }.map {
            """
            跑棘轮的那个 step 的 `run:` **不是行内标量**，或值不逐字等于期望命令：
            实际值：\($0)
            期望值：\(Self.expectedRunCommand)
            ⚠️ 值是 `|` / `>` 之类 ⇒ 那条 `run:` 被改成了**块标量**。块标量能在命令旁边
            塞兄弟行（`exit 0` / `trap 'exit 0' ERR`），而按行比对的那条判据抓不到。
            这一步的 `run:` 请保持单行；确实要改，先改 `expectedRunCommand` 并说明理由。
            """
        }
    }

    /// job 的**直接子键**里出现的、被禁的键。
    ///
    /// 直接子键 = 缩进等于 job 块内第一条非空非注释行的缩进。
    nonisolated static func blockedJobLevelKeys(inJobBlock block: String) -> [String] {
        let lines = block.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let first = lines.first(where: { !Self.isSkippable($0) }) else { return [] }
        let keyIndent = Self.indentation(of: first)
        var hits: [String] = []
        for line in lines where !Self.isSkippable(line) {
            guard Self.indentation(of: line) == keyIndent else { continue }
            guard let key = Self.keyName(ofLine: line) else { continue }
            for entry in Self.blockedJobKeys where key == entry.key {
                hits.append("`\(entry.key):`：\(entry.reason)")
            }
        }
        return hits
    }

    /// workflow 文本 → 违规清单（空 = 通过）。
    ///
    /// ⚠️ 归一化（反斜杠续行合并 / 剥引号 / 丢散文行 / 跳过 `with:` 子树）**复用**
    /// `DownstreamProbeGateGuard` 的那几个纯函数：那是**辅助**不是断言，没有
    /// 「两条判据实现独立」的价值可言（对照 `ColorGradeResolutionGuard` 头注释里
    /// 那份**有意保留**的 canary 重复——那边重复的是断言，这边复用的是解析器）。
    /// ⚠️ 代价一并登记：那几个函数将来因 `#290` 那条闸的理由被改时，本判据会跟着变。
    nonisolated static func violations(inWorkflow yaml: String) -> [String] {
        guard let block = DownstreamProbeGateGuard.jobBlock(inWorkflow: yaml, job: Self.jobName)
        else {
            return ["解析失效：workflow 里找不到 `jobs:` 下的 `\(Self.jobName):` 块"]
        }
        var problems: [String] = []

        let commands = DownstreamProbeGateGuard.runCommands(inJobBlock: block)
        let realLines = commands.flatMap { DownstreamProbeGateGuard.commandLines(inRunCommand: $0) }
        let candidates = realLines.filter { $0.contains(Self.scriptMarker) }

        if candidates.isEmpty {
            problems.append(
                """
                `\(Self.jobName)` job 里找不到跑 `\(Self.scriptMarker)` 的 `run:`。
                这一步是 `#307` 棘轮唯一真正执行判据的地方——没有它，
                `docs/mainactor-static-exemptions.txt` 只是一张没人核对的表。
                """
            )
        }
        for line in candidates where line != Self.expectedRunCommand {
            problems.append(
                """
                跑 `\(Self.scriptMarker)` 的那一行不是逐字的期望命令：
                实际：\(line)
                期望：\(Self.expectedRunCommand)
                ⚠️ 尾巴（` || true` / ` ; true` / ` | tee …`）会把脚本的非零退出码中和掉；
                合法后缀（`--verbose` 之类）同样判红——这是**正面清单**，按拼法追不完。
                要改写这一行，同时改 `expectedRunCommand`。
                """
            )
        }

        problems.append(contentsOf: Self.blockedJobLevelKeys(inJobBlock: block).map {
            "`\(Self.jobName)` job 的直接子键里出现 \($0)"
        })

        let steps = Self.stepBlocks(inJobBlock: block)
        let owning = steps.filter { $0.contains(Self.scriptMarker) }
        if candidates.isEmpty == false, owning.isEmpty {
            problems.append(
                """
                解析失效：命令行里找得到 `\(Self.scriptMarker)`，却切不出含它的 step 块
                ——`steps:` 的缩进形态变了。判据失去依据，判红而不是当作零违规。
                """
            )
        }
        for step in owning {
            problems.append(contentsOf: Self.disallowedStepKeys(inStep: step).map {
                "跑棘轮的那个 step 上出现 \($0)"
            })
            problems.append(contentsOf: Self.runLineIsInlineScalar(inStep: step))
        }
        return problems
    }

    /// 脚本文本 → 违规清单（空 = 通过）。
    nonisolated static func violations(inScript script: String) -> [String] {
        Self.requiredScriptLiterals
            .filter { !script.contains($0.literal) }
            .map {
                """
                脚本里找不到逐字片段：
                \($0.literal)
                这一条为什么必须在：\($0.reason)
                """
            }
    }

    // MARK: - 判据（全部**无条件**，没有任何 `.enabled(if:)`）

    @Test("豁免表与树内登记逐条相符（双向差集）")
    func exemptionTableMatchesRegisteredTable() throws {
        // ⚠️ 基数断言（同 `scriptPinsTheFilterPredicate` 那段的理由）：双向差集在
        // `registeredExemptions` 被清空时**不会**空转（表非空 ⇒ `extra` 非空 ⇒ 红），
        // 但「悄悄少一条 / 多一条」靠的是这个数被人看见。豁免表是**破例清单**，
        // 它的长度本身就是要 review 的东西。
        #expect(
            Self.registeredExemptions.count == 5,
            """
            `registeredExemptions` 的条数变了（期望 5，实际 \(Self.registeredExemptions.count)）。
            往豁免表里加一行是破例动作：默认处置是给那个成员加 `nonisolated`。
            确实修不掉才登记，并同轮改这个数。
            """
        )
        let text = try String(contentsOf: Self.exemptionsURL, encoding: .utf8)
        let entries = Self.exemptionEntries(inTable: text)

        // 一、防「拿重复行凑数」。
        #expect(
            entries.count == Set(entries).count,
            "豁免表里有重复行：\(entries.filter { entry in entries.filter { $0 == entry }.count > 1 })"
        )
        // 二、防「表被清空 ⇒ 脚本零命中零违规 ⇒ 绿」。
        #expect(
            !entries.isEmpty,
            "豁免表一条都没有——那不是「本包没有 MainActor 隔离的公开 static」，是表被清空了"
        )

        // 三、双向差集。
        let actual = Set(entries)
        let extra = actual.subtracting(Self.registeredExemptions).sorted()
        let missing = Self.registeredExemptions.subtracting(actual).sorted()
        #expect(
            extra.isEmpty,
            """
            豁免表里多出这些条目，而 `registeredExemptions` 没登记：\(extra)
            ⚠️ 往表里加一行是**破例动作**：默认处置是给那个成员（或它的 enclosing type）
            加 `nonisolated`。确实修不掉才登记，且必须同轮更新本文件的 `registeredExemptions`
            与表里那条「为什么修不掉」的说明。
            """
        )
        #expect(
            missing.isEmpty,
            """
            `registeredExemptions` 登记了这些条目，而豁免表里没有：\(missing)
            要么是修好了（那就把它从本文件也删掉），要么是表被人改瘦了。
            """
        )

        // 四、条目的 target 前缀必须是真的 library target。
        let known = Set(GuardScanRoots.targetNames)
        let strays = entries.filter { entry in
            guard let target = entry.split(separator: ":").first else { return true }
            return !known.contains(String(target))
        }
        #expect(
            strays.isEmpty,
            """
            这些豁免条目的 target 前缀不在 `GuardScanRoots.targetNames` 里：\(strays)
            脚本按 `<Target>.symbols.json` 逐 target 筛，前缀写错的条目**永远**匹配不上，
            会以「表里已过期」的形态一直红——那是假红，先修前缀。
            """
        )
    }

    @Test("脚本的筛条件与两半差集逐字在场")
    func scriptPinsTheFilterPredicate() throws {
        // ⚠️⚠️ **基数断言必须在这里**（PR #314 终审 A-2，实测两种变异）：
        // 唯一消费 `requiredScriptLiterals` 的循环是
        // `syntheticScriptMissingAnyLiteralIsRejected` 里的 `for entry in …`，
        // 数组一空 ⇒ 循环零次 ⇒ **空真**。加这条断言**之前**实测（当时本 suite 12 条判据）：
        //   · 删掉 `stale = sorted(expected - actual)` 那一条 pin 本身 ⇒ 12 条全绿 EXIT=0；
        //   · `requiredScriptLiterals = []`                        ⇒ 12 条全绿 EXIT=0。
        // 加上之后同样两个变异复测：分别报「实际 10」「实际 0」，双向判红。
        // 这与 `CLAUDE.md` 已经登记过的 `ColorGradeResolutionGuard` 那个形态
        // （`samples` 返回 `[]` ⇒ 两条分叉判据的循环一次都不进 ⇒ 双绿）是**同一个形状**，
        // 而本文件当时没有对应的网。基数是这一族里最直接的那道网。
        #expect(
            Self.requiredScriptLiterals.count == 11,
            """
            `requiredScriptLiterals` 的条数变了（期望 11，实际 \(Self.requiredScriptLiterals.count)）。
            少一条 ⇒ 那条筛条件从此可以被静默删掉；清空 ⇒ 整条 pin 空转（循环零次即空真）。
            确实要增删时，改这个数并在 PR 里说明增删的是哪一条、为什么。
            """
        )
        let script = try String(contentsOf: Self.scriptURL, encoding: .utf8)
        let problems = Self.violations(inScript: script)
        #expect(
            problems.isEmpty,
            "\(Self.scriptRelativePath) 的判据被改动了：\n\(problems.joined(separator: "\n\n"))"
        )
    }

    @Test("脚本存在且可执行")
    func scriptIsExecutable() {
        let path = Self.scriptURL.path
        #expect(
            FileManager.default.isExecutableFile(atPath: path),
            """
            \(Self.scriptRelativePath) 不存在或没有可执行位。
            ⚠️ `ci.yml` 那一步用 `bash <path>` 调它，缺可执行位在 CI 上**不会**红
            ——所以这条要在树内查。
            """
        )
    }

    @Test("ci.yml 的 swiftpm job 逐字跑棘轮，且这一步没被中和")
    func workflowRunsTheRatchet() throws {
        // ⚠️ 基数断言（同上）：这两张表被清空时，`blockedJobLevelKeys` 与
        // `disallowedStepKeys` 的循环会退化——前者零次迭代即零违规（空真），
        // 后者会变成「什么键都不许」（假红）。两侧都要靠这个数被人看见。
        #expect(
            Self.blockedJobKeys.count == 3,
            "`blockedJobKeys` 的条数变了（期望 3，实际 \(Self.blockedJobKeys.count)）——清空它 ⇒ job 级中和键全部放行"
        )
        #expect(
            Self.allowedStepKeys.count == 6,
            "`allowedStepKeys` 的条数变了（期望 6，实际 \(Self.allowedStepKeys.count)）——往里加键是放松判据，要有人看见"
        )
        let yaml = try String(contentsOf: Self.workflowURL, encoding: .utf8)
        let problems = Self.violations(inWorkflow: yaml)
        #expect(problems.isEmpty, "ci.yml 的棘轮闸出了问题：\n\(problems.joined(separator: "\n\n"))")
    }

    // MARK: - 合成输入（AD-E：每条断言都要有能触发红的 fixture）

    /// 一份最小 workflow，`run:` 那一行由参数给。
    ///
    /// ⚠️ 缩进逐行显式拼（不用多行字符串字面量）：本函数产出的东西要喂给一个**按缩进**
    /// 判 step 边界的解析器，缩进就是被测输入本身，不能交给字面量的缩进剥离规则去猜。
    /// 形态与真 `ci.yml` 一致：`jobs:` 0 / job 名 2 / job 子键 4 / step 的 `- ` 6 / step 子键 8。
    /// 末尾那个带 `if: always()` 的 upload step 是**正对照**：它证明「别的 step 上的 `if:`
    /// 不判红」这条有意的取舍确实成立（真 `ci.yml` 的 `swiftpm` job 就长这样）。
    nonisolated static func syntheticWorkflow(runLine: String, stepKeys: [String] = []) -> String {
        var lines = [
            "name: CI",
            "on:",
            "  push:",
            "jobs:",
            "  swiftpm:",
            "    name: SwiftPM",
            "    runs-on: macos-26",
            "    steps:",
            "      - uses: actions/checkout@v4",
            "      - name: Test",
            "        run: swift test",
            "      - name: MainActor static ratchet",
        ]
        lines.append(contentsOf: stepKeys.map { "        \($0)" })
        lines.append("        run: \(runLine)")
        lines.append(contentsOf: [
            "      - name: Upload test logs",
            "        if: always()",
            "        uses: actions/upload-artifact@v4",
        ])
        return lines.joined(separator: "\n")
    }

    @Test("合成输入：一步都没有 ⇒ 判红")
    func syntheticWorkflowWithoutTheStepIsRejected() {
        let yaml = Self.syntheticWorkflow(runLine: "swift build")
        #expect(!Self.violations(inWorkflow: yaml).isEmpty)
    }

    @Test("合成输入：命令长出 `|| true` 尾巴 ⇒ 判红")
    func syntheticWorkflowWithNeutralizedExitCodeIsRejected() {
        let yaml = Self.syntheticWorkflow(runLine: "\(Self.expectedRunCommand) || true")
        #expect(!Self.violations(inWorkflow: yaml).isEmpty)
    }

    @Test("合成输入：加个合法后缀也判红（正面清单，不是关键词匹配）")
    func syntheticWorkflowWithBenignSuffixIsRejected() {
        let yaml = Self.syntheticWorkflow(runLine: "\(Self.expectedRunCommand) --verbose")
        #expect(!Self.violations(inWorkflow: yaml).isEmpty)
    }

    @Test("合成输入：`echo` 冒充命令 ⇒ 判红")
    func syntheticWorkflowWithProseIsRejected() {
        let yaml = Self.syntheticWorkflow(runLine: "echo \"\(Self.expectedRunCommand)\"")
        #expect(!Self.violations(inWorkflow: yaml).isEmpty)
    }

    @Test("合成输入：这一步被加上 `if:` ⇒ 判红（同 job 别的 step 的 `if:` 不算）")
    func syntheticWorkflowWithStepConditionIsRejected() {
        let clean = Self.syntheticWorkflow(runLine: Self.expectedRunCommand)
        #expect(Self.violations(inWorkflow: clean).isEmpty, "正对照：干净的合成输入必须判绿")
        let dirty = Self.syntheticWorkflow(
            runLine: Self.expectedRunCommand,
            stepKeys: ["if: github.event_name == 'pull_request'"]
        )
        #expect(!Self.violations(inWorkflow: dirty).isEmpty)
    }

    @Test("合成输入：job 被加上 `if:` / `needs:` ⇒ 判红")
    func syntheticWorkflowWithJobLevelConditionIsRejected() {
        for key in ["if: false", "needs: bool-ratchet", "continue-on-error: true"] {
            let yaml = Self.syntheticWorkflow(runLine: Self.expectedRunCommand)
                .replacingOccurrences(of: "    runs-on: macos-26", with: "    \(key)\n    runs-on: macos-26")
            #expect(!Self.violations(inWorkflow: yaml).isEmpty, "job 级 `\(key)` 应判红")
        }
    }

    @Test("合成输入：`if:` / `needs:` / `continue-on-error:` 的同义 YAML 拼法一样判红")
    func syntheticWorkflowWithEquivalentKeySpellingsAreRejected() {
        // ⚠️ 这六种拼法在 PR #314 终审的实测里**全部判绿**（原实现按
        // `trimmed.hasPrefix("if:")` 比对，键名带冒号 ⇒ 任何合法等价写法都绕开），
        // 三种拼法经 YAML 解析器核过与被拦写法**逐字节同义**。
        // 现在 step 侧走 `allowedStepKeys` 正面清单、job 侧走 `keyName(ofLine:)` 归一化后相等。
        let clean = Self.syntheticWorkflow(runLine: Self.expectedRunCommand)
        #expect(Self.violations(inWorkflow: clean).isEmpty, "正对照：干净的合成输入必须判绿")

        for key in [#""if": false"#, "'if': false", "if : false", "continue-on-error : true"] {
            let yaml = Self.syntheticWorkflow(runLine: Self.expectedRunCommand, stepKeys: [key])
            #expect(!Self.violations(inWorkflow: yaml).isEmpty, "step 级 `\(key)` 应判红")
        }
        for key in [#""if": false"#, "needs : simulator"] {
            let yaml = clean.replacingOccurrences(
                of: "    runs-on: macos-26",
                with: "    \(key)\n    runs-on: macos-26"
            )
            #expect(!Self.violations(inWorkflow: yaml).isEmpty, "job 级 `\(key)` 应判红")
        }
    }

    @Test("合成输入：`run:` 改成块标量并加兄弟行 ⇒ 判红")
    func syntheticWorkflowWithBlockScalarRunIsRejected() {
        // ⚠️ 正对照很关键：这份合成输入的**含 marker 那一行逐字等于期望命令**，
        // 所以走 `commandLines(inRunCommand:)` 的那条判据对它是**绿**的
        // ——判红的只能是 `runLineIsInlineScalar`。
        let yaml = [
            "name: CI",
            "on:",
            "  push:",
            "jobs:",
            "  swiftpm:",
            "    name: SwiftPM",
            "    runs-on: macos-26",
            "    steps:",
            "      - name: MainActor static ratchet",
            "        run: |",
            "          exit 0",
            "          \(Self.expectedRunCommand)",
        ].joined(separator: "\n")
        #expect(!Self.violations(inWorkflow: yaml).isEmpty)
    }

    @Test("合成输入：job 整个不见了 ⇒ 判红（不是 fail-open）")
    func syntheticWorkflowWithoutJobIsRejected() {
        let yaml = """
        name: CI
        jobs:
          simulator:
            runs-on: macos-26
        """
        #expect(!Self.violations(inWorkflow: yaml).isEmpty)
    }

    @Test("合成输入：脚本少了任意一条筛条件字面量 ⇒ 判红")
    func syntheticScriptMissingAnyLiteralIsRejected() throws {
        let script = try String(contentsOf: Self.scriptURL, encoding: .utf8)
        #expect(Self.violations(inScript: script).isEmpty, "正对照：真脚本必须判绿")
        for entry in Self.requiredScriptLiterals {
            let mutated = script.replacingOccurrences(of: entry.literal, with: "")
            #expect(
                !Self.violations(inScript: mutated).isEmpty,
                "删掉 `\(entry.literal)` 之后判据仍绿——这一条是空转的"
            )
        }
    }
}
