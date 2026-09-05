import Foundation
import Testing

// MARK: - downstream-probe 那道 warnings-as-errors 闸的树内判据 / CI gate guard（PR #304 终审 F-4）
//
// ## 它守什么
//
// `.github/workflows/ci.yml` 的 `downstream-probe` job 里，构建 probe 的那条 `run:`
// 必须**逐字**带 `-Xswiftc -warnings-as-errors`；同 job 里必须还有一步跑
// `selftest-warnings-as-errors.sh`；而那个脚本里的两条构建命令必须逐字如
// `selftestBuildCommands` 所钉、带同一个标志。
//
// ## 为什么还要一条判据（「已经有 selftest 了」不够）
//
// ⚠️ `scripts/downstream-probe/selftest-warnings-as-errors.sh` **自己硬编码**这个标志
// （脚本内两处）⇒ 它证的是「**这条命令**会响」，**不是「CI 跑的是这条命令」**。
// 谁把 `ci.yml` 那步改回裸 `swift build`：probe 恢复容忍 warning，而 selftest 照样绿，
// `swift build` / `swift test` / iOS 腿 / bool-ratchet 也全绿 ⇒ **整道闸静默消失**。
//
// ⚠️⚠️ 这正是 `#290` 自己立的那条 AD-E 命题（「加了标志 ≠ 它真的会响」）在**上一层**
// 的复现：selftest 把命题从「标志有用吗」推到「这条命令会响吗」，本判据再推一层到
// 「CI 跑的是不是这条命令」。少了这一层，`EffectsNonisolatedUsage.swift` 与
// `FilterTransitionSupport.swift` 里那句「今天谁把 `nonisolated` 拿掉，probe 会判红」
// 会**再次变成假话**——`#291` 第 2 轮发现过同款事故（一句「常驻判据」的散文，
// 底下并没有判据）。
//
// ⚠️ 本仓先例是 `AppProjectManifestGuard`：同样用 `String(contentsOf:)` 读 manifest
// 做纯文本判据。而 `.github/workflows/ci.yml` **在本判据之前从未被任何判据读过**
// （`grep -rn "ci.yml" Tests/` 只在 `AppProjectManifestGuard.swift` 的散文注释里
// 出现一次）⇒ CI 配置本身一直是无人看守的一面。
//
// ## ⚠️⚠️ 本判据的病根与它的通用对策：`contains` 会被「含同样文本的散文」满足
//
// 本判据在 PR #304 的三轮终审里被**同一个成因**击穿了三次（第 3 轮 I-A / I-B / I-C）：
// 判据用 `contains` 找一段文本，而**注释 / `echo` 散文 / heredoc 正文 / 引号内的字符串**
// 里同样含那段文本 ⇒ 闸已死而判据全绿。逐个拼法打补丁是打不完的（第 2 轮堵了「块标量
// 里的 `#` 注释行」，第 3 轮就换成 `echo "…同一串…"` 绕过）。
//
// ⇒ 现在改成**先归一化出「真命令行」，再在真命令行上匹配**。归一化这一层是共用的：
//   1. **反斜杠续行合并**（`mergingLineContinuations`）——先把 `foo \` + 换行 + `bar`
//      并回一行，否则下面的「同一行」判定会把合法写法误杀。
//   2. **丢掉整行注释与空行**（`isSkippable`）。
//   3. **YAML 侧剥掉行内被引号包住的片段**（`strippingQuotedSegments`）——`echo "…"`
//      / `echo '…'` 里的整条命令连同引号一起消失。
//      ⚠️ **脚本侧不能这么做**：`output="$(cd "$PROBE_DIR" && swift build …)"` 的真命令
//      本身就活在引号里，剥掉就什么都不剩。脚本侧改用 heredoc 剥离 + `$PROBE_DIR`
//      共现 + 逐字钉住两条命令行（见 `flaggedBuildLines` / `selftestBuildCommands`）。
//   4. **丢掉散文命令行**（`proseLeadingWords`：`echo` / `printf` / `:` 打头）
//      ——挡住没加引号的 `echo ==> cd … && swift build …`。
//   5. **YAML 侧只认步骤自己的 `run:` 键**：`uses:` 步骤 `with:` 底下那个装饰性的
//      `run:` 输入不算命令（`runCommands` 里的 `withIndent`）。
//   6. **同一行**同时含 `probeBuildMarker` 与 `requiredFlag` 才算数——不再对整块
//      join 后的字符串做 `contains`（那等于「块里任何一行满足其一即可」）。
//
// ## 射程与已知缺口（不要读成比实际更强）
//
// ⚠️ 上一版这里把「job 被删 / workflow 文件被改名」写进了「它看不见」那一侧——
// **实测为假，照录更正**（PR #304 第 2 轮终审 I-2）：两者都判红，形态见下。
//
// **本轮在真实 `ci.yml` 与真实 selftest 脚本上逐条跑过 `swift test` 的变异：`ci.yml` 侧
// 22 种、脚本侧 5 种，全部判红**（原始输出见 PR #304 第 3 轮的验证块）。分组如下：
//
// **A. 闸本身不见了**
// · 标志被删 ⇒ `probe 构建命令缺少 -Xswiftc -warnings-as-errors：…`
// · 构建那条 `run:` 整个不见 ⇒ ``\`downstream-probe\` 里找不到含 …… 的 `run:` ``
// · selftest 那一步不见 ⇒ ``\`downstream-probe\` 里找不到跑 …… 的 `run:` ``
// · **job 被整块删掉** ⇒ `解析失效：workflow 里找不到 \`jobs:\` 下的 \`downstream-probe:\` 块`
//   （`jobBlock` 返回 `nil` 时**不**当作「零命中 ⇒ 零违规」）
// · **workflow 文件被改名 / 删除** ⇒ `String(contentsOf:)` 抛错，测试以
//   `Caught error: Error Domain=NSCocoaErrorDomain Code=260 …` 判红
//
// **B. 标志还在、但退出码被中和**（`expectedProbeBuildCommand` 与 `exitCodeNeutralizers`
// 两条各自独立地拦，任一被绕开另一条仍在）
// ⚠️ B 组拦的是「**那一行**长出尾巴」。**同一个 `run:` 块里的兄弟行**把这条命令架空
// ——不属于 B 组，也不属于下面的 C 组（C 组全是「这个 job 压根不跑」）——是**第 6 类**，
// **完全没堵**，登记在下面「它不保证」的第 3 条。
// · ` || true` / ` ||true`（**少一个空格**）/ `||` + 换行 + `true`（块标量软换行）
// · ` || :` / ` || exit 0` / ` ; true` / ` ;:` / 步骤里先 `set +e`
// · ` || echo skipped` —— `echo` 成功 ⇒ step 退出码 0；这一族**按拼法追不完**
//   （` || printf …` / ` || (exit 0)` / ` 2>/dev/null` / ` ||:` 只在合成 fixture 上覆盖），
//   靠的是「整条命令逐字相同」这条正面清单，不是再往正则表里加几条
//   ⚠️ **但那条正面清单只长在构建那一步**（`expectedProbeBuildCommand`）：**selftest 那步
//   没有**。把它改成 `scripts/downstream-probe/selftest-warnings-as-errors.sh || echo skipped`
//   （真实 `ci.yml`，本轮实测 `23 tests passed`）⇒ **闸外静默失效，已登记进 #307**
//   （PR #304 第 4 轮终审 R-7 ①）。**未修**：给它也配一条正面清单要先定 selftest 那步的
//   逐字文本，超出本轮范围。
// · 该 step 被加上 `continue-on-error: true` ⇒ `job 里出现 \`continue-on-error:\`…`
// · 该 step 被加上 `shell: bash {0}`（丢掉默认的 `-e -o pipefail`）⇒ `job 里出现 \`shell:\`…`
//
// **C. 这个 job 压根不跑**
// · job 被加上 `if:` ⇒ `job 里出现 \`if:\`…`（**step 级**的 `if:` 只在合成 fixture 上覆盖）
// · job 被加上 `needs: bool-ratchet` ⇒ `job 里出现 \`needs:\`…`
//
// **D. 散文冒充命令**（第 3 轮 I-A 那一族）
// · 块标量里 `echo "<整条命令>"` 满足 marker + flag、真命令裸 `swift build`
// · 两步都换成 `run: echo '<整条命令>'`，一条真命令都没有
// · 两步都换成 `uses:` + `with:` 底下装饰性的 `run:` 键
// · 留一条逐字的**诱饵** `run:`、把真正的构建改回裸 `swift build`
//   （逐条检查每个含 marker 的命令行，诱饵挡不住）
//
// **E. selftest 脚本侧**（第 3 轮 I-B 那一族，全部在**真实脚本 + 真实 `swift test`** 上跑）
// · `:76` 去标志 + 一条 `echo` 含整串（上一版判据在这份输入上实测 `9 tests passed`）
// · 两条真命令都去标志 + 两条 `echo` 含整串
// · heredoc 正文里出现两次整串、真命令裸 `swift build`
// · 整个脚本换成只 `echo` 两次整串的 no-op
// · 行尾注释藏标志（`(cd "$PROBE_DIR" && swift build) # swift build -Xswiftc …`）
//   —— 逐层筛拦不住，靠 `selftestBuildCommands` 的**逐字比对**兜住
//
// **正对照（期望仍判绿，本轮实测确为绿，防止上面的收紧变成假红）**
// · `ci.yml` 那条命令改成 shell 反斜杠续行 + 下一行接标志 ⇒ `19 tests passed`
// · 脚本 `:62` 那条 `echo "FAIL: …"` 被「补全」成含整条命令 ⇒ `19 tests passed`
//
// ⚠️ B/C/D 组不是理论洁癖：**标志在场 ≠ 失败会传导到 job 结论**。只查标志时，
// 这些改法都让判据全绿而闸已死——与「改回裸 `swift build`」等效，只是更隐蔽。
//
// ⚠️ 它**不**保证：
// · **CI 真的跑了这个 job** —— 本轮把 `if:` 与 `needs:` 两种堵上了，但这一类
//   **空间是开放的**，下面只是**本次登记到的 5 种**，不是穷举：
//   ① `if:`（job 或 step 上）——**已堵**；
//   ② `needs:` 指向一个可被跳过的 job——**已堵**（不是理论形态：同一份 `ci.yml` 里
//      `bool-ratchet` 就带着 `if: github.event_name == 'pull_request'`，`needs: bool-ratchet`
//      会让本 job 在**每一次 push 事件**上被跳过，而本判据在补上这条之前全绿）；
//   ③ workflow 级 `on:` 触发面收窄（`on.push.branches` 改成不存在的分支、删掉
//      `pull_request`、只留 `workflow_dispatch`）——**仍敞着**，本判据只读 job 块；
//   ④ workflow 级 / job 级 `paths:` / `paths-ignore:`（`paths-ignore: ['**']`）——**仍敞着**；
//   ⑤ `runs-on:` 指向一个不存在的 runner label——**仍敞着**。
//   ③④⑤ 三种本轮**在真实 `ci.yml` 上各跑了一次 `swift test`，都是 `19 tests passed`**
//   ⇒ 确为缺口，不是推测（PR #304 第 3 轮终审 C-2）。
// · **别的中和退出码的写法 / 那条命令根本没被执行**（**第 6 类**：job 跑了、step 跑了、
//   **那条命令没跑**——上面 C 组登记的 5 种全是「这个 job 压根不跑」，与这一类不同）。
//   现在有两道：`expectedProbeBuildCommand`（构建那条命令**整条逐字**，任何尾巴判红）
//   与 `exitCodeNeutralizers`（6 条正则，覆盖**别的** step）加 `continue-on-error:` /
//   `shell:` 两个键。
//   ⚠️ 但正面清单锁的是**那一行**；**同一个 `run:` 块里的兄弟行**与**别的 step** 一样
//   **完全不设防**。本轮（PR #304 第 4 轮终审 C-2'）在**真实 `ci.yml`** 上只改构建那步的
//   `run:`（**逐字命令原样保留**、缩进不变），下面 6 种各跑一次 `swift test`，**全绿**
//   （测时套件是 19 条；本轮补完四条新 fixture 后复测 ① 与 ③ 仍是 `23 tests passed`）：
//     ① `exit 0` ⏎ `<逐字命令>`
//     ② `if false; then` ⏎ `  <逐字命令>` ⏎ `fi`
//     ③ `trap 'exit 0' ERR` ⏎ `<逐字命令>`
//     ④ `swift() { exit 0; }` ⏎ `<逐字命令>`（函数覆写，命令跑了但什么也没构建）
//     ⑤ `eval "exit 0"` ⏎ `<逐字命令>`
//     ⑥ `cat <<'EOF' > /dev/null` ⏎ `<逐字命令>` ⏎ `EOF` ⏎ `exit 0`（heredoc 诱饵）
//   同族还有：把命令包进一个自己吞错的脚本（`run: ./ci-build.sh`，脚本里
//   `swift build …; exit 0`）、在**别的 step** 里 `trap 'exit 0' ERR`、`|| { echo …; }`。
//   **空间开放**，上面 6 种只是本轮实测到的、不是穷举。
//   ⚠️ 反讽处：本判据在**脚本侧**专门做了 heredoc 剥离（`strippingHeredocBodies`）堵这一族，
//   **YAML 侧却没有**。
//   ⚠️ **有意只登记、不加正则**（PR #304 第 4 轮终审明确不建议）：给 `^exit 0` /
//   `trap .*ERR` / `if false` 各加一条正则，正是本 PR 自己否定的「按拼法打补丁」路线
//   ——那张表追不上兄弟行的空间。**登记比加正则诚实。**
// · **judge 只读 `ci.yml` 这一个文件** —— 把 `downstream-probe` job 整体搬到另一个
//   workflow 文件（合法重构）会让 `jobBlock` 返回 `nil` ⇒ 以「解析失效」判红。
//   方向是 fail-closed，但那是一条**假红**，与 `probeBuildMarker` 逐字匹配的代价同类。
//   要搬，同时改 `workflowURL`。
// · **selftest 脚本自己的断言逻辑无人看守**（`#290` 那条「谁看着看门人」链条的下一环）：
//   本判据钉的是「脚本里那两条**构建命令**逐字如常量」，**不看脚本怎么判成败**。本轮在
//   真实脚本上各跑一次 `swift test`，两种都 `23 tests passed`（PR #304 第 4 轮终审 R-7 ②③）：
//   ① 把 `:63` 的 `exit 1`（步骤 1 期望判红却拿到 0 时的那条）改成 `exit 0` ⇒ 脚本永远成功；
//   ② 在 `set -euo pipefail` 之后加一行 `trap "exit 0" ERR` ⇒ 任何失败都被吞掉。
//   **已知缺口，未修**。⚠️ `#307` 落地后**它仍然未修**：那一轮加的
//   `MainActorStaticRatchetGuard` 也只钉自己那个脚本的**筛条件字面量**，同样不看脚本
//   怎么判成败（把 python 段整段换成 `sys.exit(0)`、或加 `trap "exit 0" ERR`，
//   那条判据照绿）——「谁看着看门人」这条链条在两处各断在同一环。
// · probe 里某个 `nonisolated func` 被整个删掉会判红 ——
//   `readTransitionPropertiesHasMotion()` / `useSettingsRowMetrics()` 删掉，
//   没有任何判据会红（`scripts/api-surface-diff.sh` 的头注释自己就写了
//   「它引用的符号是**手写清单**」；而 `api-surface-diff.sh` 比的是 `CoreDesign`
//   模块的 digester dump，**根本不读 probe**）。**已知缺口**，不在本判据射程。
//   ⚠️ 附带状态（PR #304 第 3 轮终审 S-iv，**#307 已部分处置，照录更新**）：
//   `consumeSettingsRowMetrics()` 删除后，`SettingsRowMetrics` 在整个 probe 里
//   **只剩 `useSettingsRowMetrics()` 一个 pin**，而删掉它不会有任何判据红
//   ⇒ 当时是「单点 + 无守卫」。
//   ⚠️ **「无守卫」这一半已经不成立了**：`#307` 的 `MainActorStaticRatchetGuard` +
//   `scripts/mainactor-static-ratchet.sh` 直接从 symbol graph 判定
//   `SettingsRowMetrics` 那 6 个公开 static 的隔离——`enum SettingsRowMetrics` 上那个
//   `nonisolated` 被拿掉，6 个成员会在 symbol graph 里长出 `@MainActor`，与豁免表的
//   双向差集当场红（本轮在 `CoreDesignCharts.moduleName` 上做过同形态的变异实证）。
//   ⇒ **删 `useSettingsRowMetrics()` 不再意味着这条隔离契约失守**。
//   ⚠️ 但「单点」这一半**仍然成立、仍未修**：删掉那个 `nonisolated func` 之后，probe
//   就完全不引用 `SettingsRowMetrics` 了，**「它还是不是 public」这件事没有任何判据钉住**
//   （棘轮只问隔离，不问可见性；`api-surface-diff.sh` 的清单是手写的）。
// · 新增的公开 `static` 成员会被 probe 引用 —— **#307 已处置这一条，照录更新**：
//   完整性不再依赖 `#290` 的一次性人工枚举。`scripts/mainactor-static-ratchet.sh`
//   从 `swift package dump-symbol-graph` 取编译器算出来的隔离，与
//   `docs/mainactor-static-exemptions.txt` 做双向差集，由 `ci.yml` 的 `swiftpm` job
//   一步执行、由 `Tests/CoreDesignTests/MainActorStaticRatchetGuard.swift` 树内看守。
//   ⚠️ **它只覆盖各 target 的主 symbols 文件**：写在 `extension <外来类型>`
//   （`extension Color` / `extension Transition` / `extension ButtonStyle` …）里的
//   新公开 static 成员**仍然是盲区**——那是 `#307` 定案时明确买单的代价，
//   逐字理由见那个脚本的《范围定案与代价》一节。
//
// ⚠️ 判据**只解析文本、不跑 CI**——因此它和 `AppProjectManifestGuard` 一样，
// 是那类「CI 里唯一看得见自己」的判据：它随 `swift test` 在**每个事件**上跑。
@Suite("#290 downstream-probe 的 warnings-as-errors 闸不得被静默拆掉")
struct DownstreamProbeGateGuard {

