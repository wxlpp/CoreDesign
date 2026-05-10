---
name: storybook-app
status: completed
created: 2026-05-10T13:00:34Z
progress: 100%
prd: .claude/prds/storybook-app.md
github: https://github.com/wxlpp/CoreDesign/issues/52
---

# Epic: storybook-app

## Overview

在 CoreDesign 仓库内搭建组件预览 App + 快照测试 + 文档站三位一体工作流。库开发者修改组件后：在模拟器跑 App 浏览效果 → 运行测试生成 PNG → docs/ 引用截图更新文档。

## Architecture Decisions

### ADR #1：App 载体

选择在 `App/` 目录下创建独立 `.xcodeproj`，以 local SPM package 方式引用仓库根目录的 CoreDesign。

- **理由**：SPM 不直接支持 iOS App target（只支持 library / executable）。Xcode project 是最小阻力路径。
- **替代方案**：`.xcworkspace` 包裹 SPM + App project（更干净但多一层嵌套）。首版选简单方案。

### ADR #2：快照框架

使用 [SnapshotPreviews](https://github.com/EmergeTools/SnapshotPreviews) 的 `SnapshotTest` 基类自动收编所有 `#Preview` 宏。

- **理由**：零代码生成 PNG——只需继承 `SnapshotTest`，无需逐个手动调用 snapshot API。`TEST_RUNNER_SNAPSHOTS_EXPORT_DIR` 环境变量控制输出路径。
- **替代方案**：手写 `XCTestCase` + `UIView().snapshot()`。工作量大、维护成本高。

### ADR #3：组件文档格式

`docs/components/<component>.md`，每文件含 API 签名 + 参数表 + Light/Dark 截图 + 代码示例。

- **理由**：Developer-facing，格式与现有 CLAUDE.md / PRD 一致（CommonMark + 中文注释）。
- **截图引用**：快照输出到 `docs/snapshots/<component>_light.png`、`docs/snapshots/<component>_dark.png`。

### ADR #4：部署目标

iOS 26+，与 CoreDesign 库一致。App 不上架，仅 Simulator / 开发设备使用。

## Technical Approach

### App Target（`App/CoreDesignPreview.xcodeproj`）

```
App/
├── CoreDesignPreview.xcodeproj/
├── Sources/
│   ├── App.swift              # @main App entry
│   ├── ContentView.swift       # 组件列表首页
│   ├── ComponentDetail.swift   # 组件详情页（light + dark 双栏）
│   └── ComponentData.swift     # 组件元数据（名称、描述、分类、preview builder）
└── (Info.plist — Xcode 自动生成)
```

- `ComponentData` 枚举列出所有组件，每个 case 提供 `name`、`description`、`category`、`preview` 闭包
- `ContentView` 用 `List` 渲染组件列表，`ComponentDetail` 用 `HStack` + `preferredColorScheme` 展示 light/dark 对比
- 可选：嵌入 `PreviewGallery`（SnapshotPreviews feature）作为第二浏览入口

### Snapshot Test Target（`App/CoreDesignPreview.xcodeproj` 内第二个 target）

- 继承 `SnapshotTest`，不覆写任何方法（默认收集所有 `#Preview`）
- Scheme 或 `xcconfig` 预设 `TEST_RUNNER_SNAPSHOTS_EXPORT_DIR` 指向 `docs/snapshots/`
- 运行：`xcodebuild test -project App/CoreDesignPreview.xcodeproj -scheme SnapshotTests -destination 'platform=iOS Simulator,name=iPhone 16'`

### 组件文档

```
docs/
├── components/
│   ├── badge.md
│   ├── tag.md
│   ├── banner.md
│   └── ...（13 个已实现组件）
├── snapshots/
│   ├── badge_light.png
│   ├── badge_dark.png
│   └── ...
└── README.md（组件索引 + 缩略图网格）
```

- `.md` 模板：组件名 → 概念说明 → API 签名 → 参数表 → Light 截图 → Dark 截图 → 代码示例

## Implementation Strategy

### Phase A：基础设施（Task 1-2，顺序）
1. 创建 Xcode project + App target + SPM dependency 配置
2. 实现 storybook UI（列表 + 详情页 + 组件数据）

### Phase B：快照 + 文档（Task 3-4，顺序，依赖 Phase A）
3. 配置 SnapshotTest target + 生成首版快照
4. 编写 13 个组件的 docs + 引用快照

### Phase C：收尾（Task 5，并行于 Phase B）
5. docs/README.md 索引 + 根目录 Makefile/脚本

## Task Breakdown Preview

| # | Task | 并行? | 预估 |
|---|---|---|---|
| 1 | 创建 App project + SPM 配置 | 否 | 1h |
| 2 | Storybook UI（列表 + 详情 + 组件数据） | 否* | 2h |
| 3 | SnapshotTest target + 首版快照 | 否* | 1h |
| 4 | 13 个组件文档 + 截图 | 是 | 3h |
| 5 | docs/README 索引 + 快捷脚本 | 是 | 0.5h |

\* Task 2 依赖 1，Task 3 依赖 2（需要 preview 代码才能生成快照）

## Dependencies

- [SnapshotPreviews](https://github.com/EmergeTools/SnapshotPreviews) (SPM)
- CoreDesign SPM package（本地路径引用）
- Xcode 16+ with iOS 26 Simulator

## Tasks Created
- [x] #53 - 创建 App project + SPM 配置 (parallel: false)
- [x] #54 - Storybook UI（组件列表 + 详情页 + 组件数据）(parallel: false)
- [x] #55 - SnapshotTest target + 生成首版快照 (parallel: false)
- [ ] #56 - 16 个组件文档 + 截图引用 (parallel: true)
- [ ] #57 - docs/README 索引导航 + 快捷脚本 (parallel: true)

Total tasks: 5
Parallel tasks: 2 (#56, #57)
Sequential tasks: 3 (#53→#54→#55)
Estimated total effort: 6.5 hours

## Success Criteria (Technical)

- SC-T1：`xcodebuild` 构建 App 成功，Simulator 中可浏览 13 个组件
- SC-T2：`xcodebuild test` SnapshotTest target 通过，`docs/snapshots/` 下生成 ≥ 13 张 PNG（每组件至少 1 张）
- SC-T3：`docs/components/` 下 13 个 `.md` 文件完整，每文件含双栏截图
- SC-T4：`docs/README.md` 列出所有组件，含缩略图网格

## Estimated Effort

~7.5 小时（单人），含 2 个并行任务可缩短至 ~5 小时 wall time。
