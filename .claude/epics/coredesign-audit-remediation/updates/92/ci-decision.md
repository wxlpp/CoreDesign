# Issue #92 决策记录

本文件由 Task 3 创建（C9b 的路径尝试记录），Task 4 追加 CI runner 结论。

---

## C9b：预览宿主启用 Blossom trait

### 结论：**路径 1 达成**，无需 wrapper 包

计划列了四条路径，路径 1 一次成功：

| 路径 | 结果 |
|---|---|
| 1. 更新版 xcodegen 支持 traits | ✅ **采用**。2.46.0 新增该支持 |
| 2. `xcodebuild` trait 参数 | 未采用（`xcodebuild -help` 无 trait 相关参数） |
| 3. `SWIFT_ACTIVE_COMPILATION_CONDITIONS` | 未采用（只作用于 App 自身代码，不影响作为依赖编译的 CoreDesign） |
| 4. wrapper 本地包 | **未采用**——路径 1 更优，见下方取舍说明 |

### 实施

`App/project.yml` 的 `packages.CoreDesign` 下加：

```yaml
    traits: ["Blossom"]
```

**依赖升级**：xcodegen `2.45.4` → `2.46.0`（`brew upgrade xcodegen`）。

2.45.4 会**静默忽略** `traits:` 键——不报错、不警告，生成物中零 trait 痕迹。这是本任务遇到的第二个「接受但不生效」的陷阱（另一个是 `@available(*, unavailable)` 探针）。2.46.0 的 release note 明确写了 "Added support for Swift package `traits` on remote and local package references"（PR #1629）。

**本仓库现在要求 xcodegen ≥ 2.46.0**。低于此版本跑 `xcodegen generate` 会静默产出一个不带 trait 的工程，且没有任何提示。

### 验证证据（不止于「构建成功」）

计划明确要求看真实生效而非声明存在——因为「构建成功」正是 2.45.4 静默忽略时的表现。三层证据：

1. **生成物中有声明**：`App/CoreDesignPreview.xcodeproj/project.pbxproj:447-449`

   ```
   traits = (
       Blossom,
   );
   ```

2. **trait 真的传到了编译器**（决定性证据）：

   ```
   $ xcodebuild build -project App/CoreDesignPreview.xcodeproj -scheme CoreDesignPreview \
       -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO
   ** BUILD SUCCEEDED **
   $ grep -oE '\-DBlossom' <build log>
   -DBlossom
   ```

   `-DBlossom` 出现在编译参数中，意味着 CoreDesign 的 `#if Blossom` 分支会被真实编译进去。

3. **构建成功**：`EXIT=0`、`** BUILD SUCCEEDED **`。

### 取舍：预览宿主现在总是 Blossom

`traits: ["Blossom"]` 是无条件的，因此 `CoreDesignPreview` **之后只渲染 Blossom 主题**，不再能用于查看默认 Craft 主题。

这是 92.md 的 C9b 验收标准所要求的（「使预览宿主能渲染 Blossom 主题」），但它是一处真实的能力变化，后续 Issue 的视觉评审需要知道：

- **看 Blossom**：直接跑 `scripts/run-preview.sh`
- **切回默认主题**：注释掉 `App/project.yml` 的 `traits: ["Blossom"]` 一行，重跑 `xcodegen generate --spec project.yml`，再 `git checkout -- App/CoreDesignPreview.xcodeproj/xcshareddata/` 恢复 shared scheme

### 附带发现：regenerate 会删掉 shared xcscheme

`xcodegen generate` 每次都会删除 `App/CoreDesignPreview.xcodeproj/xcshareddata/xcschemes/CoreDesignPreview.xcscheme`（它是已提交的共享 scheme，而 xcodegen 不生成它）。

**任何跑 `xcodegen generate` 的人都要跟一句**：

```bash
git checkout -- App/CoreDesignPreview.xcodeproj/xcshareddata/
```

否则 `scripts/run-snapshots.sh`（依赖 `-scheme CoreDesignPreview`）会失效。

---

## C1：CI runner 能力结论

（Task 4 填写）
