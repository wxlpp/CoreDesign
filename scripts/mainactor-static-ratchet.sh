#!/usr/bin/env bash
# 公开 static 成员的 MainActor 隔离棘轮（#307）——**钉性质，不钉形状**。
#
# ## 它替掉的是什么
#
# `#290` 给 24 个公开 `static` 常量补上 `nonisolated`，靠的是**一次性人工枚举**
# （扫源码 → 人工过滤形态 → 临时 probe 逐条编译判定），结论由
# `scripts/downstream-probe` 钉住。但 probe 钉住的是**已登记的那些符号**：
# `#290` 之后新加一个 `public static let` 到一个新类型上，它在
# `.defaultIsolation(MainActor.self)` 下默认仍是 MainActor 隔离的，而只要 probe
# 不去引用它，就**没有任何东西判红**（`scripts/api-surface-diff.sh` 的头注释自己
# 就写了「它引用的符号是**手写清单**」）。
#
# 本脚本改从 **symbol graph** 取事实：编译器自己算出来的隔离，落在
# `declarationFragments` 里的 `@MainActor`。它不读源码文本、不依赖任何手写符号清单，
# 因此对「新加的成员」是**自动覆盖**的。
#
# ## 判据（逐字，与 `MainActorStaticRatchetGuard` 钉住的那几个字面量一致）
#
#   kind.identifier ∈ {swift.type.property, swift.type.method, swift.type.subscript}
#   ∧ accessLevel   ∈ {public, open}
#   ∧ identifier.precise 不含 "::SYNTHESIZED::"
#   ∧ declarationFragments 拼起来含 "@MainActor"
#   ⇒ 集合必须**恰为** docs/mainactor-static-exemptions.txt 登记的豁免（双向差集）
#
# ⚠️ **整条可见性筛今天都是空跑**，不只是 `open` 那一半：`dump-symbol-graph` 的
#   `--minimum-access-level` **默认就是 `public`**，本轮实测整张 symbol graph
#   **50432 个符号的 `accessLevel` 无一例外全是 `public`**（470 个公开 static 型成员
#   自然也全是）。⇒ 这条筛在今天不拦任何东西，它的非空性完全取决于 dump 的门槛。
#   为了不把那个门槛留给一个脚本里没钉住的 SwiftPM 默认值，下面那条 dump 命令
#   **显式**写了 `--minimum-access-level public`（该字面量已进
#   `MainActorStaticRatchetGuard.requiredScriptLiterals`）。写 `open` 进筛条件是为了
#   将来加 open class、或有人把门槛调低时不静默漏掉，不是因为它现在拦住了什么。
#
# ## ⚠️ 范围定案与代价（必须先读这一节再改判据或豁免表）
#
# 一次 `swift package dump-symbol-graph` 会写出**两类**文件：
#
#   · `<Target>.symbols.json`      —— 成员声明在**本包自己的类型**上
#   · `<Target>@<外来模块>.symbols.json` —— 成员声明在**外来类型**上
#     （`extension Color` / `extension Transition` / `extension ButtonStyle` …，
#      SwiftPM 默认 `--omit-extension-block-symbols`，这些成员被直接挂到被扩展的
#      nominal 上，落进这一类文件）
#
# **定案：扫「各 target 的主文件」+「`<Target>@<本包另一个 target>.symbols.json`」，
# 不扫 `<Target>@<第三方模块>.symbols.json`。** 逐文件实测（本轮，见 PR 正文的原始输出）：
#
#   | 文件                                   | public/open static | 剔 SYNTHESIZED | 其中 @MainActor |
#   |----------------------------------------|--------------------|----------------|-----------------|
#   | CoreDesign.symbols.json                | 56                 | 42             | 5               |
#   | CoreDesign@SwiftUI.symbols.json        | 12                 | 12             | 12              |
#   | CoreDesign@SwiftUICore.symbols.json    | 285                | 285            | 0               |
#   | CoreDesignCharts.symbols.json          | 5                  | 5              | 0               |
#   | CoreDesignEffects.symbols.json         | 78                 | 32             | 0               |
#   | CoreDesignEffects@SwiftUICore.symbols.json | 34             | 34             | 34              |
#   | 合计                                   | 470                | 410            | 51              |
#
#   ⚠️ 表里**没有** `<Target>@<本包另一个 target>.symbols.json` 那一族（如
#     `CoreDesignEffects@CoreDesign.symbols.json`）——不是漏掉了，是**今天一个都不存在**
#     （本包内还没有跨 target 的扩展）。本脚本照样扫它们，理由见下面那段。
#     ⇒ 光看这张 6 行表**推不出**那一族的存在，所以这里点明。
#
# 上表里那三个 `@` 文件的扩展目标**全都是第三方模块**（`SwiftUI` / `SwiftUICore`），
# 排除掉的就是它们那 46 条 `@MainActor`：`Transition.blur` / `.particle` / … 那一排
# 转场工厂与 `ButtonStyle.light(role:)` / `ProgressViewStyle.core` / … 那一排 style
# 工厂——它们的 `@MainActor` **来自 SwiftUI 协议本身**，本来就该是主 actor 隔离的
# （`#290` 明确把 UI 形态排除在射程外）。把它们塞进豁免表意味着**每加一条转场就要改表**
# ⇒ 棘轮退化成橡皮图章（本仓加转场的频率见 #268 / #292）。
#
# ⚠️ **包内跨 target 的扩展块成员在射程内**（这一半是 PR #314 终审补进来的）：
#   `CoreDesignEffects` / `CoreDesignCharts` 都 `import CoreDesign`，往 `CoreDesign`
#   的公开类型上加 `public static` 成员时，`CoreDesign` 对它们而言也是「外来模块」
#   ⇒ 成员落进 `CoreDesignEffects@CoreDesign.symbols.json`。射程有多大：
#   `CoreDesign.symbols.json` 里 **109 个公开 nominal 类型有 62 个带 `@MainActor`**
#   （本轮实测）——往这 62 个里的任何一个加一个公开 static，得到的就是一个
#   MainActor 隔离的公开 static，而它既不在主文件里，也**不是**「SwiftUI 协议本身
#   带来的隔离」。⇒ 这一族必须在射程内。
#   · 代价核算：这一族**今天零个文件**（上表那三个 `@` 文件的扩展目标全是第三方模块）
#     ⇒ 收进射程是**零 churn、零新豁免、判据在今天的行为逐字不变**。
#   · 实证（本轮）：往 `CoreDesignEffects` 加
#     `public extension CoreProgressViewStyle { static var probeLeakedMainActorStatic: Int { 42 } }`
#     ⇒ 扩这一族**之前**本脚本 exit 0（洞是真的），**之后** exit 1（洞关上了）。
#
# ⚠️⚠️ **仍然敞着的代价，如实登记**（这是本定案买单的那一侧，别只记选择不记代价）：
#   **写在第三方类型（`SwiftUI` / `SwiftUICore` / …）的扩展里的新公开 static 成员，
#   不在本棘轮射程内。**
#   · ⚠️ 这个代价的形态**不是**「往 `public extension Color` 加一个纯数据常量并忘了
#     写 `nonisolated`」——那个形态**复现不出来**：`.defaultIsolation(MainActor.self)`
#     **不作用于外来模块类型的扩展**。本轮实测：新加的
#     `public extension Color { static var probeColorToken: Color { .red } }`
#     在 symbol graph 里**根本不带 `@MainActor`**。大规模佐证：
#     `CoreDesign@SwiftUICore` 那 285 个色彩 token **没有一个写 `nonisolated`**，
#     却**一个都不是** MainActor 隔离的（`@MainActor` 命中为 0）。
#   · 真实形态窄得多：**显式**写 `@MainActor`（或让它取用某个 MainActor 隔离的东西
#     从而被推断成隔离的），或者扩展一个自身就是 `@MainActor` 的第三方类型。
#     这一族本脚本看不见，不会判红。
#   · 想覆盖它，得先接受「每加一条转场 / style 工厂就要改豁免表」这个 churn，
#     或者再引一层「按 extended module 分类的免登记规则」——两条都超出 #307 的范围。
#
# ⚠️ **「只看本包自己写的声明」由两道机制共同实现，不是一道**（改判据前务必读完这段）：
#   ① 上面的**文件筛选**；② python 段里的 **`SYNTHESIZED_MARK` 筛选**。缺一不可。
#   理由：被文件筛选挡在门外的那 46 条，在**主文件里躺着一份副本**——symbol graph 把
#   「写在协议扩展上的成员」再**复制**到每个具体遵从类型上，挂 `::SYNTHESIZED::`
#   标记（`ButtonStyle.light(role:)` 在主文件里的副本叫 `LightButtonStyle.light(role:)`）。
#   本轮逐条核过：`CoreDesign` 的 14 条 SYNTHESIZED 里 12 条带 `@MainActor`，
#   去掉类型前缀后与 `CoreDesign@SwiftUI` 的 12 条**逐条同名**；`CoreDesignEffects`
#   的 46 条**全部**带 `@MainActor`，其中 34 条与 `CoreDesignEffects@SwiftUICore`
#   的 34 条**逐条同名**，另 12 条是 `<X>Transition.properties`（`Transition` 协议的
#   默认实现）。
#   ⇒ **删掉 `SYNTHESIZED_MARK` 那一行，被文件筛选挡住的那 46 条会原封不动地从主文件
#   重新进入射程**（外加那 12 条协议默认实现，共 58 条判红）。所以那条筛不是
#   「顺手剔一下噪音」，它是范围定案的另一半。
#   ⚠️ 也因此，「多出的 14 条不是本包写的声明」这句话是**错的**（曾写在
#   `MainActorStaticRatchetGuard.requiredScriptLiterals` 的理由里，已改）：那 14 条里
#   **12 条恰恰是本包写的声明**，只是换了个键。
#
# ## 为什么是「脚本 + CI step」而不是一条 `swift test` 判据
#
# `swift package dump-symbol-graph` 是一次完整的 SwiftPM 调用。开销**实测**（本机，
# 每次先 `rm -rf .build/arm64-apple-macosx/symbolgraph`，紧接在完整 `swift build` +
# `swift test` 之后，即 CI 次序）：热 `.build` 上**约 4 s**（六次连测
# 6.2 / 4.2 / 4.5 / 4.1 / 4.2 / 4.3 s，第一次偏高是内层增量构建还没完全热），
# 写出约 265 MB JSON。
#
# ⇒ **「会给每一次本地 `swift test` 加开销」不是理由**：4 s 量级的东西不值得为它
# 单开一条通路（这一条曾按「约 100s」写，是**失真的数**，PR #314 终审实测推翻）。
# 真正的理由只剩一条，而它独立成立：**从 `swift test` 里 spawn 一次完整的 SwiftPM
# 调用有嵌套构建锁的风险。** 判据因此落在本脚本，由 `.github/workflows/ci.yml` 的
# `swiftpm` job 在 `swift test` 之后调用（`.build` 已热）。
#
# ⚠️ 「判据在 CI」意味着它**不随本地 `swift test` 跑**——这与 `downstream-probe` /
#    `bool-ratchet` 同形。看着这一步不被静默拆掉的是**树内**判据
#    `Tests/CoreDesignTests/MainActorStaticRatchetGuard.swift`（无条件、随每次
#    `swift test` 跑），它钉住：豁免表逐条、本脚本的筛条件字面量、以及 `ci.yml`
#    里那条 `run:` 与它所在 step / job 的 `if:` / `continue-on-error:` 等中和键。
#
# ## 用法与退出码
#
#   bash scripts/mainactor-static-ratchet.sh              # 自己跑 dump（CI 用这一条）
#   bash scripts/mainactor-static-ratchet.sh <symbolgraph-dir>   # 复用已有产物（本地调试 / 变异实证）
#
# ⚠️ 带参数那一路**只改「读哪里」，不放松任何判据**：目录里缺任何一个
#   `<Target>.symbols.json` 一律 exit 1（fail-closed）。CI 那条 `run:` 不带参数，
#   且被树内判据逐字钉住 ⇒ 参数不是 CI 侧的 fail-open 通道。
#
# ⚠️ **小前提，如实登记**：本脚本先 `cd "$REPO_ROOT"` 再消费 `$1`，所以从别的 cwd
#   传**相对路径**会被解析到仓库根之下，而不是你当时所在的目录。只影响本地调试
#   （fail-closed：解析到别处 ⇒ 目录不存在 ⇒ exit 1，不会静默变绿），
#   但报错会让人一头雾水 ⇒ 调试时传**绝对路径**。
#
#   0 通过 / 1 棘轮违规或判据无法工作 / 2 用法错误
#
# ⚠️ **「读不到 symbols.json ⇒ 判红」是有意的，不是 skip**：判据一旦失去输入就必须
#   有人回来看，静默跳过等于把棘轮换成一张空头支票（本仓 #275 刚踩过同款）。
#   ⚠️ 这条 fail-closed 只针对**主文件**：`<Target>@<本包另一个 target>.symbols.json`
#   在「本包内确实没有跨 target 扩展」时**本来就不存在**（今天正是如此，零个）
#   ⇒ 那一族按「在就扫、不在就跳过」处理，不能照主文件的规矩判红。
#
# ⚠️ **另一条小前提，如实登记**：下面那道「防空转网」断言**每个** library target 都
#   至少有一个公开 static 型成员。将来若新增一个只有类型 / 只有 modifier、一个公开
#   static 都没有的 library target，本脚本会**假红**。方向是 fail-closed（不会静默变绿），
#   但报错读起来像 bug ⇒ 届时把那条网改成「全体 target 合计为 0 才判红」，
#   并同步 `MainActorStaticRatchetGuard.requiredScriptLiterals` 里那条字面量。
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXEMPTIONS="$REPO_ROOT/docs/mainactor-static-exemptions.txt"

