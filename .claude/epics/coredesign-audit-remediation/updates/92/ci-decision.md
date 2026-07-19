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

### 结论：**级别 1**，五条命令全部可进 CI，无需降级

这是从 PRD 阶段悬到现在的首要风险，结果是最好的一种。

### 实测输出（探针 workflow `_probe-runner.yml`，run 29691369849）

| image | macOS | Xcode | iOS 26 runtime | iPhone 17 Pro |
|---|---|---|---|---|
| **`macos-26`** | 26.4 | **26.5** (17F42) | ✅ `yes` | ✅ `yes` |
| `macos-latest` | 26.4 | 26.5 (17F42) | ✅ `yes` | ✅ `yes` |
| `macos-15` | 15.7.7 | 16.4 (16F6) | — | — |

`macos-26` 上实际可用的 iOS runtime：

```
iOS 26.2 (26.2 - 23C54)
iOS 26.4 (26.4.1 - 23E254a)
iOS 26.5 (26.5 - 23F77)
```

三个 image 的 job 全部 `success`。

### 采用

**`macos-26`**。虽然 `macos-latest` 当前解析到同一镜像（macOS 26.4 / Xcode 26.5），但 `latest` 的含义会随 GitHub 滚动，钉死 `macos-26` 更可预测——本仓库的部署目标就是 26。

runner 的 Xcode 26.5 是默认选中的，**不需要 `xcode-select` 步骤**，`ci.yml` 里预留的那个插槽保持注释状态。

### 对下游 Issue 的影响

- **SC-1（下游 probe 包）**：进 CI。本任务已把 probe 固化为 `scripts/downstream-probe/`（起因见下方「附带发现」），CI 会构建它
- **SC-4（CI workflow 覆盖五条命令）**：**达成**，无降级
- **#4 的布局断言层是否有自动化守护：有** ✅

  `#4` 可以放心把布局断言写成 `#if os(iOS)` + `xcodebuild` Simulator 形式，CI 的 `simulator` job 会真实运行它们。不需要退回「本地手工执行并记录输出」的降级路径。

- **级别 4 的本地 pre-push 脚本**：不需要，未创建

### simulator job 跳过 `ToastHostTests`（#4 与 #7 需知）

CI 首跑暴露了一件本机看不出来的事：`ToastHostTests` 的三个 timing 用例在 GitHub runner 上**稳定失败**（连跑两次都红），不是偶发 flake。它们 sleep 固定 buffer（0.3–0.5s）后断言自动 dismiss / 动画 / advance 已完成，该 buffer 在 runner 负载下持续不够。

处置：simulator job 用 `-skip-testing:CoreDesignTests/ToastHostTests` 跳过。理由——

- 它们是**平台无关**的状态机断言，SwiftPM 的两个 job 已覆盖且通过；在 simulator 里重跑一遍不增加任何信号
- 本 job 的存在意义是 iOS 特有断言（`#4` 的布局层）
- 不跳过则该 job 永久红，比没有更糟

**给 `#7` 的输入**：加大 buffer 或注入 `Clock` 抽象属于测试改动，归 `#7`（C2 恒真断言清理的同一批工作）。测试文件头 `ToastHostTests.swift:15-21` 已自述预案：`.tags(.flaky)` 或注入 `any Clock`。`#7` 完成后可考虑把这条 skip 撤掉。

**给 `#4` 的输入**：布局断言层落地后，simulator job 才开始产生真实价值。届时确认 skip 列表没有误伤新增的 `#if os(iOS)` 测试。

### 附带发现：所有验证都在被隔离的 target 内部，看不见公开 API 契约

Task 1 的 checkpoint 评审发现，`defaultIsolation` 改变的不只是库内编译，还有**公开 API 的隔离契约**——下游从 nonisolated 上下文使用 `ToastItem` / `BadgeVariant` 等公开值类型会编译失败（实测 10 个 error）。

根因是结构性的：四条 SwiftPM 命令、`xcodebuild test`、warning 判据**全都跑在被隔离的 target 内部**，没有任何一处能看见下游视角。

因此新增 `scripts/downstream-probe/`——一个从 `nonisolated` 函数使用公开值类型的探针包，并纳入 CI。它是唯一能发现这类回归的地方；后续任何涉及隔离标注的改动（`#4`、`#10` 都会碰 token 层）都应保持它绿。
