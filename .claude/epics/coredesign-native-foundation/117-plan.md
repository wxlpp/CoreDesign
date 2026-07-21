# Issue #117 实现计划：删除 6 个 GitHub 专用组件

目标组件：`BookCover` / `RefPill` / `StatusRow` / `EventRow` / `CommentCard` / `TimelineItem`。

## 基线

- `swift test`：95 tests / 30 suites，全绿（已跑过，记录为对比基准）。
- 6 个测试文件共 15 个 `@Test`（BookCover 4 / RefPill 2 / StatusRow 2 / EventRow 2 / CommentCard 2 / TimelineItem 3）——删除后预期 95 - 15 = **80 tests**，无 failure。

## 步骤

1. **删除 Sources 组件目录**
   `Sources/CoreDesign/Components/{BookCover,RefPill,StatusRow,EventRow,CommentCard,TimelineItem}/`
   - `StatusRow.swift` 内的 `StatusResult`（含 `Spec`/`spec` 扩展）随目录一起删除。
   - **不动** `Sources/CoreDesign/Components/StatusLevel.swift`——它是 `Banner` / `Toast` 的公开 API 参数类型。
   - 验证：`ls Sources/CoreDesign/Components/` 确认六个目录消失，`StatusLevel.swift` 仍在。

2. **删除 Tests 文件**
   `Tests/CoreDesignTests/{BookCoverTests,RefPillTests,StatusRowTests,EventRowTests,CommentCardTests,TimelineItemTests}.swift`
   - 验证：`ls Tests/CoreDesignTests/ | grep -iE "bookcover|refpill|statusrow|eventrow|commentcard|timelineitem"` 应为空。

3. **删除 docs/components 文档页**
   `docs/components/{book-cover,ref-pill,status-row,event-row,comment-card,timeline-item}.md`
   - 验证：同上 grep docs/components。

4. **清理 docs/README.md 组件索引条目**
   删除 6 行组件索引表格行（RefPill / BookCover / TimelineItem / EventRow / CommentCard / StatusRow）。
   - 验证：`grep -iE "bookcover|refpill|statusrow|eventrow|commentcard|timelineitem" docs/README.md` 为空。

5. **删除 docs/snapshots 快照配对**
   每个组件的 `CoreDesignPreview_Previews.swift_<Name>.png` + `.json`，共 12 个文件。
   - 验证：`ls docs/snapshots/ | grep -iE "bookcover|refpill|statusrow|eventrow|commentcard|timelineitem"` 为空。

6. **清理 `App/Sources/Previews.swift`（24 处）**
   删除对应的 `#Preview("BookCover")` / `#Preview("RefPill")` / `#Preview("TimelineItem")` /
   `#Preview("EventRow")` / `#Preview("CommentCard")` / `#Preview("StatusRow")` 整块（含内部嵌套调用，
   如 EventRow demo 里的 `RefPill(...)`、TimelineItem 的嵌套自调用）。
   - 验证：`grep -c` 每个组件名归零。

7. **清理 `App/Sources/ComponentData.swift`（4 处）**
   删除 `book-cover` 这一条 `ComponentMeta`（layout 分类）及对应的 `private struct BookCoverPreview`。
   （grep 确认该文件仅涉及 BookCover，另外 5 个组件未在此文件出现。）
   - 验证：`grep -c BookCover` 归零。

8. **不动 `CoreGradient`**
   `CommentCard.swift` 是 `Sources` 内唯一外部调用 `CoreGradient.brand` 的组件，删除 CommentCard 后
   `CoreGradient` 成孤儿，但按 117.md 说明，孤儿清理属于 Task #118 范围——本任务不删除
   `Tokens/CoreGradient.swift` / `CoreGradient+Preview.swift`。

9. **全局验证**
   - `grep -rn "BookCover\|RefPill\|StatusRow\|EventRow\|CommentCard\|TimelineItem" Sources Tests docs App` → 0 行
     （需确认不会误伤 `StatusLevel` / `StatusColors` 等无关词——这些不含目标词本身，不会被匹配到）
   - `swift build` 通过
   - `swift test` 通过，80 tests / 0 failure

10. **提交**
    按逻辑分组提交（如：Sources+Tests 一提交，docs 一提交，App 一提交，或视情况合并），
    每条 commit message 用 `Issue #117: <描述>` 格式，末尾加 Co-Authored-By 行。