if [ "$#" -gt 1 ]; then
  echo "用法: bash scripts/mainactor-static-ratchet.sh [symbolgraph-dir]" >&2
  exit 2
fi

cd "$REPO_ROOT"

if [ ! -f "$EXEMPTIONS" ]; then
  echo "❌ 找不到豁免表 $EXEMPTIONS —— 判据无法工作，这不是「没有新增 MainActor 隔离的公开 static」" >&2
  exit 1
fi

# --- 1. 拿到 symbol graph 目录 -------------------------------------------------
if [ "$#" -eq 1 ]; then
  SYMBOLGRAPH_DIR="$1"
  echo "▶ 复用已有 symbol graph：$SYMBOLGRAPH_DIR"
else
  echo "▶ swift package dump-symbol-graph（热 .build 上实测约 4s）"
  DUMP_LOG="$(mktemp -t mainactor-ratchet-dump)"
  # ⚠️ 不用 `| tee`：pipefail + 上游 SIGPIPE 会把失败洗成别的码（本仓 ci.yml 栽过一次）。
  if ! swift package dump-symbol-graph --minimum-access-level public > "$DUMP_LOG" 2>&1; then
    echo "❌ dump-symbol-graph 失败 —— 判据无法工作。最后 40 行：" >&2
    tail -40 "$DUMP_LOG" >&2
    rm -f "$DUMP_LOG"
    exit 1
  fi
  # SwiftPM 最后一行形如 `Files written to <dir>`。
  SYMBOLGRAPH_DIR="$(sed -n 's/^Files written to //p' "$DUMP_LOG" | tail -1)"
  rm -f "$DUMP_LOG"
  if [ -z "$SYMBOLGRAPH_DIR" ]; then
    echo '❌ dump-symbol-graph 成功了，却没从输出里解析出 "Files written to <dir>" 那一行' >&2
    echo "   —— SwiftPM 的输出格式变了。判据失去输入，判红而不是跳过。" >&2
    exit 1
  fi