    /// 被守的 job 名（`ci.yml` 的 `jobs:` 下那一条）。
    nonisolated static let jobName = "downstream-probe"

    /// 被守的标志——**逐字**，包含中间那个空格。
    nonisolated static let requiredFlag = "-Xswiftc -warnings-as-errors"

    /// probe 构建那条 `run:` 的识别特征（不含标志本身）。
    ///
    /// ⚠️ **它是整串逐字匹配，不是「`cd` 到那个目录并 `swift build`」的语义匹配**
    /// （PR #304 第 2 轮终审 S-2）。把那条 `run:` 改写成语义等价但**字面不同**的形态
    /// ——例如块标量里 `cd scripts/downstream-probe` 与 `swift build …` 分成两行、
    /// 或用折叠标量 `>-` 让这一串跨了折行——本判据会报
    /// 「找不到含 `\(probeBuildMarker)` 的 `run:`」而**判红**。
    /// 方向是 fail-closed（不会假绿），但重构的人会撞上一条**看起来像 bug 的红**：
    /// 那不是 bug，是本常量的已知代价。要改写那条 `run:`，同时改这里。
    /// （唯一被特意放行的等价写法是 **shell 反斜杠续行**：归一化第 1 步会先并回一行。）
    nonisolated static let probeBuildMarker = "cd scripts/downstream-probe && swift build"

