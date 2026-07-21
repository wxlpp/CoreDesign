# CoreDesign 组件库 / Component Library

iOS 26+ / macOS 26+ SwiftUI 设计系统，含 18 个 Primer 对齐组件。

## 组件索引 / Component Index

### Button 按钮

| 组件 | 预览 | 文档 |
|---|---|---|
| Button | [<img src="snapshots/CoreDesignPreview_Previews.swift_Button.png" width="200">](components/button.md) | [button.md](components/button.md) |

### Form 表单

| 组件 | 预览 | 文档 |
|---|---|---|
| SegmentedControl | [<img src="snapshots/CoreDesignPreview_Previews.swift_SegmentedControl.png" width="200">](components/segmented-control.md) | [segmented-control.md](components/segmented-control.md) |
| SearchField | [<img src="snapshots/CoreDesignPreview_Previews.swift_SearchField.png" width="200">](components/search-field.md) | [search-field.md](components/search-field.md) |
| BottomInputBar | [<img src="snapshots/CoreDesignPreview_Previews.swift_BottomInputBar.png" width="200">](components/bottom-input-bar.md) | [bottom-input-bar.md](components/bottom-input-bar.md) |
| LabelIcon / ChevronRightIcon / DangerIcon | [<img src="snapshots/CoreDesignPreview_Previews.swift_Form_Icons.png" width="200">](components/form-icons.md) | [form-icons.md](components/form-icons.md) |

### Indicator 指示器

| 组件 | 预览 | 文档 |
|---|---|---|
| Badge | [<img src="snapshots/CoreDesignPreview_Previews.swift_Badge.png" width="200">](components/badge.md) | [badge.md](components/badge.md) |
| Tag | [<img src="snapshots/CoreDesignPreview_Previews.swift_Tag.png" width="200">](components/tag.md) | [tag.md](components/tag.md) |
| Banner | [<img src="snapshots/CoreDesignPreview_Previews.swift_Banner.png" width="200">](components/banner.md) | [banner.md](components/banner.md) |
| StateLabel | [<img src="snapshots/CoreDesignPreview_Previews.swift_StateLabel.png" width="200">](components/state-label.md) | [state-label.md](components/state-label.md) |
| ProgressIndicator | [<img src="snapshots/CoreDesignPreview_Previews.swift_ProgressIndicator.png" width="200">](components/progress-indicator.md) | [progress-indicator.md](components/progress-indicator.md) |
| ProgressBar | [<img src="snapshots/CoreDesignPreview_Previews.swift_ProgressBar.png" width="200">](components/progress-bar.md) | [progress-bar.md](components/progress-bar.md) |

### Layout 布局

| 组件 | 预览 | 文档 |
|---|---|---|
| Avatar | [<img src="snapshots/CoreDesignPreview_Previews.swift_Avatar.png" width="200">](components/avatar.md) | [avatar.md](components/avatar.md) |
| AvatarGroup | [<img src="snapshots/CoreDesignPreview_Previews.swift_AvatarGroup.png" width="200">](components/avatar-group.md) | [avatar-group.md](components/avatar-group.md) |
| ListRow | [<img src="snapshots/CoreDesignPreview_Previews.swift_ListRow.png" width="200">](components/list-row.md) | [list-row.md](components/list-row.md) |
| FlowLayout | [<img src="snapshots/CoreDesignPreview_Previews.swift_FlowLayout.png" width="200">](components/flow-layout.md) | [flow-layout.md](components/flow-layout.md) |

### Navigation 导航

| 组件 | 预览 | 文档 |
|---|---|---|
| Sidebar | [<img src="snapshots/CoreDesignPreview_Previews.swift_Sidebar.png" width="200">](components/sidebar.md) | [sidebar.md](components/sidebar.md) |
| UnderlinedTabBar | [<img src="snapshots/CoreDesignPreview_Previews.swift_UnderlinedTabBar.png" width="200">](components/underlined-tab-bar.md) | [underlined-tab-bar.md](components/underlined-tab-bar.md) |

### Feedback 反馈

| 组件 | 预览 | 文档 |
|---|---|---|
| Toast | [<img src="snapshots/CoreDesignPreview_Previews.swift_Toast.png" width="200">](components/toast.md) | [toast.md](components/toast.md) |
| ~~EmptyState~~ | _已于 #97 移除 — 改用 SwiftUI [`ContentUnavailableView`](https://developer.apple.com/documentation/swiftui/contentunavailableview)_ | [empty-state.md](components/empty-state.md)（墓碑 + 迁移指引） |

## 生成预览图 / Generating Snapshots

运行 `scripts/run-snapshots.sh` 重新生成所有已收录 `#Preview` 宏的组件 PNG 预览图，输出到 `docs/snapshots/`。

Run `scripts/run-snapshots.sh` to regenerate preview PNGs for all components with `#Preview` macros, output to `docs/snapshots/`.

## 运行演示应用 / Running the Preview App

运行 `scripts/run-preview.sh` 在模拟器中构建并启动 CoreDesignPreview 应用。

Run `scripts/run-preview.sh` to build and launch the CoreDesignPreview app in the Simulator.