fi

if [ ! -d "$SYMBOLGRAPH_DIR" ]; then
  echo "❌ symbol graph 目录不存在：$SYMBOLGRAPH_DIR —— 判据无法工作（这不是「通过」）" >&2
  exit 1
fi

# --- 2. library target 名（与 Package.swift 同源，不写死） ---------------------
# ⚠️ 这里独立于 `GuardScanRoots.targetNames`（那是 Swift 侧的表，已与 Package.swift
#    做过双向差集）。两边同源于 Package.swift，因此新增 library target 时两边都会自动跟上。
TARGETS="$(swift package describe --type json \
  | python3 -c 'import json,sys; print("\n".join(t["name"] for t in json.load(sys.stdin)["targets"] if t["type"]=="library"))')"

if [ -z "$TARGETS" ]; then
  echo '❌ 从 swift package describe 里解析不出任何 library target —— 判据会在空输入上恒绿，判红。' >&2
  exit 1
fi

# --- 3. 逐 target 筛，并与豁免表做双向差集 ------------------------------------
export SYMBOLGRAPH_DIR EXEMPTIONS
printf '%s\n' "$TARGETS" | python3 -c '
import json, os, sys

symbolgraph_dir = os.environ["SYMBOLGRAPH_DIR"]
exemptions_path = os.environ["EXEMPTIONS"]

