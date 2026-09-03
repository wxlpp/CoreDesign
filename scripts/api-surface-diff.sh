#!/usr/bin/env bash
# 比对某个模块的公开 API 表面在 <base-ref> 与工作树之间有无变化（增 / 删 / 改签名）。
#
# ⚠️ **为什么需要它**（#245）：`scripts/downstream-probe` 只能证明「下游还能编」，
# 证不了「公开面没多没少」——它引用的符号是**手写清单**，删掉一个没被 probe 引用的
# public 符号，probe 照常绿。而多个 epic（shipswift-*）都把「`CoreDesign` 公开 API
# 表面 diff 为空」写进了验收标准，需要一个真能验的工具。
#
# ⚠️ **不要把比较器换回 `swift-api-digester -diagnose-sdk`**（#245 终审 C-1 第二层）。
# 它是**破坏性变更检测器**——分节全是 `Removed Decls` / `Renamed Decls` / `Type Changes`，
# **新增声明不算破坏，它一行都不报**。实测：往 `Sources/CoreDesign/` 加一个 `public enum`
# 并提交，`-dump-sdk` 抓到了（json 1496775 → 1499683 字节、命中 8 处），
# 而 `-diagnose-sdk` 输出为空 ⇒ 报「无变化」。而「多了一个公开符号」正是本工具要抓的
# 两种情形之一。⇒ 改为**直接对两份 dump 做集合差**。
#
# ⚠️ **比较键是 `(usr, declAttributes)`，不能只用 `usr`**（#257 Copilot CLI 复审）。
# `usr` 是 mangled 符号，增、删、改签名都会体现——但 **actor isolation 的变化不改 usr**。
# 实测（`CoreDesignEffects.moduleName`）：把 `nonisolated` 删掉后 usr 一字不差，
# 只有 `declAttributes` 从 `[HasInitialValue, Nonisolated, HasStorage]` 变成
# `[HasInitialValue, HasStorage, Custom]`。而本包所有 target 都启用
# `.defaultIsolation(MainActor.self)`，**「某个公开成员的 isolation 域被改了」正是这里
# 最容易悄悄发生、且对下游 nonisolated 消费者是破坏性的那类变更**——只比 usr 会对它假绿。
#
# ⚠️ **本脚本绝不改动调用者的工作树**（#245 终审 C-1 第一层）。初版用
# `git stash -u` + `git checkout <base> -- .` 做往返，有四个缺陷，均已在最小 git 仓复现，
# 留档以免有人"优化"回去：
#   ① **假绿**——`git checkout <base> -- .` 只覆盖 base 里存在的路径，**不删除 HEAD
#      新增且已提交的文件**（`-u` 只对未提交的新文件成立）⇒ 新符号被编进 baseline。
#   ② **污染工作树**——`git checkout HEAD -- .` 不删掉从 base 复活的文件；任何删过文件
#      的分支跑一次，被删文件就以 staged 状态回来了。
#   ③ **typo 静默通过**——`git checkout no-such-ref -- . 2>/dev/null || true` 吞掉错误。
#   ④ **失败路径不还原**——base 侧构建失败时工作树停在 base 内容、改动还在 stash 里。
# ⇒ 现在在**临时 detached worktree** 里构建 baseline，调用者的工作树全程只读。
#
# 用法：
#   bash scripts/api-surface-diff.sh [base-ref]                 # 默认 base-ref = main
#   MODULE=CoreDesignEffects bash scripts/api-surface-diff.sh   # 比对别的模块
#
# 退出码：0 = 无变化；1 = 有变化（差异打印到 stdout）；2 = 工具/环境问题。
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)" || { echo "❌ 不在 git 仓库内"; exit 2; }
cd "${ROOT}"

BASE_REF="${1:-main}"
MODULE="${MODULE:-CoreDesign}"

git rev-parse --verify --quiet "${BASE_REF}^{commit}" >/dev/null \
  || { echo "❌ base-ref 不存在：${BASE_REF}"; exit 2; }

WORK="$(mktemp -d)"
BASE_TREE="${WORK}/base"
cleanup() {
  git worktree remove --force "${BASE_TREE}" >/dev/null 2>&1 || true
  rm -rf "${WORK}"
}
trap cleanup EXIT

SDK="$(xcrun --sdk macosx --show-sdk-path)" || exit 2
# ⚠️ triple 与产物路径都从环境推导，不硬编码 arm64（#245 终审 S-2）
TRIPLE="$(uname -m)-apple-macos$(sw_vers -productVersion | cut -d. -f1).0"

dump() { # $1 = 构建目录，$2 = 输出 json
  ( cd "$1" \
    && swift build -q >/dev/null 2>&1 \
    && MODULES="$(swift build --show-bin-path)/Modules" \
    && xcrun swift-api-digester -dump-sdk -module "${MODULE}" -o "$2" \
         -I "${MODULES}" -sdk "${SDK}" -target "${TRIPLE}" -swift-version 6 \
         >/dev/null 2>&1 ) \
  || { echo "❌ dump 失败（dir=$1 module=${MODULE}）—— 模块名拼错、该 ref 上构建不过、或工具链不匹配"; exit 2; }
}

echo "→ dump 工作树…"
dump "${ROOT}" "${WORK}/head.json"

echo "→ 在临时 worktree 上 dump ${BASE_REF}…（不触碰你的工作树）"
git worktree add -q --detach "${BASE_TREE}" "${BASE_REF}" \
  || { echo "❌ 无法为 ${BASE_REF} 建临时 worktree"; exit 2; }
dump "${BASE_TREE}" "${WORK}/base.json"

echo "→ 比对（USR + declAttributes）…"
OUT="$(python3 - "${WORK}/base.json" "${WORK}/head.json" <<'PY'
import json, sys

def decls(path):
    """收集 dump 里所有带 usr 的声明：usr -> (declKind, printedName, 属性集合)。

    ⚠️ 属性集合必须收——isolation 变化（`nonisolated` 增删、隐式 `@MainActor`）
    **不改 usr**，只体现在 declAttributes 上。
    """
    def walk(node, acc):
        if isinstance(node, dict):
            u = node.get("usr")
            if u:
                acc[u] = (
                    node.get("declKind") or node.get("kind"),
                    node.get("printedName"),
                    frozenset(node.get("declAttributes") or []),
                )
            for child in node.get("children") or []:
                walk(child, acc)
    acc = {}
    walk(json.load(open(path))["ABIRoot"], acc)
    return acc

base, head = decls(sys.argv[1]), decls(sys.argv[2])

for u in sorted(set(base) - set(head)):
    k, n, _ = base[u]
    print(f"  - 删除  {k or '':14} {n}")
for u in sorted(set(head) - set(base)):
    k, n, _ = head[u]
    print(f"  + 新增  {k or '':14} {n}")
for u in sorted(set(base) & set(head)):
    kb, nb, ab = base[u]
    kh, nh, ah = head[u]
    if ab != ah:
        gone, got = sorted(ab - ah), sorted(ah - ab)
        detail = []
        if gone: detail.append("去掉 " + ", ".join(gone))
        if got:  detail.append("加上 " + ", ".join(got))
        print(f"  ~ 属性  {kh or '':14} {nh}  ({'；'.join(detail)})")
PY
)"

if [ -z "${OUT}" ]; then
  echo "✅ ${MODULE} 公开 API 表面无变化（vs ${BASE_REF}）"
  exit 0
fi
echo "⚠️ ${MODULE} 公开 API 表面有变化（vs ${BASE_REF}）："
echo "${OUT}"
exit 1
