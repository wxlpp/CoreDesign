---
name: storybook-app
description: 组件预览 App + 快照生成 + 文档站点，供库开发者快速验证外观与 API
status: backlog
created: 2026-05-10T12:10:00Z
---

# PRD: storybook-app

## Executive Summary

为 CoreDesign 仓库创建一个独立 iOS App target，内置基于 SnapshotPreviews 的组件预览画廊（Preview Gallery）、自动快照生成能力（XCTest），以及一个 docs/ 下的组件文档与示例图站点。目标是让库开发者在修改组件后能立即在 App 中浏览效果并生成 PNG 快照供文档引用。

## Problem Statement

当前 CoreDesign 组件仅通过 SwiftUI `#Preview` 宏在 Xcode canvas 中预览，存在三个痛点：

1. **无法脱离 Xcode 浏览**：设计师或 Code Review 者必须打开 Xcode 才能看效果
2. **API 用法无集中入口**：组件暴露的 public init 参数和 visual token 散落在源码中，新成员上手成本高
3. **文档无截图**：docs/ 目录下仅有 markdown，缺少组件视觉参考

## User Stories

- 作为库开发者，我想在 iPhone 真机 / 模拟器上浏览所有组件的外观，不需要打开 Xcode
- 作为库开发者，我想在修改组件后运行一次 `swift test` 就能生成所有组件的 PNG 快照到指定目录
- 作为库维护者，我想在 docs/ 中看到每个组件的 API 摘要、使用示例和实际截图
- 作为 Code Reviewer，我可以在 PR 描述中引用快照链接，快速对比修改前后的视觉差异

## Functional Requirements

### FR-A：PreviewGallery App

- FR-A1：在仓库根目录创建独立 App target（如 `CoreDesignPreview/`），使用 SwiftUI `App` 协议
- FR-A2：App 首页为组件列表（`List`），按组件名分组（Badge、Tag、Banner、Button、…）
- FR-A3：点击组件进入该组件的预览页，展示 light / dark 双栏对比（`HStack` + `preferredColorScheme`）
- FR-A4：每个组件至少包含一个 `#Preview` 块，覆盖空态、填充态、hover 态（如适用）
- FR-A5：利用 SnapshotPreviews 的 `PreviewGallery` view 作为备用浏览入口（可选启用）
- FR-A6：部署目标 iOS 26+，纯 SwiftUI，支持 iPhone / iPad

### FR-B：Snapshot Test Target

- FR-B1：创建 XCTest target 继承 `SnapshotTest`，自动收编所有 `#Preview` 宏生成 PNG
- FR-B2：快照输出目录通过环境变量 `TEST_RUNNER_SNAPSHOTS_EXPORT_DIR` 指定（CLI 运行时可配）
- FR-B3：测试 target 仅包含 SwiftUI 预览快照，不覆盖 WebKit / SceneKit 等非 CoreDesign 组件
- FR-B4：支持 `xcodebuild test` 无头运行（CI 兼容），生成 PNG + JSON metadata sidecars

### FR-C：组件文档 + 快照

- FR-C1：在 `docs/components/` 下每个组件一个 `.md` 文件（`badge.md`、`tag.md`、…）
- FR-C2：每个文档至少包含：API 签名摘要、参数表格、Light/Dark 双栏截图、代码示例
- FR-C3：截图引用路径指向快照输出目录中的 PNG（相对路径，如 `../snapshots/badge_light.png`）
- FR-C4：`docs/README.md` 作为组件索引，列出所有组件及缩略图网格

## Non-Functional Requirements

- NFR1：App target 不引入对 CoreDesign 之外的 UI 依赖（仅 SnapshotPreviews + SwiftUI）
- NFR2：快照生成在 Mac (arm64) 上运行，单次全量 < 30 秒
- NFR3：文档 markdown 文件遵循 CommonMark 规范，截图尺寸统一（如 390×844 iPhone 16 逻辑分辨率）

## Success Criteria

- SC1：在 iPhone 16 Simulator 上运行 App，能在首页列表看到所有现有组件，点进去可查看 light + dark 渲染
- SC2：`swift test --filter SnapshotTests` 在 Mac 上通过，生成至少 10 张 PNG（每个组件 ≥ 1 张）
- SC3：`docs/components/` 下每个已实现组件都有对应 `.md` 文件，含双栏截图
- SC4：任意开发者 checkout 后按 README 中的 3 行命令即可在模拟器中看到 App

## Constraints & Assumptions

- 仅支持 iOS 26+，与 CoreDesign 库自身一致
- SnapshotPreviews 库通过 Swift Package Manager 引入（`https://github.com/EmergeTools/SnapshotPreviews`）
- 首版覆盖已完成的 13 个组件（Badge、Tag、Banner、Button、…）
- App 仅开发团队内部使用，不上架 App Store，不要求 App Store Review 合规

## Out of Scope

- 交互式 playground（实时调参看效果）
- iPad / Mac / visionOS 适配（App 仅跑在 iPhone Simulator 上）
- 视觉回归 CI 自动对比（只生成快照，不做 diff）
- 多语言 / RTL 测试变体
- 对外公开文档站点（仅仓库内 docs/ 目录）

## Dependencies

- [SnapshotPreviews](https://github.com/EmergeTools/SnapshotPreviews) — MIT license，via SPM
- CoreDesign 库现有 `#Preview` 宏 — 快照收编的基础
- Xcode 16+（Swift 6 + iOS 26 SDK）