STATIC_KINDS = {"swift.type.property", "swift.type.method", "swift.type.subscript"}
PUBLIC_LEVELS = {"public", "open"}
SYNTHESIZED_MARK = "::SYNTHESIZED::"
ISOLATION_MARK = "@MainActor"

targets = [line.strip() for line in sys.stdin if line.strip()]
target_set = set(targets)

found = []          # "<Target>:<path>" —— 允许重复，重复本身要判红
population = {}     # target -> 候选总数（剔 SYNTHESIZED 后）

for target in targets:
    path = os.path.join(symbolgraph_dir, target + ".symbols.json")
    if not os.path.isfile(path):
        # ⚠️ fail-closed：某个 target 的主 symbols 文件缺席时，它名下的全部成员
        #    会「零命中 ⇒ 零违规」地静默通过。那正是本脚本要防的形态。
        sys.stderr.write(
            "❌ 缺 %s —— 该 target 的公开 static 成员会零命中地静默通过。"
            "判据失去输入，判红而不是跳过。\n" % path
        )
        sys.exit(1)
    # 主文件 + **本包内跨 target** 的扩展块文件（`<Target>@<本包另一个 target>.symbols.json`）。
    # 后者是 `CoreDesignEffects`/`CoreDesignCharts` 往 `CoreDesign` 的公开类型上加公开
    # static 时成员的落点：对它们而言 `CoreDesign` 也是「外来模块」。**有意不含**
    # `<Target>@<第三方模块>.symbols.json`（SwiftUI / SwiftUICore …）——理由与代价见
    # 头注释《范围定案与代价》。⚠️ 这一族今天零个文件，「在就扫、不在就跳过」，
    # 不套主文件那条 fail-closed（它本来就该不存在）。
    scan_paths = [path]
    for other in sorted(target_set):
        cross = os.path.join(symbolgraph_dir, "%s@%s.symbols.json" % (target, other))
        if os.path.isfile(cross):
            scan_paths.append(cross)
    count = 0
    for scan_path in scan_paths:
        with open(scan_path, "rb") as handle:
            doc = json.load(handle)
        for symbol in doc.get("symbols", []):
            if symbol.get("kind", {}).get("identifier") not in STATIC_KINDS:
                continue
            if symbol.get("accessLevel") not in PUBLIC_LEVELS:
                continue
            if SYNTHESIZED_MARK in symbol.get("identifier", {}).get("precise", ""):
                continue
            count += 1
            declaration = "".join(f.get("spelling", "") for f in symbol.get("declarationFragments", []))
            if ISOLATION_MARK in declaration:
                found.append("%s:%s" % (target, ".".join(symbol.get("pathComponents", []))))
    population[target] = count

