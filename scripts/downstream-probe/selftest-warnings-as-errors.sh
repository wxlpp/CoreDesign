#!/usr/bin/env bash
#
# `downstream-probe` job 的 `-Xswiftc -warnings-as-errors` 自证 fixture（AD-E）。
#
# ## 它证的是什么
#
# CI 的 `downstream-probe` 步骤跑的是
#
#     cd scripts/downstream-probe && swift build -Xswiftc -warnings-as-errors
#
# 这道闸防的形态是「**绿着的警告悄悄积累**」——#290 之前它是空的：那一步不带
# 这个标志，于是本包带着 5 条 MainActor 隔离 warning 而 CI 一直是绿的。
#
# ⚠️ 但「加了标志」不等于「它真的会响」。本仓对新守卫的一贯要求（AD-E）是**配一个
# 能触发红的 fixture**。本脚本就是它：
#
#   1. 往 probe 的 `Sources/DownstreamProbe/` 里塞一个**必然产生 warning、且不产生
#      error** 的临时文件；
#   2. 用与 CI 逐字相同的命令构建，断言它**非零退出**、且输出里那条 warning 被
#      当成了 `error`；
#   3. 无论成败都把临时文件删干净（`trap`），再用同一条命令确认干净树仍然绿。
#
# ⚠️ **fixture 必须是 warning 而不是 error**——否则它只证明「编译错误会让构建失败」
# （那不需要任何标志），证不到「**警告**会让构建失败」这条唯一有争议的因果。
# 这里用 `var` 从未被改写这条最稳定、与本库语义无关的 Swift 警告；用一条真实的
# MainActor 隔离警告反而做不到，因为那需要先把库改坏。
#
# 用法：从仓库任意目录跑 `scripts/downstream-probe/selftest-warnings-as-errors.sh`。

set -euo pipefail

readonly PROBE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly FIXTURE="${PROBE_DIR}/Sources/DownstreamProbe/WarningsAsErrorsFixture.swift"

cleanup() {
    rm -f "$FIXTURE"
}
trap cleanup EXIT

if [ -e "$FIXTURE" ]; then
    echo "FAIL: ${FIXTURE} 已存在——上一次运行没清理干净，拒绝覆盖" >&2
    exit 1
fi

cat > "$FIXTURE" <<'SWIFT'
// ⚠️ 由 selftest-warnings-as-errors.sh 临时生成，跑完即删。
// 它**只**产生一条 warning（`var` 从未被改写），不产生任何 error。
nonisolated func warningsAsErrorsFixture() -> Int {
    var value = 1
    return value
}
SWIFT

echo "==> 步骤 1/3：带 fixture 构建，期望**判红**"
set +e
output="$(cd "$PROBE_DIR" && swift build -Xswiftc -warnings-as-errors 2>&1)"
status=$?
set -e
printf '%s\n' "$output"

if [ "$status" -eq 0 ]; then
    echo "FAIL: 带 fixture 的构建退出码为 0 —— -Xswiftc -warnings-as-errors 没有起作用" >&2
    exit 1
fi

if ! grep -q "WarningsAsErrorsFixture.swift:.*error:.*never mutated" <<< "$output"; then
    echo "FAIL: 构建确实失败了，但失败原因不是 fixture 那条被提升的警告 —— 判据可能在证别的东西" >&2
    exit 1
fi
echo "==> 步骤 1/3 通过：warning 被提升为 error，退出码 ${status}"

echo "==> 步骤 2/3：删除 fixture"
cleanup

echo "==> 步骤 3/3：干净树用同一条命令构建，期望**判绿**"
(cd "$PROBE_DIR" && swift build -Xswiftc -warnings-as-errors)
echo "==> 步骤 3/3 通过：干净树零警告"

echo "OK: downstream-probe 的 -Xswiftc -warnings-as-errors 闸确认会响。"
