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
# ⚠️ `open` 目前是**空跑**：本包 469 个公开 static 型成员里 `accessLevel` 全是 `public`
#   （`open` 只对 class 成员有意义，本包没有 open class）。写进筛条件是为了将来加
#   open class 时不静默漏掉，不是因为它现在拦住了什么。
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
# **定案：只扫主文件。** 逐文件实测（本轮，见 PR 正文的原始输出）：
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
# 理由：多出的 46 条全部是 `Transition.blur` / `.particle` / … 那一排转场工厂与
# `ButtonStyle.light(role:)` / `ProgressViewStyle.core` / … 那一排 style 工厂
# ——它们的 `@MainActor` **来自 SwiftUI 协议本身**，本来就该是主 actor 隔离的
# （`#290` 明确把 UI 形态排除在射程外）。把它们塞进豁免表意味着**每加一条转场就要改表**
# ⇒ 棘轮退化成橡皮图章（本仓加转场的频率见 #268 / #292）。
#
# ⚠️⚠️ **代价，如实登记**（这是本定案买单的那一侧，别只记选择不记代价）：
#   **写在 `extension <外来类型>` 里的新公开 static 成员，完全不在本棘轮射程内。**
#   具体形态：往 `public extension Color` / `extension Transition` / `extension View`
#   等**外来类型**上新加一个 `public static let`，无论它是不是 MainActor 隔离，
#   本脚本都看不见它，不会判红。
#   · 缓解证据（不是消除）：`CoreDesign@SwiftUICore` 那 285 个色彩 token 目前
#     `@MainActor` 命中为 **0** ——整个色彩层跨模块是 nonisolated 可达的
#     ⇒ 这块**目前**不是隐患。但它是盲区，且**空间是开放的**。
#   · 想覆盖它，得先接受「每加一条转场 / style 工厂就要改豁免表」这个 churn，
#     或者再引一层「按 extended module 分类的免登记规则」——两条都超出 #307 的范围。
#
# ## 为什么是「脚本 + CI step」而不是一条 `swift test` 判据
#
# `swift package dump-symbol-graph` 是一次完整的 SwiftPM 调用（本机热 `.build` 上实测
# 约 100s，并写出约 265 MB JSON）。从 `swift test` 里 spawn 它有嵌套构建锁的风险，
# 而且会给**每一次**本地 `swift test` 加上这个开销。⇒ 判据落在本脚本，
# 由 `.github/workflows/ci.yml` 的 `swiftpm` job 在 `swift test` 之后调用（`.build` 已热）。
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
#   0 通过 / 1 棘轮违规或判据无法工作 / 2 用法错误
#
# ⚠️ **「读不到 symbols.json ⇒ 判红」是有意的，不是 skip**：判据一旦失去输入就必须
#   有人回来看，静默跳过等于把棘轮换成一张空头支票（本仓 #275 刚踩过同款）。
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
  echo "▶ swift package dump-symbol-graph（约 100s，热 .build 上）"
  DUMP_LOG="$(mktemp -t mainactor-ratchet-dump)"
  # ⚠️ 不用 `| tee`：pipefail + 上游 SIGPIPE 会把失败洗成别的码（本仓 ci.yml 栽过一次）。
  if ! swift package dump-symbol-graph > "$DUMP_LOG" 2>&1; then
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
    with open(path, "rb") as handle:
        doc = json.load(handle)
    count = 0
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
with open(exemptions_path, encoding="utf-8") as handle:
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