# ⚠️ 防空转：任一 target 的候选面为 0 ⇒ 筛条件写错了 / 主文件是别的模块的产物。
#    没有这一条，一个把 kind 名字打错的 typo 会让整条判据永远绿。
empty = [t for t, n in population.items() if n == 0]
if empty:
    sys.stderr.write(
        "❌ 这些 target 的「公开/open static 型成员」候选面为 0：%s\n"
        "   本包每个 library target 都有公开 static 成员（实测 CoreDesign 42 / "
        "CoreDesignEffects 32 / CoreDesignCharts 5，均已剔 SYNTHESIZED）。\n"
        "   候选面归零说明筛条件失效，判据会恒绿 —— 判红。\n" % ", ".join(sorted(empty))
    )
    sys.exit(1)

if len(found) != len(set(found)):
    sys.stderr.write(
        "❌ 命中里出现重复的 `<Target>:<path>` 键：%s\n"
        "   豁免表按集合比对，重复项会被静默折叠。请改用更细的键再来。\n"
        % ", ".join(sorted(k for k in found if found.count(k) > 1))
    )
    sys.exit(1)

expected = set()
# ⚠️ `utf-8-sig` 不是随手选的：树内判据用 Foundation 读同一张表，Foundation 会**吞掉**
# BOM，而 `utf-8` + `str.strip()` 不会（`\ufeff` 在 Python 里不算空白）⇒ 一个带 BOM 的
# 表会「脚本红、树内绿」地分叉。两侧解析规则的异同逐条登记在
# `MainActorStaticRatchetGuard.exemptionEntries` 的文档注释里。
with open(exemptions_path, encoding="utf-8-sig") as handle:
    for line in handle:
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        expected.add(line)