    /// probe 构建那条 `run:` 的**整条**逐字文本。
    ///
    /// ⚠️ 这一条是本轮自查（PR #304 第 3 轮，「自己再找 3 种新拼法」）的产物：
    /// `exitCodeNeutralizers` 那张表是**按拼法**登记的，于是
    /// `… -warnings-as-errors || echo skipped`（`echo` 成功 ⇒ step 退出码 0）实测**全绿**
    /// ——再往下还有 `|| printf x`、`|| touch /tmp/x`、`|| (exit 0)` …… 这条尾巴的空间是
    /// **无限**的，逐个拼法打补丁打不完（那正是本文件头「病根」那一段说的病）。
    /// ⇒ 改成**正面清单**：probe 构建那条命令行必须**逐字等于**本常量，尾巴一律判红。
    /// `exitCodeNeutralizers` 保留，因为它还覆盖**别的** step（`set +e` 就长在别处）。
    ///
    /// ⚠️ 代价与 `probeBuildMarker` 同类且更紧：给这条命令加任何合法后缀
    /// （`--verbose`、`2>&1 | tee build.log`、`-c release`）都会判红。要改，同时改这里。
    nonisolated static var expectedProbeBuildCommand: String {
        "\(Self.probeBuildMarker) \(Self.requiredFlag)"
    }

    /// selftest 那一步的识别特征。
    nonisolated static let selftestMarker = "selftest-warnings-as-errors.sh"

    /// `selftest-warnings-as-errors.sh` 里**真实**跑构建的两条命令，**逐字**。
    ///
    /// ⚠️ 逐字钉住而不是「含某个子串」，理由见文件头那段病根说明：脚本侧不能剥引号
    /// （真命令自己就活在引号里），于是只剩「把这两行本身钉死」这一条既简单又不会被
    /// 散文满足的判法。代价与 `probeBuildMarker` 同类：**合法改写这两行会判红**
    /// （双空格 `swift  build`、`swift build -c debug -Xswiftc …` 中间插旗、
    /// `swift build $FLAGS`、反斜杠续行、**把脚本里的 `PROBE_DIR` 变量改名**）。
    /// 要改，同时改这里。
    ///
    /// ⚠️ **变量改名这一种的失效形态会认错人**（PR #304 第 4 轮终审 R-5，本轮登记）：
    /// 把脚本里的 `PROBE_DIR` 全局改名成 `PROBE_ROOT`（纯合法重构）会让
    /// `flaggedBuildLines` 的**第 4 层筛**（`$PROBE_DIR` 同行共现）一条都留不下，于是
    /// 第一条文案是「带 `-Xswiftc -warnings-as-errors` 的**真实**构建命令有 0 条，而不是
    /// 预期的 2 条：（一条都没有）」——**读起来像「标志被删了」**，实际标志一个没少。
    /// 正确指引在第二条（逐字集合比对）里。计数那条文案已就此补了一句提示。
    nonisolated static let selftestBuildCommands = [
        #"output="$(cd "$PROBE_DIR" && swift build -Xswiftc -warnings-as-errors 2>&1)""#,
        #"(cd "$PROBE_DIR" && swift build -Xswiftc -warnings-as-errors)"#,
    ]

    /// `selftest-warnings-as-errors.sh` 里**真实**跑构建的命令条数（步骤 1 判红、步骤 3 判绿）。
    ///
    /// ⚠️ **上一版这里写「这个数字是判据的关键，而且必须是 `==` 而不是 `>=`」——已过时，
    /// 照录更正**（PR #304 第 4 轮终审 R-3）：把这条断言改回 `>=`（变异 G15）之后套件全绿
    /// ——本轮补完四条新 fixture 之后**再跑一次仍是 `23 tests passed`**
    /// ⇒ 它本身没有 fixture 覆盖，不是关键。
    /// 第 3 轮那条 `>=` 会被灌水满足的论证仍然成立（把一条真命令的标志删掉、再加一行含整条
    /// 命令的 `echo`，计数照样是 2），只是**真正解决灌水的是第 3 轮同时加的那条逐字集合比对**
    /// （`Set(flagged) == Set(selftestBuildCommands)`，见 `violations(inScript:)`）。
    /// ⇒ `==` 保留为**冗余的一道**（成本为零、方向 fail-closed），不要再把它读成主承重件。
    nonisolated static var selftestBuildCommandCount: Int { Self.selftestBuildCommands.count }

    /// 「这一行是散文 / 空操作而不是真命令」的首词表。
    ///
    /// ⚠️ **有意不含 `true`**：`||` 之后软换行再 `true` 时，那个 `true` 单独成一行，
    /// 把它当散文丢掉会让 `exitCodeNeutralizers` 的 `\|\|\s*true` 跨行匹配失效
    /// （本次自查发现的一条自伤，fixture 见 `syntheticNeutralizerSpellingsAreRejected`）。
    nonisolated static let proseLeadingWords: Set<String> = ["echo", "printf", ":"]

