# CoreDesign 组件库 / Component Library

iOS 26+ / macOS 26+ SwiftUI 设计系统，含 15 个 Primer 对齐组件。

## 组件索引 / Component Index

### Button 按钮

| 组件 | 预览 | 文档 |
|---|---|---|
| Button | — | [button.md](components/button.md) |

### Form 表单

| 组件 | 预览 | 文档 |
|---|---|---|
| SegmentedControl | — | [segmentedcontrol.md](components/segmentedcontrol.md) |
| SearchField | — | [searchfield.md](components/searchfield.md) |
| BottomInputBar | — | [bottominputbar.md](components/bottominputbar.md) |
| LabelIcon / ChevronRightIcon / DangerIcon | — | [form-icons.md](components/form-icons.md) |

### Indicator 指示器

| 组件 | 预览 | 文档 |
|---|---|---|
| Badge | — | [badge.md](components/badge.md) |
| Tag | — | [tag.md](components/tag.md) |
| Banner | — | [banner.md](components/banner.md) |

### Layout 布局

| 组件 | 预览 | 文档 |
|---|---|---|
| Avatar | — | [avatar.md](components/avatar.md) |
| BookCover | — | [bookcover.md](components/bookcover.md) |
| EmptyState | — | [emptystate.md](components/emptystate.md) |
| ListRow | — | [listrow.md](components/listrow.md) |

### Navigation 导航

| 组件 | 预览 | 文档 |
|---|---|---|
| SidebarRow | — | [sidebarrow.md](components/sidebarrow.md) |
| UnderlinedTabBar | — | [underlinedtabbar.md](components/underlinedtabbar.md) |

### Feedback 反馈

| 组件 | 预览 | 文档 |
|---|---|---|
| Toast | — | [toast.md](components/toast.md) |

## 生成预览图 / Generating Snapshots

运行 `scripts/run-snapshots.sh` 生成所有已收录 `#Preview` 宏的组件 PNG 预览图，输出到 `docs/snapshots/`。生成的 PNG 不检入版本库，须本地运行脚本后才能看到缩略图。

Run `scripts/run-snapshots.sh` to generate preview PNGs for all components with `#Preview` macros, output to `docs/snapshots/`. PNGs are not checked in — run the script locally to populate thumbnails.

## 运行演示应用 / Running the Preview App

运行 `scripts/run-preview.sh` 在模拟器中构建并启动 CoreDesignPreview 应用。

Run `scripts/run-preview.sh` to build and launch the CoreDesignPreview app in the Simulator.