actual = set(found)
unregistered = sorted(actual - expected)
stale = sorted(expected - actual)

for target in sorted(population):
    print("  %-20s 候选 %3d 个，其中 @MainActor %d 个"
          % (target, population[target],
             sum(1 for k in actual if k.startswith(target + ":"))))

if not unregistered and not stale:
    print("✅ 棘轮：公开 static 的 MainActor 隔离命中恰为登记的 %d 条豁免" % len(expected))
    sys.exit(0)

if unregistered:
    sys.stderr.write(
        "\n❌ 这些公开 static 成员是 MainActor 隔离的，但不在豁免表里（共 %d 条）：\n%s\n"
        "   处置：给它（或它的 enclosing type）加 `nonisolated`。\n"
        "   下游在非主 actor 语境取用会报错或被迫 await —— 这是契约不是风格，\n"
        "   本包三个 target 都开了 `.defaultIsolation(MainActor.self)`。\n"
        "   ⚠️ 确实修不掉（初始化表达式本身是 MainActor 隔离的）才登记进\n"
        "   docs/mainactor-static-exemptions.txt，并写清为什么修不掉。\n"
        % (len(unregistered), "\n".join("     " + k for k in unregistered))
    )

if stale:
    sys.stderr.write(
        "\n❌ 豁免表里这些条目已经不再是 MainActor 隔离的（共 %d 条）：\n%s\n"
        "   好消息（多半是它被修好了，或者符号被删/改名了）——但请把它从豁免表里删掉，\n"
        "   否则表会慢慢变成一张没人核对过的旧账。\n"
        % (len(stale), "\n".join("     " + k for k in stale))
    )

sys.exit(1)
'
