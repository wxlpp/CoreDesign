---
name: auto-fix-pr-after-implementation
description: |
  当本会话刚刚通过任意路径（superpowers / ccpm / 直接 gh pr create / 其他）
  在 GitHub 上打开了一个 PR，且该 PR 尚未收到 Copilot review 时，直接启动
  fix-pr 工作流：立即开始轮询 Copilot review，待 review 完成后进入 fix-pr
  处理反馈。**触发条件不再绑定特定 worktree 或 superpowers 来源**——只要
  当前会话里刚开了 PR 就激活。
---

# 开 PR 后自动进入 fix-pr 工作流

把"PR 已开"状态衔接到 fix-pr 反馈闭环，不区分 PR 是哪条工作流（superpowers /
ccpm / 手动）打开的。

## 前置条件

只有在以下条件全部满足时才激活：
- 当前会话里刚打开了一个 PR（通过 session state 跟踪，或用 `gh pr view --json createdAt` 检查最近的创建时间——一般 5 分钟内）
- 该 PR 还没有收到 Copilot review
- 用户没有显式选择退出（检查 session memory）

**已移除**的旧条件：
- ~~"PR 来自 superpowers 的 finishing-a-development-branch"~~ — 任何工作流打开的 PR 都可触发
- ~~"PR 的 head branch 与当前 worktree branch 一致"~~ — head branch 与 worktree 是否一致不再相关

## 步骤

1. **向用户发送开始执行的状态通知**。
   
  展示：
  - PR 编号、URL、标题
  - 变更文件数量
  - 计划：“我现在开始轮询等待 Copilot review（约 2 到 5 分钟），完成后会进入 fix-pr 工作流处理反馈。”
   
  不等待用户确认，满足前置条件后直接继续执行。只有当用户显式选择退出时才停止。

2. **立即开始轮询等待 Copilot review**：

   **首轮 review 由 PR 打开事件自动触发**——首轮不需要主动请求。
   将 PR 的创建时间作为本轮等待的基准时间，后续只关心该时间之后到达的 Copilot review。

   **第二轮及之后必须手动触发**：Copilot **不会**在新 push 上自动重 review，
   只在 PR 首次打开时自动 review；任何后续 review 都必须用
   `scripts/request-copilot.sh <PR>` 通过 `gh pr edit --add-reviewer @copilot`
   主动请求。这一点是步骤 5 循环的核心前提。

3. **监控 Copilot review 是否完成**：
   
```bash
   # Poll every 30s, max 10 min
   while true; do
     LATEST_TS=$(gh api "repos/$OWNER/$REPO/pulls/$PR/reviews" --paginate \
       --jq '[.[] | select(.user.login == "copilot-pull-request-reviewer[bot]")]
             | sort_by(.submitted_at) | last.submitted_at // ""')
     if [[ "$LATEST_TS" > "$PR_CREATED_AT" ]]; then
       break
     fi
     sleep 30
   done
```
   
  大约每 2 分钟向用户发送一次简短进度更新（例如“仍在等待 Copilot review...”）。如果超时（10 分钟），询问用户是继续等待，还是在没有 Copilot review 的情况下继续。

4. **进入 fix-pr 工作流**：
   
  这个 skill 目录下自带底层 shell 脚本，位于
  `.claude/skills/auto-fix-pr-after-implementation/scripts/`，包括
  `request-copilot.sh` 和 `fetch-comments.sh`。这里仍然没有仓库内定义的
  `/fix-pr` shell 命令入口。

  这一阶段指的是进入上层 fix-pr 工作流，执行以下事情：
   - 拉取所有评论（Copilot + 人工 + CI）
   - 分析并生成任务列表
   - 按 AgentKit 约束应用修复
   - 构建并测试
   - 提交并推送
   - 在线程中回复
   - 触发下一轮 Copilot review

5. **决定是否继续循环**：
   
  fix-pr 工作流完成一轮后，检查结果：
   - 如果是 `empty`（没有新的反馈）：退出并报告成功
  - 如果是 `fixed`（已经修改并推送）：**先用 `scripts/request-copilot.sh <PR>` 手动触发下一轮 Copilot review**（push 不会自动触发），然后回到步骤 3 监控
   - 上限：在没有用户 check-in 的情况下最多自动跑 3 轮。达到 3 轮后暂停，并询问用户是否继续

## 重要事项

- 每一轮 Copilot review 都会消耗一次 premium request。无人值守时最多 3 轮；达到上限后必须由用户明确决定是否继续。
- 如果 fix-pr 工作流遇到需要人工判断的 CHANGES_REQUESTED（例如架构分歧、范围争议），立即停止并上报给用户，不要自动处理。
- 如果尝试修复后 `swift build` 或 `swift test` 失败，立即停止，不要推送损坏的提交。
- 不要自动启用 babysit cron mode。这个能力只能由用户显式开启。

## 失败处理

如果任一步骤失败：
- 步骤 2（开始轮询）：如果仓库没有自动触发 Copilot review 的能力，则回退为“PR 已打开，但未检测到自动 Copilot review，退出自动循环”
- 步骤 3（监控）：如果超时，询问用户
- 步骤 4（fix-pr 工作流）：按原样把失败信息反馈出来，不要盲目重试
- 步骤 5（循环）：如果触发 3 轮上限，总结已完成内容并询问用户下一步怎么做