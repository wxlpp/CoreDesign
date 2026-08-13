#!/usr/bin/env bash
# 跨历史棘轮：比对 base revision 的豁免上限，确认它没有被**悄悄**抬高。
#
# ⚠️ 为什么这一半不放进 `swift test`：它要**两个 revision**，而单元测试只有一个工作树。
#    树内那一半（清单条目数 ≡ maxEntries）在 `BoolExemptionGuard.baselineRatchetHoldsExactly`,
#    零 git 依赖、随 `swift test` 跑。两半合起来才是完整的棘轮。
#
# ⚠️ **比对对象是 base 分支的当前 tip，不是字面的 `main`，也不是
#    `github.event.pull_request.base.sha`**（对 39.md AC 措辞的一处偏离，已写进交付说明）：
#    · 不用字面的 `main`：CoreDesign 侧五个任务集成在 `epic/component-contract`，
#      `epic→main` 要等到 #42 发版——在那之前 `main` 上根本没有这两个文件，
#      拿 `main` 比要么永久红、要么退化成「文件读不到 ⇒ 绿」。
#    · **不用 `base.sha`**：那是 GitHub 在 **PR 创建时**记录的 base 快照，
#      **不跟随 base 分支推进**（Actions 的知名坑）。后果很具体：#39 合入 epic 之后，
#      一个**更早开出**的 PR（如并行的 #40）跑本脚本时，它 payload 里的 base.sha 早于
#      #39 的合入点 ⇒ `git cat-file -e` 找不到基线文件 ⇒ 走「base 上无文件」分支 ⇒
#      **静默 fail-open**。这正是本 epic 反复在堵的「文件读不到 ⇒ 绿」的 CI 变体。
#      ⇒ CI 传进来的是 `origin/$GITHUB_BASE_REF`（base 分支**当前** tip）。
#
# 用法：bash scripts/bool-exemptions-ratchet.sh <base-ref>
# 退出码：0 通过 / 1 棘轮违规 / 2 用法错误 / 3 基线文件损坏或缺字段
set -euo pipefail

BASE_REF="${1:-}"
BASELINE="docs/bool-exemptions-baseline.json"

if [ -z "$BASE_REF" ]; then
  echo "用法: bash scripts/bool-exemptions-ratchet.sh <base-ref>" >&2
  exit 2
fi

if [ ! -f "$BASELINE" ]; then
  echo "❌ 当前修订缺 $BASELINE —— 判据无法工作，这不是「上限没被抬高」" >&2
  exit 1
fi

# 用法：read_field <key>，**JSON 从 stdin 读入**（key 走 argv）。
# ⚠️ 解析失败 / 缺字段一律 exit **3**，不与「棘轮违规」的 1 撞码，且各自带诊断
#    ——原实现直接 `json.load(...)[key]`，KeyError 会在 set -e 下变成一个**无消息的 exit 1**，
#    读日志的人会以为是棘轮判红。
read_field() {
  # ⚠️ 实测踩坑修正：不能用 `python3 - "$1" <<'PY' ... PY`——heredoc 本身就是
  #    "python3 -" 读取*程序源码*用的 stdin，会把外层 `< "$BASELINE"` / 管道喂的
  #    JSON 数据整个遮蔽掉，导致 `json.load(sys.stdin)` 永远读到 EOF、
  #    报 "Expecting value: line 1 column 1 (char 0)"（已用最小复现验证）。
  #    改用 `python3 -c '<script>' "$1"`：脚本源码走 -c 参数，stdin 留给数据、
  #    key 仍走 argv——对外契约（stdin=JSON，argv=key）不变。
  python3 -c '
import json, sys
key = sys.argv[1]
try:
    doc = json.load(sys.stdin)
except json.JSONDecodeError as error:
    sys.stderr.write(f"❌ 基线 JSON 解析失败：{error}\n")
    sys.exit(3)
if key not in doc:
    sys.stderr.write(
        f"❌ 基线缺字段「{key}」—— 抬高上限是破例动作，必须留下署名/日期/理由。"
        f"缺字段不是「通过」。\n"
    )
    sys.exit(3)
print(doc[key])
' "$1"
}