    /// 中和退出码的写法——**正则**，不是逐字子串（PR #304 第 3 轮终审 I-C）。
    ///
    /// ⚠️ 上一版写的是 `command.contains("|| true")`，**逐字带一个空格**：真实 `ci.yml`
    /// 上追加 ` ||true`（少一个空格）实测**全绿**，`||` + 换行 + `true`（块标量软换行，
    /// bash 语义等价）同样全绿。⇒ 改成 `\|\|\s*…`，顺带把判据头当时登记为「已知缺口」
    /// 的 `|| :` / `|| exit 0` 与 `; true` / `; :` / `set +e` 一并纳入（成本几乎为零）。
    nonisolated static let exitCodeNeutralizers: [(pattern: String, label: String)] = [
        (#"\|\|\s*true(?![\w-])"#, "|| true"),
        (#"\|\|\s*:(?![\w-])"#, "|| :"),
        (#"\|\|\s*exit\s+0(?![\w-])"#, "|| exit 0"),
        (#";\s*true(?![\w-])"#, "; true"),
        (#";\s*:(?![\w-])"#, "; :"),
        (#"(?:^|[\s;&|])set\s+\+e"#, "set +e"),
    ]

    /// job 块里一出现就判红的键：要么让这个 job 压根不跑，要么让它红了也不算数。
    ///
    /// ⚠️ `shell:` 是本轮自查找到的第二种新拼法：GitHub Actions 的 bash 默认是
    /// `bash --noprofile --norc -e -o pipefail {0}`，覆写成 `shell: bash {0}` 就丢掉
    /// `-e` 与 `-o pipefail` ⇒ 块标量里前一条命令失败不再中断、管道里的失败也不再传导，
    /// 而标志仍然逐字躺在那条 `run:` 里。本 job 没有覆写 shell 的正当需求 ⇒ 直接堵。
    nonisolated static let blockedJobKeys: [(key: String, reason: String)] = [
        ("if:", "这个 job / step 可能在某些事件上压根不跑"),
        ("needs:", "上游 job 被跳过时这个 job 会跟着不跑（`bool-ratchet` 就带着 `if:`）"),
        ("continue-on-error:", "这道闸判红也不会让 job 判红"),
        ("shell:", "覆写掉默认的 `bash -e -o pipefail`，失败可能不再传导到 step 退出码"),
    ]

    nonisolated static var workflowURL: URL {
        GuardScanRoots.repoRoot.appendingPathComponent(".github/workflows/ci.yml")
    }

    nonisolated static var selftestURL: URL {
        GuardScanRoots.repoRoot
            .appendingPathComponent("scripts/downstream-probe/selftest-warnings-as-errors.sh")
    }

    // MARK: - 归一化（共用；理由见文件头「病根与通用对策」）

    nonisolated private static func indentation(of line: String) -> Int {
        line.prefix { $0 == " " }.count
    }

    nonisolated private static func isSkippable(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty || trimmed.hasPrefix("#")
    }

    /// 归一化第 1 步：把 shell 反斜杠续行并回一行。
    nonisolated static func mergingLineContinuations(_ text: String) -> String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var merged: [String] = []
        var index = 0
        while index < lines.count {
            var current = lines[index]
            while current.hasSuffix("\\"), index + 1 < lines.count {
                let head = String(current.dropLast()).trimmingCharacters(in: .whitespaces)
                let tail = lines[index + 1].trimmingCharacters(in: .whitespaces)
                current = tail.isEmpty ? head : "\(head) \(tail)"
                index += 1
            }
            merged.append(current)
            index += 1
        }
        return merged.joined(separator: "\n")
    }

    /// 归一化第 3 步：剥掉一行里被单/双引号包住的片段（连引号一起）。
    ///
    /// ⚠️ **只用于 YAML 侧**。脚本侧的真命令自己就活在 `"$(…)"` 里，剥了就没了。
    ///
    /// ⚠️ **它会造成两种假红，且文案回显的是「剥引号后的串」——在 `ci.yml` 里 grep 不到。
    /// 撞上时先看这一段，别急着去搜那串**（PR #304 第 4 轮终审 R-6）：
    /// · YAML 侧给标志加引号（`swift build -Xswiftc "-warnings-as-errors"`，bash 语义等价）
    ///   ⇒ 剥完只剩 `cd scripts/downstream-probe && swift build -Xswiftc`，判据说**缺少标志**，
    ///   而文件里标志明明在。
    /// · 那条 `run:` 带了含**单撇号**的行尾注释（`… # don't drop this`）⇒ 未配对的 `'`
    ///   把从它开始到**本行末尾**的内容一起吞掉，回显同样是个文件里搜不到的残串。
    /// ⚠️ **好消息：剥引号是逐行做的**（`commandLines` 先按 `\n` 切再逐行剥），未配对引号
    /// **只吞到本行末尾、不跨行污染**；而正面清单要求剥完之后**逐字全等**
    /// ⇒ 引号**不会造成假绿**，只会造成假红。方向 fail-closed，是本轮设计有意的取舍。
    nonisolated static func strippingQuotedSegments(_ line: String) -> String {
        var out = ""
        var open: Character?
        for character in line {
            if let quote = open {
                if character == quote { open = nil }
                continue
            }
            if character == "\"" || character == "'" {
                open = character
                continue
            }
            out.append(character)
        }
        return out
    }

    /// 归一化第 4 步：`echo` / `printf` / `:` 打头的行是散文 / 空操作，不是命令。
    nonisolated static func isProseLine(_ line: String) -> Bool {
        guard let first = line.split(separator: " ").first else { return true }
        return Self.proseLeadingWords.contains(String(first))
    }

    /// 一条 `run:` 里**看起来像真命令**的行（已过完归一化 1/2/3/4 步）。
    nonisolated static func commandLines(inRunCommand command: String) -> [String] {
        Self.mergingLineContinuations(command)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { !Self.isSkippable($0) }
            .map { Self.strippingQuotedSegments($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !Self.isProseLine($0) }
    }

    /// 从 workflow 文本里切出 `jobs:` → `<job>:` 那一块（不含 job 行本身）。
    ///
    /// ⚠️ 返回 `nil` 表示**没找到那个 job**，调用方必须当解析失效处理，
    /// 而不是「零命中 ⇒ 零违规 ⇒ 绿」——那是 fail-open，正是本判据要防的形态。
    /// 块的终点是「第一条缩进 ≤ job 行缩进的非空非注释行」；空行与注释行并入块内。
    nonisolated static func jobBlock(inWorkflow yaml: String, job: String) -> String? {
        let lines = yaml.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let jobsIndex = lines.firstIndex(where: {
            $0.trimmingCharacters(in: .whitespaces) == "jobs:" && Self.indentation(of: $0) == 0
        }) else { return nil }

        var start: Int?
        var jobIndent = 0
        var cursor = jobsIndex + 1
        while cursor < lines.count {
            let line = lines[cursor]
            if Self.isSkippable(line) { cursor += 1; continue }
            let indent = Self.indentation(of: line)
            if indent == 0 { break } // 离开 `jobs:` 这一节
            if line.trimmingCharacters(in: .whitespaces) == "\(job):" {
                start = cursor + 1
                jobIndent = indent
                break
            }
            cursor += 1
        }
        guard let first = start else { return nil }

        var block: [String] = []
        var index = first
        while index < lines.count {
            let line = lines[index]
            if !Self.isSkippable(line), Self.indentation(of: line) <= jobIndent { break }
            block.append(line)
            index += 1
        }
        return block.joined(separator: "\n")
    }

    /// 取一个 job 块里的全部 `run:` 命令文本。
    ///
    /// 同时认两种写法：行内 `run: cmd`，与块标量 `run: |` +（更深缩进的）后续行。
    /// 块标量的多行会被拼成一条以 `\n` 相连的字符串。
    ///
    /// ⚠️ 块标量里的**空行与 `#` 注释行不进结果**：它们只参与判块边界（PR #304 第 2 轮
    /// 终审 I-2/S-1——上一版把它们拼进命令串，于是 `contains(requiredFlag)` 能被**注释里的
    /// 标志**满足）。⚠️⚠️ 但那只堵了 `#` 这一种拼法：第 3 轮实测 `echo "<整条命令>"`
    /// 照样满足闸。⇒ 真正的对策在调用方 `commandLines(inRunCommand:)`（剥引号 + 丢散文
    /// + **同一行**共现），本函数保持「原样取出」的职责。
    ///
    /// ⚠️ `uses:` 步骤 `with:` 底下的 `run:` **不是命令**，只是那个 action 的一个输入
    /// （归一化第 5 步）：`withIndent` 把整个 `with:` 子树跳过。
    nonisolated static func runCommands(inJobBlock block: String) -> [String] {
        let lines = block.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var commands: [String] = []
        var index = 0
        var withIndent: Int?
        while index < lines.count {
            let line = lines[index]
            if Self.isSkippable(line) { index += 1; continue }
            let indent = Self.indentation(of: line)
            if let open = withIndent {
                if indent > open { index += 1; continue }
                withIndent = nil
            }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "with:" || trimmed == "- with:" {
                withIndent = indent
                index += 1
                continue
            }
            let body: String?
            if trimmed.hasPrefix("run:") {
                body = String(trimmed.dropFirst("run:".count)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("- run:") {
                body = String(trimmed.dropFirst("- run:".count)).trimmingCharacters(in: .whitespaces)
            } else {
                body = nil
            }
            guard let scalar = body else { index += 1; continue }

            if scalar == "|" || scalar == ">" || scalar == "|-" || scalar == ">-" {
                let baseIndent = indent
                var collected: [String] = []
                var cursor = index + 1
                while cursor < lines.count {
                    let next = lines[cursor]
                    if !Self.isSkippable(next), Self.indentation(of: next) <= baseIndent { break }
                    if Self.isSkippable(next) { cursor += 1; continue }
                    collected.append(next.trimmingCharacters(in: .whitespaces))
                    cursor += 1
                }
                commands.append(collected.joined(separator: "\n"))
                index = cursor
            } else {
                commands.append(scalar)
                index += 1
            }
        }
        return commands
    }

    // MARK: - 脚本侧归一化

    /// 丢掉 heredoc 的**正文与结束标记行**（`<<'EOF'` … `EOF`）。
    ///
    /// ⚠️ 这是脚本侧「散文冒充命令」的第三种拼法：把两条整串塞进一个 `cat <<'X'` 正文里，
    /// 逐行判据会把它们当成真命令（PR #304 第 3 轮终审 I-B 的实测形态之一）。
    /// ⚠️ 已知代价：`<<` 后面跟一个标识符的模式也会命中形如 `a << b` 的移位/比较写法，
    /// 那会吞掉后续行直到出现一行恰为 `b`。本脚本里没有这种行；真出现时是**假红**。
    nonisolated static func strippingHeredocBodies(_ script: String) -> [String] {
        let lines = script.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let opener = try? NSRegularExpression(pattern: #"<<-?\s*(['"]?)([A-Za-z_][A-Za-z0-9_]*)\1"#)
        var kept: [String] = []
        var index = 0
        while index < lines.count {
            let line = lines[index]
            kept.append(line)
            if let opener,
               let match = opener.firstMatch(
                   in: line,
                   range: NSRange(line.startIndex..<line.endIndex, in: line)
               ),
               let range = Range(match.range(at: 2), in: line) {
                let terminator = String(line[range])
                index += 1
                while index < lines.count,
                      lines[index].trimmingCharacters(in: .whitespaces) != terminator {
                    index += 1
                }
            }
            index += 1
        }
        return kept
    }

    /// selftest 脚本里**真正会执行**的、带那个标志的构建命令行。
    ///
    /// 四层筛：heredoc 正文 → 整行 `#` 注释 → `echo` / `printf` 散文 → 必须与
    /// `$PROBE_DIR` **同行共现**（真命令都 `cd "$PROBE_DIR"`，而散文不必）。
    ///
    /// ⚠️ **不**做行内 `#` 处理——bash 里 `#` 只有在词首才是注释，真要处理得先做一遍
    /// shell 词法分析，那超出「纯文本判据」的定位。**已知缺口**：把标志藏进一条行尾
    /// 注释仍能骗过它（但那条行尾注释所在的行如果不含 `$PROBE_DIR`，就已经被筛掉了）。
    nonisolated static func flaggedBuildLines(inScript script: String) -> [String] {
        Self.strippingHeredocBodies(script)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") && !Self.isProseLine($0) }
            .filter { $0.contains("$PROBE_DIR") }
            .filter { $0.contains("swift build \(Self.requiredFlag)") }
    }

    // MARK: - 判据本体

    nonisolated private static func matches(_ pattern: String, in text: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        return regex.firstMatch(
            in: text,
            range: NSRange(text.startIndex..<text.endIndex, in: text)
        ) != nil
    }

    /// 判据本体：对一份 workflow 文本给出违规清单（空 = 通过）。
    ///
    /// ⚠️ 抽成纯函数，是为了让「删掉标志会判红」这件事本身**有一条常驻测试**
    /// （下面 `合成输入：删掉标志会判红`），而不必去改真实的 `ci.yml`。
    nonisolated static func violations(inWorkflow yaml: String) -> [String] {
        guard let block = Self.jobBlock(inWorkflow: yaml, job: Self.jobName) else {
            return ["解析失效：workflow 里找不到 `jobs:` 下的 `\(Self.jobName):` 块"]
        }
        let commands = Self.runCommands(inJobBlock: block)
        let realLines = commands.flatMap { Self.commandLines(inRunCommand: $0) }
        var problems: [String] = []

        // ⚠️ **同一行**共现，不是「整块 join 后 `contains`」（PR #304 第 3 轮终审 I-A）：
        // 后者等于「块里任何一行满足其一即可」，于是
        //     run: |
        //       echo "==> cd scripts/downstream-probe && swift build -Xswiftc -warnings-as-errors"
        //       cd scripts/downstream-probe && swift build
        // 实测 0 violations —— 与「改回裸 `swift build`」等效，只是更隐蔽。
        let buildLines = realLines.filter { $0.contains(Self.probeBuildMarker) }
        if buildLines.isEmpty {
            problems.append("`\(Self.jobName)` 里找不到含 `\(Self.probeBuildMarker)` 的 `run:`")
        }
        let missingFlag = buildLines.filter { !$0.contains(Self.requiredFlag) }
        for line in missingFlag {
            problems.append("probe 构建命令缺少 `\(Self.requiredFlag)`：\(line)")
        }
        // ⚠️ 正面清单：标志在场还不够，**整条命令**必须逐字相同——否则
        // `… -warnings-as-errors || echo skipped` 这类「尾巴」能把 step 退出码变成 0，
        // 而按拼法登记的 `exitCodeNeutralizers` 永远追不上尾巴的空间。
        // （标志本身就缺时不重复报，上面那条已经说清楚了。）
        if !buildLines.isEmpty, missingFlag.isEmpty,
           !buildLines.contains(Self.expectedProbeBuildCommand) {
            problems.append(
                """
                probe 构建那条 `run:` 不是逐字的 `\(Self.expectedProbeBuildCommand)`：\
                \(buildLines.joined(separator: " / "))

                这是一条**正面清单**：多出来的部分**不一定**中和退出码（`-c release` /
                `--verbose` 这类合法标志同样判红），但按拼法追尾巴追不完，所以整条锁死。
                · 确实想改这条命令 ⇒ 同步改 `\(Self.jobName)` 判据里的
                  `expectedProbeBuildCommand`（它由 `probeBuildMarker` + `requiredFlag` 拼出）。
                · 回显的串搜不到 ⇒ 多半是归一化第 3 步剥掉了引号，
                  见 `strippingQuotedSegments` 的文档注释。
                """
            )
        }
        if !realLines.contains(where: { $0.contains(Self.selftestMarker) }) {
            problems.append("`\(Self.jobName)` 里找不到跑 `\(Self.selftestMarker)` 的 `run:`")
        }

        // ⚠️ **标志在场 ≠ 失败会传导**（PR #304 第 2 轮终审 I-2、第 3 轮 I-C）。
        // 下面三组各堵一类「闸还在、但红点到不了 job 结论 / 这个 job 压根没跑」的改法；
        // 它们比「改回裸 `swift build`」更隐蔽，因为标志仍然逐字躺在那条 `run:` 里。
        //
        // ⚠️ 已知**假红**（PR #304 第 3 轮终审 S-ii）：判定跑在**本 job 的全部** `run:` 上，
        // 与「probe 构建那条」无关。将来给这个 job 加一步 `rm -f x || true` 之类的清理，
        // 会判红且文案说「退出码被吞掉」——**指错人**。方向 fail-closed，改文案或按 step
        // 定位再收窄；`echo … || true` 已经被散文筛挡掉，不会假红。
        let neutralizerText = realLines.joined(separator: "\n")
        for neutralizer in Self.exitCodeNeutralizers
        where Self.matches(neutralizer.pattern, in: neutralizerText) {
            problems.append(
                "`\(Self.jobName)` 的某条 `run:` 退出码被 `\(neutralizer.label)` 吞掉：\(neutralizerText)"
            )
        }
        let effectiveBlockLines = block
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { !Self.isSkippable($0) } // 注释里提一嘴 `continue-on-error` 不该判红
            .map { $0.trimmingCharacters(in: .whitespaces) }
        for blocked in Self.blockedJobKeys where effectiveBlockLines.contains(where: {
            $0.hasPrefix(blocked.key) || $0.hasPrefix("- \(blocked.key)")
        }) {
            problems.append(
                "`\(Self.jobName)` job 里出现 `\(blocked.key)` —— \(blocked.reason)"
            )
        }
        return problems
    }

    /// 脚本侧判据本体：对一份 selftest 脚本文本给出违规清单（空 = 通过）。
    ///
    /// ⚠️ **抽成纯函数是 PR #304 第 4 轮终审 R-1 的落件**：上一版把两条 `#expect` 直接写在
    /// `selftestUsesTheSameFlag` 里，其中**逐字集合比对**那条的**唯一证人是真实脚本**
    /// ——把它短路成恒真（变异 G14）之后套件实测 **19 tests passed** ⇒ 谁删掉它都不会有东西
    /// 判红，违反本仓 AD-E（每条断言都要有能触发红的 fixture）。
    /// ⚠️ `syntheticScriptWithTrailingCommentFlagIsRejected` 测的是 `flaggedBuildLines` 这个
    /// 纯函数，**不是**这条断言，顶不上。⇒ 抽成纯函数，由
    /// `syntheticScriptDivergingFromPinnedCommandsIsRejected`（钉集合比对）与
    /// `syntheticScriptWithFlagOutsideProbeDirIsAccepted`（钉第 4 层筛）
    /// 从**同一条路径**的合成输入钉住。
    nonisolated static func violations(inScript script: String) -> [String] {
        let flagged = Self.flaggedBuildLines(inScript: script)
        var problems: [String] = []
        if flagged.count != Self.selftestBuildCommandCount {
            problems.append(
                """
                `\(Self.selftestMarker)` 里带 `\(Self.requiredFlag)` 的**真实**构建命令
                有 \(flagged.count) 条，而不是预期的 \(Self.selftestBuildCommandCount) 条：
                \(flagged.isEmpty ? "（一条都没有）" : flagged.joined(separator: "\n"))

                ⚠️ 「一条都没有」**不等于「标志被删了」**（PR #304 第 4 轮终审 R-5）：
                `flaggedBuildLines` 的第 4 层筛按 `$PROBE_DIR` **同行共现**，把脚本里那个
                变量改名（纯合法重构）会得到**逐字相同**的这句话，而标志一个没少。
                先确认标志是否真的还在，再看下面那条逐字集合比对给的指引。
                """
            )
        }
        if Set(flagged) != Set(Self.selftestBuildCommands) {
            problems.append(
                """
                `\(Self.selftestMarker)` 的两条构建命令与 `selftestBuildCommands` 逐字钉住的
                文本对不上：
                实际：\(flagged.joined(separator: "\n"))
                期望：\(Self.selftestBuildCommands.joined(separator: "\n"))

                逐字钉住是有意的（脚本侧不能剥引号，见文件头）。合法改写这两行请同时改常量。
                """
            )
        }
        return problems
    }

    // MARK: - 判据

    @Test("ci.yml 的 downstream-probe 构建命令逐字带 -Xswiftc -warnings-as-errors")
    func workflowKeepsWarningsAsErrors() throws {
        let yaml = try String(contentsOf: Self.workflowURL, encoding: .utf8)
        let problems = Self.violations(inWorkflow: yaml)
        #expect(
            problems.isEmpty,
            """
            `.github/workflows/ci.yml` 的 `\(Self.jobName)` job 不再守着那道零警告闸：
            \(problems.joined(separator: "\n"))

            这不是风格问题——不带 `\(Self.requiredFlag)`，隔离契约里**整整一类**回归
            （长在 View / Transition 上的公开常量，诊断被降级成 warning）在这个 job 里
            是看不见的。恢复标志，或先说明为什么这道闸可以拆。
            """
        )
    }

    @Test("selftest 脚本的两条真实构建命令与 CI 用的是同一个标志")
    func selftestUsesTheSameFlag() throws {
        // ⚠️ **上一版这里写 `script.contains("swift build \(requiredFlag)")`，实测为假，
        // 照录更正**（PR #304 第 2 轮终审 I-1）：把脚本里**两条真实构建命令**（`:56`
        // 与 `:76`）的标志全部删掉，这条断言**照样绿**——满足它的是脚本第 9 行那条
        // **用法说明注释**里逐字写着的同一条命令。
        //
        // ⚠️⚠️ **上上一版改成「按行判定 + `>= 2`」仍然实测为假**（PR #304 第 3 轮终审 I-B）：
        // 把 `:76` 改回裸 `swift build`、再把 `:77` 的 `echo` 措辞补成含整条命令，
        // 真实文件 + 真实 `swift test` 上 `9 tests passed` —— 一条 `echo` 顶掉一条真命令。
        // 脚本里已经有一条差一步就会灌水的行（`:62` 的 `echo "FAIL: …-Xswiftc
        // -warnings-as-errors 没有起作用"`）。⇒ 现在是四层：heredoc / `#` / 散文首词 /
        // 与 `$PROBE_DIR` 同行共现，**计数用 `==`**，并**逐字钉住**那两行本身。
        let script = try String(contentsOf: Self.selftestURL, encoding: .utf8)
        let problems = Self.violations(inScript: script)
        #expect(
            problems.isEmpty,
            """
            \(problems.joined(separator: "\n\n"))

            这个脚本的价值是「用**带同一个标志**的构建命令证明这道闸会响」。
            ⚠️ 注意本判据**不比对两侧的命令文本**（PR #304 第 3 轮终审 S-i）：CI 那条是
            `cd scripts/downstream-probe && …`、脚本这两条是 `cd "$PROBE_DIR" && …`，
            本来就不逐字相同。两侧各自被钉住的是**同一个标志**，不是同一串命令
            ——CI 改成 `… -c release` 而脚本仍 debug，**这一条**不会红。
            ⚠️ 但**兄弟判据 `workflowKeepsWarningsAsErrors` 会红**（PR #304 第 4 轮终审 R-8）：
            第 3 轮新加的 `expectedProbeBuildCommand` 是**逐字正面清单**，`-c release` 属于
            「多出来的部分」⇒ 那边判红。⇒ 「CI 换 release、脚本不换」整体上仍会被拦住，
            只是拦它的不是这一条。
            """
        )
        // ⚠️ 下面这个循环遍历的是**常量本身**，不读任何文件——它是一条**棘轮**
        // （防有人改 `selftestBuildCommands` 时把标志一起改掉），**不是**被 fixture 驱动的
        // 判据：把它整个删掉（变异 G20）套件全绿。**非承重，登记在此**
        //（PR #304 第 4 轮终审「另外两条非承重但要知道」之二）。
        for command in Self.selftestBuildCommands {
            #expect(command.contains("swift build \(Self.requiredFlag)"))
        }
    }

    @Test("合成输入：删掉标志会判红")
    func syntheticWorkflowWithoutFlagIsRejected() {
        // ⚠️ 这就是本判据自己的「能触发红的 fixture」（AD-E）：真实 `ci.yml` 上做同样的
        // 删除也判红，见 PR #304 正文贴的原始输出；这里把它固化成常驻测试。
        let yaml = """
        jobs:
          downstream-probe:
            name: Downstream API probe
            runs-on: macos-26
            steps:
              - uses: actions/checkout@v4
              - name: Build downstream probe
                run: cd scripts/downstream-probe && swift build
              - name: Self-test the warnings-as-errors gate
                run: scripts/downstream-probe/selftest-warnings-as-errors.sh
        """
        let problems = Self.violations(inWorkflow: yaml)
        #expect(problems.count == 1)
        #expect(problems.first?.contains(Self.requiredFlag) == true)
    }

    @Test("合成输入：job 整个不见了也判红（不是 fail-open）")
    func syntheticWorkflowWithoutJobIsRejected() {
        let yaml = """
        jobs:
          build:
            runs-on: macos-26
            steps:
              - run: swift build
        """
        let problems = Self.violations(inWorkflow: yaml)
        #expect(problems.count == 1)
        #expect(problems.first?.contains("解析失效") == true)
    }

    @Test("合成输入：块标量写法也抓得到")
    func syntheticBlockScalarIsAccepted() {
        let yaml = """
        jobs:
          downstream-probe:
            steps:
              - name: Build downstream probe
                run: |
                  cd scripts/downstream-probe && swift build -Xswiftc -warnings-as-errors
              - run: scripts/downstream-probe/selftest-warnings-as-errors.sh
        """
        #expect(Self.violations(inWorkflow: yaml).isEmpty)
    }

    @Test("合成输入：反斜杠续行接标志仍判绿（归一化第 1 步的回归保护）")
    func syntheticBackslashContinuationIsAccepted() {
        // ⚠️ 「同一行共现」这条收紧（I-A）会把这种合法写法误杀 —— 所以必须先做续行合并。
        let yaml = """
        jobs:
          downstream-probe:
            steps:
              - name: Build downstream probe
                run: |
                  cd scripts/downstream-probe && swift build \\
                    -Xswiftc -warnings-as-errors
              - run: scripts/downstream-probe/selftest-warnings-as-errors.sh
        """
        #expect(Self.violations(inWorkflow: yaml).isEmpty)
    }

    @Test("合成输入：块标量里标志只剩在注释里也判红")
    func syntheticBlockScalarWithFlagOnlyInCommentIsRejected() {
        // ⚠️ 这条 fixture 钉住 `runCommands` 那个解析缺陷的修复（S-1）：注释行曾被拼进
        // 命令串，于是 `contains(requiredFlag)` 被**注释**满足 ⇒ 全绿而闸已死。
        let yaml = """
        jobs:
          downstream-probe:
            steps:
              - name: Build downstream probe
                run: |
                  # 这一步等价于 swift build -Xswiftc -warnings-as-errors
                  cd scripts/downstream-probe && swift build
              - run: scripts/downstream-probe/selftest-warnings-as-errors.sh
        """
        let problems = Self.violations(inWorkflow: yaml)
        #expect(problems.count == 1)
        #expect(problems.first?.contains(Self.requiredFlag) == true)
    }

    @Test("合成输入：注释里提到旧写法不该判红（`isSkippable` 跳 `#` 的正对照）")
    func syntheticBlockScalarCommentMentioningOldCommandStaysGreen() {
        // ⚠️ **这条是 PR #304 第 4 轮终审 R-2 的落件，但落法与终审的建议不同——照录理由。**
        // 终审说：把上面那条 fixture 的注释行改成含整条 marker，「变异 G16（`isSkippable`
        // 不再跳 `#`）立刻被杀」。**本轮实测为假**：G16 + 那份改法一起跑，`swift test`
        // 仍是 `19 tests passed`。原因是那条 fixture 的真命令本来就裸 `swift build` ⇒
        // 注释行即使被当成命令，它自己含标志、不进 `missingFlag`，`problems.count` 照样是 1。
        // ⇒ 要杀 G16 得反过来：真命令**合规**（整体应判绿），注释里提一句**旧的裸命令**
        // ——G16 之下那条注释会被当成「缺标志的构建命令」而判红，本 fixture 当场失败。
        let yaml = """
        jobs:
          downstream-probe:
            steps:
              - name: Build downstream probe
                run: |
                  # 旧写法（加标志之前）：cd scripts/downstream-probe && swift build
                  cd scripts/downstream-probe && swift build -Xswiftc -warnings-as-errors
              - run: scripts/downstream-probe/selftest-warnings-as-errors.sh
        """
        #expect(Self.violations(inWorkflow: yaml).isEmpty)
    }

    @Test("合成输入：块标量里用 echo 散文冒充命令也判红（I-A）")
    func syntheticBlockScalarWithEchoProseIsRejected() {
        // ⚠️ 第 2 轮只堵了 `#` 这一种拼法；这份输入在第 3 轮终审的实测里是 **0 violations**。
        let yaml = """
        jobs:
          downstream-probe:
            steps:
              - name: Build downstream probe
                run: |
                  echo "==> cd scripts/downstream-probe && swift build -Xswiftc -warnings-as-errors"
                  cd scripts/downstream-probe && swift build
              - run: scripts/downstream-probe/selftest-warnings-as-errors.sh
        """
        let problems = Self.violations(inWorkflow: yaml)
        #expect(problems.count == 1)
        #expect(problems.first?.contains(Self.requiredFlag) == true)
    }

    @Test("合成输入：整条命令只活在单引号 echo 里也判红（I-A 同族）")
    func syntheticEchoOnlyRunIsRejected() {
        let yaml = """
        jobs:
          downstream-probe:
            steps:
              - name: Build downstream probe
                run: echo 'cd scripts/downstream-probe && swift build -Xswiftc -warnings-as-errors'
              - run: scripts/downstream-probe/selftest-warnings-as-errors.sh
        """
        let problems = Self.violations(inWorkflow: yaml)
        #expect(problems.count == 1)
        #expect(problems.first?.contains(Self.probeBuildMarker) == true)
    }

    @Test("合成输入：selftest 路径被引号包成一个变量赋值也判红（归一化第 3 步的证人）")
    func syntheticQuotedSelftestAssignmentIsRejected() {
        // ⚠️ PR #304 第 4 轮终审 R-4：归一化第 3 步 `strippingQuotedSegments` 此前**承重但
        // 零覆盖**——把它改成恒等（变异 G6）套件实测 `19 tests passed`。既有两条 `echo`
        // fixture 全是被**第 4 步散文首词筛**判红的，与剥不剥引号无关。
        // 这份输入把 selftest 那步换成一个**变量赋值**（脚本从不执行，路径整串活在引号里）：
        // 剥引号 ON ⇒ 只剩 `SELFTEST=`，找不到 selftest 那步 ⇒ 判红；OFF ⇒ 全绿。
        let yaml = """
        jobs:
          downstream-probe:
            steps:
              - run: cd scripts/downstream-probe && swift build -Xswiftc -warnings-as-errors
              - run: SELFTEST="scripts/downstream-probe/selftest-warnings-as-errors.sh"
        """
        let problems = Self.violations(inWorkflow: yaml)
        #expect(problems.count == 1)
        #expect(problems.first?.contains(Self.selftestMarker) == true)
    }

    @Test("合成输入：`with:` 底下装饰性的 run: 不算命令（I-A 同族）")
    func syntheticRunUnderWithIsRejected() {
        let yaml = """
        jobs:
          downstream-probe:
            steps:
              - uses: some/action@v1
                with:
                  run: cd scripts/downstream-probe && swift build -Xswiftc -warnings-as-errors
              - uses: some/other@v1
                with:
                  run: scripts/downstream-probe/selftest-warnings-as-errors.sh
        """
        let problems = Self.violations(inWorkflow: yaml)
        #expect(problems.count == 2)
        #expect(problems.contains { $0.contains(Self.probeBuildMarker) })
        #expect(problems.contains { $0.contains(Self.selftestMarker) })
    }

    @Test("合成输入：`|| true` 与 continue-on-error 把闸变成装饰也判红")
    func syntheticNeutralizedGateIsRejected() {
        let swallowed = """
        jobs:
          downstream-probe:
            steps:
              - run: cd scripts/downstream-probe && swift build -Xswiftc -warnings-as-errors || true
              - run: scripts/downstream-probe/selftest-warnings-as-errors.sh
        """
        // ⚠️ 两条：`exitCodeNeutralizers` 认出 `|| true`，`expectedProbeBuildCommand`
        // 认出「这条命令后面多了尾巴」。两条各自独立，任何一条被绕开另一条仍在。
        let swallowedProblems = Self.violations(inWorkflow: swallowed)
        #expect(swallowedProblems.count == 2)
        #expect(swallowedProblems.contains { $0.contains("|| true") })
        #expect(swallowedProblems.contains { $0.contains("不是逐字的") })

        let continued = """
        jobs:
          downstream-probe:
            steps:
              - name: Build downstream probe
                continue-on-error: true
                run: cd scripts/downstream-probe && swift build -Xswiftc -warnings-as-errors
              - run: scripts/downstream-probe/selftest-warnings-as-errors.sh
        """
        let continuedProblems = Self.violations(inWorkflow: continued)
        #expect(continuedProblems.count == 1)
        #expect(continuedProblems.first?.contains("continue-on-error") == true)
    }

    @Test("合成输入：中和退出码的另外几种拼法也判红（I-C）")
    func syntheticNeutralizerSpellingsAreRejected() {
        // ⚠️ ` ||true`（少一个空格）与 `||` + 换行 + `true` 在第 3 轮终审的实测里
        // **在真实 `ci.yml` + 真实 `swift test` 上全绿** —— 逐字子串判据的典型失效。
        func workflow(withBuildSuffix suffix: String) -> String {
            """
            jobs:
              downstream-probe:
                steps:
                  - run: |
                      cd scripts/downstream-probe && swift build -Xswiftc -warnings-as-errors\(suffix)
                  - run: scripts/downstream-probe/selftest-warnings-as-errors.sh
            """
        }
        for (suffix, label) in [
            (" ||true", "|| true"),
            (" || :", "|| :"),
            (" ||:", "|| :"),
            (" || exit 0", "|| exit 0"),
            (" ; true", "; true"),
            ("; :", "; :"),
        ] {
            let problems = Self.violations(inWorkflow: workflow(withBuildSuffix: suffix))
            #expect(problems.count == 2, "`\(suffix)` 未判红")
            #expect(problems.contains { $0.contains(label) }, "`\(suffix)` 的判红标签不对")
            #expect(problems.contains { $0.contains("不是逐字的") }, "`\(suffix)` 未被逐字比对拦下")
        }

        // `||` 之后**软换行**再 `true`（bash 语义等价，块标量里完全合法）。
        let softWrapped = """
        jobs:
          downstream-probe:
            steps:
              - run: |
                  cd scripts/downstream-probe && swift build -Xswiftc -warnings-as-errors ||
                  true
              - run: scripts/downstream-probe/selftest-warnings-as-errors.sh
        """
        let softProblems = Self.violations(inWorkflow: softWrapped)
        #expect(softProblems.count == 2)
        #expect(softProblems.contains { $0.contains("|| true") })

        // 步骤里先 `set +e`（判据头上一版把它登记为「已知缺口」）。
        let setPlusE = """
        jobs:
          downstream-probe:
            steps:
              - run: |
                  set +e
                  cd scripts/downstream-probe && swift build -Xswiftc -warnings-as-errors
              - run: scripts/downstream-probe/selftest-warnings-as-errors.sh
        """
        let setProblems = Self.violations(inWorkflow: setPlusE)
        #expect(setProblems.count == 1)
        #expect(setProblems.first?.contains("set +e") == true)
    }

    @Test("合成输入：`|| echo skipped` 这类「尾巴」也判红（本轮自查新拼法 1）")
    func syntheticTrailingSwallowIsRejected() {
        // ⚠️ 加逐字比对之前，这份输入实测 **0 violations**：`echo` 成功 ⇒ step 退出码 0，
        // 而 `exitCodeNeutralizers` 那张按拼法登记的表里没有 `|| echo`。
        // 同族还有 `|| printf x` / `|| touch /tmp/x` / `|| (exit 0)` …… 空间无限
        // ⇒ 对策不是再加几条正则，是 `expectedProbeBuildCommand` 那条正面清单。
        for tail in [" || echo skipped", " || printf 'skipped'", " || (exit 0)", " 2>/dev/null"] {
            let yaml = """
            jobs:
              downstream-probe:
                steps:
                  - run: cd scripts/downstream-probe && swift build -Xswiftc -warnings-as-errors\(tail)
                  - run: scripts/downstream-probe/selftest-warnings-as-errors.sh
            """
            let problems = Self.violations(inWorkflow: yaml)
            #expect(problems.contains { $0.contains("不是逐字的") }, "`\(tail)` 未判红")
        }
    }

    @Test("合成输入：`shell:` 覆写掉 bash 的 -e / pipefail 也判红（本轮自查新拼法 2）")
    func syntheticShellOverrideIsRejected() {
        // GHA 的 bash 默认是 `bash --noprofile --norc -e -o pipefail {0}`。改成
        // `shell: bash {0}` 之后，块标量里前一条命令失败不再中断、管道里的失败也不再
        // 传导——标志仍然逐字在那条 `run:` 里，加这条断言之前实测全绿。
        let yaml = """
        jobs:
          downstream-probe:
            steps:
              - name: Build downstream probe
                shell: bash {0}
                run: |
                  cd scripts/downstream-probe && swift build -Xswiftc -warnings-as-errors
                  echo done
              - run: scripts/downstream-probe/selftest-warnings-as-errors.sh
        """
        let problems = Self.violations(inWorkflow: yaml)
        #expect(problems.count == 1)
        #expect(problems.first?.contains("`shell:`") == true)
    }

    @Test("合成输入：`if:` / `needs:` 让这个 job 可能压根不跑，也判红（C-2）")
    func syntheticSkipSwitchesAreRejected() {
        // ⚠️ `needs:` 不是理论形态：同一份 `ci.yml` 里 `bool-ratchet` 带着
        // `if: github.event_name == 'pull_request'`，`needs: bool-ratchet` 会让本 job
        // 在**每一次 push 事件**上被跳过。补上这条断言之前，两种改法实测都全绿。
        let gatedJob = """
        jobs:
          downstream-probe:
            if: github.event_name == 'pull_request'
            steps:
              - run: cd scripts/downstream-probe && swift build -Xswiftc -warnings-as-errors
              - run: scripts/downstream-probe/selftest-warnings-as-errors.sh
        """
        let gatedProblems = Self.violations(inWorkflow: gatedJob)
        #expect(gatedProblems.count == 1)
        #expect(gatedProblems.first?.contains("`if:`") == true)

        let gatedStep = """
        jobs:
          downstream-probe:
            steps:
              - name: Build downstream probe
                if: false
                run: cd scripts/downstream-probe && swift build -Xswiftc -warnings-as-errors
              - run: scripts/downstream-probe/selftest-warnings-as-errors.sh
        """
        let stepProblems = Self.violations(inWorkflow: gatedStep)
        #expect(stepProblems.count == 1)
        #expect(stepProblems.first?.contains("`if:`") == true)

        let needsSkippableJob = """
        jobs:
          downstream-probe:
            needs: bool-ratchet
            steps:
              - run: cd scripts/downstream-probe && swift build -Xswiftc -warnings-as-errors
              - run: scripts/downstream-probe/selftest-warnings-as-errors.sh
        """
        let needsProblems = Self.violations(inWorkflow: needsSkippableJob)
        #expect(needsProblems.count == 1)
        #expect(needsProblems.first?.contains("`needs:`") == true)
    }

    @Test("合成输入：selftest 里标志只剩在注释里也判红")
    func syntheticScriptWithFlagOnlyInCommentsIsRejected() {
        // 上一版断言（整文件 `contains`）对**这份**输入是绿的——它就是 I-1 那条实测的
        // 最小化形态：两条真命令裸 `swift build`，标志只活在头部用法说明里。
        let script = """
        #!/usr/bin/env bash
        #
        # CI 的 downstream-probe 步骤跑的是
        #
        #     cd scripts/downstream-probe && swift build -Xswiftc -warnings-as-errors
        #
        output="$(cd "$PROBE_DIR" && swift build 2>&1)"
        (cd "$PROBE_DIR" && swift build)
        """
        // ⚠️ 下面这条 `#expect` 是**恒真**的：它断言的是同一函数里几行之上那个字面量自己的
        // 内容，与判据实现无关（**有意的演示**——展示「旧断言在这份输入上是绿的」）。
        // **非承重，登记在此**（PR #304 第 4 轮终审「另外两条非承重但要知道」之一）。
        #expect(script.contains("swift build \(Self.requiredFlag)")) // 旧断言：绿
        #expect(Self.flaggedBuildLines(inScript: script).isEmpty) // 新判据：零命中 ⇒ 红
    }

    @Test("合成输入：两条真命令都带标志才算数")
    func syntheticScriptWithTwoRealCommandsIsAccepted() {
        let script = """
        #!/usr/bin/env bash
        # 说明里也提一次 swift build -Xswiftc -warnings-as-errors
        output="$(cd "$PROBE_DIR" && swift build -Xswiftc -warnings-as-errors 2>&1)"
        (cd "$PROBE_DIR" && swift build -Xswiftc -warnings-as-errors)
        """
        #expect(Self.flaggedBuildLines(inScript: script).count == Self.selftestBuildCommandCount)
    }

    @Test("合成输入：selftest 里用 echo 散文灌水顶替真命令也判红（I-B）")
    func syntheticScriptPaddedWithEchoIsRejected() {
        // ⚠️ 这三份输入在第 3 轮终审的实测里，对上一版的「按行 + `>= 2`」判据**全绿**，
        // 其中第一份是在**真实文件 + 真实 `swift test`** 上跑出来的 `9 tests passed`。
        let oneRealOneEcho = """
        #!/usr/bin/env bash
        output="$(cd "$PROBE_DIR" && swift build -Xswiftc -warnings-as-errors 2>&1)"
        (cd "$PROBE_DIR" && swift build)
        echo "==> 干净树用 cd "$PROBE_DIR" && swift build -Xswiftc -warnings-as-errors 构建"
        """
        #expect(Self.flaggedBuildLines(inScript: oneRealOneEcho).count == 1)

        let twoEchoes = """
        #!/usr/bin/env bash
        output="$(cd "$PROBE_DIR" && swift build 2>&1)"
        (cd "$PROBE_DIR" && swift build)
        echo "cd "$PROBE_DIR" && swift build -Xswiftc -warnings-as-errors"
        echo "cd "$PROBE_DIR" && swift build -Xswiftc -warnings-as-errors"
        """
        #expect(Self.flaggedBuildLines(inScript: twoEchoes).isEmpty)

        let heredoc = """
        #!/usr/bin/env bash
        cat > /dev/null <<'NOTE'
        (cd "$PROBE_DIR" && swift build -Xswiftc -warnings-as-errors)
        (cd "$PROBE_DIR" && swift build -Xswiftc -warnings-as-errors)
        NOTE
        (cd "$PROBE_DIR" && swift build)
        """
        #expect(Self.flaggedBuildLines(inScript: heredoc).isEmpty)
    }

    @Test("合成输入：脚本两条命令数目对但文本对不上也判红（逐字集合比对的证人）")
    func syntheticScriptDivergingFromPinnedCommandsIsRejected() {
        // ⚠️ PR #304 第 4 轮终审 R-1：`Set(flagged) == Set(selftestBuildCommands)` 此前
        // **唯一的证人是真实脚本**——把它短路成恒真（变异 G14）套件实测 `19 tests passed`。
        // 这份输入让**计数那条通过**（两行都过得了四层筛）、只有逐字比对能开火，
        // 于是它专钉那一条。
        let script = """
        #!/usr/bin/env bash
        output="$(cd "$PROBE_DIR" && swift build -Xswiftc -warnings-as-errors --verbose 2>&1)"
        (cd "$PROBE_DIR" && swift build -Xswiftc -warnings-as-errors)
        """
        #expect(Self.flaggedBuildLines(inScript: script).count == Self.selftestBuildCommandCount)
        let problems = Self.violations(inScript: script)
        #expect(problems.count == 1)
        #expect(problems.first?.contains("逐字钉住") == true)
    }

    @Test("合成输入：不含 $PROBE_DIR 的行不算真命令（第 4 层筛的证人）")
    func syntheticScriptWithFlagOutsideProbeDirIsAccepted() {
        // ⚠️ PR #304 第 4 轮终审 R-5：四层筛的第 4 层（与 `$PROBE_DIR` **同行共现**）此前
        // **承重但零覆盖**——把它删掉（变异 G12）套件实测 `19 tests passed`。
        // 这份输入在两条真命令之外多一行**含标志但不含 `$PROBE_DIR`** 的赋值：
        // 第 4 层筛在 ⇒ 判绿；筛掉了 ⇒ 计数与逐字比对两条一起开火。
        let script = """
        #!/usr/bin/env bash
        output="$(cd "$PROBE_DIR" && swift build -Xswiftc -warnings-as-errors 2>&1)"
        (cd "$PROBE_DIR" && swift build -Xswiftc -warnings-as-errors)
        HINT="修法：swift build -Xswiftc -warnings-as-errors"
        """
        #expect(Self.violations(inScript: script).isEmpty)
    }

    @Test("合成输入：脚本里把标志藏进行尾注释，逐字比对仍抓得到（本轮自查新拼法 3）")
    func syntheticScriptWithTrailingCommentFlagIsRejected() {
        // ⚠️ 「行尾注释藏标志」是上一版判据头**自己登记**的缺口，且 `flaggedBuildLines`
        // 确实拦不住它（这一行含 `$PROBE_DIR`、不以 `echo` 开头、也确实含
        // `swift build -Xswiftc -warnings-as-errors` 这个子串）——所以这里不是靠那层筛，
        // 而是靠 `selftestBuildCommands` 的**逐字比对**兜住。
        let script = """
        #!/usr/bin/env bash
        output="$(cd "$PROBE_DIR" && swift build -Xswiftc -warnings-as-errors 2>&1)"
        (cd "$PROBE_DIR" && swift build) # swift build -Xswiftc -warnings-as-errors
        """
        let flagged = Self.flaggedBuildLines(inScript: script)
        #expect(flagged.count == Self.selftestBuildCommandCount) // 逐层筛：漏过去了
        #expect(Set(flagged) != Set(Self.selftestBuildCommands)) // 逐字比对：抓住
    }
}