CUR_MAX=$(read_field maxEntries < "$BASELINE")
CUR_ON=$(read_field raisedOn < "$BASELINE")
CUR_WHY=$(read_field rationale < "$BASELINE")

if ! git cat-file -e "${BASE_REF}:${BASELINE}" 2>/dev/null; then
  # base 上没有基线文件。**只有一种情况是合法的：本次修订就是引入它的那一次。**
  # ⚠️ 先落到变量再判断，不要 `git diff | grep -q`：grep -q 命中即退出并向上游发 SIGPIPE，
  #    pipefail 会把 141 提升为整条管道的退出码，判断恒假（ci.yml 已经栽过一次同款）。
  ADDED=$(git diff --name-status "${BASE_REF}...HEAD" -- "$BASELINE" 2>/dev/null || true)
  case "$ADDED" in
    A*)
      echo "✅ 本次修订新增了 ${BASELINE}（引入 PR），base 上无历史上限可比。当前 maxEntries=${CUR_MAX}"
      exit 0
      ;;
  esac
  # ⚠️ **不 fail-open**：读不到基线 ≠「上限没被抬高」。
  echo "❌ base (${BASE_REF}) 上没有 ${BASELINE}，且本次修订也没有新增它。" >&2
  echo "   最可能的原因：base ref 选错了（例如用了 PR 创建时快照的 base.sha，它不跟随 base 分支推进），" >&2
  echo "   或基线文件被删除。请人工核对——这不是「通过」。" >&2
  exit 1
fi

BASE_JSON=$(git show "${BASE_REF}:${BASELINE}")
BASE_MAX=$(printf '%s' "$BASE_JSON" | read_field maxEntries)
BASE_ON=$(printf '%s' "$BASE_JSON" | read_field raisedOn)
BASE_WHY=$(printf '%s' "$BASE_JSON" | read_field rationale)

echo "base(${BASE_REF}) maxEntries=${BASE_MAX}  →  HEAD maxEntries=${CUR_MAX}"

if [ "$CUR_MAX" -lt "$BASE_MAX" ]; then
  echo "✅ 棘轮收紧：豁免上限从 ${BASE_MAX} 降到 ${CUR_MAX}"
  exit 0
fi

if [ "$CUR_MAX" -eq "$BASE_MAX" ]; then
  echo "✅ 棘轮：豁免上限未变（${CUR_MAX}）"
  exit 0
fi

# 抬高了：允许，但必须是一次**署名、注明日期、写明理由**的破例，不能是顺手改个数字。
#
# ⚠️ 承重字段是 **rationale**，不是日期：原实现写 `[ CUR_ON = BASE_ON ] || [ CUR_WHY = BASE_WHY ]`
#    （日期与理由**都**变才放行），于是「同一天内第二次合法抬高上限」会被**误判红**
#    ——而同一天连做两次裁决完全可能。⇒ 只把 rationale 逐字未变判红，日期相同只提醒。
if [ "$CUR_WHY" = "$BASE_WHY" ]; then
  echo "❌ 棘轮：豁免上限被抬高（${BASE_MAX} → ${CUR_MAX}），但 rationale 与 base 逐字相同。" >&2
  echo "   抬高上限是**破例动作**，必须同轮更新 raisedBy / raisedOn / rationale，" >&2
  echo "   理由要写清新增的豁免为何过不了公约第 3 节终局条款 (b)（论证它本不该存在、走删除）。" >&2
  exit 1
fi

if [ "$CUR_ON" = "$BASE_ON" ]; then
  echo "⚠️ raisedOn 与 base 相同（${CUR_ON}）——同一天内第二次抬高上限是可能的，**不判红**；"
  echo "   但请评审确认这确实是一次新的裁决，而不是改了理由却漏改日期。"
fi

echo "⚠️⚠️ 棘轮：豁免上限被抬高 ${BASE_MAX} → ${CUR_MAX}，且已附裁决记录："
echo "     raisedOn : ${CUR_ON}"
echo "     rationale: ${CUR_WHY}"
echo "⚠️⚠️ 评审必须逐条核对新增的豁免——棘轮只挡「悄悄抬高」，挡不住「明着抬高」，"
echo "     后者由人负责。"
exit 0
